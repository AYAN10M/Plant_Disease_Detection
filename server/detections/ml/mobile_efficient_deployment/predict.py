"""
Plant Disease Detector with GradCAM Visualization
==================================================
Pipeline:
  1. Leaf / Not-Leaf check
       → Uses trained leaf_detector.keras if present (recommended)
       → Falls back to a green-channel HSV heuristic otherwise
  2. MobileNetV2 38-class disease classification
  3. Grad-CAM heatmap overlay on the original image
  4. Confidence % for healthy vs diseased predictions

Train the leaf detector first (one-time step):
    python train_leaf_detector.py

Usage:
    python predict.py --image path/to/leaf.jpg
    python predict.py --image path/to/leaf.jpg --output result.jpg
"""

import argparse
import os
import sys

import cv2
import numpy as np
import tensorflow as tf
import matplotlib
matplotlib.use("Agg")          # headless backend – safe on servers
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

# ──────────────────────────────────────────────────────────────────────────────
# 1.  CLASS MAP  (38 plant-disease classes from PlantVillage-style dataset)
# ──────────────────────────────────────────────────────────────────────────────
CLASS_NAMES = [
    "Apple_Apple_scab",
    "Apple_Black_rot",
    "Apple_Cedar_apple_rust",
    "Apple_healthy",
    "Cherry_healthy",
    "Cherry_Powdery_mildew",  # trained as Cherry_mildew in dataset
    "Corn_Northern_Leaf_Blight",  # trained as Corn_Blight in dataset
    "Corn_Cercospora_leaf_spot Gray_leaf_spot",
    "Corn_Common_rust",
    "Corn_healthy",
    "Grape_Black_rot",
    "Grape_Esca_(Black_Measles)",
    "Grape_Leaf_blight_(Isariopsis_Leaf_Spot)",
    "Grape_healthy",
    "Peach_Bacterial_spot",
    "Peach_healthy",
    "Pepper_bell_Bacterial_spot",
    "Pepper_bell_healthy",
    "Potato_Early_blight",
    "Potato_Late_blight",
    "Potato_healthy",
    "Rice_Bacterialblight",
    "Rice_Blast",
    "Rice_Brownspot",
    "Rice_Healthy",
    "Rice_Tungro",
    "Strawberry_Leaf_scorch",
    "Strawberry_healthy",
    "Tomato_Bacterial_spot",
    "Tomato_Early_blight",
    "Tomato_Late_blight",
    "Tomato_Leaf_Mold",
    "Tomato_Septoria_leaf_spot",
    "Tomato_Spider_mites Two-spotted_spider_mite",
    "Tomato_Target_Spot",
    "Tomato_Tomato_Yellow_Leaf_Curl_Virus",
    "Tomato_Tomato_mosaic_virus",
    "Tomato_healthy",
]

HEALTHY_KEYWORDS = {"healthy", "Healthy"}


def is_healthy_class(class_name: str) -> bool:
    return any(kw in class_name for kw in HEALTHY_KEYWORDS)


# ──────────────────────────────────────────────────────────────────────────────
# 2.  MODEL PATHS
# ──────────────────────────────────────────────────────────────────────────────
_THIS_DIR = os.path.dirname(os.path.abspath(__file__))

MODEL_PATH = os.path.join(_THIS_DIR, "plant_disease_mobilenet.h5")

# Leaf detector: trained binary model (leaf vs not-leaf)
# Run `python train_leaf_detector.py` once to generate this.
LEAF_MODEL_PATH = os.path.join(_THIS_DIR, "leaf_detector.keras")


def load_model(model_path: str = MODEL_PATH) -> tf.keras.Model:
    """Load the saved MobileNetV2-based disease model."""
    if not os.path.exists(model_path):
        sys.exit(
            f"[ERROR] Model not found at: {model_path}\n"
            "Please place 'plant_disease_mobilenet.h5' in the parent directory."
        )
    print(f"[INFO] Loading disease model from: {model_path}")
    model = tf.keras.models.load_model(model_path)
    print("[INFO] Disease model loaded successfully.")
    return model


# Lazy-loaded leaf detector (populated on first call to is_leaf)
_leaf_detector_model: tf.keras.Model | None = None
_leaf_detector_loaded: bool = False


