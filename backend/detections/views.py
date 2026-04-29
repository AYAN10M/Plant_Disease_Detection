import logging

from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Detection
from diseases.models import Disease
from .serializers import DetectionCreateSerializer, DetectionResultSerializer
from .ml_model import run_prediction
from constants import (
    CONFIDENCE_THRESHOLD,
    HEALTHY_MESSAGE,
    LOW_CONFIDENCE_MESSAGE,
    NOT_A_PLANT_MESSAGE,
)

logger = logging.getLogger(__name__)


class HealthView(APIView):
    """GET /api/detections/health/ — confirms the backend is reachable."""
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        try:
            from .ml_model import _get_model, _build_gradcam_model
            _get_model()
            _build_gradcam_model()
            return Response({
                'status': 'ok',
                'model_ready': True,
                'model': 'MobileNetV2',
                'gradcam': True,
            })
        except Exception as exc:
            logger.warning('[Midori] Health check: model not ready: %s', exc)
            return Response({
                'status': 'ok',
                'model_ready': False,
                'model': 'MobileNetV2',
                'detail': 'Backend is reachable, but the model is not ready yet.',
            })


class DetectView(APIView):
    """POST /api/detections/ — upload image, get disease prediction + Grad-CAM."""
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = DetectionCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        plant          = serializer.validated_data.get('plant')
        uploaded_image = serializer.validated_data['uploaded_image']

        # Persist the uploaded image — the ML pipeline needs a real path
        detection = Detection.objects.create(
            plant          = plant,
            uploaded_image = uploaded_image,
            confidence     = 0.0,
            status         = 'processing',
        )

        try:
            disease_id, confidence, class_name, is_plant, is_healthy, top_k, gradcam_path = (
                run_prediction(
                    image_path=detection.uploaded_image.path,
                    plant_id=plant.id if plant is not None else None,
                )
            )
        except Exception as exc:
            logger.error('[Midori] run_prediction error: %s', exc, exc_info=True)
            detection.status = 'failed'
            detection.save(update_fields=['status'])
            return Response(
                {'detail': 'Prediction failed internally.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        # ── Attach Grad-CAM path (available for all non-failed statuses) ──────
        if gradcam_path:
            detection.gradcam_image = gradcam_path

        # ── Stage 1 result: not a plant ───────────────────────────────────────
        if not is_plant:
            detection.confidence = confidence
            detection.status     = 'not_a_plant'
            detection.save(update_fields=['confidence', 'status', 'gradcam_image'])
            result = DetectionResultSerializer(detection, context={'request': request})
            return Response({
                'status' : 'not_a_plant',
                'message': NOT_A_PLANT_MESSAGE,
                'data'   : result.data,
            }, status=status.HTTP_200_OK)

        # ── Stage 2: healthy plant ─────────────────────────────────────────────
        if is_healthy:
            # Extract plant from class name.
            # New format:  "Apple_healthy"               → "Apple"
            # Also handles "Pepper_bell_healthy"         → "Pepper bell"
            # Old format:  "Apple___healthy"             → "Apple"
            if class_name:
                # Strip the trailing _healthy / _Healthy suffix
                label = class_name
                for suffix in ('_Healthy', '_healthy'):
                    if label.endswith(suffix):
                        label = label[: -len(suffix)]
                        break
                else:
                    # Fallback: split on '___' (old format)
                    if '___' in label:
                        label = label.split('___')[0]
                plant_label = label.replace('_', ' ').strip()
                from plants.models import Plant  # noqa: PLC0415
                db_plant = Plant.objects.filter(name__iexact=plant_label).first()
                if db_plant:
                    detection.plant = db_plant

            detection.confidence = confidence
            detection.status     = 'healthy'
            detection.save(update_fields=['plant', 'confidence', 'status', 'gradcam_image'])
            result = DetectionResultSerializer(detection, context={'request': request})
            return Response({
                'status'  : 'healthy',
                'message' : HEALTHY_MESSAGE,
                'data'    : result.data,
            }, status=status.HTTP_200_OK)

        # ── Stage 3: disease detected — resolve DB record ─────────────────────
        if disease_id is not None:
            disease = Disease.objects.select_related('plant').filter(id=disease_id).first()
            if disease is not None:
                detection.plant   = disease.plant
                detection.disease = disease

        detection.confidence = confidence
        detection.save(update_fields=['plant', 'disease', 'gradcam_image', 'confidence'])

        # ── Low confidence warning ─────────────────────────────────────────────
        if confidence < CONFIDENCE_THRESHOLD:
            detection.status = 'low_confidence'
            detection.save(update_fields=['status'])
            result = DetectionResultSerializer(detection, context={'request': request})
            return Response({
                'status'      : 'low_confidence',
                'message'     : LOW_CONFIDENCE_MESSAGE,
                'data'        : result.data,
                'alternatives': top_k,
            }, status=status.HTTP_200_OK)

        # ── High confidence success ────────────────────────────────────────────
        detection.status = 'success'
        detection.save(update_fields=['status'])
        result = DetectionResultSerializer(detection, context={'request': request})
        return Response({
            'status'      : 'success',
            'data'        : result.data,
            'alternatives': top_k,
        }, status=status.HTTP_201_CREATED)