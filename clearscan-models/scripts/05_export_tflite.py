from pathlib import Path

import numpy as np
import tensorflow as tf
from tabulate import tabulate


def export_tflite(keras_path: str, tflite_path: str, input_shape: tuple) -> dict:
    print(f"\nExporting {keras_path} -> {tflite_path}")
    model = tf.keras.models.load_model(keras_path, compile=False)
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    Path(tflite_path).parent.mkdir(parents=True, exist_ok=True)
    with open(tflite_path, "wb") as f:
        f.write(tflite_model)

    size_mb = Path(tflite_path).stat().st_size / (1024 * 1024)
    print(f"  File size: {size_mb:.2f} MB")
    if size_mb > 15:
        print(f"  WARNING: Model is {size_mb:.2f} MB (above 15 MB soft limit)")
    assert size_mb < 25, f"Model {tflite_path} exceeds 25 MB hard limit ({size_mb:.2f} MB)"

    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    dummy = np.random.rand(1, *input_shape).astype(np.float32)
    interpreter.set_tensor(input_details[0]["index"], dummy)
    interpreter.invoke()
    output = interpreter.get_tensor(output_details[0]["index"])
    output_shape = tuple(output.shape)
    sample_val = float(output.flat[0])

    print(f"  Input shape:  {input_details[0]['shape']}")
    print(f"  Output shape: {output_shape}")
    print(f"  Sample output value: {sample_val:.6f}")

    return {
        "name": Path(keras_path).stem,
        "tflite_path": tflite_path,
        "size_mb": round(size_mb, 2),
        "input_shape": str(input_details[0]["shape"].tolist()),
        "output_shape": str(list(output_shape)),
        "quantisation": "DEFAULT",
    }


def create_synthetic_model(path: str, input_shape: tuple, output_units: int):
    """Create a tiny Keras model for dry-run testing if real models are absent."""
    inputs = tf.keras.Input(shape=input_shape)
    x = tf.keras.layers.Flatten()(inputs)
    x = tf.keras.layers.Dense(16, activation="relu")(x)
    outputs = tf.keras.layers.Dense(output_units, activation="softmax")(x)
    model = tf.keras.Model(inputs, outputs)
    model.save(path)
    print(f"  Synthetic model created at {path}")


def main():
    model_dir = Path("models/saved")
    tflite_dir = Path("models/tflite")
    tflite_dir.mkdir(parents=True, exist_ok=True)

    classifier_keras = str(model_dir / "quality_classifier.keras")
    autoencoder_keras = str(model_dir / "enhancement_autoencoder.keras")

    if not Path(classifier_keras).exists():
        print("quality_classifier.keras not found; creating synthetic model for dry-run.")
        create_synthetic_model(classifier_keras, (224, 224, 3), 3)

    if not Path(autoencoder_keras).exists():
        print("enhancement_autoencoder.keras not found; creating synthetic model for dry-run.")
        create_synthetic_model(autoencoder_keras, (512, 512, 1), 1)

    results = []
    results.append(export_tflite(
        classifier_keras,
        str(tflite_dir / "quality_classifier.tflite"),
        (224, 224, 3),
    ))
    results.append(export_tflite(
        autoencoder_keras,
        str(tflite_dir / "enhancement_autoencoder.tflite"),
        (512, 512, 1),
    ))

    print("\n=== TFLite Export Summary ===")
    table_rows = [
        [r["name"], r["size_mb"], r["input_shape"], r["output_shape"], r["quantisation"]]
        for r in results
    ]
    print(tabulate(
        table_rows,
        headers=["Model", "Size (MB)", "Input Shape", "Output Shape", "Quantisation"],
        tablefmt="github",
    ))


if __name__ == "__main__":
    main()