def _try_load_leaf_detector() -> tf.keras.Model | None:
    """
    Attempt to load the trained leaf detector model.
    Returns None if the model file does not exist yet (falls back to heuristic).
    Caches the result after the first call.
    """
    global _leaf_detector_model, _leaf_detector_loaded
    if _leaf_detector_loaded:
        return _leaf_detector_model
    _leaf_detector_loaded = True
    if os.path.exists(LEAF_MODEL_PATH):
        print(f"[INFO] Loading leaf detector model from: {LEAF_MODEL_PATH}")
        _leaf_detector_model = tf.keras.models.load_model(LEAF_MODEL_PATH)
        print("[INFO] Leaf detector model loaded (trained binary classifier).")
    else:
        print(
            "[WARN] Leaf detector model not found at:\n"
            f"       {LEAF_MODEL_PATH}\n"
            "       Falling back to green-channel heuristic.\n"
            "       Run 'python train_leaf_detector.py' to train it."
        )
    return _leaf_detector_model


# ──────────────────────────────────────────────────────────────────────────────
# 3.  LEAF DETECTION
#     Priority: trained binary model  →  green-channel heuristic (fallback)
# ──────────────────────────────────────────────────────────────────────────────
def _heuristic_is_leaf(
    image_bgr: np.ndarray,
    green_ratio_threshold: float = 0.08,
) -> tuple[bool, float]:
    """Green-channel HSV heuristic (fallback when trained model is absent)."""
    hsv = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2HSV)
    lower_green = np.array([25, 30, 30])
    upper_green = np.array([100, 255, 255])
    mask = cv2.inRange(hsv, lower_green, upper_green)
    ratio = cv2.countNonZero(mask) / mask.size
    confidence = min(ratio / 0.40, 1.0) * 100.0
    return ratio >= green_ratio_threshold, round(confidence, 2)


def is_leaf(
    image_bgr: np.ndarray,
    green_ratio_threshold: float = 0.08,
    model_threshold: float = 0.50,
) -> tuple[bool, float]:
    """
    Determine whether the image contains a leaf.

    Strategy (in order of preference)
    -----------------------------------
    1. Trained binary classifier (leaf_detector.keras) if available.
       - More robust to non-green leaves, unusual backgrounds & lighting.
    2. Green-channel HSV heuristic (fast, no model required).

    Parameters
    ----------
    image_bgr             : OpenCV BGR image
    green_ratio_threshold : Used only by the heuristic fallback.
    model_threshold       : Sigmoid probability threshold for the trained model.

    Returns
    -------
    (is_leaf_bool, confidence_percent)
    """
    leaf_model = _try_load_leaf_detector()

    if leaf_model is not None:
        # ── Trained model path ─────────────────────────────────────────────
        rgb     = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
        resized = cv2.resize(rgb, IMG_SIZE).astype(np.float32)
        batch   = np.expand_dims(resized, axis=0)
        batch   = tf.keras.applications.mobilenet_v2.preprocess_input(batch)
        prob    = float(leaf_model.predict(batch, verbose=0)[0][0])
        result  = prob >= model_threshold
        confidence = round(prob * 100.0, 2)
        return result, confidence
    else:
        # ── Heuristic fallback ─────────────────────────────────────────────
        return _heuristic_is_leaf(image_bgr, green_ratio_threshold)


# ──────────────────────────────────────────────────────────────────────────────
# 4.  IMAGE PREPROCESSING
# ──────────────────────────────────────────────────────────────────────────────
IMG_SIZE = (224, 224)


def preprocess_image(image_bgr: np.ndarray) -> np.ndarray:
    """Resize + MobileNetV2 preprocess_input → batch of 1."""
    rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    resized = cv2.resize(rgb, IMG_SIZE)
    arr = np.expand_dims(resized.astype(np.float32), axis=0)
    return tf.keras.applications.mobilenet_v2.preprocess_input(arr)


# ──────────────────────────────────────────────────────────────────────────────
# 5.  GRAD-CAM
# ──────────────────────────────────────────────────────────────────────────────
def get_last_conv_layer(model: tf.keras.Model) -> str:
    """
    Walk the model (including nested sub-models) to find the last
    Conv2D layer name – used as the Grad-CAM target.
    """
    last_conv_name = None

    def _search(m):
        nonlocal last_conv_name
        for layer in m.layers:
            if hasattr(layer, "layers"):       # nested model (e.g. MobileNetV2 base)
                _search(layer)
            elif isinstance(layer, tf.keras.layers.Conv2D):
                last_conv_name = layer.name

    _search(model)
    return last_conv_name


