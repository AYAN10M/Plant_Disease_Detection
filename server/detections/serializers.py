from rest_framework import serializers
from .models import Detection
from diseases.serializers import DiseaseDetailSerializer

# 10 MB upload limit — matches frontend guard
_MAX_IMAGE_BYTES = 10 * 1024 * 1024

# Permitted MIME types for uploaded leaf images
_ALLOWED_CONTENT_TYPES = {
    'image/jpeg', 'image/jpg', 'image/png',
    'image/webp', 'image/heic', 'image/heif',
}


class DetectionCreateSerializer(serializers.ModelSerializer):
    """Input — what Flutter sends to us."""

    class Meta:
        model  = Detection
        fields = ['plant', 'uploaded_image']
        extra_kwargs = {
            'plant': {
                'required': False,
                'allow_null': True,
            },
        }

    def validate_uploaded_image(self, value):
        # Size check
        if value.size > _MAX_IMAGE_BYTES:
            raise serializers.ValidationError(
                f'Image is too large ({value.size // (1024*1024)} MB). Maximum is 10 MB.'
            )

        # Content-type check (header only — not a magic-byte deep scan, but sufficient
        # to reject obviously wrong file types sent by the Flutter client).
        content_type = getattr(value, 'content_type', None)
        if content_type and content_type.lower() not in _ALLOWED_CONTENT_TYPES:
            raise serializers.ValidationError(
                f'Unsupported image format: {content_type}. '
                f'Use JPEG, PNG, or WebP.'
            )

        return value


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
    is_healthy      = serializers.SerializerMethodField()

    class Meta:
        model  = Detection
        fields = [
            'id', 'plant_name', 'disease_detail',
            'uploaded_image', 'gradcam_image',
            'confidence', 'confidence_pct',
            'status', 'is_healthy', 'created_at',
        ]

    def get_confidence_pct(self, obj):
        return f"{round(obj.confidence * 100, 1)}%"

    def get_plant_name(self, obj):
        if obj.plant is not None:
            return obj.plant.name
        # Fall back to deriving from the linked disease's plant
        if obj.disease is not None and obj.disease.plant is not None:
            return obj.disease.plant.name
        return None

    def get_is_healthy(self, obj):
        return obj.status == 'healthy'

    def _absolute_url(self, field_value):
        """Build an absolute URL for an ImageField value.

        Returns None when the field is empty so Flutter can treat it as absent.
        """
        if not field_value:
            return None
        request = self.context.get('request')
        if request is not None:
            return request.build_absolute_uri(field_value.url)
        return field_value.url

    def get_uploaded_image(self, obj):
        return self._absolute_url(obj.uploaded_image)

    def get_gradcam_image(self, obj):
        return self._absolute_url(obj.gradcam_image)