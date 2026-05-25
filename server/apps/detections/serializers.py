from rest_framework import serializers

from .models import Detection
from diseases.serializers import DiseaseDetailSerializer

# ── Constants ─────────────────────────────────────────────────────────────────
_MAX_IMAGE_BYTES = 10 * 1024 * 1024   # 10 MB

_ALLOWED_CONTENT_TYPES = {
    "image/jpeg", "image/jpg",
    "image/png",
    "image/webp",
    "image/heic", "image/heif",
}

# Only plants that have a disease model are valid overrides.
# Corn and Tomato are excluded — no disease model exists for them yet.
PLANT_OVERRIDE_CHOICES = ["", "Apple", "Grape", "Potato", "Pepper"]


# ─────────────────────────────────────────────────────────────────────────────
# Input serializer
# ─────────────────────────────────────────────────────────────────────────────

class DetectionCreateSerializer(serializers.Serializer):
    """
    Validates what Flutter POSTs to /api/detections/.
    Fields
    ------
    uploaded_image  : the leaf photo (required)
    plant_override  : force a specific plant name, skipping Stage 1 (optional)
    """

    uploaded_image = serializers.ImageField()
    plant_override = serializers.ChoiceField(
        choices=PLANT_OVERRIDE_CHOICES,
        required=False,
        allow_blank=True,
        default="",
    )
    confidence_threshold = serializers.FloatField(
        required=False,
        default=40.0,
        min_value=0.0,
        max_value=100.0,
        help_text="Stage-1 minimum confidence % (0-100). Default: 40.",
    )

    def validate_uploaded_image(self, value):
        if value.size > _MAX_IMAGE_BYTES:
            raise serializers.ValidationError(
                f"Image is too large ({value.size // (1024 * 1024)} MB). "
                "Maximum allowed size is 10 MB."
            )
        content_type = getattr(value, "content_type", None)
        if content_type and content_type.lower() not in _ALLOWED_CONTENT_TYPES:
            raise serializers.ValidationError(
                f"Unsupported format: {content_type}. "
                "Please upload a JPEG, PNG, WebP, or HEIC image."
            )
        return value


# ─────────────────────────────────────────────────────────────────────────────
# Output serializer
# ─────────────────────────────────────────────────────────────────────────────

class DetectionResultSerializer(serializers.ModelSerializer):
    """
    Serialises a Detection instance into the full JSON response.

    Key computed fields
    -------------------
    plant_name           : resolved from plant FK or disease.plant FK
    plant_confidence_pct : formatted Stage-1 confidence  e.g. "87.3%"
    confidence_pct       : formatted Stage-2 confidence  e.g. "91.2%"
    is_healthy           : True when status == 'healthy'
    uploaded_image       : absolute URL
    gradcam_image        : absolute URL  (Stage-2 / disease Grad-CAM)
    plant_gradcam_image  : absolute URL  (Stage-1 / plant Grad-CAM)
    disease_detail       : nested DiseaseDetailSerializer
    """

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
            # Stage-1
            "plant_name",
            "plant_confidence",
            "plant_confidence_pct",
            "plant_scores",
            "plant_gradcam_image",
            # Stage-2
            "disease_detail",
            "confidence",
            "confidence_pct",
            "disease_scores",
            "gradcam_image",
            # Shared
            "uploaded_image",
            "advice",
            "status",
            "is_healthy",
            "created_at",
        ]

    # ── Computed fields ───────────────────────────────────────────────────────

    def get_plant_name(self, obj: Detection) -> str | None:
        if obj.plant:
            return obj.plant.name
        if obj.disease and obj.disease.plant:
            return obj.disease.plant.name
        return None

    def get_plant_confidence_pct(self, obj: Detection) -> str:
        return f"{round(obj.plant_confidence * 100.0, 1)}%"

    def get_confidence_pct(self, obj: Detection) -> str:
        return f"{round(obj.confidence * 100.0, 1)}%"

    def get_is_healthy(self, obj: Detection) -> bool:
        """True when status is 'healthy' OR the top disease class was 'Healthy'."""
        if obj.status == "healthy":
            return True
        if obj.disease and obj.disease.name.lower() == "healthy":
            return True
        return False

    # ── URL helpers ───────────────────────────────────────────────────────────

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