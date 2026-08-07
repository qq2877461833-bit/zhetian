#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""《遮天》icon 压缩工具：AI 原图 PNG → WebP（缩尺寸+降体积）
用法: python tools/compress_icons.py [--dir assets/icons] [--force]
"""
import argparse
import os
from pathlib import Path
from PIL import Image

TARGET_SIZE = 160       # icon 目标边长（原 256）
QUALITY = 82            # webp 质量


def compress(png_path: Path, webp_path: Path, target: int = TARGET_SIZE) -> int:
    img = Image.open(png_path)
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    # 等比缩到目标边长
    ratio = target / max(img.size)
    if ratio < 1.0:
        img = img.resize((max(1, int(img.size[0] * ratio)), max(1, int(img.size[1] * ratio))), Image.LANCZOS)
    img.save(webp_path, "WEBP", quality=QUALITY, method=6)
    return webp_path.stat().st_size


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", default="assets/icons", help="icon 目录")
    parser.add_argument("--force", action="store_true", help="覆盖已转换文件")
    args = parser.parse_args()

    d = Path(args.dir)
    total_before = 0
    total_after = 0
    count = 0
    for png in sorted(d.glob("*.png")):
        # 跳过已转换的（存在同名 webp 且未 force）
        webp = png.with_suffix(".webp")
        if webp.exists() and not args.force:
            continue
        before = png.stat().st_size
        after = compress(png, webp)
        total_before += before
        total_after += after
        count += 1
        print(f"  {png.name}: {before/1024:.0f}KB -> {after/1024:.0f}KB ({after*100/before:.0f}%)")
    print(f"\n共 {count} 张：{total_before/1024/1024:.2f}MB -> {total_after/1024/1024:.2f}MB (节省 {(1-total_after/total_before)*100:.0f}%)")


if __name__ == "__main__":
    main()
