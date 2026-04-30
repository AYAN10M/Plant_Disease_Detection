import logging
import os
import sys

from django.apps import AppConfig

logger = logging.getLogger(__name__)


class DetectionsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name         = "detections"
    verbose_name = "Disease Detections"

    def ready(self):
        """Pre-load the TF model and build Grad-CAM sub-model at startup.

        Guard:
          Dev reloader spawns a parent process (RUN_MAIN unset) then a child
          (RUN_MAIN=true).  Skip loading in the parent to avoid double-loading.
          In production (gunicorn/uvicorn) RUN_MAIN is never set, so we load
          unless 'runserver' is in argv (i.e. we are in the parent).
        """
        in_dev_reloader_parent = (
            os.environ.get("RUN_MAIN") != "true"
            and "runserver" in sys.argv
        )
        if in_dev_reloader_parent:
            return  # child process will warm up

        try:
            from .engine import _get_model, _get_input_size, _build_gradcam_model
            _get_model()
            _get_input_size()
            backbone_conv_model, head_layers, layer_name = _build_gradcam_model()
            logger.info("[Midori] MobileNetV2 + Grad-CAM ready. Conv layer: %s", layer_name)
        except Exception as exc:
            logger.warning(
                "[Midori] Model warm-up failed (will load on first request): %s", exc
            )
