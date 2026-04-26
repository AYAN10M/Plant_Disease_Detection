from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import Detection
from .serializers import DetectionCreateSerializer, DetectionResultSerializer
from .ml_model import run_prediction, generate_gradcam
from django.db.models import Count
from django.utils import timezone
from datetime import timedelta
from .serializers import DetectionResultSerializer

CONFIDENCE_THRESHOLD = 0.60


class DetectView(APIView):
    """Core endpoint — upload image → get disease result"""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = DetectionCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        plant          = serializer.validated_data['plant']
        uploaded_image = serializer.validated_data['uploaded_image']

        disease_id, confidence = run_prediction(
            image_path=uploaded_image,
            plant_id=plant.id
        )

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

        gradcam_path = generate_gradcam(uploaded_image)

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
    serializer_class   = DetectionResultSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Detection.objects.filter(user=self.request.user)


class DetectionDetailView(generics.RetrieveAPIView):
    serializer_class   = DetectionResultSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # users can only see their own detections
        return Detection.objects.filter(user=self.request.user)
    

class DashboardView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user

        all_detections = Detection.objects.filter(user=user)

        total       = all_detections.count()
        successful  = all_detections.filter(status='success').count()
        low_conf    = all_detections.filter(status='low_confidence').count()

        top_disease = (
            all_detections
            .filter(disease__isnull=False)
            .values('disease__name')          # group by disease name
            .annotate(count=Count('id'))      # count detections per disease
            .order_by('-count')               # highest first
            .first()                          # take top 1
        )

        by_plant = (
            all_detections
            .values('plant__name')
            .annotate(count=Count('id'))
            .order_by('-count')
        )

        recent = all_detections.select_related(
            'plant', 'disease'
        )[:5]

        today      = timezone.now().date()
        last_7days = today - timedelta(days=6)

        trend_qs = (
            all_detections
            .filter(created_at__date__gte=last_7days)
            .values('created_at__date')
            .annotate(count=Count('id'))
            .order_by('created_at__date')
        )

        trend_map = {
            str(entry['created_at__date']): entry['count']
            for entry in trend_qs
        }
        trend = []
        for i in range(7):
            day = str(last_7days + timedelta(days=i))
            trend.append({'date': day, 'count': trend_map.get(day, 0)})

        return Response({
            'summary': {
                'total_detections'          : total,
                'successful_detections'     : successful,
                'low_confidence_detections' : low_conf,
                'most_detected_disease'     : top_disease['disease__name'] if top_disease else None,
            },
            'detections_by_plant': list(by_plant),
            'detection_trend'    : trend,
            'recent_detections'  : DetectionResultSerializer(
                                     recent,
                                     many=True,
                                     context={'request': request}
                                   ).data,
        })