

import logging
import time
import uuid
from functools import lru_cache
from pathlib import Path

import numpy as np
from PIL import Image

logger = logging.getLogger(__name__)






def _import_tf():
    import tensorflow as tf
    return tf


def _import_keras():
    import keras
    return keras


def _import_cv2():
    try:
        import cv2
        return cv2
    except ImportError:
        return None






def _ml_dir() -> Path:
    try:
        from django.conf import settings
        return Path(settings.ML_MODELS_DIR)
    except Exception:
        return Path(__file__).resolve().parent.parent.parent.parent / "14-07-26"


def _model_paths() -> dict:
    d = _ml_dir()
    return {
        "plant":      d / "stage1_plant_identifier_eff.keras",
        "Apple":      d / "Apple_disease.keras",
        "Corn":       d / "Corn_disease.keras",
        "Grape":      d / "Grape_disease.keras",
        "Pepper":     d / "Pepper_disease.keras",
        "Potato":     d / "Potato_disease.keras",
        "Strawberry": d / "Strawberry_disease.keras",
    }


def _gradcam_dir(sub: str) -> Path:
    from django.conf import settings
    d = Path(settings.MEDIA_ROOT) / "detections" / f"gradcam_{sub}"
    d.mkdir(parents=True, exist_ok=True)
    return d






PLANT_CLASSES = ["Apple", "Corn", "Grape", "Others", "Pepper", "Potato", "Strawberry"]

SUPPORTED_PLANTS = {"Apple", "Corn", "Grape", "Pepper", "Potato", "Strawberry"}


DISEASE_CLASSES = {
    "Apple": [
        "Apple___Apple_scab",
        "Apple___Black_rot",
        "Apple___Cedar_apple_rust",
        "Apple___healthy",
    ],
    "Corn": [
        "Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot",
        "Corn_(maize)___Common_rust_",
        "Corn_(maize)___Northern_Leaf_Blight",
        "Corn_(maize)___healthy",
    ],
    "Grape": [
        "Grape___Black_rot",
        "Grape___Esca_(Black_Measles)",
        "Grape___Leaf_blight_(Isariopsis_Leaf_Spot)",
        "Grape___healthy",
    ],
    "Pepper": [
        "Pepper,_bell___Bacterial_spot",
        "Pepper,_bell___healthy",
    ],
    "Potato": [
        "Potato___Early_blight",
        "Potato___Late_blight",
        "Potato___healthy",
    ],
    "Strawberry": [
        "Strawberry___Leaf_scorch",
        "Strawberry___healthy",
    ],
}


DISEASE_DISPLAY = {
    "Apple___Apple_scab":                                      "Apple Scab",
    "Apple___Black_rot":                                       "Black Rot",
    "Apple___Cedar_apple_rust":                                "Cedar Apple Rust",
    "Apple___healthy":                                         "Healthy",
    "Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot":      "Cercospora / Gray Leaf Spot",
    "Corn_(maize)___Common_rust_":                             "Common Rust",
    "Corn_(maize)___Northern_Leaf_Blight":                     "Northern Leaf Blight",
    "Corn_(maize)___healthy":                                  "Healthy",
    "Grape___Black_rot":                                       "Black Rot",
    "Grape___Esca_(Black_Measles)":                            "Esca (Black Measles)",
    "Grape___Leaf_blight_(Isariopsis_Leaf_Spot)":              "Leaf Blight (Isariopsis)",
    "Grape___healthy":                                         "Healthy",
    "Pepper,_bell___Bacterial_spot":                           "Bacterial Spot",
    "Pepper,_bell___healthy":                                  "Healthy",
    "Potato___Early_blight":                                   "Early Blight",
    "Potato___Late_blight":                                    "Late Blight",
    "Potato___healthy":                                        "Healthy",
    "Strawberry___Leaf_scorch":                                "Leaf Scorch",
    "Strawberry___healthy":                                    "Healthy",
}

STAGE1_MODEL_NAME = "EfficientNet"
STAGE2_MODEL_NAME = "MobileNetV2"

