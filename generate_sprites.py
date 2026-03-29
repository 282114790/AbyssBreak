"""
Abyss Break - Sprite Sheet Generator
生成主角、怪物、特效的动画精灵表 (spritesheet)
每个角色 48x48 像素，包含完整动画帧
"""
from PIL import Image, ImageDraw
import math
import os

OUT = r"D:\AbyssBreak\assets\sprites"
os.makedirs(OUT, exist_ok=True)

# ── 工具函数 ─────────────────────────────────────────────
def new_frame(size=48, bg=(0,0,0,0)):
    return Image.new("RGBA", (size, size), bg)

def make_sheet(frames, cols=None):
    """把帧列表拼成横向 spritesheet"""
    if cols is None:
        cols = len(frames)
    rows = math.ceil(len(frames) / cols)
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * cols, h * rows), (0,0,0,0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i % cols * w, i // cols * h))
    return sheet

def lerp(a, b, t):
    return int(a + (b - a) * t)

def lerp_color(c1, c2, t):
    return tuple(lerp(a, b, t) for a, b in zip(c1, c2))

# ══════════════════════════════════════════════════════════
# 1. 主角 — 蓝袍法师 (Mage) 48x48
#    walk: 8帧 (4方向各2帧) → 横向拼 8帧
#    attack: 6帧
#    hurt: 3帧  idle: 4帧
# ══════════════════════════════════════════════════════════
MAGE_ROBE    = (60, 80, 200, 255)
MAGE_ROBE2   = (40, 55, 160, 255)
MAGE_SKIN    = (255, 210, 170, 255)
MAGE_HAIR    = (80, 50, 20, 255)
MAGE_STAFF   = (139, 90, 43, 255)
MAGE_ORB     = (100, 200, 255, 255)
MAGE_EYE     = (20, 20, 80, 255)
MAGE_SHADOW  = (0, 0, 60, 120)

def draw_mage_base(d, frame=0, facing="down", bob=0):
    """画法师身体，facing: down/up/left/right"""
    cx, cy = 24, 30
    # 阴影
    d.ellipse([cx-10, cy+12+bob, cx+10, cy+16+bob], fill=MAGE_SHADOW)
    # 长袍底部（渐变感用多个椭圆）
    for i in range(6):
        col = lerp_color(MAGE_ROBE, MAGE_ROBE2, i/6)
        d.ellipse([cx-10+i//2, cy+8+bob+i, cx+10-i//2, cy+14+bob+i], fill=col)
    # 袍身
    d.rounded_rectangle([cx-9, cy-4+bob, cx+9, cy+10+bob], radius=4, fill=MAGE_ROBE)
    # 袖子（左右）
    if facing in ("down","up"):
        d.rounded_rectangle([cx-14, cy-2+bob, cx-8, cy+6+bob], radius=3, fill=MAGE_ROBE2)
        d.rounded_rectangle([cx+8, cy-2+bob, cx+14, cy+6+bob], radius=3, fill=MAGE_ROBE2)
    # 头部
    d.ellipse([cx-7, cy-16+bob, cx+7, cy-2+bob], fill=MAGE_SKIN)
    # 帽子
    hat_y = cy-16+bob
    d.polygon([cx, hat_y-14, cx-7, hat_y+2, cx+7, hat_y+2], fill=MAGE_ROBE2)
    d.rectangle([cx-8, hat_y, cx+8, hat_y+4], fill=MAGE_ROBE)
    # 眼睛（朝向决定）
    if facing == "down":
        d.ellipse([cx-4, cy-11+bob, cx-1, cy-8+bob], fill=MAGE_EYE)
        d.ellipse([cx+1, cy-11+bob, cx+4, cy-8+bob], fill=MAGE_EYE)
    elif facing == "up":
        pass  # 背面，不画眼睛
    else:
        eye_x = cx+4 if facing=="right" else cx-4
        d.ellipse([eye_x-2, cy-11+bob, eye_x+2, cy-8+bob], fill=MAGE_EYE)

def draw_staff(d, frame=0, facing="down", bob=0, swing=0):
    cx, cy = 24, 30
    # 法杖
    sx = cx + 11 + swing
    d.line([sx, cy+6+bob, sx+2, cy-14+bob], fill=MAGE_STAFF, width=3)
    # 魔法球
    glow = abs(math.sin(frame * 0.5)) * 0.5 + 0.5
    orb_r = int(4 + glow * 2)
    orb_col = (int(100+glow*100), int(200+glow*50), 255, 220)
    d.ellipse([sx-orb_r+2, cy-14+bob-orb_r, sx+orb_r+2, cy-14+bob+orb_r], fill=orb_col)

def mage_idle():
    frames = []
    for i in range(4):
        f = new_frame(48)
        d = ImageDraw.Draw(f)
        bob = int(math.sin(i * math.pi / 2) * 1.5)
        draw_mage_base(d, i, "down", bob)
        draw_staff(d, i, "down", bob)
        frames.append(f)
    return frames

def mage_walk():
    """8帧行走 (左右脚交替)"""
    frames = []
    for i in range(8):
        f = new_frame(48)
        d = ImageDraw.Draw(f)
        bob = int(abs(math.sin(i * math.pi / 4)) * -2)
        # 脚部摆动
        step = math.sin(i * math.pi / 4)
        draw_mage_base(d, i, "down", bob)
        # 脚
        d.ellipse([24+int(step*5)-3, 38+bob, 24+int(step*5)+3, 43+bob], fill=MAGE_ROBE2)
        d.ellipse([24-int(step*5)-3, 38+bob, 24-int(step*5)+3, 43+bob], fill=MAGE_ROBE2)
        draw_staff(d, i, "down", bob, swing=int(step*2))
        frames.append(f)
    return frames

def mage_attack():
    """6帧施法动画"""
    frames = []
    for i in range(6):
        f = new_frame(48)
        d = ImageDraw.Draw(f)
        t = i / 5.0
        # 前摇：身体前倾 → 后仰
        if i < 3:
            lean = i * 2
            arm_ext = i * 4
        else:
            lean = (5 - i) * 1
            arm_ext = (5 - i) * 3
        draw_mage_base(d, i, "down", -lean)
        # 伸出的手和法球
        ball_x = 24 + 12 + arm_ext
        ball_y = 20 - lean
        glow_r = 5 + arm_ext // 2
        # 光晕外层
        for r in range(glow_r, 0, -1):
            alpha = int(80 * r / glow_r)
            d.ellipse([ball_x-r, ball_y-r, ball_x+r, ball_y+r],
                      fill=(100, 200, 255, alpha))
        d.ellipse([ball_x-5, ball_y-5, ball_x+5, ball_y+5], fill=MAGE_ORB)
        draw_staff(d, i, "down", -lean, swing=arm_ext//2)
        frames.append(f)
    return frames

def mage_hurt():
    """3帧受伤闪烁"""
    frames = []
    colors = [
        (255, 100, 100, 255),  # 红色
        (255, 200, 200, 255),  # 亮白
        MAGE_ROBE,              # 恢复
    ]
    for i in range(3):
        f = new_frame(48)
        d = ImageDraw.Draw(f)
        draw_mage_base(d, i, "down", i * -2)
        draw_staff(d, i, "down", i * -2)
        # 闪红
        flash = Image.new("RGBA", (48, 48), (255, 0, 0, 0))
        fd = ImageDraw.Draw(flash)
        fd.ellipse([14, 10, 34, 32], fill=(255, 50, 50, [100, 150, 0][i]))
        f = Image.alpha_composite(f, flash)
        frames.append(f)
    return frames

# ══════════════════════════════════════════════════════════
# 2. 怪物 — 恶魔 (Demon) 48x48
#    walk: 6帧  attack: 5帧  hurt: 2帧  death: 5帧
# ══════════════════════════════════════════════════════════
DEMON_BODY   = (160, 30, 30, 255)
DEMON_DARK   = (100, 10, 10, 255)
DEMON_HORN   = (60, 20, 5, 255)
DEMON_EYE    = (255, 200, 0, 255)
DEMON_WING   = (80, 15, 15, 200)
DEMON_CLAW   = (200, 50, 10, 255)

def draw_demon(d, frame=0, bob=0, wing_flap=0, attack_arm=0):
    cx, cy = 24, 28
    # 翅膀（在身后）
    wf = wing_flap
    # 左翼
    d.polygon([cx-8, cy-4+bob,
               cx-22, cy-14+bob+wf,
               cx-18, cy+2+bob], fill=DEMON_WING)
    # 右翼
    d.polygon([cx+8, cy-4+bob,
               cx+22, cy-14+bob+wf,
               cx+18, cy+2+bob], fill=DEMON_WING)
    # 阴影
    d.ellipse([cx-9, cy+12+bob, cx+9, cy+16+bob], fill=(0,0,0,80))
    # 躯干
    d.rounded_rectangle([cx-9, cy-6+bob, cx+9, cy+10+bob], radius=5, fill=DEMON_BODY)
    # 腿
    leg = int(math.sin(frame * 1.0) * 3)
    d.rounded_rectangle([cx-7, cy+8+bob, cx-2, cy+16+bob+leg], radius=3, fill=DEMON_DARK)
    d.rounded_rectangle([cx+2, cy+8+bob, cx+7, cy+16+bob-leg], radius=3, fill=DEMON_DARK)
    # 手臂
    arm_y = cy + attack_arm
    d.rounded_rectangle([cx-14, cy-4+bob, cx-8, cy+4+bob], radius=3, fill=DEMON_BODY)
    d.rounded_rectangle([cx+8, cy-4+bob+attack_arm, cx+14, cy+4+bob+attack_arm], radius=3, fill=DEMON_BODY)
    # 爪子
    d.polygon([cx-14, cy+4+bob,
               cx-18, cy+2+bob,
               cx-16, cy+7+bob,
               cx-12, cy+5+bob], fill=DEMON_CLAW)
    d.polygon([cx+14, cy+4+bob+attack_arm,
               cx+18, cy+2+bob+attack_arm,
               cx+16, cy+7+bob+attack_arm,
               cx+12, cy+5+bob+attack_arm], fill=DEMON_CLAW)
    # 头部
    d.ellipse([cx-8, cy-18+bob, cx+8, cy-4+bob], fill=DEMON_BODY)
    # 角
    d.polygon([cx-6, cy-16+bob, cx-10, cy-26+bob, cx-2, cy-14+bob], fill=DEMON_HORN)
    d.polygon([cx+6, cy-16+bob, cx+10, cy-26+bob, cx+2, cy-14+bob], fill=DEMON_HORN)
    # 眼睛（发光）
    glow = abs(math.sin(frame * 0.7)) * 80 + 175
    d.ellipse([cx-6, cy-15+bob, cx-2, cy-11+bob], fill=(*DEMON_EYE[:3], int(glow)))
    d.ellipse([cx+2, cy-15+bob, cx+6, cy-11+bob], fill=(*DEMON_EYE[:3], int(glow)))
    # 嘴（龇牙）
    for t in range(4):
        tx = cx - 4 + t * 3
        d.polygon([tx, cy-8+bob, tx+1, cy-5+bob, tx+2, cy-8+bob], fill=(240,240,240,200))

def demon_walk():
    frames = []
    for i in range(6):
        f = new_frame(48)
        d = ImageDraw.Draw(f)
        bob = int(math.sin(i * math.pi / 3) * 1.5)
        wf = int(math.sin(i * math.pi / 3) * 5)
        draw_demon(d, i, bob, wf)
        frames.append(f)
    return frames

def demon_attack():
    frames = []
    for i in range(5):
        f = new_frame(48)
        d = ImageDraw.Draw(f)
        arm_ext = int(math.sin(i * math.pi / 4) * 6)
        draw_demon(d, i, 0, 0, arm_ext)
        # 爪痕特效
        if i >= 2:
            slash_x = 24 + 14 + arm_ext + 4
            for s in range(3):
                sy = 18 + s * 6
                d.line([slash_x, sy, slash_x+8, sy+3], fill=(255,200,0,int(200*(1-i/4))), width=2)
        frames.append(f)
    return frames

def demon_death():
    frames = []
    for i in range(5):
        f = new_frame(48)
        d = ImageDraw.Draw(f)
        t = i / 4.0
        alpha = int(255 * (1 - t))
        drop = int(t * 10)
        # 渐渐倒下消散
        img_tmp = new_frame(48)
        dt = ImageDraw.Draw(img_tmp)
        draw_demon(dt, i, drop, 0)
        # 逐渐淡出
        r, g, b, a_ch = img_tmp.split()
        a_arr = a_ch.point(lambda x: min(x, alpha))
        img_tmp = Image.merge("RGBA", (r, g, b, a_arr))
        # 火焰粒子
        for _ in range(i * 3):
            px = 24 + int((hash(str(i) + str(_)) % 20) - 10)
            py = 20 + int((hash(str(i) + 'y' + str(_)) % 15))
            pr = max(1, 4 - i)
            dt2 = ImageDraw.Draw(img_tmp)
            dt2.ellipse([px-pr, py-pr, px+pr, py+pr],
                        fill=(255, int(100+_*20)%256, 0, alpha//2))
        f = img_tmp
        frames.append(f)
    return frames

# ══════════════════════════════════════════════════════════
# 3. 怪物 — 骷髅 (Skeleton) 48x48
# ══════════════════════════════════════════════════════════
SKEL_BONE  = (240, 230, 200, 255)
SKEL_DARK  = (180, 170, 140, 255)
SKEL_EYE   = (80, 200, 80, 255)   # 绿色幽灵眼
SKEL_SWORD = (180, 180, 200, 255)

def draw_skeleton(d, frame=0, bob=0, sword_angle=0):
    cx, cy = 24, 28
    # 阴影
    d.ellipse([cx-8, cy+13+bob, cx+8, cy+17+bob], fill=(0,0,0,60))
    # 骨盆/骨盆
    d.ellipse([cx-6, cy+6+bob, cx+6, cy+12+bob], fill=SKEL_BONE)
    # 腿骨
    leg = int(math.sin(frame * 1.2) * 4)
    # 左腿
    d.line([cx-3, cy+10+bob, cx-4, cy+14+bob+leg], fill=SKEL_BONE, width=3)
    d.line([cx-4, cy+14+bob+leg, cx-3, cy+18+bob+leg//2], fill=SKEL_BONE, width=3)
    d.ellipse([cx-5, cy+18+bob, cx-1, cy+20+bob], fill=SKEL_DARK)  # 脚
    # 右腿
    d.line([cx+3, cy+10+bob, cx+4, cy+14+bob-leg], fill=SKEL_BONE, width=3)
    d.line([cx+4, cy+14+bob-leg, cx+3, cy+18+bob-leg//2], fill=SKEL_BONE, width=3)
    d.ellipse([cx+1, cy+18+bob, cx+5, cy+20+bob], fill=SKEL_DARK)
    # 脊椎
    for yi in range(3):
        d.ellipse([cx-2, cy-1+bob+yi*4, cx+2, cy+2+bob+yi*4], fill=SKEL_BONE)
    # 肋骨
    for ri in range(2):
        ry = cy - 2 + bob + ri * 4
        d.arc([cx-7, ry, cx+0, ry+4], 180, 360, fill=SKEL_BONE, width=2)
        d.arc([cx+0, ry, cx+7, ry+4], 0, 180, fill=SKEL_BONE, width=2)
    # 手臂
    arm_swing = math.sin(frame * 1.2) * 3
    d.line([cx-7, cy-4+bob, cx-12, cy+0+bob+int(arm_swing)], fill=SKEL_BONE, width=3)
    d.ellipse([cx-14, cy+0+bob-2+int(arm_swing), cx-10, cy+2+bob+2+int(arm_swing)], fill=SKEL_DARK)
    # 持剑的右臂
    angle_r = math.radians(sword_angle)
    ax = int(math.cos(angle_r) * 10)
    ay = int(math.sin(angle_r) * 10)
    d.line([cx+7, cy-4+bob, cx+7+ax, cy+0+bob+ay], fill=SKEL_BONE, width=3)
    # 剑
    sx, sy = cx+7+ax, cy+0+bob+ay
    d.line([sx, sy, sx+int(ax*1.8), sy+int(ay*1.8)+2], fill=SKEL_SWORD, width=3)
    d.line([sx+int(ax*0.5)-3, sy+int(ay*0.5), sx+int(ax*0.5)+3, sy+int(ay*0.5)], fill=SKEL_DARK, width=2)
    # 颅骨
    d.ellipse([cx-7, cy-18+bob, cx+7, cy-5+bob], fill=SKEL_BONE)
    d.ellipse([cx-8, cy-14+bob, cx+8, cy-8+bob], fill=SKEL_BONE)  # 颧骨宽
    # 眼眶
    d.ellipse([cx-6, cy-16+bob, cx-2, cy-11+bob], fill=(30,30,30,255))
    d.ellipse([cx+2, cy-16+bob, cx+6, cy-11+bob], fill=(30,30,30,255))
    # 眼睛发光
    glow = abs(math.sin(frame * 0.6)) * 100 + 155
    d.ellipse([cx-5, cy-15+bob, cx-3, cy-12+bob], fill=(*SKEL_EYE[:3], int(glow)))
    d.ellipse([cx+3, cy-15+bob, cx+5, cy-12+bob], fill=(*SKEL_EYE[:3], int(glow)))
    # 鼻腔
    d.polygon([cx-1, cy-11+bob, cx, cy-9+bob, cx+1, cy-11+bob], fill=(30,30,30,200))
    # 牙齿
    for t in range(4):
        tx = cx - 4 + t * 3
        d.rectangle([tx, cy-9+bob, tx+2, cy-7+bob], fill=SKEL_BONE)

def skeleton_walk():
    frames = []
    for i in range(6):
        f = new_frame(48)
        d = ImageDraw.Draw(f)
        bob = int(abs(math.sin(i * math.pi / 3)) * -2)
        draw_skeleton(d, i, bob, sword_angle=20)
        frames.append(f)
    return frames

def skeleton_attack():
    frames = []
    angles = [-10, 20, 50, 30, 10]
    for i, angle in enumerate(angles):
        f = new_frame(48)
        d = ImageDraw.Draw(f)
        draw_skeleton(d, i, 0, sword_angle=angle)
        # 剑光
        if i == 2:
            for s in range(4):
                sa = math.radians(angle - 5 + s * 3)
                sx = int(24 + math.cos(sa) * (18 + s * 4))
                sy = int(24 + math.sin(sa) * (18 + s * 4))
                d.ellipse([sx-2, sy-2, sx+2, sy+2], fill=(255,255,200, 200-s*40))
        frames.append(f)
    return frames

# ══════════════════════════════════════════════════════════
# 4. 特效 spritesheet
# ══════════════════════════════════════════════════════════
def fireball_frames():
    """火球飞行动画 32x32, 8帧"""
    frames = []
    for i in range(8):
        f = Image.new("RGBA", (32, 32), (0,0,0,0))
        d = ImageDraw.Draw(f)
        t = i / 7.0
        # 尾迹
        for tr in range(5):
            tx = 10 - tr * 4
            ty = 16
            tr_r = max(1, 6 - tr * 1)
            tr_a = int(180 - tr * 35)
            d.ellipse([tx-tr_r, ty-tr_r//2, tx+tr_r, ty+tr_r//2],
                      fill=(255, 100+tr*20, 0, tr_a))
        # 主球
        r = 7 + int(math.sin(i * 0.8) * 2)
        # 外层光晕
        d.ellipse([16-r-3, 16-r-3, 16+r+3, 16+r+3], fill=(255, 150, 0, 60))
        d.ellipse([16-r-1, 16-r-1, 16+r+1, 16+r+1], fill=(255, 200, 0, 120))
        # 核心
        d.ellipse([16-r, 16-r, 16+r, 16+r], fill=(255, 220, 80, 240))
        d.ellipse([16-r+2, 16-r+2, 16+r-2, 16+r-2], fill=(255, 255, 200, 200))
        frames.append(f)
    return frames

def explosion_frames():
    """爆炸特效 64x64, 12帧"""
    frames = []
    for i in range(12):
        f = Image.new("RGBA", (64, 64), (0,0,0,0))
        d = ImageDraw.Draw(f)
        t = i / 11.0
        cx, cy = 32, 32
        # 爆炸半径扩展
        max_r = 28
        r = int(max_r * min(t * 1.5, 1.0))
        fade = max(0, 1.0 - t * 1.2)
        # 外层冲击波
        if r > 5:
            wave_w = max(1, int(4 * (1 - t)))
            for wr in range(wave_w):
                d.ellipse([cx-r-wr, cy-r-wr, cx+r+wr, cy+r+wr],
                          outline=(255, 200, 100, int(150*fade*(1-wr/wave_w))), width=1)
        # 火焰团
        for fi in range(12):
            angle = fi * 30 + i * 15
            dist = r * 0.7
            fx = cx + int(math.cos(math.radians(angle)) * dist)
            fy = cy + int(math.sin(math.radians(angle)) * dist)
            fr = max(2, int((10 - i * 0.7)))
            d.ellipse([fx-fr, fy-fr, fx+fr, fy+fr],
                      fill=(255, int(150*(1-t)), 0, int(200*fade)))
        # 中心核
        if t < 0.5:
            core_r = int(15 * (1 - t * 2))
            d.ellipse([cx-core_r, cy-core_r, cx+core_r, cy+core_r],
                      fill=(255, 255, 200, int(250*fade)))
        # 烟雾
        if t > 0.4:
            smoke_r = int(r * 0.9)
            smoke_a = int(80 * (t - 0.4) / 0.6)
            d.ellipse([cx-smoke_r, cy-smoke_r, cx+smoke_r, cy+smoke_r],
                      fill=(80, 80, 80, smoke_a))
        frames.append(f)
    return frames

def magic_hit_frames():
    """魔法命中特效 32x32, 6帧"""
    frames = []
    for i in range(6):
        f = Image.new("RGBA", (32, 32), (0,0,0,0))
        d = ImageDraw.Draw(f)
        cx, cy = 16, 16
        t = i / 5.0
        r = int(5 + t * 10)
        alpha = int(255 * (1 - t))
        # 光环
        d.ellipse([cx-r, cy-r, cx+r, cy+r],
                  outline=(100, 200, 255, alpha), width=2)
        # 星形光芒
        for sp in range(6):
            angle = math.radians(sp * 60 + i * 20)
            x1 = cx + int(math.cos(angle) * (r//2))
            y1 = cy + int(math.sin(angle) * (r//2))
            x2 = cx + int(math.cos(angle) * r)
            y2 = cy + int(math.sin(angle) * r)
            d.line([x1, y1, x2, y2], fill=(180, 240, 255, alpha), width=2)
        # 中心
        if i < 3:
            d.ellipse([cx-3, cy-3, cx+3, cy+3], fill=(255, 255, 255, alpha))
        frames.append(f)
    return frames

def heal_effect_frames():
    """治愈特效（绿色粒子上升）32x32, 8帧"""
    frames = []
    for i in range(8):
        f = Image.new("RGBA", (32, 32), (0,0,0,0))
        d = ImageDraw.Draw(f)
        for p in range(5):
            phase = (i + p * 1.6) / 8.0
            px = 8 + p * 5 + int(math.sin(phase * math.pi * 2) * 3)
            py = 28 - int(phase * 20)
            alpha = int(200 * (1 - phase))
            r = max(1, 3 - int(phase * 2))
            d.ellipse([px-r, py-r, px+r, py+r], fill=(80, 255, 120, alpha))
        frames.append(f)
    return frames

def shield_frames():
    """护盾特效 48x48, 8帧"""
    frames = []
    for i in range(8):
        f = Image.new("RGBA", (48, 48), (0,0,0,0))
        d = ImageDraw.Draw(f)
        cx, cy = 24, 24
        pulse = math.sin(i * math.pi / 4) * 3
        r = int(20 + pulse)
        # 外层护盾圈
        for layer in range(3):
            lr = r + layer * 2
            alpha = int((80 - layer * 20))
            d.ellipse([cx-lr, cy-lr, cx+lr, cy+lr],
                      outline=(100, 180, 255, alpha), width=2)
        # 六边形格子感
        for h in range(6):
            angle = math.radians(h * 60 + i * 5)
            x1 = cx + int(math.cos(angle) * (r * 0.6))
            y1 = cy + int(math.sin(angle) * (r * 0.6))
            x2 = cx + int(math.cos(angle) * r)
            y2 = cy + int(math.sin(angle) * r)
            d.line([x1, y1, x2, y2], fill=(150, 220, 255, 120), width=1)
        frames.append(f)
    return frames

# ══════════════════════════════════════════════════════════
# 保存所有 spritesheet
# ══════════════════════════════════════════════════════════
print("Generating sprites...")

# 主角法师
mage_idle_sh   = make_sheet(mage_idle())
mage_walk_sh   = make_sheet(mage_walk())
mage_attack_sh = make_sheet(mage_attack())
mage_hurt_sh   = make_sheet(mage_hurt())

mage_idle_sh.save(f"{OUT}/mage_idle.png")
mage_walk_sh.save(f"{OUT}/mage_walk.png")
mage_attack_sh.save(f"{OUT}/mage_attack.png")
mage_hurt_sh.save(f"{OUT}/mage_hurt.png")
print(f"  mage: idle({mage_idle_sh.size}), walk({mage_walk_sh.size}), attack({mage_attack_sh.size}), hurt({mage_hurt_sh.size})")

# 恶魔
demon_walk_sh   = make_sheet(demon_walk())
demon_attack_sh = make_sheet(demon_attack())
demon_death_sh  = make_sheet(demon_death())

demon_walk_sh.save(f"{OUT}/demon_walk.png")
demon_attack_sh.save(f"{OUT}/demon_attack.png")
demon_death_sh.save(f"{OUT}/demon_death.png")
print(f"  demon: walk({demon_walk_sh.size}), attack({demon_attack_sh.size}), death({demon_death_sh.size})")

# 骷髅
skel_walk_sh   = make_sheet(skeleton_walk())
skel_attack_sh = make_sheet(skeleton_attack())

skel_walk_sh.save(f"{OUT}/skeleton_walk.png")
skel_attack_sh.save(f"{OUT}/skeleton_attack.png")
print(f"  skeleton: walk({skel_walk_sh.size}), attack({skel_attack_sh.size})")

# 特效
fireball_sh  = make_sheet(fireball_frames())
explosion_sh = make_sheet(explosion_frames())
magic_hit_sh = make_sheet(magic_hit_frames())
heal_sh      = make_sheet(heal_effect_frames())
shield_sh    = make_sheet(shield_frames())

fireball_sh.save(f"{OUT}/effect_fireball.png")
explosion_sh.save(f"{OUT}/effect_explosion.png")
magic_hit_sh.save(f"{OUT}/effect_magic_hit.png")
heal_sh.save(f"{OUT}/effect_heal.png")
shield_sh.save(f"{OUT}/effect_shield.png")
print(f"  effects: fireball, explosion, magic_hit, heal, shield")

print(f"\nAll sprites saved to: {OUT}")
print("Done!")
