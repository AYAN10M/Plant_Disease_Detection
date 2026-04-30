"""
Deep validation test — tests ALL classes with real val images.
cd server && venv\Scripts\python.exe scripts\full_val_test.py
"""
import os, sys, pathlib
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "3"
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import numpy as np
import tensorflow as tf
keras = tf.keras

CLASS_NAMES = [
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
]

print("Loading model...")
model = keras.models.load_model("plant_disease_mobilenet.h5")

val_dir = pathlib.Path(r"C:\Users\arsenic\Coding\model\dataset\Valid")
if not val_dir.exists():
    print("Val dir not found at", val_dir)
    sys.exit(1)

from PIL import Image

correct = 0
wrong = 0
missing_classes = []
wrong_predictions = []

print(f"\nTesting real validation images from {val_dir}\n")

for cls_name in CLASS_NAMES:
    cls_dir = val_dir / cls_name
    if not cls_dir.exists():
        missing_classes.append(cls_name)
        continue

    # Pick up to 3 images per class
    imgs = list(cls_dir.glob("*.jpg"))[:3] + list(cls_dir.glob("*.JPG"))[:3] + list(cls_dir.glob("*.png"))[:3]
    imgs = imgs[:3]
    if not imgs:
        missing_classes.append(cls_name)
        continue

    cls_correct = 0
    for img_path in imgs:
        try:
            img = Image.open(str(img_path)).convert("RGB").resize((224, 224))
            arr = keras.applications.mobilenet_v2.preprocess_input(
                np.expand_dims(np.array(img, dtype=np.float32), 0)
            )
            preds = model(tf.cast(arr, tf.float32), training=False)[0].numpy()
            pred_idx = int(np.argmax(preds))
            true_idx = CLASS_NAMES.index(cls_name)
            conf = float(preds[pred_idx]) * 100

            if pred_idx == true_idx:
                cls_correct += 1
                correct += 1
            else:
                wrong += 1
                wrong_predictions.append({
                    "true": cls_name,
                    "pred": CLASS_NAMES[pred_idx],
                    "conf": conf,
                })
        except Exception as e:
            print(f"  Error on {img_path}: {e}")

total = correct + wrong
print(f"Overall: {correct}/{total} correct  ({correct/total*100:.1f}%)")

if missing_classes:
    print(f"\nMissing val folders ({len(missing_classes)}):")
    for c in missing_classes:
        print(f"  - {c}")

if wrong_predictions:
    print(f"\nWrong predictions ({len(wrong_predictions)}):")
    for w in wrong_predictions[:20]:
        print(f"  true={w['true']:45s}  pred={w['pred']:45s}  conf={w['conf']:.1f}%")
