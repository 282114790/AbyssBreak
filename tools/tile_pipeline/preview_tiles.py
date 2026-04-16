"""
AbyssBreak Tile Pipeline — 预览工具
生成拼接预览图，在导入 Godot 之前检查:
  - 无缝拼接效果
  - 色调一致性
  - 整体视觉效果

用法:
  python preview_tiles.py --category floor --theme dungeon
  python preview_tiles.py --all
"""

import json
import argparse
import random
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

SCRIPT_DIR = Path(__file__).parent
CONFIG_PATH = SCRIPT_DIR / "tile_config.json"


def load_config() -> dict:
    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def generate_tiling_preview(sheet_path: Path, cat_cfg: dict,
                            grid_w: int = 12, grid_h: int = 8) -> Image.Image:
    """从 spritesheet 中随机抽取 tile 拼成预览图"""
    sheet = Image.open(sheet_path).convert("RGBA")
    src_w, src_h = cat_cfg["source_size"]
    cols = cat_cfg["sheet_cols"]

    sheet_w, sheet_h = sheet.size
    actual_cols = sheet_w // src_w
    actual_rows = sheet_h // src_h
    tile_count = actual_cols * actual_rows

    tiles = []
    for idx in range(tile_count):
        col = idx % actual_cols
        row = idx // actual_cols
        region = sheet.crop((col * src_w, row * src_h,
                             (col + 1) * src_w, (row + 1) * src_h))
        if region.getbbox() is not None:
            tiles.append(region)

    if not tiles:
        return Image.new("RGBA", (100, 100), (255, 0, 0, 255))

    disp_w, disp_h = cat_cfg["display_size"]
    preview = Image.new("RGBA", (grid_w * disp_w, grid_h * disp_h), (30, 22, 18, 255))

    random.seed(42)
    for gy in range(grid_h):
        for gx in range(grid_w):
            tile = random.choice(tiles)
            resized = tile.resize((disp_w, disp_h), Image.LANCZOS)
            preview.paste(resized, (gx * disp_w, gy * disp_h), resized)

    return preview


def generate_catalog_preview(proc_dir: Path, cat_cfg: dict) -> Image.Image | None:
    """生成每个 tile 的编目预览"""
    src_w, src_h = cat_cfg["source_size"]
    pngs = sorted(proc_dir.glob("*.png"))
    if not pngs:
        return None

    cols = min(8, len(pngs))
    rows = (len(pngs) + cols - 1) // cols
    padding = 4
    cell_w = src_w + padding * 2
    cell_h = src_h + padding * 2

    catalog = Image.new("RGBA",
                         (cols * cell_w, rows * cell_h),
                         (40, 35, 30, 255))

    for i, png_path in enumerate(pngs):
        col = i % cols
        row = i // cols
        tile = Image.open(png_path).convert("RGBA")
        tile = tile.resize((src_w, src_h), Image.LANCZOS)
        x = col * cell_w + padding
        y = row * cell_h + padding
        catalog.paste(tile, (x, y), tile)

    return catalog


def main():
    if not HAS_PIL:
        print("错误: 请先安装 Pillow: pip install Pillow")
        return

    parser = argparse.ArgumentParser(description="AbyssBreak Tile Preview")
    parser.add_argument("--category", type=str, default=None)
    parser.add_argument("--theme", type=str, default=None)
    parser.add_argument("--all", action="store_true")
    args = parser.parse_args()

    config = load_config()
    output_dir = (SCRIPT_DIR / config["output_dir"]).resolve()
    preview_dir = SCRIPT_DIR / "previews"
    preview_dir.mkdir(parents=True, exist_ok=True)

    print("=" * 60)
    print("AbyssBreak Tile Pipeline — 预览生成")
    print("=" * 60)

    categories = [args.category] if args.category else config["tile_categories"].keys()

    for cat_name in categories:
        cat_cfg = config["tile_categories"][cat_name]
        themes = [args.theme] if args.theme else cat_cfg["themes"].keys()

        for theme in themes:
            if theme not in cat_cfg["themes"]:
                continue

            sheet_path = output_dir / f"{cat_name}_{theme}_sheet.png"
            if not sheet_path.exists():
                print(f"  跳过: {sheet_path.name} 不存在")
                continue

            print(f"\n[{cat_name} / {theme}]")

            if cat_cfg.get("seamless"):
                tiling = generate_tiling_preview(sheet_path, cat_cfg)
                tiling_path = preview_dir / f"preview_tiling_{cat_name}_{theme}.png"
                tiling.save(tiling_path, "PNG")
                print(f"  拼接预览: {tiling_path}")

            proc_dir = SCRIPT_DIR / config["processed_dir"] / f"{cat_name}_{theme}"
            catalog = generate_catalog_preview(proc_dir, cat_cfg)
            if catalog:
                catalog_path = preview_dir / f"preview_catalog_{cat_name}_{theme}.png"
                catalog.save(catalog_path, "PNG")
                print(f"  编目预览: {catalog_path}")

    print(f"\n预览图已保存到: {preview_dir}")


if __name__ == "__main__":
    main()
