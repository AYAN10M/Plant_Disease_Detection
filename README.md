<h1 align="center">🌿 Midori — Plant Disease Detection</h1>

<p align="center">
  <em>A two-stage deep learning pipeline for plant species identification and disease diagnosis, with Grad-CAM explainability.</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Backend-Django%205-092e20?style=flat-square&logo=django" alt="Django">
  <img src="https://img.shields.io/badge/ML-TensorFlow%202-FF6F00?style=flat-square&logo=tensorflow" alt="TensorFlow">
  <img src="https://img.shields.io/badge/Mobile-Flutter%203-02569B?style=flat-square&logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/DB-PostgreSQL-4169E1?style=flat-square&logo=postgresql" alt="PostgreSQL">
  <img src="https://img.shields.io/badge/Architecture-MobileNetV2-green?style=flat-square" alt="MobileNetV2">
</p>

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [ML Pipeline](#ml-pipeline)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [API Reference](#api-reference)
- [Mobile App](#mobile-app)
- [Supported Plants & Diseases](#supported-plants--diseases)
- [Configuration](#configuration)

---

## Overview

Midori is a full-stack plant disease detection system designed for agricultural diagnostics. It combines computer vision with a mobile-first interface to help farmers and plant enthusiasts identify diseases from leaf photographs.

### Key Features

| Feature | Description |
|---------|-------------|
| **Two-Stage ML Pipeline** | Stage 1 identifies the plant species (6 classes). Stage 2 runs a plant-specific disease model. |
| **Grad-CAM Heatmaps** | Visual explanations for both stages showing which regions of the leaf influenced the prediction. |
| **HSV Leaf Isolation** | OpenCV preprocessing isolates the green leaf from background, improving model accuracy. |
| **Calibrated Thresholds** | Per-plant confidence thresholds prevent false positives from biased models (e.g., Grape Esca bias). |
| **Offline History** | Flutter app stores scan history locally with base64-encoded images for offline review. |
| **Dark Mode** | Full dark/light theme support with a nature-inspired green palette. |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter Mobile App                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐ │
│  │ Scan Tab │  │ History  │  │ Widgets  │  │ API Service      │ │
│  │ (state)  │  │ Tab      │  │ (15 pcs) │  │ (HTTP + polling) │ │
│  └──────────┘  └──────────┘  └──────────┘  └────────┬─────────┘ │
└──────────────────────────────────────────────────────┼───────────┘
                                                       │ REST API
┌──────────────────────────────────────────────────────┼───────────┐
│                     Django REST Backend              │           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┼────────┐  │
│  │ detections/  │  │ plants/      │  │ diseases/    │        │  │
│  │ views.py     │  │ models.py    │  │ models.py    │        │  │
│  │ engine.py    │  │ serializers  │  │ serializers  │        │  │
│  └──────┬───────┘  └──────────────┘  └──────────────┘        │  │
│         │                                                     │  │
│  ┌──────┴───────────────────────────────────────────────────┐ │  │
│  │                  ML Inference Engine                      │ │  │
│  │  ┌─────────────────┐  ┌───────────────────────────────┐  │ │  │
│  │  │ Stage 1:        │  │ Stage 2:                      │  │ │  │
│  │  │ Plant ID        │──│ Disease Detection             │  │ │  │
│  │  │ (MobileNetV2)   │  │ (Per-plant MobileNetV2)       │  │ │  │
│  │  │ 6 classes       │  │ Apple(4) Grape(4) Potato(3)   │  │ │  │
│  │  │                 │  │ Pepper(2)                     │  │ │  │
│  │  └─────────┬───────┘  └──────────────┬────────────────┘  │ │  │
│  │            │                          │                   │ │  │
│  │  ┌─────────┴──────────────────────────┴────────────────┐  │ │  │
│  │  │ Preprocessing: HSV Isolation → Resize → Normalize   │  │ │  │
│  │  │ Explainability: Grad-CAM heatmap generation         │  │ │  │
│  │  └────────────────────────────────────────────────────┘  │ │  │
│  └──────────────────────────────────────────────────────────┘ │  │
│                                                               │  │
│  ┌────────────────────────────┐                               │  │
│  │ PostgreSQL                 │                               │  │
│  │ Plants │ Diseases │ Scans  │                               │  │
│  └────────────────────────────┘                               │  │
└───────────────────────────────────────────────────────────────────┘
```

---

## ML Pipeline

### Stage 1 — Plant Identification

| Property | Value |
|----------|-------|
| **Model** | MobileNetV2 (transfer learning) |
| **Input** | 224×224 RGB, normalized to [0, 1] |
| **Classes** | Apple, Corn, Grape, Potato, Tomato, Pepper |
| **Output** | Softmax probabilities for all 6 classes |
| **Threshold** | 40% minimum (configurable per-request) |

### Stage 2 — Disease Detection

Runs only for plants with a trained disease model (Apple, Grape, Potato, Pepper).

| Plant | Disease Classes |
|-------|----------------|
| **Apple** | Apple Scab, Black Rot, Cedar Apple Rust, Healthy |
| **Grape** | Black Rot, Esca (Black Measles), Leaf Blight, Healthy |
| **Potato** | Early Blight, Late Blight, Healthy |
| **Pepper** | Bacterial Spot, Healthy |

### Preprocessing

1. **OpenCV HSV Isolation** — Extracts the green channel (H: 25–90, S: 30–255, V: 30–255) to isolate the leaf from the background
2. **Brightness Normalization** — Adjusts exposure for over/underexposed images
3. **Resize** — Bilinear interpolation to 224×224
4. **Normalization** — Pixel values scaled to [0, 1]

### Grad-CAM Explainability

Both stages produce Grad-CAM heatmaps from the `out_relu` layer of MobileNetV2, overlaid on the original image with a jet colormap at 50% opacity.

---

## Project Structure

```
Plant_Disease_Detection/
├── server/                          # Django REST API backend
│   ├── apps/
│   │   ├── detections/              # Core detection app
│   │   │   ├── engine.py            # ML inference engine (866 lines)
│   │   │   ├── views.py             # API endpoints
│   │   │   ├── models.py            # Detection DB model
│   │   │   ├── serializers.py       # DRF serializers
│   │   │   └── management/commands/ # seed_model_catalog command
│   │   ├── plants/                  # Plant catalog (models, views, admin)
│   │   └── diseases/                # Disease catalog (models, views, admin)
│   ├── config/
│   │   ├── settings/
│   │   │   ├── base.py              # Shared Django settings
│   │   │   ├── development.py       # Dev overrides (DEBUG=True)
│   │   │   └── production.py        # Production hardening
│   │   └── urls.py                  # Root URL configuration
│   ├── ml/
│   │   ├── models/                  # Extracted .keras model files
│   │   └── weights/                 # Source .keras.zip archives
│   ├── scripts/
│   │   ├── setup_models.py          # Extract models from zip archives
│   │   └── smoke_test.py            # API integration test
│   ├── constants.py                 # Application-wide constants (single source of truth)
│   ├── requirements.txt             # Pinned Python dependencies
│   ├── .env                         # Local environment variables (NOT committed)
│   └── .env.example                 # Environment template (committed)
│
├── mobile/                          # Flutter mobile app
│   ├── lib/
│   │   ├── core/
│   │   │   ├── constants/           # App constants (endpoints, limits)
│   │   │   ├── network/             # API client (MidoriApiClient)
│   │   │   └── theme/               # Material 3 theme (AppColors, AppTheme)
│   │   ├── features/
│   │   │   └── scan/
│   │   │       ├── models/          # DetectionResult, DetectionHistoryEntry
│   │   │       ├── screens/         # ScanScreen (state management shell)
│   │   │       ├── services/        # DetectionHistoryStore (SharedPreferences)
│   │   │       └── widgets/         # 15 extracted UI components
│   │   │           ├── confidence_chip.dart
│   │   │           ├── confidence_slider.dart
│   │   │           ├── detail_group.dart
│   │   │           ├── detail_line.dart
│   │   │           ├── fullscreen_image_viewer.dart
│   │   │           ├── history_card.dart
│   │   │           ├── history_controls.dart
│   │   │           ├── image_card.dart
│   │   │           ├── notice_card.dart
│   │   │           ├── plant_override_dropdown.dart
│   │   │           ├── preview_tile.dart
│   │   │           ├── result_card.dart
│   │   │           ├── score_chart.dart
│   │   │           ├── stage_confidence_bar.dart
│   │   │           └── status_banner.dart
│   │   └── main.dart                # App entry point
│   └── pubspec.yaml                 # Flutter dependencies
│
└── docs/                            # Documentation assets
```

---

## Getting Started

### Prerequisites

- Python 3.10+
- PostgreSQL 14+
- Flutter 3.19+ & Dart 3.3+
- Node.js (optional, for tooling)

### Server Setup

```bash
# 1. Clone and navigate
cd Plant_Disease_Detection/server

# 2. Create virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Configure environment
cp .env.example .env
# Edit .env with your database credentials and a new SECRET_KEY

# 5. Extract ML models from zip archives
python scripts/setup_models.py

# 6. Run migrations
python manage.py migrate

# 7. Seed the plant/disease catalog
python manage.py seed_model_catalog

# 8. Start the server
python manage.py runserver 0.0.0.0:8000
```

### Mobile Setup

```bash
# 1. Navigate to mobile directory
cd Plant_Disease_Detection/mobile

# 2. Get dependencies
flutter pub get

# 3. Update API base URL in lib/core/constants/app_constants.dart
#    Set it to your server's IP address

# 4. Run on device/emulator
flutter run
```

### Smoke Test

```bash
# With the server running:
cd server
python scripts/smoke_test.py
```

---

## API Reference

### Health Check

```
GET /api/detections/health/
```

Returns model readiness status, loaded classes, and pipeline info.

### Detect Disease

```
POST /api/detections/
Content-Type: multipart/form-data
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `uploaded_image` | File | ✅ | Leaf photo (JPEG/PNG/WebP, max 10 MB) |
| `plant_override` | String | ❌ | Skip Stage 1; force a specific plant (e.g., "Apple") |
| `confidence_threshold` | Float | ❌ | Min confidence % for Stage 1 (default: 40.0) |

**Response statuses:** `success`, `healthy`, `low_confidence`, `not_recognized`, `no_model`, `not_a_plant`

### Plant & Disease Catalog

```
GET /api/plants/              # List all plants
GET /api/plants/<id>/         # Plant detail
GET /api/diseases/            # List diseases (filter by ?plant=<id>)
GET /api/diseases/<id>/       # Disease detail
```

---

## Mobile App

### Widget Architecture

The Flutter app follows a **feature-first** structure with 15 extracted UI components:

| Widget | Responsibility |
|--------|---------------|
| `ScanScreen` | State management shell, business logic, navigation |
| `PlantOverrideDropdown` | Plant selection dropdown (Auto-detect or manual) |
| `ConfidenceSlider` | Min confidence threshold slider with guidance text |
| `ImageCard` | Three-panel preview (Original + Plant CAM + Disease CAM) |
| `ResultCard` | Full detection result with banners, bars, details |
| `StatusBanner` | Color-coded status header (healthy/disease/error) |
| `StageConfidenceBar` | Animated confidence bar for a single stage |
| `ScoreChart` | All-class score bar chart |
| `HistoryCard` | Expandable history entry with swipe-to-delete |
| `HistoryControls` | Search + filter + sort controls |
| `NoticeCard` | Feedback/error/loading notice |
| `DetailGroup` | Bordered section container |
| `DetailLine` | Label + value row |
| `ConfidenceChip` | Color-coded confidence badge |
| `PreviewTile` | Image preview with fullscreen support |
| `FullscreenImageViewer` | Pinch-to-zoom fullscreen dialog |

---

## Supported Plants & Diseases

| Plant | Scientific Name | Disease Classes |
|-------|----------------|-----------------|
| 🍎 Apple | *Malus domestica* | Apple Scab, Black Rot, Cedar Apple Rust, Healthy |
| 🍇 Grape | *Vitis vinifera* | Black Rot, Esca (Black Measles), Leaf Blight, Healthy |
| 🥔 Potato | *Solanum tuberosum* | Early Blight, Late Blight, Healthy |
| 🌶️ Pepper | *Capsicum annuum* | Bacterial Spot, Healthy |
| 🌽 Corn | *Zea mays* | *Stage 1 only — no disease model* |
| 🍅 Tomato | *Solanum lycopersicum* | *Stage 1 only — no disease model* |

---

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SECRET_KEY` | — | Django secret key (required) |
| `DEBUG` | `True` | Django debug mode |
| `ALLOWED_HOSTS` | `localhost,...` | Comma-separated allowed hosts |
| `DB_NAME` | `plant_disease` | PostgreSQL database name |
| `DB_USER` | `postgres` | Database user |
| `DB_PASSWORD` | — | Database password (required) |
| `DB_HOST` | `localhost` | Database host |
| `DB_PORT` | `5432` | Database port |
| `CORS_ALLOWED_ORIGINS` | — | Comma-separated CORS origins |

### Per-Plant Confidence Thresholds

Defined in `server/constants.py`:

| Plant | Threshold | Rationale |
|-------|-----------|-----------|
| Apple | 55% | Well-calibrated model |
| Potato | 55% | Well-calibrated model |
| Grape | 75% | Systematic Esca bias on dark/featureless images |
| Pepper | 55% | Well-calibrated model |
