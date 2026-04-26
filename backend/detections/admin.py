from django.contrib import admin
from .models import Detection

@admin.register(Detection)
class DetectionAdmin(admin.ModelAdmin):
    list_display  = ['user', 'plant', 'disease', 'confidence', 'status', 'created_at']
    list_filter   = ['status', 'plant']
    search_fields = ['user__email', 'plant__name', 'disease__name']
    readonly_fields = ['uploaded_image', 'gradcam_image', 'confidence', 'created_at']