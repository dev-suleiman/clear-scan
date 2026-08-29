"""
Train the ClearScan enhancement autoencoder v4 on a HYBRID dataset:

- Synthetic overexposure pairs (majority, ~79%): a clear X-ray is used as
  the target, and the input is synthesized ON THE FLY as
  clip(target * factor, 0, 1) with factor ~ Uniform(1.3, 2.5) — a fresh
  random factor every time the sample is drawn, so effectively infinite
  variation across epochs. This gives the network a clean, pixel-aligned,
  invertible signal for "undo this specific overexposure" — the v3 model
  never had this and (per training-curve analysis) plateaued almost
  immediately with negligible visible correction, because its only
  supervision was real, anatomically-UNALIGNED pairs (different scans /
  different patients), which is a weak/noisy signal for pixel regression.

- Real same-patient, same-view pairs (minority, ~21%): genuine overexposed
  chest X-rays paired with a same-patient, same-view clear scan. Kept for
  domain realism / robustness, filtered down from the v3 dataset by
  dropping cross-patient pairs entirely (least aligned, likely the biggest
  source of the "no visible effect" problem) and different-view
  same-patient pairs.

Data source: data/real_pairs/{overexposed,clear,synthetic_pool}/*.png +
             data/real_pairs/v4_manifest.csv
             (columns: pair_type, aligned, target_file, target_dir,
              input_file, input_dir, patient, view)

This is a brand-new model trained independently of v3 — no warm-start.
Never touches quality_classifier*.
"""
import argparse
import csv
import os
import sys
import time
from collections import defaultdict

import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models, callbacks

IMG_SIZE = 512
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(BASE, "data", "real_pairs")
MANIFEST = os.path.join(DATA_DIR, "v4_manifest.csv")
SAVED_DIR = os.path.join(BASE, "models", "saved")
CURVES_PNG = os.path.join(SAVED_DIR, "autoencoder_training_curves_v4.png")
BEST_MODEL_PATH = os.path.join(SAVED_DIR, "enhancement_autoencoder.keras")

os.makedirs(SAVED_DIR, exist_ok=True)


def load_manifest():
    with open(MANIFEST, newline="") as f:
        return list(csv.DictReader(f))


def split_rows(rows, seed=42, val_frac=0.1, test_frac=0.1):
    """Stratified split by pair_type so train/val/test each keep the
    real/synthetic mix, not just a lucky/unlucky random draw."""
    by_type = defaultdict(list)
    for r in rows:
        by_type[r["pair_type"]].append(r)

    rng = np.random.default_rng(seed)
    train, val, test = [], [], []
    for pair_type, group in by_type.items():
        idx = np.arange(len(group))
        rng.shuffle(idx)
        n = len(group)
        n_val = int(n * val_frac)
        n_test = int(n * test_frac)
        val += [group[i] for i in idx[:n_val]]
        test += [group[i] for i in idx[n_val:n_val + n_test]]
        train += [group[i] for i in idx[n_val + n_test:]]
    return train, val, test


def decode_png(path):
    data = tf.io.read_file(path)
    img = tf.io.decode_png(data, channels=1)
    img = tf.image.resize(img, [IMG_SIZE, IMG_SIZE], method="bilinear")
    img = tf.cast(img, tf.float32) / 255.0
    return img


def make_dataset(rows, batch_size, shuffle, augment):
    target_paths = [os.path.join(DATA_DIR, r["target_dir"], r["target_file"]) for r in rows]
    # for synthetic rows input_path is unused (dummy = target's own path)
    input_paths = [
        os.path.join(DATA_DIR, r["input_dir"], r["input_file"]) if r["pair_type"] == "real_same_patient"
        else os.path.join(DATA_DIR, r["target_dir"], r["target_file"])
        for r in rows
    ]
    is_synthetic = [r["pair_type"] == "synthetic_overexposure" for r in rows]

    ds = tf.data.Dataset.from_tensor_slices((target_paths, input_paths, is_synthetic))

    def _load(target_path, input_path, synthetic_flag):
        target = decode_png(target_path)

        def synth():
            factor = tf.random.uniform([], 1.3, 2.5)
            return tf.clip_by_value(target * factor, 0.0, 1.0)

        def real():
            return decode_png(input_path)

        x = tf.cond(synthetic_flag, synth, real)
        return x, target

    ds = ds.map(_load, num_parallel_calls=tf.data.AUTOTUNE)

    if augment:
        def _aug(x, y):
            if tf.random.uniform([]) > 0.5:
                x = tf.image.flip_left_right(x)
                y = tf.image.flip_left_right(y)
            return x, y
        ds = ds.map(_aug, num_parallel_calls=tf.data.AUTOTUNE)

    if shuffle:
        ds = ds.shuffle(buffer_size=min(len(rows), 4000), seed=42)

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

    return models.Model(inputs, outputs, name="clearscan_enhancement_unet_v4")


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
    n_real = sum(1 for r in rows if r["pair_type"] == "real_same_patient")
    n_syn = sum(1 for r in rows if r["pair_type"] == "synthetic_overexposure")
    print(f"Loaded {len(rows)} pairs from {MANIFEST}  (real={n_real}, synthetic={n_syn})")

    train_rows, val_rows, test_rows = split_rows(rows)
    print(f"Split -> train={len(train_rows)}  val={len(val_rows)}  test={len(test_rows)}")
    for name, split in (("train", train_rows), ("val", val_rows), ("test", test_rows)):
        n_r = sum(1 for r in split if r["pair_type"] == "real_same_patient")
        n_s = sum(1 for r in split if r["pair_type"] == "synthetic_overexposure")
        print(f"  {name}: real={n_r} synthetic={n_s}")
        path = os.path.join(DATA_DIR, f"split_v4_{name}.csv")
        with open(path, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=rows[0].keys())
            w.writeheader()
            w.writerows(split)
    print(f"Saved split_v4_{{train,val,test}}.csv under {DATA_DIR}")

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
        callbacks.CSVLogger(os.path.join(SAVED_DIR, "autoencoder_training_history_v4.csv")),
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

    plt.title("ClearScan Enhancement Autoencoder v4 — Training Curves (hybrid synthetic+real)")
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
