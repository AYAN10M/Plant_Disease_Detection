from django.urls import path
from .views import WeatherView

urlpatterns = [
    path('', WeatherView.as_view(), name='weather'),  # GET /api/weather/?lat=&lon=
]
