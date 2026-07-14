"""Application-wide constants."""

# Model architecture  (matches 14-07-26 notebook)
STAGE1_MODEL = "EfficientNet"
STAGE2_MODEL = "MobileNetV2"

# Confidence threshold  (matches notebook CONFIDENCE_THRESHOLD = 0.55)
CONFIDENCE_THRESHOLD = 0.55

# User-facing messages
HEALTHY_MESSAGE = "Your plant looks healthy! No signs of disease were detected."

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
    "Supported: Apple, Corn, Grape, Pepper, Potato, Strawberry."
)

MAX_DETECTION_HISTORY = 50
