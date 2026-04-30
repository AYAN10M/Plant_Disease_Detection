from django.contrib import admin
from .models import Plant
from diseases.models import Disease


class DiseaseInline(admin.TabularInline):
    model = Disease
    extra = 1
    fields = ['name', 'severity', 'cause', 'remedy']

@admin.register(Plant)
class PlantAdmin(admin.ModelAdmin):
    list_display  = ['name', 'scientific_name', 'family', 'growing_season', 'created_at']
    search_fields = ['name', 'scientific_name', 'family']
    list_filter   = ['growing_season', 'family']
    inlines       = [DiseaseInline]