TREATMENT_ADVICE = {
    "Apple Scab":                          "Apply fungicides (captan/myclobutanil) at bud-break. Remove infected leaves.",
    "Black Rot":                           "Prune infected wood below cankers. Apply copper-based fungicide.",
    "Cedar Apple Rust":                    "Remove nearby juniper/cedar hosts. Apply mancozeb before infection periods.",
    "Cercospora / Gray Leaf Spot":         "Apply fungicides like strobilurins. Rotate crops and use resistant varieties.",
    "Common Rust":                         "Apply foliar fungicides early. Use rust-resistant corn varieties.",
    "Northern Leaf Blight":                "Apply fungicides at first sign. Practice crop rotation and remove debris.",
    "Esca (Black Measles)":                "Remove infected wood. Apply trunk wound protectants.",
    "Leaf Blight (Isariopsis)":            "Apply copper-based fungicide. Remove infected leaves.",
    "Bacterial Spot":                      "Apply copper-based bactericide. Avoid overhead irrigation. Rotate crops.",
    "Early Blight":                        "Apply chlorothalonil or mancozeb. Rotate crops; avoid wetting foliage.",
    "Late Blight":                         "URGENT - Apply metalaxyl immediately. Destroy infected plants.",
    "Leaf Scorch":                         "Remove infected leaves. Apply fungicides. Ensure good air circulation.",
    "Healthy":                             "No disease detected. Maintain regular watering and fertilisation schedule.",
}


CONFIDENCE_THRESHOLD = 0.55
IMG_SIZE = (224, 224)








def _preprocess_stage1(image_path: str) -> np.ndarray:

    pil_image = Image.open(image_path).convert("RGB")
    img = pil_image.resize((IMG_SIZE[1], IMG_SIZE[0]))
    arr = np.array(img, dtype=np.float32)
    return np.expand_dims(arr, axis=0)


def _preprocess_stage2(image_path: str) -> np.ndarray:

    keras = _import_keras()
    preprocess_input = keras.applications.mobilenet_v2.preprocess_input
    pil_image = Image.open(image_path).convert("RGB")
    img = pil_image.resize((IMG_SIZE[1], IMG_SIZE[0]))
    arr = np.array(img, dtype=np.float32)
    arr = preprocess_input(arr)
    return np.expand_dims(arr, axis=0)






def _safe_load_model(path: str):

    tf = _import_tf()
    keras = _import_keras()

    
    try:
        m = keras.models.load_model(str(path))
        logger.info("  Loaded %s (strategy 1)", path)
        return m
    except Exception as e1:
        logger.debug("  Strategy 1 failed: %s", type(e1).__name__)

    
    try:
        m = keras.models.load_model(str(path), compile=False)
        logger.info("  Loaded %s (strategy 2: compile=False)", path)
        return m
    except Exception as e2:
        logger.debug("  Strategy 2 failed: %s", type(e2).__name__)

    
    _KNOWN_BN_KWARGS = {
        'name', 'trainable', 'dtype', 'axis', 'momentum', 'epsilon',
        'center', 'scale', 'beta_initializer', 'gamma_initializer',
        'moving_mean_initializer', 'moving_variance_initializer',
        'beta_regularizer', 'gamma_regularizer',
        'beta_constraint', 'gamma_constraint', 'synchronized',
    }

    class _PatchedBatchNormalization(tf.keras.layers.BatchNormalization):

        @classmethod
        def from_config(cls, config):
            clean_config = {k: v for k, v in config.items() if k in _KNOWN_BN_KWARGS}
            return cls(**clean_config)

    try:
        custom_objects = {'BatchNormalization': _PatchedBatchNormalization}
        with tf.keras.utils.custom_object_scope(custom_objects):
            m = keras.models.load_model(str(path), compile=False)
        logger.info("  Loaded %s (strategy 3: patched BN)", path)
        return m
    except Exception as e3:
        raise RuntimeError(
            f"All loading strategies failed for {path}.\n"
            f"  S1: {e1}\n  S2: {e2}\n  S3: {e3}"
        )


@lru_cache(maxsize=1)
def _get_plant_model():  
    path = _model_paths()["plant"]
    if not path.exists():
        raise FileNotFoundError(f"Plant model not found at {path}")
    logger.info("Loading EfficientNet Stage-1 from %s", path)
    model = _safe_load_model(str(path))
    assert model is not None, f"Failed to load model from {path}"
    n_out = model.output_shape[-1]  
    logger.info("Plant model ready - %d classes (expected %d)", n_out, len(PLANT_CLASSES))
    if n_out != len(PLANT_CLASSES):
        logger.warning("Stage 1 class count mismatch: model=%d, expected=%d", n_out, len(PLANT_CLASSES))
    return model


@lru_cache(maxsize=6)
def _get_disease_model(plant_name: str):  
    path = _model_paths().get(plant_name)
    if path is None or not path.exists():
        return None
    logger.info("Loading MobileNetV2 %s disease model from %s", plant_name, path)
    model = _safe_load_model(str(path))
    assert model is not None, f"Failed to load model from {path}"
    expected = len(DISEASE_CLASSES.get(plant_name, []))
    if model.output_shape[-1] != expected:  
        logger.warning("%s class mismatch: model=%d, expected=%d", plant_name, model.output_shape[-1], expected)  
    return model






