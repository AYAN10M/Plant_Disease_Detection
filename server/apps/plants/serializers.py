from rest_framework import serializers
from .models import Plant

class PlantListSerializer(serializers.ModelSerializer):
    """Short version — for showing a list of plants"""
    class Meta:
        model  = Plant
        fields = ['id', 'name', 'scientific_name', 'image']


class PlantDetailSerializer(serializers.ModelSerializer):
    """Full version — all fields + diseases mapped to this plant"""
    diseases = serializers.SerializerMethodField()

    class Meta:
        model  = Plant
        fields = [
            'id', 'name', 'scientific_name', 'family',
            'description', 'origin', 'growing_season',
            'ideal_climate', 'common_uses', 'image',
            'created_at', 'diseases'   # ← nested diseases list
        ]

    def get_diseases(self, obj):
        # import here to avoid circular import
        from diseases.serializers import DiseaseListSerializer
        diseases = obj.diseases.all()   # reverse relation name from Disease.plant
        return DiseaseListSerializer(diseases, many=True).data