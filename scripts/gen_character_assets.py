#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""《遮天》Sprint 2 角色正式资产 P0 第一批生成脚本
产出：
- assets/characters/character_<id>_card.png   5 张卡面立绘 512x768
- assets/characters/character_<id>_avatar.png 5 张头像 128x128
- assets/gacha/gacha_bg_ziqi_f1..3.png        抽卡演出背景 3 帧 640x360
- assets/gacha/gacha_card_back.png            卡背图 512x768
约束：合计 <=4MB；稀有度着色引用美术圣经 §5.4；命名规范。
"""
import os, math, random

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError as e:
    raise SystemExit("PIL not available: %s" % e)

ROOT = r"C:\Users\yanglimei\WorkBuddy\遮天"
OUT_CHAR = os.path.join(ROOT, "assets", "characters")
OUT_GACHA = os.path.join(ROOT, "assets", "gacha")
os.makedirs(OUT_CHAR, exist_ok=True)
os.makedirs(OUT_GACHA, exist_ok=True)

# ---------- 美术圣经 v0.2 色板 ----------
BRONZE_GREEN = (74, 107, 90)     # 主·青铜绿 #4A6B5A
RUST_BROWN   = (110, 90, 58)     # 主·青铜锈棕 #6E5A3A
INK_GREEN    = (28, 42, 38)      # 辅·墨青 #1C2A26
GOLD         = (201, 168, 106)   # 辅·鎏金 #C9A86A
MOON_WHITE   = (232, 228, 216)   # 辅·月白 #E8E4D8
STAR_PURPLE  = (74, 62, 110)     # 辅·星紫 #4A3E6E
CINNABAR     = (168, 50, 50)     # 强调·朱砂 #A83232
MIST_GRAY    = (138, 146, 136)   # 雾霭 #8A9288

# 稀有度定义（引用 §5.4）：id -> (名称, 边框色, 标记形状, 环数)
RARITIES = {
    "fan":   ("凡品", BRONZE_GREEN, "diamond", 0),
    "ling":  ("灵品", MOON_WHITE,   "diamond", 1),
    "xuan":  ("玄品", GOLD,         "diamond", 2),
    "di":    ("地品", STAR_PURPLE,  "diamond", 3),
    "tian":  ("天品", GOLD,         "hex",     1),
    "di_p":  ("帝品", GOLD,         "hex",     2),
}

def vgrad_rgba(w, h, top, bottom, alpha=255):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        d.line([(0, y), (w, y)], fill=c + (alpha,))
    return img

def radial_glow(w, h, cx, cy, r, color, a=160):
    """径向光晕层（透明背景）"""
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    steps = 24
    for i in range(steps, 0, -1):
        rr = r * i / steps
        alpha = int(a * (1 - i / steps) ** 1.6)
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=color + (alpha,))
    return layer.filter(ImageFilter.GaussianBlur(6))

def fog_layer(w, h, color, alpha=70, n=8, seed=3):
    """云雾层（透明背景）"""
    random.seed(seed)
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(n):
        cx = random.randrange(0, w)
        cy = random.randrange(int(h * 0.25), int(h * 0.95))
        rw = random.randrange(int(w * 0.12), int(w * 0.3))
        rh = int(rw * random.uniform(0.25, 0.45))
        a = random.randrange(alpha - 25, alpha + 25)
        d.ellipse([cx - rw, cy - rh, cx + rw, cy + rh], fill=color + (a,))
    return layer.filter(ImageFilter.GaussianBlur(14))

def add_noise(img, amount=6, seed=1):
    random.seed(seed)
    px = img.load()
    w, h = img.size
    for _ in range(int(w * h * 0.015)):
        x = random.randrange(w); y = random.randrange(h)
        r, g, b = px[x, y][:3]
        dd = random.randint(-amount, amount)
        px[x, y] = (max(0, min(255, r + dd)), max(0, min(255, g + dd)),
                    max(0, min(255, b + dd)), px[x, y][3])
    return img

def draw_person(d, cx, top, scale, skin, hair, robe, robe2=None, belt=None, pose="stand"):
    """简笔人物剪影：头 + 躯干 + 简单四肢/服饰。cx=中心x, top=头顶y, scale=体型缩放"""
    head_r = int(26 * scale)
    head_y = top + head_r
    # 头
    d.ellipse([cx - head_r, head_y - head_r, cx + head_r, head_y + head_r], fill=skin)
    # 发
    d.ellipse([cx - head_r - 2, head_y - head_r - 3, cx + head_r + 2, head_y + head_r * 0.6], fill=hair)
    # 躯干（袍）
    shoulder = int(38 * scale)
    hip = int(24 * scale)
    torso_top = head_y + head_r * 0.75
    torso_bot = torso_top + int(130 * scale)
    robe_c = robe2 if robe2 else robe
    d.polygon([(cx - shoulder, torso_top), (cx + shoulder, torso_top),
               (cx + hip, torso_bot), (cx - hip, torso_bot)], fill=robe_c)
    # 衣领/腰带
    if belt:
        d.rectangle([cx - int(20 * scale), torso_top + int(58 * scale),
                     cx + int(20 * scale), torso_top + int(66 * scale)], fill=belt)
    # 手臂
    arm_len = int(52 * scale)
    ax = int(shoulder * 0.85)
    if pose == "arms_cross":
        d.line([(cx - ax, torso_top + 10), (cx - int(8 * scale), torso_top + int(34 * scale))],
               fill=robe_c, width=int(12 * scale))
        d.line([(cx + ax, torso_top + 10), (cx + int(8 * scale), torso_top + int(34 * scale))],
               fill=robe_c, width=int(12 * scale))
    else:
        d.line([(cx - ax, torso_top + 6), (cx - ax - int(6 * scale), torso_top + arm_len)],
               fill=robe_c, width=int(12 * scale))
        d.line([(cx + ax, torso_top + 6), (cx + ax + int(6 * scale), torso_top + arm_len)],
               fill=robe_c, width=int(12 * scale))

def draw_rim_light(img, color=GOLD, alpha=90):
    """角色轮廓鎏金描边光（§7.2 Rim Light 简化：四周内发光）"""
    w, h = img.size
    gl = radial_glow(w, h, w // 2, int(h * 0.42), int(h * 0.38), color, alpha)
    return Image.alpha_composite(img, gl)

def rarity_frame(card, rarity_key):
    """稀有度边框：描边 + 顶部标记（§5.4 双通道：色值 + 形态）"""
    w, h = card.size
    d = ImageDraw.Draw(card)
    name, col, shape, rings = RARITIES[rarity_key]
    # 外描边
    d.rectangle([4, 4, w - 4, h - 4], outline=col + (255,), width=3)
    # 内细线
    d.rectangle([12, 12, w - 12, h - 12], outline=col + (150,), width=1)
    # 顶部标记
    mx, my = w // 2, 44
    if shape == "diamond":
        d.polygon([(mx, my - 18), (mx + 18, my), (mx, my + 18), (mx - 18, my)], outline=col + (255,), width=3)
        for i in range(rings):
            rr = 26 + i * 10
            d.ellipse([mx - rr, my - rr, mx + rr, my + rr], outline=col + (200,), width=2)
    elif shape == "hex":
        pts = [(mx + 20 * math.cos(math.radians(a)), my + 20 * math.sin(math.radians(a)))
               for a in range(0, 360, 60)]
        d.polygon(pts, outline=col + (255,), width=3)
        for i in range(rings):
            rr = 28 + i * 10
            d.ellipse([mx - rr, my - rr, mx + rr, my + rr], outline=col + (200,), width=2)
    # 底部铭文台（UI 文本覆盖区占位，不写文字）
    d.rectangle([40, h - 96, w - 40, h - 44], outline=col + (120,), width=1)
    return card

def make_card(cid, name_zh, rarity, bg_top, bg_bot, robe, robe2, hair, skin,
              belt=None, pose="stand", scale=1.0, scene="plain", accent=None):
    W, H = 512, 768
    # 背景渐变 + 噪点
    card = vgrad_rgba(W, H, bg_top, bg_bot)
    card = add_noise(card, 5, seed=hash(cid) % 100)
    # 场景元素
    if scene == "mountain":
        ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        dd = ImageDraw.Draw(ov)
        for i, (hh, col, al) in enumerate([
            (180, BRONZE_GREEN + (80,), 90),
            (240, (48, 74, 62) + (80,), 80),
        ]):
            pts = [(0, H)]
            for x in range(0, W + 30, 30):
                y = H - hh - int(22 * math.sin(x / 150 + i * 2.4))
                pts.append((x, y))
            pts.append((W, H))
            dd.polygon(pts, fill=col)
        ov = ov.filter(ImageFilter.GaussianBlur(2))
        card = Image.alpha_composite(card, ov)
    elif scene == "stars":
        random.seed(hash(cid) % 100)
        st = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ds = ImageDraw.Draw(st)
        for _ in range(70):
            x = random.randrange(0, W); y = random.randrange(0, int(H * 0.55))
            r = random.choice([1, 1, 2])
            ds.ellipse([x - r, y - r, x + r, y + r], fill=MOON_WHITE + (random.randrange(120, 230),))
        st = st.filter(ImageFilter.GaussianBlur(1))
        card = Image.alpha_composite(card, st)
    elif scene == "mist":
        card = Image.alpha_composite(card, fog_layer(W, H, MIST_GRAY, 60, seed=hash(cid) % 100))
    # 背景光晕
    card = Image.alpha_composite(card, radial_glow(W, H, W // 2, int(H * 0.34), int(H * 0.42), accent or GOLD, 70))
    # 角色
    body = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    cx = W // 2
    top = int(H * 0.30)
    draw_person(d, cx, top, scale, skin, hair, robe, robe2, belt, pose)
    body = draw_rim_light(body, GOLD, 60)
    card = Image.alpha_composite(card, body)
    # 前景雾气
    card = Image.alpha_composite(card, fog_layer(W, H, MOON_WHITE, 26, n=5, seed=hash(cid) % 100 + 7))
    # 稀有度边框
    card = rarity_frame(card, rarity)
    out = os.path.join(OUT_CHAR, "character_%s_card.png" % cid)
    card.convert("RGBA").save(out)
    print(out, "OK", "%.1fKB" % (os.path.getsize(out) / 1024))
    return out

def make_avatar(cid, rarity, bg_top, bg_bot, robe, hair, skin):
    """128x128 头像：背景 + 头肩特写 + 稀有度描边圆角"""
    S = 128
    av = vgrad_rgba(S, S, bg_top, bg_bot)
    av = add_noise(av, 4, seed=hash(cid) % 50)
    body = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    # 肩
    d.polygon([(18, 128), (S - 18, 128), (S - 30, 78), (30, 78)], fill=robe)
    # 头
    d.ellipse([38, 26, 90, 82], fill=skin)
    # 发
    d.ellipse([34, 22, 94, 74], fill=hair)
    av = Image.alpha_composite(av, body)
    # 稀有度描边（圆角蒙版）
    mask = Image.new("L", (S, S), 0)
    dm = ImageDraw.Draw(mask)
    dm.rounded_rectangle([2, 2, S - 2, S - 2], radius=14, fill=255)
    _, col, _, _ = RARITIES[rarity]
    ring = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(ring)
    dr.rounded_rectangle([2, 2, S - 2, S - 2], radius=14, outline=col + (255,), width=3)
    av = Image.composite(Image.alpha_composite(av, ring), Image.new("RGBA", (S, S), (0, 0, 0, 0)), mask)
    out = os.path.join(OUT_CHAR, "character_%s_avatar.png" % cid)
    av.convert("RGBA").save(out)
    print(out, "OK", "%.1fKB" % (os.path.getsize(out) / 1024))
    return out

# ================= 角色定义（GDD-002 轮海期可用） =================
# (cid, 中文名, 稀有度, bg_top, bg_bot, robe主, robe副, 发色, 肤色, 腰带, 姿态, scale, 场景, 强调色)
characters = [
    # 叶凡：主角·剧情送——玄品（鎏金），荒古山村/青铜绿，短褐+长剑，青年
    ("ye_fan", "叶凡", "xuan",
     (40, 58, 50), (18, 26, 22), BRONZE_GREEN, (92, 122, 104), (26, 30, 32), (224, 200, 178),
     RUST_BROWN, "stand", 1.02, "mountain", GOLD),
    # 庞博：轮海毕业送——灵品（月白），荒古粗犷，深棕布衣+粗腰，壮汉
    ("pang_bo", "庞博", "ling",
     (58, 52, 40), (24, 22, 18), (96, 74, 52), (120, 96, 68), (20, 20, 22), (216, 190, 166),
     RUST_BROWN, "arms_cross", 1.14, "mountain", MOON_WHITE),
    # 姬紫月：抽卡——玄品（鎏金），星紫夜空+飘带，女修
    ("ji_ziyue", "姬紫月", "xuan",
     (40, 34, 64), (16, 14, 30), STAR_PURPLE, (108, 96, 148), (20, 22, 34), (228, 202, 186),
     MOON_WHITE, "stand", 1.0, "stars", STAR_PURPLE),
    # 黑皇：抽卡——灵品（月白），墨青夜晚，大黑狗（特殊：用简化剪影）
    ("hei_huang", "黑皇", "ling",
     (26, 38, 40), (12, 18, 20), (26, 26, 30), (40, 40, 46), (22, 22, 26), (210, 190, 170),
     GOLD, "stand", 1.0, "mist", GOLD),
    # 段德：抽卡——凡品（青铜绿），雾霭道观，青灰道袍+拂尘，道士
    ("duan_de", "段德", "fan",
     (48, 58, 54), (20, 26, 24), (92, 104, 98), (120, 128, 122), (34, 32, 30), (222, 200, 178),
     RUST_BROWN, "stand", 1.02, "mist", BRONZE_GREEN),
]

for c in characters:
    cid, name_zh, rarity, bt, bb, robe, robe2, hair, skin, belt, pose, scale, scene, accent = c
    make_card(cid, name_zh, rarity, bt, bb, robe, robe2, hair, skin, belt, pose, scale, scene, accent)
    make_avatar(cid, rarity, bt, bb, robe, hair, skin)

# ================= 抽卡演出背景（紫气东来增强版 3 帧，§7.1 仙道法术类） =================
def make_gacha_frame(fname, frame, seed_base=0):
    W, H = 640, 360
    img = vgrad_rgba(W, H, STAR_PURPLE, (16, 12, 30))
    # 帧进度 t: f1=0.15 f2=0.55 f3=0.95
    t = [0.15, 0.55, 0.95][frame]
    # 紫金流霞（星紫→鎏金）
    base = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dg = ImageDraw.Draw(base)
    for y in range(H):
        k = y / H
        c = tuple(int(STAR_PURPLE[i] * (1 - k) + GOLD[i] * k) for i in range(3))
        dg.line([(0, y), (W, y)], fill=c + (int(90 + 120 * (1 - k)),))
    base = base.filter(ImageFilter.GaussianBlur(8))
    img = Image.alpha_composite(img, base)
    # 中心爆发光
    img = Image.alpha_composite(img, radial_glow(W, H, W // 2, H // 2, int(140 + 120 * t), MOON_WHITE, int(150 * t + 30)))
    img = Image.alpha_composite(img, radial_glow(W, H, W // 2, H // 2, int(80 + 80 * t), GOLD, int(170 * t + 20)))
    # 上升粒子（随帧增强）
    random.seed(seed_base + frame)
    ps = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dp = ImageDraw.Draw(ps)
    n = int(60 + 110 * t)
    for _ in range(n):
        x = random.randrange(0, W)
        y = random.randrange(int(H * (1 - 0.6 * t)), H)
        r = random.choice([1, 2, 3, 4])
        col = GOLD if random.random() < 0.5 else MOON_WHITE
        dp.ellipse([x - r, y - r, x + r, y + r], fill=col + (random.randrange(140, 240),))
    ps = ps.filter(ImageFilter.GaussianBlur(1))
    img = Image.alpha_composite(img, ps)
    # 光柱
    beam = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    db = ImageDraw.Draw(beam)
    cx = W // 2
    bw = int(20 + 30 * t)
    db.polygon([(cx - bw, H), (cx - int(bw * 0.25), 0), (cx + int(bw * 0.25), 0), (cx + bw, H)],
               fill=MOON_WHITE + (int(50 + 40 * t),))
    beam = beam.filter(ImageFilter.GaussianBlur(5))
    img = Image.alpha_composite(img, beam)
    # 符文环（f2/f3 出现）
    if frame >= 1:
        ring = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        dr = ImageDraw.Draw(ring)
        for rr, a in [(110, 120), (140, 80)]:
            dr.ellipse([cx - rr, H // 2 - rr, cx + rr, H // 2 + rr], outline=GOLD + (a,), width=3)
        ring = ring.filter(ImageFilter.GaussianBlur(2))
        img = Image.alpha_composite(img, ring)
    out = os.path.join(OUT_GACHA, fname)
    img.convert("RGBA").save(out)
    print(out, "OK", "%.1fKB" % (os.path.getsize(out) / 1024))

for i, f in enumerate(["gacha_bg_ziqi_f1.png", "gacha_bg_ziqi_f2.png", "gacha_bg_ziqi_f3.png"]):
    make_gacha_frame(f, i, seed_base=21)

# ================= 卡背图 gacha_card_back.png =================
def make_card_back(fname, size=(512, 768)):
    W, H = size
    img = vgrad_rgba(W, H, INK_GREEN, (14, 20, 18))
    img = add_noise(img, 5, seed=9)
    d = ImageDraw.Draw(img)
    # 外框
    d.rectangle([6, 6, W - 6, H - 6], outline=GOLD + (255,), width=3)
    d.rectangle([16, 16, W - 16, H - 16], outline=GOLD + (130,), width=1)
    # 中央铭文盘（云雷纹简化：同心圆 + 十字）
    cx, cy = W // 2, H // 2
    d.ellipse([cx - 90, cy - 90, cx + 90, cy + 90], outline=GOLD + (230,), width=4)
    d.ellipse([cx - 72, cy - 72, cx + 72, cy + 72], outline=GOLD + (150,), width=2)
    d.ellipse([cx - 26, cy - 26, cx + 26, cy + 26], outline=CINNABAR + (240,), width=3)
    # 四角云雷纹
    for sx, sy in [(40, 40), (W - 40, 40), (40, H - 40), (W - 40, H - 40)]:
        d.arc([sx - 22, sy - 22, sx + 22, sy + 22], start=0, end=300, fill=GOLD + (180,), width=2)
    # 光晕
    img = Image.alpha_composite(img, radial_glow(W, H, cx, cy, 180, GOLD, 40))
    out = os.path.join(OUT_GACHA, fname)
    img.convert("RGBA").save(out)
    print(out, "OK", "%.1fKB" % (os.path.getsize(out) / 1024))

make_card_back("gacha_card_back.png")

# ================= 体积统计 =================
total = 0
print("---- assets/characters ----")
for f in sorted(os.listdir(OUT_CHAR)):
    if f.lower().endswith(".png"):
        sz = os.path.getsize(os.path.join(OUT_CHAR, f)); total += sz
        print("  %-40s %8.1f KB" % (f, sz / 1024))
print("---- assets/gacha ----")
for f in sorted(os.listdir(OUT_GACHA)):
    if f.lower().endswith(".png"):
        sz = os.path.getsize(os.path.join(OUT_GACHA, f)); total += sz
        print("  %-40s %8.1f KB" % (f, sz / 1024))
print("TOTAL: %.2f KB" % (total / 1024))
print("DONE")
