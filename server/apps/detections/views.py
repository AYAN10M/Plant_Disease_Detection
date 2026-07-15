import logging

from django.db import transaction
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.throttling import AnonRateThrottle
from rest_framework.views import APIView

from diseases.models import Disease
from plants.models import Plant

from .engine import (
    DISEASE_CLASSES, PLANT_CLASSES, SUPPORTED_PLANTS,
    STAGE1_MODEL_NAME, STAGE2_MODEL_NAME,
    run_prediction,
)
from .models import Detection
from .serializers import DetectionCreateSerializer, DetectionResultSerializer

logger = logging.getLogger(__name__)


class DetectionRateThrottle(AnonRateThrottle):
    rate = '30/min'


class HealthView(APIView):

    permission_classes = [permissions.AllowAny]

    def get(self, request):
        from .engine import DISEASE_CLASSES, _get_disease_model, _get_plant_model

        model_ready = False
        loaded_diseases = []

        try:
            _get_plant_model()
            model_ready = True
        except Exception as exc:
            logger.warning("Health: plant model not ready — %s", exc)

        for plant in DISEASE_CLASSES:
            try:
                if _get_disease_model(plant) is not None:
                    loaded_diseases.append(plant)
            except Exception:
                pass

        return Response({
            "status":              "ok",
            "model_ready":         model_ready,
            "pipeline":            "two-stage",
            "stage1_architecture": STAGE1_MODEL_NAME,
            "stage2_architecture": STAGE2_MODEL_NAME,
            "all_plant_classes":   PLANT_CLASSES,
            "supported_plants":    sorted(SUPPORTED_PLANTS),
            "disease_models_loaded": loaded_diseases,
        })


class DetectView(APIView):

    permission_classes = [permissions.AllowAny]
    throttle_classes   = [DetectionRateThrottle]

    def post(self, request):
        serializer = DetectionCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        uploaded_image = serializer.validated_data["uploaded_image"]
        plant_override = serializer.validated_data.get("plant_override", "") or None
        confidence_threshold = serializer.validated_data.get("confidence_threshold", 55.0)

        try:
            with transaction.atomic():
                detection = Detection.objects.create(
                    uploaded_image=uploaded_image,
                    confidence=0.0,
                    status="processing",
                )

                try:
                    result = run_prediction(
                        image_path=detection.uploaded_image.path,
                        plant_override=plant_override,
                        confidence_threshold=confidence_threshold,
                    )
                except Exception as exc:
                    logger.error("run_prediction error: %s", exc, exc_info=True)
                    raise

                detection.status           = result["status"]
                detection.predicted_plant_name = result.get("plant_name", "") or ""
                detection.plant_confidence = result["plant_confidence"] / 100.0
                detection.plant_scores     = [
                    {"name": name, "confidence": round(pct / 100.0, 4)}
                    for name, pct in result.get("plant_scores", [])
                ]
                detection.confidence       = result["disease_confidence"] / 100.0
                detection.disease_scores   = [
                    {"name": name, "confidence": round(pct / 100.0, 4)}
                    for name, pct in result.get("disease_scores", [])
                ]
                detection.advice = result.get("advice", "")

                detection.stage1_latency_ms        = result.get("stage1_latency_ms", 0.0)
                detection.stage2_latency_ms        = result.get("stage2_latency_ms", 0.0)
                detection.preprocessing_latency_ms = result.get("preprocessing_latency_ms", 0.0)
                detection.total_latency_ms         = result.get("total_latency_ms", 0.0)
                detection.stage1_model             = result.get("stage1_model", STAGE1_MODEL_NAME)
                detection.stage2_model             = result.get("stage2_model", STAGE2_MODEL_NAME)

                if result.get("plant_gradcam_path"):
                    detection.plant_gradcam_image = result["plant_gradcam_path"]
                if result.get("disease_gradcam_path"):
                    detection.gradcam_image = result["disease_gradcam_path"]

                if result.get("plant_name") and result["plant_name"] != "Unknown Plant":
                    db_plant = Plant.objects.filter(name__iexact=result["plant_name"]).first()
                    if db_plant:
                        detection.plant = db_plant

                resolvable_statuses = {"success", "healthy", "low_confidence"}
                if result["status"] in resolvable_statuses and result.get("disease_name"):
                    disease_name = result["disease_name"]
                    if detection.plant:
                        db_disease = Disease.objects.filter(
                            plant=detection.plant, name__iexact=disease_name,
                        ).first()
                    else:
                        db_disease = Disease.objects.filter(name__iexact=disease_name).first()
                    if db_disease:
                        detection.disease = db_disease

                detection.save()

        except Exception as exc:
            logger.error("Detection transaction failed: %s", exc, exc_info=True)
            return Response(
                {"detail": "An internal error occurred during prediction."},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        serialized = DetectionResultSerializer(detection, context={"request": request})
        disease_name: str = result.get("disease_name") or ""
        is_healthy = result.get("is_healthy", False) or disease_name.lower() == "healthy"

        return Response(
            {
                "status":       result["status"],
                "message":      result.get("message", ""),
                "is_healthy":   is_healthy,
                "disease_name": disease_name or None,
                "data":         serialized.data,
            },
            status=status.HTTP_200_OK,
        )