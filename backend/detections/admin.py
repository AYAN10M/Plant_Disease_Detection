from django.contrib import admin
from .models import Detection


@admin.register(Detection)
class DetectionAdmin(admin.ModelAdmin):
    list_display    = ['id', 'plant', 'disease', 'confidence_display', 'status', 'created_at']
    list_filter     = ['status', 'plant']
    search_fields   = ['plant__name', 'disease__name']
    readonly_fields = ['uploaded_image', 'gradcam_image', 'confidence', 'created_at']
    ordering        = ['-created_at']

    @admin.display(description='Confidence')
    def confidence_display(self, obj):
        return f"{obj.confidence:.1%}"