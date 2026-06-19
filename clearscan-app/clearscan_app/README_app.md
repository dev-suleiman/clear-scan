# ClearScan Mobile App

## What is ClearScan?

A radiographer's morning workflow, reimagined. You arrive at the ward, clip a chest X-ray to the lightbox, open ClearScan on your phone, and take a photo. Within seconds the app tells you whether the image is **Good**, **Fair**, or **Poor** quality — with objective scores for sharpness, contrast, noise, and exposure. If the film is poor, tap **Enhance Image** and the app applies a hybrid CLAHE-CNN pipeline to sharpen and denoise it. When you're done, export a professional PDF report directly to the referring clinician's inbox, or save the enhanced image to your gallery.

No login. No cloud dependency when you need it most. Even in a low-connectivity rural clinic, ClearScan's on-device pipeline keeps working.

---

## Technical Architecture

### Feature-Based Folder Structure

```
lib/
├── app.dart                      ← GoRouter + MaterialApp.router
├── main.dart                     ← Entry point, orientation lock
├── core/
│   ├── constants/                ← AppColors, AppTextStyles, ApiEndpoints
│   └── services/                 ← ConnectivityService, TFLiteService,
│                                    ClaheService, ApiService, DatabaseService
├── models/                       ← AssessmentResult, EnhancementResult
├── providers/                    ← AssessmentNotifier, EnhancementNotifier
└── features/
    ├── onboarding/               ← 3-slide PageView onboarding
    ├── home/                     ← Home screen, source sheet, session tiles
    ├── assessment/               ← QualityBadge, MetricsCard, DefectChips
    ├── enhancement/              ← ImageComparisonSlider, EnhancementScreen
    ├── results/                  ← ResultsScreen, ExportSheet, PDF generation
    ├── history/                  ← HistoryScreen with filter chips
    └── settings/                 ← SettingsScreen, URL editor, cache clearing
```

### State Management (Riverpod)

- `connectivityProvider` — `AsyncNotifier<bool>`: pings the API health endpoint every time connectivity changes
- `assessmentProvider` — `StateNotifier<AsyncValue<AssessmentResult?>>`: runs online (API) or offline (TFLite) based on connectivity
- `enhancementProvider` — `StateNotifier<AsyncValue<EnhancementResult?>>`: runs `compare` (API), `enhanceClahe` (API), or local CLAHE

### Online / Offline Decision Tree

```
App starts
  └─ connectivityProvider checks:
       1. connectivity_plus (any non-none result?)
       2. HTTP GET /api/v1/health → status == "online"?
       
  ┌─ Online ──────────────────────────────────────────────┐
  │  assess()     → POST /api/v1/assess                   │
  │  enhance()    → POST /api/v1/compare or /clahe        │
  └───────────────────────────────────────────────────────┘
  
  ┌─ Offline ─────────────────────────────────────────────┐
  │  assess()     → TFLite quality_classifier.tflite      │
  │  enhance()    → ClaheService (image package pipeline) │
  └───────────────────────────────────────────────────────┘
```

### TFLite On-Device Inference

1. `TFLiteService` loads `assets/models/quality_classifier.tflite` at startup
2. Input: 224×224 RGB float32 `[1, 224, 224, 3]`
3. Output: `[1, 3]` softmax probabilities → argmax → Good/Fair/Poor + confidence
4. If the model file is missing, `classifyImage()` returns `Unknown` and the UI falls back gracefully

---

## Prerequisites

| Tool | Minimum Version |
|------|----------------|
| Flutter SDK | ≥ 3.19.0 (tested on 3.44.2) |
| Dart SDK | ≥ 3.3.0 |
| Android Studio | Electric Eel+ (for Android builds) |
| Xcode | 15+ (for iOS builds, macOS only) |
| Android SDK | API 21+ |
| iOS | 12.0+ |

---

## Setup Guide

```bash
# 1. Clone the repo
git clone <repo-url>
cd clear-scan/clearscan-app/clearscan_app

# 2. Install dependencies
flutter pub get

# 3. Place TFLite models (optional — app works without them via API)
cp ../../clearscan-models/models/tflite/quality_classifier.tflite assets/models/
cp ../../clearscan-models/models/tflite/enhancement_autoencoder.tflite assets/models/

# 4. Update backend URL
# Edit lib/core/constants/api_endpoints.dart
# Change baseUrl to your Render/Railway deployment URL

# 5. Run on a connected device or emulator
flutter run
```

---

## Backend URL Configuration

**Option A — Code:** Edit `lib/core/constants/api_endpoints.dart`:
```dart
static const String baseUrl = 'https://your-actual-app.onrender.com';
```

**Option B — In-app:** Open the app → Settings → Backend Server → tap the edit icon → enter your URL → Save → Test Connection.

---

## Building for Production

### Android
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```
> For Play Store submission you must configure a signing key. See https://docs.flutter.dev/deployment/android

### iOS (macOS only)
```bash
flutter build ipa
# Requires Apple Developer account for device installation
```
> See https://docs.flutter.dev/deployment/ios

---

## Offline Mode

**Works without internet:**
- Quality classification via TFLite (once model files are placed in `assets/models/`)
- CLAHE image enhancement via the `image` package pipeline (grayscale → histogram equalisation → unsharp mask)
- All five IQA metric computations
- Full session history (SQLite)

**Requires internet:**
- CNN autoencoder enhancement (`/api/v1/enhance/cnn`)
- Comparison engine (`/api/v1/compare`)
- API-based quality assessment with defect labels

The connectivity dot in the home screen AppBar reflects the current mode:
- **Green pulsing** → CNN Mode (online)
- **Amber static** → CLAHE Mode (offline)

---

## Permissions

| Permission | Platform | Reason |
|-----------|----------|--------|
| CAMERA | Android + iOS | Capture X-rays directly from the device camera |
| READ_MEDIA_IMAGES | Android 13+ | Select images from gallery |
| READ_EXTERNAL_STORAGE | Android ≤ 12 | Select images from gallery |
| WRITE_EXTERNAL_STORAGE | Android ≤ 9 | Save enhanced images |
| INTERNET | Android | API communication |
| NSCameraUsageDescription | iOS | Camera access for capturing X-rays |
| NSPhotoLibraryUsageDescription | iOS | Selecting X-ray images from library |
| NSPhotoLibraryAddUsageDescription | iOS | Saving enhanced images to library |

---

## Troubleshooting

1. **TFLite model not found at runtime**
   - Ensure `quality_classifier.tflite` is in `assets/models/` and listed under `assets:` in `pubspec.yaml`
   - Run `flutter pub get` after adding model files

2. **Connectivity indicator always shows offline**
   - Verify `ApiEndpoints.baseUrl` is your actual deployment URL (not `your-app.onrender.com`)
   - Render free tier sleeps after 15 min of inactivity — the first request may take ~30 s to wake it
   - Check Settings → Test Connection for a specific error

3. **Image picker returns null on Android 13**
   - Ensure `READ_MEDIA_IMAGES` is declared in `AndroidManifest.xml` (already configured)
   - Grant the permission when the system dialog appears

4. **PDF export crashes**
   - Ensure the device has available storage in the temp directory
   - Check `pdf` package version matches pubspec (`^3.10.8`)

5. **Gradle build fails on first run**
   - Accept Android SDK licences: `flutter doctor --android-licenses`
   - Ensure Android SDK build-tools 34+ are installed via Android Studio SDK Manager

---

## Credits

**KNUST Department of Computer Science**  
Group 6 — Final Year Project 2025/26  
Supervisor: [Supervisor Name]  
Academic Year: 2025/26
