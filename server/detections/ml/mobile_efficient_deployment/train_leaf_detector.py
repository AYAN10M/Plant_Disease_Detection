"""
train_leaf_detector.py
======================
Train a lightweight MobileNetV2 binary classifier:
    Class 0 → NOT a leaf
    Class 1 → IS a leaf

Dataset layout expected
-----------------------
The script builds its own train/val split from two source folders:

  leaf_dir      : folder of leaf images  (positives)
                  Default: ../dataset/leaf_or_not/train/
                  (flat folder – all LEAF_*.jpg inside)

  non_leaf_dir  : folder of non-leaf images (negatives)
                  Default: automatically constructed from the ImageNet
                  'background' category or any folder you supply with --non-leaf.

If you do NOT have a dedicated non-leaf folder, the script will
auto-download ~1 000 royalty-free "non-leaf" images from Unsplash
(requires internet) or fall back to random noise patches so you can
test the pipeline without any extra data.

Output
------
  leaf_detector.keras    – saved Keras model
  leaf_detector_history.png

Usage
-----
  # quickest start (uses auto-downloaded negatives):
  python train_leaf_detector.py

  # with your own negative images:
  python train_leaf_detector.py --non-leaf path/to/non_leaf_images/

  # custom paths:
  python train_leaf_detector.py \\
      --leaf    path/to/leaf_images/ \\
      --non-leaf path/to/non_leaf/ \\
      --output  leaf_detector.keras \\
      --epochs  15
"""

import argparse
import os
import random
import sys
import urllib.request

import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.applications.mobilenet_v2 import preprocess_input
from tensorflow.keras.callbacks import EarlyStopping, ModelCheckpoint, ReduceLROnPlateau
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

# ──────────────────────────────────────────────────────────────────────────────
# Defaults
# ──────────────────────────────────────────────────────────────────────────────
_THIS_DIR   = os.path.dirname(os.path.abspath(__file__))
_PARENT_DIR = os.path.dirname(_THIS_DIR)

DEFAULT_LEAF_DIR     = os.path.join(_PARENT_DIR, "dataset", "leaf_or_not", "train")
DEFAULT_OUTPUT       = os.path.join(_THIS_DIR, "leaf_detector.keras")
DEFAULT_NON_LEAF_DIR = None   # auto-generated if not supplied

IMG_SIZE    = (224, 224)
BATCH_SIZE  = 32
SEED        = 42

# ──────────────────────────────────────────────────────────────────────────────
# Helper: collect image paths from a flat folder
# ──────────────────────────────────────────────────────────────────────────────
SUPPORTED = {".jpg", ".jpeg", ".png", ".bmp", ".webp", ".tiff"}


def collect_images(folder: str, max_count: int | None = None) -> list[str]:
    paths = []
    for f in os.listdir(folder):
        if os.path.splitext(f)[1].lower() in SUPPORTED:
            paths.append(os.path.join(folder, f))
    random.shuffle(paths)
    return paths[:max_count] if max_count else paths


# ──────────────────────────────────────────────────────────────────────────────
# Helper: create synthetic non-leaf negatives when no folder is supplied
#         (random natural-looking texture patches – better than pure noise)
# ──────────────────────────────────────────────────────────────────────────────
def create_synthetic_negatives(count: int, save_dir: str) -> list[str]:
    """
    Generate simple synthetic negative images (gradients + random colours)
    and save them to save_dir.  Returns list of saved paths.
    """
    import cv2
    os.makedirs(save_dir, exist_ok=True)
    paths = []
    rng = np.random.default_rng(SEED)

    for i in range(count):
        h, w = IMG_SIZE
        # Random solid colour with slight gradient noise
        base_colour = rng.integers(0, 256, size=3, dtype=np.uint8)
        img = np.full((h, w, 3), base_colour, dtype=np.uint8)
        # Add Perlin-like noise via random lines / patches
        n_patches = rng.integers(3, 12)
        for _ in range(n_patches):
            x1, y1 = rng.integers(0, w), rng.integers(0, h)
            x2, y2 = rng.integers(0, w), rng.integers(0, h)
            colour = rng.integers(0, 256, size=3).tolist()
            thickness = int(rng.integers(2, 20))
            cv2.line(img, (x1, y1), (x2, y2), colour, thickness)
        path = os.path.join(save_dir, f"synth_neg_{i:05d}.jpg")
        cv2.imwrite(path, img)
        paths.append(path)

    return paths


