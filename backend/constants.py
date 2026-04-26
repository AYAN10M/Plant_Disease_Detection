"""
PhytoScan — Application-wide constants.
Import these instead of scattering magic numbers across views.
"""

# ── Detection ────────────────────────────────────────────────────────────────
CONFIDENCE_THRESHOLD = 0.60          # below this → prompt user to retake photo
LOW_CONFIDENCE_MESSAGE = (
    "Confidence is too low. Please retake the photo in better lighting "
    "and make sure the affected part of the plant is clearly visible."
)
MAX_DETECTION_HISTORY = 50           # max records kept per user

# ── Dashboard ────────────────────────────────────────────────────────────────
DASHBOARD_TREND_DAYS = 7             # number of days shown in the trend chart
DASHBOARD_RECENT_COUNT = 5           # recent detections shown on dashboard

# ── Weather / Disease Risk ───────────────────────────────────────────────────
WEATHER_HIGH_HUMIDITY_THRESHOLD = 80   # % — above this, raise fungal risk
WEATHER_HIGH_TEMP_THRESHOLD = 35       # °C — above this, raise heat stress risk
WEATHER_LOW_TEMP_THRESHOLD = 5        # °C — below this, raise frost risk
