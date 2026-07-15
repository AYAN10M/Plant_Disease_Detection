from django.contrib import admin
from .models import Disease


class DiseaseInline(admin.TabularInline):
    model  = Disease
    extra  = 1   
    fields = ['name', 'severity', 'cause', 'remedy']


@admin.register(Disease)
class DiseaseAdmin(admin.ModelAdmin):
    list_display   = ['name', 'plant', 'severity', 'affected_parts', 'created_at']
    search_fields  = ['name', 'plant__name']
    list_filter    = ['severity', 'plant']