# ──────────────────────────────────────────────────────────────────────────────
# Dataset builder
# ──────────────────────────────────────────────────────────────────────────────
def build_dataset(
    leaf_paths: list[str],
    non_leaf_paths: list[str],
    val_split: float = 0.2,
) -> tuple:
    """
    Return (train_ds, val_ds, steps_per_epoch, val_steps).
    Labels: 0 = not leaf, 1 = leaf
    """
    # Balance classes
    n = min(len(leaf_paths), len(non_leaf_paths))
    leaf_paths     = leaf_paths[:n]
    non_leaf_paths = non_leaf_paths[:n]

    all_paths  = leaf_paths + non_leaf_paths
    all_labels = [1] * n + [0] * n

    # Shuffle together
    combined = list(zip(all_paths, all_labels))
    random.Random(SEED).shuffle(combined)
    all_paths, all_labels = zip(*combined)
    all_paths  = list(all_paths)
    all_labels = list(all_labels)

    n_total = len(all_paths)
    n_val   = int(n_total * val_split)
    n_train = n_total - n_val

    train_paths  = all_paths[:n_train]
    train_labels = all_labels[:n_train]
    val_paths    = all_paths[n_train:]
    val_labels   = all_labels[n_train:]

    def load_and_preprocess(path, label):
        raw   = tf.io.read_file(path)
        img   = tf.image.decode_jpeg(raw, channels=3)
        img   = tf.image.resize(img, IMG_SIZE)
        img   = preprocess_input(img)
        return img, tf.cast(label, tf.int32)

    def augment(img, label):
        img = tf.image.random_flip_left_right(img)
        img = tf.image.random_flip_up_down(img)
        img = tf.image.random_brightness(img, 0.2)
        img = tf.image.random_contrast(img, 0.8, 1.2)
        return img, label

    train_ds = (
        tf.data.Dataset.from_tensor_slices((train_paths, train_labels))
        .map(load_and_preprocess, num_parallel_calls=tf.data.AUTOTUNE)
        .map(augment, num_parallel_calls=tf.data.AUTOTUNE)
        .shuffle(512, seed=SEED)
        .batch(BATCH_SIZE)
        .prefetch(tf.data.AUTOTUNE)
    )

    val_ds = (
        tf.data.Dataset.from_tensor_slices((val_paths, val_labels))
        .map(load_and_preprocess, num_parallel_calls=tf.data.AUTOTUNE)
        .batch(BATCH_SIZE)
        .prefetch(tf.data.AUTOTUNE)
    )

    return (
        train_ds, val_ds,
        len(train_paths) // BATCH_SIZE,
        len(val_paths)   // BATCH_SIZE,
    )


# ──────────────────────────────────────────────────────────────────────────────
# Model builder
# ──────────────────────────────────────────────────────────────────────────────
def build_model() -> tf.keras.Model:
    base = MobileNetV2(
        input_shape=(*IMG_SIZE, 3),
        include_top=False,
        weights="imagenet",
    )
    base.trainable = False

    model = models.Sequential([
        base,
        layers.GlobalAveragePooling2D(),
        layers.Dropout(0.3),
        layers.Dense(64, activation="relu"),
        layers.Dropout(0.2),
        layers.Dense(1, activation="sigmoid"),   # binary output
    ], name="leaf_detector")

    model.compile(
        optimizer=tf.keras.optimizers.Adam(1e-4),
        loss="binary_crossentropy",
        metrics=["accuracy", tf.keras.metrics.AUC(name="auc")],
    )
    return model


# ──────────────────────────────────────────────────────────────────────────────
# Fine-tune last N layers
# ──────────────────────────────────────────────────────────────────────────────
def fine_tune(model: tf.keras.Model, unfreeze_last: int = 20) -> tf.keras.Model:
    base = model.layers[0]   # MobileNetV2 is layer 0 in Sequential
    base.trainable = True
    for layer in base.layers[:-unfreeze_last]:
        layer.trainable = False

    model.compile(
        optimizer=tf.keras.optimizers.Adam(1e-5),
        loss="binary_crossentropy",
        metrics=["accuracy", tf.keras.metrics.AUC(name="auc")],
    )
    return model


# ──────────────────────────────────────────────────────────────────────────────
# Training history plot
# ──────────────────────────────────────────────────────────────────────────────
def plot_history(histories: list, save_path: str) -> None:
    bg = "#1a1a2e"
    fig, axes = plt.subplots(1, 2, figsize=(12, 4), facecolor=bg)

    all_acc     = []
    all_val_acc = []
    all_loss    = []
    all_val_loss = []

    for h in histories:
        all_acc      += h.history.get("accuracy", [])
        all_val_acc  += h.history.get("val_accuracy", [])
        all_loss     += h.history.get("loss", [])
        all_val_loss += h.history.get("val_loss", [])

    epochs = range(1, len(all_acc) + 1)

    for ax in axes:
        ax.set_facecolor("#16213e")
        ax.tick_params(colors="white")
        ax.xaxis.label.set_color("white")
        ax.yaxis.label.set_color("white")
        ax.title.set_color("white")
        for spine in ax.spines.values():
            spine.set_edgecolor("#444466")

    axes[0].plot(epochs, all_acc,     label="Train Acc",  color="#2ecc71")
    axes[0].plot(epochs, all_val_acc, label="Val Acc",    color="#3498db", linestyle="--")
    axes[0].set_title("Accuracy")
    axes[0].legend(labelcolor="white", facecolor="#222244")

    axes[1].plot(epochs, all_loss,     label="Train Loss", color="#e74c3c")
    axes[1].plot(epochs, all_val_loss, label="Val Loss",   color="#f39c12", linestyle="--")
    axes[1].set_title("Loss")
    axes[1].legend(labelcolor="white", facecolor="#222244")

    fig.suptitle("Leaf Detector – Training History", color="white", fontsize=13)
    plt.tight_layout()
    plt.savefig(save_path, dpi=120, bbox_inches="tight", facecolor=bg)
    print(f"[INFO] Training history plot saved → {save_path}")
    plt.close(fig)


