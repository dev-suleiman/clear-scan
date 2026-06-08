# ClearScan Models — Documentation

## Overview (Plain Language)

ClearScan helps hospital radiology departments automatically check the quality of chest X-ray images before they are reviewed by a doctor. Poor-quality images — blurry, too dark, too noisy — waste a radiologist's time and can lead to missed diagnoses. ClearScan solves this in two steps:

1. **Triage:** An AI model looks at each incoming X-ray and immediately labels it *Good*, *Fair*, or *Poor*.
2. **Rescue:** If an image is rated Fair or Poor, a second AI model attempts to enhance it — reducing noise, improving contrast, and sharpening detail — so it becomes readable before it reaches the radiologist.

Both models are small enough to run on a mobile device or tablet at the point of care, with no internet connection required.

---

## Overview (Technical)

The pipeline consists of two neural networks:

- **Quality Classifier** — MobileNetV2 (ImageNet-pretrained) backbone with a custom classification head (GlobalAveragePooling2D → Dense 128 → Dropout 0.3 → Softmax 3-class). Input: 224 × 224 × 3 RGB. Output: probability vector over `[Good, Fair, Poor]`.
- **Enhancement Autoencoder** — U-Net with four encoder/decoder levels (filter progression: 32 → 64 → 128 → 256 → 512 bottleneck), skip connections, and a combined MSE + (1 − SSIM) loss. Input/output: 512 × 512 × 1 grayscale.

Both models are exported to **TFLite** with `DEFAULT` post-training quantisation for mobile deployment. The classifier is the gatekeeper; the autoencoder is invoked only when the classifier returns Fair or Poor.

---

## Environment Setup

### Local Setup

```bash
# 1. Clone the repo
git clone <repo-url>
cd clear-scan

# 2. Create and activate a virtual environment
python -m venv .venv

# Windows
.venv\Scripts\activate

# Linux / macOS
source .venv/bin/activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Verify
python -c "import tensorflow, cv2, skimage, sklearn; print('All imports OK')"
```

### Digital Ocean GPU Droplet Setup

```bash
# SSH into your droplet
ssh root@<your-droplet-ip>

# Verify CUDA is available
nvidia-smi

# If CUDA 12.x is missing, install it (Ubuntu 22.04 example)
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt update
sudo apt install -y cuda-toolkit-12-3

# Clone and set up the project
git clone <repo-url>
cd clear-scan
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

---

## Data Preparation

### Dataset Sources

| Dataset | URL | Notes |
|---------|-----|-------|
| NIH ChestX-ray14 | https://nihcc.app.box.com/v/ChestXray-NIHCC | 112,120 frontal-view X-rays, 14 disease labels |
| JSRT | http://db.jsrt.or.jp/eng.php | 247 chest X-rays (nodule / non-nodule) |
| Montgomery County | https://openi.nlm.nih.gov/ | 138 X-rays, TB screening |

After downloading, place all images into `data/raw/`:

```
data/raw/
  00000001_000.png
  00000002_000.png
  ...
```

### `data/labelled/labels.csv` Format

The classifier training script reads this CSV. Required columns:

| Column | Description |
|--------|-------------|
| `filename` | Image filename (basename only), e.g. `00000001_000.png` |
| `quality_label` | One of: `Good`, `Fair`, `Poor` |
| `defects` | Comma-separated defect tags, or empty string |

**Example rows:**

```csv
filename,quality_label,defects
00000001_000.png,Good,
00000045_003.png,Poor,"motion_blur,underexposure"
```

---

## Training Guide

Run scripts in order from the project root with the virtual environment active.

### Step 1 — Generate Synthetic Degraded Pairs (~5 min for 500 images)

```bash
python -m scripts.01_synthetic_degradation \
    --input_dir data/raw/ \
    --output_dir data/synthetic_pairs/ \
    --samples_per_image 3
```

Expected output:
```
Processing images: 100%|████████████| 500/500 [04:52<00:00]
Generated 1500 pairs from 500 source images.
Manifest saved to data/synthetic_pairs/pairs_manifest.csv
```

### Step 2 — Train Quality Classifier (~2 hrs on GPU)

```bash
python -m scripts.02_train_quality_classifier \
    --epochs 50 \
    --data_dir data/labelled/ \
    --model_dir models/saved/
