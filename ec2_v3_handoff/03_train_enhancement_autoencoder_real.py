"""
Train the ClearScan enhancement autoencoder from scratch on REAL
overexposed/clear image pairs (not synthetic degradation).

Data source: data/real_pairs/{overexposed,clear}/*.png +
             data/real_pairs/pairs_manifest.csv
             (columns: overexposed_file, clear_file, pair_type,
              patient, over_view, clear_view, confidence, source_folder)

This is a brand-new model trained independently of any previous
enhancement_autoencoder checkpoint. It does not read or write anything
under quality_classifier* — that model is untouched.
"""
import argparse
import csv
import os
import sys
import time

import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models, callbacks

IMG_SIZE = 512
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(BASE, "data", "real_pairs")
MANIFEST = os.path.join(DATA_DIR, "pairs_manifest.csv")
SAVED_DIR = os.path.join(BASE, "models", "saved")
CURVES_PNG = os.path.join(SAVED_DIR, "autoencoder_training_curves_v2.png")
BEST_MODEL_PATH = os.path.join(SAVED_DIR, "enhancement_autoencoder.keras")

os.makedirs(SAVED_DIR, exist_ok=True)


def load_manifest():
    rows = []
    with open(MANIFEST, newline="") as f:
        r = csv.DictReader(f)
        for row in r:
            rows.append(row)
    return rows


def split_rows(rows, seed=42, val_frac=0.1, test_frac=0.1):
    rng = np.random.default_rng(seed)
    idx = np.arange(len(rows))
    rng.shuffle(idx)
    n = len(rows)
    n_val = int(n * val_frac)
    n_test = int(n * test_frac)
    val_idx = idx[:n_val]
    test_idx = idx[n_val:n_val + n_test]
    train_idx = idx[n_val + n_test:]
    train = [rows[i] for i in train_idx]
    val = [rows[i] for i in val_idx]
    test = [rows[i] for i in test_idx]
    return train, val, test


def decode_png(path):
    data = tf.io.read_file(path)
    img = tf.io.decode_png(data, channels=1)
    img = tf.image.resize(img, [IMG_SIZE, IMG_SIZE], method="bilinear")
    img = tf.cast(img, tf.float32) / 255.0
    return img


def make_dataset(rows, batch_size, shuffle, augment):
    over_paths = [os.path.join(DATA_DIR, "overexposed", r["overexposed_file"]) for r in rows]
    clear_paths = [os.path.join(DATA_DIR, "clear", r["clear_file"]) for r in rows]

    ds = tf.data.Dataset.from_tensor_slices((over_paths, clear_paths))

    def _load(over_path, clear_path):
        x = decode_png(over_path)
        y = decode_png(clear_path)
        return x, y

    ds = ds.map(_load, num_parallel_calls=tf.data.AUTOTUNE)

    if augment:
        def _aug(x, y):
            if tf.random.uniform([]) > 0.5:
                x = tf.image.flip_left_right(x)
                y = tf.image.flip_left_right(y)
            return x, y
        ds = ds.map(_aug, num_parallel_calls=tf.data.AUTOTUNE)

    if shuffle:
        ds = ds.shuffle(buffer_size=min(len(rows), 2000), seed=42)

    ds = ds.batch(batch_size).prefetch(tf.data.AUTOTUNE)
    return ds


def conv_block(x, filters):
    x = layers.Conv2D(filters, 3, padding="same")(x)
    x = layers.BatchNormalization()(x)
    x = layers.Activation("relu")(x)
    x = layers.Conv2D(filters, 3, padding="same")(x)
    x = layers.BatchNormalization()(x)
    x = layers.Activation("relu")(x)
    return x


def build_unet(img_size=IMG_SIZE):
    inputs = layers.Input(shape=(img_size, img_size, 1))

    c1 = conv_block(inputs, 32)
    p1 = layers.MaxPooling2D()(c1)

    c2 = conv_block(p1, 64)
    p2 = layers.MaxPooling2D()(c2)

    c3 = conv_block(p2, 128)
    p3 = layers.MaxPooling2D()(c3)

    c4 = conv_block(p3, 256)
    p4 = layers.MaxPooling2D()(c4)

    b = conv_block(p4, 512)

    u4 = layers.Conv2DTranspose(256, 2, strides=2, padding="same")(b)
    u4 = layers.Concatenate()([u4, c4])
    d4 = conv_block(u4, 256)

    u3 = layers.Conv2DTranspose(128, 2, strides=2, padding="same")(d4)
    u3 = layers.Concatenate()([u3, c3])
    d3 = conv_block(u3, 128)

    u2 = layers.Conv2DTranspose(64, 2, strides=2, padding="same")(d3)
    u2 = layers.Concatenate()([u2, c2])
    d2 = conv_block(u2, 64)

    u1 = layers.Conv2DTranspose(32, 2, strides=2, padding="same")(d2)
    u1 = layers.Concatenate()([u1, c1])
    d1 = conv_block(u1, 32)

    outputs = layers.Conv2D(1, 1, activation="sigmoid")(d1)

    return models.Model(inputs, outputs, name="clearscan_enhancement_unet_v3")


def ssim_loss(y_true, y_pred):
    return 1.0 - tf.reduce_mean(tf.image.ssim(y_true, y_pred, max_val=1.0))


def combined_loss(y_true, y_pred):
    mse = tf.reduce_mean(tf.square(y_true - y_pred))
    return 0.5 * mse + 0.5 * ssim_loss(y_true, y_pred)


