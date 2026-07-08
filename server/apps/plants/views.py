from rest_framework import generics, permissions
from .models import Plant
from .serializers import PlantListSerializer, PlantDetailSerializer


class PlantListView(generics.ListAPIView):
    queryset           = Plant.objects.all().order_by('name')
    serializer_class   = PlantListSerializer
    permission_classes = [permissions.AllowAny]


class PlantDetailView(generics.RetrieveAPIView):
    queryset           = Plant.objects.all()
    serializer_class   = PlantDetailSerializer
    permission_classes = [permissions.AllowAny]
    