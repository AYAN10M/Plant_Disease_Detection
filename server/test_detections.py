#!/usr/bin/env python
"""Test script to check detection records."""

import os
import sys
import django

sys.path.insert(0, os.path.dirname(__file__))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.development')
django.setup()

from detections.models import Detection
from detections.serializers import DetectionResultSerializer
from django.http import HttpRequest

# Create a fake request for URL building
request = HttpRequest()
request.META['HTTP_HOST'] = 'localhost:8000'
request.META['wsgi.url_scheme'] = 'http'

print(f"Total detections: {Detection.objects.count()}\n")

for d in Detection.objects.all():
    s = DetectionResultSerializer(d, context={'request': request})
    data = s.data
    disease_info = data.get('disease_detail')
    print(f"Detection {d.id}:")
    print(f"  Plant: {data.get('plant_name')}")
    print(f"  Disease: {disease_info.get('name') if disease_info else 'None'}")
    print(f"  Status: {data.get('status')}")
    print(f"  Plant DB: {d.plant}")
    print(f"  Disease DB: {d.disease}")
    print()
