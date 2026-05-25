"""
Midori ML inference engine — Two-Stage Pipeline (v2)
=====================================================

Architecture
------------
Stage 1 : plant_identifier.keras  — 6-class plant identification
          Classes: Apple, Corn, Grape, Potato, Tomato, Pepper

Stage 2 : Per-plant disease models
          Apple.keras   — 4 classes : Apple Scab | Black Rot | Cedar Apple Rust | Healthy
          Potato.keras  — 3 classes : Early Blight | Late Blight | Healthy
          Grape.keras   — 4 classes : Black Rot | Esca (Black Measles) |
                                      Leaf Blight (Isariopsis Leaf Spot) | Healthy
          Pepper.keras  — 2 classes : Bacterial Spot | Healthy
          Corn/Tomato   — no disease model yet

Preprocessing
-------------
1. Load image with OpenCV (BGR → RGB).
2. HSV green-channel isolation — hue range 25–95.
3. Morphological cleanup  (15×15 ellipse CLOSE + OPEN).
4. Largest contour  = dominant leaf.
5. Crop with 10 % padding around bounding box.
6. Resize to (224, 224) via PIL.
7. MobileNetV2 preprocess_input → [-1, 1].
8. Fallback (no OpenCV) : simple PIL centre-resize.

Grad-CAM
--------
Both Stage-1 and Stage-2 generate Grad-CAM overlays.
  • Last conv layer : "out_relu"  (consistent across all MobileNetV2-based models).
  • Backbone-split  : build feature_extractor(backbone.input → conv_layer.output),
    then manually apply remaining layers (GAP, Dense …) inside GradientTape
    so gradients flow correctly through Keras 3 sub-model boundaries.
"""

from __future__ import annotations

import logging
import os
import uuid
from functools import lru_cache
from pathlib import Path

import numpy as np
from PIL import Image

logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────────────────────────────────────
# Lazy TF / Keras imports  (compatible with TF 2.21 + Keras 3)
# ─────────────────────────────────────────────────────────────────────────────

def _import_tf():
    """Return the tensorflow module."""
    import tensorflow as tf
    return tf


def _import_keras():
    """
    Return the keras module.  Priority order:
      1. keras (standalone Keras 3  — ships with TF 2.16+)
      2. tf.keras  (legacy shim inside TensorFlow)
      3. tf_keras  (explicit legacy package, if installed)
    """
    try:
        import keras
        return keras
    except ImportError:
        pass
    try:
        import tensorflow as tf
        return tf.keras
    except Exception:
        pass
    import tf_keras
    return tf_keras


def _mobilenet_preprocess(img_arr: "np.ndarray") -> "np.ndarray":
    """
    Apply MobileNetV2 preprocess_input — matches the notebook exactly.
    Uses tensorflow.keras directly (same path the models were trained with).
    """
    try:
        from tensorflow.keras.applications.mobilenet_v2 import preprocess_input
        return preprocess_input(img_arr)
    except ImportError:
        pass
    try:
        import keras
        return keras.applications.mobilenet_v2.preprocess_input(img_arr)
    except Exception:
        pass
    # Final fallback: manual MobileNetV2 scaling [-1, 1]
    return (img_arr / 127.5) - 1.0


def _import_cv2():
    """Return cv2 module or None if not installed."""
    try:
        import cv2
        return cv2
    except ImportError:
        return None


# ─────────────────────────────────────────────────────────────────────────────
# Model paths  (driven by settings.ML_MODELS_DIR = server/ml/models/)
# ─────────────────────────────────────────────────────────────────────────────

def _ml_dir() -> Path:
    """Return the directory that holds all .keras model files."""
    try:
        from django.conf import settings
        return Path(settings.ML_MODELS_DIR)
    except Exception:
        # Fallback when called outside Django context (e.g. setup_models.py)
        return Path(__file__).resolve().parent.parent.parent / "ml" / "models"


