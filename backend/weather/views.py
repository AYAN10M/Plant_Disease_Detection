import urllib.request
import urllib.parse
import json

from django.conf import settings
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from constants import (
    WEATHER_HIGH_HUMIDITY_THRESHOLD,
    WEATHER_HIGH_TEMP_THRESHOLD,
    WEATHER_LOW_TEMP_THRESHOLD,
)

# Disease risk hints keyed on weather condition.
# Returned alongside weather data to help the farmer act proactively.
RISK_RULES = [
    {
        'condition': lambda w: w['humidity'] > WEATHER_HIGH_HUMIDITY_THRESHOLD,
        'level': 'high',
        'message': (
            f"Humidity above {WEATHER_HIGH_HUMIDITY_THRESHOLD}% — "
            "high risk of fungal diseases such as blight, mold, and rust. "
            "Ensure good airflow around plants and avoid overhead watering."
        ),
    },
    {
        'condition': lambda w: w['temp'] > WEATHER_HIGH_TEMP_THRESHOLD,
        'level': 'medium',
        'message': (
            f"Temperature above {WEATHER_HIGH_TEMP_THRESHOLD}°C — "
            "heat stress can weaken plant immunity. "
            "Provide shade and increase irrigation."
        ),
    },
    {
        'condition': lambda w: w['temp'] < WEATHER_LOW_TEMP_THRESHOLD,
        'level': 'medium',
        'message': (
            f"Temperature below {WEATHER_LOW_TEMP_THRESHOLD}°C — "
            "risk of frost damage. Cover sensitive crops overnight."
        ),
    },
]


def _evaluate_risk(weather_data: dict) -> list[dict]:
    """Return all triggered risk hints for the given weather snapshot."""
    return [
        {'level': rule['level'], 'message': rule['message']}
        for rule in RISK_RULES
        if rule['condition'](weather_data)
    ]


class WeatherView(APIView):
    """
    GET /api/weather/?lat=<float>&lon=<float>

    Fetches current weather from OpenWeatherMap and appends disease risk hints.
    Falls back to a mock response when WEATHER_API_KEY is not set.
    """

    def get(self, request):
        lat = request.query_params.get('lat')
        lon = request.query_params.get('lon')

        if not lat or not lon:
            return Response(
                {'error': 'lat and lon query parameters are required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        api_key = settings.WEATHER_API_KEY

        # ── No API key: return a safe mock so the frontend still renders ──────
        if not api_key:
            mock_weather = {
                'location': 'Demo Location',
                'temp': 28.0,
                'feels_like': 30.0,
                'humidity': 72,
                'description': 'partly cloudy',
                'icon': '02d',
                'wind_speed': 3.5,
                'source': 'mock',
            }
            mock_weather['disease_risk'] = _evaluate_risk(mock_weather)
            return Response(mock_weather)

        # ── Live call to OpenWeatherMap ───────────────────────────────────────
        try:
            params = urllib.parse.urlencode({
                'lat':   lat,
                'lon':   lon,
                'appid': api_key,
                'units': 'metric',
            })
            url = f"https://api.openweathermap.org/data/2.5/weather?{params}"

            with urllib.request.urlopen(url, timeout=8) as resp:
                raw = json.loads(resp.read().decode())

            weather_data = {
                'location':   raw.get('name', 'Unknown'),
                'temp':       raw['main']['temp'],
                'feels_like': raw['main']['feels_like'],
                'humidity':   raw['main']['humidity'],
                'description': raw['weather'][0]['description'],
                'icon':       raw['weather'][0]['icon'],
                'wind_speed': raw['wind']['speed'],
                'source':     'openweathermap',
            }
            weather_data['disease_risk'] = _evaluate_risk(weather_data)
            return Response(weather_data)

        except Exception as exc:
            return Response(
                {'error': f"Weather service unavailable: {exc}"},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
