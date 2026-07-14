"""Production settings."""
from .base import *  # noqa: F401, F403
import os

DEBUG = False

if SECRET_KEY == "change-me-in-production":  # noqa: F405
    raise ValueError("Set a strong SECRET_KEY in your environment variables before deploying.")

CORS_ALLOW_ALL_ORIGINS = False
CORS_ALLOWED_ORIGINS = [
    o.strip() for o in os.getenv('CORS_ALLOWED_ORIGINS', '').split(',') if o.strip()
]

SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE    = True
SECURE_HSTS_SECONDS   = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_SSL_REDIRECT   = True
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
