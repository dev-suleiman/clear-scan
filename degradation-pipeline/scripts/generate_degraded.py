"""
Synthetic degradation pipeline for chest X-ray images.
Generates clean/degraded image pairs for ML training.
"""
import argparse
import csv
import random
import time
from pathlib import Path

import cv2
import numpy as np
from tqdm import tqdm

SUPPORTED_EXTENSIONS = {".png", ".jpg", ".jpeg", ".bmp"}
TARGET_SIZE = (512, 512)
DEGRADATION_TYPES = [
    "gaussian_blur",
    "gaussian_noise",
    "poisson_noise",
    "underexposure",
    "contrast_compression",
    "combined",
]


def _to_float(img: np.ndarray) -> np.ndarray:
    return img.astype(np.float64) / 255.0


def _to_uint8(img: np.ndarray) -> np.ndarray:
    return np.clip(img * 255.0, 0, 255).astype(np.uint8)


def gaussian_blur(img: np.ndarray) -> tuple[np.ndarray, str]:
    sigma = random.uniform(0.8, 3.5)
    # kernel size must be odd and large enough to capture sigma
    k = int(2 * round(3 * sigma) + 1)
    k = k if k % 2 == 1 else k + 1
    result = cv2.GaussianBlur(img, (k, k), sigma)
    return result, f"sigma={sigma:.2f}"


def gaussian_noise(img: np.ndarray) -> tuple[np.ndarray, str]:
    variance = random.uniform(0.005, 0.05)
    f = _to_float(img)
    noise = np.random.normal(0, variance ** 0.5, f.shape)
    result = _to_uint8(f + noise)
    return result, f"variance={variance:.4f}"


def poisson_noise(img: np.ndarray) -> tuple[np.ndarray, str]:
    f = _to_float(img)
    # scale factor determines how much Poisson noise is applied
    scale = random.uniform(10.0, 50.0)
    noisy = np.random.poisson(f * scale) / scale
    result = _to_uint8(noisy)
    return result, f"scale={scale:.1f}"


def underexposure(img: np.ndarray) -> tuple[np.ndarray, str]:
    factor = random.uniform(0.3, 0.7)
    f = _to_float(img)
    result = _to_uint8(f * factor)
    return result, f"factor={factor:.2f}"


def contrast_compression(img: np.ndarray) -> tuple[np.ndarray, str]:
    pct = random.uniform(0.30, 0.60)
    f = _to_float(img)
    lo, hi = f.min(), f.max()
    spread = hi - lo
    if spread < 1e-6:
        return img.copy(), f"pct={pct:.2f},spread=0"
    mid = (lo + hi) / 2.0
    new_half = (spread * pct) / 2.0
    compressed = (f - mid) * (new_half / (spread / 2.0)) + mid
    result = _to_uint8(compressed)
    return result, f"pct={pct:.2f}"


def combined(img: np.ndarray) -> tuple[np.ndarray, str]:
    base_fns = [gaussian_blur, gaussian_noise, poisson_noise, underexposure, contrast_compression]
    chosen = random.sample(base_fns, 2)
    result, p1 = chosen[0](img)
    result, p2 = chosen[1](result)
    names = f"{chosen[0].__name__}+{chosen[1].__name__}"
    return result, f"{names}({p1},{p2})"


DEGRADATION_FN_MAP = {
    "gaussian_blur": gaussian_blur,
    "gaussian_noise": gaussian_noise,
    "poisson_noise": poisson_noise,
    "underexposure": underexposure,
    "contrast_compression": contrast_compression,
    "combined": combined,
}


def pick_degradations(n: int) -> list[str]:
    """Pick n degradation types ensuring no two consecutive picks are the same."""
    picks = []
    last = None
    for _ in range(n):
        pool = [d for d in DEGRADATION_TYPES if d != last]
        choice = random.choice(pool)
        picks.append(choice)
        last = choice
    return picks


def process_images(input_dir: Path, output_dir: Path, samples_per_image: int) -> None:
    clean_dir = output_dir / "clean"
    degraded_dir = output_dir / "degraded"
    clean_dir.mkdir(parents=True, exist_ok=True)
    degraded_dir.mkdir(parents=True, exist_ok=True)

    images = [p for p in input_dir.iterdir() if p.suffix.lower() in SUPPORTED_EXTENSIONS]
    if not images:
        print(f"No supported images found in {input_dir}")
        return

    manifest_path = output_dir / "pairs_manifest.csv"
    manifest_rows = []
    type_counts: dict[str, int] = {t: 0 for t in DEGRADATION_TYPES}
    total_degraded = 0

    t0 = time.time()

    for img_path in tqdm(images, desc="Processing images", unit="img"):
        img = cv2.imread(str(img_path), cv2.IMREAD_GRAYSCALE)
        if img is None:
            tqdm.write(f"Warning: could not read {img_path.name}, skipping")
            continue

        resized = cv2.resize(img, TARGET_SIZE, interpolation=cv2.INTER_CUBIC)

        clean_out = clean_dir / img_path.name
        cv2.imwrite(str(clean_out), resized)

        deg_types = pick_degradations(samples_per_image)

        for variant_num, deg_type in enumerate(deg_types, start=1):
            fn = DEGRADATION_FN_MAP[deg_type]
            degraded_img, params_str = fn(resized)

            stem = img_path.stem
            deg_filename = f"{stem}_deg_{variant_num}_{deg_type}.png"
            deg_out = degraded_dir / deg_filename
            cv2.imwrite(str(deg_out), degraded_img)

            manifest_rows.append({
                "clean_path": str(clean_out.relative_to(output_dir.parent)),
                "degraded_path": str(deg_out.relative_to(output_dir.parent)),
                "degradation_type": deg_type,
                "parameters_used": params_str,
            })
            type_counts[deg_type] += 1
            total_degraded += 1

    elapsed = time.time() - t0

    with open(manifest_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["clean_path", "degraded_path", "degradation_type", "parameters_used"])
        writer.writeheader()
        writer.writerows(manifest_rows)

    print(f"\n{'='*60}")
    print(f"SUMMARY")
    print(f"{'='*60}")
    print(f"Clean images processed : {len(images)}")
    print(f"Degraded images created: {total_degraded}")
    print(f"\nBreakdown by degradation type:")
    for dtype, count in type_counts.items():
        print(f"  {dtype:<24}: {count}")
    print(f"\nTotal processing time  : {elapsed:.1f}s")
    print(f"Manifest written to    : {manifest_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate synthetic degraded chest X-ray pairs")
    parser.add_argument("--input_dir", default="data/raw/", help="Directory of clean source images")
    parser.add_argument("--output_dir", default="data/synthetic_pairs/", help="Output directory for pairs")
    parser.add_argument("--samples_per_image", type=int, default=3, help="Degraded variants per image")
    args = parser.parse_args()

    input_dir = Path(args.input_dir)
    output_dir = Path(args.output_dir)

    if not input_dir.exists():
        raise SystemExit(f"Input directory not found: {input_dir}")

    process_images(input_dir, output_dir, args.samples_per_image)


if __name__ == "__main__":
    main()
