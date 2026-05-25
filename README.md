# 🌿 Midori — AI Plant Disease Detector

> **Two-stage deep learning pipeline** · Plant ID → Disease Detection · Grad-CAM visualisation · Flutter mobile app · Django REST backend

---

## Architecture

```
Photo → Stage 1 (MobileNetV2 Plant ID, 6 classes)
      ↘ HSV leaf isolation (OpenCV)
          ↘ Stage 2 (Per-plant Disease Model, 2–4 classes)
              ↘ Grad-CAM heat-map for both stages
```

**Supported plants:** Apple · Corn · Grape · Potato · Tomato · Pepper  
**Disease models:** Apple (4) · Grape (4) · Potato (3) · Pepper (2) · _Corn & Tomato = plant-only_

---

## Tech Stack

| Layer   | Technology                                       |
| ------- | ------------------------------------------------ |
| ML      | TensorFlow 2.21 · Keras 3 · OpenCV · MobileNetV2 |
| Backend | Django 5 · Django REST Framework · PostgreSQL    |
| Mobile  | Flutter 3 · Dart · Riverpod                      |
| Python  | 3.13                                             |

---

## Project Structure

```
Plant_Disease_Detection/
├── docs/
│   ├── notebooks/          Research Jupyter notebooks (Apple, Grape, Pepper, Potato, Plant ID)
│   └── reports/            HTML reference documents
│
├── server/                 Django REST API
│   ├── apps/
│   │   ├── detections/     Core detection app — engine, models, views, Grad-CAM
│   │   ├── diseases/       Disease catalog (seeded from engine class labels)
│   │   └── plants/         Plant catalog
│   ├── config/             Django project settings, URLs, wsgi/asgi
│   │   └── settings/       base.py · development.py · production.py
│   ├── ml/
│   │   ├── models/         Extracted .keras files  (gitignored — run setup_models.py)
│   │   └── weights/        Source .keras.zip archives
│   ├── scripts/
│   │   ├── setup_models.py Extract .keras from weights/
│   │   ├── smoke_test.py   Full two-stage API smoke test
│   │   └── test_detection.py  Quick integration test (--image / --override)
│   ├── constants.py        Thresholds, status messages
│   ├── manage.py
│   └── requirements.txt    All unified dependencies (Django + TensorFlow)
│
└── mobile/                 Flutter client app
    └── lib/
        ├── core/
        │   ├── constants/  app_constants.dart  (timeouts, limits, status codes)
        │   ├── network/    api_service.dart     (MidoriApiClient)
        │   └── theme/      app_theme.dart       (AppTheme, AppColors)
        └── features/scan/
            ├── models/     detection_model.dart (DetectionResult, HistoryEntry)
            ├── screens/    scan_screen.dart     (Scan + History tabs)
            └── services/   history_service.dart (SharedPreferences)
```

---

## Quick Start

### Prerequisites

- Python 3.13 (installed)
- PostgreSQL running locally
- Flutter SDK ≥ 3.5

### 1. Backend — First Time Setup

```bash
cd server

# Install all dependencies (TF 2.21 + Django + OpenCV)
py -m pip install -r requirements.txt

# Configure environment
cp .env.example .env
# → Edit .env: fill in SECRET_KEY, DB_NAME, DB_USER, DB_PASSWORD

# Extract Keras models from zips
py scripts/setup_models.py

# Apply DB migrations + seed plant/disease catalog
py manage.py migrate
py manage.py seed_model_catalog

# Start dev server (port 8000, all interfaces)
py manage.py runserver 0.0.0.0:8000
```

### 2. Verify Backend

```bash
# With server running:
py scripts/smoke_test.py

# Test with a real leaf image:
py scripts/test_detection.py --image /path/to/leaf.jpg

# Force a specific plant (skip Stage 1):
py scripts/test_detection.py --image /path/to/leaf.jpg --override Potato
```

### 3. Mobile App

```bash
cd mobile
flutter pub get

# Android emulator (default):
flutter run

# Real device — set your server's LAN IP:
flutter run --dart-define=MIDORI_SERVER_IP=192.168.x.x

# Full base URL override:
flutter run --dart-define=MIDORI_BASE_URL=http://192.168.x.x:8000
```

---

## API Reference

### `GET /api/detections/health/`

```json
{
  "status": "ok",
  "model_ready": true,
  "pipeline": "two-stage",
  "plant_classes": ["Apple", "Corn", "Grape", "Potato", "Tomato", "Pepper"],
  "disease_models_loaded": ["Apple", "Potato", "Grape", "Pepper"]
}
```

### `POST /api/detections/`

**Form fields:**

| Field            | Type   | Required | Notes                        |
| ---------------- | ------ | :------: | ---------------------------- |
| `uploaded_image` | File   |    ✅    | JPEG/PNG/WebP, max 10 MB     |
| `plant_override` | String |    ❌    | Skip Stage 1 (e.g. `Potato`) |

**Response status values:**

| `status`         | Meaning                                    |
| ---------------- | ------------------------------------------ |
| `success`        | Disease detected with high confidence      |
| `healthy`        | No disease signs detected                  |
| `low_confidence` | Below 40 % confidence — retake recommended |
| `not_recognized` | Stage-1 plant ID failed                    |
| `no_model`       | Plant found but no disease model exists    |
| `not_a_plant`    | No green leaf detected in the image        |
| `failed`         | Internal server error                      |

---

## Re-seeding the Database

```bash
# Full reseed (wipes detections, diseases, plants + clears media):
py manage.py seed_model_catalog

# Keep existing media files:
py manage.py seed_model_catalog --keep-media
```