def _build_model_files() -> dict:
    d = _ml_dir()
    return {
        "plant":  d / "plant_identifier.keras",
        "Apple":  d / "Apple_disease.keras",
        "Potato": d / "Potato_disease.keras",
        "Grape":  d / "Grape_disease.keras",
        "Pepper": d / "Pepper_disease.keras",
    }


# Evaluated lazily per request so tests / scripts can override ML_MODELS_DIR
_MODEL_FILES_CACHE: dict | None = None


def _MODEL_FILES() -> dict:          # type: ignore[override]
    global _MODEL_FILES_CACHE
    if _MODEL_FILES_CACHE is None:
        _MODEL_FILES_CACHE = _build_model_files()
    return _MODEL_FILES_CACHE


def _gradcam_dir(sub: str) -> Path:
    from django.conf import settings
    d = Path(settings.MEDIA_ROOT) / "detections" / f"gradcam_{sub}"
    d.mkdir(parents=True, exist_ok=True)
    return d


# ─────────────────────────────────────────────────────────────────────────────
# Class labels
# ─────────────────────────────────────────────────────────────────────────────

PLANT_CLASSES = ["Apple", "Corn", "Grape", "Potato", "Tomato", "Pepper"]

DISEASE_CLASSES: dict[str, list[str]] = {
    "Apple":  ["Apple Scab", "Black Rot", "Cedar Apple Rust", "Healthy"],
    "Potato": ["Early Blight", "Late Blight", "Healthy"],
    "Grape":  [
        "Black Rot",
        "Esca (Black Measles)",
        "Leaf Blight (Isariopsis Leaf Spot)",
        "Healthy",
    ],
    "Pepper": ["Bacterial Spot", "Healthy"],
    # Corn and Tomato: no disease model yet
}

# ─────────────────────────────────────────────────────────────────────────────
# Treatment advice  (from notebooks)
# ─────────────────────────────────────────────────────────────────────────────

TREATMENT_ADVICE: dict[str, str] = {
    # Apple
    "Apple Scab": (
        "Apply fungicides (captan / myclobutanil) at bud-break. "
        "Remove infected leaves. Improve air circulation."
    ),
    "Black Rot": (
        "Prune infected wood 8–12 inches below cankers. "
        "Apply copper-based fungicide. Avoid overhead irrigation."
    ),
    "Cedar Apple Rust": (
        "Remove nearby juniper/cedar hosts if possible. "
        "Apply protective fungicide (mancozeb / myclobutanil) before infection periods."
    ),
    # Potato
    "Early Blight": (
        "Apply chlorothalonil or mancozeb fungicide. "
        "Rotate crops; avoid wetting foliage. Remove debris after harvest."
    ),
    "Late Blight": (
        "URGENT — Apply metalaxyl or cymoxanil immediately. "
        "Destroy infected plants. Report to local agricultural authority."
    ),
    # Grape
    "Esca (Black Measles)": (
        "Remove and destroy infected wood. Apply trunk wound protectants. "
        "Avoid large pruning cuts. No curative treatment exists — prevention is key."
    ),
    "Leaf Blight (Isariopsis Leaf Spot)": (
        "Apply copper-based fungicide or mancozeb. "
        "Remove infected leaves. Ensure good canopy air circulation."
    ),
    # Pepper
    "Bacterial Spot": (
        "Apply copper-based bactericide at first sign. "
        "Avoid overhead irrigation. Use certified disease-free seeds. "
        "Rotate crops for 2–3 years."
    ),
    # Shared
    "Healthy": (
        "No disease detected. Maintain regular watering and fertilisation schedule."
    ),
}

# ─────────────────────────────────────────────────────────────────────────────
# Confidence thresholds
# ─────────────────────────────────────────────────────────────────────────────

PLANT_CONF_THRESHOLD   = 40.0   # Stage-1 min confidence %
DISEASE_CONF_THRESHOLD = 40.0   # Stage-2 min confidence %

LAST_CONV_LAYER = "out_relu"    # Last ReLU in MobileNetV2 — valid for all 5 models


# ─────────────────────────────────────────────────────────────────────────────
# Image preprocessing
# ─────────────────────────────────────────────────────────────────────────────

