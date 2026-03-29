"""
Abyss Break - Mage Sprite Generator (参考 AI 生成图重写)
风格特征：
- 深蓝色长袍，金色/棕色镶边
- 白色长胡须
- 蓝色尖顶帽，帽上有装饰
- 棕色鞋子
- 发蓝光的魔法杖
- 每帧 48x48，透明背景，正面朝下视角
"""
from PIL import Image, ImageDraw
import math, os

OUT = r"D:\AbyssBreak\assets\sprites\player"
os.makedirs(OUT, exist_ok=True)

# ── 颜色方案（从参考图提取）──────────────────────────────
ROBE_DEEP    = (25,  45, 110, 255)   # 深蓝袍主色
ROBE_MID     = (40,  65, 150, 255)   # 袍中间色
ROBE_LIGHT   = (70, 100, 180, 255)   # 袍高光
ROBE_TRIM    = (160, 120, 40, 255)   # 金色镶边
ROBE_TRIM2   = (120,  85, 25, 255)   # 深金镶边
HAT_MAIN     = (30,  55, 130, 255)   # 帽子主色
HAT_BRIM     = (20,  40,  95, 255)   # 帽沿
HAT_DECO     = (180, 160, 80, 255)   # 帽子装饰（星形/月形）
SKIN         = (235, 195, 155, 255)  # 皮肤
BEARD        = (240, 240, 235, 255)  # 白胡须
BEARD_SHADOW = (190, 190, 185, 255)  # 胡须阴影
SHOE         = (100,  60,  20, 255)  # 棕色鞋
SHOE_SOLE    = ( 70,  40,  10, 255)  # 鞋底
STAFF_WOOD   = (120,  75,  25, 255)  # 法杖木色
STAFF_DARK   = ( 80,  45,  10, 255)  # 杖阴影
ORB_CORE     = (140, 210, 255, 255)  # 魔法球核心
ORB_GLOW1    = (100, 170, 255, 180)  # 魔法球光晕1
ORB_GLOW2    = ( 60, 130, 255,  90)  # 魔法球光晕2
EYE_COLOR    = ( 40,  30,  80, 255)  # 眼睛
OUTLINE      = ( 15,  15,  35, 255)  # 外轮廓

def pixel(d, x, y, color):
    """画单像素"""
    d.rectangle([x, y, x, y], fill=color)

def hline(d, x1, x2, y, color):
    d.rectangle([x1, y, x2, y], fill=color)

def vline(d, x, y1, y2, color):
    d.rectangle([x, y1, x, y2], fill=color)

