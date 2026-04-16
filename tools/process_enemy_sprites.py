#!/usr/bin/env python3
"""怪物 spritesheet 后处理：去 Gemini logo → 绿幕抠图 → 透明背景 PNG

用法:
  python3 process_enemy_sprites.py <raw_dir> <output_dir>
  python3 process_enemy_sprites.py   # 默认: raw_enemy_sprites/ → assets/sprites/enemies/
"""

import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("需要 Pillow: pip install Pillow")
    sys.exit(1)

try:
    import numpy as np
except ImportError:
    print("需要 numpy: pip install numpy")
    sys.exit(1)

SCRIPT_DIR = Path(__file__).parent
sys.path.insert(0, str(SCRIPT_DIR / "tile_pipeline"))
from process_tiles import remove_watermark, clean_background


def process_sprite(src: Path, dst: Path) -> bool:
    try:
        img = Image.open(src).convert("RGBA")
    except Exception as e:
        print(f"[ERR] 无法打开 {src.name}: {e}")
        return False

    w, h = img.size
    print(f"  {w}x{h}", end="", flush=True)

    min_dim = min(w, h)
    if min_dim >= 200:
        img = remove_watermark(img, corner_size=80, margin=5)
    elif min_dim >= 100:
        cs = min_dim // 4
        img = remove_watermark(img, corner_size=cs, margin=2)
    else:
        pass  # 太小，跳过去 logo
    print(" → 去logo", end="", flush=True)

    img = clean_background(img)
    print(" → 去绿幕", end="", flush=True)

    dst.parent.mkdir(parents=True, exist_ok=True)
    img.save(dst, "PNG")
    size_kb = dst.stat().st_size // 1024
    print(f" → OK ({size_kb}KB)")
    return True


def main():
    if len(sys.argv) >= 3:
        raw_dir = Path(sys.argv[1])
        out_dir = Path(sys.argv[2])
    elif len(sys.argv) == 2:
        raw_dir = Path(sys.argv[1])
        out_dir = SCRIPT_DIR.parent / "assets" / "sprites" / "enemies"
    else:
        raw_dir = SCRIPT_DIR / "raw_enemy_sprites"
        out_dir = SCRIPT_DIR.parent / "assets" / "sprites" / "enemies"

    if not raw_dir.exists():
        print(f"原始目录不存在: {raw_dir}")
        sys.exit(1)

    pngs = sorted(raw_dir.glob("*.png"))
    if not pngs:
        print(f"未找到 PNG: {raw_dir}")
        return

    out_dir.mkdir(parents=True, exist_ok=True)
    print(f"输入: {raw_dir.resolve()}  ({len(pngs)} 张)")
    print(f"输出: {out_dir.resolve()}\n")

    ok = 0
    for i, p in enumerate(pngs):
        print(f"[{i+1}/{len(pngs)}] {p.name}", end="", flush=True)
        if process_sprite(p, out_dir / p.name):
            ok += 1

    print(f"\n完成: {ok}/{len(pngs)} 成功")


if __name__ == "__main__":
    main()
