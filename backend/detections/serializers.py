from rest_framework import serializers
from .models import Detection
from diseases.serializers import DiseaseDetailSerializer


class DetectionCreateSerializer(serializers.ModelSerializer):
    """Input — what Flutter sends to us"""
    class Meta:
        model  = Detection
        fields = ['plant', 'uploaded_image']
        # user is set automatically from request, not sent by client


class DetectionResultSerializer(serializers.ModelSerializer):
    """Output — what we send back to Flutter"""
    disease_detail = DiseaseDetailSerializer(source='disease', read_only=True)
    confidence_pct = serializers.SerializerMethodField()
    plant_name     = serializers.CharField(source='plant.name', read_only=True)

    class Meta:
        model  = Detection
        fields = [
            'id', 'plant_name', 'disease_detail',
            'uploaded_image', 'gradcam_image',
            'confidence', 'confidence_pct',
            'status', 'created_at'
        ]

    def get_confidence_pct(self, obj):
        return f"{round(obj.confidence * 100, 1)}%"