def draw_mage_frame(bob=0, left_foot=0, right_foot=0, staff_sway=0, orb_pulse=0):
    """
    bob: 身体上下偏移 (-2~0)
    left_foot, right_foot: 脚的前后位移 (-3~3)
    staff_sway: 法杖左右摆动 (-2~2)
    orb_pulse: 魔法球大小脉冲 (0~2)
    """
    f = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(f)

    # 基准点（脚底中心）
    fx = 24
    fy = 41 + bob  # 脚底Y

    # ── 1. 鞋子 ──────────────────────────────────────────
    # 左脚
    lx = fx - 4 + left_foot
    ly = fy
    d.rectangle([lx-3, ly-2, lx+2, ly], fill=SHOE)
    d.rectangle([lx-3, ly,   lx+2, ly], fill=SHOE_SOLE)
    d.rectangle([lx-3, ly-2, lx-3, ly], fill=OUTLINE)
    d.rectangle([lx+2, ly-2, lx+2, ly], fill=OUTLINE)
    d.rectangle([lx-3, ly,   lx+2, ly], fill=OUTLINE)

    # 右脚
    rx = fx + 4 + right_foot
    ry = fy
    d.rectangle([rx-2, ry-2, rx+3, ry], fill=SHOE)
    d.rectangle([rx-2, ry,   rx+3, ry], fill=SHOE_SOLE)
    d.rectangle([rx-2, ry-2, rx-2, ry], fill=OUTLINE)
    d.rectangle([rx+3, ry-2, rx+3, ry], fill=OUTLINE)
    d.rectangle([rx-2, ry,   rx+3, ry], fill=OUTLINE)

    # ── 2. 长袍下摆 ──────────────────────────────────────
    robe_bot = fy - 2
    robe_top = fy - 18
    cx = fx

    # 袍下摆（梯形，带褶皱感）
    d.polygon([
        cx-8, robe_bot,
        cx+8, robe_bot,
        cx+6, robe_top+6,
        cx-6, robe_top+6
    ], fill=ROBE_MID)
    # 袍身主体
    d.rectangle([cx-6, robe_top, cx+6, robe_bot-2], fill=ROBE_DEEP)
    # 高光（左侧一条）
    vline(d, cx-5, robe_top+2, robe_bot-4, ROBE_LIGHT)
    # 金边镶边（底部）
    hline(d, cx-8, cx+8, robe_bot,   ROBE_TRIM)
    hline(d, cx-7, cx+7, robe_bot-1, ROBE_TRIM2)
    # 袍中线装饰
    vline(d, cx, robe_top+2, robe_bot-3, ROBE_TRIM2)
    # 袍轮廓
    d.rectangle([cx-8, robe_top, cx+8, robe_bot], outline=OUTLINE, width=1)

    # ── 3. 袖子 + 手 ─────────────────────────────────────
    sleeve_y = robe_top + 5
    # 左袖
    d.rectangle([cx-12, sleeve_y, cx-6, sleeve_y+7], fill=ROBE_MID)
    hline(d, cx-12, cx-6, sleeve_y+7, ROBE_TRIM)
    d.rectangle([cx-12, sleeve_y, cx-6, sleeve_y+7], outline=OUTLINE, width=1)
    # 左手（小点皮肤色）
    d.rectangle([cx-13, sleeve_y+6, cx-10, sleeve_y+9], fill=SKIN)
    d.rectangle([cx-13, sleeve_y+6, cx-10, sleeve_y+9], outline=OUTLINE, width=1)

    # 右袖（持杖侧）
    d.rectangle([cx+6, sleeve_y, cx+12, sleeve_y+7], fill=ROBE_MID)
    hline(d, cx+6, cx+12, sleeve_y+7, ROBE_TRIM)
    d.rectangle([cx+6, sleeve_y, cx+12, sleeve_y+7], outline=OUTLINE, width=1)
    # 右手
    d.rectangle([cx+10, sleeve_y+6, cx+13, sleeve_y+9], fill=SKIN)
    d.rectangle([cx+10, sleeve_y+6, cx+13, sleeve_y+9], outline=OUTLINE, width=1)

    # ── 4. 法杖 ──────────────────────────────────────────
    staff_x = cx + 13 + staff_sway
    staff_y_bot = sleeve_y + 8
    staff_y_top = robe_top - 12

    # 杖身
    d.line([staff_x, staff_y_bot, staff_x + staff_sway, staff_y_top],
           fill=STAFF_WOOD, width=3)
    d.line([staff_x+1, staff_y_bot, staff_x+1+staff_sway, staff_y_top],
           fill=STAFF_DARK, width=1)

    # 魔法球光晕（多层）
    orb_x = staff_x + staff_sway
    orb_y = staff_y_top - 1
    r_outer = 5 + orb_pulse
    r_mid   = 4 + orb_pulse
    r_inner = 3

    d.ellipse([orb_x-r_outer-2, orb_y-r_outer-2,
               orb_x+r_outer+2, orb_y+r_outer+2], fill=ORB_GLOW2)
    d.ellipse([orb_x-r_outer, orb_y-r_outer,
               orb_x+r_outer, orb_y+r_outer], fill=ORB_GLOW1)
    d.ellipse([orb_x-r_mid, orb_y-r_mid,
               orb_x+r_mid, orb_y+r_mid], fill=ORB_CORE)
    # 高光点
    pixel(d, orb_x-1, orb_y-r_inner+1, (220, 240, 255, 255))
    pixel(d, orb_x,   orb_y-r_inner+1, (220, 240, 255, 255))

    # ── 5. 身体上半（长袍上身）────────────────────────────
    torso_top = robe_top - 2
    torso_bot = robe_top + 5
    d.rectangle([cx-5, torso_top, cx+5, torso_bot], fill=ROBE_DEEP)
    d.rectangle([cx-5, torso_top, cx+5, torso_bot], outline=OUTLINE, width=1)

    # ── 6. 胡须 ──────────────────────────────────────────
    beard_top = torso_top - 5
    beard_bot = torso_top + 3
    # 胡须主体（白色流线型）
    d.ellipse([cx-4, beard_top, cx+4, beard_bot+4], fill=BEARD)
    # 胡须分叉下摆
    d.polygon([cx-4, beard_bot,
               cx-6, beard_bot+5,
               cx-2, beard_bot+3,
               cx,   beard_bot+6,
               cx+2, beard_bot+3,
               cx+6, beard_bot+5,
               cx+4, beard_bot], fill=BEARD)
    # 胡须阴影
    vline(d, cx, beard_top+1, beard_bot+2, BEARD_SHADOW)
    hline(d, cx-3, cx+3, beard_bot+1, BEARD_SHADOW)

    # ── 7. 头部（脸）─────────────────────────────────────
    head_cx = cx
    head_cy = torso_top - 7
    # 脸
    d.ellipse([head_cx-5, head_cy-5,
               head_cx+5, head_cy+5], fill=SKIN)
    d.ellipse([head_cx-5, head_cy-5,
               head_cx+5, head_cy+5], outline=OUTLINE, width=1)
    # 眼睛（正面朝下，两个小点）
    pixel(d, head_cx-2, head_cy, EYE_COLOR)
    pixel(d, head_cx+2, head_cy, EYE_COLOR)
    # 眉毛
    hline(d, head_cx-3, head_cx-1, head_cy-2, BEARD_SHADOW)
    hline(d, head_cx+1, head_cx+3, head_cy-2, BEARD_SHADOW)

    # ── 8. 帽子 ──────────────────────────────────────────
    hat_brim_y = head_cy - 4
    # 帽沿
    d.rectangle([head_cx-7, hat_brim_y,
                 head_cx+7, hat_brim_y+2], fill=HAT_BRIM)
    d.rectangle([head_cx-7, hat_brim_y,
                 head_cx+7, hat_brim_y+2], outline=OUTLINE, width=1)
    # 帽身（三角形尖顶）
    hat_tip_y = hat_brim_y - 14
    d.polygon([head_cx, hat_tip_y,
               head_cx-5, hat_brim_y,
               head_cx+5, hat_brim_y], fill=HAT_MAIN)
    d.polygon([head_cx, hat_tip_y,
               head_cx-5, hat_brim_y,
               head_cx+5, hat_brim_y], outline=OUTLINE, width=1)
    # 帽身高光
    d.line([head_cx-1, hat_tip_y+2,
            head_cx-3, hat_brim_y-1], fill=ROBE_LIGHT, width=1)
    # 帽子装饰（月亮形）
    pixel(d, head_cx+1, hat_brim_y-5, HAT_DECO)
    pixel(d, head_cx+2, hat_brim_y-6, HAT_DECO)
    pixel(d, head_cx+3, hat_brim_y-5, HAT_DECO)
    pixel(d, head_cx+2, hat_brim_y-4, HAT_DECO)

    # ── 9. 阴影（地面）───────────────────────────────────
    shadow = Image.new("RGBA", (48, 48), (0,0,0,0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse([cx-8, 43, cx+8, 46], fill=(0, 0, 30, 60))
    f = Image.alpha_composite(shadow, f)

    return f


def make_sheet(frames):
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), (0,0,0,0))
    for i, fr in enumerate(frames):
        sheet.paste(fr, (i * w, 0))
    return sheet


