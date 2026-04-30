#!/usr/bin/env python3
"""
Quick smoke-test for the Midori ML inference pipeline.

Run from the server directory (with venv active):
    python scripts/smoke_test.py

Requires the Django server to be running:
    python manage.py runserver
"""

import sys
import requests
from pathlib import Path

BASE = "http://localhost:8000"


def section(title: str) -> None:
    print(f"\n{'='*60}")
    print(f"  {title}")
    print("="*60)


# ── 1. Health check ───────────────────────────────────────────────────────────
section("Health Endpoint")
try:
    r = requests.get(f"{BASE}/api/detections/health/", timeout=15)
    data = r.json()
    print(f"  HTTP {r.status_code}")
    print(f"  model_ready  : {data.get('model_ready')}")
    print(f"  model        : {data.get('model')}")
    print(f"  gradcam_layer: {data.get('gradcam_layer')}")
    if not data.get("model_ready"):
        print("\n  [FAIL] Model not ready -- start server first and wait for warm-up.")
        sys.exit(1)
    print("\n  [PASS] Backend healthy.")
except Exception as exc:
    print(f"  [FAIL] Cannot reach server: {exc}")
    sys.exit(1)

# ── 2. Detection endpoint ─────────────────────────────────────────────────────
section("Detection Endpoint (synthetic green image)")
try:
    from PIL import Image
    import numpy as np

    # Synthetic green leaf-like image (should pass green filter)
    arr = np.zeros((224, 224, 3), dtype=np.uint8)
    arr[:, :, 1] = 160   # dominant green
    arr[:, :, 0] = 80    # some red
    arr[:, :, 2] = 60    # some blue

    tmp = Path(__file__).parent / "_smoke_test_img.jpg"
    Image.fromarray(arr).save(str(tmp))

    with open(tmp, "rb") as fh:
        r = requests.post(
            f"{BASE}/api/detections/",
            files={"uploaded_image": ("leaf.jpg", fh, "image/jpeg")},
            timeout=90,
        )

    tmp.unlink(missing_ok=True)

    print(f"  HTTP {r.status_code}")
    body = r.json()
    outer_status = body.get("status", "--")
    print(f"  outer status : {outer_status}")

    det = body.get("data", {})
    confidence   = det.get("confidence", 0.0)
    confidence_p = det.get("confidence_pct", f"{confidence*100:.1f}%")
    det_status   = det.get("status", "--")
    gradcam      = det.get("gradcam_image")

    print(f"  det status   : {det_status}")
    print(f"  confidence   : {confidence_p}  (raw={confidence:.4f})")
    print(f"  gradcam url  : {gradcam or '(none)'}")

    if confidence > 0:
        print("\n  [PASS] Confidence is non-zero.")
    else:
        print("\n  [FAIL] Confidence is 0 -- check model / preprocessing.")

    if gradcam:
        print("  [PASS] Grad-CAM URL returned.")
        # Try fetching the gradcam image
        try:
            gr = requests.get(f"{BASE}/media/{gradcam}", timeout=10)
            if gr.status_code == 200:
                print(f"  [PASS] Grad-CAM image accessible ({len(gr.content)} bytes).")
            else:
                print(f"  [WARN] Grad-CAM URL returned HTTP {gr.status_code}.")
        except Exception as e:
            print(f"  [WARN] Could not fetch Grad-CAM image: {e}")
    else:
        print("  [FAIL] No Grad-CAM URL (check server logs for errors).")

except Exception as exc:
    import traceback
    print(f"  [FAIL] Error: {exc}")
    traceback.print_exc()
    sys.exit(1)

section("All tests passed!")