def _find_gradcam_layer(model):

    keras = _import_keras()
    SPATIAL_TYPES = (
        keras.layers.Conv2D,
        keras.layers.DepthwiseConv2D,
        keras.layers.SeparableConv2D,
        keras.layers.Activation,
        keras.layers.ReLU,
        keras.layers.BatchNormalization,
    )
    for layer in reversed(model.layers):
        if not isinstance(layer, SPATIAL_TYPES):
            continue
        try:
            out = layer.output_shape  
            if isinstance(out, list):
                out = out[0]
            if len(out) == 4 and out[1] is not None and out[1] > 1:
                return layer
        except Exception:
            continue
    return None


def _make_heatmap(model, img_array, target_layer, class_index):

    tf = _import_tf()
    keras = _import_keras()

    try:
        grad_model = keras.Model(
            inputs=model.inputs,
            outputs=[target_layer.output, model.output]
        )
    except Exception as e:
        logger.debug("Grad-CAM grad_model build failed: %s", e)
        return None

    img_tensor = tf.cast(img_array, tf.float32)

    with tf.GradientTape() as tape:
        tape.watch(img_tensor)
        conv_out, preds = grad_model(img_tensor, training=False)
        tape.watch(conv_out)
        score = preds[:, class_index]

    grads = tape.gradient(score, conv_out)
    if grads is None:
        return None

    pooled = tf.reduce_mean(grads, axis=(0, 1, 2)).numpy()
    feat   = conv_out[0].numpy()

    cam = np.dot(feat, pooled)

    
    cam_relu = np.maximum(cam, 0)
    amax = cam_relu.max()
    if amax > 1e-8:
        return (cam_relu / amax).astype(np.float32)

    
    cmin, cmax = cam.min(), cam.max()
    if cmax - cmin > 1e-8:
        return ((cam - cmin) / (cmax - cmin)).astype(np.float32)

    
    return np.full(cam.shape, 0.5, dtype=np.float32)


def _generate_gradcam_overlay(model, processed_arr, pil_image):

    tf = _import_tf()
    cv2 = _import_cv2()

    orig_rgb = np.array(pil_image.convert('RGB'))
    orig_h, orig_w = orig_rgb.shape[:2]

    
    target_layer = _find_gradcam_layer(model)

    
    cam = None
    if target_layer is not None:
        try:
            preds_raw = model(tf.cast(processed_arr, tf.float32), training=False)
            top_class = int(tf.argmax(preds_raw[0]).numpy())
            cam = _make_heatmap(model, processed_arr, target_layer, top_class)
        except Exception as e:
            logger.debug("Grad-CAM heatmap failed: %s", e)
            cam = None

    
    if cam is None and cv2 is not None:
        gray  = cv2.cvtColor(orig_rgb, cv2.COLOR_RGB2GRAY)
        edges = cv2.Canny(gray, 50, 150).astype(np.float32)
        edges = cv2.GaussianBlur(edges, (21, 21), 0)
        amax  = edges.max()
        cam   = (edges / amax) if amax > 0 else np.full((orig_h, orig_w), 0.5, dtype=np.float32)

    if cam is None:
        return None

    
    if cv2 is not None:
        cam_resized = cv2.resize(cam, (orig_w, orig_h), interpolation=cv2.INTER_LINEAR)
    else:
        cam_resized = np.array(Image.fromarray(np.uint8(255 * cam)).resize((orig_w, orig_h))) / 255.0

    
    cam_u8 = np.uint8(255 * np.clip(cam_resized, 0, 1))

    try:
        import matplotlib
        jet_lut = matplotlib.colormaps['jet'](np.arange(256))[:, :3]
    except ImportError:
        x = np.linspace(0, 1, 256)
        r = np.clip(1.5 - np.abs(4.0 * x - 3.0), 0, 1)
        g = np.clip(1.5 - np.abs(4.0 * x - 2.0), 0, 1)
        b = np.clip(1.5 - np.abs(4.0 * x - 1.0), 0, 1)
        jet_lut = np.stack([r, g, b], axis=-1)

    jet_heatmap = np.uint8(jet_lut[cam_u8] * 255)

    
    if cv2 is not None:
        overlay = cv2.addWeighted(orig_rgb, 0.55, jet_heatmap, 0.45, 0)
    else:
        overlay = np.uint8(orig_rgb * 0.55 + jet_heatmap * 0.45)

    return overlay


