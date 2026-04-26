from django.urls import path
from .views import DetectView

urlpatterns = [
    path('',          DetectView.as_view(),  name='detect'),
]