"""
Midori ML inference engine.

Pipeline
--------
1. Green-channel pre-filter (fast, no TF needed):
   Rejects images with < GREEN_RATIO_THRESHOLD green pixels.

2. Forward pass (MobileNetV2, 38 PlantVillage classes):
   Temperature-scaled softmax → top-1 class + confidence.

3. Not-a-plant check:
   If max confidence < NOT_A_PLANT_THRESHOLD the model itself is
   uncertain → return is_plant=False.

4. Healthy vs diseased:
   PlantVillage class names contain '___healthy' for healthy plants.
   If the predicted class contains 'healthy' → return is_healthy=True,
   no disease DB lookup needed.

5. Grad-CAM overlay:
   GradientTape watches the last conv feature-map inside the MobileNetV2
   backbone, computes class-weighted spatial attention, overlays jet
   colormap on the original image and saves a PNG to media/detections/gradcam/.
"""

import logging
import os
import uuid
from functools import lru_cache
from pathlib import Path

import numpy as np
from PIL import Image

logger = logging.getLogger(__name__)

# ── Lazy TF/Keras imports ─────────────────────────────────────────────────────
#  Imported lazily so Django management commands (migrate, seed_model_catalog)
#  can run in environments that do not have TensorFlow installed.
def _import_tf():
    os.environ.setdefault("TF_USE_LEGACY_KERAS", "1")
    import tensorflow as tf  # noqa: PLC0415
    return tf


def _import_keras():
    os.environ.setdefault("TF_USE_LEGACY_KERAS", "1")
    try:
        import tf_keras as keras  # noqa: PLC0415
    except ImportError:
        from tensorflow import keras  # noqa: PLC0415
    return keras


# ── Paths ─────────────────────────────────────────────────────────────────────
# The model lives at the backend root (same level as manage.py).
MODEL_PATH = Path(__file__).resolve().parent.parent / 'plant_disease_mobilenet.h5'

# Grad-CAM overlays are stored under MEDIA_ROOT so Django can serve them.
# We resolve the actual path from Django settings at runtime.
def _gradcam_dir() -> Path:
    from django.conf import settings  # noqa: PLC0415
    d = Path(settings.MEDIA_ROOT) / 'detections' / 'gradcam'
    d.mkdir(parents=True, exist_ok=True)
    return d


# ── Class catalogue ─────────────────────────────────────────────────────────────
# These MUST match EXACTLY what image_dataset_from_directory produced from the
# training folder (alphabetically sorted subfolder names).
# Source: C:/Users/arsenic/Coding/model/dataset/Train  (verified 2026-04-29)
CLASS_NAMES: tuple[str, ...] = (
    'Apple_Apple_scab',                            #  0
    'Apple_Black_rot',                             #  1
    'Apple_Cedar_apple_rust',                      #  2
    'Apple_healthy',                               #  3
    'Cherry_healthy',                              #  4
    'Cherry_mildew',                               #  5
    'Corn_Blight',                                 #  6
    'Corn_Cercospora_leaf_spot Gray_leaf_spot',    #  7
    'Corn_Common_rust',                            #  8
    'Corn_healthy',                                #  9
    'Grape_Black_rot',                             # 10
    'Grape_Esca_(Black_Measles)',                  # 11
    'Grape_Leaf_blight_(Isariopsis_Leaf_Spot)',    # 12
    'Grape_healthy',                               # 13
    'Peach_Bacterial_spot',                        # 14
    'Peach_healthy',                               # 15
    'Pepper_bell_Bacterial_spot',                  # 16
    'Pepper_bell_healthy',                         # 17
    'Potato_Early_blight',                         # 18
    'Potato_Late_blight',                          # 19
    'Potato_healthy',                              # 20
    'Rice_Bacterialblight',                        # 21
    'Rice_Blast',                                  # 22
    'Rice_Brownspot',                              # 23
    'Rice_Healthy',                                # 24
    'Rice_Tungro',                                 # 25
    'Strawberry_Leaf_scorch',                      # 26
    'Strawberry_healthy',                          # 27
    'Tomato_Bacterial_spot',                       # 28
    'Tomato_Early_blight',                         # 29
    'Tomato_Late_blight',                          # 30
    'Tomato_Leaf_Mold',                            # 31
    'Tomato_Septoria_leaf_spot',                   # 32
    'Tomato_Spider_mites Two-spotted_spider_mite', # 33
    'Tomato_Target_Spot',                          # 34
    'Tomato_Tomato_Yellow_Leaf_Curl_Virus',        # 35
    'Tomato_Tomato_mosaic_virus',                  # 36
    'Tomato_healthy',                              # 37
)

