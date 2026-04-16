"""
AbyssBreak Tile Pipeline — Step 2: 后处理 + Spritesheet 打包
功能:
  1. 读取 raw_tiles/ 下的 AI 生成图
  2. 裁剪/缩放到目标尺寸
  3. 清理背景（需要透明的类别）
  4. 色调映射到目标色板
  5. 无缝拼接检查（地板类）
  6. 打包为 spritesheet
  7. 复制到 Godot 项目目录

用法:
  python process_tiles.py                          # 处理所有
  python process_tiles.py --category floor --theme dungeon
  python process_tiles.py --skip-color-map         # 跳过色调映射
"""

import json
import argparse
import shutil
from pathlib import Path

try:
    from PIL import Image, ImageFilter, ImageStat, ImageEnhance
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

try:
    import numpy as np
    HAS_NUMPY = True
except ImportError:
    HAS_NUMPY = False

SCRIPT_DIR = Path(__file__).parent
CONFIG_PATH = SCRIPT_DIR / "tile_config.json"


def load_config() -> dict:
    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def remove_watermark(img: Image.Image, corner_size: int = 80, margin: int = 5) -> Image.Image:
    """
    去除右下角的 Gemini 四角星水印。
    用水印区域周围的纹理做 inpaint 填充：
    取水印左侧和上方的像素块平均混合后覆盖水印区域。
    """
    import numpy as np

    if img.mode != "RGBA":
        img = img.convert("RGBA")

    arr = np.array(img, dtype=np.float32)
    h, w = arr.shape[:2]

    y1 = h - corner_size - margin
    x1 = w - corner_size - margin
    y2 = h - margin
    x2 = w - margin

    patch_h = y2 - y1
    patch_w = x2 - x1

    src_left = arr[y1:y2, (x1 - patch_w):x1, :].copy()
    src_top = arr[(y1 - patch_h):y1, x1:x2, :].copy()

    src_left_flipped = src_left[:, ::-1, :]

    src_top_flipped = src_top[::-1, :, :]

    blended = src_left_flipped * 0.5 + src_top_flipped * 0.5

    for y_off in range(patch_h):
        for x_off in range(patch_w):
            dy = min(y_off, patch_h - 1 - y_off)
            dx = min(x_off, patch_w - 1 - x_off)
            edge_dist = min(dy, dx)
            blend_zone = min(12, patch_h // 4)
            if edge_dist < blend_zone:
                t = edge_dist / blend_zone
                oy = y1 + y_off
                ox = x1 + x_off
                blended[y_off, x_off] = arr[oy, ox] * (1 - t) + blended[y_off, x_off] * t

    arr[y1:y2, x1:x2, :] = blended

    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def resize_tile(img: Image.Image, target_w: int, target_h: int) -> Image.Image:
    """缩放到目标尺寸，保持质量"""
    if img.size == (target_w, target_h):
        return img
    return img.resize((target_w, target_h), Image.LANCZOS)


def _rgb_to_hsv_array(rgb: np.ndarray) -> np.ndarray:
    """RGB (uint8) -> HSV array, H in [0,360], S/V in [0,100]."""
    norm = rgb.astype(np.float32) / 255.0
    r, g, b = norm[:, :, 0], norm[:, :, 1], norm[:, :, 2]

    max_c = np.maximum(np.maximum(r, g), b)
    min_c = np.minimum(np.minimum(r, g), b)
    delta = max_c - min_c

    h = np.zeros_like(max_c)
    mask_r = (max_c == r) & (delta != 0)
    h[mask_r] = (60 * ((g[mask_r] - b[mask_r]) / delta[mask_r]) + 360) % 360
    mask_g = (max_c == g) & (delta != 0)
    h[mask_g] = 60 * ((b[mask_g] - r[mask_g]) / delta[mask_g]) + 120
    mask_b = (max_c == b) & (delta != 0)
    h[mask_b] = 60 * ((r[mask_b] - g[mask_b]) / delta[mask_b]) + 240

    s = np.zeros_like(max_c)
    s[max_c != 0] = delta[max_c != 0] / max_c[max_c != 0]

    return np.stack([h, s * 100, max_c * 100], axis=-1)


def clean_background(img: Image.Image, threshold: int = 248) -> Image.Image:
    """
    软绿幕移除: 用连续的 greenness 分数代替二值掩码，保留更多边缘细节。
      1) HSV 软评分: 计算每像素与 chromakey 绿的接近程度 (0~1)
      2) 绿色主导软评分: 捕获低饱和度的绿色残留 (阈值收紧)
      3) 合并评分, 对 alpha 做比例衰减而非硬切
      4) 高置信绿色 (score>0.7) 直接设 alpha=0
      5) 1px 高斯模糊 alpha 通道消除锯齿
      6) 兜底白色移除
    """
    if img.mode != "RGBA":
        img = img.convert("RGBA")

    data = np.array(img)
    rgb = data[:, :, :3]
    alpha = data[:, :, 3].astype(np.float32)

    # --- HSV 软评分 ---
    hsv = _rgb_to_hsv_array(rgb)
    h, s, v = hsv[:, :, 0], hsv[:, :, 1], hsv[:, :, 2]

    hue_diff = np.abs(h - 120.0)
    hue_diff = np.minimum(hue_diff, 360.0 - hue_diff)

    hue_score = np.clip(1.0 - hue_diff / 50.0, 0.0, 1.0)
    sat_score = np.clip((s - 15.0) / 45.0, 0.0, 1.0)
    val_score = np.clip((v - 15.0) / 45.0, 0.0, 1.0)
    green_score = hue_score * sat_score * val_score

    # --- 绿色主导软评分 (收紧: ratio > 1.6 才开始计分) ---
    r = rgb[:, :, 0].astype(np.float32)
    g = rgb[:, :, 1].astype(np.float32)
    b = rgb[:, :, 2].astype(np.float32)
    rb_max = np.maximum(r, b) + 1.0
    dominance = np.clip((g / rb_max - 1.6) / 1.0, 0.0, 1.0)

    combined_score = np.maximum(green_score, dominance * 0.5)

    # --- 软 alpha 衰减 ---
    alpha *= (1.0 - combined_score)

    # --- 高置信区域硬切 ---
    alpha[combined_score > 0.7] = 0.0

    # --- 1px 高斯模糊 alpha, 消除锯齿 ---
    alpha_img = Image.fromarray(np.clip(alpha, 0, 255).astype(np.uint8), "L")
    alpha_img = alpha_img.filter(ImageFilter.GaussianBlur(radius=0.8))
    alpha = np.array(alpha_img, dtype=np.float32)

    # --- 兜底白色背景 ---
    white_mask = (rgb[:, :, 0] > threshold) & (rgb[:, :, 1] > threshold) & (rgb[:, :, 2] > threshold)
    alpha[white_mask] = 0.0

    data[:, :, 3] = np.clip(alpha, 0, 255).astype(np.uint8)
    return Image.fromarray(data)


def apply_color_mapping(img: Image.Image, palette: dict, strength: float = 0.3) -> Image.Image:
    """
    轻微色调映射：将图像整体色调向目标色板偏移
    strength 控制映射强度 (0=不变, 1=完全映射)
    """
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    img = img.copy()

    stat = ImageStat.Stat(img.convert("RGB"))
    avg_r, avg_g, avg_b = stat.mean

    target_r = palette["mid"][0]
    target_g = palette["mid"][1]
    target_b = palette["mid"][2]

    shift_r = (target_r - avg_r) * strength
    shift_g = (target_g - avg_g) * strength
    shift_b = (target_b - avg_b) * strength

    pixels = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a < 10:
                continue
            nr = max(0, min(255, int(r + shift_r)))
            ng = max(0, min(255, int(g + shift_g)))
            nb = max(0, min(255, int(b + shift_b)))
            pixels[x, y] = (nr, ng, nb, a)

    return img


def check_seamless(img: Image.Image, edge_px: int = 4) -> tuple:
    """
    检查图片边缘的无缝程度
    返回 (总分, 水平分, 垂直分)，每项 0~1，1=完美无缝
    """
    if img.mode != "RGB":
        check = img.convert("RGB")
    else:
        check = img

    w, h = check.size
    pixels = check.load()

    h_diff = 0
    h_count = 0
    for y in range(h):
        for dx in range(edge_px):
            l = pixels[dx, y]
            r = pixels[w - 1 - dx, y]
            diff = sum(abs(a - b) for a, b in zip(l, r)) / (3 * 255)
            h_diff += diff
            h_count += 1

    v_diff = 0
    v_count = 0
    for x in range(w):
        for dy in range(edge_px):
            t = pixels[x, dy]
            b = pixels[x, h - 1 - dy]
            diff = sum(abs(a - b) for a, b in zip(t, b)) / (3 * 255)
            v_diff += diff
            v_count += 1

    h_score = max(0.0, 1.0 - (h_diff / max(h_count, 1)) * 5)
    v_score = max(0.0, 1.0 - (v_diff / max(v_count, 1)) * 5)
    total = (h_score + v_score) / 2.0

    return (total, h_score, v_score)


def _remove_lighting_gradient(img: Image.Image) -> Image.Image:
    """
    消除 AI 生成的方向性光照梯度。
    检测图片四条边的平均亮度差，如果存在明显的从左到右或从上到下的
    亮度渐变，就用反向渐变补偿回来。
    """
    import numpy as np

    if img.mode != "RGBA":
        img = img.convert("RGBA")

    arr = np.array(img, dtype=np.float32)
    rgb = arr[:, :, :3]
    alpha = arr[:, :, 3]

    h, w = rgb.shape[:2]
    sample = max(1, w // 8)

    left_avg = rgb[:, :sample, :].mean()
    right_avg = rgb[:, -sample:, :].mean()
    top_avg = rgb[:sample, :, :].mean()
    bottom_avg = rgb[-sample:, :, :].mean()

    h_gradient = right_avg - left_avg
    v_gradient = bottom_avg - top_avg

    threshold = 8.0
    if abs(h_gradient) < threshold and abs(v_gradient) < threshold:
        return img

    for x_idx in range(w):
        h_comp = -h_gradient * (x_idx / (w - 1) - 0.5)
        for y_idx in range(h):
            if alpha[y_idx, x_idx] < 10:
                continue
            v_comp = -v_gradient * (y_idx / (h - 1) - 0.5)
            comp = h_comp + v_comp
            rgb[y_idx, x_idx, 0] = max(0, min(255, rgb[y_idx, x_idx, 0] + comp))
            rgb[y_idx, x_idx, 1] = max(0, min(255, rgb[y_idx, x_idx, 1] + comp))
            rgb[y_idx, x_idx, 2] = max(0, min(255, rgb[y_idx, x_idx, 2] + comp))

    arr[:, :, :3] = rgb
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def _normalize_edge_brightness(img: Image.Image, edge_px: int = 12) -> Image.Image:
    """
    单独均衡化四条边的亮度，让对边的亮度趋于一致。
    只在边缘 edge_px 像素范围内做渐变式修正，不影响中心。
    """
    import numpy as np

    if img.mode != "RGBA":
        img = img.convert("RGBA")

    arr = np.array(img, dtype=np.float32)
    rgb = arr[:, :, :3]
    h, w = rgb.shape[:2]

    left_mean = rgb[:, 0, :].mean()
    right_mean = rgb[:, -1, :].mean()
    target_h = (left_mean + right_mean) / 2.0

    for x in range(edge_px):
        t = 1.0 - (x / edge_px)
        shift_l = (target_h - left_mean) * t
        shift_r = (target_h - right_mean) * t
        rgb[:, x, :] = np.clip(rgb[:, x, :] + shift_l, 0, 255)
        rgb[:, w - 1 - x, :] = np.clip(rgb[:, w - 1 - x, :] + shift_r, 0, 255)

    top_mean = rgb[0, :, :].mean()
    bottom_mean = rgb[-1, :, :].mean()
    target_v = (top_mean + bottom_mean) / 2.0

    for y in range(edge_px):
        t = 1.0 - (y / edge_px)
        shift_t = (target_v - top_mean) * t
        shift_b = (target_v - bottom_mean) * t
        rgb[y, :, :] = np.clip(rgb[y, :, :] + shift_t, 0, 255)
        rgb[h - 1 - y, :, :] = np.clip(rgb[h - 1 - y, :, :] + shift_b, 0, 255)

    arr[:, :, :3] = rgb
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def make_seamless(img: Image.Image, blend_px: int = None) -> Image.Image:
    """
    三步无缝处理:
    1. 消除方向性光照梯度（根因修复）
    2. 均衡四边亮度
    3. 半偏移融合法（经典 tileable 技术）:
       将图偏移 (w/2, h/2)，让原本的边缘变成中央，
       然后用渐变 mask 混合原图和偏移图，
       保证实际边缘完美衔接。
    """
    import numpy as np

    if img.mode != "RGBA":
        img = img.convert("RGBA")

    w, h = img.size
    if blend_px is None:
        blend_px = max(8, w // 4)

    img = _remove_lighting_gradient(img)
    img = _normalize_edge_brightness(img, edge_px=blend_px // 2)

    arr_orig = np.array(img, dtype=np.float32)

    half_w, half_h = w // 2, h // 2
    arr_shifted = np.roll(np.roll(arr_orig, half_w, axis=1), half_h, axis=0)

    mask = np.zeros((h, w), dtype=np.float32)

    for y in range(h):
        dy = min(y, h - 1 - y)
        wy = min(1.0, dy / blend_px) if blend_px > 0 else 1.0
        for x in range(w):
            dx = min(x, w - 1 - x)
            wx = min(1.0, dx / blend_px) if blend_px > 0 else 1.0
            mask[y, x] = wx * wy

    mask_4ch = mask[:, :, np.newaxis]
    blended = arr_orig * mask_4ch + arr_shifted * (1.0 - mask_4ch)

    blended[:, :, 3] = arr_orig[:, :, 3]

    return Image.fromarray(blended.astype(np.uint8), "RGBA")


def apply_edge_feather(img: Image.Image, feather_px: int = 32, noise_scale: float = 0.12,
                       noise_seed: int = 42) -> Image.Image:
    """
    用噪声驱动的不规则 alpha 遮罩对 tile 边缘做羽化。
    feather_px: 羽化带宽度（像素）
    noise_scale: 噪声频率，越大锯齿越碎
    noise_seed: 噪声种子，保证同批 tile 一致

    边缘从完全不透明渐变到透明，渐变线不是直线而是受噪声扰动的不规则曲线，
    让 tile 重叠时呈现自然的有机过渡。
    """
    import numpy as np

    if img.mode != "RGBA":
        img = img.convert("RGBA")

    arr = np.array(img, dtype=np.float32)
    h, w = arr.shape[:2]

    rng = np.random.RandomState(noise_seed)
    noise_field = rng.rand(h, w).astype(np.float32)
    from PIL import ImageFilter
    noise_img = Image.fromarray((noise_field * 255).astype(np.uint8), "L")
    noise_img = noise_img.filter(ImageFilter.GaussianBlur(radius=max(1, int(1.0 / max(noise_scale, 0.01)))))
    noise_field = np.array(noise_img, dtype=np.float32) / 255.0

    xs = np.arange(w, dtype=np.float32)
    ys = np.arange(h, dtype=np.float32)
    dist_left = xs[np.newaxis, :]
    dist_right = (w - 1 - xs)[np.newaxis, :]
    dist_top = ys[:, np.newaxis]
    dist_bottom = (h - 1 - ys)[:, np.newaxis]
    min_dist = np.minimum(np.minimum(dist_left, dist_right),
                          np.minimum(dist_top, dist_bottom))

    noise_offset = (noise_field - 0.5) * feather_px * 0.6
    effective_dist = min_dist + noise_offset
    t = np.clip(effective_dist / feather_px, 0.0, 1.0)
    mask = t * t * (3.0 - 2.0 * t)

    arr[:, :, 3] = arr[:, :, 3] * mask
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def pack_spritesheet(tiles: list, cols: int, tile_w: int, tile_h: int) -> Image.Image:
    """将 tile 列表打包为 spritesheet"""
    rows = max(1, (len(tiles) + cols - 1) // cols)
    sheet = Image.new("RGBA", (cols * tile_w, rows * tile_h), (0, 0, 0, 0))

    for i, tile in enumerate(tiles):
        x = (i % cols) * tile_w
        y = (i // cols) * tile_h
        sheet.paste(tile, (x, y))

    return sheet


def process_category(config: dict, category: str, theme: str,
                     skip_color_map: bool = False) -> Image.Image | None:
    """处理单个类别+主题的所有 tile"""
    cat_cfg = config["tile_categories"][category]
    if theme not in cat_cfg["themes"]:
        return None

    theme_cfg = cat_cfg["themes"][theme]
    palette = config["color_palettes"].get(theme, {})
    src_w, src_h = cat_cfg["source_size"]
    raw_dir = SCRIPT_DIR / config["raw_dir"] / f"{category}_{theme}"
    proc_dir = SCRIPT_DIR / config["processed_dir"] / f"{category}_{theme}"
    proc_dir.mkdir(parents=True, exist_ok=True)

    if not raw_dir.exists():
        print(f"  跳过: {raw_dir} 不存在")
        return None

    png_files = sorted(raw_dir.glob("*.png"))
    if not png_files:
        print(f"  跳过: {raw_dir} 无 PNG 文件")
        return None

    print(f"  找到 {len(png_files)} 张原始图片")

    processed_tiles = []
    seamless_scores = []

    for idx, png_path in enumerate(png_files):
        img = Image.open(png_path).convert("RGBA")

        img = remove_watermark(img)
        print(f"    去水印: {png_path.name}")

        img = resize_tile(img, src_w, src_h)

        if cat_cfg.get("has_alpha"):
            img = clean_background(img)

        if not skip_color_map and palette:
            img = apply_color_mapping(img, palette, strength=0.25)

        if cat_cfg.get("seamless"):
            total, h_score, v_score = check_seamless(img)
            seamless_scores.append((png_path.name, total, h_score, v_score))
            img = make_seamless(img)
            new_total, new_h, new_v = check_seamless(img)
            if total < 0.8 or new_total > total:
                detail = f"总={total:.2f}→{new_total:.2f} 水平={h_score:.2f}→{new_h:.2f} 垂直={v_score:.2f}→{new_v:.2f}"
                print(f"    无缝修正: {png_path.name} {detail}")

        out_path = proc_dir / png_path.name
        img.save(out_path, "PNG")
        processed_tiles.append(img)

    if seamless_scores:
        avg = sum(s[1] for s in seamless_scores) / len(seamless_scores)
        low = [(s[0], s[1], s[2], s[3]) for s in seamless_scores if s[1] < 0.5]
        print(f"  无缝评分(处理前): 平均={avg:.2f}, 低分={len(low)}张")
        if low:
            for name, total, hs, vs in low[:5]:
                print(f"    注意: {name} 得分 {total:.2f} (水平={hs:.2f}, 垂直={vs:.2f})")

    if not processed_tiles:
        return None

    max_tiles = cat_cfg["sheet_cols"] * cat_cfg["sheet_rows"]
    if len(processed_tiles) > max_tiles:
        print(f"  警告: 图片数({len(processed_tiles)})超过sheet容量({max_tiles}), 截断")
        processed_tiles = processed_tiles[:max_tiles]

    sheet = pack_spritesheet(
        processed_tiles,
        cols=cat_cfg["sheet_cols"],
        tile_w=src_w,
        tile_h=src_h
    )

    return sheet


def generate_tile_manifest(config: dict, category: str, theme: str,
                           sheet_path: Path) -> dict:
    """生成 tile 清单，供 Godot 脚本使用"""
    cat_cfg = config["tile_categories"][category]
    src_w, src_h = cat_cfg["source_size"]
    disp_w, disp_h = cat_cfg["display_size"]

    raw_dir = SCRIPT_DIR / config["raw_dir"] / f"{category}_{theme}"
    tile_count = len(list(raw_dir.glob("*.png"))) if raw_dir.exists() else 0

    return {
        "category": category,
        "theme": theme,
        "sheet_file": sheet_path.name,
        "tile_count": min(tile_count, cat_cfg["sheet_cols"] * cat_cfg["sheet_rows"]),
        "source_tile_size": [src_w, src_h],
        "display_tile_size": [disp_w, disp_h],
        "sheet_cols": cat_cfg["sheet_cols"],
        "sheet_rows": cat_cfg["sheet_rows"],
        "has_alpha": cat_cfg.get("has_alpha", False),
        "seamless": cat_cfg.get("seamless", False),
        "scale_factor": [disp_w / src_w, disp_h / src_h],
    }


def main():
    if not HAS_PIL:
        print("错误: 请先安装 Pillow: pip install Pillow")
        sys.exit(1)
    if not HAS_NUMPY:
        print("错误: 请先安装 numpy: pip install numpy")
        sys.exit(1)

    parser = argparse.ArgumentParser(description="AbyssBreak Tile Processor")
    parser.add_argument("--category", type=str, default=None)
    parser.add_argument("--theme", type=str, default=None)
    parser.add_argument("--skip-color-map", action="store_true")
    args = parser.parse_args()

    config = load_config()
    output_dir = (SCRIPT_DIR / config["output_dir"]).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    print("=" * 60)
    print("AbyssBreak Tile Pipeline — 后处理 & 打包")
    print("=" * 60)

    manifests = []
    categories = [args.category] if args.category else config["tile_categories"].keys()

    for cat_name in categories:
        cat_cfg = config["tile_categories"][cat_name]
        themes = [args.theme] if args.theme else cat_cfg["themes"].keys()

        for theme in themes:
            if theme not in cat_cfg["themes"]:
                continue

            print(f"\n[{cat_name} / {theme}]")
            sheet = process_category(config, cat_name, theme,
                                     skip_color_map=args.skip_color_map)

            if sheet is None:
                continue

            sheet_name = f"{cat_name}_{theme}_sheet.png"
            sheet_path = output_dir / sheet_name
            sheet.save(sheet_path, "PNG")
            print(f"  Spritesheet: {sheet_path}")
            print(f"  尺寸: {sheet.size[0]}x{sheet.size[1]}")

            manifest = generate_tile_manifest(config, cat_name, theme, sheet_path)
            manifests.append(manifest)

    manifest_path = output_dir / "tile_manifest.json"
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifests, f, ensure_ascii=False, indent=2)
    print(f"\n清单文件: {manifest_path}")

    print(f"\n全部完成! Spritesheet 已输出到: {output_dir}")
    print("下一步: 在 Godot 中重新导入资源，或运行 python update_godot_imports.py")


import sys

if __name__ == "__main__":
    main()
