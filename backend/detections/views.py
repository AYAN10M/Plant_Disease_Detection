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
    LOW_CONFIDENCE_MESSAGE,
    NOT_A_PLANT_MESSAGE,
)

logger = logging.getLogger(__name__)


class HealthView(APIView):
    """GET /api/detections/health/ — confirms the server and model are ready."""
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        try:
            from .ml_model import _get_model, _build_gradcam_models
            _get_model()
            _build_gradcam_models()
            return Response({'status': 'ok', 'model': 'MobileNetV2'})
        except Exception as exc:
            return Response({'status': 'error', 'detail': str(exc)},
                            status=status.HTTP_503_SERVICE_UNAVAILABLE)


class DetectView(APIView):
    """POST /api/detections/ — upload image, get disease prediction + Grad-CAM."""
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = DetectionCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        plant          = serializer.validated_data.get('plant')
        uploaded_image = serializer.validated_data['uploaded_image']

        # Persist image to disk first — ML model needs a real file path
        detection = Detection.objects.create(
            plant          = plant,
            uploaded_image = uploaded_image,
            confidence     = 0.0,
            status         = 'processing',
        )

        try:
            # Single forward pass → prediction + Grad-CAM
            disease_id, confidence, class_name, is_plant, top_k, gradcam_path = (
                run_prediction(
                    image_path=detection.uploaded_image.path,
                    plant_id=plant.id if plant is not None else None,
                )
            )
        except Exception as exc:
            logger.error('[Midori] run_prediction error: %s', exc, exc_info=True)
            detection.status = 'failed'
            detection.save(update_fields=['status'])
            return Response({'detail': 'Prediction failed internally.'},
                            status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        # ── Not a plant ───────────────────────────────────────────────────────
        if not is_plant:
            detection.confidence = confidence
            detection.status     = 'not_a_plant'
            detection.save(update_fields=['confidence', 'status'])
            result = DetectionResultSerializer(detection, context={'request': request})
            return Response({
                'status' : 'not_a_plant',
                'message': NOT_A_PLANT_MESSAGE,
                'data'   : result.data,
            })

        # ── Resolve disease & attach Grad-CAM ────────────────────────────────
        disease = Disease.objects.select_related('plant').filter(id=disease_id).first()
        if disease is not None:
            detection.plant   = disease.plant
            detection.disease = disease
        if gradcam_path:
            detection.gradcam_image = gradcam_path

        # ── Low confidence ────────────────────────────────────────────────────
        if confidence < CONFIDENCE_THRESHOLD:
            detection.confidence = confidence
            detection.status     = 'low_confidence'
            detection.save(update_fields=['plant', 'disease', 'gradcam_image',
                                          'confidence', 'status'])
            result = DetectionResultSerializer(detection, context={'request': request})
            return Response({
                'status'      : 'low_confidence',
                'message'     : LOW_CONFIDENCE_MESSAGE,
                'data'        : result.data,
                'alternatives': top_k,
            })

        # ── Success ───────────────────────────────────────────────────────────
        detection.confidence = confidence
        detection.status     = 'success'
        detection.save(update_fields=['plant', 'disease', 'gradcam_image',
                                      'confidence', 'status'])
        result = DetectionResultSerializer(detection, context={'request': request})
        return Response({
            'status'      : 'success',
            'data'        : result.data,
            'alternatives': top_k,
        }, status=status.HTTP_201_CREATED)