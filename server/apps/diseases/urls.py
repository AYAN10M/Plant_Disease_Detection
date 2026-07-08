from django.urls import path
from .views import DiseaseListByPlantView, DiseaseDetailView

urlpatterns = [
    path('',          DiseaseListByPlantView.as_view(), name='disease-list'),
    path('<int:pk>/', DiseaseDetailView.as_view(),      name='disease-detail'),
]