def make_gradcam_heatmap(
    img_array: np.ndarray,
    model: tf.keras.Model,
    pred_index: int | None = None,
) -> np.ndarray:
    """
    Compute a Grad-CAM heatmap for the given image and class index.

    Parameters
    ----------
    img_array   : preprocessed batch (1, 224, 224, 3)
    model       : full Keras model
    pred_index  : class index to explain (None → top prediction)

    Returns
    -------
    heatmap     : float32 array shaped (H, W) in [0, 1]
    """
    # ── Build a sub-model that outputs (conv_features, final_logits) ──────────
    last_conv_layer_name = get_last_conv_layer(model)
    if last_conv_layer_name is None:
        raise RuntimeError("Could not find any Conv2D layer in the model.")

    # We need to trace through the nested MobileNetV2 base to find the layer
    # object – tf.keras.Model.get_layer() searches only one level deep.
    def _find_layer(m, name):
        for layer in m.layers:
            if layer.name == name:
                return layer
            if hasattr(layer, "layers"):
                result = _find_layer(layer, name)
                if result is not None:
                    return result
        return None

    last_conv_layer = _find_layer(model, last_conv_layer_name)

    # Build grad model using GradientTape
    grad_model = tf.keras.models.Model(
        inputs=model.inputs,
        outputs=[last_conv_layer.output, model.output],
    )

    with tf.GradientTape() as tape:
        inputs = tf.cast(img_array, tf.float32)
        conv_outputs, predictions = grad_model(inputs)
        if pred_index is None:
            pred_index = tf.argmax(predictions[0])
        class_channel = predictions[:, pred_index]

    grads = tape.gradient(class_channel, conv_outputs)           # (1, H, W, C)
    pooled_grads = tf.reduce_mean(grads, axis=(0, 1, 2))         # (C,)

    conv_outputs = conv_outputs[0]                               # (H, W, C)
    heatmap = conv_outputs @ pooled_grads[..., tf.newaxis]       # (H, W, 1)
    heatmap = tf.squeeze(heatmap)                                # (H, W)

    # Normalise to [0, 1]
    heatmap = tf.maximum(heatmap, 0) / (tf.math.reduce_max(heatmap) + 1e-8)
    return heatmap.numpy()


def overlay_gradcam(
    original_bgr: np.ndarray,
    heatmap: np.ndarray,
    alpha: float = 0.45,
) -> np.ndarray:
    """
    Blend a Grad-CAM heatmap over the original image.

    Returns
    -------
    blended BGR image (same size as original_bgr)
    """
    h, w = original_bgr.shape[:2]
    heatmap_resized = cv2.resize(heatmap, (w, h))

    # Apply JET colormap
    heatmap_uint8 = np.uint8(255 * heatmap_resized)
    colormap = cv2.applyColorMap(heatmap_uint8, cv2.COLORMAP_JET)

    # Overlay
    blended = cv2.addWeighted(original_bgr, 1 - alpha, colormap, alpha, 0)
    return blended