def preprocess_image(image_path: str, target_size: tuple = (224, 224)) -> np.ndarray:
    """
    Load and preprocess a leaf image for MobileNetV2 inference.

    Attempts HSV green-blob isolation via OpenCV first (dominant-leaf crop).
    Falls back to a simple PIL centre-resize when OpenCV is not available.

    Returns np.ndarray of shape (1, H, W, 3) with values in [-1, 1].
    """
    cv2 = _import_cv2()

    if cv2 is not None:
        img_bgr = cv2.imread(image_path)
        if img_bgr is not None:
            img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
            h, w    = img_rgb.shape[:2]

            # ── HSV green isolation (hue 25–95) ───────────────────────────
            hsv     = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2HSV)
            lower_g = np.array([25,  40,  40])
            upper_g = np.array([95, 255, 255])
            mask    = cv2.inRange(hsv, lower_g, upper_g)

            kernel  = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (15, 15))
            mask    = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
            mask    = cv2.morphologyEx(mask, cv2.MORPH_OPEN,  kernel)

            # ── Crop to dominant leaf ──────────────────────────────────────
            contours, _ = cv2.findContours(
                mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
            )
            if contours:
                largest     = max(contours, key=cv2.contourArea)
                x, y, bw, bh = cv2.boundingRect(largest)
                pad_x = int(bw * 0.10)
                pad_y = int(bh * 0.10)
                x1    = max(0, x - pad_x)
                y1    = max(0, y - pad_y)
                x2    = min(w, x + bw + pad_x)
                y2    = min(h, y + bh + pad_y)
                img_rgb = img_rgb[y1:y2, x1:x2]
            else:
                # No green region — fall back to centre square crop
                side   = min(h, w)
                cy, cx = h // 2, w // 2
                img_rgb = img_rgb[
                    cy - side // 2: cy + side // 2,
                    cx - side // 2: cx + side // 2,
                ]

            # Use BICUBIC — matches PIL default and training-time preprocessing
            img_pil = Image.fromarray(img_rgb).resize(target_size, Image.BICUBIC)
            img_arr = np.array(img_pil, dtype=np.float32)
            img_arr = _mobilenet_preprocess(img_arr)
            return np.expand_dims(img_arr, axis=0)

    # ── Fallback: simple PIL resize (no OpenCV) ───────────────────────────
    logger.warning("[Midori] OpenCV not available — using simple PIL preprocessing.")
    with Image.open(image_path) as raw:
        img_pil = raw.convert("RGB").resize(target_size, Image.BICUBIC)
    img_arr = np.array(img_pil, dtype=np.float32)
    img_arr = _mobilenet_preprocess(img_arr)
    return np.expand_dims(img_arr, axis=0)


# ─────────────────────────────────────────────────────────────────────────────
# Cached model loaders
# ─────────────────────────────────────────────────────────────────────────────

@lru_cache(maxsize=1)
def _get_plant_model():
    keras = _import_keras()
    path  = _MODEL_FILES()["plant"]
    if not path.exists():
        raise FileNotFoundError(
            f"[Midori] Plant identifier not found at {path}. "
            "Run  python scripts/setup_models.py  first."
        )
    logger.info("[Midori] Loading plant identifier from %s", path)
    model = keras.models.load_model(str(path))
    n_classes = _get_output_classes(model)
    logger.info("[Midori] Plant model ready — output classes: %d", n_classes)
    return model


@lru_cache(maxsize=4)
def _get_disease_model(plant_name: str):
    keras = _import_keras()
    path  = _MODEL_FILES().get(plant_name)
    if path is None or not path.exists():
        return None
    logger.info("[Midori] Loading %s disease model from %s", plant_name, path)
    model = keras.models.load_model(str(path))
    n_classes = _get_output_classes(model)
    logger.info(
        "[Midori] %s disease model ready — classes: %d", plant_name, n_classes
    )
    return model


