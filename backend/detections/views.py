from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import Detection
from .serializers import DetectionCreateSerializer, DetectionResultSerializer
from .ml_model import run_prediction, generate_gradcam

CONFIDENCE_THRESHOLD = 0.60   # below this → ask user to retake photo


class DetectView(APIView):
    """Core endpoint — upload image → get disease result"""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = DetectionCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        plant          = serializer.validated_data['plant']
        uploaded_image = serializer.validated_data['uploaded_image']

        # Step 1 — run ML prediction (mock for now)
        disease_id, confidence = run_prediction(
            image_path=uploaded_image,
            plant_id=plant.id
        )

        # Step 2 — check confidence threshold
        if confidence < CONFIDENCE_THRESHOLD:
            detection = Detection.objects.create(
                user           = request.user,
                plant          = plant,
                disease        = None,
                uploaded_image = uploaded_image,
                confidence     = confidence,
                status         = 'low_confidence'
            )
            result = DetectionResultSerializer(detection, context={'request': request})
            return Response({
                'status'  : 'low_confidence',
                'message' : 'Image quality too low. Please retake a clearer photo.',
                'data'    : result.data
            }, status=status.HTTP_200_OK)

        # Step 3 — generate Grad-CAM (mock for now)
        gradcam_path = generate_gradcam(uploaded_image)

        # Step 4 — save successful detection
        detection = Detection.objects.create(
            user           = request.user,
            plant          = plant,
            disease_id     = disease_id,
            uploaded_image = uploaded_image,
            gradcam_image  = gradcam_path,
            confidence     = confidence,
            status         = 'success'
        )

        result = DetectionResultSerializer(detection, context={'request': request})
        return Response({
            'status' : 'success',
            'data'   : result.data
        }, status=status.HTTP_201_CREATED)


class DetectionHistoryView(generics.ListAPIView):
    """All past detections for the logged-in user"""
    serializer_class   = DetectionResultSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Detection.objects.filter(user=self.request.user)


class DetectionDetailView(generics.RetrieveAPIView):
    """Single past detection by ID"""
    serializer_class   = DetectionResultSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # users can only see their own detections
        return Detection.objects.filter(user=self.request.user)