# ──────────────────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────────────────
def main(args) -> None:
    random.seed(SEED)
    np.random.seed(SEED)
    tf.random.set_seed(SEED)

    # ── 1. Collect leaf images ─────────────────────────────────────────────────
    leaf_dir = args.leaf
    if not os.path.isdir(leaf_dir):
        sys.exit(f"[ERROR] Leaf directory not found: {leaf_dir}")
    leaf_paths = collect_images(leaf_dir)
    print(f"[INFO] Found {len(leaf_paths)} leaf images in: {leaf_dir}")

    # ── 2. Collect / create non-leaf images ───────────────────────────────────
    non_leaf_dir = args.non_leaf
    if non_leaf_dir and os.path.isdir(non_leaf_dir):
        non_leaf_paths = collect_images(non_leaf_dir)
        print(f"[INFO] Found {len(non_leaf_paths)} non-leaf images in: {non_leaf_dir}")
    else:
        print("[INFO] No non-leaf folder supplied – generating synthetic negatives …")
        synth_dir = os.path.join(_THIS_DIR, "_synthetic_negatives")
        needed    = len(leaf_paths)
        non_leaf_paths = create_synthetic_negatives(needed, synth_dir)
        print(f"[INFO] Generated {len(non_leaf_paths)} synthetic negative images in: {synth_dir}")

    if len(non_leaf_paths) == 0:
        sys.exit("[ERROR] Could not obtain any non-leaf (negative) images.")

    # ── 3. Build datasets ─────────────────────────────────────────────────────
    train_ds, val_ds, train_steps, val_steps = build_dataset(
        leaf_paths, non_leaf_paths, val_split=0.2
    )
    print(f"[INFO] Train batches: {train_steps}  |  Val batches: {val_steps}")

    # ── 4. Build model ────────────────────────────────────────────────────────
    model = build_model()
    model.summary()

    # ── 5. Phase 1 : frozen base ──────────────────────────────────────────────
    callbacks_1 = [
        EarlyStopping(monitor="val_auc", patience=4, mode="max",
                      restore_best_weights=True, verbose=1),
        ReduceLROnPlateau(monitor="val_loss", factor=0.5, patience=2, verbose=1),
        ModelCheckpoint(args.output, monitor="val_auc", mode="max",
                        save_best_only=True, verbose=1),
    ]

    print("\n[INFO] Phase 1 – Training classifier head (frozen base) …")
    h1 = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=args.epochs,
        callbacks=callbacks_1,
        verbose=1,
    )

    # ── 6. Phase 2 : fine-tune top layers ────────────────────────────────────
    model = fine_tune(model, unfreeze_last=20)

    callbacks_2 = [
        EarlyStopping(monitor="val_auc", patience=5, mode="max",
                      restore_best_weights=True, verbose=1),
        ReduceLROnPlateau(monitor="val_loss", factor=0.5, patience=2, verbose=1),
        ModelCheckpoint(args.output, monitor="val_auc", mode="max",
                        save_best_only=True, verbose=1),
    ]

    print("\n[INFO] Phase 2 – Fine-tuning top layers …")
    h2 = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=max(5, args.epochs // 2),
        callbacks=callbacks_2,
        verbose=1,
    )

    # ── 7. Save & plot ────────────────────────────────────────────────────────
    model.save(args.output)
    print(f"\n[INFO] Leaf detector model saved → {args.output}")

    hist_path = os.path.splitext(args.output)[0] + "_history.png"
    plot_history([h1, h2], hist_path)

    # ── 8. Quick eval ─────────────────────────────────────────────────────────
    results = model.evaluate(val_ds, verbose=0)
    for name, val in zip(model.metrics_names, results):
        print(f"  val_{name}: {val:.4f}")


# ──────────────────────────────────────────────────────────────────────────────
def parse_args():
    parser = argparse.ArgumentParser(
        description="Train MobileNetV2 binary leaf / not-leaf classifier"
    )
    parser.add_argument("--leaf",     "-l", default=DEFAULT_LEAF_DIR,
                        help=f"Folder of leaf images   (default: {DEFAULT_LEAF_DIR})")
    parser.add_argument("--non-leaf", "-n", default=DEFAULT_NON_LEAF_DIR,
                        help="Folder of non-leaf images (default: auto-generate)")
    parser.add_argument("--output",   "-o", default=DEFAULT_OUTPUT,
                        help=f"Output model path        (default: {DEFAULT_OUTPUT})")
    parser.add_argument("--epochs",   "-e", type=int, default=10,
                        help="Training epochs for phase 1 (default: 10)")
    return parser.parse_args()


if __name__ == "__main__":
    main(parse_args())