# ── Thresholds ────────────────────────────────────────────────────────────────
# Keep in sync with constants.py
#
# IMPORTANT: NOT_A_PLANT_THRESHOLD must be interpreted against the model's raw
# softmax output (probabilities that already sum to 1.0 across 38 classes).
# Random-chance for 38 classes = 1/38 ≈ 2.6 %.  We use 10 % as a comfortable
# floor — anything below this is essentially random noise.
NOT_A_PLANT_THRESHOLD  = 0.10   # max softmax prob < this → not a plant

# Green filter: fraction of pixels where green channel > red AND green > blue.
# 0.5 % is intentionally very low — diseased/yellowed/brown leaves have far
# fewer "pure green" pixels.  This filter is only meant to reject obviously
# non-plant images (skin, sky, solid-colour objects …).
_GREEN_RATIO_THRESHOLD = 0.005  # 0.5 % of pixels must be "greenish"


# ── Temperature scaling (DISABLED — model already outputs probabilities) ────────
# The MobileNetV2 model uses softmax as its final activation, so model() already
# returns a proper probability distribution (sums to 1.0).  Applying a softmax
# again would severely deflate confidence scores (e.g. 85% → 7%), causing every
# real leaf to be misclassified as "not a plant".
#
# If you later switch to a logit-output model (no final softmax), re-enable this.
def _apply_temperature(probs: np.ndarray) -> np.ndarray:
    """No-op passthrough — kept for API compatibility."""
    return probs  # model output is already a probability distribution


# ── Stage 1: green-channel pre-filter ────────────────────────────────────────
def _is_likely_plant(image_path: str) -> bool:
    """
    Fast colour heuristic: does the image contain enough green pixels?

    Uses a very low threshold (2 %) so diseased/yellowed/brown leaves
    still pass — the ML model makes the final call.  This filter only
    rejects obviously non-plant images (sky, skin, solid-colour cards …).
    """
    try:
        with Image.open(image_path) as img:
            rgb = np.array(img.convert('RGB'), dtype=np.int16)
            r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
            ratio = ((g > r) & (g > b)).sum() / (rgb.shape[0] * rgb.shape[1])
            logger.info('[Midori] Green ratio: %.1f%% (threshold: %.1f%%)',
                        ratio * 100, _GREEN_RATIO_THRESHOLD * 100)
            if ratio < _GREEN_RATIO_THRESHOLD:
                logger.warning('[Midori] Image rejected by green-filter: %.1f%%', ratio * 100)
                return False
            return True
    except Exception as exc:
        logger.warning('[Midori] green-check failed (%s) — letting model decide', exc)
        return True   # fail open


# ── Model loading (singleton, cached) ─────────────────────────────────────────
@lru_cache(maxsize=1)
def _get_model():
    keras = _import_keras()
    if not MODEL_PATH.exists():
        raise FileNotFoundError(f'[Midori] Model not found at {MODEL_PATH}')
    logger.info('[Midori] Loading MobileNetV2 from %s', MODEL_PATH)
    model = keras.models.load_model(str(MODEL_PATH))
    logger.info('[Midori] Model loaded. Input shape: %s', model.input_shape)
    return model


