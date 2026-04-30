"""
evaluate_and_finetune.py
========================
1. Evaluates plant_disease_mobilenet.h5 on the real validation set
2. Shows per-class accuracy + worst-performing classes
3. Re-fine-tunes with stronger augmentation + label smoothing + EarlyStopping
4. Saves improved model as plant_disease_mobilenet_v2.h5

Run:
    python evaluate_and_finetune.py
"""

import os, json
import numpy as np
import tensorflow as tf
from tensorflow.keras.applications.mobilenet_v2 import preprocess_input
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau, ModelCheckpoint
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

# ─── Paths ────────────────────────────────────────────────────────────────────
_DIR          = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH    = os.path.join(_DIR, "plant_disease_mobilenet.h5")
IMPROVED_PATH = os.path.join(_DIR, "plant_disease_mobilenet_v2.h5")
TRAIN_DIR     = os.path.join(_DIR, "..", "dataset", "Train")
VAL_DIR       = os.path.join(_DIR, "..", "dataset", "Valid")

IMG_SIZE   = (224, 224)
BATCH_SIZE = 32

# ─── 1. Load datasets ─────────────────────────────────────────────────────────
print("\n[INFO] Loading datasets …")

raw_val = tf.keras.utils.image_dataset_from_directory(
    VAL_DIR, label_mode="categorical",
    image_size=IMG_SIZE, batch_size=BATCH_SIZE, shuffle=False
)
class_names = raw_val.class_names
NUM_CLASSES  = len(class_names)
print(f"[INFO] {NUM_CLASSES} classes  |  val batches: {len(raw_val)}")

val_ds = raw_val.map(lambda x, y: (preprocess_input(x), y),
                     num_parallel_calls=tf.data.AUTOTUNE).cache().prefetch(tf.data.AUTOTUNE)

# ─── 2. Load model & baseline evaluation ─────────────────────────────────────
print(f"\n[INFO] Loading model: {MODEL_PATH}")
model = tf.keras.models.load_model(MODEL_PATH)

print("\n[INFO] === BASELINE EVALUATION ON VALIDATION SET ===")
loss, acc = model.evaluate(val_ds, verbose=1)
print(f"  Baseline val_accuracy : {acc*100:.2f}%")
print(f"  Baseline val_loss     : {loss:.4f}")

# ─── 3. Per-class accuracy ────────────────────────────────────────────────────
print("\n[INFO] Computing per-class accuracy …")
y_true, y_pred = [], []

for images, labels in val_ds:
    preds  = model.predict(images, verbose=0)
    y_true.extend(np.argmax(labels.numpy(), axis=1))
    y_pred.extend(np.argmax(preds, axis=1))

y_true = np.array(y_true)
y_pred = np.array(y_pred)

per_class_acc = {}
for idx, name in enumerate(class_names):
    mask = y_true == idx
    if mask.sum() > 0:
        per_class_acc[name] = np.mean(y_pred[mask] == idx) * 100

# Sort by accuracy
sorted_classes = sorted(per_class_acc.items(), key=lambda x: x[1])

print("\n  WORST 10 classes (need most improvement):")
for name, a in sorted_classes[:10]:
    print(f"    {a:5.1f}%  {name}")

print("\n  BEST 10 classes:")
for name, a in sorted_classes[-10:]:
    print(f"    {a:5.1f}%  {name}")

# Save per-class report
report_path = os.path.join(_DIR, "class_accuracy_report.json")
with open(report_path, "w") as f:
    json.dump(dict(sorted(per_class_acc.items(), key=lambda x: x[1])), f, indent=2)
print(f"\n[INFO] Full per-class report saved → {report_path}")

# ─── 4. Plot per-class accuracy ───────────────────────────────────────────────
fig, ax = plt.subplots(figsize=(14, 10), facecolor="#1a1a2e")
ax.set_facecolor("#16213e")
names = [n.replace("_", " ") for n, _ in sorted_classes]
accs  = [a for _, a in sorted_classes]
colours = ["#e74c3c" if a < 80 else "#f39c12" if a < 90 else "#2ecc71" for a in accs]
ax.barh(names, accs, color=colours)
ax.set_xlabel("Accuracy (%)", color="white")
ax.set_title("Per-Class Validation Accuracy", color="white", fontsize=13)
ax.tick_params(colors="white", labelsize=7)
ax.axvline(acc*100, color="white", linestyle="--", linewidth=1, label=f"Overall {acc*100:.1f}%")
ax.legend(labelcolor="white", facecolor="#333355")
for spine in ax.spines.values():
    spine.set_edgecolor("#444466")
plt.tight_layout()
plot_path = os.path.join(_DIR, "per_class_accuracy.png")
plt.savefig(plot_path, dpi=120, bbox_inches="tight", facecolor="#1a1a2e")
print(f"[INFO] Per-class accuracy chart saved → {plot_path}")
plt.close()

