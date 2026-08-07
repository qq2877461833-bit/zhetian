# -*- coding: utf-8 -*-
"""改抽卡为宝物池（main.gd）"""
import io

p = 'src/main.gd'
s = io.open(p, encoding='utf-8').read()

# 1. _draw_one
old_draw = '''func _draw_one(pool: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var pid := String(pool.get("id", "standard"))
	var r := _gacha_svc.draw(_model, pid, rng)
	if not r.get("ok", false):
		return { "ok": false, "rarity": "fan", "char_id": "", "yuan_shards": 0, "fresh": 0 }
	var cid := String(r.get("char_id", ""))
	if cid.is_empty():
		## 池内无可抽角色（数据缺失兜底）
		return { "ok": true, "rarity": String(r.get("rarity", "fan")), "char_id": "", "yuan_shards": 1, "fresh": 0 }
	## 新角色入图鉴；重复角色转碎片
	var fresh := 0
	if not _model.characters.has(cid):
		_model.add_character(cid)
		fresh = 1
	else:
		var c: Dictionary = _model.get_character(cid)
		c["fragments"] = int(c.get("fragments", 0)) + 1
		_model.characters[cid] = c
	return { "ok": true, "rarity": String(r.get("rarity", "fan")), "char_id": cid, "yuan_shards": 1, "fresh": fresh }'''

new_draw = '''func _draw_one(pool: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
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

assert old_draw in s, "draw_one pattern not found"
s = s.replace(old_draw, new_draw)

# 2. _show_last_result
old_last = '''func _show_last_result(last: Dictionary) -> void:
	var cid := String(last.get("char_id", ""))
	if cid.is_empty():
		_gacha_stage.texture = _ziqi_frames[0] if not _ziqi_frames.is_empty() else null
		return
	var tex: Texture2D = load(_char_card_path(cid))
	_gacha_stage.texture = tex if tex != null else (_ziqi_frames[0] if not _ziqi_frames.is_empty() else null)'''

new_last = '''func _show_last_result(last: Dictionary) -> void:
	var iid := String(last.get("item_id", ""))
	var itype := String(last.get("type", "material"))
	if iid.is_empty() or itype == "material":
		_gacha_stage.texture = _ziqi_frames[0] if not _ziqi_frames.is_empty() else null
		return
	var tex: Texture2D = load(_treasure_icon_path(itype, iid))
	_gacha_stage.texture = tex if tex != null else (_ziqi_frames[0] if not _ziqi_frames.is_empty() else null)'''

assert old_last in s, "last pattern not found"
s = s.replace(old_last, new_last)

# 3. 汇总文案
old_sum = '''		var cid := String(r.get("char_id", ""))
		if cid.is_empty():
			lines.append("（空位）%s" % _rarity_name(rar))
		else:
			var fresh := "（新）" if int(r.get("fresh", 0)) > 0 else ""
			lines.append("%s %s%s" % [_rarity_name(rar), _char_name(cid), fresh])'''

new_sum = '''		var iid := String(r.get("item_id", ""))
		var itype := String(r.get("type", "material"))
		var fresh := "（新）" if int(r.get("fresh", 0)) > 0 else ""
		lines.append("%s %s%s" % [_rarity_name(rar), _treasure_name(itype, iid), fresh])'''

assert old_sum in s, "summary pattern not found"
s = s.replace(old_sum, new_sum)

io.open(p, 'w', encoding='utf-8').write(s)
print("main.gd 宝物抽卡改造完成")
