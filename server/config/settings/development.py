"""
Midori — Development settings.
Used locally. Never deploy this to production.
"""
from .base import *  # noqa: F401, F403

DEBUG = True

CORS_ALLOW_ALL_ORIGINS = True

# Verbose ML logging in dev
LOGGING["loggers"]["detections"]["level"] = "DEBUG"  # noqa: F405
