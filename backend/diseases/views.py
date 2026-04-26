from rest_framework import generics, permissions
from .models import Disease
from .serializers import DiseaseListSerializer, DiseaseDetailSerializer


class DiseaseListByPlantView(generics.ListAPIView):
    serializer_class   = DiseaseListSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        plant_id = self.request.query_params.get('plant')
        if plant_id:
            return Disease.objects.filter(plant_id=plant_id)
        return Disease.objects.all()


class DiseaseDetailView(generics.RetrieveAPIView):
    queryset           = Disease.objects.all()
    serializer_class   = DiseaseDetailSerializer
    permission_classes = [permissions.IsAuthenticated]