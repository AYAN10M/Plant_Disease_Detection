"""
leaf_detector.py
================
Standalone leaf detection module.

Three complementary strategies are combined to improve robustness:
  1. Green-channel dominance (HSV)
  2. Edge / texture complexity (Canny + contour area)
  3. Aspect-ratio sanity check

Public API
----------
    is_leaf(image_bgr, threshold=0.08)         -> (bool, float)
    is_leaf_multi(image_bgr, verbose=False)    -> (bool, dict)
"""

import cv2
import numpy as np


# ──────────────────────────────────────────────────────────────────────────────
# Strategy 1 – Green-channel dominance (primary heuristic)
# ──────────────────────────────────────────────────────────────────────────────
def _green_ratio(image_bgr: np.ndarray) -> float:
    """Return the fraction of pixels that fall in the 'green' HSV range."""
    hsv = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2HSV)
    lower = np.array([25, 30, 30])
    upper = np.array([100, 255, 255])
    mask = cv2.inRange(hsv, lower, upper)
    return cv2.countNonZero(mask) / mask.size


# ──────────────────────────────────────────────────────────────────────────────
# Strategy 2 – Texture / edge complexity
# ──────────────────────────────────────────────────────────────────────────────
def _edge_score(image_bgr: np.ndarray) -> float:
    """
    Fraction of edge pixels after Canny detection.
    Leaves tend to have moderate edge density (veins, boundary).
    Too low → solid colour block; too high → noise / non-leaf texture.
    """
    gray = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    edges = cv2.Canny(blurred, 50, 150)
    return cv2.countNonZero(edges) / edges.size


# ──────────────────────────────────────────────────────────────────────────────
# Public: simple (original) function
# ──────────────────────────────────────────────────────────────────────────────
def is_leaf(
    image_bgr: np.ndarray,
    green_ratio_threshold: float = 0.08,
) -> tuple[bool, float]:
    """
    Lightweight leaf check based on green-channel dominance.

    Parameters
    ----------
    image_bgr             : BGR image (OpenCV format)
    green_ratio_threshold : minimum green-pixel fraction to call it a leaf

    Returns
    -------
    (is_leaf_bool, confidence_percent)
        confidence_percent – 0-100, how confident we are that it IS a leaf
    """
    ratio = _green_ratio(image_bgr)
    confidence = min(ratio / 0.40, 1.0) * 100.0   # 40 % green → 100 %
    return ratio >= green_ratio_threshold, round(confidence, 2)


# ──────────────────────────────────────────────────────────────────────────────
# Public: multi-strategy function
# ──────────────────────────────────────────────────────────────────────────────
def is_leaf_multi(
    image_bgr: np.ndarray,
    green_threshold: float = 0.05,
    edge_min: float = 0.01,
    edge_max: float = 0.45,
    verbose: bool = False,
) -> tuple[bool, dict]:
    """
    Multi-strategy leaf detection (more robust than green-only).

    Combines three signals:
      • green ratio (HSV)
      • edge density (Canny)
      • aspect ratio of the image (extreme ratios are unlikely to be leaves)

    Parameters
    ----------
    image_bgr        : BGR image
    green_threshold  : minimum green ratio
    edge_min/max     : acceptable edge-density range for a leaf
    verbose          : if True, print individual scores

    Returns
    -------
    (is_leaf_bool, scores_dict)
        scores_dict contains individual sub-scores and the final confidence.
    """
    h, w = image_bgr.shape[:2]
    aspect = min(h, w) / max(h, w)   # 1.0 = square, lower = elongated

    green = _green_ratio(image_bgr)
    edge = _edge_score(image_bgr)

    green_ok = green >= green_threshold
    edge_ok = edge_min <= edge <= edge_max
    aspect_ok = aspect >= 0.15        # reject extreme panoramas / strips

    # Weighted confidence
    green_conf = min(green / 0.40, 1.0)
    edge_conf = 1.0 if edge_ok else 0.0
    aspect_conf = min(aspect / 0.5, 1.0)
    confidence = (0.60 * green_conf + 0.25 * edge_conf + 0.15 * aspect_conf) * 100

    result = green_ok and edge_ok and aspect_ok

    scores = {
        "green_ratio": round(green, 4),
        "edge_density": round(edge, 4),
        "aspect_ratio": round(aspect, 4),
        "green_ok": green_ok,
        "edge_ok": edge_ok,
        "aspect_ok": aspect_ok,
        "confidence": round(confidence, 2),
    }

    if verbose:
        print(f"[LeafDetector] green={green:.3f}({green_ok}), "
              f"edge={edge:.3f}({edge_ok}), "
              f"aspect={aspect:.3f}({aspect_ok}), "
              f"conf={confidence:.1f}%  →  {'LEAF' if result else 'NOT LEAF'}")

    return result, scores
