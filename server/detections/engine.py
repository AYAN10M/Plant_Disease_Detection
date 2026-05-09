"""
Midori ML inference engine  (MobileNetV2 · 38 PlantVillage classes)
====================================================================

Pipeline
--------
1. Green-channel pre-filter  — fast PIL-based check; rejects obviously
   non-plant images (sky, skin, solid objects …).

2. Weighted TTA inference — 7 crops (full image + 2 centred + 4 corners) with
   centre-biased weights averaged for robustness against real-world backgrounds.

3. Not-a-plant floor — if top-1 probability < NOT_A_PLANT_THRESHOLD the
   model is uncertain → is_plant=False.

4. Healthy vs diseased — PlantVillage class names end in '_healthy' or
   '_Healthy' for healthy plants; no DB lookup needed.

5. Grad-CAM overlay — GradientTape differentiates the top-1 class score
   w.r.t. the last conv-layer activations and saves a jet-colormap PNG.

Grad-CAM implementation notes
------------------------------
* We build a *sub-model* that maps outer-model inputs → [conv_acts, preds].
  The key rule is:  tape.watch(conv_acts_tensor) must be called *before*
  the forward pass so TF records the operation in the tape's context.
* We use a ``persistent=True`` tape and watch the conv tensor explicitly.
* Layer search is recursive so it works whether the model is flat or wraps
  a MobileNetV2 backbone as a sub-model.
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

# ── Lazy TF/Keras imports ─────────────────────────────────────────────────────
# Imported lazily so Django management commands (migrate, seed_model_catalog)
# work in environments without TensorFlow.
def _import_tf():
    os.environ.setdefault("TF_USE_LEGACY_KERAS", "1")
    import tensorflow as tf  # noqa: PLC0415
    return tf


def _import_keras():
    os.environ.setdefault("TF_USE_LEGACY_KERAS", "1")
    # In TF 2.x (all versions including 2.13) tf.keras is always available.
    # Standalone `import keras` fails in TF 2.13 because it tries to bootstrap
    # via tensorflow.compat which is a lazy loader — causing circular init errors.
    # tf.keras is the canonical path for TF 2.x environments.
    try:
        import tensorflow as tf  # noqa: PLC0415
        return tf.keras
    except Exception:
        pass
    try:
        import tf_keras as keras  # noqa: PLC0415  # tf_keras compat shim (TF 2.16+)
        return keras
    except ImportError:
        pass
    import keras  # noqa: PLC0415  # bare keras (Keras 3 / TF 2.16+)
    return keras


# ── Paths ─────────────────────────────────────────────────────────────────────
MODEL_PATH = Path(__file__).resolve().parent.parent / "plant_disease_mobilenet.h5"


def _gradcam_dir() -> Path:
    from django.conf import settings  # noqa: PLC0415
    d = Path(settings.MEDIA_ROOT) / "detections" / "gradcam"
    d.mkdir(parents=True, exist_ok=True)
    return d


# ── Class catalogue ───────────────────────────────────────────────────────────
# Verified: alphabetical order matches the training folder order used by
# image_dataset_from_directory.
CLASS_NAMES: tuple[str, ...] = (
    "Apple_Apple_scab",                            #  0
    "Apple_Black_rot",                             #  1
    "Apple_Cedar_apple_rust",                      #  2
    "Apple_healthy",                               #  3
    "Cherry_healthy",                              #  4
    "Cherry_mildew",                               #  5
    "Corn_Blight",                                 #  6
    "Corn_Cercospora_leaf_spot Gray_leaf_spot",    #  7
    "Corn_Common_rust",                            #  8
    "Corn_healthy",                                #  9
    "Grape_Black_rot",                             # 10
    "Grape_Esca_(Black_Measles)",                  # 11
    "Grape_Leaf_blight_(Isariopsis_Leaf_Spot)",    # 12
    "Grape_healthy",                               # 13
    "Peach_Bacterial_spot",                        # 14
    "Peach_healthy",                               # 15
    "Pepper_bell_Bacterial_spot",                  # 16
    "Pepper_bell_healthy",                         # 17
    "Potato_Early_blight",                         # 18
    "Potato_Late_blight",                          # 19
    "Potato_healthy",                              # 20
    "Rice_Bacterialblight",                        # 21
    "Rice_Blast",                                  # 22
    "Rice_Brownspot",                              # 23
    "Rice_Healthy",                                # 24
    "Rice_Tungro",                                 # 25
    "Strawberry_Leaf_scorch",                      # 26
    "Strawberry_healthy",                          # 27
    "Tomato_Bacterial_spot",                       # 28
    "Tomato_Early_blight",                         # 29
    "Tomato_Late_blight",                          # 30
    "Tomato_Leaf_Mold",                            # 31
    "Tomato_Septoria_leaf_spot",                   # 32
    "Tomato_Spider_mites Two-spotted_spider_mite", # 33
    "Tomato_Target_Spot",                          # 34
    "Tomato_Tomato_Yellow_Leaf_Curl_Virus",        # 35
    "Tomato_Tomato_mosaic_virus",                  # 36
    "Tomato_healthy",                              # 37
)

# ── Thresholds ────────────────────────────────────────────────────────────────
# NOT_A_PLANT_THRESHOLD: if the model's top-1 confidence after weighted TTA
# is below this, the image is treated as "not a plant" and no disease is reported.
# Raised from 0.10 → 0.20 to reject borderline guesses from real-world photos.
NOT_A_PLANT_THRESHOLD = 0.20

# At least this fraction of pixels must be "greener than red AND blue".
# Raised to 2 % to catch more non-leaf photos (phones against cloth, walls etc.)
_GREEN_RATIO_THRESHOLD = 0.02


# ── Stage 1: green-channel pre-filter ─────────────────────────────────────────
def _is_likely_plant(image_path: str) -> bool:
    """
    Fast colour heuristic: reject clearly non-plant images.
    Threshold is intentionally very low so diseased / yellowed / brown
    leaves still pass — the ML model makes the final call.
    """
    try:
        with Image.open(image_path) as img:
            rgb = np.array(img.convert("RGB"), dtype=np.int16)
            r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
            ratio = ((g > r) & (g > b)).sum() / (rgb.shape[0] * rgb.shape[1])
            logger.info("[Midori] Green ratio: %.1f%% (threshold: %.1f%%)",
                        ratio * 100, _GREEN_RATIO_THRESHOLD * 100)
            if ratio < _GREEN_RATIO_THRESHOLD:
                logger.warning("[Midori] Rejected by green-filter: %.1f%%", ratio * 100)
                return False
            return True
    except Exception as exc:
        logger.warning("[Midori] green-check failed (%s) — letting model decide", exc)
        return True   # fail open


# ── Model loading (singleton) ──────────────────────────────────────────────────
@lru_cache(maxsize=1)
def _get_model():
    keras = _import_keras()
    if not MODEL_PATH.exists():
        raise FileNotFoundError(f"[Midori] Model not found at {MODEL_PATH}")
    logger.info("[Midori] Loading MobileNetV2 from %s", MODEL_PATH)
    model = keras.models.load_model(str(MODEL_PATH))
    logger.info("[Midori] Model loaded. Input shape: %s", model.input_shape)
    return model


@lru_cache(maxsize=1)
def _get_input_size() -> tuple[int, int]:
    m = _get_model()
    return int(m.input_shape[1]), int(m.input_shape[2])


# ── Recursive layer finder ────────────────────────────────────────────────────
def _find_layer(model, name: str):
    """
    Recursively search for a layer by name, descending into sub-models.
    Returns the layer object or None.
    """
    for layer in model.layers:
        if layer.name == name:
            return layer
        if hasattr(layer, "layers"):
            result = _find_layer(layer, name)
            if result is not None:
                return result
    return None


def _last_conv_layer_name(model) -> str:
    """
    Walk the model (including nested sub-models) and return the name of
    the last layer whose output is 4-D (N, H, W, C).
    """
    last = None

    def _walk(m):
        nonlocal last
        for layer in m.layers:
            if hasattr(layer, "layers"):
                _walk(layer)
            else:
                try:
                    shape = layer.output_shape
                    if isinstance(shape, (list, tuple)) and len(shape) == 4:
                        last = layer.name
                except Exception:
                    pass

    _walk(model)
    if last is None:
        raise ValueError("[Midori] Cannot find any 4-D conv layer for Grad-CAM")
    return last


# ── Grad-CAM components (cached) ──────────────────────────────────────────────
@lru_cache(maxsize=1)
def _build_gradcam_model():
    """
    Return (backbone_conv_model, head_layers, layer_name).

    Empirically verified approach (see scripts/diagnose_grad2.py Test 5):
    -----------------------------------------------------------------------
    The outer model wraps MobileNetV2 as a nested sub-model (backbone).
    Gradient tape cannot differentiate through the outer model's graph to
    intermediate tensors inside the backbone (different input tensors).

    Proven working strategy:
      1. Build backbone_conv_model: backbone.inputs -> [conv_acts, backbone.output]
         (all tensors live in the backbone's own connected graph)
      2. Collect the head layers (GAP, Dense etc.) from the outer model
      3. In _generate_gradcam_overlay:
         a. Run backbone_conv_model(img) inside tape
         b. tape.watch(conv_acts) BEFORE applying head
         c. Pass backbone_output through head layers to get predictions
         d. grads = tape.gradient(class_score, conv_acts)  <- non-None
    """
    keras  = _import_keras()
    outer  = _get_model()

    # ── Find backbone sub-model ────────────────────────────────────────────────
    backbone = None
    for lyr in outer.layers:
        if hasattr(lyr, "layers") and len(lyr.layers) > 3:
            backbone = lyr
            break

    # ── Find last conv layer (inside backbone or flat model) ───────────────────
    if backbone is not None:
        search_model = backbone
    else:
        search_model = outer

    last_conv = None
    last_conv_name = None
    for lyr in search_model.layers:
        try:
            shape = lyr.output_shape
            if isinstance(shape, (list, tuple)) and len(shape) == 4:
                last_conv = lyr
                last_conv_name = lyr.name
        except Exception:
            pass

    if last_conv is None:
        raise RuntimeError("[Midori] Grad-CAM: no 4-D conv layer found")

    logger.info("[Midori] Grad-CAM target layer: %s  shape=%s",
                last_conv_name, last_conv.output_shape)

    if backbone is not None:
        # Build: backbone.inputs -> [conv_acts, backbone.output]
        # Fully connected within backbone's own graph — gradients flow ✓
        backbone_conv_model = keras.Model(
            inputs=backbone.inputs,
            outputs=[last_conv.output, backbone.output],
        )
        # Head layers = everything after backbone in outer model
        head_layers = []
        after_backbone = False
        for lyr in outer.layers:
            if lyr is backbone:
                after_backbone = True
                continue
            if after_backbone and not isinstance(lyr, keras.layers.InputLayer):
                head_layers.append(lyr)
    else:
        # Flat model: build inner_model: outer.inputs -> [conv_acts, outer.output]
        backbone_conv_model = keras.Model(
            inputs=outer.inputs,
            outputs=[last_conv.output, outer.output],
        )
        head_layers = []  # predictions already included in backbone_conv_model

    logger.info("[Midori] Grad-CAM model ready. Head layers: %s",
                [l.name for l in head_layers])
    return backbone_conv_model, head_layers, last_conv_name


# Apps warm-up alias
def _build_gradcam_models():
    return _build_gradcam_model()


# ── Preprocessing ─────────────────────────────────────────────────────────────
def _preprocess(image_path: str) -> "np.ndarray":
    """Standard single-image preprocessing for Grad-CAM (exact training pipeline)."""
    keras = _import_keras()
    h, w = _get_input_size()
    with Image.open(image_path) as raw:
        pil_img = raw.convert("RGB").resize((w, h), Image.LANCZOS)
    arr = np.array(pil_img, dtype=np.float32)
    return keras.applications.mobilenet_v2.preprocess_input(np.expand_dims(arr, 0))


def _tta_crops(pil_img: "Image.Image") -> list[tuple]:
    """
    Return (crop, weight) pairs for centre-biased weighted TTA.

    Crop strategy
    -------------
    - Full image (weight 3): captures the whole leaf context.
    - Centre 80% crop (weight 3): the subject is usually centred in phone photos.
    - Centre 60% crop (weight 2): tighter centre — more leaf, less background.
    - 4 corner crops at 70% (weight 1 each): robustness to off-centre leaves.

    Corner crops are down-weighted because they frequently contain background
    (tables, hands, cloth) in real-world mobile photos, which dilutes the signal.
    """
    W, H = pil_img.size
    cX, cY = W // 2, H // 2
    crops = []

    # Full image — highest weight
    crops.append((pil_img, 3))

    # Centre 80%
    s80 = int(min(W, H) * 0.80)
    crops.append((pil_img.crop((cX - s80 // 2, cY - s80 // 2,
                                 cX + s80 // 2, cY + s80 // 2)), 3))

    # Centre 60%
    s60 = int(min(W, H) * 0.60)
    crops.append((pil_img.crop((cX - s60 // 2, cY - s60 // 2,
                                 cX + s60 // 2, cY + s60 // 2)), 2))

    # 4 corners at 70% — low weight
    s70 = int(min(W, H) * 0.70)
    for x0, y0 in [(0, 0), (W - s70, 0), (0, H - s70), (W - s70, H - s70)]:
        crops.append((pil_img.crop((x0, y0, x0 + s70, y0 + s70)), 1))

    return crops


def _infer_tta(image_path: str) -> np.ndarray:
    """
    Centre-biased weighted TTA inference.

    Each crop's probability vector is multiplied by its weight before summing.
    An agreement check then penalises the confidence when crops disagree,
    surfacing genuine uncertainty instead of averaging it away.
    """
    tf    = _import_tf()
    keras = _import_keras()
    model = _get_model()
    h, w  = _get_input_size()

    with Image.open(image_path) as raw:
        pil_img = raw.convert("RGB")

    weighted_sum = None
    total_weight = 0
    crop_top1s   = []  # top-1 class per crop (for agreement check)

    for crop, weight in _tta_crops(pil_img):
        resized = crop.resize((w, h), Image.LANCZOS)
        arr     = np.array(resized, dtype=np.float32)
        batch   = keras.applications.mobilenet_v2.preprocess_input(
                      np.expand_dims(arr, 0))
        probs   = model(tf.cast(batch, tf.float32), training=False)[0].numpy()
        crop_top1s.append(int(np.argmax(probs)))

        if weighted_sum is None:
            weighted_sum = probs * weight
        else:
            weighted_sum += probs * weight
        total_weight += weight

    avg = weighted_sum / total_weight

    # ── Crop agreement check ──────────────────────────────────────────────────
    # Only penalise when the two most informative crops (full image + centre 80%)
    # disagree. Corner crops often land on background, so ignoring them for the
    # penalty avoids false confidence reductions on legitimate predictions.
    # crop_top1s[0]=full image, crop_top1s[1]=centre 80%, crop_top1s[2]=centre 60%
    if crop_top1s[0] != crop_top1s[1]:
        # Full image and centre-80 disagree — genuine uncertainty
        penalty = 0.80
        avg = avg * penalty
        logger.info("[Midori] Full-image vs centre-80 disagree (%s vs %s) "
                    "— confidence penalised x%.2f",
                    CLASS_NAMES[crop_top1s[0]] if crop_top1s[0] < len(CLASS_NAMES) else "?",
                    CLASS_NAMES[crop_top1s[1]] if crop_top1s[1] < len(CLASS_NAMES) else "?",
                    penalty)

    top_idx = int(np.argmax(avg))
    logger.info("[Midori] TTA (%d crops, weighted): top-1 = %s  (%.1f%%)",
                len(crop_top1s),
                CLASS_NAMES[top_idx] if top_idx < len(CLASS_NAMES) else "?",
                float(avg[top_idx]) * 100)
    return avg


# ── Grad-CAM overlay ──────────────────────────────────────────────────────────
def _apply_jet_colormap(arr: np.ndarray) -> np.ndarray:
    """
    Pure-NumPy jet colormap: (H, W) float [0,1] → (H, W, 3) uint8 RGB.
    """
    r = np.clip(1.5 - np.abs(4.0 * arr - 3.0), 0, 1)
    g = np.clip(1.5 - np.abs(4.0 * arr - 2.0), 0, 1)
    b = np.clip(1.5 - np.abs(4.0 * arr - 1.0), 0, 1)
    return (np.stack([r, g, b], axis=-1) * 255).astype(np.uint8)


def _generate_gradcam_overlay(image_path: str, class_idx: int) -> str | None:
    """
    Grad-CAM using the empirically proven backbone-split approach.

    Architecture: outer_model wraps MobileNetV2 (backbone) + head layers.
    Gradient tape cannot trace across nested sub-model boundaries, so we:
      1. Run backbone_conv_model(img) inside tape → conv_acts, backbone_out
      2. tape.watch(conv_acts) immediately after obtaining it
      3. Apply head layers to backbone_out inside tape → predictions
      4. grads = tape.gradient(class_score, conv_acts)  — guaranteed non-None
    """
    try:
        tf = _import_tf()
        backbone_conv_model, head_layers, layer_name = _build_gradcam_model()
        h, w = _get_input_size()

        img_tensor = tf.cast(_preprocess(image_path), tf.float32)

        has_head = len(head_layers) > 0

        with tf.GradientTape(persistent=True) as tape:
            if has_head:
                # backbone_conv_model: img -> [conv_acts, backbone_features]
                conv_acts, backbone_feats = backbone_conv_model(img_tensor, training=False)
                tape.watch(conv_acts)              # watch BEFORE head
                x = backbone_feats
                for lyr in head_layers:
                    x = lyr(x, training=False)     # apply GAP, Dense, etc.
                preds = x
            else:
                # Flat model: backbone_conv_model -> [conv_acts, predictions]
                conv_acts, preds = backbone_conv_model(img_tensor, training=False)
                tape.watch(conv_acts)

            class_score = preds[:, class_idx]

        grads = tape.gradient(class_score, conv_acts)
        del tape

        if grads is None:
            logger.warning(
                "[Midori] Grad-CAM: gradient is None for class %d "
                "(layer '%s' may not be in the compute graph)", class_idx, layer_name
            )
            return None

        # ── Class-weighted spatial average ───────────────────────────────────
        # pooled_grads shape: (C,)  — global average over spatial dims
        pooled_grads = tf.reduce_mean(grads, axis=(0, 1, 2))
        # weighted: (H, W, C) * (C,) → element-wise → sum over channels → (H, W)
        heatmap = tf.reduce_sum(conv_acts[0] * pooled_grads, axis=-1)
        heatmap = tf.nn.relu(heatmap)
        hmax    = tf.reduce_max(heatmap)
        heatmap = (heatmap / hmax) if float(hmax) > 1e-8 else tf.zeros_like(heatmap)
        heatmap_np = heatmap.numpy()  # (H_conv, W_conv) e.g. (7, 7)

        # ── Overlay on original image ─────────────────────────────────────────
        heatmap_img = Image.fromarray(np.uint8(heatmap_np * 255)).resize(
            (w, h), Image.BILINEAR
        )
        heatmap_arr = np.array(heatmap_img, dtype=np.float32) / 255.0
        jet         = _apply_jet_colormap(heatmap_arr)          # (h, w, 3) uint8

        with Image.open(image_path) as orig:
            orig_rgb = np.array(orig.convert("RGB").resize((w, h), Image.BILINEAR),
                                dtype=np.float32)

        overlay = (orig_rgb * 0.55 + jet.astype(np.float32) * 0.45).clip(0, 255)

        rel_path  = f"detections/gradcam/{uuid.uuid4().hex}.png"
        save_path = _gradcam_dir() / Path(rel_path).name
        Image.fromarray(overlay.astype(np.uint8)).save(str(save_path))

        logger.info("[Midori] Grad-CAM saved → %s", save_path)
        return rel_path

    except Exception as exc:
        logger.warning("[Midori] Grad-CAM generation failed: %s", exc, exc_info=True)
        return None


# ── Core inference ────────────────────────────────────────────────────────────
def _infer(image_path: str):
    """
    TTA forward pass + Grad-CAM.

    Returns
    -------
    class_name   : str
    confidence   : float  (0–1, direct softmax probability)
    is_healthy   : bool
    top_k        : list[dict]  top-3 [{class_name, confidence}]
    gradcam_path : str | None
    """
    probs = _infer_tta(image_path)

    class_idx  = int(np.argmax(probs))
    confidence = float(probs[class_idx])

    logger.info("[Midori] Top-1: %s  conf=%.1f%%",
                CLASS_NAMES[class_idx] if class_idx < len(CLASS_NAMES) else "?",
                confidence * 100)

    if class_idx >= len(CLASS_NAMES):
        return None, 0.0, False, [], None

    class_name = CLASS_NAMES[class_idx]
    is_healthy = "healthy" in class_name.lower()

    top_k = [
        {"class_name": CLASS_NAMES[int(i)], "confidence": float(probs[i])}
        for i in np.argsort(probs)[::-1][:3]
        if int(i) < len(CLASS_NAMES)
    ]

    # Grad-CAM uses single-pass preprocessing (required for gradient flow)
    gradcam_path = _generate_gradcam_overlay(image_path, class_idx)

    return class_name, confidence, is_healthy, top_k, gradcam_path


# ── Disease resolver ──────────────────────────────────────────────────────────
def _resolve_disease(class_name: str, plant_id=None):
    from diseases.models import Disease  # noqa: PLC0415
    if plant_id is not None:
        d = Disease.objects.filter(plant_id=plant_id, name=class_name).first()
        if d:
            return d
    return Disease.objects.filter(name=class_name).first()


# ── Public API ────────────────────────────────────────────────────────────────
def run_prediction(image_path: str, plant_id=None):
    """
    Entry point called by views.py.

    Returns
    -------
    disease_id   : int | None
    confidence   : float       (0–1)
    class_name   : str | None
    is_plant     : bool
    is_healthy   : bool
    top_k        : list[dict]
    gradcam_path : str | None
    """
    # Stage 1 — colour pre-filter
    if not _is_likely_plant(image_path):
        logger.info("[Midori] Rejected by green-filter: %s", image_path)
        return None, 0.0, None, False, False, [], None

    # Stage 2 — model inference
    try:
        class_name, confidence, is_healthy, top_k, gradcam_path = _infer(image_path)
    except Exception as exc:
        logger.error("[Midori] _infer failed: %s", exc, exc_info=True)
        return None, 0.0, None, True, False, [], None

    if not class_name:
        return None, 0.0, None, True, False, [], None

    # Stage 3 — not-a-plant confidence floor
    if confidence < NOT_A_PLANT_THRESHOLD:
        logger.info("[Midori] Conf %.2f < %.2f — treated as not a plant",
                    confidence, NOT_A_PLANT_THRESHOLD)
        return None, confidence, class_name, False, False, [], gradcam_path

    # Stage 4 — healthy plant (no DB lookup needed)
    if is_healthy:
        logger.info("[Midori] Healthy: %s (%.1f%%)", class_name, confidence * 100)
        return None, confidence, class_name, True, True, top_k, gradcam_path

    # Stage 5 — disease path
    disease = _resolve_disease(class_name, plant_id)
    if disease is None:
        logger.warning(
            '[Midori] No DB row for "%s" — run seed_model_catalog', class_name
        )
        return None, confidence, class_name, True, False, top_k, gradcam_path

    return disease.id, confidence, class_name, True, False, top_k, gradcam_path


# ── Backward-compat stubs ─────────────────────────────────────────────────────
def generate_gradcam(image_path: str, class_name: str):
    """Deprecated: Grad-CAM is now generated inside run_prediction."""
    return None
