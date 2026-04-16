#!/usr/bin/env python3
"""
repack_spritesheet.py — 自动检测 spritesheet 中的帧位置，重新等距打包。

用法:
  python3 repack_spritesheet.py <input_dir> [output_dir]
  若不指定 output_dir，则覆盖原文件。

原理:
  1. 按列扫描 alpha 通道，找到「有内容」的列
  2. 将连续有内容的列聚类为一个帧
  3. 取所有帧中最大宽度作为统一帧宽
  4. 用统一帧宽 × 帧数创建新图，将每帧居中放入
  5. 输出帧数、实际帧宽、帧高供 VISUAL_DB 使用
"""
import sys
from pathlib import Path
from PIL import Image
import numpy as np


def find_frames(img: Image.Image, alpha_threshold: int = 10, min_gap: int = 3) -> list[tuple[int, int]]:
    """返回 [(x_start, x_end), ...] 列表，每个元素是一个帧的水平像素范围。"""
    arr = np.array(img)
    if arr.shape[2] < 4:
        return [(0, arr.shape[1])]

    alpha = arr[:, :, 3]
    col_has_content = np.any(alpha > alpha_threshold, axis=0)

    frames = []
    in_frame = False
    start = 0
    gap_count = 0

    for x in range(len(col_has_content)):
        if col_has_content[x]:
            if not in_frame:
                start = x
                in_frame = True
            gap_count = 0
        else:
            if in_frame:
                gap_count += 1
                if gap_count >= min_gap:
                    end = x - gap_count
                    frames.append((start, end))
                    in_frame = False
                    gap_count = 0

    if in_frame:
        end = len(col_has_content) - 1
        while end > start and not col_has_content[end]:
            end -= 1
        frames.append((start, end + 1))

    return frames


def find_content_rows(img: Image.Image, alpha_threshold: int = 10) -> tuple[int, int]:
    """返回 (y_start, y_end) 垂直内容范围。"""
    arr = np.array(img)
    if arr.shape[2] < 4:
        return (0, arr.shape[0])
    alpha = arr[:, :, 3]
    row_has_content = np.any(alpha > alpha_threshold, axis=1)
    rows = np.where(row_has_content)[0]
    if len(rows) == 0:
        return (0, arr.shape[0])
    return (int(rows[0]), int(rows[-1]) + 1)


def repack(src: Path, dst: Path) -> dict:
    """重新打包一张 spritesheet，返回 {frames, fw, fh} 信息。"""
    img = Image.open(src).convert("RGBA")
    w, h = img.size

    frames = find_frames(img)
    if len(frames) < 2:
        print(f"  ⚠ 只检测到 {len(frames)} 帧，跳过")
        if src != dst:
            img.save(dst)
        return {"frames": len(frames), "fw": w, "fh": h}

    y_start, y_end = find_content_rows(img)
    content_h = y_end - y_start
    padding_v = 4
    fh = content_h + padding_v * 2

    frame_widths = [end - start for start, end in frames]
    max_fw = max(frame_widths)
    padding_h = 4
    fw = max_fw + padding_h * 2

    num_frames = len(frames)
    new_w = fw * num_frames
    new_img = Image.new("RGBA", (new_w, fh), (0, 0, 0, 0))

    for i, (x_start, x_end) in enumerate(frames):
        frame_crop = img.crop((x_start, y_start, x_end, y_end))
        frame_w = x_end - x_start
        offset_x = i * fw + (fw - frame_w) // 2
        offset_y = padding_v
        new_img.paste(frame_crop, (offset_x, offset_y))

    new_img.save(dst)
    return {"frames": num_frames, "fw": fw, "fh": fh}


def main():
    if len(sys.argv) < 2:
        print("用法: python3 repack_spritesheet.py <input_dir> [output_dir]")
        sys.exit(1)

    in_dir = Path(sys.argv[1])
    out_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else in_dir

    if not in_dir.exists():
        print(f"目录不存在: {in_dir}")
        sys.exit(1)
    out_dir.mkdir(parents=True, exist_ok=True)

    pngs = sorted(in_dir.glob("*_walk_sheet.png"))
    if not pngs:
        pngs = sorted(in_dir.glob("*.png"))

    print(f"输入: {in_dir}  ({len(pngs)} 张)")
    print(f"输出: {out_dir}\n")

    results = {}
    for i, png in enumerate(pngs):
        print(f"[{i+1}/{len(pngs)}] {png.name}", end="  ")
        old_dims = f"{Image.open(png).size[0]}x{Image.open(png).size[1]}"
        info = repack(png, out_dir / png.name)
        print(f"{old_dims} → {info['frames']}帧 {info['fw']}x{info['fh']}")
        results[png.name] = info

    print(f"\n完成: {len(results)} 张")
    print("\n── VISUAL_DB 参考 ──")
    for name, info in results.items():
        print(f'  "fw": {info["fw"]}, "fh": {info["fh"]}, "frames": {info["frames"]}  # {name}')


if __name__ == "__main__":
    main()
