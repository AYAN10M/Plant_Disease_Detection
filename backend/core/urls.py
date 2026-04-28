from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),

    # ── Plant & Disease catalog ───────────────────────────────────────────────
    path('api/plants/',    include('plants.urls')),
    path('api/diseases/',  include('diseases.urls')),

    # ── Detection (scan endpoint) ─────────────────────────────────────────────
    path('api/detections/', include('detections.urls')),

] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)