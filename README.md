# Midori 🌿
> AI-powered plant disease detection — MobileNetV2 + Grad-CAM

Midori is a full-stack application that diagnoses plant diseases from leaf photos. Upload an image and get an instant prediction with confidence score, disease details, and a Grad-CAM attention heatmap.

---

## Repository Structure

```
midori/
├── server/                    # Django REST API + ML inference engine
│   ├── config/                # Django project settings (WSGI, ASGI, URLs)
│   │   └── settings/
│   │       ├── base.py        # Shared settings
│   │       ├── development.py # Local dev overrides
│   │       └── production.py  # Production overrides
│   ├── detections/            # Core detection app (ML pipeline, API views)
│   │   └── engine.py          # MobileNetV2 inference + Grad-CAM
│   ├── diseases/              # Disease catalog app
│   ├── plants/                # Plant catalog app
│   ├── requirements/
│   │   ├── base.txt           # Core runtime deps (Django, DRF, Pillow)
│   │   ├── ml.txt             # + TensorFlow, NumPy, h5py
│   │   └── dev.txt            # + Jupyter, Matplotlib
│   ├── scripts/
│   │   └── smoke_test.py      # End-to-end API smoke test
│   ├── manage.py
│   ├── plant_disease_mobilenet.h5   # Trained model weights
│   └── .env.example
│
└── mobile/                    # Flutter mobile client
    ├── lib/
    │   ├── main.dart
    │   ├── core/
    │   │   ├── theme/         # App theme (light/dark)
    │   │   └── network/       # HTTP API client
    │   └── features/
    │       └── scan/          # Disease scan feature
    │           ├── models/    # Data models (API response, history entry)
    │           ├── screens/   # ScanScreen (main UI)
    │           └── services/  # Local history persistence
    └── assets/
        └── ml/                # Bundled TFLite model
```

---

## Quick Start

### Server
```bash
cd server
python -m venv venv
venv\Scripts\activate          # Windows
pip install -r requirements/dev.txt
cp .env.example .env           # fill in DB credentials
python manage.py migrate
python manage.py seed_model_catalog
python manage.py runserver 0.0.0.0:8000
```

### Mobile
```bash
cd mobile
flutter pub get
flutter run --dart-define=MIDORI_API_BASE_URL=http://<YOUR_LAN_IP>:8000
```

---

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET`  | `/api/detections/health/` | Model readiness check |
| `POST` | `/api/detections/`        | Upload image, get prediction |
| `GET`  | `/api/plants/`            | Plant catalog |
| `GET`  | `/api/diseases/`          | Disease catalog |