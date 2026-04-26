from django.urls import path
from .views import DiseaseListByPlantView, DiseaseDetailView

urlpatterns = [
    path('',         DiseaseListByPlantView.as_view()),  # GET /api/diseases/?plant=1
    path('<int:pk>/', DiseaseDetailView.as_view()),       # GET /api/diseases/3/
]