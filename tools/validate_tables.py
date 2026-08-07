#!/usr/bin/env python3
"""《遮天》数据表 Schema 校验器（CI 阶段：schema-check）

纯 Python 标准库实现（无第三方依赖），运行于 CI 或本地：
    python tools/validate_tables.py [tables_dir]

职责（对齐 ADR-0004）：
1. 每表 schema_version >= 1 且与"table"字段一致；
2. 必填字段/类型/范围校验（按表）；
3. 跨表引用完整性：id 注册表（realm/sub/class/rarity/dungeon/stage/type）交叉校验；
4. 数值合理性（抽卡概率和 ≈ 1.0、克制矩阵完整性等）。

退出码：0 = 通过；1 = 校验失败（CI 阻断）。
"""
import json
import os
import sys

REQUIRED_TABLES = {"realm", "battle", "drop", "character", "gacha", "constants", "equipment", "skill_sets"}
RARITY_SET = {"fan", "ling", "xuan", "di", "tian", "di_pin"}
CLASS_SET = {"huanggu_tizhi", "xiandao_shentong", "bingqi_liupai"}
CURRENCY_SET = {"LING", "YUAN", "ling", "yuan"}
ITEM_SET = {"yuan_shard", "exp_book", "artifact_mat", "skill_mat"}
ERRORS = []


def err(msg: str) -> None:
    ERRORS.append(msg)


def load_json(path: str):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:  # noqa: BLE001
        err(f"{os.path.basename(path)}: JSON 解析失败: {e}")
        return None


def check_common(tbl: dict, filename: str) -> None:
    if not isinstance(tbl, dict):
        err(f"{filename}: 顶层必须为对象")
        return
    sv = tbl.get("schema_version")
    if not isinstance(sv, int) or sv < 1:
        err(f"{filename}: schema_version 必须为 >=1 整数")
    table = tbl.get("table")
    expect = filename.replace(".json", "")
    if table != expect:
        err(f"{filename}: table 字段应为 '{expect}'，实际 '{table}'")


def check_realm(tbl: dict) -> None:
    realms = tbl.get("realms", [])
    realm_ids = set()
    sub_ids = set()
    for r in realms:
        if r.get("id") not in realm_ids:
            realm_ids.add(r.get("id"))
        for s in r.get("sub_stages", []):
            if s.get("id") not in sub_ids:
                sub_ids.add(s.get("id"))
    costs = tbl.get("breakthrough_costs", [])
    if len(costs) != 9:
        err(f"realm: breakthrough_costs 应为 9 条（MVP 轮海4+道宫5），实际 {len(costs)}")
    for c in costs:
        for field in ("sub_index", "cost_ling", "cost_yuan", "stage_req"):
            if field not in c:
                err(f"realm: breakthrough_costs 缺少字段 {field}: {c}")
    params = tbl.get("params", {})
    for key in ("R0", "B", "sub_bonus", "eff_offline", "cap_offline_sec"):
        if key not in params:
            err(f"realm: params 缺少 {key}")
    # 供其他表引用
    tbl["_registry"] = {"realm_ids": realm_ids, "sub_ids": sub_ids}


def check_battle(tbl: dict) -> None:
    counter = tbl.get("counter", {})
    for cls in CLASS_SET:
        if cls not in counter:
            err(f"battle: counter 缺少职业 {cls}")
            continue
        row = counter[cls]
        if set(row.keys()) != CLASS_SET:
            err(f"battle: counter[{cls}] 必须覆盖三职业")
        for v in row.values():
            if v not in (1.0, 1.50, 0.67):
                err(f"battle: counter[{cls}] 克制倍率非法: {v}")
    dmg = tbl.get("damage", {})
    if dmg.get("k_def") != 300:
        err("battle: damage.k_def 应为 300（GDD-003 §5.1）")
    energy = tbl.get("energy", {})
    for key in ("cap", "recover_per_sec", "free_claim_daily", "free_claim_amount",
                "paid_claim_daily", "paid_claim_amount", "stage_cost"):
        if key not in energy:
            err(f"battle: energy 缺少 {key}")
    for s in tbl.get("stages", []):
        for field in ("id", "chapter", "order", "turn_limit"):
            if field not in s:
                err(f"battle: stage {s.get('id')} 缺少字段 {field}")


def check_drop(tbl: dict, registry: dict) -> None:
    realm_ids = registry["realm_ids"]
    sub_ids = registry["sub_ids"]
    unlock_ids = realm_ids | sub_ids
    for d in tbl.get("dungeons", []):
        for field in ("id", "energy_cost", "daily_limit", "tiers"):
            if field not in d:
                err(f"drop: dungeon {d.get('id')} 缺少字段 {field}")
        for t in d.get("tiers", []):
            u = t.get("unlock_realm")
            if u and u not in unlock_ids:
                err(f"drop: dungeon {d.get('id')} tier{t.get('tier')} unlock_realm '{u}' 未注册")
            for drop in t.get("drops", []):
                dtype = drop.get("type")
                if dtype not in CURRENCY_SET and dtype not in ITEM_SET:
                    err(f"drop: dungeon {d.get('id')} 掉落类型 '{dtype}' 未注册")
                if drop.get("min", -1) > drop.get("max", 0):
                    err(f"drop: dungeon {d.get('id')} min>max: {drop}")


