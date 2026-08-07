# -*- coding: utf-8 -*-
"""重写 _draw_one：抽卡产物入背包 + 重复转命座/残卷/碎片"""
import io

p = 'src/main.gd'
s = io.open(p, encoding='utf-8').read()

old = '''func _draw_one(pool: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var pid := String(pool.get("id", "standard"))
	var r := _gacha_svc.draw(_model, pid, rng)
	if not r.get("ok", false):
		return { "ok": false, "rarity": "fan", "item_id": "", "type": "material", "yuan_shards": 0, "fresh": 0 }
	var iid := String(r.get("item_id", ""))
	var itype := String(r.get("type", "material"))
	var fresh := 0
	if itype == "equipment":
		## 帝兵：新装备解锁槽位（已解锁转材料）
		var item := _eq_svc.find_item(iid)
		if item.is_empty():
			return { "ok": true, "rarity": String(r.get("rarity", "fan")), "item_id": iid, "type": itype, "yuan_shards": 1, "fresh": 0 }
		var slot_id := String(item.get("slot", ""))
		if not slot_id.is_empty() and not _model.equipment.has(slot_id):
			_model.equipment[slot_id] = iid
			fresh = 1
		else:
			_model.stats["mat_ling"] = int(_model.stats.get("mat_ling", 0)) + 500
	elif itype == "skill":
		## 功法：新功法解锁（已解锁转材料）
		if not _model.active_skills.has(iid):
			_model.stats["unlocked_skills"] = String(_model.stats.get("unlocked_skills", "")) + "," + iid
			fresh = 1
		else:
			_model.stats["mat_ling"] = int(_model.stats.get("mat_ling", 0)) + 300
	else:
		## 材料安慰奖
		_model.stats["mat_ling"] = int(_model.stats.get("mat_ling", 0)) + 800
	return { "ok": true, "rarity": String(r.get("rarity", "fan")), "item_id": iid, "type": itype, "yuan_shards": 1, "fresh": fresh }'''

new = '''func _draw_one(pool: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var pid := String(pool.get("id", "standard"))
	var r := _gacha_svc.draw(_model, pid, rng)
	if not r.get("ok", false):
		return { "ok": false, "rarity": "fan", "item_id": "", "type": "material", "yuan_shards": 0, "fresh": 0, "dup": 0 }
	var iid := String(r.get("item_id", ""))
	var itype := String(r.get("type", "material"))
	var fresh := 0
	var dup := 0
	## 背包入账（先入包，所有宝物/材料都可见）
	_model.inventory[iid] = int(_model.inventory.get(iid, 0)) + 1
	if itype == "equipment":
		## 帝兵：新装备解锁槽位；重复 → 装备残卷（强化材料）
		var item := _eq_svc.find_item(iid)
		if item.is_empty():
			return { "ok": true, "rarity": String(r.get("rarity", "fan")), "item_id": iid, "type": itype, "yuan_shards": 1, "fresh": 0, "dup": 0 }
		var slot_id := String(item.get("slot", ""))
		if not slot_id.is_empty() and not _model.equipment.has(slot_id):
			_model.equipment[slot_id] = iid
			fresh = 1
		else:
			dup = 1
			_model.inventory["mat_equip_shard"] = int(_model.inventory.get("mat_equip_shard", 0)) + 1
	elif itype == "skill":
		## 功法：新功法解锁；重复 → 命座 +1（强化功法效果）
		var book := _sk_svc.find_book(iid)
		if book.is_empty():
			return { "ok": true, "rarity": String(r.get("rarity", "fan")), "item_id": iid, "type": itype, "yuan_shards": 1, "fresh": 0, "dup": 0 }
		if not _model.active_skills.has(iid) and not String(_model.stats.get("unlocked_skills", "")).split(",", false).has(iid):
			_model.stats["unlocked_skills"] = String(_model.stats.get("unlocked_skills", "")) + "," + iid
			fresh = 1
		else:
			dup = 1
			## 命座 1-6 阶，满命后转残卷材料
			var con := int(_model.stats.get("sk_con_%s" % iid, 0))
			if con < 6:
				_model.stats["sk_con_%s" % iid] = con + 1
			else:
				_model.inventory["mat_skill_shard"] = int(_model.inventory.get("mat_skill_shard", 0)) + 1
	else:
		## 材料安慰奖
		pass
	return { "ok": true, "rarity": String(r.get("rarity", "fan")), "item_id": iid, "type": itype, "yuan_shards": 1, "fresh": fresh, "dup": dup }'''

assert old in s, "draw_one pattern not found"
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8').write(s)
print("_draw_one 重写完成（背包+命座+残卷）")