@lru_cache(maxsize=1)
def _get_input_size() -> tuple[int, int]:
    m = _get_model()
    return int(m.input_shape[1]), int(m.input_shape[2])


# ── Grad-CAM helpers (cached once) ────────────────────────────────────────────
@lru_cache(maxsize=1)
def _get_gradcam_layer_name() -> str:
    """
    Walk the MobileNetV2 backbone and find the last 4-D convolutional layer.
    Returns the layer name inside the *outer* model that produces the activation
    we will differentiate through.
    """
    keras = _import_keras()
    outer = _get_model()

    # The outer model wraps a MobileNetV2 sub-model + Dense head.
    # We look inside the sub-model for the last spatial (4-D) layer.
    backbone = None
    for layer in outer.layers:
        if isinstance(layer, keras.Model) and 'mobilenet' in layer.name.lower():
            backbone = layer
            break

    if backbone is None:
        # Flat model — search outer layers directly
        for layer in reversed(outer.layers):
            if len(layer.output_shape) == 4:
                logger.info('[Midori] Grad-CAM layer (flat): %s  shape=%s',
                            layer.name, layer.output_shape)
                return layer.name
        raise ValueError('[Midori] Cannot find a spatial conv layer for Grad-CAM')

    for layer in reversed(backbone.layers):
        if len(layer.output_shape) == 4:
            logger.info('[Midori] Grad-CAM layer (backbone): %s  shape=%s',
                        layer.name, layer.output_shape)
            return layer.name

    raise ValueError('[Midori] Cannot find a spatial conv layer inside backbone for Grad-CAM')


@lru_cache(maxsize=1)
def _build_gradcam_model():
    """
    Return (outer_model, backbone_or_None, target_layer_name).

    We keep this simple: just return the pre-loaded outer model and the
    name of the target conv layer. The actual gradient computation is done
    inside _generate_gradcam_overlay using tf.GradientTape on a per-call
    basis with a backbone sub-model built on the fly (cheap — no weight copy).
    """
    outer      = _get_model()
    layer_name = _get_gradcam_layer_name()
    keras      = _import_keras()

    # Find backbone sub-model
    backbone = None
    for layer in outer.layers:
        if isinstance(layer, keras.Model) and 'mobilenet' in layer.name.lower():
            backbone = layer
            break

    logger.info('[Midori] Grad-CAM config: layer=%s backbone=%s',
                layer_name, backbone.name if backbone else 'N/A')
    return outer, backbone, layer_name


@lru_cache(maxsize=1)
def _build_gradcam_models():
    """Kept for apps.py warm-up compatibility."""
    return _build_gradcam_model()


# ── Preprocessing ─────────────────────────────────────────────────────────────
def _preprocess(image_path: str) -> np.ndarray:
    keras = _import_keras()
    h, w = _get_input_size()
    img = keras.utils.load_img(image_path, target_size=(h, w))
    arr = keras.utils.img_to_array(img)
    return keras.applications.mobilenet_v2.preprocess_input(np.expand_dims(arr, 0))


