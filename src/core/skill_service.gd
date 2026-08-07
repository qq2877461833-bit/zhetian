class_name SkillService
extends RefCounted
## 功法修炼服务（核心层 · 纯逻辑）· 单主角修仙
## 获取秘笈 → 修炼突破 → 装备生效（最多 3 个）
## 数据来源：data/tables/skill_sets.json（唯一事实来源）

var _skill_tbl: Dictionary

func _init(skill_tbl: Dictionary = {}) -> void:
	_skill_tbl = skill_tbl

func find_book(book_id: String) -> Dictionary:
	for b in _skill_tbl.get("books", []):
		if String(b.get("id", "")) == book_id:
			return b
	return {}

func train(model: SaveModel, book_id: String) -> Dictionary:
	var book := find_book(book_id)
	if book.is_empty():
		return {"ok": false, "reason": "book_not_found"}
	var lv_key := "sk_lv_%s" % book_id
	var lv := int(model.stats.get(lv_key, 1))
	var max_lv := int(book.get("max_level", 10))
	if lv >= max_lv:
		return {"ok": false, "reason": "max_level"}
	var train: Dictionary = _skill_tbl.get("train", {})
	var cost := int(float(train.get("ling_cost_per_level", 800)) * pow(float(train.get("ling_growth", 1.25)), lv - 1))
	if model.ling < cost:
		return {"ok": false, "reason": "no_ling", "need": cost}
	model.ling -= cost
	## 功法残卷消耗：Lv≥5 后每级需 1 残卷（重复抽功法满命转化）
	var shard_cost := 0
	if lv >= 5:
		shard_cost = 1
		if int(model.inventory.get("mat_skill_shard", 0)) < shard_cost:
			model.ling += cost
			return {"ok": false, "reason": "no_shard", "need": shard_cost, "cost": cost}
		model.inventory["mat_skill_shard"] = int(model.inventory.get("mat_skill_shard", 0)) - shard_cost
	lv += 1
	model.stats[lv_key] = lv
	return {"ok": true, "level": lv, "cost": cost, "shard_cost": shard_cost}

func equip_skill(model: SaveModel, book_id: String) -> Dictionary:
	var slots := int(_skill_tbl.get("active_slots", 3))
	if model.active_skills.has(book_id):
		model.active_skills.erase(book_id)
		return {"ok": true, "unequipped": book_id}
	if model.active_skills.size() >= slots:
		return {"ok": false, "reason": "slots_full"}
	var book := find_book(book_id)
	if book.is_empty():
		return {"ok": false, "reason": "book_not_found"}
	model.active_skills.append(book_id)
	return {"ok": true, "equipped": book_id}

func total_bonus(model: SaveModel) -> Dictionary:
	var bonus := {"atk": 0.0, "def": 0.0, "idle_rate": 0.0, "energy": 0.0, "yuan": 0.0}
	for sid in model.active_skills:
		var b := find_book(String(sid))
		if b.is_empty():
			continue
		var lv := int(model.stats.get("sk_lv_%s" % sid, 1))
		## 命座加成：每命座 +50% 效果（1 命=1.5x，6 命=4x）
		var con := int(model.stats.get("sk_con_%s" % sid, 0))
		var con_mult := 1.0 + 0.25 * con
		var val := float(b.get("value", 0.0)) * lv * con_mult
		var effect := String(b.get("effect", ""))
		match effect:
			"atk_bonus": bonus["atk"] += val
			"idle_rate": bonus["idle_rate"] += val
			"energy_recover": bonus["energy"] += val
			"yuan_bonus": bonus["yuan"] += val
	return bonus
