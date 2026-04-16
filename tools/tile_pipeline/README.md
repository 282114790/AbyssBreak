# AbyssBreak Tile Pipeline

自动化地图素材生成流水线：AI 生成 → 后处理 → Spritesheet 打包 → Godot 导入

## 依赖

```bash
pip install Pillow requests
```

## 快速开始

```bash
cd tools/tile_pipeline

# 方式1: 交互式主控台
python run_pipeline.py

# 方式2: 命令行直接执行
python run_pipeline.py --step prompts               # 导出 prompt 文件
python run_pipeline.py --step process               # 后处理 + 打包
python run_pipeline.py --step api --theme dungeon    # API 自动生成
```

## 完整工作流

### 手动模式（推荐入门）

```
1. python generate_tiles.py --mode prompt --theme dungeon
   → 导出 prompt 文件到 prompt_export/

2. 在 Nano Banana 网页端逐个生成图片
   → 下载后按文件名放入 raw_tiles/floor_dungeon/ 等目录

3. python process_tiles.py --theme dungeon
   → 自动: 缩放 + 清理背景 + 色调统一 + 无缝检查 + 打包 spritesheet

4. python update_godot_imports.py
   → 生成 .import 配置文件

5. python preview_tiles.py --theme dungeon
   → 生成预览图到 previews/ 目录检查效果
```

### API 自动模式

```bash
export NANO_BANANA_API_KEY="your-key-here"
python generate_tiles.py --mode api --theme dungeon --category floor
python process_tiles.py
python update_godot_imports.py
```

## 目录结构

```
tile_pipeline/
├── tile_config.json          # 所有 tile 的规格、prompt 模板、色板定义
├── run_pipeline.py           # 一键主控脚本
├── generate_tiles.py         # Step 1: 生成 prompt / 调用 API
├── process_tiles.py          # Step 2: 后处理 + Spritesheet 打包
├── update_godot_imports.py   # Step 3: Godot 导入配置
├── preview_tiles.py          # 预览工具
├── prompt_export/            # 导出的 prompt 文件
├── raw_tiles/                # AI 生成的原始图片
│   ├── floor_dungeon/
│   ├── floor_ice/
│   └── ...
├── processed_tiles/          # 后处理后的单张 tile
└── previews/                 # 预览图
```

## Tile 规格

| 类别 | 源尺寸 | 显示尺寸 | Sheet 布局 | 用途 |
|------|--------|---------|-----------|------|
| floor | 128×128 | 64×64 | 8×4=32 | 地板基底 |
| detail_overlay | 128×128 | 64×64 | 6×3=18 | 裂纹/苔藓叠层 |
| deco_props | 128×128 | 64×64 | 8×4=32 | 小型装饰物 |
| wall_pieces | 128×256 | 64×128 | 8×2=16 | 墙壁片段 |
| large_deco | 256×256 | 128×128 | 4×3=12 | 大型装饰 |

## 自定义

编辑 `tile_config.json` 可以:
- 添加新的 tile 类别
- 修改 prompt 模板
- 调整色板
- 更改尺寸规格
- 添加新主题 (如 "forest", "desert")
