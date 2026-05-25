#!/usr/bin/env python
"""Test script to check model loading."""

import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(__file__))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.development')

import django
django.setup()

from detections.engine import _MODEL_FILES, _get_disease_model, DISEASE_CLASSES

print("Model files mapping:")
for key, path in _MODEL_FILES().items():
    exists = path.exists()
    print(f"  {key}: {path}")
    print(f"    Exists: {exists}")

print("\n\nDisease classes mapping:")
for plant_name, classes in DISEASE_CLASSES.items():
    print(f"  {plant_name}: {classes}")

print("\n\nTesting _get_disease_model:")
for plant in ["Apple", "Potato", "Grape", "Pepper"]:
    model = _get_disease_model(plant)
    status = "Loaded" if model else "Failed"
    print(f"  {plant}: {status}")
