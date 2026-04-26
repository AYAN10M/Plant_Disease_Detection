from django.urls import path
from .views import DetectView, DetectionHistoryView, DetectionDetailView

urlpatterns = [
    path('',          DetectView.as_view()),
    path('history/',  DetectionHistoryView.as_view()),
    path('<int:pk>/', DetectionDetailView.as_view()),
]