# ──────────────────────────────────────────────────────────────────────────────
# 6.  FULL PREDICTION PIPELINE
# ──────────────────────────────────────────────────────────────────────────────
def predict(
    image_path: str,
    model: tf.keras.Model,
    output_path: str | None = None,
    leaf_threshold: float = 0.08,
) -> dict:
    """
    Run the full leaf→disease→GradCAM pipeline.

    Returns a dict with all results.
    """
    # ── Load image ─────────────────────────────────────────────────────────────
    image_bgr = cv2.imread(image_path)
    if image_bgr is None:
        sys.exit(f"[ERROR] Cannot read image: {image_path}")

    results = {}

    # ── Step 1 : Leaf check ────────────────────────────────────────────────────
    leaf_detected, leaf_confidence = is_leaf(image_bgr, leaf_threshold)
    results["is_leaf"] = leaf_detected
    results["leaf_confidence"] = leaf_confidence

    if not leaf_detected:
        print(f"\n{'='*60}")
        print("  RESULT: NOT A LEAF")
        print(f"  Leaf confidence : {leaf_confidence:.1f}%")
        print(f"{'='*60}\n")
        results["status"] = "not_a_leaf"
        return results

    print(f"\n[INFO] Leaf detected  (confidence: {leaf_confidence:.1f}%)")

    # ── Step 2 : Disease classification ───────────────────────────────────────
    img_array = preprocess_image(image_bgr)
    preds = model.predict(img_array, verbose=0)[0]          # (38,)

    top_idx = int(np.argmax(preds))
    top_conf = float(preds[top_idx]) * 100.0
    top_class = CLASS_NAMES[top_idx]
    healthy = is_healthy_class(top_class)

    plant_name, *condition_parts = top_class.split("_", 1)
    condition = condition_parts[0].replace("_", " ") if condition_parts else top_class

    # Top-3 for display
    top3_indices = np.argsort(preds)[::-1][:3]
    top3 = [(CLASS_NAMES[i], round(float(preds[i]) * 100, 2)) for i in top3_indices]

    results.update(
        {
            "status": "healthy" if healthy else "diseased",
            "predicted_class": top_class,
            "plant": plant_name,
            "condition": condition,
            "confidence": round(top_conf, 2),
            "is_healthy": healthy,
            "top3": top3,
        }
    )

    # ── Step 3 : Grad-CAM ─────────────────────────────────────────────────────
    heatmap = make_gradcam_heatmap(img_array, model, pred_index=top_idx)
    overlay = overlay_gradcam(image_bgr, heatmap)
    results["gradcam_overlay"] = overlay      # BGR ndarray

    # ── Print summary ─────────────────────────────────────────────────────────
    status_label = "HEALTHY ✓" if healthy else "DISEASED ✗"
    print(f"\n{'='*60}")
    print(f"  RESULT: {status_label}")
    print(f"  Plant      : {plant_name}")
    print(f"  Condition  : {condition}")
    print(f"  Confidence : {top_conf:.1f}%")
    print(f"\n  Top-3 predictions:")
    for cls, conf in top3:
        print(f"    • {cls:<50}  {conf:6.2f}%")
    print(f"{'='*60}\n")

    # ── Save / display figure ─────────────────────────────────────────────────
    if output_path or True:   # always build the figure
        _save_figure(image_bgr, overlay, heatmap, results, output_path)

    return results