def _get_output_classes(model) -> int:
    """
    Safely read the number of output classes from any Keras model.
    Keras 3 removed model.output_shape on subclassed models; this helper
    falls back to checking the last layer's output spec.
    """
    try:
        return model.output_shape[-1]
    except Exception:
        pass
    try:
        return model.layers[-1].output_shape[-1]
    except Exception:
        pass
    return -1



# ─────────────────────────────────────────────────────────────────────────────
# Grad-CAM  (Keras 3 compatible, backbone-split approach)
# ─────────────────────────────────────────────────────────────────────────────

def _jet_colormap(arr: np.ndarray) -> np.ndarray:
    """Pure-NumPy jet colormap.  arr : (H, W) float [0,1]  →  (H, W, 3) uint8."""
    r = np.clip(1.5 - np.abs(4.0 * arr - 3.0), 0.0, 1.0)
    g = np.clip(1.5 - np.abs(4.0 * arr - 2.0), 0.0, 1.0)
    b = np.clip(1.5 - np.abs(4.0 * arr - 1.0), 0.0, 1.0)
    return (np.stack([r, g, b], axis=-1) * 255).astype(np.uint8)


def _find_mobilenet_base(model):
    """Return the MobileNetV2 sub-model embedded inside *model*, or None."""
    keras = _import_keras()
    for layer in model.layers:
        if isinstance(layer, keras.Model) and "mobilenetv2" in layer.name.lower():
            return layer
    # Generic fallback: first nested model with many layers
    for layer in model.layers:
        if hasattr(layer, "layers") and len(layer.layers) > 3:
            return layer
    return None


def get_gradcam_heatmap(
    model,
    img_array: np.ndarray,
    pred_index: int | None = None,
    last_conv_layer_name: str = LAST_CONV_LAYER,
) -> tuple[np.ndarray, int]:
    """
    Compute Grad-CAM heatmap (Keras 3 / TF 2.13+ compatible).

    Parameters
    ----------
    model                : keras.Model   Any of the 5 project models.
    img_array            : np.ndarray    Preprocessed image  (1, 224, 224, 3).
    pred_index           : int | None    Class to explain. None = argmax.
    last_conv_layer_name : str           Last ReLU in MobileNetV2.

    Returns
    -------
    heatmap    : np.ndarray  shape (7, 7), float32 in [0, 1]
    pred_index : int
    """
    tf    = _import_tf()
    keras = _import_keras()

    base_model = _find_mobilenet_base(model)
    if base_model is None:
        base_model = model   # flat model — treat the whole thing as backbone

    # Build feature extractor: backbone.input → last-conv.output  (7 × 7 × 1280)
    try:
        conv_layer = base_model.get_layer(last_conv_layer_name)
    except (ValueError, AttributeError):
        # Find last layer whose output is 4D (spatial feature map)
        conv_layer = None
        for lyr in reversed(base_model.layers):
            try:
                shape = lyr.output_shape
                if isinstance(shape, (list, tuple)) and len(shape) == 4:
                    conv_layer = lyr
                    break
            except Exception:
                # Keras 3 raises RuntimeError for layers not yet built
                pass
        if conv_layer is None:
            raise RuntimeError("[Midori] Cannot find a convolutional layer for Grad-CAM.")


    feature_extractor = keras.Model(
        inputs=base_model.input,
        outputs=conv_layer.output,
    )

    # Layers after the backbone (GAP, Dense, Softmax …)
    if base_model is model:
        remaining_layers: list = []
    else:
        base_idx = next(
            (i for i, lyr in enumerate(model.layers) if lyr is base_model), None
        )
        remaining_layers = model.layers[base_idx + 1:] if base_idx is not None else []

    img_tensor = tf.cast(img_array, tf.float32)

    with tf.GradientTape() as tape:
        conv_outputs = feature_extractor(img_tensor, training=False)
        tape.watch(conv_outputs)

        if remaining_layers:
            x = conv_outputs
            for layer in remaining_layers:
                x = layer(x, training=False)
            predictions = x
        else:
            predictions = model(img_tensor, training=False)

        if pred_index is None:
            pred_index = int(tf.argmax(predictions[0]))

        class_score = predictions[:, pred_index]

    grads = tape.gradient(class_score, conv_outputs)
    if grads is None:
        raise RuntimeError(
            "[Midori] GradientTape returned None — check last_conv_layer_name."
        )

    pooled_grads = tf.reduce_mean(grads, axis=(0, 1, 2))   # (C,)
    conv_map     = conv_outputs[0]                           # (H, W, C)
    heatmap      = conv_map @ pooled_grads[..., tf.newaxis]  # (H, W, 1)
    heatmap      = tf.squeeze(heatmap)                       # (H, W)

    heatmap  = tf.maximum(heatmap, 0.0)
    max_val  = tf.math.reduce_max(heatmap)
    if float(max_val) > 0.0:
        heatmap = heatmap / max_val

    return heatmap.numpy(), pred_index


