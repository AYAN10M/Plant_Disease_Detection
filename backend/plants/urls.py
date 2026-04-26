from django.urls import path
from .views import PlantListView, PlantDetailView

urlpatterns = [
    path('',      PlantListView.as_view()),    # GET /api/plants/
    path('<int:pk>/', PlantDetailView.as_view()),  # GET /api/plants/1/
]