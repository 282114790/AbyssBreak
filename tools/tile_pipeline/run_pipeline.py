#!/usr/bin/env python3
"""
AbyssBreak Tile Pipeline — 一键主控脚本

完整流程:
  Step 1: 生成 Prompt / 调用 API 生成原图
  Step 2: 后处理 + 打包 Spritesheet
  Step 3: 生成 Godot 导入配置
  Step 4: 输出验证报告

用法:
  python run_pipeline.py                          # 交互式选择
  python run_pipeline.py --step all               # 全流程（需先有 raw_tiles）
  python run_pipeline.py --step prompts           # 只导出 prompt
  python run_pipeline.py --step process           # 只处理 + 打包
  python run_pipeline.py --step api --theme dungeon --category floor  # API 生成指定内容
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
CONFIG_PATH = SCRIPT_DIR / "tile_config.json"


def load_config() -> dict:
    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def run_step(script: str, extra_args: list = None):
    cmd = [sys.executable, str(SCRIPT_DIR / script)]
    if extra_args:
        cmd.extend(extra_args)
    print(f"\n{'─' * 50}")
    print(f"执行: {' '.join(cmd)}")
    print(f"{'─' * 50}")
    result = subprocess.run(cmd, cwd=str(SCRIPT_DIR))
    return result.returncode == 0


def show_status(config: dict):
    """显示当前流水线状态"""
    print("\n📊 当前状态:")
    print("─" * 50)

    raw_dir = SCRIPT_DIR / config["raw_dir"]
    proc_dir = SCRIPT_DIR / config["processed_dir"]
    output_dir = (SCRIPT_DIR / config["output_dir"]).resolve()

    for cat_name, cat_cfg in config["tile_categories"].items():
        for theme in cat_cfg["themes"]:
            raw_path = raw_dir / f"{cat_name}_{theme}"
            proc_path = proc_dir / f"{cat_name}_{theme}"
            sheet_path = output_dir / f"{cat_name}_{theme}_sheet.png"

            raw_count = len(list(raw_path.glob("*.png"))) if raw_path.exists() else 0
            proc_count = len(list(proc_path.glob("*.png"))) if proc_path.exists() else 0
            has_sheet = sheet_path.exists()
            expected = cat_cfg["themes"][theme]["count"]

            status = "✅" if has_sheet else ("🔄" if raw_count > 0 else "⬜")
            print(f"  {status} {cat_name}/{theme}: "
                  f"原图={raw_count}/{expected}, "
                  f"已处理={proc_count}, "
                  f"Sheet={'有' if has_sheet else '无'}")

    print()


def interactive_menu():
    """交互式菜单"""
    config = load_config()

    while True:
        print("\n" + "=" * 60)
        print("  AbyssBreak Tile Pipeline 主控台")
        print("=" * 60)

        show_status(config)

        print("操作选项:")
        print("  1. 导出全部 Prompt 文件（手动模式）")
        print("  2. API 自动生成（需要 NANO_BANANA_API_KEY）")
        print("  3. 后处理 + 打包 Spritesheet")
        print("  4. 生成 Godot 导入配置")
        print("  5. 执行完整流程 (3+4)")
        print("  6. 仅生成指定主题/类别")
        print("  0. 退出")
        print()

        try:
            choice = input("选择 [0-6]: ").strip()
        except (EOFError, KeyboardInterrupt):
            break

        if choice == "0":
            break
        elif choice == "1":
            run_step("generate_tiles.py", ["--mode", "prompt"])
        elif choice == "2":
            theme = input("主题 (dungeon/ice/lava/回车=全部): ").strip() or None
            category = input("类别 (floor/detail_overlay/deco_props/wall_pieces/large_deco/回车=全部): ").strip() or None
            args = ["--mode", "api"]
            if theme:
                args += ["--theme", theme]
            if category:
                args += ["--category", category]
            run_step("generate_tiles.py", args)
        elif choice == "3":
            run_step("process_tiles.py")
        elif choice == "4":
            run_step("update_godot_imports.py")
        elif choice == "5":
            run_step("process_tiles.py")
            run_step("update_godot_imports.py")
        elif choice == "6":
            theme = input("主题 (dungeon/ice/lava): ").strip()
            category = input("类别 (floor/detail_overlay/deco_props/wall_pieces/large_deco): ").strip()
            if theme and category:
                run_step("process_tiles.py", ["--category", category, "--theme", theme])
            else:
                print("需要指定主题和类别")
        else:
            print("无效选择")


def main():
    parser = argparse.ArgumentParser(description="AbyssBreak Tile Pipeline 主控")
    parser.add_argument("--step", choices=["all", "prompts", "api", "process", "import"],
                        default=None, help="直接执行指定步骤")
    parser.add_argument("--theme", type=str, default=None)
    parser.add_argument("--category", type=str, default=None)
    args = parser.parse_args()

    if args.step is None:
        interactive_menu()
        return

    extra = []
    if args.theme:
        extra += ["--theme", args.theme]
    if args.category:
        extra += ["--category", args.category]

    if args.step == "prompts":
        run_step("generate_tiles.py", ["--mode", "prompt"] + extra)
    elif args.step == "api":
        run_step("generate_tiles.py", ["--mode", "api"] + extra)
    elif args.step == "process":
        run_step("process_tiles.py", extra)
    elif args.step == "import":
        run_step("update_godot_imports.py")
    elif args.step == "all":
        ok = run_step("process_tiles.py", extra)
        if ok:
            run_step("update_godot_imports.py")


if __name__ == "__main__":
    main()