def psnr_metric(y_true, y_pred):
    return tf.reduce_mean(tf.image.psnr(y_true, y_pred, max_val=1.0))


def ssim_metric(y_true, y_pred):
    return tf.reduce_mean(tf.image.ssim(y_true, y_pred, max_val=1.0))


class EpochLogger(callbacks.Callback):
    """Print epoch/loss/val_loss/val_psnr/val_ssim every N epochs."""

    def __init__(self, every=5):
        super().__init__()
        self.every = every
        self.t0 = None

    def on_epoch_begin(self, epoch, logs=None):
        self.t0 = time.time()

    def on_epoch_end(self, epoch, logs=None):
        logs = logs or {}
        if (epoch + 1) % self.every == 0 or epoch == 0:
            dt = time.time() - self.t0
            print(
                f"[epoch {epoch + 1:3d}] "
                f"train_loss={logs.get('loss', float('nan')):.4f}  "
                f"val_loss={logs.get('val_loss', float('nan')):.4f}  "
                f"val_psnr={logs.get('val_psnr_metric', float('nan')):.2f}dB  "
                f"val_ssim={logs.get('val_ssim_metric', float('nan')):.4f}  "
                f"({dt:.1f}s)",
                flush=True,
            )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--epochs", type=int, default=100)
    ap.add_argument("--batch_size", type=int, default=8)
    ap.add_argument("--lr", type=float, default=1e-4)
    ap.add_argument("--patience", type=int, default=15)
    args = ap.parse_args()

    gpus = tf.config.list_physical_devices("GPU")
    print(f"TF {tf.__version__}  GPUs: {gpus}")
    if not gpus:
        print("WARNING: no GPU detected, training will be very slow on CPU.")

    rows = load_manifest()
    print(f"Loaded {len(rows)} real pairs from {MANIFEST}")
    train_rows, val_rows, test_rows = split_rows(rows)
    print(f"Split -> train={len(train_rows)}  val={len(val_rows)}  test={len(test_rows)}")

    # persist the split so evaluation/doc-figure scripts use the same test set
    for name, split in (("train", train_rows), ("val", val_rows), ("test", test_rows)):
        path = os.path.join(DATA_DIR, f"split_{name}.csv")
        with open(path, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=rows[0].keys())
            w.writeheader()
            w.writerows(split)
    print(f"Saved split_{{train,val,test}}.csv under {DATA_DIR}")

    batch_size = args.batch_size
    train_ds = make_dataset(train_rows, batch_size, shuffle=True, augment=True)
    val_ds = make_dataset(val_rows, batch_size, shuffle=False, augment=False)

    model = build_unet()
    model.summary()

    optimizer = tf.keras.optimizers.Adam(learning_rate=args.lr)
    model.compile(optimizer=optimizer, loss=combined_loss, metrics=[psnr_metric, ssim_metric])

    cbs = [
        EpochLogger(every=5),
        callbacks.ModelCheckpoint(BEST_MODEL_PATH, monitor="val_loss", save_best_only=True, verbose=0),
        callbacks.EarlyStopping(monitor="val_loss", patience=args.patience, restore_best_weights=True, verbose=1),
        callbacks.ReduceLROnPlateau(monitor="val_loss", factor=0.5, patience=6, min_lr=1e-6, verbose=1),
        callbacks.TerminateOnNaN(),
        callbacks.CSVLogger(os.path.join(SAVED_DIR, "autoencoder_training_history_v3.csv")),
    ]

    try:
        history = model.fit(
            train_ds,
            validation_data=val_ds,
            epochs=args.epochs,
            callbacks=cbs,
        )
    except tf.errors.ResourceExhaustedError:
        print("OOM at batch_size", batch_size, "-> retrying with batch_size=4")
        tf.keras.backend.clear_session()
        model = build_unet()
        model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate=args.lr), loss=combined_loss, metrics=[psnr_metric, ssim_metric])
        train_ds = make_dataset(train_rows, 4, shuffle=True, augment=True)
        val_ds = make_dataset(val_rows, 4, shuffle=False, augment=False)
        history = model.fit(train_ds, validation_data=val_ds, epochs=args.epochs, callbacks=cbs)

    # plot curves
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    h = history.history
    fig, ax1 = plt.subplots(figsize=(9, 6))
    ax1.plot(h["loss"], label="Train loss", color="tab:blue")
    ax1.plot(h["val_loss"], label="Val loss", color="tab:orange")
    ax1.set_xlabel("Epoch")
    ax1.set_ylabel("Loss")
    ax1.legend(loc="upper left")

    ax2 = ax1.twinx()
    ax2.plot(h["val_psnr_metric"], label="Val PSNR", color="tab:green")
    ax2.plot(h["val_ssim_metric"], label="Val SSIM", color="tab:red")
    ax2.set_ylabel("PSNR (dB) / SSIM")
    ax2.legend(loc="upper right")

    plt.title("ClearScan Enhancement Autoencoder v3 — Training Curves (real pairs)")
    plt.tight_layout()
    plt.savefig(CURVES_PNG, dpi=150)
    print("Saved training curves:", CURVES_PNG)

    best_val_psnr = max(h["val_psnr_metric"])
    best_val_ssim = max(h["val_ssim_metric"])
    best_val_loss = min(h["val_loss"])
    print(f"\nBest val_loss={best_val_loss:.4f}  best val_psnr={best_val_psnr:.2f}dB  best val_ssim={best_val_ssim:.4f}")
    print("Best model saved to:", BEST_MODEL_PATH)

    if not os.path.exists(BEST_MODEL_PATH):
        print("ERROR: best model file was not saved!", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
