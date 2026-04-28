import logging
from functools import lru_cache
from pathlib import Path

import numpy as np
import tensorflow as tf
from PIL import Image, ImageOps
from tensorflow import keras

logger = logging.getLogger(__name__)

MODEL_PATH = Path(__file__).resolve().parent / 'model' / 'plant_disease_mobilenet.h5'

CLASS_NAMES = (
    'Apple___Apple_scab',
    'Apple___Black_rot',
    'Apple___Cedar_apple_rust',
    'Apple___healthy',
    'Blueberry___healthy',
    'Cherry_(including_sour)___Powdery_mildew',
    'Cherry_(including_sour)___healthy',
    'Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot',
    'Corn_(maize)___Common_rust_',
    'Corn_(maize)___Northern_Leaf_Blight',
    'Corn_(maize)___healthy',
    'Grape___Black_rot',
    'Grape___Esca_(Black_Measles)',
    'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)',
    'Grape___healthy',
    'Orange___Haunglongbing_(Citrus_greening)',
    'Peach___Bacterial_spot',
    'Peach___healthy',
    'Pepper,_bell___Bacterial_spot',
    'Pepper,_bell___healthy',
    'Potato___Early_blight',
    'Potato___Late_blight',
    'Potato___healthy',
    'Raspberry___healthy',
    'Soybean___healthy',
    'Squash___Powdery_mildew',
    'Strawberry___Leaf_scorch',
    'Strawberry___healthy',
    'Tomato___Bacterial_spot',
    'Tomato___Early_blight',
    'Tomato___Late_blight',
    'Tomato___Leaf_Mold',
    'Tomato___Septoria_leaf_spot',
    'Tomato___Spider_mites Two-spotted_spider_mite',
    'Tomato___Target_Spot',
    'Tomato___Tomato_Yellow_Leaf_Curl_Virus',
    'Tomato___Tomato_mosaic_virus',
    'Tomato___healthy',
)

NOT_A_PLANT_THRESHOLD = 0.25   # temperature-scaled floor → "not a plant"
_TEMPERATURE          = 2.5    # softens overconfident softmax


# ── Temperature scaling ───────────────────────────────────────────────────────
def _apply_temperature(probs: np.ndarray) -> np.ndarray:
    log_p  = np.log(np.clip(probs, 1e-10, 1.0))
    scaled = np.exp(log_p / _TEMPERATURE)
    return scaled / scaled.sum()


# ── Green-channel pre-filter ──────────────────────────────────────────────────
def _is_likely_plant(image_path: str) -> bool:
    try:
        with Image.open(image_path) as img:
            rgb = np.array(img.convert('RGB'), dtype=np.int16)
            r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
            ratio = ((g > r) & (g > b)).sum() / (rgb.shape[0] * rgb.shape[1])
            logger.debug('[Midori] green_ratio=%.3f', ratio)
            return ratio >= 0.12
    except Exception as exc:
        logger.warning('[Midori] green-check failed: %s', exc)
        return True   # fail open


# ── Model loading (cached) ────────────────────────────────────────────────────
@lru_cache(maxsize=1)
def _get_model():
    if not MODEL_PATH.exists():
        raise FileNotFoundError(f'[Midori] Model not found at {MODEL_PATH}')
    logger.info('[Midori] Loading MobileNetV2 from %s', MODEL_PATH)
    return keras.models.load_model(str(MODEL_PATH))


@lru_cache(maxsize=1)
def _get_input_size():
    m = _get_model()
    return int(m.input_shape[1]), int(m.input_shape[2])


# ── Preprocessing ─────────────────────────────────────────────────────────────
def _preprocess(image_path: str) -> np.ndarray:
    h, w = _get_input_size()
    img  = keras.utils.load_img(image_path, target_size=(h, w))
    arr  = keras.utils.img_to_array(img)
    return keras.applications.mobilenet_v2.preprocess_input(np.expand_dims(arr, 0))


# ── Grad-CAM sub-models (cached) ──────────────────────────────────────────────
#
#  We split the outer model into two cached sub-models so one forward pass
#  covers BOTH prediction and Grad-CAM — eliminating the double-inference cost.
#
#  feat_extractor : outer.inputs → backbone.output  (7×7×1280)
#  head_model     : Input(7×7×1280) → 38-class logits
#
@lru_cache(maxsize=1)
def _build_gradcam_models():
    outer    = _get_model()
    backbone = next((l for l in outer.layers if isinstance(l, keras.Model)), None)
    if backbone is None:
        raise ValueError('[Midori] No backbone sub-model found')

    # feat_extractor lives inside the outer model's graph
    feat_extractor = keras.Model(inputs=outer.inputs, outputs=backbone.output,
                                 name='feat_extractor')

    # head_model: takes backbone output shape as fresh input
    feat_in = keras.Input(shape=backbone.output.shape[1:], name='feat_in')
    skip    = {backbone.name}
    x       = feat_in
    for layer in outer.layers:
        if layer.name.startswith('input') or layer.name in skip:
            continue
        try:
            x = layer(x, training=False)
        except TypeError:
            x = layer(x)

    head_model = keras.Model(inputs=feat_in, outputs=x, name='head_model')
    logger.info('[Midori] Grad-CAM models ready: feat=%s → head → %s',
                feat_extractor.output.shape, head_model.output.shape)
    return feat_extractor, head_model


