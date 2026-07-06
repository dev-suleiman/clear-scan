# ClearScan — Project Handoff

ClearScan is a chest X-ray quality assessment and enhancement system. It classifies images as Good/Fair/Poor and enhances poor-quality images using either a classical CLAHE pipeline or a trained CNN (U-Net autoencoder). It ships as a FastAPI REST backend and an ML training pipeline, with TFLite export for mobile deployment.

---

## Project Structure

```
clear-scan/
├── CLAUDE.md                          ← this file
├── .gitignore
├── clearscan-backend/                 ← FastAPI REST server
│   ├── app/
│   │   ├── main.py                    ← FastAPI app entry point
│   │   ├── config.py                  ← Settings loaded from .env
│   │   ├── models/
│   │   │   ├── classifier.py          ← Quality classifier wrapper (Keras → TF)
│   │   │   └── enhancer.py            ← U-Net autoencoder wrapper
│   │   ├── processing/
│   │   │   ├── metrics.py             ← IQA: Laplacian variance, contrast, entropy, noise
│   │   │   ├── clahe.py               ← Classical: CLAHE + NLM denoising + unsharp mask
│   │   │   └── comparison.py          ← CLAHE vs CNN scoring (SSIM/PSNR/BRISQUE)
│   │   ├── routers/
│   │   │   ├── health.py              ← GET /api/v1/health
│   │   │   ├── assess.py              ← POST /api/v1/assess
│   │   │   ├── enhance.py             ← POST /api/v1/enhance/clahe and /cnn
│   │   │   └── compare.py             ← POST /api/v1/compare
│   │   └── schemas/
│   │       └── responses.py           ← Pydantic response models
│   ├── tests/
│   │   ├── conftest.py
│   │   ├── test_health.py
│   │   ├── test_assess.py
│   │   ├── test_enhance.py
│   │   └── test_compare.py
│   ├── requirements.txt
│   ├── Dockerfile                     ← Python 3.10-slim, single uvicorn worker
│   ├── render.yaml                    ← Render.com deployment (1 GB persistent disk)
│   ├── railway.toml                   ← Railway.app deployment
│   ├── .env.example                   ← Template for environment variables
│   └── README_backend.md              ← API docs and deployment guide
│
├── clearscan-models/                  ← ML training pipeline
│   ├── scripts/
│   │   ├── 01_synthetic_degradation.py
│   │   ├── 02_train_quality_classifier.py
│   │   ├── 03_train_enhancement_autoencoder.py
│   │   ├── 04_evaluate_models.py
│   │   ├── 05_export_tflite.py
│   │   └── quality_metrics.py         ← Shared metric utilities
│   ├── requirements.txt
│   └── README_models.md               ← Training guide and troubleshooting
│
└── design-reference/                  ← UI mockups / design assets
```

---

## Architecture

### Backend (FastAPI)

- **Framework:** FastAPI 0.110 + Uvicorn ASGI
- **Models:** Two Keras models loaded at startup from `MODEL_DIR`
  - `quality_classifier.keras` — MobileNetV2 backbone, 224×224 RGB input, 3-class softmax (Good/Fair/Poor)
  - `enhancement_autoencoder.keras` — U-Net, 512×512 grayscale input/output
- **Graceful degradation:** If models aren't present at startup, all endpoints fall back to the classical CLAHE pipeline automatically. No crashes.

**API Endpoints**

| Endpoint | Method | Description |
|---|---|---|
| `/api/v1/health` | GET | Status, model-loaded flags, timestamp |
| `/api/v1/assess` | POST | Quality triage → class, confidence, defect labels |
| `/api/v1/enhance/clahe` | POST | Classical enhancement, returns base64 image + metrics |
| `/api/v1/enhance/cnn` | POST | CNN enhancement (falls back to CLAHE if model missing) |
| `/api/v1/compare` | POST | Runs both, picks winner by composite score |

**Image Quality Metrics** (computed on every image)
- Laplacian variance — sharpness / blur detection
- RMS contrast — underexposure detection
- Shannon entropy — information content
- Histogram spread — dynamic range
- Noise variance — denoising quality

**Winner Selection Weights** (`/compare` endpoint)
- SSIM: 40%
- PSNR (normalized to 50 dB max): 40%
- BRISQUE (inverted — lower is better): 20%

**Classical pipeline order:**
Input (grayscale) → CLAHE → NLM Denoising → Unsharp Mask → Output

### ML Training Pipeline (clearscan-models/scripts)

Run scripts in numbered order:

1. **`01_synthetic_degradation.py`** — Generates paired clean/degraded images from `data/raw/`. Degradations: Gaussian blur, Gaussian/Poisson noise, underexposure, contrast compression, combinations. Outputs to `data/synthetic_pairs/` + manifest CSV.

