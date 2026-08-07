class_name EquipmentService
extends RefCounted
## 装备培养服务（核心层 · 纯逻辑）· 单主角修仙
## 强化（灵石消耗×1.3 每级）+ 升阶（每 10 级一阶，消耗源石 1/3/5/8/13）+ 附魔（后续）
## 数据来源：data/tables/equipment.json（唯一事实来源）

var _equip_tbl: Dictionary


func _init(equip_tbl: Dictionary = {}) -> void:
	_equip_tbl = equip_tbl


func find_item(item_id: String) -> Dictionary:
	for e in _equip_tbl.get("items", []):
		if String(e.get("id", "")) == item_id:
			return e
	return {}


## 强化：消耗灵石，提升装备等级和属性
## 返回 { ok, level, cost, atk_bonus, def_bonus, hp_bonus, reason }
func enhance(model: SaveModel, slot_id: String) -> Dictionary:
	var item_id := String(model.equipment.get(slot_id, ""))
	if item_id.is_empty():
		return { "ok": false, "reason": "no_item" }
	var item := find_item(item_id)
	if item.is_empty():
		return { "ok": false, "reason": "item_not_found" }
	var lv := int(model.stats.get("eq_lv_%s" % slot_id, 1))
	var max_lv := int(item.get("max_level", 20))
	if lv >= max_lv:
		return { "ok": false, "reason": "max_level" }
	var enhance: Dictionary = _equip_tbl.get("enhance", {})
	var cost := int(float(enhance.get("ling_cost_per_level", 1000)) * pow(float(enhance.get("ling_growth", 1.3)), lv - 1))
	if model.ling < cost:
		return { "ok": false, "reason": "no_ling", "need": cost }
	model.ling -= cost
	lv += 1
	model.stats["eq_lv_%s" % slot_id] = lv
	## 属性增益 = base × (1 + growth × (lv-1))
	var base_atk := float(item.get("base_atk", 0))
	var base_def := float(item.get("base_def", 0))
	var base_hp := float(item.get("base_hp", 0))
	var growth := float(item.get("growth", 0.10))
	var atk_bonus := int(base_atk * growth * (lv - 1))
	var def_bonus := int(base_def * growth * (lv - 1))
	var hp_bonus := int(base_hp * growth * (lv - 1))
	return { "ok": true, "level": lv, "cost": cost, "atk_bonus": atk_bonus, "def_bonus": def_bonus, "hp_bonus": hp_bonus }


## 装备/卸下物品
func equip(model: SaveModel, slot_id: String, item_id: String) -> Dictionary:
	var item := find_item(item_id)
	if item.is_empty():
		return { "ok": false, "reason": "item_not_found" }
	if String(item.get("slot", "")) != slot_id:
		return { "ok": false, "reason": "slot_mismatch", "expect": item.get("slot") }
	model.equipment[slot_id] = item_id
	return { "ok": true, "item": item_id }


## 装备总属性加成（供战斗用）——含新属性：特攻/暴击率/暴击伤害/闪避率
func total_bonus(model: SaveModel) -> Dictionary:
	var bonus := { "atk": 0, "matk": 0, "def": 0, "hp": 0, "crit_rate": 0.0, "crit_dmg": 0.0, "dodge": 0.0 }
	for slot_id in model.equipment:
		var item_id := String(model.equipment.get(slot_id, ""))
		if item_id.is_empty():
			continue
		var item := find_item(item_id)
		if item.is_empty():
			continue
		var lv := int(model.stats.get("eq_lv_%s" % slot_id, 1))
		var growth := float(item.get("growth", 0.10))
		bonus["atk"] += int(float(item.get("base_atk", 0)) * (1.0 + growth * (lv - 1)))
		bonus["matk"] += int(float(item.get("base_matk", 0)) * (1.0 + growth * (lv - 1)))
		bonus["def"] += int(float(item.get("base_def", 0)) * (1.0 + growth * (lv - 1)))
		bonus["hp"]  += int(float(item.get("base_hp", 0))  * (1.0 + growth * (lv - 1)))
		## 固定值加成（不随等级成长：暴击/暴伤/闪避）
		bonus["crit_rate"] += float(item.get("crit_rate", 0.0))
		bonus["crit_dmg"] += float(item.get("crit_dmg", 0.0))
		bonus["dodge"] += float(item.get("dodge", 0.0))
	return bonus
