"""
Evaluate the freshly-trained real-pairs enhancement autoencoder and
generate all Chapter 4 documentation figures.

Unlike the old synthetic pipeline, there is only one real degradation
type here (overexposure), so the "6 degradation types" grid from the
old script is replaced with 6 representative test pairs (mixed
same_patient / cross_patient, mixed PA/AP) — all genuinely overexposed
chest X-rays, not synthetic.

Does not touch models/saved/quality_classifier*.
"""
import csv
import os

import cv2
import numpy as np
import tensorflow as tf
from skimage.filters import unsharp_mask
from skimage.metrics import peak_signal_noise_ratio as sk_psnr
from skimage.metrics import structural_similarity as sk_ssim
from tabulate import tabulate

IMG_SIZE = 512
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(BASE, "data", "real_pairs")
SAVED_DIR = os.path.join(BASE, "models", "saved")
FIG_DIR = os.path.join(SAVED_DIR, "eval_figures")
MODEL_PATH = os.path.join(SAVED_DIR, "enhancement_autoencoder.keras")
RESULTS_CSV = os.path.join(SAVED_DIR, "evaluation_results.csv")

os.makedirs(FIG_DIR, exist_ok=True)

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


def load_gray(path, size=IMG_SIZE):
    img = cv2.imread(path, cv2.IMREAD_GRAYSCALE)
    img = cv2.resize(img, (size, size), interpolation=cv2.INTER_LINEAR)
    return img


def clahe_pipeline(img_u8):
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    out = clahe.apply(img_u8)
    out = cv2.fastNlMeansDenoising(out, h=7)
    out_f = out.astype(np.float32) / 255.0
    out_f = unsharp_mask(out_f, radius=1.0, amount=1.5)
    out_u8 = np.clip(out_f * 255.0, 0, 255).astype(np.uint8)
    return out_u8


def cnn_enhance(model, img_u8):
    x = img_u8.astype(np.float32) / 255.0
    x = x[np.newaxis, :, :, np.newaxis]
    y = model.predict(x, verbose=0)[0, :, :, 0]
    return np.clip(y * 255.0, 0, 255).astype(np.uint8)


def metrics(ref_u8, test_u8):
    ssim = sk_ssim(ref_u8, test_u8, data_range=255)
    psnr = sk_psnr(ref_u8, test_u8, data_range=255)
    return ssim, psnr


def load_test_rows():
    path = os.path.join(DATA_DIR, "split_test.csv")
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


