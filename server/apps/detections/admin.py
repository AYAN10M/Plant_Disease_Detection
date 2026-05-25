from django.contrib import admin

from diseases.models import Disease
from .models import Detection


class DiseaseInline(admin.TabularInline):
    model  = Disease
    extra  = 0
    fields = ["name", "severity", "cause", "remedy"]
    readonly_fields = ["name", "severity"]


@admin.register(Detection)
class DetectionAdmin(admin.ModelAdmin):
    list_display   = [
        "id", "plant", "disease",
        "_plant_conf_pct", "_disease_conf_pct",
        "status", "created_at",
    ]
    list_filter    = ["status", "plant"]
    search_fields  = ["plant__name", "disease__name"]
    readonly_fields = [
        "uploaded_image", "plant_gradcam_image", "gradcam_image",
        "plant_confidence", "confidence",
        "plant_scores", "disease_scores",
        "advice", "status", "created_at",
    ]
    fieldsets = [
        ("Images", {
            "fields": ["uploaded_image", "plant_gradcam_image", "gradcam_image"],
        }),
        ("Classification", {
            "fields": ["plant", "disease", "status"],
        }),
        ("Stage 1 — Plant", {
            "fields": ["plant_confidence", "plant_scores"],
        }),
        ("Stage 2 — Disease", {
            "fields": ["confidence", "disease_scores", "advice"],
        }),
        ("Timestamps", {
            "fields": ["created_at"],
        }),
    ]

    @admin.display(description="Plant conf")
    def _plant_conf_pct(self, obj: Detection) -> str:
        return f"{obj.plant_confidence * 100:.1f}%"

    @admin.display(description="Disease conf")
    def _disease_conf_pct(self, obj: Detection) -> str:
        return f"{obj.confidence * 100:.1f}%"