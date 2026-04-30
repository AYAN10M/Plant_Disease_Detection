from django.urls import path
from .views import DetectView, HealthView

urlpatterns = [
    path('',        DetectView.as_view(), name='detect'),   # POST /api/detections/
    path('health/', HealthView.as_view(), name='health'),   # GET  /api/detections/health/
]