def check_character(tbl: dict) -> None:
    order = tbl.get("rarity_order", [])
    if set(order) != RARITY_SET:
        err("character: rarity_order 必须为六档（凡→帝品）")
    for c in tbl.get("characters", []):
        if c.get("rarity") not in RARITY_SET:
            err(f"character: {c.get('id')} rarity '{c.get('rarity')}' 非法")
        if c.get("class") not in CLASS_SET:
            err(f"character: {c.get('id')} class '{c.get('class')}' 非法")
        for field in ("base", "growth", "skills"):
            if field not in c:
                err(f"character: {c.get('id')} 缺少字段 {field}")
        if len(c.get("skills", [])) != 3:
            err(f"character: {c.get('id')} 技能数应为 3（GDD-003 §3.6）")


def check_gacha(tbl: dict) -> None:
    for p in tbl.get("pools", []):
        prob = p.get("rarity_prob", {})
        total = sum(prob.values())
        if abs(total - 1.0) > 0.0001:
            err(f"gacha: pool {p.get('id')} 概率和 {total} ≠ 1.0")
        if p.get("pity_di") != 60 or p.get("pity_tian") != 90:
            err(f"gacha: pool {p.get('id')} 保底应为 60 地/90 天（GDD-002 §3.1.2）")


def check_constants(tbl: dict) -> None:
    cur = tbl.get("currencies", {})
    if "LING" not in cur or "YUAN" not in cur:
        err("constants: 双币 LING/YUAN 必须存在")
    for key in ("defaults", "limits", "economy_redlines"):
        if key not in tbl:
            err(f"constants: 缺少 {key}")


def check_equipment(tbl: dict) -> None:
    """装备表校验（V4 新表）：槽位枚举 / item 字段 / slot 引用合法"""
    slots = {s.get("id") for s in tbl.get("slots", [])}
    if not slots:
        err("equipment: slots 不能为空")
    items = tbl.get("items", [])
    if not items:
        err("equipment: items 不能为空")
    for it in items:
        for f in ("id", "name", "slot", "rarity", "base_atk", "base_def", "base_hp", "growth", "max_level"):
            if f not in it:
                err(f"equipment.items[{it.get('id','?')}]: 缺少字段 {f}")
        if it.get("slot") not in slots:
            err(f"equipment.items[{it.get('id','?')}]: slot 引用不存在 {it.get('slot')}")
    if "enhance" not in tbl:
        err("equipment: 缺少 enhance 规则")
    elif "ling_cost_per_level" not in tbl["enhance"]:
        err("equipment.enhance: 缺少 ling_cost_per_level")


def check_skill_sets(tbl: dict) -> None:
    """功法表校验（V4 新表）：分类枚举 / book 字段 / effect 合法"""
    cats = {c.get("id") for c in tbl.get("categories", [])}
    if not cats:
        err("skill_sets: categories 不能为空")
    books = tbl.get("books", [])
    if not books:
        err("skill_sets: books 不能为空")
    for b in books:
        for f in ("id", "name", "category", "rarity", "effect", "value", "max_level"):
            if f not in b:
                err(f"skill_sets.books[{b.get('id','?')}]: 缺少字段 {f}")
        if b.get("category") not in cats:
            err(f"skill_sets.books[{b.get('id','?')}]: category 引用不存在 {b.get('category')}")
    if "train" not in tbl:
        err("skill_sets: 缺少 train 规则")
    elif "ling_cost_per_level" not in tbl["train"]:
        err("skill_sets.train: 缺少 ling_cost_per_level")


def main() -> int:
    tables_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(__file__), "..", "data", "tables")
    tables_dir = os.path.abspath(tables_dir)
    if not os.path.isdir(tables_dir):
        print(f"错误：数据表目录不存在 {tables_dir}")
        return 1

    data = {}
    for filename in sorted(os.listdir(tables_dir)):
        if not filename.endswith(".json"):
            continue
        path = os.path.join(tables_dir, filename)
        tbl = load_json(path)
        if tbl is None:
            continue
        check_common(tbl, filename)
        data[filename.replace(".json", "")] = tbl

    missing = REQUIRED_TABLES - set(data.keys())
    if missing:
        err(f"缺少必需数据表: {sorted(missing)}")

    # 注册表 + 各表专项校验
    if "realm" in data:
        check_realm(data["realm"])
    registry = data.get("realm", {}).get("_registry", {"realm_ids": set(), "sub_ids": set()})
    if "battle" in data:
        check_battle(data["battle"])
    if "drop" in data:
        check_drop(data["drop"], registry)
    if "character" in data:
        check_character(data["character"])
    if "gacha" in data:
        check_gacha(data["gacha"])
    if "constants" in data:
        check_constants(data["constants"])
    if "equipment" in data:
        check_equipment(data["equipment"])
    if "skill_sets" in data:
        check_skill_sets(data["skill_sets"])

    if ERRORS:
        print(f"❌ 数据表校验失败（{len(ERRORS)} 项）：")
        for e in ERRORS:
            print(f"  - {e}")
        return 1
    print(f"✅ 数据表校验通过（{len(data)} 张表）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