# ── 动画数据 ────────────────────────────────────────────
# 行走8帧：左右脚交替前后摆，身体上下bob，法杖随步伐摆动
WALK_FRAMES = [
    # (bob, left_foot, right_foot, staff_sway, orb_pulse)
    ( 0,  0,  0,  0, 1),   # 1 站立
    (-1,  2, -1,  1, 0),   # 2 左脚前
    (-1,  3, -2,  1, 0),   # 3 左脚前进
    ( 0,  1, -1,  0, 1),   # 4 换步
    ( 0, -1,  2, -1, 0),   # 5 右脚前
    (-1, -2,  3, -1, 0),   # 6 右脚前进
    (-1, -1,  1,  0, 1),   # 7 换步过渡
    ( 0,  0,  0,  0, 2),   # 8 回到站立
]

# 待机4帧：轻微呼吸感 + 魔法球脉冲
IDLE_FRAMES = [
    ( 0, 0, 0,  0, 0),
    (-1, 0, 0,  1, 1),
    (-1, 0, 0,  1, 2),
    ( 0, 0, 0,  0, 1),
]

# 施法6帧：身体前倾，法杖前伸，魔法球爆发
CAST_FRAMES = [
    ( 0,  0,  0,  0, 1),   # 蓄力
    (-1,  1,  1,  2, 2),   # 前倾
    (-2,  2,  2,  3, 3),   # 前倾最大
    (-2,  2,  2,  4, 3),   # 释放
    (-1,  1,  1,  2, 2),   # 后摇
    ( 0,  0,  0,  0, 1),   # 恢复
]

# 受伤3帧：往后仰
HURT_FRAMES = [
    ( 0, -1, -1, -1, 0),
    (-2, -2, -2, -2, 0),
    ( 0,  0,  0,  0, 1),
]

print("Generating refined mage sprites...")

walk_frames = [draw_mage_frame(*p) for p in WALK_FRAMES]
idle_frames = [draw_mage_frame(*p) for p in IDLE_FRAMES]
cast_frames = [draw_mage_frame(*p) for p in CAST_FRAMES]
hurt_frames = [draw_mage_frame(*p) for p in HURT_FRAMES]

make_sheet(walk_frames).save(f"{OUT}/mage_walk.png")
make_sheet(idle_frames).save(f"{OUT}/mage_idle.png")
make_sheet(cast_frames).save(f"{OUT}/mage_cast.png")
make_sheet(hurt_frames).save(f"{OUT}/mage_hurt.png")

# 同时覆盖旧的主目录 sprites
make_sheet(walk_frames).save(r"D:\AbyssBreak\assets\sprites\mage_walk.png")
make_sheet(idle_frames).save(r"D:\AbyssBreak\assets\sprites\mage_idle.png")
make_sheet(cast_frames).save(r"D:\AbyssBreak\assets\sprites\mage_attack.png")
make_sheet(hurt_frames).save(r"D:\AbyssBreak\assets\sprites\mage_hurt.png")

print(f"walk:  {make_sheet(walk_frames).size}")
print(f"idle:  {make_sheet(idle_frames).size}")
print(f"cast:  {make_sheet(cast_frames).size}")
print(f"hurt:  {make_sheet(hurt_frames).size}")
print("Done!")
