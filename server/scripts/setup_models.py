"""
setup_models.py - Extract / install Keras model files from ml/weights/ zip archives.

Run once from the server/ directory BEFORE starting the Django server:
    python scripts/setup_models.py

The zip archives contain Keras 3 SavedModel bundles:
    metadata.json  config.json  model.weights.h5

Each zip is extracted into its own subdirectory under ml/models/, then
renamed to a plain .keras directory so keras.models.load_model() can find it.

Layout after extraction:
    ml/models/plant_identifier.keras/   <- directory, not file
    ml/models/Apple_disease.keras/
    ml/models/Potato_disease.keras/
    ml/models/Grape_disease.keras/
    ml/models/Pepper_disease.keras/
"""

import shutil
import zipfile
from pathlib import Path

# ── Paths ──────────────────────────────────────────────────────────────────
# This file lives at  server/scripts/setup_models.py
# SERVER_DIR is always two levels up from this file.
_THIS       = Path(__file__).resolve()
SERVER_DIR  = _THIS.parent.parent          # server/
ML_DIR      = SERVER_DIR / "ml"
WEIGHTS_DIR = ML_DIR / "weights"
MODELS_DIR  = ML_DIR / "models"

# zip-name in weights/ -> directory name in models/
MODELS = {
    "plant_identifier.keras.zip":  "plant_identifier.keras",
    "Apple_disease.keras.zip":     "Apple_disease.keras",
    "Potato_disease.keras.zip":    "Potato_disease.keras",
    "Grape_disease.keras.zip":     "Grape_disease.keras",
    "Pepper_disease.keras.zip":    "Pepper_disease.keras",
}


def extract_models() -> None:
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    print(f"\n[Midori] Model Setup\n{'='*50}")
    print(f"  Source : {WEIGHTS_DIR}")
    print(f"  Target : {MODELS_DIR}\n")

    if not WEIGHTS_DIR.exists():
        print(f"  [ERROR] Weights directory not found: {WEIGHTS_DIR}")
        print("     Make sure the .keras.zip files are in server/ml/weights/")
        return

    found_any = False
    for zip_name, keras_name in MODELS.items():
        dest = MODELS_DIR / keras_name

        if dest.exists():
            size_mb = dest.stat().st_size / (1024 * 1024)
            print(f"  [OK]  {keras_name:<35} ({size_mb:.1f} MB) -- already exists")
            found_any = True
            continue

        zip_path = WEIGHTS_DIR / zip_name
        if not zip_path.exists():
            print(f"  [--]  {zip_name:<35} NOT FOUND in ml/weights/")
            continue

        print(f"  [...] Installing {zip_name} ...", end="", flush=True)
        try:
            with zipfile.ZipFile(zip_path, "r") as zf:
                names = zf.namelist()

            # Case 1: Keras 3 SavedModel bundle
            # The zip contains metadata.json + config.json + model.weights.h5
            # In Keras 3, a .keras file IS a zip with this exact structure.
            # Simply copy the zip as the .keras file.
            if "metadata.json" in names and "config.json" in names:
                shutil.copy2(str(zip_path), str(dest))

            # Case 2: Legacy format — zip wraps a single .keras file
            elif any(n.endswith(".keras") for n in names):
                keras_entry = next(n for n in names if n.endswith(".keras"))
                tmp_dir = MODELS_DIR / "_tmp_extract"
                tmp_dir.mkdir(exist_ok=True)
                with zipfile.ZipFile(zip_path, "r") as zf:
                    zf.extract(keras_entry, tmp_dir)
                shutil.move(str(tmp_dir / keras_entry), str(dest))
                shutil.rmtree(tmp_dir, ignore_errors=True)

            else:
                print(f"\n    [ERROR] Unrecognised zip layout: {names[:5]}")
                continue

            size_mb = dest.stat().st_size / (1024 * 1024)
            print(f" [OK] ({size_mb:.1f} MB)")
            found_any = True

        except Exception as exc:
            print(f"\n    [FAIL] {exc}")
            shutil.rmtree(MODELS_DIR / "_tmp_extract", ignore_errors=True)

    print(f"\n{'='*50}")
    if found_any:
        print("  Models available in ml/models/:")
        for entry in sorted(MODELS_DIR.iterdir()):
            if entry.name.startswith("_"):
                continue
            if entry.is_dir():
                size = sum(f.stat().st_size for f in entry.rglob("*") if f.is_file())
            else:
                size = entry.stat().st_size
            size_mb = size / (1024 * 1024)
            print(f"    * {entry.name:<35} ({size_mb:.1f} MB)")
    else:
        print("  [WARNING] No models were found or extracted.")
        print("     Make sure the .keras.zip files are in server/ml/weights/")

    print()


if __name__ == "__main__":
    extract_models()
