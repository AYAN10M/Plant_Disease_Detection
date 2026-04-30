"""
convert_to_tflite.py
====================
Converts plant_disease_mobilenet.h5  →  plant_disease_mobilenet.tflite

Run once:
    python convert_to_tflite.py
"""

import os
import numpy as np
import tensorflow as tf

_DIR = os.path.dirname(os.path.abspath(__file__))

H5_PATH     = os.path.join(_DIR, "plant_disease_mobilenet.h5")
TFLITE_PATH = os.path.join(_DIR, "plant_disease_mobilenet.tflite")

# ── Load ──────────────────────────────────────────────────────────────────────
print(f"[INFO] Loading model: {H5_PATH}")
model = tf.keras.models.load_model(H5_PATH)
print(f"[INFO] Model loaded — output shape: {model.output_shape}")

# ── Convert (float32 — keeps full accuracy, works with Grad-CAM) ─────────────
converter = tf.lite.TFLiteConverter.from_keras_model(model)

# Optional: uncomment below for smaller file (~4x) with slight accuracy drop
# converter.optimizations = [tf.lite.Optimize.DEFAULT]

tflite_model = converter.convert()

# ── Save ──────────────────────────────────────────────────────────────────────
with open(TFLITE_PATH, "wb") as f:
    f.write(tflite_model)

size_mb = os.path.getsize(TFLITE_PATH) / (1024 * 1024)
print(f"[INFO] TFLite model saved → {TFLITE_PATH}  ({size_mb:.1f} MB)")

# ── Quick sanity check ────────────────────────────────────────────────────────
interpreter = tf.lite.Interpreter(model_path=TFLITE_PATH)
interpreter.allocate_tensors()
inp  = interpreter.get_input_details()[0]
out  = interpreter.get_output_details()[0]
print(f"[INFO] Input  shape: {inp['shape']}   dtype: {inp['dtype']}")
print(f"[INFO] Output shape: {out['shape']}   dtype: {out['dtype']}")
print("[INFO] ✅ Conversion successful!")
