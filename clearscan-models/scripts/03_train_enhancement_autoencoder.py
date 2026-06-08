import argparse
from pathlib import Path

import cv2
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import tensorflow as tf


def build_unet(input_shape=(512, 512, 1)) -> tf.keras.Model:
    inputs = tf.keras.Input(shape=input_shape)

    # Encoder
    def enc_block(x, filters):
        x = tf.keras.layers.Conv2D(filters, 3, padding="same", activation="relu")(x)
        x = tf.keras.layers.BatchNormalization()(x)
        x = tf.keras.layers.Conv2D(filters, 3, padding="same", activation="relu")(x)
        x = tf.keras.layers.BatchNormalization()(x)
        return x

    e1 = enc_block(inputs, 32)
    p1 = tf.keras.layers.MaxPooling2D(2)(e1)
    e2 = enc_block(p1, 64)
    p2 = tf.keras.layers.MaxPooling2D(2)(e2)
    e3 = enc_block(p2, 128)
    p3 = tf.keras.layers.MaxPooling2D(2)(e3)
    e4 = enc_block(p3, 256)
    p4 = tf.keras.layers.MaxPooling2D(2)(e4)

    # Bottleneck
    b = tf.keras.layers.Conv2D(512, 3, padding="same", activation="relu")(p4)
    b = tf.keras.layers.BatchNormalization()(b)
    b = tf.keras.layers.Conv2D(512, 3, padding="same", activation="relu")(b)
    b = tf.keras.layers.BatchNormalization()(b)

    # Decoder
    def dec_block(x, skip, filters):
        x = tf.keras.layers.UpSampling2D(2)(x)
        x = tf.keras.layers.Conv2D(filters, 2, padding="same", activation="relu")(x)
        x = tf.keras.layers.Concatenate()([x, skip])
        x = tf.keras.layers.Conv2D(filters, 3, padding="same", activation="relu")(x)
        x = tf.keras.layers.Conv2D(filters, 3, padding="same", activation="relu")(x)
        return x

    d1 = dec_block(b, e4, 256)
    d2 = dec_block(d1, e3, 128)
    d3 = dec_block(d2, e2, 64)
    d4 = dec_block(d3, e1, 32)

    outputs = tf.keras.layers.Conv2D(1, 1, activation="sigmoid")(d4)
    return tf.keras.Model(inputs, outputs)


def combined_loss(y_true, y_pred):
    mse = tf.reduce_mean(tf.square(y_true - y_pred))
    ssim_val = tf.reduce_mean(tf.image.ssim(y_true, y_pred, max_val=1.0))
    return 0.5 * mse + 0.5 * (1.0 - ssim_val)


def compute_psnr_ssim(y_true: np.ndarray, y_pred: np.ndarray):
    psnr_vals, ssim_vals = [], []
    for t, p in zip(y_true, y_pred):
        mse = np.mean((t - p) ** 2)
        psnr = 20 * np.log10(1.0 / (np.sqrt(mse) + 1e-8)) if mse > 0 else 100.0
        psnr_vals.append(psnr)

        t_t = tf.constant(t[np.newaxis], dtype=tf.float32)
        p_t = tf.constant(p[np.newaxis], dtype=tf.float32)
        ssim = float(tf.image.ssim(t_t, p_t, max_val=1.0).numpy()[0])
        ssim_vals.append(ssim)
    return np.mean(psnr_vals), np.mean(ssim_vals)


def load_pair(clean_path: str, degraded_path: str):
    clean = cv2.imread(clean_path, cv2.IMREAD_GRAYSCALE)
    deg = cv2.imread(degraded_path, cv2.IMREAD_GRAYSCALE)
    if clean is None or deg is None:
        return None, None
    clean = cv2.resize(clean, (512, 512)).astype(np.float32) / 255.0
    deg = cv2.resize(deg, (512, 512)).astype(np.float32) / 255.0
    return clean[..., np.newaxis], deg[..., np.newaxis]


def main():
    parser = argparse.ArgumentParser(description="Train enhancement autoencoder")
    parser.add_argument("--epochs", type=int, default=100)
    parser.add_argument("--data_dir", default="data/synthetic_pairs/")
    parser.add_argument("--model_dir", default="models/saved/")
    args = parser.parse_args()

    data_dir = Path(args.data_dir)
    model_dir = Path(args.model_dir)
    model_dir.mkdir(parents=True, exist_ok=True)

    manifest_path = data_dir / "pairs_manifest.csv"
    if not manifest_path.exists():
        print(f"Manifest not found at {manifest_path}. Run script 01 first.")
        return

    df = pd.read_csv(manifest_path)

    clean_imgs, deg_imgs = [], []
    for _, row in df.iterrows():
        c, d = load_pair(row["clean_path"], row["degraded_path"])
        if c is not None:
            clean_imgs.append(c)
            deg_imgs.append(d)

    if len(clean_imgs) < 3:
        print("Not enough image pairs. Creating synthetic data for dry-run.")
        clean_imgs = [np.random.rand(512, 512, 1).astype(np.float32) for _ in range(10)]
        deg_imgs = [np.random.rand(512, 512, 1).astype(np.float32) for _ in range(10)]

    clean_imgs = np.array(clean_imgs, dtype=np.float32)
    deg_imgs = np.array(deg_imgs, dtype=np.float32)

    n = len(clean_imgs)
    n_train = max(1, int(n * 0.8))
    n_val = max(1, int(n * 0.1))

    X_train_d, y_train_c = deg_imgs[:n_train], clean_imgs[:n_train]
    X_val_d, y_val_c = deg_imgs[n_train:n_train + n_val], clean_imgs[n_train:n_train + n_val]
    X_test_d, y_test_c = deg_imgs[n_train + n_val:], clean_imgs[n_train + n_val:]

    if len(X_test_d) == 0:
        X_test_d, y_test_c = X_val_d, y_val_c

    print(f"Train: {len(X_train_d)}, Val: {len(X_val_d)}, Test: {len(X_test_d)}")

    model = build_unet()
    model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3), loss=combined_loss)

    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor="val_loss", patience=15, restore_best_weights=True
        ),
    ]

    history = model.fit(
        X_train_d, y_train_c,
        validation_data=(X_val_d, y_val_c),
        epochs=args.epochs,
        batch_size=8,
        callbacks=callbacks,
        verbose=1,
    )

    model.save(str(model_dir / "enhancement_autoencoder.keras"))
    print(f"\nModel saved to {model_dir / 'enhancement_autoencoder.keras'}")

    val_preds = model.predict(X_val_d)
    psnr, ssim = compute_psnr_ssim(y_val_c, val_preds)
    print(f"Final val PSNR: {psnr:.2f} dB, SSIM: {ssim:.4f}")

    epochs_ran = len(history.history["loss"])
    ep_range = range(1, epochs_ran + 1)
    fig, axes = plt.subplots(1, 3, figsize=(15, 4))
    axes[0].plot(ep_range, history.history["loss"], label="train")
    axes[0].plot(ep_range, history.history["val_loss"], label="val")
    axes[0].set_title("Loss")
    axes[0].legend()

    axes[1].set_title("PSNR (final val)")
    axes[1].bar(["PSNR"], [psnr])
    axes[1].set_ylabel("dB")

    axes[2].set_title("SSIM (final val)")
    axes[2].bar(["SSIM"], [ssim])

    plt.tight_layout()
    curves_path = model_dir / "autoencoder_training_curves.png"
    plt.savefig(str(curves_path), dpi=100)
    plt.close()
    print(f"Training curves saved to {curves_path}")


if __name__ == "__main__":
    main()