# ──────────────────────────────────────────────────────────────────────────────
# 7.  FIGURE BUILDER
# ──────────────────────────────────────────────────────────────────────────────
def _save_figure(
    original_bgr: np.ndarray,
    overlay_bgr: np.ndarray,
    heatmap: np.ndarray,
    results: dict,
    output_path: str | None,
) -> None:
    """Compose and save (or display) a 3-panel result figure."""
    orig_rgb = cv2.cvtColor(original_bgr, cv2.COLOR_BGR2RGB)
    overlay_rgb = cv2.cvtColor(overlay_bgr, cv2.COLOR_BGR2RGB)

    is_healthy = results.get("is_healthy", False)
    confidence = results.get("confidence", 0.0)
    plant = results.get("plant", "Unknown")
    condition = results.get("condition", "Unknown")
    top3 = results.get("top3", [])

    accent = "#2ecc71" if is_healthy else "#e74c3c"
    bg_color = "#1a1a2e"
    panel_color = "#16213e"

    fig = plt.figure(figsize=(16, 6), facecolor=bg_color)
    fig.subplots_adjust(left=0.04, right=0.96, top=0.88, bottom=0.10, wspace=0.08)

    # ── Panel 1 : Original ────────────────────────────────────────────────────
    ax1 = fig.add_subplot(1, 3, 1)
    ax1.imshow(orig_rgb)
    ax1.set_title("Original Image", color="white", fontsize=11, pad=6)
    ax1.axis("off")
    ax1.set_facecolor(panel_color)

    # ── Panel 2 : Grad-CAM overlay ────────────────────────────────────────────
    ax2 = fig.add_subplot(1, 3, 2)
    im = ax2.imshow(overlay_rgb)
    ax2.set_title("Grad-CAM Heatmap", color="white", fontsize=11, pad=6)
    ax2.axis("off")
    ax2.set_facecolor(panel_color)

    # Colourbar
    cbar = plt.colorbar(
        plt.cm.ScalarMappable(cmap="jet"),
        ax=ax2, fraction=0.046, pad=0.04,
    )
    cbar.set_label("Activation intensity", color="white", fontsize=8)
    cbar.ax.yaxis.set_tick_params(color="white")
    plt.setp(cbar.ax.yaxis.get_ticklabels(), color="white")

    # ── Panel 3 : Results card ────────────────────────────────────────────────
    ax3 = fig.add_subplot(1, 3, 3)
    ax3.set_facecolor(panel_color)
    ax3.axis("off")

    status_text = "✓  HEALTHY" if is_healthy else "✗  DISEASED"
    ax3.text(
        0.5, 0.94, status_text,
        color=accent, fontsize=18, fontweight="bold",
        ha="center", va="top", transform=ax3.transAxes,
    )
    ax3.text(
        0.5, 0.80, f"Plant: {plant}",
        color="white", fontsize=12, ha="center", va="top",
        transform=ax3.transAxes,
    )
    ax3.text(
        0.5, 0.70, f"Condition: {condition}",
        color="#cccccc", fontsize=10, ha="center", va="top",
        transform=ax3.transAxes, wrap=True,
    )

    # Confidence bar
    bar_y = 0.52
    ax3.text(
        0.5, bar_y + 0.08,
        f"Confidence: {confidence:.1f}%",
        color="white", fontsize=11, ha="center", va="top",
        transform=ax3.transAxes,
    )
    ax3.add_patch(
        mpatches.FancyBboxPatch(
            (0.05, bar_y - 0.035), 0.90, 0.04,
            boxstyle="round,pad=0.01", linewidth=0,
            facecolor="#333355", transform=ax3.transAxes,
        )
    )
    ax3.add_patch(
        mpatches.FancyBboxPatch(
            (0.05, bar_y - 0.035), 0.90 * confidence / 100, 0.04,
            boxstyle="round,pad=0.01", linewidth=0,
            facecolor=accent, transform=ax3.transAxes,
        )
    )

    # Top-3 table
    ax3.text(
        0.05, 0.38, "Top-3 Predictions:",
        color="#aaaaaa", fontsize=9, va="top", transform=ax3.transAxes,
    )
    for rank, (cls, conf) in enumerate(top3):
        y_pos = 0.30 - rank * 0.09
        cls_short = cls.replace("_", " ")
        ax3.text(
            0.05, y_pos, f"{rank+1}. {cls_short}",
            color="white", fontsize=8, va="top", transform=ax3.transAxes,
        )
        ax3.text(
            0.95, y_pos, f"{conf:.1f}%",
            color=accent if rank == 0 else "#aaaaaa",
            fontsize=8, va="top", ha="right", transform=ax3.transAxes,
        )

    # ── Super-title ───────────────────────────────────────────────────────────
    fig.suptitle(
        "🌿  Plant Disease Detector  –  MobileNetV2 + Grad-CAM",
        color="white", fontsize=14, fontweight="bold", y=0.97,
    )

    # ── Save ──────────────────────────────────────────────────────────────────
    if output_path is None:
        base = os.path.splitext(os.path.basename(
            results.get("input_path", "output")
        ))[0]
        output_path = f"{base}_gradcam_result.jpg"

    plt.savefig(output_path, dpi=150, bbox_inches="tight", facecolor=bg_color)
    print(f"[INFO] Result figure saved → {output_path}")
    plt.close(fig)


# ──────────────────────────────────────────────────────────────────────────────
# 8.  CLI ENTRYPOINT
# ──────────────────────────────────────────────────────────────────────────────
def parse_args():
    parser = argparse.ArgumentParser(
        description="Plant Disease Detector with MobileNetV2 + Grad-CAM"
    )
    parser.add_argument(
        "--image", "-i", required=True,
        help="Path to the input image (jpg/png/…)",
    )
    parser.add_argument(
        "--model", "-m", default=MODEL_PATH,
        help=f"Path to the .h5 model file (default: {MODEL_PATH})",
    )
    parser.add_argument(
        "--output", "-o", default=None,
        help="Path to save the result figure (default: <image>_gradcam_result.jpg)",
    )
    parser.add_argument(
        "--leaf-threshold", type=float, default=0.08,
        help="Minimum green-pixel ratio to accept image as a leaf (default: 0.08)",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()

    # Resolve output path
    out = args.output
    if out is None:
        base = os.path.splitext(os.path.basename(args.image))[0]
        out = os.path.join(
            os.path.dirname(os.path.abspath(args.image)),
            f"{base}_gradcam_result.jpg",
        )

    model = load_model(args.model)
    results = predict(
        image_path=args.image,
        model=model,
        output_path=out,
        leaf_threshold=args.leaf_threshold,
    )
    results["input_path"] = args.image
