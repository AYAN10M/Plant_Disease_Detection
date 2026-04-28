from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Detection
from diseases.models import Disease
from .serializers import DetectionCreateSerializer, DetectionResultSerializer
from .ml_model import run_prediction, generate_gradcam
from constants import (
    CONFIDENCE_THRESHOLD,
    LOW_CONFIDENCE_MESSAGE,
)


class DetectView(APIView):
    """
    Core endpoint — POST an image → get disease result.
    No authentication required. Works for all users anonymously.
    History is managed client-side on the device.
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = DetectionCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        plant          = serializer.validated_data.get('plant')
        uploaded_image = serializer.validated_data['uploaded_image']

        # Save the detection first so Django writes the image to disk.
        # The ML model needs an on-disk path — InMemoryUploadedFile has no
        # .path before the ORM saves it.
        detection = Detection.objects.create(
            plant          = plant,
            uploaded_image = uploaded_image,
            confidence     = 0.0,
            status         = 'processing',
        )

        disease_id, confidence, class_name = run_prediction(
            image_path=detection.uploaded_image.path,
            plant_id=plant.id if plant is not None else None,
        )

        disease = Disease.objects.select_related('plant').filter(id=disease_id).first()
        if disease is not None:
            detection.plant = disease.plant
            detection.disease = disease

        if confidence < CONFIDENCE_THRESHOLD:
            detection.confidence = confidence
            detection.status     = 'low_confidence'
            detection.save(update_fields=['plant', 'disease', 'confidence', 'status'])

            result = DetectionResultSerializer(detection, context={'request': request})
            return Response({
                'status'  : 'low_confidence',
                'message' : LOW_CONFIDENCE_MESSAGE,
                'data'    : result.data,
            }, status=status.HTTP_200_OK)

        gradcam_path = generate_gradcam(detection.uploaded_image.path, class_name)

        detection.gradcam_image = gradcam_path
        detection.confidence    = confidence
        detection.status        = 'success'
        detection.save(update_fields=['plant', 'disease', 'gradcam_image', 'confidence', 'status'])

        result = DetectionResultSerializer(detection, context={'request': request})
        return Response({
            'status' : 'success',
            'data'   : result.data,
        }, status=status.HTTP_201_CREATED)