def _save_gradcam(overlay, sub="disease"):

    try:
        filename = f"{uuid.uuid4().hex}.png"
        save_path = _gradcam_dir(sub) / filename
        Image.fromarray(overlay).save(str(save_path))
        return f"detections/gradcam_{sub}/{filename}"
    except Exception as exc:
        logger.warning("Grad-CAM save failed: %s", exc)
        return None






def identify_plant(image_path):

    model = _get_plant_model()

    t0 = time.perf_counter()
    processed_arr = _preprocess_stage1(image_path)
    preds = model(processed_arr, training=False)
    if hasattr(preds, 'numpy'):
        preds = preds.numpy()[0]
    else:
        preds = np.array(preds)[0]
    latency = (time.perf_counter() - t0) * 1000.0

    top_idx    = int(np.argmax(preds))
    confidence = float(preds[top_idx])
    all_probs  = dict(zip(PLANT_CLASSES, preds.tolist()))

    
    if confidence < CONFIDENCE_THRESHOLD or PLANT_CLASSES[top_idx] == "Others":
        plant_name = "Unknown Plant"
    else:
        plant_name = PLANT_CLASSES[top_idx]

    logger.info("Stage 1: %s (%.1f%%) [%.0fms]", plant_name, confidence * 100, latency)

    
    plant_scores = [(PLANT_CLASSES[i], float(preds[i]) * 100.0) for i in range(len(PLANT_CLASSES))]

    
    gradcam = None
    try:
        pil_img = Image.open(image_path).convert("RGB")
        overlay = _generate_gradcam_overlay(model, processed_arr, pil_img)
        if overlay is not None:
            gradcam = _save_gradcam(overlay, sub="plant")
    except Exception:
        pass

    return plant_name, confidence, plant_scores, gradcam, latency






def detect_disease(image_path, plant_name):

    disease_classes = DISEASE_CLASSES.get(plant_name)
    model = _get_disease_model(plant_name)

    if model is None or disease_classes is None:
        return None, None, 0.0, [], "No disease model available.", None, False, 0.0

    t0 = time.perf_counter()
    processed_arr = _preprocess_stage2(image_path)
    preds = model(processed_arr, training=False)
    if hasattr(preds, 'numpy'):
        preds = preds.numpy()[0]
    else:
        preds = np.array(preds)[0]
    latency = (time.perf_counter() - t0) * 1000.0

    top_idx    = int(np.argmax(preds))
    confidence = float(preds[top_idx])

    
    if disease_classes and top_idx < len(disease_classes):
        raw_label     = disease_classes[top_idx]
        display_label = DISEASE_DISPLAY.get(raw_label, raw_label.split("___")[-1].replace("_", " "))
    else:
        raw_label     = f"Class {top_idx}"
        display_label = raw_label

    advice = TREATMENT_ADVICE.get(display_label, "Consult a local agronomist.")

    
    scores = [
        (DISEASE_DISPLAY.get(disease_classes[i], disease_classes[i]), float(preds[i]) * 100.0)
        for i in range(len(disease_classes))
    ]

    logger.info("Stage 2: %s (%.1f%%) [%.0fms]", display_label, confidence * 100, latency)

    
    gradcam = None
    if display_label and "healthy" not in display_label.lower():
        try:
            pil_img = Image.open(image_path).convert("RGB")
            overlay = _generate_gradcam_overlay(model, processed_arr, pil_img)
            if overlay is not None:
                gradcam = _save_gradcam(overlay, sub="disease")
        except Exception:
            pass

    return display_label, raw_label, confidence, scores, advice, gradcam, True, latency






