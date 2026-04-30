"""Test with real validation images through the live API."""
import requests, json, sys, pathlib
from PIL import Image
import numpy as np

BASE = "http://127.0.0.1:8000"
val_dir = pathlib.Path(r"C:\Users\arsenic\Coding\model\dataset\Valid")

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

test_classes = [
    "Tomato_Early_blight", "Tomato_Late_blight", "Tomato_healthy",
    "Apple_Apple_scab", "Apple_healthy", "Rice_Blast", "Potato_Early_blight",
]

correct = 0
total = 0

print(f"\n{'True Class':40s}  {'Predicted':40s}  {'Conf':6s}  {'OK?'}")
print("-" * 100)

for cls_name in test_classes:
    cls_dir = val_dir / cls_name
    if not cls_dir.exists():
        continue
    imgs = list(cls_dir.glob("*.jpg"))[:2]
    for img_path in imgs:
        with open(img_path, "rb") as fh:
            r = requests.post(
                f"{BASE}/api/detections/",
                files={"uploaded_image": (img_path.name, fh, "image/jpeg")},
                timeout=120,
            )
        body = r.json()
        det = body.get("data", {}) or {}
        disease_detail = det.get("disease_detail") or {}
        pred_class = disease_detail.get("name") or (
            "healthy" if det.get("is_healthy") else body.get("status", "?")
        )
        confidence = det.get("confidence_pct", "?")
        status = det.get("status", "?")

        # For healthy images, check is_healthy flag
        if cls_name.endswith("_healthy"):
            ok = det.get("is_healthy", False)
        else:
            ok = (pred_class == cls_name) or (pred_class and cls_name in pred_class)

        flag = "[OK]" if ok else "[WRONG]"
        if ok:
            correct += 1
        total += 1
        print(f"  {cls_name:38s}  {str(pred_class):38s}  {str(confidence):6s}  {flag}  (status={status})")

print(f"\nAPI accuracy on real val images: {correct}/{total}  ({correct/total*100:.0f}%)")
