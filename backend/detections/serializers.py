from rest_framework import serializers
from .models import Detection
from diseases.serializers import DiseaseDetailSerializer


class DetectionCreateSerializer(serializers.ModelSerializer):
    """Input — what Flutter sends to us"""
    class Meta:
        model  = Detection
        fields = ['plant', 'uploaded_image']
        extra_kwargs = {
            'plant': {
                'required': False,
                'allow_null': True,
            },
        }


class DetectionResultSerializer(serializers.ModelSerializer):
    """Output — what we send back to Flutter.

    Both image fields are returned as **absolute** URLs so the Flutter client
    can fetch them directly without having to know the server's base URL or the
    /media/ prefix.
    """
    disease_detail  = DiseaseDetailSerializer(source='disease', read_only=True)
    confidence_pct  = serializers.SerializerMethodField()
    plant_name      = serializers.SerializerMethodField()
    uploaded_image  = serializers.SerializerMethodField()
    gradcam_image   = serializers.SerializerMethodField()

    class Meta:
        model  = Detection
        fields = [
            'id', 'plant_name', 'disease_detail',
            'uploaded_image', 'gradcam_image',
            'confidence', 'confidence_pct',
            'status', 'created_at',
        ]

    def get_confidence_pct(self, obj):
        return f"{round(obj.confidence * 100, 1)}%"

    def get_plant_name(self, obj):
        return obj.plant.name if obj.plant is not None else None

    def _absolute_url(self, field_value):
        """Build an absolute URL for an ImageField value.

        Returns None when the field is empty so Flutter can treat it as absent.
        """
        if not field_value:
            return None
        request = self.context.get('request')
        if request is not None:
            return request.build_absolute_uri(field_value.url)
        # Fallback: return the relative media URL (shouldn't normally happen).
        return field_value.url

    def get_uploaded_image(self, obj):
        return self._absolute_url(obj.uploaded_image)

    def get_gradcam_image(self, obj):
        return self._absolute_url(obj.gradcam_image)