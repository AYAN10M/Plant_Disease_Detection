"""Quick detection test — sends a real image to the running server."""
import requests, json, sys
from pathlib import Path
import numpy as np
from PIL import Image

BASE = "http://127.0.0.1:8000"

# Make a real-looking green leaf image
arr = np.zeros((300, 300, 3), dtype=np.uint8)
arr[:, :, 1] = 140; arr[:, :, 0] = 60; arr[:, :, 2] = 40

# Add some variation (dark spots like a disease lesion)
arr[100:140, 100:140, :] = [40, 30, 20]
arr[50:80, 200:230, :] = [80, 20, 10]

img_path = Path(__file__).parent / "_test_leaf_real.jpg"
Image.fromarray(arr).save(str(img_path))

print("Sending POST /api/detections/ ...")
with open(img_path, "rb") as fh:
    r = requests.post(
        f"{BASE}/api/detections/",
        files={"uploaded_image": ("leaf.jpg", fh, "image/jpeg")},
        timeout=120,
    )

img_path.unlink(missing_ok=True)
print(f"HTTP {r.status_code}")
body = r.json()
print(json.dumps(body, indent=2))

# Check gradcam
det = body.get("data", {})
gcam = det.get("gradcam_image")
print(f"\ngradcam_image field: {gcam}")
if gcam:
    # Try relative
    for url in [f"{BASE}/{gcam}", f"{BASE}/media/{gcam}", gcam]:
        try:
            gr = requests.get(url, timeout=5)
            if gr.status_code == 200:
                print(f"[PASS] Grad-CAM accessible at: {url} ({len(gr.content)} bytes)")
                break
            else:
                print(f"  {url} -> HTTP {gr.status_code}")
        except Exception as e:
            print(f"  {url} -> {e}")
