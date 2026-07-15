from rest_framework import serializers
from .models import Plant

class PlantListSerializer(serializers.ModelSerializer):

    class Meta:
        model  = Plant
        fields = ['id', 'name', 'scientific_name', 'image']


class PlantDetailSerializer(serializers.ModelSerializer):

    diseases = serializers.SerializerMethodField()

    class Meta:
        model  = Plant
        fields = [
            'id', 'name', 'scientific_name', 'family',
            'description', 'origin', 'growing_season',
            'ideal_climate', 'common_uses', 'image',
            'created_at', 'diseases'   
        ]

    def get_diseases(self, obj):
        
        from diseases.serializers import DiseaseListSerializer
        diseases = obj.diseases.all()   
        return DiseaseListSerializer(diseases, many=True).data