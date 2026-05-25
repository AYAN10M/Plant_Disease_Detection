"""
Quick integration test — sends a synthetic leaf image to the running server
and pretty-prints the full two-stage response.

Usage:
    python scripts/test_detection.py
    python scripts/test_detection.py --override Potato
    python scripts/test_detection.py --image /path/to/leaf.jpg
"""

import argparse
import io
import json
import sys
from pathlib import Path

import numpy as np
import requests
from PIL import Image

BASE    = "http://127.0.0.1:8000"
TIMEOUT = 120


def _synth_image() -> bytes:
    arr = np.zeros((300, 300, 3), dtype=np.uint8)
    arr[:, :, 1] = 140; arr[:, :, 0] = 60; arr[:, :, 2] = 40
    arr[100:140, 100:140, :] = [40, 30, 20]   # dark lesion
    arr[50:80, 200:230, :]   = [80, 20, 10]   # rust-like spot
    buf = io.BytesIO()
    Image.fromarray(arr).save(buf, format="JPEG")
    return buf.getvalue()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--override", help="Force plant name, e.g. Potato")
    parser.add_argument("--image",    help="Path to a real leaf JPEG/PNG")
    args = parser.parse_args()

    if args.image:
        img_bytes = Path(args.image).read_bytes()
        filename  = Path(args.image).name
    else:
        img_bytes = _synth_image()
        filename  = "leaf.jpg"

    fields: dict = {}
    if args.override:
        fields["plant_override"] = args.override

    print(f"POST {BASE}/api/detections/  (image={filename}, override={args.override})")
    r = requests.post(
        f"{BASE}/api/detections/",
        files={"uploaded_image": (filename, img_bytes, "image/jpeg")},
        data=fields,
        timeout=TIMEOUT,
    )

    print(f"HTTP {r.status_code}\n")
    body = r.json()
    print(json.dumps(body, indent=2))

    # Grad-CAM check
    det  = body.get("data", {})
    for label, key in [("Stage-1 Plant CAM", "plant_gradcam_image"),
                        ("Stage-2 Disease CAM", "gradcam_image")]:
        url = det.get(key)
        if url:
            gr = requests.get(url, timeout=10)
            status = "✅ accessible" if gr.status_code == 200 else f"HTTP {gr.status_code}"
            print(f"\n{label}: {url}\n  → {status} ({len(gr.content):,} bytes)")
        else:
            print(f"\n{label}: (not returned)")


if __name__ == "__main__":
    main()
