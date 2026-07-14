from rest_framework import serializers
from .models import Detection
from diseases.serializers import DiseaseDetailSerializer

_MAX_IMAGE_BYTES = 10 * 1024 * 1024

_ALLOWED_CONTENT_TYPES = {
    "image/jpeg", "image/jpg", "image/png", "image/webp", "image/heic", "image/heif",
}

PLANT_OVERRIDE_CHOICES = ["", "Apple", "Corn", "Grape", "Pepper", "Potato", "Strawberry"]


class DetectionCreateSerializer(serializers.Serializer):
    uploaded_image = serializers.ImageField()
    plant_override = serializers.ChoiceField(
        choices=PLANT_OVERRIDE_CHOICES, required=False, allow_blank=True, default="",
    )
    confidence_threshold = serializers.FloatField(
        required=False, default=55.0, min_value=0.0, max_value=100.0,
    )

    def validate_uploaded_image(self, value):
        if value.size > _MAX_IMAGE_BYTES:
            raise serializers.ValidationError(
                f"Image too large ({value.size // (1024 * 1024)} MB). Max is 10 MB."
            )
        content_type = getattr(value, "content_type", None)
        if content_type and content_type.lower() not in _ALLOWED_CONTENT_TYPES:
            raise serializers.ValidationError(
                f"Unsupported format: {content_type}. Use JPEG, PNG, WebP, or HEIC."
            )
        return value


class DetectionResultSerializer(serializers.ModelSerializer):
    disease_detail      = DiseaseDetailSerializer(source="disease", read_only=True)
    plant_name          = serializers.SerializerMethodField()
    plant_confidence_pct = serializers.SerializerMethodField()
    confidence_pct      = serializers.SerializerMethodField()
    is_healthy          = serializers.SerializerMethodField()
    uploaded_image      = serializers.SerializerMethodField()
    gradcam_image       = serializers.SerializerMethodField()
    plant_gradcam_image = serializers.SerializerMethodField()

    class Meta:
        model  = Detection
        fields = [
            "id",
            "plant_name", "plant_confidence", "plant_confidence_pct",
            "plant_scores", "plant_gradcam_image",
            "disease_detail", "confidence", "confidence_pct",
            "disease_scores", "gradcam_image",
            "uploaded_image", "advice", "status", "is_healthy", "created_at",
            "stage1_latency_ms", "stage2_latency_ms",
            "preprocessing_latency_ms", "total_latency_ms",
            "stage1_model", "stage2_model",
        ]

    def get_plant_name(self, obj: Detection) -> str | None:
        if obj.plant:
            return obj.plant.name
        if obj.disease and obj.disease.plant:
            return obj.disease.plant.name
        # Fall back to the ML engine's raw prediction
        if obj.predicted_plant_name:
            return obj.predicted_plant_name
        return None

    def get_plant_confidence_pct(self, obj: Detection) -> str:
        return f"{round(obj.plant_confidence * 100.0, 1)}%"

    def get_confidence_pct(self, obj: Detection) -> str:
        return f"{round(obj.confidence * 100.0, 1)}%"

    def get_is_healthy(self, obj: Detection) -> bool:
        if obj.status == "healthy":
            return True
        if obj.disease and obj.disease.name.lower() == "healthy":
            return True
        return False

    def _absolute_url(self, field_value) -> str | None:
        if not field_value:
            return None
        request = self.context.get("request")
        if request:
            return request.build_absolute_uri(field_value.url)
        return field_value.url

    def get_uploaded_image(self, obj: Detection) -> str | None:
        return self._absolute_url(obj.uploaded_image)

    def get_gradcam_image(self, obj: Detection) -> str | None:
        return self._absolute_url(obj.gradcam_image)

    def get_plant_gradcam_image(self, obj: Detection) -> str | None:
        return self._absolute_url(obj.plant_gradcam_image)