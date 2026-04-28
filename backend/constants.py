"""
Midori — Application-wide constants.
Import these instead of scattering magic numbers across views.
"""

# ── Detection ────────────────────────────────────────────────────────────────
CONFIDENCE_THRESHOLD  = 0.60          # below this → prompt user to retake photo
NOT_A_PLANT_THRESHOLD = 0.25          # below this (after temperature scaling) → not a plant
                                       # Must stay in sync with ml_model.NOT_A_PLANT_THRESHOLD

LOW_CONFIDENCE_MESSAGE = (
    "Confidence is too low. Please retake the photo in better lighting "
    "and make sure the affected part of the plant is clearly visible."
)

NOT_A_PLANT_MESSAGE = (
    "The image doesn't appear to be a plant leaf. "
    "Please take a clear, close-up photo of a plant leaf and try again."
)

MAX_DETECTION_HISTORY = 50           # max records kept per user
