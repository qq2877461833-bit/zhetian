# -*- coding: utf-8 -*-
"""升级 _show_hero_detail 为完整属性面板"""
import io

p = 'src/main.gd'
s = io.open(p, encoding='utf-8').read()

old_start = s.find('func _show_hero_detail() -> void:')
old_end = s.find('# --------------------------- 主界面（修炼） ---------------------------')
assert old_start > 0 and old_end > old_start

new_func = '''func _show_hero_detail() -> void:
	## 完整属性面板（境界/五维/装备明细/功法明细/战力）
	var hero_def: Dictionary = _char_def(HERO_ID)
	var base: Dictionary = hero_def.get("base", {})
	var base_atk := float(base.get("atk", 120))
	var base_def := float(base.get("def", 80))
	var base_hp := float(base.get("hp", 1500))
	var base_spd := float(base.get("spd", 100))
	var equip := _eq_svc.total_bonus(_model)
	var sk := _sk_svc.total_bonus(_model)
	var total_atk := int(base_atk * (1.0 + sk.atk)) + int(equip.atk)
	var total_def := int(base_def) + int(equip.def)
	var total_hp := int(base_hp) + int(equip.hp)
	var c := _model.get_character(HERO_ID)
	var sub := int(c.get("sub_index", 0))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.custom_minimum_size = Vector2(430, 0)

	var head := _mk_title("叶凡 · %s" % _realm_name(), 22)
	box.add_child(head)
	box.add_child(_mk_dim("境界进度：%s / %s · 修炼速率 +%.1f 灵/秒" % [_sub_name(sub), _next_sub_name(sub), _sum_rate()], 14))

	var sec1 := _mk_label("—— 五维属性 ——", 15)
	sec1.add_theme_color_override("font_color", C_GOLD)
	box.add_child(sec1)
	box.add_child(_mk_label("攻击 %d  = 基础 %d × 功法x%.2f + 装备 %d" % [total_atk, int(base_atk), 1.0 + sk.atk, equip.atk], 14))
	box.add_child(_mk_label("防御 %d  = 基础 %d + 装备 %d" % [total_def, int(base_def), equip.def], 14))
	box.add_child(_mk_label("生命 %d  = 基础 %d + 装备 %d" % [total_hp, int(base_hp), equip.hp], 14))
	box.add_child(_mk_label("速度 %d（行动条基础，越高越先手）" % int(base_spd), 14))

	var sec2 := _mk_label("—— 装备加成 ——", 15)
	sec2.add_theme_color_override("font_color", C_GOLD)
	box.add_child(sec2)
	for sl in _eq_tbl.get("slots", []):
		var sid := String(sl.get("id", ""))
		var item_id := String(_model.equipment.get(sid, ""))
		if item_id.is_empty():
			box.add_child(_mk_dim("%s：未装备" % sl.get("name", sid), 13))
			continue
		var item := _eq_svc.find_item(item_id)
		var lv := int(_model.stats.get("eq_lv_%s" % sid, 1))
		var growth := float(item.get("growth", 0.10))
		var atk_b := int(float(item.get("base_atk", 0)) * (1.0 + growth * (lv - 1)))
		var def_b := int(float(item.get("base_def", 0)) * (1.0 + growth * (lv - 1)))
		var hp_b := int(float(item.get("base_hp", 0)) * (1.0 + growth * (lv - 1)))
		box.add_child(_mk_label("%s：%s Lv.%d（攻+%d 防+%d 血+%d）" % [sl.get("name", sid), item.get("name", item_id), lv, atk_b, def_b, hp_b], 13))

	var sec3 := _mk_label("—— 功法加成（已装备）——", 15)
	sec3.add_theme_color_override("font_color", C_GOLD)
	box.add_child(sec3)
	if _model.active_skills.is_empty():
		box.add_child(_mk_dim("未装备任何功法", 13))
	else:
		for sid2 in _model.active_skills:
			var bk := _sk_svc.find_book(String(sid2))
			if bk.is_empty():
				continue
			var lv2 := int(_model.stats.get("sk_lv_%s" % sid2, 1))
			var con := int(_model.stats.get("sk_con_%s" % sid2, 0))
			var eff_name := {"idle_rate": "修炼速率", "atk_bonus": "攻击力", "energy_recover": "体力恢复", "yuan_bonus": "源石收益"}
			var eff_txt := "%s +%d%%" % [eff_name.get(String(bk.get("effect", "")), "?"), int(float(bk.get("value", 0.0)) * lv2 * (1.0 + 0.5 * con) * 100)]
			box.add_child(_mk_label("%s Lv.%d%s：%s" % [bk.get("name", "?"), lv2, " 命座%d" % con if con > 0 else "", eff_txt], 13))

	var sec4 := _mk_label("—— 战力 ——", 15)
	sec4.add_theme_color_override("font_color", C_GOLD)
	box.add_child(sec4)
	box.add_child(_mk_label("合计战力：%d（攻×2 + 防×1.5 + 血×0.05）" % int(_team_power()), 16))
	box.add_child(_mk_label("装备强化提升战力 · 功法修炼/命座大幅加成" % [], 13))
	_show_custom_popup("主角属性", box, func() -> bool: return true)


func _next_sub_name(sub: int) -> String:
	if sub >= 8:
		return "已满"
	return _sub_name(sub + 1)


'''
s = s[:old_start] + new_func + s[old_end:]
io.open(p, 'w', encoding='utf-8').write(s)
print("hero detail panel upgraded")
