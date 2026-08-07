#!/usr/bin/env python3
"""《遮天》Web 构建体积门禁（CI 阶段：size-gate）

纯 Python 标准库实现（zlib 内置 gzip 压测，无第三方依赖）：
    python tools/size_gate.py build/web [--manifest build/web/manifest.json]
    python tools/size_gate.py --selfcheck        # 子目录文件回归自检（防 FileNotFoundError 回归）

门禁数值（对齐 ARCH-ENG-005 §2 / ARCH-ENG-002 §5）：
  - 引擎壳 gzip（godot.wasm + index.html + 核心 js）  target ≤9MB / hard ≤12MB
  - 首屏美术增量（first_screen bundle）               target ≤5MB / hard ≤6MB
  - 远程 Bundle（manifest.bundles）                    每包 hard ≤3MB
  - 引擎+首场景总下载（引擎壳 + 首屏）                 target ≤10MB / hard ≤14MB（引擎壳>8MB 时口径上修）

target 超限 → 警告（不失败）；hard 超限 → 失败（退出码 1，CI 阻断）。
"""
import json
import os
import shutil
import sys
import tempfile
import zlib

# ---- 门禁配置（对齐 ARCH-ENG-002 §5.2 / ARCH-ENG-005 §2）----
GATES = {
    "engine_shell_gzip":   {"target": 9 * 1024 * 1024,   "hard": 12 * 1024 * 1024},
    "first_screen_art":    {"target": 5 * 1024 * 1024,   "hard": 6 * 1024 * 1024},
    "bundle_each":         {"target": 3 * 1024 * 1024,   "hard": 3 * 1024 * 1024},
    "stage1_total":        {"target": 10 * 1024 * 1024,  "hard": 14 * 1024 * 1024},
}
ENGINE_SHELL_EXTS = (".wasm", ".js", ".html")
FIRST_SCREEN_BUNDLE_IDS = {"first_screen"}


def gzip_size(data: bytes) -> int:
    """zlib 实现 gzip 压测（level 9）"""
    comp = zlib.compressobj(9, zlib.DEFLATED, 16 + zlib.MAX_WBITS)
    out = comp.compress(data) + comp.flush()
    return len(out)


def fmt(b: int) -> str:
    if b < 1024 * 1024:
        return f"{b / 1024:.1f}KB"
    return f"{b / 1024 / 1024:.2f}MB"