def _save_gradcam(
    image_path: str,
    heatmap: np.ndarray,
    sub: str = "disease",
    alpha: float = 0.45,
) -> str | None:
    """
    Overlay heatmap on original image, save PNG, return relative media path.
    sub : "plant" or "disease"
    """
    try:
        orig_img    = np.array(
            Image.open(image_path).convert("RGB").resize((224, 224), Image.LANCZOS)
        )
        heatmap_pil = Image.fromarray(np.uint8(255 * heatmap)).resize(
            (224, 224), Image.BILINEAR
        )
        heatmap_up  = np.array(heatmap_pil) / 255.0
        jet         = _jet_colormap(heatmap_up)
        overlay     = np.uint8(jet * alpha + orig_img * (1 - alpha))

        filename  = f"{uuid.uuid4().hex}.png"
        save_dir  = _gradcam_dir(sub)
        save_path = save_dir / filename
        Image.fromarray(overlay).save(str(save_path))

        rel_path = f"detections/gradcam_{sub}/{filename}"
        logger.info("[Midori] Grad-CAM (%s) saved → %s", sub, save_path)
        return rel_path

    except Exception as exc:
        logger.warning("[Midori] Grad-CAM (%s) failed: %s", sub, exc, exc_info=True)
        return None


# ─────────────────────────────────────────────────────────────────────────────
# Stage 1 — Plant Identification
# ─────────────────────────────────────────────────────────────────────────────

def identify_plant(image_path: str) -> tuple[str, float, list, str | None]:
    """
    Stage 1: Identify plant species from leaf image.

    Returns
    -------
    plant_name      : str         Top-1 class name
    confidence      : float       Confidence %  (0–100)
    all_scores      : list        [(name, pct), ...] for all 6 plant classes
    gradcam_path    : str | None  Relative media path to Stage-1 Grad-CAM PNG
    """
    tf    = _import_tf()
    model = _get_plant_model()

    img_array = preprocess_image(image_path)
    # Use predict() to exactly match the notebook inference path
    raw_preds = model.predict(img_array, verbose=0)[0]

    pred_idx   = int(np.argmax(raw_preds))
    confidence = float(raw_preds[pred_idx]) * 100.0
    plant_name = PLANT_CLASSES[pred_idx]

    all_scores = [
        (PLANT_CLASSES[i], float(raw_preds[i]) * 100.0)
        for i in range(len(PLANT_CLASSES))
    ]

    logger.info("[Midori] Stage 1: %s  (%.1f%%)", plant_name, confidence)

    # Stage-1 Grad-CAM
    gradcam_path: str | None = None
    try:
        heatmap, _ = get_gradcam_heatmap(model, img_array, pred_index=pred_idx)
        gradcam_path = _save_gradcam(image_path, heatmap, sub="plant")
    except Exception as exc:
        logger.warning("[Midori] Stage-1 Grad-CAM error: %s", exc)

    return plant_name, confidence, all_scores, gradcam_path


# ─────────────────────────────────────────────────────────────────────────────
# Stage 2 — Disease Detection
# ─────────────────────────────────────────────────────────────────────────────

