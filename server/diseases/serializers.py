from rest_framework import serializers
from .models import Disease


class DiseaseListSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Disease
        fields = ['id', 'name', 'severity', 'affected_parts', 'disease_image']


class DiseaseDetailSerializer(serializers.ModelSerializer):
    plant_name = serializers.CharField(source='plant.name', read_only=True)

    class Meta:
        model  = Disease
        fields = [
            'id', 'plant_name', 'name', 'description',
            'cause', 'symptoms', 'remedy', 'prevention',
            'severity', 'affected_parts', 'disease_image',
            'created_at'
        ]