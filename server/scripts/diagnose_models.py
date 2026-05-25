"""
diagnose_models.py
==================
Reads every trained Keras model and prints:
  1. Exact class order (index 0, 1, 2, …) that the model outputs
  2. Raw softmax scores on a uniform grey image (224x224)
  3. Comparison with what engine.py EXPECTS for that class order

Run from server/ directory:
    python scripts/diagnose_models.py

This helps catch index-order mismatches between training and inference.
"""
import sys
import json
import numpy as np
from pathlib import Path

SERVER_DIR = Path(__file__).resolve().parent.parent
ML_DIR     = SERVER_DIR / "ml" / "models"

# What engine.py currently expects for each plant
ENGINE_CLASSES = {
    "plant_identifier": ["Apple", "Corn", "Grape", "Potato", "Tomato", "Pepper"],
    "Apple_disease":    ["Apple Scab", "Black Rot", "Cedar Apple Rust", "Healthy"],
    "Potato_disease":   ["Early Blight", "Late Blight", "Healthy"],
    "Grape_disease":    ["Black Rot", "Esca (Black Measles)", "Leaf Blight (Isariopsis Leaf Spot)", "Healthy"],
    "Pepper_disease":   ["Bacterial Spot", "Healthy"],
}

def get_model_class_order(model_path: Path) -> list | None:
    """
    Try to read class_names from model metadata (Keras 3 SavedModel format).
    Falls back to None if not embedded.
    """
    # Keras 3 .keras is a zip file containing config.json
    import zipfile
    if not model_path.is_file():
        # It's a directory-format SavedModel — look for saved_model_metadata
        meta_path = model_path / "metadata.json"
        if meta_path.exists():
            with open(meta_path) as f:
                meta = json.load(f)
            return meta.get("class_names") or meta.get("classes")
        return None

    try:
        with zipfile.ZipFile(model_path, "r") as zf:
            if "metadata.json" in zf.namelist():
                with zf.open("metadata.json") as f:
                    meta = json.load(f)
                return meta.get("class_names") or meta.get("classes")
    except Exception:
        pass
    return None


def load_model(name: str):
    try:
        import keras
        return keras.models.load_model
    except ImportError:
        import tensorflow as tf
        return tf.keras.models.load_model


def diagnose():
    import os
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.development")
    os.environ["TF_CPP_MIN_LOG_LEVEL"] = "3"

    try:
        import keras
        load_fn = keras.models.load_model
    except ImportError:
        import tensorflow as tf
        load_fn = tf.keras.models.load_model

    try:
        from tensorflow.keras.applications.mobilenet_v2 import preprocess_input
    except ImportError:
        def preprocess_input(x): return (x / 127.5) - 1.0

    # Uniform grey image — no leaf features, shows raw bias
    grey_img = np.full((1, 224, 224, 3), 128.0, dtype=np.float32)
    grey_pp  = preprocess_input(grey_img.copy())

    # Green-ish synthetic leaf
    green_img = np.zeros((1, 224, 224, 3), dtype=np.float32)
    green_img[:, :, :, 1] = 150  # green channel
    green_img[:, :, :, 0] = 70
    green_img[:, :, :, 2] = 55
    green_pp = preprocess_input(green_img.copy())

    all_ok = True

    for model_key, expected_classes in ENGINE_CLASSES.items():
        model_path = ML_DIR / f"{model_key}.keras"
        print(f"\n{'='*70}")
        print(f"  Model: {model_key}")
        print(f"  Path:  {model_path}")

        if not model_path.exists():
            print("  [SKIP] model file not found")
            continue

        # Check embedded class order
        embedded = get_model_class_order(model_path)
        if embedded:
            print(f"\n  Embedded class order: {embedded}")
            if embedded != expected_classes:
                print("  *** MISMATCH with engine.py! ***")
                print(f"  engine.py expects: {expected_classes}")
                all_ok = False
            else:
                print("  [OK] matches engine.py")
        else:
            print("  (No embedded class_names in metadata — relying on engine.py order)")

        try:
            model = load_fn(str(model_path))
            n_out = model.output_shape[-1]
            print(f"\n  Output neurons: {n_out}  |  engine.py classes: {len(expected_classes)}")
            if n_out != len(expected_classes):
                print(f"  *** OUTPUT COUNT MISMATCH: model={n_out}, engine={len(expected_classes)} ***")
                all_ok = False
            else:
                print("  [OK] neuron count matches")

            # Run inference
            preds_grey  = model.predict(grey_pp,  verbose=0)[0]
            preds_green = model.predict(green_pp, verbose=0)[0]

            print("\n  Scores on GREY image (no leaf features):")
            for i, (cls, sc) in enumerate(zip(expected_classes, preds_grey)):
                marker = " <-- TOP" if i == int(np.argmax(preds_grey)) else ""
                print(f"    [{i}] {cls:<45} {sc*100:6.2f}%{marker}")

            print("\n  Scores on GREEN image (generic leaf colour):")
            for i, (cls, sc) in enumerate(zip(expected_classes, preds_green)):
                marker = " <-- TOP" if i == int(np.argmax(preds_green)) else ""
                print(f"    [{i}] {cls:<45} {sc*100:6.2f}%{marker}")

        except Exception as exc:
            print(f"  [ERROR] Could not load/run model: {exc}")
            all_ok = False

    print(f"\n{'='*70}")
    if all_ok:
        print("  ✅ All models match engine.py class order — class mismatch is NOT the issue.")
        print("     The healthy-as-disease problem is likely a model generalisation issue.")
        print("     Consider raising DISEASE_CONF_THRESHOLD or adding image augmentation.")
    else:
        print("  ❌ MISMATCH(ES) found — engine.py class order does not match trained model!")
        print("     Fix the DISEASE_CLASSES dict in engine.py to match the actual training order.")
    print()


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
    diagnose()
