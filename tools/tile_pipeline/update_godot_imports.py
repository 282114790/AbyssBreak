"""
AbyssBreak Tile Pipeline — Step 3: Godot 导入配置
为生成的 spritesheet 自动创建 .import 文件，确保:
  - Texture Filter = Nearest
  - Compress Mode = Lossless
  - Mipmaps = Off

用法:
  python update_godot_imports.py
"""

import json
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
CONFIG_PATH = SCRIPT_DIR / "tile_config.json"

IMPORT_TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://{uid}"
path="res://.godot/imported/{filename}-{hash}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="res://assets/tilesets/{filename}"
dest_files=["res://.godot/imported/{filename}-{hash}.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal_path=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""


def generate_uid_hash(name: str) -> str:
    """生成简单的 UID（Godot 格式）"""
    import hashlib
    h = hashlib.md5(name.encode()).hexdigest()[:12]
    return h


def main():
    config = load_config()
    tileset_dir = (SCRIPT_DIR / config["output_dir"]).resolve()
    manifest_path = tileset_dir / "tile_manifest.json"

    if not manifest_path.exists():
        print("错误: tile_manifest.json 不存在，请先运行 process_tiles.py")
        return

    with open(manifest_path, "r", encoding="utf-8") as f:
        manifests = json.load(f)

    print("=" * 60)
    print("AbyssBreak Tile Pipeline — Godot 导入配置")
    print("=" * 60)

    for m in manifests:
        filename = m["sheet_file"]
        filepath = tileset_dir / filename
        if not filepath.exists():
            print(f"  跳过: {filename} 不存在")
            continue

        uid = generate_uid_hash(filename)
        file_hash = generate_uid_hash(filepath.name + str(filepath.stat().st_size))

        import_content = IMPORT_TEMPLATE.format(
            uid=uid,
            filename=filename,
            hash=file_hash,
        )

        import_path = filepath.with_suffix(filepath.suffix + ".import")
        with open(import_path, "w", encoding="utf-8") as f:
            f.write(import_content.strip())

        print(f"  已生成: {import_path.name}")

    print(f"\n完成! 导入文件已创建在 {tileset_dir}")
    print("请在 Godot 编辑器中刷新 (Project → Reload Current Project)")
    print("或下次打开项目时会自动重新导入")


def load_config() -> dict:
    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


if __name__ == "__main__":
    main()
