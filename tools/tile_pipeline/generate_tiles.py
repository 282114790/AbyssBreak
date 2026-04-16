"""
AbyssBreak Tile Pipeline — Step 1: 生成 Tile 图片
支持两种模式:
  - api:    调用 Google Gemini API (Imagen 3) 自动生成
  - prompt: 仅导出 prompt 列表，手动生成后放入 raw_tiles/

用法:
  python generate_tiles.py --mode api --theme dungeon --category floor
  python generate_tiles.py --mode prompt --theme dungeon
  python generate_tiles.py --mode api --all

前置条件 (API 模式):
  1. pip install google-genai
  2. export GEMINI_API_KEY="你的密钥"
     (获取地址: https://aistudio.google.com/apikey)
"""

import json
import os
import sys
import time
import argparse
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
CONFIG_PATH = SCRIPT_DIR / "tile_config.json"


def load_config() -> dict:
    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def build_prompt(config: dict, category: str, theme: str, variant: dict) -> str:
    """组装完整的 prompt：类别基础 + 变体描述 + 风格锚点 + 后缀"""
    cat_cfg = config["tile_categories"][category]
    theme_cfg = cat_cfg["themes"][theme]
    style = config["style_anchor"]
    is_prop = cat_cfg.get("prop_style", False)

    parts = [
        theme_cfg["prompt_base"],
        variant["prompt"],
        style["description"],
    ]

    if is_prop:
        parts.append("centered composition, viewed from directly above")
    else:
        size = cat_cfg["source_size"]
        parts.append("square format" if size[0] == size[1] else "rectangular format")
        parts.append("simple composition, single tile, centered")

    suffix = style["prop_suffix"] if is_prop else style["tile_suffix"]
    if cat_cfg.get("has_alpha"):
        suffix += style.get("alpha_suffix", "")
    if cat_cfg.get("seamless"):
        suffix += style.get("seamless_suffix", "")

    full = ", ".join(parts) + suffix
    return full.replace(", ,", ",").replace(",,", ",")


def generate_all_prompts(config: dict, theme: str = None, category: str = None) -> list:
    """生成所有需要的 prompt 列表"""
    tasks = []
    categories = [category] if category else config["tile_categories"].keys()

    for cat_name in categories:
        cat_cfg = config["tile_categories"][cat_name]
        themes = [theme] if theme else cat_cfg["themes"].keys()

        for th in themes:
            if th not in cat_cfg["themes"]:
                continue
            theme_cfg = cat_cfg["themes"][th]

            idx = 0
            for variant in theme_cfg["variants"]:
                for i in range(variant["count"]):
                    prompt = build_prompt(config, cat_name, th, variant)

                    filename = f"{cat_name}_{th}_{variant['name']}_{i:02d}.png"
                    tasks.append({
                        "prompt": prompt,
                        "filename": filename,
                        "category": cat_name,
                        "theme": th,
                        "variant": variant["name"],
                        "index": idx,
                    })
                    idx += 1

    return tasks


def export_prompts(tasks: list, output_path: Path):
    """导出 prompt 列表为可读文件（手动模式）"""
    output_path.mkdir(parents=True, exist_ok=True)

    by_category = {}
    for t in tasks:
        key = f"{t['category']}_{t['theme']}"
        by_category.setdefault(key, []).append(t)

    for key, items in by_category.items():
        filepath = output_path / f"prompts_{key}.txt"
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(f"# AbyssBreak Tile Prompts — {key}\n")
            f.write(f"# 共 {len(items)} 张图需要生成\n")
            f.write(f"# 手动生成后，按文件名放入 raw_tiles/{key}/ 目录\n")
            f.write(f"# 建议设置: 正方形(1:1), 1024x1024, 最高画质\n\n")

            for item in items:
                f.write(f"--- [{item['filename']}] ---\n")
                f.write(f"{item['prompt']}\n\n")

        print(f"  已导出: {filepath} ({len(items)} prompts)")

    summary_path = output_path / "prompts_summary.json"
    with open(summary_path, "w", encoding="utf-8") as f:
        json.dump(tasks, f, ensure_ascii=False, indent=2)
    print(f"  摘要文件: {summary_path}")


# ── Google Gemini API (Imagen 3) ────────────────────────────

