"""
Midori — Production settings.
Set DJANGO_SETTINGS_MODULE=core.settings.production in your server env.
"""
from .base import *  # noqa: F401, F403
import os

DEBUG = False

CORS_ALLOWED_ORIGINS = [
    o.strip() for o in os.getenv('CORS_ALLOWED_ORIGINS', '').split(',') if o.strip()
]

# Secure cookies in production
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE    = True
SECURE_HSTS_SECONDS   = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
