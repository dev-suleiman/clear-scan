import argparse
import csv
import random
from pathlib import Path

import cv2
import numpy as np
from tqdm import tqdm


def apply_gaussian_blur(img: np.ndarray) -> tuple[np.ndarray, float]:
    sigma = random.uniform(0.8, 3.5)
    k = int(sigma * 6) | 1
    return cv2.GaussianBlur(img, (k, k), sigma), sigma


def apply_gaussian_noise(img: np.ndarray) -> tuple[np.ndarray, float]:
    variance = random.uniform(0.005, 0.05)
    noise = np.random.normal(0, np.sqrt(variance), img.shape).astype(np.float32)
    return np.clip(img + noise, 0, 1), variance


def apply_poisson_noise(img: np.ndarray) -> tuple[np.ndarray, float]:
    scaled = (img * 255).astype(np.float32)
    noisy = np.random.poisson(np.maximum(scaled, 0)).astype(np.float32)
    return np.clip(noisy / 255.0, 0, 1), 1.0


def apply_underexposure(img: np.ndarray) -> tuple[np.ndarray, float]:
    factor = random.uniform(0.3, 0.7)
    return np.clip(img * factor, 0, 1), factor


def apply_contrast_compression(img: np.ndarray) -> tuple[np.ndarray, float]:
    compress_ratio = random.uniform(0.3, 0.6)
    img_min, img_max = img.min(), img.max()
    mid = (img_min + img_max) / 2.0
    compressed = mid + (img - mid) * compress_ratio
    return np.clip(compressed, 0, 1), compress_ratio


def apply_combined(img: np.ndarray) -> tuple[np.ndarray, float]:
    fns = [apply_gaussian_blur, apply_gaussian_noise, apply_poisson_noise,
           apply_underexposure, apply_contrast_compression]
    chosen = random.sample(fns, 2)
    result = img.copy()
    severity = 0.0
    for fn in chosen:
        result, sev = fn(result)
        severity += sev
    return result, severity / 2.0


DEGRADATION_FUNCTIONS = {
    "gaussian_blur": apply_gaussian_blur,
    "gaussian_noise": apply_gaussian_noise,
    "poisson_noise": apply_poisson_noise,
    "underexposure": apply_underexposure,
    "contrast_compression": apply_contrast_compression,
    "combined": apply_combined,
}


def main():
    parser = argparse.ArgumentParser(description="Generate synthetic degraded X-ray pairs")
    parser.add_argument("--input_dir", default="data/raw/", help="Directory of clean images")
    parser.add_argument("--output_dir", default="data/synthetic_pairs/", help="Output directory")
    parser.add_argument("--samples_per_image", type=int, default=3)
    args = parser.parse_args()

    input_dir = Path(args.input_dir)
    output_dir = Path(args.output_dir)
    clean_dir = output_dir / "clean"
    degraded_dir = output_dir / "degraded"
    clean_dir.mkdir(parents=True, exist_ok=True)
    degraded_dir.mkdir(parents=True, exist_ok=True)

    extensions = {".png", ".jpg", ".jpeg"}
    image_paths = [p for p in input_dir.iterdir() if p.suffix.lower() in extensions]

    if not image_paths:
        print(f"No images found in {input_dir}")
        return

    manifest_rows = []
    degradation_names = list(DEGRADATION_FUNCTIONS.keys())

    for img_path in tqdm(image_paths, desc="Processing images"):
        img = cv2.imread(str(img_path), cv2.IMREAD_GRAYSCALE)
        if img is None:
            print(f"Warning: could not read {img_path}, skipping.")
            continue
        img = cv2.resize(img, (512, 512))
        float_img = img.astype(np.float32) / 255.0

        clean_out = clean_dir / img_path.name
        cv2.imwrite(str(clean_out), img)

        for i in range(args.samples_per_image):
            deg_name = random.choice(degradation_names)
            fn = DEGRADATION_FUNCTIONS[deg_name]
            degraded_float, severity = fn(float_img.copy())
            degraded_uint8 = (degraded_float * 255).astype(np.uint8)

            stem = img_path.stem
            out_name = f"{stem}_deg_{i}.png"
            deg_out = degraded_dir / out_name
            cv2.imwrite(str(deg_out), degraded_uint8)

            manifest_rows.append({
                "clean_path": str(clean_out),
                "degraded_path": str(deg_out),
                "degradation_type": deg_name,
                "severity": round(severity, 4),
            })

    manifest_path = output_dir / "pairs_manifest.csv"
    with open(manifest_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["clean_path", "degraded_path", "degradation_type", "severity"])
        writer.writeheader()
        writer.writerows(manifest_rows)

    print(f"\nGenerated {len(manifest_rows)} pairs from {len(image_paths)} source images.")
    print(f"Manifest saved to {manifest_path}")


if __name__ == "__main__":
    main()