# ── Grad-CAM overlay generation ───────────────────────────────────────────────
def _generate_gradcam_overlay(image_path: str, class_idx: int) -> str | None:
    """
    Compute a Grad-CAM heatmap for *class_idx* and save a colour overlay PNG.

    Returns the relative path inside MEDIA_ROOT  (e.g.
    'detections/gradcam/<uuid>.png')  or None on any failure.

    Approach
    --------
    We build a tiny Keras functional model that outputs:
        [last_conv_activations,  final_predictions]
    both derived from the *backbone* sub-model (which has its own input tensor).
    We then run it inside tf.GradientTape, watching the conv activations tensor,
    and differentiate the class score w.r.t. those activations.

    This avoids the 'graph disconnected' error from trying to span the outer
    model boundary.
    """
    try:
        tf    = _import_tf()
        keras = _import_keras()
        outer, backbone, layer_name = _build_gradcam_model()
        h, w = _get_input_size()

        img_array = tf.cast(_preprocess(image_path), tf.float32)

        if backbone is not None:
            # ── Strategy: build a unified model from BACKBONE inputs ──────────
            # backbone_input → (conv_activations, full_predictions_via_outer_head)
            #
            # The backbone's output goes through GlobalAveragePooling2D + Dense
            # inside the outer model.  We replay that by calling those head layers
            # symbolically using the backbone's OWN symbolic output.
            conv_output     = backbone.get_layer(layer_name).output  # symbolic (7,7,1280)

            # Find head layers in outer that come after backbone
            backbone_idx = next(i for i, l in enumerate(outer.layers) if l is backbone)
            # Feed backbone's actual output through the remaining outer layers
            head_out = conv_output
            for lyr in outer.layers[backbone_idx + 1:]:
                head_out = lyr(head_out)

            # Single functional model: backbone_input → (conv_acts, predictions)
            grad_model = keras.Model(
                inputs  = backbone.inputs,
                outputs = [conv_output, head_out],
            )

            with tf.GradientTape() as tape:
                conv_acts, preds = grad_model(img_array, training=False)
                tape.watch(conv_acts)
                class_score = preds[:, class_idx]

            grads = tape.gradient(class_score, conv_acts)

        else:
            # Flat model — can build directly
            grad_model = keras.Model(
                inputs  = outer.inputs,
                outputs = [outer.get_layer(layer_name).output, outer.output],
            )
            with tf.GradientTape() as tape:
                conv_acts, preds = grad_model(img_array, training=False)
                tape.watch(conv_acts)
                class_score = preds[:, class_idx]
            grads = tape.gradient(class_score, conv_acts)

        if grads is None:
            logger.warning('[Midori] Grad-CAM: gradient is None for class %d '
                           '(model may not be differentiable at this layer)', class_idx)
            return None

        # ── Compute class-weighted heatmap ─────────────────────────────────────
        pooled   = tf.reduce_mean(grads, axis=(0, 1, 2))       # (C,)
        weighted = conv_acts[0] * pooled                        # (7, 7, C)
        heatmap  = tf.reduce_sum(weighted, axis=-1)             # (7, 7)
        heatmap  = tf.nn.relu(heatmap)
        hmax     = tf.reduce_max(heatmap)
        heatmap  = (heatmap / hmax) if float(hmax) > 0 else tf.zeros_like(heatmap)
        heatmap_np = heatmap.numpy()

        # ── Overlay on original image ──────────────────────────────────────────
        heatmap_img = Image.fromarray(np.uint8(heatmap_np * 255)).resize(
            (w, h), Image.BILINEAR,
        )
        heatmap_arr = np.array(heatmap_img, dtype=np.float32) / 255.0
        jet_heatmap = _apply_jet_colormap(heatmap_arr)         # (h, w, 3)

        with Image.open(image_path) as orig:
            orig_rgb = orig.convert('RGB').resize((w, h), Image.BILINEAR)
        orig_arr = np.array(orig_rgb, dtype=np.float32)

        overlay     = (orig_arr * 0.55 + jet_heatmap.astype(np.float32) * 0.45).clip(0, 255)
        overlay_img = Image.fromarray(overlay.astype(np.uint8))

        rel_path  = f'detections/gradcam/{uuid.uuid4().hex}.png'
        save_path = Path(_gradcam_dir()) / Path(rel_path).name
        overlay_img.save(str(save_path))

        logger.info('[Midori] Grad-CAM saved → %s', save_path)
        return rel_path

    except Exception as exc:
        logger.warning('[Midori] Grad-CAM generation failed: %s', exc, exc_info=True)
        return None


