"""
Full end-to-end Grad-CAM test using the new backbone-split approach.
cd server && venv\Scripts\python.exe scripts\test_gradcam_final.py
"""
import os, sys
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"
os.environ["TF_USE_LEGACY_KERAS"] = "1"
os.environ["DJANGO_SETTINGS_MODULE"] = "config.settings.development"
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import numpy as np
from pathlib import Path
from PIL import Image
import tensorflow as tf
import uuid

keras = tf.keras
print(f"TF: {tf.__version__}")

MODEL_PATH = Path(__file__).parent.parent / "plant_disease_mobilenet.h5"
model = keras.models.load_model(str(MODEL_PATH))
print(f"Model input: {model.input_shape}  output: {model.output_shape}")

CLASS_NAMES = (
    "Apple_Apple_scab","Apple_Black_rot","Apple_Cedar_apple_rust","Apple_healthy",
    "Cherry_healthy","Cherry_mildew","Corn_Blight","Corn_Cercospora_leaf_spot Gray_leaf_spot",
    "Corn_Common_rust","Corn_healthy","Grape_Black_rot","Grape_Esca_(Black_Measles)",
    "Grape_Leaf_blight_(Isariopsis_Leaf_Spot)","Grape_healthy","Peach_Bacterial_spot",
    "Peach_healthy","Pepper_bell_Bacterial_spot","Pepper_bell_healthy","Potato_Early_blight",
    "Potato_Late_blight","Potato_healthy","Rice_Bacterialblight","Rice_Blast","Rice_Brownspot",
    "Rice_Healthy","Rice_Tungro","Strawberry_Leaf_scorch","Strawberry_healthy",
    "Tomato_Bacterial_spot","Tomato_Early_blight","Tomato_Late_blight","Tomato_Leaf_Mold",
    "Tomato_Septoria_leaf_spot","Tomato_Spider_mites Two-spotted_spider_mite",
    "Tomato_Target_Spot","Tomato_Tomato_Yellow_Leaf_Curl_Virus","Tomato_Tomato_mosaic_virus",
    "Tomato_healthy",
)

# ── Build backbone_conv_model + head_layers ─────────────────────────────────
backbone = None
for lyr in model.layers:
    if hasattr(lyr, "layers") and len(lyr.layers) > 3:
        backbone = lyr
        break

last_conv = None
for lyr in backbone.layers:
    try:
        shape = lyr.output_shape
        if isinstance(shape, (list, tuple)) and len(shape) == 4:
            last_conv = lyr
    except Exception:
        pass

print(f"Backbone: {backbone.name}")
print(f"Last conv: {last_conv.name}  shape={last_conv.output_shape}")

backbone_conv_model = keras.Model(
    inputs=backbone.inputs,
    outputs=[last_conv.output, backbone.output],
)

head_layers = []
after_backbone = False
for lyr in model.layers:
    if lyr is backbone:
        after_backbone = True
        continue
    if after_backbone and not isinstance(lyr, keras.layers.InputLayer):
        head_layers.append(lyr)

print(f"Head layers: {[l.name for l in head_layers]}")

# ── Make a synthetic green leaf image ─────────────────────────────────────────
arr = np.zeros((224, 224, 3), dtype=np.uint8)
arr[:, :, 1] = 140; arr[:, :, 0] = 60; arr[:, :, 2] = 40
tmp = Path(__file__).parent / "_test_leaf.jpg"
Image.fromarray(arr).save(str(tmp))

preprocessed = keras.applications.mobilenet_v2.preprocess_input(
    np.expand_dims(np.array(Image.fromarray(arr), dtype=np.float32), 0)
)
img_tensor = tf.cast(preprocessed, tf.float32)

# ── Run Grad-CAM ──────────────────────────────────────────────────────────────
print("\n--- Running Grad-CAM ---")
with tf.GradientTape(persistent=True) as tape:
    conv_acts, backbone_feats = backbone_conv_model(img_tensor, training=False)
    tape.watch(conv_acts)
    x = backbone_feats
    for lyr in head_layers:
        x = lyr(x, training=False)
    preds = x
    class_idx = int(tf.argmax(preds[0]))
    class_score = preds[:, class_idx]

grads = tape.gradient(class_score, conv_acts)
del tape

print(f"conv_acts shape : {conv_acts.shape}")
print(f"preds shape     : {preds.shape}")
print(f"grads is None   : {grads is None}")
if grads is not None:
    print(f"grads shape     : {grads.shape}")
    print(f"grads max       : {float(tf.reduce_max(tf.abs(grads))):.6f}")

print(f"\nPrediction:")
print(f"  class_idx  : {class_idx}")
print(f"  class_name : {CLASS_NAMES[class_idx] if class_idx < len(CLASS_NAMES) else '?'}")
print(f"  confidence : {float(preds[0, class_idx]) * 100:.1f}%")

# ── Generate heatmap if grads available ───────────────────────────────────────
if grads is not None:
    pooled = tf.reduce_mean(grads, axis=(0, 1, 2))
    heatmap = tf.reduce_sum(conv_acts[0] * pooled, axis=-1)
    heatmap = tf.nn.relu(heatmap)
    hmax = tf.reduce_max(heatmap)
    heatmap = (heatmap / hmax) if float(hmax) > 1e-8 else tf.zeros_like(heatmap)
    heatmap_np = heatmap.numpy()
    print(f"\nHeatmap shape : {heatmap_np.shape}")
    print(f"Heatmap min   : {heatmap_np.min():.3f}  max={heatmap_np.max():.3f}")

    # Save overlay
    r = np.clip(1.5 - np.abs(4.0 * heatmap_np - 3.0), 0, 1)
    g_ = np.clip(1.5 - np.abs(4.0 * heatmap_np - 2.0), 0, 1)
    b_ = np.clip(1.5 - np.abs(4.0 * heatmap_np - 1.0), 0, 1)
    jet = (np.stack([r, g_, b_], axis=-1) * 255).astype(np.uint8)

    hm_img = Image.fromarray(np.uint8(heatmap_np * 255)).resize((224, 224), Image.BILINEAR)
    hm_arr = np.array(hm_img, dtype=np.float32) / 255.0
    jet2 = (np.stack([
        np.clip(1.5 - np.abs(4.0 * hm_arr - 3.0), 0, 1),
        np.clip(1.5 - np.abs(4.0 * hm_arr - 2.0), 0, 1),
        np.clip(1.5 - np.abs(4.0 * hm_arr - 1.0), 0, 1),
    ], axis=-1) * 255).astype(np.uint8)

    orig = np.array(Image.fromarray(arr).resize((224, 224)), dtype=np.float32)
    overlay = (orig * 0.55 + jet2.astype(np.float32) * 0.45).clip(0, 255)
    out_path = Path(__file__).parent / "_test_gradcam_result.png"
    Image.fromarray(overlay.astype(np.uint8)).save(str(out_path))
    print(f"\nOverlay saved: {out_path}")
    print("\n✓ SUCCESS — Grad-CAM is working correctly!")
else:
    print("\n✗ FAIL — grads is None")

tmp.unlink(missing_ok=True)
