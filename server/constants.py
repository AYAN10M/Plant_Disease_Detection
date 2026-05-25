"""
Midori — Application-wide constants
=====================================
Import with:
    from constants import PLANT_CONF_THRESHOLD, DISEASE_CONF_THRESHOLD, ...
"""

# ── Detection thresholds ──────────────────────────────────────────────────────

PLANT_CONF_THRESHOLD   = 40.0   # Stage-1 : below this % → status = not_recognized
DISEASE_CONF_THRESHOLD = 40.0   # Stage-2 : below this % → status = low_confidence

# Legacy alias used in a few older scripts
CONFIDENCE_THRESHOLD = DISEASE_CONF_THRESHOLD / 100.0  # 0.40 (0–1 scale)

# ── User-facing messages ──────────────────────────────────────────────────────

HEALTHY_MESSAGE = (
    "Your plant looks healthy! No signs of disease were detected. "
    "Keep up the good care! 🌱"
)

LOW_CONFIDENCE_MESSAGE = (
    "Disease detection confidence is too low for a reliable diagnosis. "
    "Please retake the photo in good lighting with the affected leaf filling the frame."
)

NOT_RECOGNIZED_MESSAGE = (
    "Could not confidently identify the plant. "
    "Please take a clear, close-up photo of the leaf against a plain background."
)

NO_MODEL_MESSAGE = (
    "The plant was identified but no disease model is available for it yet. "
    "Supported plants for disease detection: Apple, Potato, Grape, Pepper."
)

# ── Misc ──────────────────────────────────────────────────────────────────────

MAX_DETECTION_HISTORY = 50   # Flutter-side history cap (matches history_service.dart)