def main():
    print("Loading model:", MODEL_PATH)
    model = tf.keras.models.load_model(
        MODEL_PATH,
        custom_objects={
            "combined_loss": lambda y_true, y_pred: 0.0,
            "psnr_metric": lambda y_true, y_pred: 0.0,
            "ssim_metric": lambda y_true, y_pred: 0.0,
        },
        compile=False,
    )

    test_rows = load_test_rows()
    print(f"Test split size: {len(test_rows)}")

    rng = np.random.default_rng(7)
    # 6 representative pairs: try to mix same_patient / cross_patient and PA / AP
    same = [r for r in test_rows if r["pair_type"] == "same_patient"]
    cross = [r for r in test_rows if r["pair_type"] == "cross_patient"]
    picks = []
    for pool in (same, cross, same, cross, same, cross):
        if pool:
            picks.append(pool[int(rng.integers(0, len(pool)))])
    picks = picks[:6] if len(picks) >= 6 else (test_rows[:6])

    all_results = []  # per selected sample: dict of ssim/psnr for orig/clahe/cnn
    imgs = []  # for grid figure

    for row in picks:
        deg_path = os.path.join(DATA_DIR, "overexposed", row["overexposed_file"])
        clean_path = os.path.join(DATA_DIR, "clear", row["clear_file"])
        deg = load_gray(deg_path)
        clean = load_gray(clean_path)

        clahe_out = clahe_pipeline(deg)
        cnn_out = cnn_enhance(model, deg)

        orig_ssim, orig_psnr = metrics(clean, deg)
        clahe_ssim, clahe_psnr = metrics(clean, clahe_out)
        cnn_ssim, cnn_psnr = metrics(clean, cnn_out)

        all_results.append({
            "label": f"{row['overexposed_file']} ({row['pair_type']})",
            "orig_ssim": orig_ssim, "orig_psnr": orig_psnr,
            "clahe_ssim": clahe_ssim, "clahe_psnr": clahe_psnr,
            "cnn_ssim": cnn_ssim, "cnn_psnr": cnn_psnr,
        })
        imgs.append({
            "label": row["overexposed_file"], "pair_type": row["pair_type"],
            "deg": deg, "clahe": clahe_out, "cnn": cnn_out, "clean": clean,
            "clahe_ssim": clahe_ssim, "clahe_psnr": clahe_psnr,
            "cnn_ssim": cnn_ssim, "cnn_psnr": cnn_psnr,
            "orig_ssim": orig_ssim, "orig_psnr": orig_psnr,
        })

    # --- 4c: comparison grid (6 rows x 3 cols) ---
    fig, axes = plt.subplots(6, 3, figsize=(10, 20))
    for i, d in enumerate(imgs):
        axes[i, 0].imshow(d["deg"], cmap="gray")
        axes[i, 0].set_title(f"SSIM {d['orig_ssim']:.3f} / PSNR {d['orig_psnr']:.1f}dB", fontsize=9)
        axes[i, 0].set_ylabel(d["pair_type"], fontsize=9)
        axes[i, 1].imshow(d["clahe"], cmap="gray")
        axes[i, 1].set_title(f"SSIM {d['clahe_ssim']:.3f} / PSNR {d['clahe_psnr']:.1f}dB", fontsize=9)
        axes[i, 2].imshow(d["cnn"], cmap="gray")
        axes[i, 2].set_title(f"SSIM {d['cnn_ssim']:.3f} / PSNR {d['cnn_psnr']:.1f}dB", fontsize=9)
        for j in range(3):
            axes[i, j].set_xticks([])
            axes[i, j].set_yticks([])
    axes[0, 0].set_title("Degraded original\n" + axes[0, 0].get_title(), fontsize=9)
    axes[0, 1].set_title("CLAHE enhanced\n" + axes[0, 1].get_title(), fontsize=9)
    axes[0, 2].set_title("CNN enhanced\n" + axes[0, 2].get_title(), fontsize=9)
    fig.suptitle("ClearScan Enhancement Results — Original vs CLAHE vs CNN (real overexposure pairs)", fontsize=13)
    plt.tight_layout()
    grid_path = os.path.join(FIG_DIR, "enhancement_comparison_grid_v2.png")
    plt.savefig(grid_path, dpi=150)
    plt.close(fig)
    print("Saved:", grid_path)

    # --- 4d: bar chart ---
    mean_orig_ssim = np.mean([d["orig_ssim"] for d in imgs])
    mean_clahe_ssim = np.mean([d["clahe_ssim"] for d in imgs])
    mean_cnn_ssim = np.mean([d["cnn_ssim"] for d in imgs])
    mean_orig_psnr = np.mean([d["orig_psnr"] for d in imgs])
    mean_clahe_psnr = np.mean([d["clahe_psnr"] for d in imgs])
    mean_cnn_psnr = np.mean([d["cnn_psnr"] for d in imgs])

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 5))
    labels = ["Original", "CLAHE", "CNN"]
    ssim_vals = [mean_orig_ssim, mean_clahe_ssim, mean_cnn_ssim]
    psnr_vals = [mean_orig_psnr, mean_clahe_psnr, mean_cnn_psnr]

    bars1 = ax1.bar(labels, ssim_vals, color=["#888888", "#4C72B0", "#55A868"])
    ax1.set_title("Mean SSIM")
    ax1.set_ylim(0, 1.0)
    for b, v in zip(bars1, ssim_vals):
        ax1.text(b.get_x() + b.get_width() / 2, v + 0.01, f"{v:.3f}", ha="center", fontsize=9)

    bars2 = ax2.bar(labels, psnr_vals, color=["#888888", "#4C72B0", "#55A868"])
    ax2.set_title("Mean PSNR (dB)")
    for b, v in zip(bars2, psnr_vals):
        ax2.text(b.get_x() + b.get_width() / 2, v + 0.3, f"{v:.1f}", ha="center", fontsize=9)

    fig.suptitle("ClearScan Enhancement Quality: Original vs CLAHE vs CNN", fontsize=13)
    plt.tight_layout()
    chart_path = os.path.join(FIG_DIR, "comparison_chart_v2.png")
    plt.savefig(chart_path, dpi=150)
    plt.close(fig)
    print("Saved:", chart_path)

    # --- 4e: best enhancement example (highest SSIM improvement) ---
    best = max(imgs, key=lambda d: d["cnn_ssim"] - d["orig_ssim"])
    fig, axes = plt.subplots(1, 2, figsize=(10, 5.5))
    axes[0].imshow(best["deg"], cmap="gray")
    axes[0].set_title("Original")
    axes[0].axis("off")
    axes[1].imshow(best["cnn"], cmap="gray")
    axes[1].set_title("CNN Enhanced")
    axes[1].axis("off")
    d_ssim = best["cnn_ssim"] - best["orig_ssim"]
    d_psnr = best["cnn_psnr"] - best["orig_psnr"]
    fig.suptitle(
        f"Best Enhancement Example ({best['label']})\n"
        f"SSIM {best['orig_ssim']:.3f} -> {best['cnn_ssim']:.3f} (+{d_ssim:.3f})   "
        f"PSNR {best['orig_psnr']:.1f} -> {best['cnn_psnr']:.1f}dB (+{d_psnr:.1f}dB)",
        fontsize=11,
    )
    plt.tight_layout()
    best_path = os.path.join(FIG_DIR, "best_enhancement_example.png")
    plt.savefig(best_path, dpi=150)
    plt.close(fig)
    print("Saved:", best_path)

    # --- 4f: overexposure correction example (3 candidates from test split) ---
    cand_rows = list(rng.choice(test_rows, size=min(3, len(test_rows)), replace=False))
    over_candidates = []
    for row in cand_rows:
        deg_path = os.path.join(DATA_DIR, "overexposed", row["overexposed_file"])
        clean_path = os.path.join(DATA_DIR, "clear", row["clear_file"])
        deg = load_gray(deg_path)
        clean = load_gray(clean_path)
        cnn_out = cnn_enhance(model, deg)
        o_ssim, o_psnr = metrics(clean, deg)
        c_ssim, c_psnr = metrics(clean, cnn_out)
        over_candidates.append({
            "label": row["overexposed_file"], "deg": deg, "cnn": cnn_out,
            "o_ssim": o_ssim, "o_psnr": o_psnr, "c_ssim": c_ssim, "c_psnr": c_psnr,
        })

    best_over = max(over_candidates, key=lambda d: d["c_ssim"] - d["o_ssim"])
    fig, axes = plt.subplots(1, 2, figsize=(10, 5.5))
    axes[0].imshow(best_over["deg"], cmap="gray")
    axes[0].set_title("Overexposed Original")
    axes[0].axis("off")
    axes[1].imshow(best_over["cnn"], cmap="gray")
    axes[1].set_title("CNN Enhanced")
    axes[1].axis("off")
    d_ssim = best_over["c_ssim"] - best_over["o_ssim"]
    d_psnr = best_over["c_psnr"] - best_over["o_psnr"]
    fig.suptitle(
        f"Overexposure Correction — ClearScan v2 ({best_over['label']})\n"
        f"SSIM {best_over['o_ssim']:.3f} -> {best_over['c_ssim']:.3f} (+{d_ssim:.3f})   "
        f"PSNR {best_over['o_psnr']:.1f} -> {best_over['c_psnr']:.1f}dB (+{d_psnr:.1f}dB)",
        fontsize=11,
    )
    plt.tight_layout()
    over_path = os.path.join(FIG_DIR, "overexposure_correction_example.png")
    plt.savefig(over_path, dpi=150)
    plt.close(fig)
    print("Saved:", over_path)

    # --- results CSV ---
    with open(RESULTS_CSV, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=[
            "label", "orig_ssim", "orig_psnr", "clahe_ssim", "clahe_psnr", "cnn_ssim", "cnn_psnr",
        ])
        w.writeheader()
        w.writerows(all_results)
    print("Saved:", RESULTS_CSV)

    # --- 4g: results table ---
    table_rows = []
    for r in all_results:
        table_rows.append([
            r["label"],
            f"{r['orig_ssim']:.3f} / {r['orig_psnr']:.1f}",
            f"{r['clahe_ssim']:.3f} / {r['clahe_psnr']:.1f}",
            f"{r['cnn_ssim']:.3f} / {r['cnn_psnr']:.1f}",
        ])
    table_rows.append([
        "MEAN",
        f"{mean_orig_ssim:.3f} / {mean_orig_psnr:.1f}",
        f"{mean_clahe_ssim:.3f} / {mean_clahe_psnr:.1f}",
        f"{mean_cnn_ssim:.3f} / {mean_cnn_psnr:.1f}",
    ])
    print("\nCLEARSCAN V2 ENHANCEMENT RESULTS (real overexposure pairs)\n")
    print(tabulate(table_rows, headers=["Sample", "Original\nSSIM/PSNR", "CLAHE\nSSIM/PSNR", "CNN\nSSIM/PSNR"], tablefmt="grid"))

    cnn_wins = sum(1 for r in all_results if r["cnn_ssim"] > r["clahe_ssim"])
    print(f"\nCNN win rate: {cnn_wins} out of {len(all_results)} images")
    clahe_improve = (mean_clahe_ssim - mean_orig_ssim) / mean_orig_ssim * 100
    cnn_improve = (mean_cnn_ssim - mean_orig_ssim) / mean_orig_ssim * 100
    print(f"CLAHE 20% SSIM improvement target: {'MET' if clahe_improve >= 20 else 'NOT MET'} ({clahe_improve:.1f}%)")
    print(f"CNN 20% SSIM improvement target:   {'MET' if cnn_improve >= 20 else 'NOT MET'} ({cnn_improve:.1f}%)")


if __name__ == "__main__":
    main()
