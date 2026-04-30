"""
Test weighted TTA on real validation images and compare against old flat TTA.
cd server && venv\Scripts\python.exe scripts\test_weighted_tta.py
"""
import os, sys, pathlib
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "3"
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import numpy as np
import tensorflow as tf
from PIL import Image
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

def infer_single(img_path):
    """Single-pass inference (no TTA) as baseline."""
    img = Image.open(str(img_path)).convert("RGB").resize((224, 224))
    arr = keras.applications.mobilenet_v2.preprocess_input(
        np.expand_dims(np.array(img, dtype=np.float32), 0))
    probs = model(tf.cast(arr, tf.float32), training=False)[0].numpy()
    return probs

def infer_weighted_tta(img_path):
    """New centre-biased weighted TTA."""
    pil_img = Image.open(str(img_path)).convert("RGB")
    W, H = pil_img.size
    cX, cY = W // 2, H // 2

    crops_weights = []
    # Full image
    crops_weights.append((pil_img, 3))
    # Centre 80%
    s80 = int(min(W, H) * 0.80)
    crops_weights.append((pil_img.crop((cX - s80//2, cY - s80//2, cX + s80//2, cY + s80//2)), 3))
    # Centre 60%
    s60 = int(min(W, H) * 0.60)
    crops_weights.append((pil_img.crop((cX - s60//2, cY - s60//2, cX + s60//2, cY + s60//2)), 2))
    # 4 corners at 70%
    s70 = int(min(W, H) * 0.70)
    for x0, y0 in [(0,0),(W-s70,0),(0,H-s70),(W-s70,H-s70)]:
        crops_weights.append((pil_img.crop((x0,y0,x0+s70,y0+s70)), 1))

    weighted_sum = None
    total_weight = 0
    crop_top1s = []
    for crop, w in crops_weights:
        arr = np.array(crop.resize((224, 224), Image.LANCZOS), dtype=np.float32)
        batch = keras.applications.mobilenet_v2.preprocess_input(np.expand_dims(arr, 0))
        probs = model(tf.cast(batch, tf.float32), training=False)[0].numpy()
        crop_top1s.append(int(np.argmax(probs)))
        weighted_sum = probs * w if weighted_sum is None else weighted_sum + probs * w
        total_weight += w

    avg = weighted_sum / total_weight
    # Agreement check
    hv = crop_top1s[:3]
    dom = max(set(hv), key=hv.count)
    agreement = hv.count(dom) / len(hv)
    if agreement < 1.0:
        penalty = 0.75 if agreement < 0.67 else 0.90
        avg = avg * penalty
    return avg

# Test on 3 images from each of a representative set of classes
test_classes = [
    "Apple_Apple_scab", "Apple_healthy", "Tomato_Early_blight",
    "Tomato_Late_blight", "Tomato_Septoria_leaf_spot", "Tomato_healthy",
    "Potato_Early_blight", "Rice_Blast", "Grape_Black_rot", "Corn_Blight",
]

print(f"\n{'Class':45s} {'Single':10s} {'W-TTA':10s} {'Match?'}")
print("-" * 80)

single_correct = 0
wtta_correct = 0
total = 0

for cls_name in test_classes:
    cls_dir = val_dir / cls_name
    if not cls_dir.exists():
        continue
    imgs = list(cls_dir.glob("*.jpg"))[:3] + list(cls_dir.glob("*.JPG"))[:3]
    imgs = imgs[:3]
    true_idx = CLASS_NAMES.index(cls_name)

    for img_path in imgs:
        s_probs = infer_single(img_path)
        w_probs = infer_weighted_tta(img_path)

        s_idx = int(np.argmax(s_probs)); s_conf = float(s_probs[s_idx]) * 100
        w_idx = int(np.argmax(w_probs)); w_conf = float(w_probs[w_idx]) * 100

        s_ok = s_idx == true_idx
        w_ok = w_idx == true_idx

        if s_ok: single_correct += 1
        if w_ok: wtta_correct += 1
        total += 1

        flag = ""
        if s_ok and not w_ok: flag = " <- WTTA regressed"
        if not s_ok and w_ok: flag = " <- WTTA fixed"

        s_label = CLASS_NAMES[s_idx][:20]
        w_label = CLASS_NAMES[w_idx][:20]
        print(f"  {cls_name[:30]:30s}  S:{s_label:20s}{s_conf:5.0f}%  W:{w_label:20s}{w_conf:5.0f}%{flag}")

print(f"\nSingle-pass: {single_correct}/{total}  ({single_correct/total*100:.0f}%)")
print(f"Weighted TTA: {wtta_correct}/{total}  ({wtta_correct/total*100:.0f}%)")
