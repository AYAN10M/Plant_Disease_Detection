"""Development settings."""
from .base import *  # noqa: F401, F403

DEBUG = True
CORS_ALLOW_ALL_ORIGINS = True
LOGGING["loggers"]["detections"]["level"] = "DEBUG"  # noqa: F405
