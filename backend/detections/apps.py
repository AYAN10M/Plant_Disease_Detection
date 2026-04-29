import logging
import os
import sys

from django.apps import AppConfig

logger = logging.getLogger(__name__)


class DetectionsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name         = 'detections'
    verbose_name = 'Disease Detections'

    def ready(self):
        """Pre-load the TF model and build Grad-CAM sub-models at startup.

        Guard logic:
          - In Django's dev reloader the parent process starts with RUN_MAIN unset,
            then re-spawns the child with RUN_MAIN=true. Skip the parent to avoid
            loading the model twice.
          - In production (gunicorn / uvicorn) RUN_MAIN is never set. We detect
            this by checking that we are NOT inside the reloader process, using
            the 'runserver' command as the signal that we're in dev mode.
        """
        in_dev_reloader_parent = (
            os.environ.get('RUN_MAIN') != 'true'
            and 'runserver' in sys.argv
        )
        if in_dev_reloader_parent:
            return  # skip — child process will warm up

        try:
            from .ml_model import _get_model, _get_input_size, _build_gradcam_model
            _get_model()
            _get_input_size()
            _build_gradcam_model()   # caches (outer, backbone, backbone_grad_model)
            logger.info('[Midori] MobileNetV2 + Grad-CAM sub-model ready.')
        except Exception as exc:
            logger.warning('[Midori] Model warm-up failed (will load on first request): %s', exc)
