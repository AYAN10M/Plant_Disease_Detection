# 🌿 Plant Disease Detector — `mobile_efficient_deployment`

A complete **MobileNetV2 + Grad-CAM** plant disease detection pipeline with a dedicated trained leaf detector.

---

## 📁 Folder Structure

```
mobile_efficient_deployment/
├── predict.py              # Main inference script (single image)
├── batch_predict.py        # Batch inference over a folder of images
├── train_leaf_detector.py  # Train the leaf / not-leaf binary classifier ← do this first
├── gradcam_utils.py        # Reusable Grad-CAM utilities
├── leaf_detector.py        # Standalone leaf detection module (heuristic + multi-strategy)
├── leaf_detector.keras     # (created after running train_leaf_detector.py)
└── README.md
```

---

## 🔄 Pipeline Overview

```
Input Image
    │
    ▼
┌─────────────────────────────┐
│  Step 1 – Leaf Check        │  ← trained MobileNetV2 binary classifier
│  (leaf_detector.keras)      │    OR green-channel heuristic (fallback)
└──────────┬──────────────────┘
           │ Not a leaf → ❌ STOP, report "Not a leaf"
           │ Is a leaf  ↓
┌─────────────────────────────┐
│  Step 2 – Disease Classify  │  ← plant_disease_mobilenet.h5  (38 classes)
│  (MobileNetV2, 38 classes)  │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│  Step 3 – Grad-CAM          │  ← heatmap of the affected region
│  overlay on original image  │
└──────────┬──────────────────┘
           │
           ▼
  Result figure (3-panel)
  • Original  •  Heatmap  •  Confidence card
```

---

## 🚀 Quick Start

### Step 1 — Train the leaf detector *(one-time)*

```bash
cd mobile_efficient_deployment

# Uses the leaf images already in dataset/leaf_or_not/train/
# Synthetic negatives are auto-generated if you have no non-leaf folder.
python train_leaf_detector.py

# Or supply your own non-leaf folder:
python train_leaf_detector.py --non-leaf path/to/non_leaf_images/
```

This saves `leaf_detector.keras` inside the folder.

---

### Step 2 — Run inference on a single image

```bash
python predict.py --image path/to/your_leaf.jpg
# Output figure is saved as:  your_leaf_gradcam_result.jpg

# Custom output path:
python predict.py --image path/to/leaf.jpg --output results/my_result.jpg
```

---

### Step 3 — Batch inference (whole folder)

```bash
python batch_predict.py \
    --input  path/to/images/ \
    --output path/to/results/
# Saves Grad-CAM figures + results.csv summary
```

---

## 📊 Output Figure (3 panels)

| Panel | Contents |
|---|---|
| **Original Image** | Input as-is |
| **Grad-CAM Heatmap** | JET colormap overlay — red = highest activation |
| **Results Card** | Status (healthy / diseased), plant name, condition, confidence %, Top-3 |

---

## 🌱 Leaf Detection: Why Use a Trained Model?

| Method | Pros | Cons |
|---|---|---|
| Green-channel heuristic | Zero setup, instant | Fails on brown/yellow/diseased leaves; false positives from green backgrounds |
| **Trained binary model** ✅ | Robust to colour, lighting, and backgrounds | Requires one training run (~10 min) |

The trained model (`leaf_detector.keras`) is automatically used if present.  
If missing, the system **gracefully falls back** to the heuristic so inference always works.

---

## 🎯 Disease Classes (38)

| Plant | Diseases |
|---|---|
| Apple | Apple Scab, Black Rot, Cedar Apple Rust, Healthy |
| Cherry | Healthy, Mildew |
| Corn | Blight, Cercospora Gray Leaf Spot, Common Rust, Healthy |
| Grape | Black Rot, Esca (Black Measles), Leaf Blight, Healthy |
| Peach | Bacterial Spot, Healthy |
| Pepper Bell | Bacterial Spot, Healthy |
| Potato | Early Blight, Late Blight, Healthy |
| Rice | Bacterial Blight, Blast, Brown Spot, Healthy, Tungro |
| Strawberry | Leaf Scorch, Healthy |
| Tomato | Bacterial Spot, Early Blight, Late Blight, Leaf Mold, Septoria Leaf Spot, Spider Mites, Target Spot, Yellow Leaf Curl Virus, Mosaic Virus, Healthy |

---

## ⚙️ CLI Reference

### `predict.py`
```
--image / -i   Path to input image (required)
--model / -m   Path to disease model .h5 (default: ../plant_disease_mobilenet.h5)
--output / -o  Path to save result figure (default: <image>_gradcam_result.jpg)
--leaf-threshold  Green-pixel ratio threshold for heuristic fallback (default: 0.08)
```

### `train_leaf_detector.py`
```
--leaf / -l     Folder of leaf images    (default: ../dataset/leaf_or_not/train/)
--non-leaf / -n Folder of non-leaf images (default: auto-generate synthetic)
--output / -o   Output model path         (default: leaf_detector.keras)
--epochs / -e   Training epochs phase 1   (default: 10)
```

### `batch_predict.py`
```
--input / -i   Input folder containing images (required)
--output / -o  Output folder for figures & CSV (required)
--model / -m   Disease model path (default: ../plant_disease_mobilenet.h5)
--leaf-threshold  Same as predict.py (default: 0.08)
```

---

## 📦 Dependencies

```
tensorflow >= 2.12
opencv-python
numpy
matplotlib
```

Install with:
```bash
pip install tensorflow opencv-python numpy matplotlib
```
