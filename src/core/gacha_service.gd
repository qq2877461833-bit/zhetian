class_name GachaService
extends RefCounted
## 抽卡服务（核心层 · 纯逻辑）· Sprint 2 改版为宝物池
## REQ-002-3.1.2：概率公开 + 保底 60 地 / 90 天（跨池继承）+ 卡池分段 + 源石碎片副产物
## 宝物池：帝兵（装备）/ 功法 / 材料（角色池已废弃，单主角体系不抽角色）
## 服务端权威（ADR-0003 防篡改点③）：本实现为本地 mock，服务端 RNG 后续替换

var _gacha_tbl: Dictionary


func _init(gacha_tbl: Dictionary = {}) -> void:
	_gacha_tbl = gacha_tbl


## 抽卡一次：返回 { ok, rarity, type, item_id, yuan_shards }
## type: equipment / skill / material
## 保底逻辑：di_pity 计数达 60 必出 ≥地；tian_pity 达 90 必出 ≥天
## 保底为全局共享（GDD-002 拍板：跨池继承）——存 model.gacha["global"]
func draw(model: SaveModel, pool_id: String, rng: RandomNumberGenerator, hero_sub: int = 8) -> Dictionary:
	var pool := _find_pool(pool_id)
	if pool.is_empty():
		return { "ok": false, "reason": "pool_not_found" }
	var pity: Dictionary = model.gacha.get("global", { "di_pity": 0, "tian_pity": 0 })
	var di_pity := int(pity.get("di_pity", 0)) + 1
	var tian_pity := int(pity.get("tian_pity", 0)) + 1

	var rarity: String
	if tian_pity >= 90:
		rarity = _tier_tian()
	elif di_pity >= 60:
		rarity = _tier_di_or_above(pool)
	else:
		rarity = _roll_rarity(pool, rng, hero_sub)

	## 保底计数：出天品/帝品重置 tian，出地及以上重置 di
	if _is_tian_or_above(rarity):
		tian_pity = 0
	if _is_di_or_above(rarity):
		di_pity = 0

	model.gacha["global"] = { "di_pity": di_pity, "tian_pity": tian_pity }
	var treasure := _pick_treasure(pool, rarity, rng)
	var shards := 1  ## 源石碎片副产物（REQ-002-3.1.2）
	return { "ok": true, "rarity": rarity, "type": treasure.get("type", "material"), "item_id": treasure.get("id", ""), "yuan_shards": shards }


## 卡池分段（REQ-002-3.1.2 拍板）：轮海期仅 凡/灵/玄；道宫后开 地/天
## G-03 修复：实现 open_di_tian_after 分段——hero_sub < 道宫(sub_index>=6) 时不抽地/天
func _roll_rarity(pool: Dictionary, rng: RandomNumberGenerator, hero_sub: int = 8) -> String:
	var prob: Dictionary = pool.get("rarity_prob", {})
	var unlocked := _di_tian_unlocked(pool, hero_sub)
	var r := rng.randf()
	var acc := 0.0
	for rar in ["fan", "ling", "xuan", "di", "tian", "di_pin"]:
		if not unlocked and (rar == "di" or rar == "tian" or rar == "di_pin"):
			continue  ## 未到道宫：地/天/帝品概率并入凡品
		acc += float(prob.get(rar, 0.0))
		if r <= acc:
			return rar
	return "fan"


## 道宫后解锁地/天（GDD 分段拍板：轮海→仙台为凡/灵/玄；道宫起开地/天）
func _di_tian_unlocked(pool: Dictionary, hero_sub: int) -> bool:
	var seg: Dictionary = pool.get("segment", {})
	var after := String(seg.get("open_di_tian_after", "daogong"))
	## realm.json 顺序：轮海0-3 / 命泉4-7 / 道宫8-11（sub_index 8=道宫·心藏起）
	if after == "daogong":
		return hero_sub >= 8
	return hero_sub >= 8


func _tier_di_or_above(pool: Dictionary) -> String:
	## 保底 60：必出 ≥地（地 80% / 天 19% / 帝 1%）
	var r := RandomNumberGenerator.new()
	r.randomize()
	var x := r.randf()
	if x < 0.80:
		return "di"
	if x < 0.99:
		return "tian"
	return "di_pin"


func _tier_tian() -> String:
	## 保底 90：必出 ≥天（天 70% / 帝 30%）
	var r := RandomNumberGenerator.new()
	r.randomize()
	return "tian" if r.randf() < 0.70 else "di_pin"


func _is_tian_or_above(rarity: String) -> bool:
	return rarity == "tian" or rarity == "di_pin"


func _is_di_or_above(rarity: String) -> bool:
	return rarity == "di" or rarity == "tian" or rarity == "di_pin"


func _pick_treasure(pool: Dictionary, rarity: String, rng: RandomNumberGenerator) -> Dictionary:
	## 从宝物池按稀有度筛选（优先返回装备/功法，无则材料安慰奖）
	var treasures: Array = pool.get("treasures", [])
	var candidates: Array = []
	for t in treasures:
		if t.get("rarity") == rarity:
			candidates.append(t)
	if candidates.is_empty():
		## 该稀有度无对应宝物 → 材料转化
		return { "type": "material", "id": "mat_ling_pack", "rarity": rarity }
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _find_pool(pool_id: String) -> Dictionary:
	for p in _gacha_tbl.get("pools", []):
		if p.get("id") == pool_id:
			return p
	return {}
