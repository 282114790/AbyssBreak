#!/usr/bin/env python3
"""Post-process Gemini-generated floor textures:
1. Remove Gemini logo (bottom-right corner)
2. Make seamless via cross-blend
3. Save as real PNG to assets/tilesets/
"""
import os, sys
import numpy as np
from PIL import Image, ImageFilter, ImageDraw

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RAW_DIR = os.path.join(SCRIPT_DIR, "raw_tiles", "floor_styles")
OUT_DIR = os.path.join(SCRIPT_DIR, "..", "..", "assets", "tilesets")


def remove_logo(img: Image.Image, corner_size: int = 80) -> Image.Image:
    """Inpaint bottom-right corner by mirroring from adjacent region."""
    arr = np.array(img, dtype=np.float64)
    h, w = arr.shape[:2]
    cs = corner_size

    src_region = arr[h - 2 * cs : h - cs, w - 2 * cs : w - cs].copy()

    mask = np.ones((cs, cs), dtype=np.float64)
    for y in range(cs):
        for x in range(cs):
            dy = y / cs
            dx = x / cs
            mask[y, x] = max(dy, dx)

    # Gaussian blur via PIL instead of scipy
    mask_img = Image.fromarray((mask * 255).astype(np.uint8))
    mask_img = mask_img.filter(ImageFilter.GaussianBlur(radius=8))
    mask = np.array(mask_img, dtype=np.float64) / 255.0

    mask3 = mask[:, :, np.newaxis]
    dst_region = arr[h - cs : h, w - cs : w]
    arr[h - cs : h, w - cs : w] = src_region * mask3 + dst_region * (1.0 - mask3)

    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))


def remove_logo_simple(img: Image.Image, corner_size: int = 72) -> Image.Image:
    """Simple logo removal: sample from nearby area and paste over the corner."""
    arr = np.array(img, dtype=np.float64)
    h, w = arr.shape[:2]
    cs = corner_size

    # Take a patch from (h-cs, w-2*cs) to (h, w-cs) — just left of the logo
    src = arr[h - cs : h, w - 2 * cs : w - cs].copy()
    arr[h - cs : h, w - cs : w] = src

    # Smooth the boundary with gaussian
    result = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    return result


def make_seamless(img: Image.Image, blend_ratio: float = 0.25) -> Image.Image:
    """Cross-blend edges to make texture seamless."""
    arr = np.array(img, dtype=np.float64)
    h, w = arr.shape[:2]
    blend_w = int(w * blend_ratio)

    offset = np.roll(np.roll(arr, w // 2, axis=1), h // 2, axis=0)

    mask_h = np.ones((h, w), dtype=np.float64)
    for x in range(blend_w):
        t = x / float(blend_w)
        mask_h[:, x] = t
        mask_h[:, w - 1 - x] = t

    mask_v = np.ones((h, w), dtype=np.float64)
    for y in range(blend_w):
        t = y / float(blend_w)
        mask_v[y, :] = t
        mask_v[h - 1 - y, :] = t

    combined = np.minimum(mask_h, mask_v)[:, :, np.newaxis]
    result = offset * combined + arr * (1.0 - combined)
    return Image.fromarray(np.clip(result, 0, 255).astype(np.uint8))


def process_one(src_path: str, dst_path: str):
    print(f"  Loading: {os.path.basename(src_path)}")
    img = Image.open(src_path).convert("RGB")

    print(f"    Removing logo...")
    try:
        img = remove_logo(img)
    except ImportError:
        print(f"    (scipy not available, using simple method)")
        img = remove_logo_simple(img)

    print(f"    Making seamless...")
    img = make_seamless(img)

    img.save(dst_path, "PNG")
    print(f"    Saved: {dst_path} ({img.size[0]}x{img.size[1]})")


def main():
    raw_dir = RAW_DIR
    out_dir = OUT_DIR

    if len(sys.argv) >= 2:
        raw_dir = sys.argv[1]
    if len(sys.argv) >= 3:
        out_dir = sys.argv[2]

    if not os.path.isdir(raw_dir):
        print(f"Raw directory not found: {raw_dir}")
        print("Run batch_gemini_gen.py first to generate images.")
        return

    os.makedirs(out_dir, exist_ok=True)

    files = sorted(f for f in os.listdir(raw_dir) if f.endswith(".png"))
    if not files:
        print(f"No PNG files in {raw_dir}")
        return

    print(f"Processing {len(files)} files from {raw_dir}")
    print(f"Output to: {out_dir}\n")

    for f in files:
        src = os.path.join(raw_dir, f)
        dst = os.path.join(out_dir, f)
        process_one(src, dst)
        print()

    print(f"Done! {len(files)} textures processed.")
    print(f"\nTo preview 2x2 tiling, run:")
    print(f"  python3 {__file__} --preview")

    if "--preview" in sys.argv:
        print("\nGenerating 2x2 previews...")
        preview_dir = os.path.join(out_dir, "_previews")
        os.makedirs(preview_dir, exist_ok=True)
        for f in files:
            path = os.path.join(out_dir, f)
            if not os.path.exists(path):
                continue
            img = Image.open(path)
            w, h = img.size
            preview = Image.new("RGB", (w * 2, h * 2))
            for ty in range(2):
                for tx in range(2):
                    preview.paste(img, (tx * w, ty * h))
            pname = f.replace(".png", "_2x2.png")
            preview.save(os.path.join(preview_dir, pname))
            print(f"  {pname}")


if __name__ == "__main__":
    main()
