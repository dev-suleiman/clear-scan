import argparse
import os
import random
import warnings
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
import tensorflow as tf
from sklearn.metrics import classification_report, confusion_matrix, roc_auc_score, roc_curve
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import label_binarize

from scripts.quality_metrics import compute_metrics

CLASSES = ["Good", "Fair", "Poor"]
CLASS_TO_IDX = {c: i for i, c in enumerate(CLASSES)}


def load_or_create_labels(data_dir: Path, model_dir: Path) -> pd.DataFrame:
    labels_path = data_dir / "labels.csv"
    if labels_path.exists():
        return pd.read_csv(labels_path)

    print("\n[WARNING] data/labelled/labels.csv not found.")
    print("[WARNING] Generating a SYNTHETIC labels CSV from data/raw/ for verification only.")
    print("[WARNING] Replace with real labelled data before actual training.\n")

    raw_dir = Path("data/raw")
    extensions = {".png", ".jpg", ".jpeg"}
    image_files = [p.name for p in raw_dir.iterdir() if p.suffix.lower() in extensions]

    if not image_files:
        image_files = [f"test_{i:03d}.png" for i in range(1, 10)]

    rows = []
    for fname in image_files:
        label = random.choice(CLASSES)
        rows.append({"filename": fname, "quality_label": label, "defects": ""})

    df = pd.DataFrame(rows)
    data_dir.mkdir(parents=True, exist_ok=True)
    df.to_csv(labels_path, index=False)
    print(f"Synthetic labels saved to {labels_path}")
    return df


def load_image(path: str) -> np.ndarray | None:
    import cv2
    img = cv2.imread(path, cv2.IMREAD_GRAYSCALE)
    if img is None:
        return None
    img = cv2.resize(img, (224, 224))
    img = img.astype(np.float32) / 255.0
    img = np.stack([img, img, img], axis=-1)
    return img