```

Expected output (excerpt):
```
Train: 2100, Val: 450, Test: 450
Epoch 1/50 — loss: 1.0823 — accuracy: 0.3412 — val_loss: 0.9714 — val_accuracy: 0.4200
...
=== CNN Classification Report ===
              precision    recall  f1-score   support
        Good       0.88      0.91      0.89       ...
```

### Step 3 — Train Enhancement Autoencoder (~6 hrs on GPU)

```bash
python -m scripts.03_train_enhancement_autoencoder \
    --epochs 100 \
    --data_dir data/synthetic_pairs/ \
    --model_dir models/saved/
```

Expected output (excerpt):
```
Train: 1200, Val: 150, Test: 150
Epoch 1/100 — loss: 0.2341 — val_loss: 0.2198
...
Final val PSNR: 28.45 dB, SSIM: 0.8712
```

### Step 4 — Evaluate Both Models

```bash
python -m scripts.04_evaluate_models
```

### Step 5 — Export to TFLite

```bash
python -m scripts.05_export_tflite
```

---

## Output Files Table

| File | Location | Used By |
|------|----------|---------|
| `pairs_manifest.csv` | `data/synthetic_pairs/` | Scripts 03, 04 |
| `quality_classifier.keras` | `models/saved/` | Scripts 04, 05 |
| `enhancement_autoencoder.keras` | `models/saved/` | Scripts 04, 05 |
| `confusion_matrix.png` | `models/saved/classifier_eval/` | Reporting |
| `roc_curves.png` | `models/saved/classifier_eval/` | Reporting |
| `autoencoder_training_curves.png` | `models/saved/` | Reporting |
| `confusion_matrix_final.png` | `models/saved/eval_figures/` | Reporting |
| `roc_curves_final.png` | `models/saved/eval_figures/` | Reporting |
| `evaluation_results.csv` | `models/saved/` | Reporting |
| `quality_classifier.tflite` | `models/tflite/` | Mobile app |
| `enhancement_autoencoder.tflite` | `models/tflite/` | Mobile app |

---

## Evaluation Targets

After running script 04, the terminal prints a summary table. Here is how to interpret each target:

| Metric | Target | How to Read |
|--------|--------|-------------|
| Classifier macro F1 | ≥ 0.85 | Row "Classifier macro F1" in summary table |
| Classifier ROC-AUC | ≥ 0.85 | Row "Classifier ROC-AUC" in summary table |
| Mean SSIM Improvement | ≥ 0.10 | Row "Mean SSIM Improvement" — CNN output vs. degraded input |
| Mean PSNR Improvement | ≥ 2 dB | Row "Mean PSNR Improvement (dB)" |
| CNN Win Rate | ≥ 50% | Row "CNN Win Rate" — % of images where CNN outscored CLAHE |

If any target is missed, check `models/saved/evaluation_results.csv` for per-image breakdowns.

---

## Troubleshooting

### 1. `ResourceExhaustedError` (GPU out of memory)

The batch size is too large for your GPU VRAM.

**Fix:** Reduce `batch_size` in the training scripts. Start at 4 for the autoencoder and 8 for the classifier. For the autoencoder on a 16 GB GPU, batch size 8 at 512 × 512 is the practical ceiling.

### 2. `brisque` install failure on some Linux distros

`brisque` depends on `libsvm` which may fail to compile without system libraries.

**Fix:**
```bash
sudo apt install -y libsvm-dev
pip install libsvm
pip install brisque
```

### 3. F1 collapses below 0.5 with a small dataset

Class imbalance or insufficient data causes the model to predict only the majority class.

**Fix:** (a) Increase augmentation intensity in `build_model()` — raise `RandomRotation` to 0.15 and `RandomZoom` to 0.2; (b) use `class_weight` in `model.fit()` computed via `sklearn.utils.class_weight.compute_class_weight`; (c) ensure at least 200 labelled samples per class.

### 4. TFLite conversion fails with custom loss

The TFLite converter cannot serialise some custom Keras loss objects.

**Fix:** Convert from a SavedModel instead:
```python
model.export("tmp_saved_model")
converter = tf.lite.TFLiteConverter.from_saved_model("tmp_saved_model")
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_model = converter.convert()
```

### 5. SSIM loss returns NaN during autoencoder training

Images are not normalised to `[0, 1]` or contain all-zero patches.

**Fix:** Add `assert y_true.max() <= 1.0 and y_pred.max() <= 1.0` before the loss call. Also add `epsilon = 1e-8` to the SSIM call: `tf.image.ssim(y_true + epsilon, y_pred + epsilon, max_val=1.0)`.
