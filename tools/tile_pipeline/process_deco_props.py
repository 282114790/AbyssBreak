#!/usr/bin/env python3
"""处理 deco_props_dungeon：去 Gemini logo → 去绿幕 → 缩放 256x256

复用 process_tiles.py 中的 remove_watermark 和 clean_background 函数。
输出 32 张独立透明背景 PNG，不打包 spritesheet。
"""

import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("需要安装 Pillow: pip install Pillow")
    sys.exit(1)

try:
    import numpy as np
except ImportError:
    print("需要安装 numpy: pip install numpy")
    sys.exit(1)

from process_tiles import remove_watermark, clean_background

SCRIPT_DIR = Path(__file__).parent
RAW_DIR = SCRIPT_DIR / "../../raw_tiles/deco_props_dungeon"
OUTPUT_DIR = SCRIPT_DIR / "../../assets/tilesets/deco_props_dungeon"
TARGET_SIZE = 256


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    png_files = sorted(RAW_DIR.glob("*.png"))
    if not png_files:
        print(f"未找到 PNG 文件: {RAW_DIR}")
        return

    print(f"找到 {len(png_files)} 张原始图片")
    print(f"输出: {OUTPUT_DIR.resolve()}")
    print(f"目标尺寸: {TARGET_SIZE}x{TARGET_SIZE}\n")

    for i, path in enumerate(png_files):
        name = path.name
        print(f"[{i+1}/{len(png_files)}] {name}", end=" ", flush=True)

        img = Image.open(path).convert("RGBA")
        print(f"({img.size[0]}x{img.size[1]})", end=" ", flush=True)

        img = remove_watermark(img)
        print("→ 去logo", end=" ", flush=True)

        img = clean_background(img)
        print("→ 去绿幕", end=" ", flush=True)

        if img.size != (TARGET_SIZE, TARGET_SIZE):
            img = img.resize((TARGET_SIZE, TARGET_SIZE), Image.LANCZOS)
        print(f"→ {TARGET_SIZE}x{TARGET_SIZE}", end=" ", flush=True)

        out_path = OUTPUT_DIR / name
        img.save(out_path, "PNG")
        size_kb = out_path.stat().st_size // 1024
        print(f"→ OK ({size_kb}KB)")

    print(f"\n完成! {len(png_files)} 张图片已处理到 {OUTPUT_DIR.resolve()}")


if __name__ == "__main__":
    main()
