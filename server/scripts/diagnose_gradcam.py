"""
Standalone Grad-CAM diagnostic — run directly with venv Python.
Usage:
    cd server
    venv\Scripts\python.exe scripts\diagnose_gradcam.py
"""
import os, sys
os.environ["DJANGO_SETTINGS_MODULE"] = "config.settings.development"
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import numpy as np
from pathlib import Path
from PIL import Image

print("=" * 60)
print("  Midori Grad-CAM Diagnostic")
print("=" * 60)

# ── 1. Import TF ───────────────────────────────────────────────
print("\n[1] Importing TensorFlow...")
import tensorflow as tf
keras = tf.keras
print(f"    TF={tf.__version__}  keras OK")

# ── 2. Load model ──────────────────────────────────────────────
MODEL_PATH = Path(__file__).parent.parent / "plant_disease_mobilenet.h5"
print(f"\n[2] Loading model from {MODEL_PATH} ...")
model = keras.models.load_model(str(MODEL_PATH))
print(f"    Input shape : {model.input_shape}")
print(f"    Output shape: {model.output_shape}")
print("    Top-level layers:")
for l in model.layers:
    nested = hasattr(l, "layers") and len(l.layers) > 3
    print(f"      {l.name:40s}  nested={nested}")

# ── 3. Find backbone & conv layer ─────────────────────────────
print("\n[3] Finding backbone and conv layer...")
backbone = None
for lyr in model.layers:
    if hasattr(lyr, "layers") and len(lyr.layers) > 3:
        backbone = lyr
        break

if backbone:
    print(f"    Backbone: {backbone.name}")
    # Find last 4-D layer in backbone
    last_conv = None
    for l in backbone.layers:
        try:
            if isinstance(l.output_shape, (list, tuple)) and len(l.output_shape) == 4:
                last_conv = l
        except Exception:
            pass
    print(f"    Last conv layer: {last_conv.name}  shape={last_conv.output_shape}")
else:
    print("    No nested backbone found — flat model")
    last_conv = None
    for l in model.layers:
        try:
            if isinstance(l.output_shape, (list, tuple)) and len(l.output_shape) == 4:
                last_conv = l
        except Exception:
            pass
    print(f"    Last conv layer: {last_conv.name}  shape={last_conv.output_shape}")

# ── 4. Build grad model ────────────────────────────────────────
print("\n[4] Building Grad-CAM sub-model...")
try:
    if backbone is not None:
        conv_extractor = keras.Model(
            inputs=backbone.inputs,
            outputs=last_conv.output,
        )
        conv_output_in_outer = conv_extractor(model.input)
    else:
        conv_output_in_outer = last_conv.output

    grad_model = keras.Model(
        inputs=model.inputs,
        outputs=[conv_output_in_outer, model.output],
    )
    print(f"    grad_model inputs : {[i.shape for i in grad_model.inputs]}")
    print(f"    grad_model outputs: {[o.shape for o in grad_model.outputs]}")
    print("    Build: OK")
except Exception as e:
    print(f"    Build FAILED: {e}")
    sys.exit(1)

# ── 5. Synthetic green image ───────────────────────────────────
print("\n[5] Creating synthetic leaf image...")
arr = np.zeros((224, 224, 3), dtype=np.uint8)
arr[:, :, 1] = 150
arr[:, :, 0] = 60
arr[:, :, 2] = 40
img = Image.fromarray(arr)
tmp_path = Path(__file__).parent / "_diag_img.jpg"
img.save(str(tmp_path))

preprocessed = keras.applications.mobilenet_v2.preprocess_input(
    np.expand_dims(np.array(img, dtype=np.float32), 0)
)
img_tensor = tf.cast(preprocessed, tf.float32)
print(f"    img_tensor shape: {img_tensor.shape}")

# ── 6. Test gradient strategies ────────────────────────────────
print("\n[6] Testing GradientTape strategies...")

# Strategy A: watch img_tensor, gradient w.r.t. conv_acts
print("\n  Strategy A: watch(img_tensor), gradient w.r.t. conv_acts")
try:
    with tf.GradientTape() as tape:
        tape.watch(img_tensor)
        conv_acts, preds = grad_model(img_tensor, training=False)
        class_idx = int(tf.argmax(preds[0]))
        class_score = preds[:, class_idx]
    grads = tape.gradient(class_score, conv_acts)
    print(f"    grads is None: {grads is None}")
    if grads is not None:
        print(f"    grads shape: {grads.shape}  max={float(tf.reduce_max(tf.abs(grads))):.6f}")
except Exception as e:
    print(f"    ERROR: {e}")

# Strategy B: watch conv_acts directly (persistent tape)
print("\n  Strategy B: persistent tape, watch(conv_acts) THEN class_score")
try:
    with tf.GradientTape(persistent=True) as tape:
        conv_acts, preds = grad_model(img_tensor, training=False)
        tape.watch(conv_acts)
        class_idx = int(tf.argmax(preds[0]))
        class_score = preds[:, class_idx]
    grads = tape.gradient(class_score, conv_acts)
    print(f"    grads is None: {grads is None}")
    if grads is not None:
        print(f"    grads shape: {grads.shape}  max={float(tf.reduce_max(tf.abs(grads))):.6f}")
    del tape
except Exception as e:
    print(f"    ERROR: {e}")

# Strategy C: tf.Variable
print("\n  Strategy C: tf.Variable as input")
try:
    img_var = tf.Variable(img_tensor, trainable=True)
    with tf.GradientTape() as tape:
        conv_acts, preds = grad_model(img_var, training=False)
        class_idx = int(tf.argmax(preds[0]))
        class_score = preds[:, class_idx]
    grads = tape.gradient(class_score, conv_acts)
    print(f"    grads is None: {grads is None}")
    if grads is not None:
        print(f"    grads shape: {grads.shape}  max={float(tf.reduce_max(tf.abs(grads))):.6f}")
except Exception as e:
    print(f"    ERROR: {e}")

# Strategy D: split into two models — conv model + full model
print("\n  Strategy D: two-model split (conv_extractor + full model)")
try:
    if backbone is not None:
        # conv_extractor: backbone.input -> conv_output  (in backbone graph)
        # Build a model from backbone.input -> [conv_output, backbone.output]
        conv_and_backbone = keras.Model(
            inputs=backbone.inputs,
            outputs=[last_conv.output, backbone.output],
        )
        # head layers (everything after backbone in outer model)
        # run the full outer model separately for predictions
    
    img_var2 = tf.Variable(img_tensor, trainable=True)
    with tf.GradientTape(persistent=True) as tape:
        if backbone is not None:
            conv_acts2, _ = conv_and_backbone(img_var2, training=False)
        else:
            conv_acts2 = last_conv(img_var2, training=False)
        tape.watch(conv_acts2)
        preds2 = model(img_var2, training=False)
        class_idx2 = int(tf.argmax(preds2[0]))
        class_score2 = preds2[:, class_idx2]
    grads2 = tape.gradient(class_score2, conv_acts2)
    del tape
    print(f"    grads is None: {grads2 is None}")
    if grads2 is not None:
        print(f"    grads shape: {grads2.shape}  max={float(tf.reduce_max(tf.abs(grads2))):.6f}")
        print(f"    Predicted class: {class_idx2}  confidence: {float(preds2[0, class_idx2])*100:.1f}%")
except Exception as e:
    print(f"    ERROR: {e}")

# ── 7. Cleanup ────────────────────────────────────────────────
tmp_path.unlink(missing_ok=True)
print("\n" + "=" * 60)
print("  Diagnostic complete.")
print("=" * 60)
