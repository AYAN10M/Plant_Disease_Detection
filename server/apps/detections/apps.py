import logging
import os
import sys

from django.apps import AppConfig

logger = logging.getLogger(__name__)


class DetectionsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name               = "detections"
    verbose_name       = "Disease Detections"

    def ready(self) -> None:
        # Skip warm-up in the reloader parent process (avoids double-load).
        if os.environ.get("RUN_MAIN") != "true" and "runserver" in sys.argv:
            return

        # Skip warm-up for management commands that don't need the ML models.
        _no_ml_commands = {
            "migrate", "makemigrations", "seed_model_catalog",
            "collectstatic", "shell", "dbshell", "help",
            "setup_models",
        }
        if any(cmd in sys.argv for cmd in _no_ml_commands):
            return

        try:
            from .engine import warm_up_models
            warm_up_models()
        except Exception as exc:
            logger.warning(
                "[Midori] Model warm-up failed — will load on first request. "
                "Make sure you ran  python setup_models.py  first. (%s)",
                exc,
            )
