#!/usr/bin/env python3
"""
Midori — Two-Stage API Smoke Test
===================================

Run with the Django server already started:
    python scripts/smoke_test.py

Tests:
  1. GET  /api/detections/health/     — model warm-up check
  2. POST /api/detections/            — synthetic green-leaf image
  3. POST /api/detections/ (override) — force plant_override=Potato
"""

import sys
import io
import requests
import numpy as np
from pathlib import Path

BASE = "http://localhost:8000"
TIMEOUT_SHORT  = 15
TIMEOUT_DETECT = 120


def section(title: str) -> None:
    print(f"\n{'='*62}")
    print(f"  {title}")
    print("=" * 62)


def ok(msg: str)   -> None: print(f"  ✅ {msg}")
def fail(msg: str) -> None: print(f"  ❌ {msg}")
def warn(msg: str) -> None: print(f"  ⚠  {msg}")


# ── 1. Health check ───────────────────────────────────────────────────────────
section("1. Health Endpoint — GET /api/detections/health/")
try:
    r    = requests.get(f"{BASE}/api/detections/health/", timeout=TIMEOUT_SHORT)
    data = r.json()
    print(f"  HTTP {r.status_code}")
    print(f"  pipeline             : {data.get('pipeline')}")
    print(f"  model_ready          : {data.get('model_ready')}")
    print(f"  plant_classes        : {data.get('plant_classes')}")
    print(f"  disease_models_loaded: {data.get('disease_models_loaded')}")

    if not data.get("model_ready"):
        warn("Plant model not ready. Run  python setup_models.py  then restart server.")
        # Don't exit — detection might still work with on-demand loading
    else:
        ok("Backend healthy, all models loaded.")
except Exception as exc:
    fail(f"Cannot reach server: {exc}")
    sys.exit(1)


def _make_green_jpeg() -> bytes:
    """Synthetic 224×224 green leaf image as JPEG bytes."""
    from PIL import Image
    arr = np.zeros((224, 224, 3), dtype=np.uint8)
    arr[:, :, 1] = 150   # dominant green channel
    arr[:, :, 0] = 70    # some red
    arr[:, :, 2] = 55    # some blue
    buf = io.BytesIO()
    Image.fromarray(arr).save(buf, format="JPEG")
    return buf.getvalue()


def _assert_detection_response(body: dict, label: str) -> None:
    """Print key fields from a detection response and run basic assertions."""
    outer_status    = body.get("status", "--")
    message         = body.get("message", "")
    det             = body.get("data", {})

    plant_name      = det.get("plant_name", "--")
    plant_conf      = det.get("plant_confidence", 0.0)
    plant_pct       = det.get("plant_confidence_pct", "--")
    plant_scores    = det.get("plant_scores", [])
    plant_cam       = det.get("plant_gradcam_image")

    disease_detail  = det.get("disease_detail") or {}
    disease_name    = disease_detail.get("name", "--")
    disease_conf    = det.get("confidence", 0.0)
    disease_pct     = det.get("confidence_pct", "--")
    disease_scores  = det.get("disease_scores", [])
    disease_cam     = det.get("gradcam_image")
    advice          = det.get("advice", "")

    print(f"\n  [{label}]")
    print(f"  outer status     : {outer_status}  — {message[:80]}")
    print(f"  plant            : {plant_name}  ({plant_pct})  [{len(plant_scores)} scores]")
    print(f"  disease          : {disease_name}  ({disease_pct})  [{len(disease_scores)} scores]")
    print(f"  advice           : {advice[:80]}")
    print(f"  plant Grad-CAM   : {plant_cam or '(none)'}")
    print(f"  disease Grad-CAM : {disease_cam or '(none)'}")

    # Assertions
    if "data" not in body:
        fail("No 'data' key in response")
        return

    if plant_conf > 0:
        ok(f"Plant confidence non-zero ({plant_pct})")
    else:
        warn("Plant confidence is 0 — check model / preprocessing")

    if plant_scores:
        ok(f"plant_scores returned ({len(plant_scores)} entries)")
    else:
        warn("plant_scores is empty")

    if plant_cam:
        ok("Stage-1 Grad-CAM URL returned")
        try:
            gr = requests.get(plant_cam, timeout=10)
            if gr.status_code == 200:
                ok(f"Stage-1 Grad-CAM accessible ({len(gr.content):,} bytes)")
            else:
                warn(f"Stage-1 Grad-CAM HTTP {gr.status_code}")
        except Exception as e:
            warn(f"Could not fetch Stage-1 Grad-CAM: {e}")
    else:
        warn("No Stage-1 Grad-CAM URL (may be expected for not_recognized)")

    if disease_cam:
        ok("Stage-2 Grad-CAM URL returned")
        try:
            gr = requests.get(disease_cam, timeout=10)
            if gr.status_code == 200:
                ok(f"Stage-2 Grad-CAM accessible ({len(gr.content):,} bytes)")
            else:
                warn(f"Stage-2 Grad-CAM HTTP {gr.status_code}")
        except Exception as e:
            warn(f"Could not fetch Stage-2 Grad-CAM: {e}")


# ── 2. Detection — auto-detect ────────────────────────────────────────────────
section("2. Detection — POST /api/detections/ (auto-detect plant)")
try:
    jpeg_bytes = _make_green_jpeg()
    r = requests.post(
        f"{BASE}/api/detections/",
        files={"uploaded_image": ("leaf.jpg", jpeg_bytes, "image/jpeg")},
        timeout=TIMEOUT_DETECT,
    )
    print(f"  HTTP {r.status_code}")
    _assert_detection_response(r.json(), "auto-detect")
except Exception as exc:
    import traceback
    fail(f"Error: {exc}")
    traceback.print_exc()
    sys.exit(1)


# ── 3. Detection — plant_override=Potato ─────────────────────────────────────
section("3. Detection — POST /api/detections/ (plant_override=Potato)")
try:
    jpeg_bytes = _make_green_jpeg()
    r = requests.post(
        f"{BASE}/api/detections/",
        files={"uploaded_image": ("leaf.jpg", jpeg_bytes, "image/jpeg")},
        data={"plant_override": "Potato"},
        timeout=TIMEOUT_DETECT,
    )
    print(f"  HTTP {r.status_code}")
    _assert_detection_response(r.json(), "Potato override")
except Exception as exc:
    import traceback
    fail(f"Error: {exc}")
    traceback.print_exc()
    sys.exit(1)


section("Smoke test complete")
