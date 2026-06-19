# Model Files

Place the following TFLite model files here:

- `quality_classifier.tflite`
- `enhancement_autoencoder.tflite`

Copy these from `clearscan-models/models/tflite/` after running the training pipeline (`05_export_tflite.py`).

Without these files the app falls back to online API mode. The TFLite offline path will activate automatically once the files are present.
