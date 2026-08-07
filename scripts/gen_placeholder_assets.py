#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""《遮天》Sprint 1 垂直切片 P0 占位资产生成脚本
生成：主界面背景 / 三按钮 / 结算弹窗 / 突破演出占位
落盘：assets/placeholder/  命名：区域_类型_名称.png
约束：合计 <=2MB，PNG 格式，尺寸贴合 MVP 资产规格
"""
import os

try:
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
except ImportError as e:
    raise SystemExit("PIL not available: %s" % e)

ROOT = r"C:\Users\yanglimei\WorkBuddy\遮天"
OUT = os.path.join(ROOT, "assets", "placeholder")
os.makedirs(OUT, exist_ok=True)

# ---- 美术圣经 v0.2 色板 ----
BRONZE_GREEN = (74, 107, 90)      # 主·青铜绿 #4A6B5A
RUST_BROWN   = (110, 90, 58)      # 主·青铜锈棕 #6E5A3A
INK_GREEN    = (28, 42, 38)       # 辅·墨青 #1C2A26
GOLD         = (201, 168, 106)    # 辅·鎏金 #C9A86A
MOON_WHITE   = (232, 228, 216)    # 辅·月白 #E8E4D8
STAR_PURPLE  = (74, 62, 110)      # 辅·星紫 #4A3E6E
CINNABAR     = (168, 50, 50)      # 强调·朱砂 #A83232
MIST_GRAY    = (138, 146, 136)    # 雾霭 #8A9288

def vgrad(w, h, top, bottom):
    """垂直渐变"""
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        d.line([(0, y), (w, y)], fill=c)
    return img

def rounded_rect(d, box, radius, fill=None, outline=None, width=1):
    d.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)

def add_noise(img, amount=10, seed=42):
    """轻微噪点增加材质感（占位足够）"""
    import random
    random.seed(seed)
    px = img.load()
    w, h = img.size
    for _ in range(int(w * h * 0.02)):
        x = random.randrange(w)
        y = random.randrange(h)
        r, g, b = px[x, y]
        d = random.randint(-amount, amount)
        px[x, y] = (max(0, min(255, r + d)), max(0, min(255, g + d)), max(0, min(255, b + d)))
    return img

def draw_clouds(d, w, h, color, alpha_scale=1):
    """简单云雾：叠加椭圆柔光"""
    for i in range(6):
        cx = int(w * (0.15 + 0.7 * (i / 5)))
        cy = int(h * (0.35 + 0.5 * ((i * 37) % 100) / 100))
        rw = int(w * (0.10 + 0.05 * (i % 3)))
        rh = int(rw * 0.4)
        d.ellipse([cx - rw, cy - rh, cx + rw, cy + rh], fill=color)
    return d

def glow(img, radius=8):
    return img.filter(ImageFilter.GaussianBlur(radius))

# ============ 1. 主界面背景 main_bg_huanggu (1280x720) ============
W, H = 1280, 720
bg = vgrad(W, H, (34, 48, 43), (16, 24, 21))            # 墨青底
bg = add_noise(bg, 8, 1)

# 远山（青铜绿层叠）
overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(overlay)
for i, (hgt, col, alpha) in enumerate([
    (260, BRONZE_GREEN + (90,), 120),
    (340, (58, 84, 71) + (90,), 110),
    (400, RUST_BROWN + (90,), 100),
]):
    pts = [(0, H)]
    for x in range(0, W + 40, 40):
        import math
        y = H - hgt - int(30 * math.sin(x / 180 + i * 2.0))
        pts.append((x, y))
    pts.append((W, H))
    d.polygon(pts, fill=col)

# 山体柔化
overlay = overlay.filter(ImageFilter.GaussianBlur(2))
bg = Image.alpha_composite(bg.convert("RGBA"), overlay)

# 雾气（雾霭灰半透明）
fog = Image.new("RGBA", (W, H), (0, 0, 0, 0))
df = ImageDraw.Draw(fog)
draw_clouds(df, W, H, MIST_GRAY + (60,))
fog = fog.filter(ImageFilter.GaussianBlur(18))
bg = Image.alpha_composite(bg, fog)

# 顶部铭文光带（鎏金）
line = Image.new("RGBA", (W, 8), (0, 0, 0, 0))
dl = ImageDraw.Draw(line)
for x in range(0, W, 40):
    dl.rectangle([x, 0, x + 18, 8], fill=GOLD + (70,))
line = glow(line, 6)
bg.paste(line, (0, int(H * 0.08)), line)

bg.convert("RGB").save(os.path.join(OUT, "main_bg_huanggu.png"))
print("main_bg_huanggu.png OK")

# ============ 2. 三按钮 main_btn_close / main_btn_breakthrough / main_btn_stage ============
def make_button(fname, label, width=160, height=64, accent=GOLD, dark=INK_GREEN, label_color=MOON_WHITE):
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # 符箓/卷轴母题：深底 + 鎏金描边 + 朱砂印角
    rounded_rect(d, [4, 4, width - 4, height - 4], radius=10, fill=dark + (235,), outline=accent + (255,), width=3)
    # 内描边
    rounded_rect(d, [10, 10, width - 10, height - 10], radius=7, outline=(accent[0], accent[1], accent[2], 110), width=1)
    # 底部鎏金高光
    d.line([(14, height - 10), (width - 14, height - 10)], fill=accent + (200,), width=2)
    # 朱砂印角（右上）
    seal = 12
    d.rectangle([width - 8 - seal, 8, width - 8, 8 + seal], fill=CINNABAR + (220,))
    try:
        font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 20)
    except Exception:
        font = ImageFont.load_default()
    tw = d.textlength(label, font=font)
    d.text(((width - tw) / 2, height / 2 - 12), label, font=font, fill=label_color + (255,))
    img.save(os.path.join(OUT, fname))
    print(fname, "OK")

make_button("main_btn_close.png", "闭关")
make_button("main_btn_breakthrough.png", "突破", accent=GOLD)
make_button("main_btn_stage.png", "推关", accent=GOLD)

# ============ 3. 结算弹窗 settle_popup_scroll (512x384) ============
PW, PH = 512, 384
popup = Image.new("RGBA", (PW, PH), (0, 0, 0, 0))
d = ImageDraw.Draw(popup)
# 卷轴展开母题：墨青半透明底 + 卷边
rounded_rect(d, [8, 8, PW - 8, PH - 8], radius=16, fill=INK_GREEN + (210,), outline=GOLD + (255,), width=3)
# 卷轴横轴（上下）
for ypos in (18, PH - 34):
    d.rounded_rectangle([20, ypos, PW - 20, ypos + 16], radius=8, fill=RUST_BROWN + (235,), outline=GOLD + (200,), width=2)
    d.ellipse([PW - 52, ypos - 6, PW - 28, ypos + 22], fill=RUST_BROWN + (235,), outline=GOLD + (200,), width=2)
    d.ellipse([28, ypos - 6, 52, ypos + 22], fill=RUST_BROWN + (235,), outline=GOLD + (200,), width=2)
# 标题铭文区
d.rectangle([128, 64, PW - 128, 96], outline=GOLD + (160,), width=2)
# 内容区网格占位（给工程摆文字/掉落）
for i in range(3):
    y0 = 120 + i * 64
    rounded_rect(d, [80, y0, PW - 80, y0 + 40], radius=6, outline=MIST_GRAY + (120,), width=1)
popup.save(os.path.join(OUT, "settle_popup_scroll.png"))
print("settle_popup_scroll.png OK")

# ============ 4. 突破演出占位 vfx_breakthrough_ziqi (640x360, 2 帧) ============
def make_vfx_frame(fname, seed_shift=0):
    FW, FH = 640, 360
    frame = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    # 底部星紫渐变（紫气东来：星紫+鎏金上升）
    base = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    dg = ImageDraw.Draw(base)
    for y in range(FH):
        t = y / FH
        c = tuple(int(STAR_PURPLE[i] * (1 - t) + GOLD[i] * t) for i in range(3))
        dg.line([(0, y), (FW, y)], fill=c + (int(120 + 80 * (1 - t)),))
    base = base.filter(ImageFilter.GaussianBlur(6))
    frame = Image.alpha_composite(frame, base)

    # 上升粒子（星辉点）
    import random
    random.seed(7 + seed_shift)
    d = ImageDraw.Draw(frame)
    for _ in range(90):
        x = random.randrange(0, FW)
        y = random.randrange(0, FH)
        r = random.choice([2, 3, 4])
        col = GOLD if random.random() < 0.45 else MOON_WHITE
        d.ellipse([x - r, y - r, x + r, y + r], fill=col + (200,))
    # 中心龙形/神华光晕（突破核心）
    halo = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    dh = ImageDraw.Draw(halo)
    cx, cy = FW // 2, FH // 2
    for rr, a in [(90, 90), (60, 130), (36, 190)]:
        dh.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=GOLD + (a,))
    halo = glow(halo, 12)
    frame = Image.alpha_composite(frame, halo)
    # 光柱（上升感）
    beam = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    db = ImageDraw.Draw(beam)
    db.polygon([(cx - 16, FH), (cx - 4, 0), (cx + 4, 0), (cx + 16, FH)], fill=MOON_WHITE + (60,))
    beam = glow(beam, 6)
    frame = Image.alpha_composite(frame, beam)
    frame.save(os.path.join(OUT, fname))
    print(fname, "OK")

make_vfx_frame("vfx_breakthrough_ziqi_f1.png", seed_shift=0)
make_vfx_frame("vfx_breakthrough_ziqi_f2.png", seed_shift=11)

# ============ 体积统计 ============
total = 0
print("---- size ----")
for f in sorted(os.listdir(OUT)):
    if f.lower().endswith(".png"):
        sz = os.path.getsize(os.path.join(OUT, f))
        total += sz
        print("%-32s %8.1f KB" % (f, sz / 1024))
print("TOTAL: %.2f KB" % (total / 1024))
print("DONE")
