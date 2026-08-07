#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""快速质量校验：尺寸、透明度、稀有度色落位"""
import os
from PIL import Image

ROOT = r"C:\Users\yanglimei\WorkBuddy\遮天"

def near(c1, c2, tol=18):
    return all(abs(a - b) <= tol for a, b in zip(c1[:3], c2[:3]))

def check(path, expect_size=None, expect_color=None, alpha_min=200):
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    px = img.load()
    opaque = 0
    found_color = False
    sample = 0
    for y in range(0, h, 4):
        for x in range(0, w, 4):
            r, g, b, a = px[x, y]
            if a >= alpha_min:
                opaque += 1
            if expect_color and a >= alpha_min and near((r, g, b), expect_color):
                found_color = True
            sample += 1
    pct = opaque / sample * 100
    ok = True
    msgs = []
    if expect_size and (w, h) != expect_size:
        ok = False; msgs.append("SIZE MISMATCH %s!=%s" % ((w, h), expect_size))
    if expect_color and not found_color:
        ok = False; msgs.append("COLOR %s NOT FOUND" % (str(expect_color),))
    print("%-46s %dx%d opaque=%5.1f%% %s" % (
        os.path.relpath(path, ROOT), w, h, pct,
        "OK" if ok else " | ".join(msgs)))
    return ok

print("== characters ==")
expect = {
    ("character_ye_fan_card.png", "xuan"), ("character_ye_fan_avatar.png", "xuan"),
    ("character_pang_bo_card.png", "ling"), ("character_pang_bo_avatar.png", "ling"),
    ("character_ji_ziyue_card.png", "xuan"), ("character_ji_ziyue_avatar.png", "xuan"),
    ("character_hei_huang_card.png", "ling"), ("character_hei_huang_avatar.png", "ling"),
    ("character_duan_de_card.png", "fan"), ("character_duan_de_avatar.png", "fan"),
}
RAR = {
    "fan": (74, 107, 90), "ling": (232, 228, 216), "xuan": (201, 168, 106),
}
for fn, rar in expect:
    p = os.path.join(ROOT, "assets", "characters", fn)
    size = (128, 128) if "avatar" in fn else (512, 768)
    check(p, size, RAR[rar])

print("== gacha ==")
for fn in ["gacha_bg_ziqi_f1.png", "gacha_bg_ziqi_f2.png", "gacha_bg_ziqi_f3.png"]:
    check(os.path.join(ROOT, "assets", "gacha", fn), (640, 360), None)
check(os.path.join(ROOT, "assets", "gacha", "gacha_card_back.png"), (512, 768), (201, 168, 106))
print("DONE")