# ─── 5. Re-fine-tune with improvements ───────────────────────────────────────
print("\n[INFO] === STARTING IMPROVED FINE-TUNING ===")
print("  Improvements:")
print("  • Stronger augmentation (flip, rotation, zoom, brightness, contrast)")
print("  • Label smoothing (reduces overconfidence)")
print("  • EarlyStopping on val_loss (prevents overfitting)")
print("  • ReduceLROnPlateau (adaptive LR)")
print("  • Lower learning rate (1e-5 → 5e-6 for fine layers)")

# ── Augmentation layer ────────────────────────────────────────────────────────
augment = tf.keras.Sequential([
    tf.keras.layers.RandomFlip("horizontal_and_vertical"),
    tf.keras.layers.RandomRotation(0.15),
    tf.keras.layers.RandomZoom(0.15),
    tf.keras.layers.RandomBrightness(0.2),
    tf.keras.layers.RandomContrast(0.2),
], name="augmentation")

# ── Rebuild train dataset with augmentation ───────────────────────────────────
raw_train = tf.keras.utils.image_dataset_from_directory(
    TRAIN_DIR, label_mode="categorical",
    image_size=IMG_SIZE, batch_size=BATCH_SIZE, shuffle=True, seed=42
)

train_ds = (
    raw_train
    .map(lambda x, y: (preprocess_input(augment(x, training=True)), y),
         num_parallel_calls=tf.data.AUTOTUNE)
    .cache()
    .prefetch(tf.data.AUTOTUNE)
)

# ── Unfreeze last 50 layers for deeper fine-tuning ────────────────────────────
base_model = model.layers[0]          # MobileNetV2 is layer 0 in Sequential
base_model.trainable = True
for layer in base_model.layers[:-50]:
    layer.trainable = False

trainable_count = sum(1 for l in base_model.layers if l.trainable)
print(f"[INFO] Trainable conv layers: {trainable_count}")

# ── Recompile with label smoothing ────────────────────────────────────────────
model.compile(
    optimizer=tf.keras.optimizers.Adam(learning_rate=5e-6),
    loss=tf.keras.losses.CategoricalCrossentropy(label_smoothing=0.1),
    metrics=["accuracy"],
)

callbacks = [
    EarlyStopping(
        monitor="val_accuracy", patience=5,
        mode="max", restore_best_weights=True, verbose=1
    ),
    ReduceLROnPlateau(
        monitor="val_loss", factor=0.3,
        patience=2, min_lr=1e-7, verbose=1
    ),
    ModelCheckpoint(
        IMPROVED_PATH, monitor="val_accuracy",
        mode="max", save_best_only=True, verbose=1
    ),
]

print(f"\n[INFO] Training … (EarlyStopping will stop when val_accuracy plateaus)")
history = model.fit(
    train_ds,
    validation_data=val_ds,
    epochs=25,           # EarlyStopping will cut this short
    callbacks=callbacks,
    verbose=1,
)

# ─── 6. Final evaluation ──────────────────────────────────────────────────────
print("\n[INFO] === FINAL EVALUATION (improved model) ===")
model2 = tf.keras.models.load_model(IMPROVED_PATH)
loss2, acc2 = model2.evaluate(val_ds, verbose=1)
print(f"\n  Original  val_accuracy : {acc*100:.2f}%")
print(f"  Improved  val_accuracy : {acc2*100:.2f}%")
print(f"  Gain                   : +{(acc2-acc)*100:.2f}%")

# ─── 7. Training curve ────────────────────────────────────────────────────────
bg = "#1a1a2e"
fig, axes = plt.subplots(1, 2, figsize=(12, 4), facecolor=bg)
for ax in axes:
    ax.set_facecolor("#16213e")
    ax.tick_params(colors="white")
    for spine in ax.spines.values():
        spine.set_edgecolor("#444466")

epochs_ran = range(1, len(history.history["accuracy"]) + 1)
axes[0].plot(epochs_ran, history.history["accuracy"],     color="#2ecc71", label="Train")
axes[0].plot(epochs_ran, history.history["val_accuracy"], color="#3498db", linestyle="--", label="Val")
axes[0].set_title("Accuracy", color="white"); axes[0].legend(labelcolor="white", facecolor="#333355")

axes[1].plot(epochs_ran, history.history["loss"],     color="#e74c3c", label="Train")
axes[1].plot(epochs_ran, history.history["val_loss"], color="#f39c12", linestyle="--", label="Val")
axes[1].set_title("Loss", color="white"); axes[1].legend(labelcolor="white", facecolor="#333355")

fig.suptitle("Improved Fine-Tuning History", color="white", fontsize=13)
plt.tight_layout()
curve_path = os.path.join(_DIR, "finetune_history.png")
plt.savefig(curve_path, dpi=120, bbox_inches="tight", facecolor=bg)
print(f"[INFO] Training curve saved → {curve_path}")
plt.close()

print(f"\n[INFO] ✅ Improved model saved → {IMPROVED_PATH}")
print("[INFO] Update predict.py MODEL_PATH to use plant_disease_mobilenet_v2.h5")
