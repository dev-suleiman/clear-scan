"""
Export the freshly-trained real-pairs enhancement autoencoder to .h5 and
.tflite. Only touches enhancement_autoencoder* files — never touches
quality_classifier*.
"""
import os

import numpy as np
import tensorflow as tf

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAVED_DIR = os.path.join(BASE, "models", "saved")
TFLITE_DIR = os.path.join(BASE, "models", "tflite")
KERAS_PATH = os.path.join(SAVED_DIR, "enhancement_autoencoder.keras")
H5_PATH = os.path.join(SAVED_DIR, "enhancement_autoencoder.h5")
TFLITE_PATH = os.path.join(TFLITE_DIR, "enhancement_autoencoder.tflite")

os.makedirs(TFLITE_DIR, exist_ok=True)


def combined_loss(y_true, y_pred):
    ssim = 1.0 - tf.reduce_mean(tf.image.ssim(y_true, y_pred, max_val=1.0))
    mse = tf.reduce_mean(tf.square(y_true - y_pred))
    return 0.5 * mse + 0.5 * ssim


def psnr_metric(y_true, y_pred):
    return tf.reduce_mean(tf.image.psnr(y_true, y_pred, max_val=1.0))


def ssim_metric(y_true, y_pred):
    return tf.reduce_mean(tf.image.ssim(y_true, y_pred, max_val=1.0))


def main():
    print("Loading:", KERAS_PATH)
    model = tf.keras.models.load_model(
        KERAS_PATH,
        custom_objects={
            "combined_loss": combined_loss,
            "psnr_metric": psnr_metric,
            "ssim_metric": ssim_metric,
        },
        compile=False,
    )
    model.save(H5_PATH)
    print("Saved h5:", H5_PATH, os.path.getsize(H5_PATH) / 1e6, "MB")

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    with open(TFLITE_PATH, "wb") as f:
        f.write(tflite_model)
    size_mb = os.path.getsize(TFLITE_PATH) / 1e6
    print("Saved tflite:", TFLITE_PATH, size_mb, "MB")
    if not (5 <= size_mb <= 25):
        print(f"WARNING: tflite size {size_mb:.1f}MB outside expected 5-25MB range")

    # verify h5 loads cleanly
    _ = tf.keras.models.load_model(
        H5_PATH,
        custom_objects={
            "combined_loss": combined_loss,
            "psnr_metric": psnr_metric,
            "ssim_metric": ssim_metric,
        },
        compile=False,
    )
    print("h5 reload check: OK")

    # test inference on tflite
    interpreter = tf.lite.Interpreter(model_path=TFLITE_PATH)
    interpreter.allocate_tensors()
    inp = interpreter.get_input_details()[0]
    out = interpreter.get_output_details()[0]
    x = np.random.rand(1, 512, 512, 1).astype(np.float32)
    interpreter.set_tensor(inp["index"], x)
    interpreter.invoke()
    y = interpreter.get_tensor(out["index"])
    print("tflite test inference output shape:", y.shape)
    assert y.shape[1:3] == (512, 512), f"unexpected output shape {y.shape}"
    print("tflite inference check: OK")


if __name__ == "__main__":
    main()