def _init_gemini_client(config: dict):
    """初始化 Google Gemini 客户端"""
    try:
        from google import genai
        return genai
    except ImportError:
        print("  错误: 请安装 google-genai: pip install google-genai")
        return None


def call_gemini_api(config: dict, prompt: str, filename: str, output_dir: Path) -> bool:
    """调用 Google Gemini Imagen 3 生成单张图片"""
    genai = _init_gemini_client(config)
    if genai is None:
        return False

    api_cfg = config["image_api"]
    api_key = os.environ.get(api_cfg["api_key_env"])
    if not api_key:
        print(f"  错误: 请设置环境变量 {api_cfg['api_key_env']}")
        print(f"  获取地址: https://aistudio.google.com/apikey")
        return False

    from google.genai import types
    client = genai.Client(api_key=api_key)

    try:
        response = client.models.generate_images(
            model=api_cfg["model"],
            prompt=prompt,
            config=types.GenerateImagesConfig(
                number_of_images=1,
                aspect_ratio=api_cfg.get("aspect_ratio", "1:1"),
                output_mime_type="image/png",
            )
        )

        if not response.generated_images:
            print(f"  警告: API 未返回图片 — {filename}")
            return False

        output_dir.mkdir(parents=True, exist_ok=True)
        filepath = output_dir / filename
        response.generated_images[0].image.save(filepath)

        print(f"  已生成: {filename}")
        return True

    except Exception as e:
        print(f"  API 错误 [{filename}]: {e}")
        return False


def generate_via_api(config: dict, tasks: list, raw_dir: Path):
    """通过 Gemini API 批量生成"""
    total = len(tasks)
    success = 0
    skip = 0
    fail = 0

    api_cfg = config["image_api"]
    est_cost = total * 0.03
    print(f"  模型: {api_cfg['model']}")
    print(f"  预估费用: ${est_cost:.2f} ({total} 张 × $0.03)")
    print()

    for i, task in enumerate(tasks):
        cat_theme_dir = raw_dir / f"{task['category']}_{task['theme']}"
        filepath = cat_theme_dir / task["filename"]

        if filepath.exists():
            print(f"  [{i+1}/{total}] 跳过(已存在): {task['filename']}")
            skip += 1
            continue

        print(f"  [{i+1}/{total}] 生成中: {task['filename']}")
        ok = call_gemini_api(config, task["prompt"], task["filename"], cat_theme_dir)
        if ok:
            success += 1
        else:
            fail += 1

        if i < total - 1:
            time.sleep(1.0)

    actual_cost = success * 0.03
    print(f"\n完成: 成功={success}, 跳过={skip}, 失败={fail}, 总计={total}")
    print(f"实际费用: ~${actual_cost:.2f}")


def main():
    parser = argparse.ArgumentParser(description="AbyssBreak Tile Generator")
    parser.add_argument("--mode", choices=["api", "prompt"], default="prompt",
                        help="api=调用Gemini API自动生成, prompt=仅导出prompt列表")
    parser.add_argument("--theme", type=str, default=None,
                        help="指定主题: dungeon/ice/lava (不指定=全部)")
    parser.add_argument("--category", type=str, default=None,
                        help="指定类别: floor/detail_overlay/deco_props/wall_pieces/large_deco")
    parser.add_argument("--all", action="store_true",
                        help="生成所有主题和类别")
    args = parser.parse_args()

    config = load_config()
    raw_dir = SCRIPT_DIR / config["raw_dir"]

    print("=" * 60)
    print("AbyssBreak Tile Pipeline — 图片生成")
    print("=" * 60)

    tasks = generate_all_prompts(config, theme=args.theme, category=args.category)
    print(f"共 {len(tasks)} 张图片待生成\n")

    if not tasks:
        print("没有匹配的任务，请检查 --theme 和 --category 参数")
        return

    if args.mode == "prompt":
        prompt_dir = SCRIPT_DIR / "prompt_export"
        export_prompts(tasks, prompt_dir)
        print(f"\nPrompt 文件已导出到 {prompt_dir}")
        print("手动生成后放入对应的 raw_tiles/ 子目录")
        print("然后运行: python process_tiles.py")
    else:
        generate_via_api(config, tasks, raw_dir)
        print("\n下一步: python process_tiles.py")


if __name__ == "__main__":
    main()