# ── Single-pass prediction + Grad-CAM ─────────────────────────────────────────
#
#  ONE forward pass through feat_extractor + head_model gives us:
#    • calibrated class probabilities (for confidence score)
#    • gradients of class score w.r.t. feature map (for Grad-CAM heatmap)
#
def _infer(image_path: str):
    """
    Returns:
        class_name   : str
        confidence   : float   (temperature-scaled, 0-1)
        top_k        : list[{class_name, confidence}]
        gradcam_path : str | None  (saved relative media path)
    """
    feat_extractor, head_model = _build_gradcam_models()
    img_batch = tf.cast(_preprocess(image_path), tf.float32)

    # -- Single forward pass with GradientTape watching the feature map --------
    with tf.GradientTape() as tape:
        features = feat_extractor(img_batch, training=False)   # (1,7,7,1280)
        tape.watch(features)
        preds    = head_model(features, training=False)        # (1,38)

        # determine winning class INSIDE tape so we can differentiate wrt it
        raw_probs  = preds[0].numpy()
        probs      = _apply_temperature(raw_probs)
        class_idx  = int(np.argmax(probs))
        class_score = preds[:, class_idx]

    confidence = float(probs[class_idx])
    if class_idx >= len(CLASS_NAMES):
        return None, 0.0, [], None

    class_name = CLASS_NAMES[class_idx]

    top_k = [
        {'class_name': CLASS_NAMES[int(i)], 'confidence': float(probs[i])}
        for i in np.argsort(probs)[::-1][:3]
        if int(i) < len(CLASS_NAMES)
    ]

    # -- Grad-CAM from the SAME tape (no second forward pass) ------------------
    gradcam_path = None
    try:
        gradients = tape.gradient(class_score, features)
        if gradients is not None:
            pooled   = tf.reduce_mean(gradients, axis=(0, 1, 2)).numpy()  # (C,)
            feat_map = features[0].numpy()                                 # (7,7,C)
            heatmap  = np.maximum(np.mean(feat_map * pooled, axis=-1), 0) # (7,7)
            mx = heatmap.max()
            if mx > 0:
                heatmap = np.uint8(255 * heatmap / mx)
                with Image.open(image_path) as img:
                    orig = img.convert('RGB')
                heat_img = ImageOps.colorize(
                    Image.fromarray(heatmap).resize(orig.size, Image.BILINEAR).convert('L'),
                    black='navy', mid='lime', white='red',
                ).convert('RGB')
                overlay  = Image.blend(orig, heat_img, alpha=0.45)
                out_dir  = (Path(__file__).resolve().parent.parent
                            / 'media' / 'detections' / 'gradcam')
                out_dir.mkdir(parents=True, exist_ok=True)
                stem     = Path(image_path).stem
                out_file = out_dir / f'{stem}_gradcam.jpg'
                overlay.save(str(out_file), format='JPEG', quality=92)
                gradcam_path = f'detections/gradcam/{out_file.name}'
                logger.info('[Midori] Grad-CAM saved → %s', out_file.name)
            else:
                logger.warning('[Midori] Zero heatmap for "%s"', class_name)
        else:
            logger.warning('[Midori] Gradient is None for "%s"', class_name)
    except Exception as exc:
        logger.warning('[Midori] Grad-CAM failed: %s', exc, exc_info=True)

    return class_name, confidence, top_k, gradcam_path


# ── Disease resolver ──────────────────────────────────────────────────────────
def _resolve_disease(class_name: str, plant_id=None):
    from diseases.models import Disease
    if plant_id is not None:
        d = Disease.objects.filter(plant_id=plant_id, name=class_name).first()
        if d:
            return d
    return Disease.objects.filter(name=class_name).first()


# ── Public API ────────────────────────────────────────────────────────────────
def run_prediction(image_path: str, plant_id=None):
    """
    Entry point called by views.py.

    Returns: (disease_id, confidence, class_name, is_plant, top_k, gradcam_path)

    gradcam_path is now included here — views.py no longer needs a separate
    generate_gradcam() call, halving the total inference time.
    """
    if not _is_likely_plant(image_path):
        logger.info('[Midori] Green-check rejected: %s', image_path)
        return None, 0.0, None, False, [], None

    try:
        class_name, confidence, top_k, gradcam_path = _infer(image_path)
    except Exception as exc:
        logger.warning('[Midori] _infer failed: %s', exc, exc_info=True)
        return None, 0.0, None, True, [], None

    if not class_name:
        return None, 0.0, None, True, [], None

    if confidence < NOT_A_PLANT_THRESHOLD:
        logger.info('[Midori] Conf %.2f below threshold — not a plant', confidence)
        return None, confidence, class_name, False, [], None

    disease = _resolve_disease(class_name, plant_id)
    if disease is None:
        logger.warning('[Midori] No DB row for "%s" — run seed_model_catalog', class_name)
        return None, confidence, class_name, True, top_k, gradcam_path

    return disease.id, confidence, class_name, True, top_k, gradcam_path


# Keep for backward-compat (apps.py warm-up)
def generate_gradcam(image_path: str, class_name: str):
    """Deprecated: Grad-CAM is now generated inside run_prediction."""
    return None
