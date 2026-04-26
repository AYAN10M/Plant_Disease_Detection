from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),

    # ── Core Plant & Disease data ────────────────────────────────────────────
    path('api/plants/', include('plants.urls')),
    path('api/diseases/', include('diseases.urls')),

    # ── Detection (scan) ─────────────────────────────────────────────────────
    path('api/detections/', include('detections.urls')),

    # ── Weather ──────────────────────────────────────────────────────────────
    path('api/weather/', include('weather.urls')),

] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)