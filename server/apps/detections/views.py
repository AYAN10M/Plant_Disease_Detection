import logging

from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from diseases.models import Disease
from plants.models import Plant

from .engine import PLANT_CLASSES, run_prediction
from .models import Detection
from .serializers import DetectionCreateSerializer, DetectionResultSerializer

logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────────────────────────────────────
# Health check
# ─────────────────────────────────────────────────────────────────────────────

class HealthView(APIView):
    """GET /api/detections/health/  — confirms the backend and models are ready."""

    permission_classes = [permissions.AllowAny]

    def get(self, request):
        from .engine import DISEASE_CLASSES, _get_disease_model, _get_plant_model

        model_ready      = False
        loaded_diseases  = []

        try:
            _get_plant_model()
            model_ready = True
        except Exception as exc:
            logger.warning("[Midori] Health: plant model not ready — %s", exc)

        for plant in DISEASE_CLASSES:
            try:
                m = _get_disease_model(plant)
                if m is not None:
                    loaded_diseases.append(plant)
            except Exception:
                pass

        return Response({
            "status":                "ok",
            "model_ready":           model_ready,
            "pipeline":              "two-stage",
            "plant_classes":         PLANT_CLASSES,
            "disease_models_loaded": loaded_diseases,
        })


# ─────────────────────────────────────────────────────────────────────────────
# Detect view
# ─────────────────────────────────────────────────────────────────────────────

class DetectView(APIView):
    """POST /api/detections/ — upload a leaf photo, run the two-stage pipeline."""

    permission_classes = [permissions.AllowAny]

    def post(self, request):
        # ── Validate input ────────────────────────────────────────────────────
        serializer = DetectionCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        uploaded_image = serializer.validated_data["uploaded_image"]
        plant_override = serializer.validated_data.get("plant_override", "") or None

        # ── Persist Detection record (we need the file path for the ML engine) ──
        detection = Detection.objects.create(
            uploaded_image=uploaded_image,
            confidence=0.0,
            status="processing",
        )

        # ── Run two-stage pipeline ────────────────────────────────────────────
        try:
            result = run_prediction(
                image_path=detection.uploaded_image.path,
                plant_override=plant_override,
            )
        except Exception as exc:
            logger.error("[Midori] run_prediction unhandled error: %s", exc, exc_info=True)
            detection.status = "failed"
            detection.save(update_fields=["status"])
            return Response(
                {"detail": "An internal error occurred during prediction."},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        # ── Populate model fields from result dict ────────────────────────────
        detection.status         = result["status"]
        detection.plant_confidence = result["plant_confidence"] / 100.0   # → 0–1
        detection.plant_scores   = [
            {"name": name, "confidence": round(pct / 100.0, 4)}
            for name, pct in result.get("plant_scores", [])
        ]
        detection.confidence     = result["disease_confidence"] / 100.0   # → 0–1
        detection.disease_scores = [
            {"name": name, "confidence": round(pct / 100.0, 4)}
            for name, pct in result.get("disease_scores", [])
        ]
        detection.advice         = result.get("advice", "")

        if result.get("plant_gradcam_path"):
            detection.plant_gradcam_image = result["plant_gradcam_path"]

        if result.get("disease_gradcam_path"):
            detection.gradcam_image = result["disease_gradcam_path"]

        # ── Resolve Plant DB record ───────────────────────────────────────────
        if result.get("plant_name"):
            db_plant = Plant.objects.filter(
                name__iexact=result["plant_name"]
            ).first()
            if db_plant:
                detection.plant = db_plant

        # ── Resolve Disease DB record (only on success) ───────────────────────
        if result["status"] == "success" and result.get("disease_name"):
            disease_name = result["disease_name"]
            if detection.plant:
                db_disease = Disease.objects.filter(
                    plant=detection.plant,
                    name__iexact=disease_name,
                ).first()
            else:
                db_disease = Disease.objects.filter(
                    name__iexact=disease_name
                ).first()
            if db_disease:
                detection.disease = db_disease

        detection.save()

        # ── Serialize & respond ───────────────────────────────────────────────
        serialized = DetectionResultSerializer(
            detection, context={"request": request}
        )
        return Response(
            {
                "status":  result["status"],
                "message": result.get("message", ""),
                "data":    serialized.data,
            },
            status=status.HTTP_200_OK,
        )