def build_model() -> tf.keras.Model:
    base = tf.keras.applications.MobileNetV2(
        weights="imagenet", include_top=False, input_shape=(224, 224, 3)
    )
    base.trainable = False

    inputs = tf.keras.Input(shape=(224, 224, 3))
    x = tf.keras.layers.RandomFlip("horizontal")(inputs)
    x = tf.keras.layers.RandomRotation(0.08)(x)
    x = tf.keras.layers.RandomBrightness(0.2)(x)
    x = tf.keras.layers.RandomZoom(0.1)(x)
    x = base(x, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dense(128, activation="relu")(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    outputs = tf.keras.layers.Dense(3, activation="softmax")(x)
    return tf.keras.Model(inputs, outputs)


class ClassicalBaselineClassifier:
    def predict(self, images: list) -> list[str]:
        preds = []
        for img in images:
            img = np.array(img)
            gray = img[:, :, 0]
            metrics = compute_metrics(gray)
            preds.append(metrics["quality_class"])
        return preds


def main():
    parser = argparse.ArgumentParser(description="Train quality classifier")
    parser.add_argument("--epochs", type=int, default=50)
    parser.add_argument("--data_dir", default="data/labelled/")
    parser.add_argument("--model_dir", default="models/saved/")
    args = parser.parse_args()

    data_dir = Path(args.data_dir)
    model_dir = Path(args.model_dir)
    classifier_eval_dir = model_dir / "classifier_eval"
    classifier_eval_dir.mkdir(parents=True, exist_ok=True)

    df = load_or_create_labels(data_dir, model_dir)

    raw_dir = Path("data/raw")
    images, labels, valid_rows = [], [], []
    for _, row in df.iterrows():
        path = raw_dir / row["filename"]
        img = load_image(str(path))
        if img is not None:
            images.append(img)
            labels.append(CLASS_TO_IDX[row["quality_label"]])
            valid_rows.append(row)

    if len(images) < 9 or (len(images) > 0 and min(np.bincount(np.array(labels, dtype=np.int32))) < 2):
        print("Not enough labelled images for stratified split. Using synthetic data for dry-run.")
        images = [np.random.rand(224, 224, 3).astype(np.float32) for _ in range(30)]
        labels = [i % 3 for i in range(30)]

    images = np.array(images, dtype=np.float32)
    labels = np.array(labels, dtype=np.int32)

    X_train, X_temp, y_train, y_temp = train_test_split(
        images, labels, test_size=0.30, stratify=labels, random_state=42
    )
    X_val, X_test, y_val, y_test = train_test_split(
        X_temp, y_temp, test_size=0.50, stratify=y_temp, random_state=42
    )

    print(f"Train: {len(X_train)}, Val: {len(X_val)}, Test: {len(X_test)}")

    y_train_cat = tf.keras.utils.to_categorical(y_train, 3)
    y_val_cat = tf.keras.utils.to_categorical(y_val, 3)
    y_test_cat = tf.keras.utils.to_categorical(y_test, 3)

    model = build_model()
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-4),
        loss="categorical_crossentropy",
        metrics=["accuracy"],
    )

    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor="val_loss", patience=10, restore_best_weights=True
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor="val_loss", factor=0.5, patience=5
        ),
    ]

    model.fit(
        X_train, y_train_cat,
        validation_data=(X_val, y_val_cat),
        epochs=args.epochs,
        batch_size=16,
        callbacks=callbacks,
        verbose=1,
    )

    model.save(str(model_dir / "quality_classifier.keras"))
    print(f"\nModel saved to {model_dir / 'quality_classifier.keras'}")

    y_pred_probs = model.predict(X_test)
    y_pred = np.argmax(y_pred_probs, axis=1)

    print("\n=== CNN Classification Report ===")
    print(classification_report(y_test, y_pred, target_names=CLASSES, zero_division=0))

    cm = confusion_matrix(y_test, y_pred)
    plt.figure(figsize=(6, 5))
    sns.heatmap(cm, annot=True, fmt="d", xticklabels=CLASSES, yticklabels=CLASSES, cmap="Blues")
    plt.title("Confusion Matrix")
    plt.ylabel("True")
    plt.xlabel("Predicted")
    plt.tight_layout()
    plt.savefig(str(classifier_eval_dir / "confusion_matrix.png"), dpi=100)
    plt.close()
    print(f"Confusion matrix saved to {classifier_eval_dir / 'confusion_matrix.png'}")

    y_test_bin = label_binarize(y_test, classes=[0, 1, 2])
    plt.figure(figsize=(7, 5))
    try:
        for i, cls in enumerate(CLASSES):
            fpr, tpr, _ = roc_curve(y_test_bin[:, i], y_pred_probs[:, i])
            auc = roc_auc_score(y_test_bin[:, i], y_pred_probs[:, i])
            plt.plot(fpr, tpr, label=f"{cls} (AUC={auc:.2f})")
        plt.plot([0, 1], [0, 1], "k--")
        plt.xlabel("False Positive Rate")
        plt.ylabel("True Positive Rate")
        plt.title("ROC Curves (One-vs-Rest)")
        plt.legend()
        plt.tight_layout()
        plt.savefig(str(classifier_eval_dir / "roc_curves.png"), dpi=100)
        plt.close()
        print(f"ROC curves saved to {classifier_eval_dir / 'roc_curves.png'}")
    except Exception as e:
        print(f"ROC curve generation skipped: {e}")

    baseline = ClassicalBaselineClassifier()
    baseline_preds = baseline.predict(X_test.tolist())
    baseline_label_ids = [CLASS_TO_IDX.get(p, 0) for p in baseline_preds]
    from sklearn.metrics import f1_score
    cnn_f1 = f1_score(y_test, y_pred, average="macro", zero_division=0)
    baseline_f1 = f1_score(y_test, baseline_label_ids, average="macro", zero_division=0)
    print(f"\nCNN macro F1:      {cnn_f1:.4f}")
    print(f"Baseline macro F1: {baseline_f1:.4f}")


if __name__ == "__main__":
    main()