def _apply_jet_colormap(arr: np.ndarray) -> np.ndarray:
    """
    Pure-NumPy implementation of the 'jet' colourmap.
    Maps a (H, W) float array in [0, 1] to (H, W, 3) uint8 RGB.
    """
    r = np.clip(1.5 - np.abs(4.0 * arr - 3.0), 0, 1)
    g = np.clip(1.5 - np.abs(4.0 * arr - 2.0), 0, 1)
    b = np.clip(1.5 - np.abs(4.0 * arr - 1.0), 0, 1)
    jet = np.stack([r, g, b], axis=-1)
    return (jet * 255).astype(np.uint8)


# ── Main inference ────────────────────────────────────────────────────────────
def _infer(image_path: str):
    """
    Single forward pass.

    Returns
    -------
    class_name   : str
    confidence   : float  (0–1, temperature-scaled)
    is_healthy   : bool   (True when class contains 'healthy')
    top_k        : list[dict]  [{class_name, confidence}, …]  top-3
    gradcam_path : str | None  relative media path
    """
    tf = _import_tf()
    model = _get_model()

    img_batch = tf.cast(_preprocess(image_path), tf.float32)
    preds = model(img_batch, training=False)  # (1, 38) — already softmax probabilities
    probs = preds[0].numpy()                  # DO NOT re-apply softmax (model has softmax layer)

    class_idx = int(np.argmax(probs))
    confidence = float(probs[class_idx])
    logger.info('[Midori] Top-1: %s  conf=%.1f%%',
                CLASS_NAMES[class_idx] if class_idx < len(CLASS_NAMES) else '?',
                confidence * 100)

    if class_idx >= len(CLASS_NAMES):
        return None, 0.0, False, [], None

    class_name = CLASS_NAMES[class_idx]
    is_healthy = 'healthy' in class_name.lower()

    top_k = [
        {'class_name': CLASS_NAMES[int(i)], 'confidence': float(probs[i])}
        for i in np.argsort(probs)[::-1][:3]
        if int(i) < len(CLASS_NAMES)
    ]

    # Generate Grad-CAM overlay for this prediction
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
    confidence   : float
    class_name   : str | None
    is_plant     : bool
    is_healthy   : bool
    top_k        : list[dict]
    gradcam_path : str | None
    """
    # ── Stage 1: colour pre-filter ────────────────────────────────────────────
    if not _is_likely_plant(image_path):
        logger.info('[Midori] Rejected by green-filter: %s', image_path)
        return None, 0.0, None, False, False, [], None

    # ── Stage 2: model inference ──────────────────────────────────────────────
    try:
        class_name, confidence, is_healthy, top_k, gradcam_path = _infer(image_path)
    except Exception as exc:
        logger.error('[Midori] _infer failed: %s', exc, exc_info=True)
        return None, 0.0, None, True, False, [], None

    if not class_name:
        return None, 0.0, None, True, False, [], None

    # ── Stage 3: not-a-plant confidence floor ────────────────────────────────
    if confidence < NOT_A_PLANT_THRESHOLD:
        logger.info('[Midori] Conf %.2f < %.2f — treated as not a plant',
                    confidence, NOT_A_PLANT_THRESHOLD)
        return None, confidence, class_name, False, False, [], gradcam_path

    # ── Stage 4: healthy path (no disease DB lookup needed) ───────────────────
    if is_healthy:
        logger.info('[Midori] Healthy plant detected: %s (%.1f%%)',
                    class_name, confidence * 100)
        return None, confidence, class_name, True, True, top_k, gradcam_path

    # ── Stage 5: disease path ─────────────────────────────────────────────────
    disease = _resolve_disease(class_name, plant_id)
    if disease is None:
        logger.warning('[Midori] No DB row for "%s" — run seed_model_catalog', class_name)
        return None, confidence, class_name, True, False, top_k, gradcam_path

    return disease.id, confidence, class_name, True, False, top_k, gradcam_path


# ── Backward-compat stub ──────────────────────────────────────────────────────
def generate_gradcam(image_path: str, class_name: str):
    """Deprecated: Grad-CAM is now generated inside run_prediction."""
    return None
