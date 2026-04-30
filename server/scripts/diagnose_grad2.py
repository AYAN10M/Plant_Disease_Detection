"""
Deep gradient flow diagnostic.
cd server && venv\Scripts\python.exe scripts\diagnose_grad2.py
"""
import os, sys
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"
os.environ["TF_USE_LEGACY_KERAS"] = "1"
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import numpy as np
from pathlib import Path
from PIL import Image
import tensorflow as tf
keras = tf.keras

print("TF:", tf.__version__)

MODEL_PATH = Path(__file__).parent.parent / "plant_disease_mobilenet.h5"
model = keras.models.load_model(str(MODEL_PATH))

# Synthetic image
arr = np.zeros((1, 224, 224, 3), dtype=np.float32)
arr[:, :, :, 1] = 100
preprocessed = keras.applications.mobilenet_v2.preprocess_input(arr.copy())

# ── Test 1: Can we get any gradient at all (input -> output)?
print("\n=== Test 1: Input gradient ===")
img_var = tf.Variable(preprocessed, trainable=True, dtype=tf.float32)
with tf.GradientTape() as tape:
    out = model(img_var, training=False)
    loss = out[0, 0]
g = tape.gradient(loss, img_var)
print(f"Gradient of output[0] w.r.t input: {g is None} (None=bad, tensor=good)")
if g is not None:
    print(f"  grad max={float(tf.reduce_max(tf.abs(g))):.6f}")

# ── Test 2: Check if model uses training=False stops gradients
print("\n=== Test 2: Model trainable vars ===")
print(f"  model.trainable: {model.trainable}")
print(f"  trainable vars count: {len(model.trainable_variables)}")

# ── Test 3: Check if BN layers are the issue (training=True)
print("\n=== Test 3: training=True ===")
img_var2 = tf.Variable(preprocessed, trainable=True, dtype=tf.float32)
with tf.GradientTape() as tape:
    out = model(img_var2, training=True)
    loss = out[0, 0]
g2 = tape.gradient(loss, img_var2)
print(f"Gradient (training=True): {g2 is None}")
if g2 is not None:
    print(f"  grad max={float(tf.reduce_max(tf.abs(g2))):.6f}")

# ── Test 4: backbone directly
print("\n=== Test 4: Direct backbone call ===")
backbone = None
for lyr in model.layers:
    if hasattr(lyr, "layers") and len(lyr.layers) > 3:
        backbone = lyr
        break

if backbone:
    print(f"  Backbone: {backbone.name}  trainable={backbone.trainable}")
    img_var3 = tf.Variable(preprocessed, trainable=True, dtype=tf.float32)
    with tf.GradientTape() as tape:
        out3 = backbone(img_var3, training=False)
        loss3 = tf.reduce_sum(out3)
    g3 = tape.gradient(loss3, img_var3)
    print(f"  Backbone gradient: {g3 is None}")
    if g3 is not None:
        print(f"  grad max={float(tf.reduce_max(tf.abs(g3))):.6f}")

    # Backbone's last conv layer
    last_conv = None
    for l in backbone.layers:
        try:
            if isinstance(l.output_shape, (list, tuple)) and len(l.output_shape) == 4:
                last_conv = l
        except Exception:
            pass
    print(f"  Last conv: {last_conv.name}")

    # Test 5: build simple model backbone.input->conv.output in backbone graph
    print("\n=== Test 5: Backbone sub-model (no outer model) ===")
    try:
        sub = keras.Model(inputs=backbone.inputs, outputs=[last_conv.output, backbone.output])
        img_var4 = tf.Variable(preprocessed, trainable=True, dtype=tf.float32)
        with tf.GradientTape() as tape:
            conv4, out4 = sub(img_var4, training=False)
            tape.watch(conv4)
            loss4 = out4[0, 0]
        g4 = tape.gradient(loss4, conv4)
        print(f"  Gradient of backbone_out[0,0] w.r.t conv_acts: {g4 is None}")
        if g4 is not None:
            print(f"  grad shape={g4.shape}  max={float(tf.reduce_max(tf.abs(g4))):.6f}")
    except Exception as e:
        print(f"  ERROR: {e}")

    # Test 6: gradient of conv -> output (no outer model, watch before call)
    print("\n=== Test 6: Watch backbone.input, grad w.r.t. conv_acts ===")
    try:
        sub2 = keras.Model(inputs=backbone.inputs, outputs=[last_conv.output, backbone.output])
        img_var5 = tf.Variable(preprocessed, trainable=True, dtype=tf.float32)
        with tf.GradientTape() as tape:
            tape.watch(img_var5)
            conv5, out5 = sub2(img_var5, training=False)
            loss5 = out5[0, 0]
        g5 = tape.gradient(loss5, conv5)
        print(f"  Gradient of backbone_out[0,0] w.r.t conv_acts (via input watch): {g5 is None}")
        if g5 is not None:
            print(f"  grad shape={g5.shape}  max={float(tf.reduce_max(tf.abs(g5))):.6f}")
    except Exception as e:
        print(f"  ERROR: {e}")

    # Test 7: eager mode explicit
    print("\n=== Test 7: Explicit eager grad (no model, layer by layer) ===")
    try:
        # Only use backbone layers to avoid the outer model issue entirely
        img_tf = tf.constant(preprocessed)
        img_var6 = tf.Variable(img_tf)
        with tf.GradientTape(persistent=True) as tape:
            x = img_var6
            conv_out = None
            for layer in backbone.layers:
                if hasattr(layer, 'call'):
                    try:
                        if layer.name == 'input_2':
                            continue
                        x = layer(x, training=False)
                        if layer.name == last_conv.name:
                            conv_out = x
                    except Exception:
                        pass
            final_out = x
        g6a = tape.gradient(tf.reduce_sum(final_out), img_var6)
        g6b = tape.gradient(tf.reduce_sum(final_out), conv_out) if conv_out is not None else None
        del tape
        print(f"  grad w.r.t input: {g6a is None}")
        print(f"  grad w.r.t conv_out: {g6b is None}")
        if g6a is not None:
            print(f"  input grad max={float(tf.reduce_max(tf.abs(g6a))):.6f}")
        if g6b is not None:
            print(f"  conv_out grad max={float(tf.reduce_max(tf.abs(g6b))):.6f}")
    except Exception as e:
        import traceback; traceback.print_exc()

print("\n=== Done ===")
