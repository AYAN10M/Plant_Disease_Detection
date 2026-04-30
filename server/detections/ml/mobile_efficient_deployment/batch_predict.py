"""
batch_predict.py
================
Run the plant disease detector on a whole folder of images.

Usage
-----
    python batch_predict.py --input  path/to/images/
                            --output path/to/results/
                            --model  path/to/plant_disease_mobilenet.h5

The script will:
  • Process every supported image found in the input folder (recursively).
  • Save Grad-CAM result figures to the output folder.
  • Write a CSV summary  (results.csv) with all predictions.
"""

import argparse
import csv
import os
import sys
import time

# ── Allow importing from the same package ─────────────────────────────────────
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from predict import load_model, predict, MODEL_PATH

SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".tiff", ".tif", ".webp"}


# ──────────────────────────────────────────────────────────────────────────────
def collect_images(folder: str) -> list[str]:
    """Return all supported image paths found in *folder* (recursive)."""
    paths = []
    for root, _, files in os.walk(folder):
        for f in files:
            if os.path.splitext(f)[1].lower() in SUPPORTED_EXTENSIONS:
                paths.append(os.path.join(root, f))
    return sorted(paths)


# ──────────────────────────────────────────────────────────────────────────────
def run_batch(
    input_folder: str,
    output_folder: str,
    model_path: str,
    leaf_threshold: float = 0.08,
) -> None:
    os.makedirs(output_folder, exist_ok=True)

    images = collect_images(input_folder)
    if not images:
        sys.exit(f"[ERROR] No supported images found in: {input_folder}")

    print(f"[INFO] Found {len(images)} image(s) – loading model …")
    model = load_model(model_path)

    csv_path = os.path.join(output_folder, "results.csv")
    fieldnames = [
        "image", "is_leaf", "leaf_confidence",
        "status", "plant", "condition", "confidence",
        "top1_class", "top2_class", "top2_confidence",
        "result_figure",
    ]

    with open(csv_path, "w", newline="", encoding="utf-8") as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()

        for idx, img_path in enumerate(images, start=1):
            rel_name = os.path.relpath(img_path, input_folder)
            print(f"\n[{idx}/{len(images)}] {rel_name}")
            t0 = time.perf_counter()

            # Flat output filename (replace separators to avoid sub-folders)
            safe_name = rel_name.replace(os.sep, "__").replace("/", "__")
            base = os.path.splitext(safe_name)[0]
            out_path = os.path.join(output_folder, f"{base}_gradcam_result.jpg")

            try:
                results = predict(
                    image_path=img_path,
                    model=model,
                    output_path=out_path,
                    leaf_threshold=leaf_threshold,
                )
            except Exception as exc:
                print(f"  [WARN] Failed to process {rel_name}: {exc}")
                writer.writerow({
                    "image": rel_name,
                    "is_leaf": "ERROR",
                    "leaf_confidence": "",
                    "status": str(exc),
                    "plant": "", "condition": "", "confidence": "",
                    "top1_class": "", "top2_class": "", "top2_confidence": "",
                    "result_figure": "",
                })
                continue

            elapsed = time.perf_counter() - t0
            top3 = results.get("top3", [])

            row = {
                "image": rel_name,
                "is_leaf": results.get("is_leaf", False),
                "leaf_confidence": results.get("leaf_confidence", 0),
                "status": results.get("status", ""),
                "plant": results.get("plant", ""),
                "condition": results.get("condition", ""),
                "confidence": results.get("confidence", 0),
                "top1_class": top3[0][0] if len(top3) > 0 else "",
                "top2_class": top3[1][0] if len(top3) > 1 else "",
                "top2_confidence": top3[1][1] if len(top3) > 1 else "",
                "result_figure": out_path if os.path.exists(out_path) else "",
            }
            writer.writerow(row)
            print(f"  Done in {elapsed:.2f}s  →  {results.get('status', '?')}"
                  f"  ({results.get('confidence', 0):.1f}%)")

    print(f"\n[INFO] Batch complete. CSV summary saved → {csv_path}")
    print(f"[INFO] Result figures saved in → {output_folder}")


# ──────────────────────────────────────────────────────────────────────────────
def parse_args():
    parser = argparse.ArgumentParser(
        description="Batch plant disease detection with Grad-CAM"
    )
    parser.add_argument("--input",  "-i", required=True,
                        help="Input folder containing images")
    parser.add_argument("--output", "-o", required=True,
                        help="Output folder for results & CSV")
    parser.add_argument("--model",  "-m", default=MODEL_PATH,
                        help=f"Path to .h5 model (default: {MODEL_PATH})")
    parser.add_argument("--leaf-threshold", type=float, default=0.08,
                        help="Green-pixel ratio threshold for leaf detection")
    return parser.parse_args()


# ──────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    args = parse_args()
    run_batch(
        input_folder=args.input,
        output_folder=args.output,
        model_path=args.model,
        leaf_threshold=args.leaf_threshold,
    )
