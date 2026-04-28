import logging
import os

from django.apps import AppConfig

logger = logging.getLogger(__name__)


class DetectionsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name         = 'detections'
    verbose_name = 'Disease Detections'

    def ready(self):
        """Pre-load the TF model and build Grad-CAM sub-models at startup."""
        if os.environ.get('RUN_MAIN') != 'true':
            return  # skip parent reloader process

        try:
            from .ml_model import _get_model, _get_input_size, _build_gradcam_models
            _get_model()
            _get_input_size()
            _build_gradcam_models()
            logger.info('[Midori] MobileNetV2 + Grad-CAM models ready.')
        except Exception as exc:
            logger.warning('[Midori] Warm-up failed: %s', exc)
