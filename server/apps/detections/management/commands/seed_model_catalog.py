"""
seed_model_catalog — populate Plant + Disease tables from the two-stage model labels.

Usage
-----
    python manage.py seed_model_catalog
    python manage.py seed_model_catalog --keep-media

What it does
------------
1. Deletes all existing Detection, Disease, Plant records (wrapped in a transaction).
2. Optionally removes media sub-directories.
3. Creates one Plant per PLANT_CLASSES entry.
4. Creates one Disease per DISEASE_CLASSES entry for each plant that has a model.
   Plants without a disease model (Corn, Tomato) get zero disease records.
"""

import shutil
from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand
from django.db import transaction

# Import from engine — fixes the old ml_model import bug
from detections.engine import DISEASE_CLASSES, PLANT_CLASSES, TREATMENT_ADVICE
from detections.models import Detection
from diseases.models import Disease
from plants.models import Plant


# ─────────────────────────────────────────────────────────────────────────────
# Static metadata
# ─────────────────────────────────────────────────────────────────────────────

PLANT_METADATA: dict[str, dict] = {
    "Apple":  {"scientific_name": "Malus domestica",       "family": "Rosaceae"},
    "Corn":   {"scientific_name": "Zea mays",              "family": "Poaceae"},
    "Grape":  {"scientific_name": "Vitis vinifera",        "family": "Vitaceae"},
    "Potato": {"scientific_name": "Solanum tuberosum",     "family": "Solanaceae"},
    "Tomato": {"scientific_name": "Solanum lycopersicum",  "family": "Solanaceae"},
    "Pepper": {"scientific_name": "Capsicum annuum",       "family": "Solanaceae"},
}

DISEASE_SEVERITY: dict[str, str] = {
    "Apple Scab":                         "moderate",
    "Black Rot":                          "severe",
    "Cedar Apple Rust":                   "moderate",
    "Early Blight":                       "moderate",
    "Late Blight":                        "severe",
    "Esca (Black Measles)":               "severe",
    "Leaf Blight (Isariopsis Leaf Spot)": "moderate",
    "Bacterial Spot":                     "moderate",
    "Healthy":                            "mild",
}

DISEASE_SYMPTOMS: dict[str, str] = {
    "Apple Scab": (
        "Olive-green to dark scab-like lesions on leaves and fruit; "
        "defoliation in severe cases."
    ),
    "Black Rot": (
        "Dark brown to black cankers on twigs; circular fruit rot "
        "with concentric rings."
    ),
    "Cedar Apple Rust": (
        "Bright orange-yellow spots on upper leaf surface; "
        "tube-like projections on undersides."
    ),
    "Early Blight": (
        "Circular brown spots with concentric rings (target-board pattern) "
        "on lower leaves."
    ),
    "Late Blight": (
        "Water-soaked lesions rapidly turning brown; "
        "white mold on undersides; plant collapse."
    ),
    "Esca (Black Measles)": (
        "Tiger-stripe leaf discoloration; apoplexy (sudden vine death); "
        "internal wood streaking."
    ),
    "Leaf Blight (Isariopsis Leaf Spot)": (
        "Angular brown lesions; dark spots near leaf margins; "
        "premature defoliation."
    ),
    "Bacterial Spot": (
        "Small water-soaked spots turning brown with yellow halos "
        "on leaves and fruit."
    ),
    "Healthy": "Vigorous leaf color, no lesions, normal growth.",
}

DISEASE_AFFECTED: dict[str, str] = {
    "Apple Scab":                         "leaf, fruit",
    "Black Rot":                          "fruit, twig, leaf",
    "Cedar Apple Rust":                   "leaf",
    "Early Blight":                       "leaf, stem",
    "Late Blight":                        "leaf, stem, tuber",
    "Esca (Black Measles)":               "leaf, cane, wood",
    "Leaf Blight (Isariopsis Leaf Spot)": "leaf",
    "Bacterial Spot":                     "leaf, fruit",
    "Healthy":                            "leaf",
}


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def _remove_media_subdirs() -> None:
    media_root = Path(settings.MEDIA_ROOT)
    for rel in (
        "detections/uploads",
        "detections/gradcam_plant",
        "detections/gradcam_disease",
        "detections/gradcam",   # legacy path
        "plants",
        "diseases",
    ):
        target = media_root / rel
        if target.exists():
            shutil.rmtree(target)


# ─────────────────────────────────────────────────────────────────────────────
# Management command
# ─────────────────────────────────────────────────────────────────────────────

class Command(BaseCommand):
    help = (
        "Clear the plant/disease/detection catalog and reseed it "
        "from the two-stage model class labels."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--keep-media",
            action="store_true",
            help="Keep uploaded images and Grad-CAM outputs while clearing the DB.",
        )

    @transaction.atomic
    def handle(self, *args, **options):
        self.stdout.write("Clearing existing records …")
        Detection.objects.all().delete()
        Disease.objects.all().delete()
        Plant.objects.all().delete()

        if not options["keep_media"]:
            _remove_media_subdirs()
            self.stdout.write("  Media sub-directories cleared.")

        plants_created   = 0
        diseases_created = 0

        for plant_name in PLANT_CLASSES:
            meta = PLANT_METADATA.get(plant_name, {})
            plant = Plant.objects.create(
                name=plant_name,
                scientific_name=meta.get("scientific_name", ""),
                family=meta.get("family", ""),
                description=(
                    f"{plant_name} is supported by the Midori two-stage "
                    "plant disease detection pipeline."
                ),
            )
            plants_created += 1

            class_names = DISEASE_CLASSES.get(plant_name)
            if not class_names:
                self.stdout.write(
                    f"  {plant_name:<10} — no disease model yet (plant only)"
                )
                continue

            for disease_name in class_names:
                Disease.objects.create(
                    plant=plant,
                    name=disease_name,
                    description=(
                        f"{disease_name} as classified by the "
                        f"{plant_name} disease model."
                    ),
                    cause=TREATMENT_ADVICE.get(disease_name, ""),
                    symptoms=DISEASE_SYMPTOMS.get(disease_name, ""),
                    remedy=TREATMENT_ADVICE.get(disease_name, ""),
                    prevention="",
                    severity=DISEASE_SEVERITY.get(disease_name, "moderate"),
                    affected_parts=DISEASE_AFFECTED.get(disease_name, "leaf"),
                )
                diseases_created += 1

            self.stdout.write(
                f"  {plant_name:<10} — {len(class_names)} disease classes seeded"
            )

        self.stdout.write(
            self.style.SUCCESS(
                f"\n[OK] Seeded {plants_created} plants and {diseases_created} diseases."
            )
        )