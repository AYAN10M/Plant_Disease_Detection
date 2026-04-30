"""Diagnose prediction quality issues."""
import os, sys, json, pathlib
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "3"
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import numpy as np
import tensorflow as tf
keras = tf.keras

# ── Class accuracy report ────────────────────────────────────────────────────
report = pathlib.Path(r"C:\Users\arsenic\Coding\model\mobile_efficient_deployment\class_accuracy_report.json")
if report.exists():
    data = json.loads(report.read_text())
    items = list(data.items())
    print("WORST 10 classes by validation accuracy:")
    for name, acc in items[:10]:
        print(f"  {acc:5.1f}%  {name}")
    print("\nBEST 10 classes:")
    for name, acc in items[-10:]:
        print(f"  {acc:5.1f}%  {name}")
    overall = sum(data.values()) / len(data)
    print(f"\nAvg per-class accuracy: {overall:.1f}%")
else:
    print("No class_accuracy_report.json found")

# ── Model layer config ────────────────────────────────────────────────────────
print("\n" + "="*50)
model = keras.models.load_model("plant_disease_mobilenet.h5")
print("Top-level layer summary:")
for lyr in model.layers:
    print(f"  {lyr.name:45s}  type={type(lyr).__name__}")

last = model.layers[-1]
cfg = last.get_config()
print(f"\nFinal layer: {last.name}")
print(f"  activation : {cfg.get('activation')}")
print(f"  units      : {cfg.get('units')}")

# ── Run on a sample real val image ────────────────────────────────────────────
val_dir = pathlib.Path(r"C:\Users\arsenic\Coding\model\dataset\Valid")
if val_dir.exists():
    print("\n" + "="*50)
    print("Sampling real validation images...")
    correct = 0
    total = 0
    # Test first image from each of first 5 classes
    CLASS_NAMES = sorted([d.name for d in val_dir.iterdir() if d.is_dir()])
    for cls_name in CLASS_NAMES[:5]:
        cls_dir = val_dir / cls_name
        imgs = list(cls_dir.glob("*.jpg"))[:1] + list(cls_dir.glob("*.JPG"))[:1] + list(cls_dir.glob("*.png"))[:1]
        if not imgs:
            continue
        from PIL import Image
        img = Image.open(str(imgs[0])).convert("RGB").resize((224, 224))
        arr = keras.applications.mobilenet_v2.preprocess_input(
            np.expand_dims(np.array(img, dtype=np.float32), 0)
        )
        preds = model(tf.cast(arr, tf.float32), training=False)[0].numpy()
        pred_idx = int(np.argmax(preds))
        true_idx = CLASS_NAMES.index(cls_name)
        conf = float(preds[pred_idx]) * 100
        ok = "[OK]" if pred_idx == true_idx else "[WRONG]"
        print(f"  {ok} true={cls_name:40s}  pred={CLASS_NAMES[pred_idx]:40s}  conf={conf:.1f}%")
        if pred_idx == true_idx:
            correct += 1
        total += 1
    print(f"\n  Mini accuracy: {correct}/{total}")
else:
    print("Val dir not found")