def audit(build_dir: str, manifest_path: str | None = None) -> tuple[int, dict]:
    """执行体积审计与门禁判定。返回 (退出码, 统计字典)。"""
    if not os.path.isdir(build_dir):
        print(f"❌ 构建目录不存在: {build_dir}")
        return 1, {}

    # 收集文件：键 = 相对 build_dir 的路径（统一正斜杠，支持子目录；manifest 协议用 "/"）
    files = {}
    for root, _dirs, names in os.walk(build_dir):
        for name in names:
            p = os.path.join(root, name)
            rel = os.path.relpath(p, build_dir).replace(os.sep, "/")
            files[rel] = os.path.getsize(p)

    # 引擎壳 = wasm/js/html 文件（按相对路径，gzip 压测）
    engine_raw = 0
    engine_gz = 0
    for rel, size in files.items():
        if rel.endswith(ENGINE_SHELL_EXTS):
            engine_raw += size
            with open(os.path.join(build_dir, rel), "rb") as f:
                engine_gz += gzip_size(f.read())

    # manifest 与首屏/远程 Bundle（file 字段按相对路径匹配）
    bundles = []
    if manifest_path and os.path.isfile(manifest_path):
        with open(manifest_path, "r", encoding="utf-8") as f:
            manifest = json.load(f)
        bundles = manifest.get("bundles", [])
        for b in bundles:
            bfile = b.get("file")
            if bfile and bfile in files:
                b["_size"] = files[bfile]
                with open(os.path.join(build_dir, bfile), "rb") as f:
                    b["_size_gz"] = gzip_size(f.read())
            else:
                b["_size"] = 0
                b["_size_gz"] = 0
                print(f"⚠️  manifest 引用文件缺失: {bfile}")

    first_screen = [b for b in bundles if b.get("id") in FIRST_SCREEN_BUNDLE_IDS]
    first_screen_art = sum(b.get("_size_gz", 0) for b in first_screen)
    remote_bundles = [b for b in bundles if b.get("id") not in FIRST_SCREEN_BUNDLE_IDS]
    stage1_total = engine_gz + first_screen_art

    # 报告
    print(f"构建目录: {build_dir}")
    print(f"  引擎壳 raw={fmt(engine_raw)} gzip={fmt(engine_gz)}  (target ≤{fmt(GATES['engine_shell_gzip']['target'])} / hard ≤{fmt(GATES['engine_shell_gzip']['hard'])})")
    print(f"  首屏美术 gzip={fmt(first_screen_art)}  (target ≤{fmt(GATES['first_screen_art']['target'])} / hard ≤{fmt(GATES['first_screen_art']['hard'])})")
    print(f"  阶段1总下载 gzip={fmt(stage1_total)}  (target ≤{fmt(GATES['stage1_total']['target'])} / hard ≤{fmt(GATES['stage1_total']['hard'])})")
    for b in remote_bundles:
        flag = "OK" if b.get("_size_gz", 0) <= GATES["bundle_each"]["hard"] else "FAIL"
        print(f"  远程Bundle {b.get('id')}: {fmt(b.get('_size_gz', 0))}  {flag}")

    # 门禁判定
    failures = []
    warnings = []
    if engine_gz > GATES["engine_shell_gzip"]["hard"]:
        failures.append(f"引擎壳 gzip {fmt(engine_gz)} > hard {fmt(GATES['engine_shell_gzip']['hard'])}")
    elif engine_gz > GATES["engine_shell_gzip"]["target"]:
        warnings.append(f"引擎壳 gzip {fmt(engine_gz)} > target {fmt(GATES['engine_shell_gzip']['target'])}（口径待评审）")

    if first_screen_art > GATES["first_screen_art"]["hard"]:
        failures.append(f"首屏美术 {fmt(first_screen_art)} > hard {fmt(GATES['first_screen_art']['hard'])}")
    elif first_screen_art > GATES["first_screen_art"]["target"]:
        warnings.append(f"首屏美术 {fmt(first_screen_art)} > target {fmt(GATES['first_screen_art']['target'])}")

    if stage1_total > GATES["stage1_total"]["hard"]:
        failures.append(f"阶段1总下载 {fmt(stage1_total)} > hard {fmt(GATES['stage1_total']['hard'])}")
    elif stage1_total > GATES["stage1_total"]["target"]:
        warnings.append(f"阶段1总下载 {fmt(stage1_total)} > target {fmt(GATES['stage1_total']['target'])}（引擎壳>8MB 时口径上修）")

    for b in remote_bundles:
        if b.get("_size_gz", 0) > GATES["bundle_each"]["hard"]:
            failures.append(f"Bundle {b.get('id')} {fmt(b.get('_size_gz', 0))} > {fmt(GATES['bundle_each']['hard'])}")

    for w in warnings:
        print(f"⚠️  {w}")
    for f in failures:
        print(f"❌ {f}")

    if failures:
        print("体积门禁失败")
        return 1, {"engine_raw": engine_raw, "first_screen_art": first_screen_art}
    if warnings:
        print("体积门禁通过（含 target 警告，需预算评审）")
        return 0, {"engine_raw": engine_raw, "first_screen_art": first_screen_art}
    print("✅ 体积门禁通过")
    return 0, {"engine_raw": engine_raw, "first_screen_art": first_screen_art}


def selfcheck() -> int:
    """回归自检：构建产物含子目录文件时（Godot 导出常见），审计不崩溃且正确统计。

    构造：sub/godot.wasm(1MB) + index.html + sub/fs.pck(0.5MB) + manifest 引用 sub/fs.pck。
    断言：退出码 0；引擎壳 raw 捕获到子目录 wasm（>=1MB）；首屏美术 gzip 捕获到子目录 bundle（>0）。
    """
    tmp = tempfile.mkdtemp(prefix="zt_sizegate_")
    try:
        build = os.path.join(tmp, "web")
        sub = os.path.join(build, "sub")
        os.makedirs(sub)
        with open(os.path.join(sub, "godot.wasm"), "wb") as f:
            f.write(b"0" * 1_000_000)
        with open(os.path.join(build, "index.html"), "wb") as f:
            f.write(b"<html>x</html>")
        with open(os.path.join(sub, "fs.pck"), "wb") as f:
            f.write(b"1" * 500_000)
        mp = os.path.join(build, "manifest.json")
        with open(mp, "w", encoding="utf-8") as f:
            json.dump({"version": "1.0.0", "bundles": [
                {"id": "first_screen", "file": "sub/fs.pck", "size_bytes": 0, "hash": "x"}]}, f)

        print("── 自检：子目录构建产物 ──")
        code, stats = audit(build, mp)
        ok = (code == 0
              and stats.get("engine_raw", 0) >= 1_000_000
              and stats.get("first_screen_art", 0) > 0)
        if not ok:
            print(f"❌ 自检失败: code={code}, stats={stats}")
            return 1
        print("✅ 自检通过：子目录 wasm/bundle 均被正确统计，无 FileNotFoundError")
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main() -> int:
    if "--selfcheck" in sys.argv:
        return selfcheck()
    if len(sys.argv) < 2:
        print("用法: python tools/size_gate.py <build_dir> [--manifest <path>]")
        return 2
    build_dir = sys.argv[1]
    manifest_path = None
    if "--manifest" in sys.argv:
        manifest_path = sys.argv[sys.argv.index("--manifest") + 1]
    code, _stats = audit(build_dir, manifest_path)
    return code


if __name__ == "__main__":
    sys.exit(main())
