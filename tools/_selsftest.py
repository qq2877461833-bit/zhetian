#!/usr/bin/env python3
"""临时自检：构造假构建目录（Sprint 1 验证 size_gate.py 用，用完删除）"""
import json
import os

root = "/tmp/zt-build/web"
os.makedirs(root, exist_ok=True)
with open(os.path.join(root, "godot.wasm"), "wb") as f:
    f.write(b"0" * 3_000_000)
with open(os.path.join(root, "index.html"), "wb") as f:
    f.write(b"<html>test</html>")
with open(os.path.join(root, "fs.pck"), "wb") as f:
    f.write(b"1" * 1_000_000)
with open(os.path.join(root, "hg.pck"), "wb") as f:
    f.write(b"2" * 1_500_000)
with open(os.path.join(root, "manifest.json"), "w", encoding="utf-8") as f:
    json.dump({
        "version": "1.0.0",
        "bundles": [
            {"id": "first_screen", "file": "fs.pck", "size_bytes": 0, "hash": "x"},
            {"id": "huanggu", "file": "hg.pck", "size_bytes": 0, "hash": "y"},
        ],
    }, f)
print("dummy build created")