def detect_disease(
    image_path: str,
    plant_name: str,
) -> tuple[str | None, float, list, str, str | None, bool]:
    """
    Stage 2: Detect disease for the identified plant.

    Returns
    -------
    disease_name    : str | None
    confidence      : float       Confidence %  (0–100)
    all_scores      : list        [(name, pct), ...]
    advice          : str         Treatment recommendation
    gradcam_path    : str | None  Relative media path to Stage-2 Grad-CAM PNG
    has_model       : bool        False when no disease model exists for this plant
    """
    tf = _import_tf()

    class_names   = DISEASE_CLASSES.get(plant_name)
    disease_model = _get_disease_model(plant_name)

    if disease_model is None or class_names is None:
        logger.info("[Midori] No disease model for '%s'", plant_name)
        return (
            None,
            0.0,
            [],
            "No disease model available for this plant.",
            None,
            False,
        )

    img_array = preprocess_image(image_path)
    # Use predict() to exactly match the notebook inference path
    raw_preds = disease_model.predict(img_array, verbose=0)[0]

    pred_idx   = int(np.argmax(raw_preds))
    confidence = float(raw_preds[pred_idx]) * 100.0
    disease    = class_names[pred_idx]
    advice     = TREATMENT_ADVICE.get(disease, "Consult a local agronomist.")

    all_scores = [
        (class_names[i], float(raw_preds[i]) * 100.0)
        for i in range(len(class_names))
    ]

    logger.info("[Midori] Stage 2: %s  (%.1f%%)", disease, confidence)

    # Stage-2 Grad-CAM
    gradcam_path: str | None = None
    try:
        heatmap, _ = get_gradcam_heatmap(
            disease_model, img_array, pred_index=pred_idx
        )
        gradcam_path = _save_gradcam(image_path, heatmap, sub="disease")
    except Exception as exc:
        logger.warning("[Midori] Stage-2 Grad-CAM error: %s", exc)

    return disease, confidence, all_scores, advice, gradcam_path, True


# ─────────────────────────────────────────────────────────────────────────────
# Public API — run_prediction()
# ─────────────────────────────────────────────────────────────────────────────

