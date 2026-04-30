"""
gradcam_utils.py
================
Reusable Grad-CAM utilities for MobileNetV2-based Keras models.

Public API
----------
    make_gradcam_heatmap(img_array, model, pred_index=None) -> np.ndarray
    overlay_gradcam(original_bgr, heatmap, alpha=0.45)      -> np.ndarray
    get_last_conv_layer(model)                               -> str
    save_heatmap(heatmap, path)                              -> None
"""

import cv2
import numpy as np
import tensorflow as tf
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


# ──────────────────────────────────────────────────────────────────────────────
def get_last_conv_layer(model: tf.keras.Model) -> str:
    """
    Recursively walk nested sub-models to find the last Conv2D layer name.

    MobileNetV2 is embedded as a Sequential sub-model, so a simple
    ``model.layers`` loop would miss it.
    """
    last_name = None

    def _search(m: tf.keras.Model):
        nonlocal last_name
        for layer in m.layers:
            if hasattr(layer, "layers"):        # nested model
                _search(layer)
            elif isinstance(layer, tf.keras.layers.Conv2D):
                last_name = layer.name

    _search(model)
    if last_name is None:
        raise RuntimeError(
            "No Conv2D layer found inside the model. "
            "Grad-CAM requires at least one convolutional layer."
        )
    return last_name


# ──────────────────────────────────────────────────────────────────────────────
def _find_layer_by_name(model: tf.keras.Model, name: str):
    """Recursively search for a layer by name inside nested models."""
    for layer in model.layers:
        if layer.name == name:
            return layer
        if hasattr(layer, "layers"):
            found = _find_layer_by_name(layer, name)
            if found is not None:
                return found
    return None


# ──────────────────────────────────────────────────────────────────────────────
def make_gradcam_heatmap(
    img_array: np.ndarray,
    model: tf.keras.Model,
    pred_index: int | None = None,
    conv_layer_name: str | None = None,
) -> np.ndarray:
    """
    Compute a Grad-CAM heatmap.

    Parameters
    ----------
    img_array        : pre-processed image batch, shape (1, H, W, 3)
    model            : compiled Keras model
    pred_index       : class index to explain; None → top-1 prediction
    conv_layer_name  : target conv layer; None → auto-detect last Conv2D

    Returns
    -------
    heatmap : float32 ndarray, shape (h, w), values in [0, 1]
    """
    if conv_layer_name is None:
        conv_layer_name = get_last_conv_layer(model)

    conv_layer = _find_layer_by_name(model, conv_layer_name)
    if conv_layer is None:
        raise ValueError(f"Layer '{conv_layer_name}' not found in model.")

    # Sub-model that returns (conv_output, final_logits)
    grad_model = tf.keras.models.Model(
        inputs=model.inputs,
        outputs=[conv_layer.output, model.output],
    )

    with tf.GradientTape() as tape:
        inputs = tf.cast(img_array, tf.float32)
        conv_outputs, predictions = grad_model(inputs)
        if pred_index is None:
            pred_index = int(tf.argmax(predictions[0]))
        class_channel = predictions[:, pred_index]

    grads = tape.gradient(class_channel, conv_outputs)   # (1, h, w, c)
    pooled_grads = tf.reduce_mean(grads, axis=(0, 1, 2)) # (c,)

    conv_outputs = conv_outputs[0]                        # (h, w, c)
    heatmap = conv_outputs @ pooled_grads[..., tf.newaxis]  # (h, w, 1)
    heatmap = tf.squeeze(heatmap)                         # (h, w)

    heatmap = tf.maximum(heatmap, 0)
    heatmap = heatmap / (tf.reduce_max(heatmap) + 1e-8)
    return heatmap.numpy().astype(np.float32)


# ──────────────────────────────────────────────────────────────────────────────
def overlay_gradcam(
    original_bgr: np.ndarray,
    heatmap: np.ndarray,
    alpha: float = 0.45,
    colormap: int = cv2.COLORMAP_JET,
) -> np.ndarray:
    """
    Blend a Grad-CAM heatmap over the original BGR image.

    Parameters
    ----------
    original_bgr : original image in BGR format
    heatmap      : float32 array in [0, 1]
    alpha        : blend weight for the heatmap  (0 = invisible, 1 = full)
    colormap     : OpenCV colormap constant

    Returns
    -------
    blended BGR image, same spatial size as original_bgr
    """
    h, w = original_bgr.shape[:2]
    heatmap_resized = cv2.resize(heatmap, (w, h))
    heatmap_uint8 = np.uint8(255 * heatmap_resized)
    colored = cv2.applyColorMap(heatmap_uint8, colormap)
    blended = cv2.addWeighted(original_bgr, 1 - alpha, colored, alpha, 0)
    return blended


# ──────────────────────────────────────────────────────────────────────────────
def save_heatmap(
    heatmap: np.ndarray,
    path: str,
    colormap: int = cv2.COLORMAP_JET,
) -> None:
    """
    Save just the raw heatmap (no blending) as a coloured image file.

    Parameters
    ----------
    heatmap  : float32 array in [0, 1]
    path     : output file path (e.g. 'heatmap.png')
    colormap : OpenCV colormap constant
    """
    heatmap_uint8 = np.uint8(255 * heatmap)
    colored = cv2.applyColorMap(heatmap_uint8, colormap)
    cv2.imwrite(path, colored)
    print(f"[INFO] Heatmap saved → {path}")


# ──────────────────────────────────────────────────────────────────────────────
def plot_gradcam(
    original_bgr: np.ndarray,
    overlay_bgr: np.ndarray,
    title: str = "Grad-CAM",
    save_path: str | None = None,
) -> None:
    """
    Display (or save) a side-by-side comparison of original vs Grad-CAM overlay.
    """
    fig, axes = plt.subplots(1, 2, figsize=(10, 4), facecolor="#1a1a2e")
    for ax in axes:
        ax.axis("off")
        ax.set_facecolor("#16213e")

    axes[0].imshow(cv2.cvtColor(original_bgr, cv2.COLOR_BGR2RGB))
    axes[0].set_title("Original", color="white", fontsize=11)

    axes[1].imshow(cv2.cvtColor(overlay_bgr, cv2.COLOR_BGR2RGB))
    axes[1].set_title("Grad-CAM Overlay", color="white", fontsize=11)

    fig.suptitle(title, color="white", fontsize=13, fontweight="bold")
    plt.tight_layout()

    if save_path:
        plt.savefig(save_path, dpi=120, bbox_inches="tight", facecolor="#1a1a2e")
        print(f"[INFO] Grad-CAM plot saved → {save_path}")
    else:
        plt.show()

    plt.close(fig)
