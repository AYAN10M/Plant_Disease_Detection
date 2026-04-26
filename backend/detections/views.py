from rest_framework import generics, permissions

from .ml_model import generate_gradcam, run_prediction
from .models import Detection
from .serializers import DetectionCreateSerializer, DetectionResultSerializer


class DetectView(generics.CreateAPIView):
	serializer_class = DetectionCreateSerializer
	permission_classes = [permissions.IsAuthenticated]

	def perform_create(self, serializer):
		detection = serializer.save(user=self.request.user)

		disease_id, confidence = run_prediction(
			detection.uploaded_image.path,
			detection.plant_id,
		)
		gradcam_path = generate_gradcam(detection.uploaded_image.path)

		if disease_id is None:
			detection.status = 'failed'
			detection.disease = None
			detection.confidence = 0.0
		else:
			detection.disease_id = disease_id
			detection.confidence = confidence
			detection.status = 'success' if confidence >= 0.60 else 'low_confidence'

		if gradcam_path:
			detection.gradcam_image = gradcam_path

		detection.save(update_fields=['disease', 'confidence', 'status', 'gradcam_image'])


class DetectionHistoryView(generics.ListAPIView):
	serializer_class = DetectionResultSerializer
	permission_classes = [permissions.IsAuthenticated]

	def get_queryset(self):
		return (
			Detection.objects.filter(user=self.request.user)
			.select_related('plant', 'disease', 'disease__plant')
		)


class DetectionDetailView(generics.RetrieveAPIView):
	serializer_class = DetectionResultSerializer
	permission_classes = [permissions.IsAuthenticated]

	def get_queryset(self):
		return (
			Detection.objects.filter(user=self.request.user)
			.select_related('plant', 'disease', 'disease__plant')
		)