2. **`02_train_quality_classifier.py`** — Reads `data/labelled/labels.csv` (columns: `filename`, `quality_label`, `defects`). Architecture: MobileNetV2 → GlobalAveragePooling2D → Dense(128) → Dropout(0.3) → Softmax(3). Augmentation: RandomFlip, RandomRotation, RandomBrightness, RandomZoom. Loss: categorical crossentropy. Early stopping (patience 10). Output: `quality_classifier.keras`.

3. **`03_train_enhancement_autoencoder.py`** — Reads synthetic pairs from manifest CSV. U-Net with 4 encoder levels (32→64→128→256), bottleneck 512, symmetric decoder with skip connections. Loss: `0.5 * MSE + 0.5 * (1 - SSIM)`, batch size 8. Output: `enhancement_autoencoder.keras`.

4. **`04_evaluate_models.py`** — Evaluates both models. Targets: classifier F1 ≥ 0.85 and AUC ≥ 0.85; enhancer PSNR improvement ≥ 2 dB, SSIM improvement ≥ 10%, CNN win rate ≥ 50%.

5. **`05_export_tflite.py`** — Converts both `.keras` models to TFLite with `DEFAULT` quantization. Hard limit: 25 MB per file (soft limit 15 MB). Outputs: `quality_classifier.tflite` and `enhancement_autoencoder.tflite`.

---

## Environment Setup

### Backend

```bash
cd clearscan-backend
python -m venv .venv
.venv\Scripts\activate          # Windows
pip install -r requirements.txt

# Copy and fill in .env
cp .env.example .env
```

`.env` variables:
```
MODEL_DIR=model_files           # Directory containing .keras files
MAX_IMAGE_SIZE_MB=10
CORS_ORIGINS=*
LOG_LEVEL=INFO
```

Place trained model files in `clearscan-backend/model_files/`:
- `quality_classifier.keras`
- `enhancement_autoencoder.keras`

Run locally:
```bash
uvicorn app.main:app --reload --port 8000
```

### ML Training

```bash
cd clearscan-models
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

Data layout expected before training:
```
clearscan-models/
└── data/
    ├── raw/                    # Source clean X-ray images (NIH ChestX-ray14, JSRT, Montgomery)
    └── labelled/
        └── labels.csv          # filename, quality_label, defects columns
```

---

## Testing

```bash
cd clearscan-backend
pytest tests/ -v
```

Tests cover: health endpoint (200 + timestamp), assess endpoint (valid PNG/JPG accepted, invalid extensions and oversized files rejected), CLAHE enhancement (returns base64), compare endpoint (winner is "clahe" or "cnn").

---

## Deployment

### Render.com (primary)
- Configured in `render.yaml`
- Docker runtime (Python 3.10-slim)
- 1 GB persistent disk mounted at `/model_files` — place `.keras` files here manually after first deploy
- Health check: `GET /api/v1/health`
- Free tier hibernates after 15 min of inactivity

### Railway.app (alternative)
- Configured in `railway.toml`
- Volume mount at `/model_files`
- Health check + auto-restart on failure

### What is NOT in the repo (gitignored)
- `.venv/` directories
- `*.keras` and `*.h5` model files (stored on deployment disk or external storage)
- `*.tflite` files
- `data/raw/` images (source data from NIH/JSRT/Montgomery — download separately)
- `.env` files (use `.env.example` as template)

---

## Current Status (as of June 2026)

- ML training pipeline: complete (scripts 01–05 implemented and tested)
- FastAPI backend: complete with CLAHE fallback, IQA metrics, comparison scoring, full test suite
- Deployment configs: Render and Railway both configured
- TFLite export pipeline: implemented, supports mobile deployment
- **What remains:** Actual model training requires real/synthetic data and a GPU environment. The `.keras` model files do not exist yet in the repo — the backend runs in CLAHE-only fallback mode until they are trained and placed in `MODEL_DIR`.

---

## Data Sources for Training

Recommended public datasets (download separately):
- **NIH ChestX-ray14** — chest X-rays with disease labels, useful for quality diversity
- **JSRT** — Japanese Society of Radiological Technology dataset
- **Montgomery County** — TB screening dataset

---

## Key Decisions

- **MobileNetV2 for classifier** — lightweight enough for TFLite export while achieving target accuracy on 3-class quality problem
- **U-Net for enhancement** — skip connections preserve anatomical detail that gets lost in plain autoencoders
- **CLAHE fallback** — backend is fully functional without ML models, making deployment and testing independent of training completion
- **Composite scoring for compare** — SSIM + PSNR weighted equally (80%) with BRISQUE as tiebreaker (20%) because BRISQUE alone is unreliable on X-rays
- **Separate venvs per subproject** — backend and models have different TF/CV dependency trees; keeping them separate avoids conflicts