def run_prediction(
    image_path: str,
    plant_override: str | None = None,
) -> dict:
    """
    Run the full two-stage detection pipeline.

    Parameters
    ----------
    image_path     : str           Absolute path to the uploaded image.
    plant_override : str | None    Skip Stage 1 — force this plant name.
                                   Required for plants absent from Stage-1 training
                                   (e.g. Pepper, if it was not in Stage-1 data).

    Returns  dict with keys
    --------
    plant_name, plant_confidence, plant_scores, plant_gradcam_path,
    disease_name, disease_confidence, disease_scores,
    advice, is_healthy, disease_gradcam_path,
    status, message
    """

    # ── Stage 1 ──────────────────────────────────────────────────────────────
    if plant_override:
        plant_name       = plant_override.strip().capitalize()
        plant_confidence = 100.0
        plant_scores     = [(plant_name, 100.0)]
        plant_gradcam_path: str | None = None
        logger.info("[Midori] Stage 1 skipped — override: %s", plant_name)
    else:
        try:
            plant_name, plant_confidence, plant_scores, plant_gradcam_path = \
                identify_plant(image_path)
        except Exception as exc:
            logger.error("[Midori] Stage-1 error: %s", exc, exc_info=True)
            return _result(
                status="failed",
                message="Plant identification failed due to an internal error.",
            )

        if plant_confidence < PLANT_CONF_THRESHOLD:
            logger.info(
                "[Midori] Stage-1 confidence too low: %.1f%% < %.1f%%",
                plant_confidence, PLANT_CONF_THRESHOLD,
            )
            return _result(
                plant_name=plant_name,
                plant_confidence=plant_confidence,
                plant_scores=plant_scores,
                plant_gradcam_path=plant_gradcam_path,
                status="not_recognized",
                message=(
                    f"Could not confidently identify the plant "
                    f"({plant_confidence:.1f}%). "
                    "Please take a clearer, closer photo of the leaf."
                ),
            )

    # ── Stage 2 ──────────────────────────────────────────────────────────────
    try:
        (disease_name, disease_confidence, disease_scores,
         advice, disease_gradcam_path, has_model) = detect_disease(image_path, plant_name)
    except Exception as exc:
        logger.error("[Midori] Stage-2 error: %s", exc, exc_info=True)
        return _result(
            plant_name=plant_name,
            plant_confidence=plant_confidence,
            plant_scores=plant_scores,
            plant_gradcam_path=plant_gradcam_path,
            status="failed",
            message="Disease detection failed due to an internal error.",
        )

    if not has_model:
        return _result(
            plant_name=plant_name,
            plant_confidence=plant_confidence,
            plant_scores=plant_scores,
            plant_gradcam_path=plant_gradcam_path,
            status="no_model",
            message=(
                f"{plant_name} was identified, but no disease model is available yet. "
                "Supported: Apple, Potato, Grape, Pepper."
            ),
        )

    is_healthy = "healthy" in disease_name.lower()

    if not is_healthy and disease_confidence < DISEASE_CONF_THRESHOLD:
        return _result(
            plant_name=plant_name,
            plant_confidence=plant_confidence,
            plant_scores=plant_scores,
            plant_gradcam_path=plant_gradcam_path,
            disease_name=disease_name,
            disease_confidence=disease_confidence,
            disease_scores=disease_scores,
            advice=advice,
            disease_gradcam_path=disease_gradcam_path,
            status="low_confidence",
            message=(
                "Disease detection confidence is too low. "
                "Please retake the photo in better lighting."
            ),
        )

    if is_healthy:
        return _result(
            plant_name=plant_name,
            plant_confidence=plant_confidence,
            plant_scores=plant_scores,
            plant_gradcam_path=plant_gradcam_path,
            disease_name=disease_name,
            disease_confidence=disease_confidence,
            disease_scores=disease_scores,
            advice=TREATMENT_ADVICE["Healthy"],
            disease_gradcam_path=disease_gradcam_path,
            is_healthy=True,
            status="healthy",
            message=(
                "Your plant looks healthy! No signs of disease detected. "
                "Keep up the good care! 🌱"
            ),
        )

    # ── Success ───────────────────────────────────────────────────────────────
    return _result(
        plant_name=plant_name,
        plant_confidence=plant_confidence,
        plant_scores=plant_scores,
        plant_gradcam_path=plant_gradcam_path,
        disease_name=disease_name,
        disease_confidence=disease_confidence,
        disease_scores=disease_scores,
        advice=advice,
        disease_gradcam_path=disease_gradcam_path,
        status="success",
        message="",
    )


def _result(
    plant_name: str | None = None,
    plant_confidence: float = 0.0,
    plant_scores: list | None = None,
    plant_gradcam_path: str | None = None,
    disease_name: str | None = None,
    disease_confidence: float = 0.0,
    disease_scores: list | None = None,
    advice: str = "",
    is_healthy: bool = False,
    disease_gradcam_path: str | None = None,
    status: str = "failed",
    message: str = "",
) -> dict:
    """Convenience constructor for run_prediction return dict."""
    return {
        "plant_name":           plant_name,
        "plant_confidence":     plant_confidence,
        "plant_scores":         plant_scores or [],
        "plant_gradcam_path":   plant_gradcam_path,
        "disease_name":         disease_name,
        "disease_confidence":   disease_confidence,
        "disease_scores":       disease_scores or [],
        "advice":               advice,
        "is_healthy":           is_healthy,
        "disease_gradcam_path": disease_gradcam_path,
        "status":               status,
        "message":              message,
    }


# ─────────────────────────────────────────────────────────────────────────────
# Warm-up  (called from apps.py ready())
# ─────────────────────────────────────────────────────────────────────────────

def warm_up_models() -> None:
    """Pre-load all available models at Django startup."""
    logger.info("[Midori] Warming up two-stage models …")
    _get_plant_model()
    for plant in DISEASE_CLASSES:
        try:
            _get_disease_model(plant)
        except Exception as exc:
            logger.warning("[Midori] Could not warm up %s model: %s", plant, exc)
    logger.info("[Midori] Model warm-up complete.")