def run_prediction(image_path, plant_override=None, confidence_threshold=None):

    t0 = time.perf_counter()
    preprocess_ms = (time.perf_counter() - t0) * 1000.0

    stage1_ms = 0.0
    stage2_ms = 0.0

    
    if plant_override:
        plant_name = plant_override.strip().title()
        plant_conf = 1.0  
        plant_scores = [(plant_name, 100.0)]
        plant_gradcam = None
    else:
        try:
            plant_name, plant_conf, plant_scores, plant_gradcam, stage1_ms =                identify_plant(image_path)
        except Exception as exc:
            logger.error("Stage 1 failed: %s", exc)
            return _result(status="failed", message="Plant identification failed.",
                           preprocessing_latency_ms=preprocess_ms)

        
        if plant_name == "Unknown Plant":
            return _result(
                plant_name=plant_name, plant_confidence=plant_conf * 100.0,
                plant_scores=plant_scores, plant_gradcam_path=plant_gradcam,
                status="not_recognized",
                message="This doesn't appear to be a recognized plant. "
                        "Supported: Apple, Corn, Grape, Pepper, Potato, Strawberry.",
                stage1_latency_ms=stage1_ms, preprocessing_latency_ms=preprocess_ms,
            )

    if plant_name not in SUPPORTED_PLANTS:
        return _result(
            plant_name=plant_name, plant_confidence=plant_conf * 100.0,
            plant_scores=plant_scores, plant_gradcam_path=plant_gradcam,
            status="no_model",
            message=f"{plant_name} identified, but no disease model is available.",
            stage1_latency_ms=stage1_ms, preprocessing_latency_ms=preprocess_ms,
        )

    
    try:
        display_label, raw_label, disease_conf, disease_scores, advice,            disease_gradcam, has_model, stage2_ms =            detect_disease(image_path, plant_name)
    except Exception as exc:
        logger.error("Stage 2 failed: %s", exc)
        return _result(
            plant_name=plant_name, plant_confidence=plant_conf * 100.0,
            plant_scores=plant_scores, plant_gradcam_path=plant_gradcam,
            status="failed", message="Disease detection failed.",
            stage1_latency_ms=stage1_ms, preprocessing_latency_ms=preprocess_ms,
        )

    if not has_model:
        return _result(
            plant_name=plant_name, plant_confidence=plant_conf * 100.0,
            plant_scores=plant_scores, plant_gradcam_path=plant_gradcam,
            status="no_model", message=f"No disease model available for {plant_name}.",
            stage1_latency_ms=stage1_ms, preprocessing_latency_ms=preprocess_ms,
        )

    is_healthy = display_label is not None and "healthy" in display_label.lower()

    
    
    if not is_healthy and disease_conf < CONFIDENCE_THRESHOLD:
        return _result(
            plant_name=plant_name, plant_confidence=plant_conf * 100.0,
            plant_scores=plant_scores, plant_gradcam_path=plant_gradcam,
            disease_name=display_label, disease_confidence=disease_conf * 100.0,
            disease_scores=disease_scores, advice=advice,
            disease_gradcam_path=disease_gradcam,
            status="low_confidence",
            message="Disease detection confidence is too low. Retake photo in better lighting.",
            stage1_latency_ms=stage1_ms, stage2_latency_ms=stage2_ms,
            preprocessing_latency_ms=preprocess_ms,
        )

    status = "healthy" if is_healthy else "success"
    message = "Your plant looks healthy! No disease detected." if is_healthy else ""

    return _result(
        plant_name=plant_name, plant_confidence=plant_conf * 100.0,
        plant_scores=plant_scores, plant_gradcam_path=plant_gradcam,
        disease_name=display_label, disease_confidence=disease_conf * 100.0,
        disease_scores=disease_scores, advice=advice,
        is_healthy=is_healthy, disease_gradcam_path=disease_gradcam,
        status=status, message=message,
        stage1_latency_ms=stage1_ms, stage2_latency_ms=stage2_ms,
        preprocessing_latency_ms=preprocess_ms,
    )


def _result(
    plant_name=None, plant_confidence=0.0, plant_scores=None, plant_gradcam_path=None,
    disease_name=None, disease_confidence=0.0, disease_scores=None,
    advice="", is_healthy=False, disease_gradcam_path=None,
    status="failed", message="",
    stage1_latency_ms=0.0, stage2_latency_ms=0.0, preprocessing_latency_ms=0.0,
):
    total = stage1_latency_ms + stage2_latency_ms + preprocessing_latency_ms
    return {
        "plant_name": plant_name,
        "plant_confidence": plant_confidence,
        "plant_scores": plant_scores or [],
        "plant_gradcam_path": plant_gradcam_path,
        "disease_name": disease_name,
        "disease_confidence": disease_confidence,
        "disease_scores": disease_scores or [],
        "advice": advice,
        "is_healthy": is_healthy,
        "disease_gradcam_path": disease_gradcam_path,
        "status": status,
        "message": message,
        "stage1_model": STAGE1_MODEL_NAME,
        "stage2_model": STAGE2_MODEL_NAME,
        "stage1_latency_ms": round(stage1_latency_ms, 1),
        "stage2_latency_ms": round(stage2_latency_ms, 1),
        "preprocessing_latency_ms": round(preprocessing_latency_ms, 1),
        "total_latency_ms": round(total, 1),
    }






def warm_up_models():

    logger.info("Warming up models...")
    _get_plant_model()
    for plant in DISEASE_CLASSES:
        _get_disease_model(plant)
    logger.info("All models loaded.")
