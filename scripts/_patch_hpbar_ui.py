# -*- coding: utf-8 -*-
"""演出加双血条：hero/enemy HP 条 + 按真实伤害扣血"""
import io

p = 'src/main.gd'
s = io.open(p, encoding='utf-8').read()

# 在 ok_btn 加入后、_battle_layer.visible = true 之前插入血条创建
old_anchor = '''	ok_btn.position.y += 215
	field.add_child(ok_btn)

	_battle_layer.visible = true
	var win := String(result.get("winner", "")) == "player"
	var rounds := int(result.get("rounds", 1))
	var hero_home := hero_img.position
	var enemy_home := enemy_img.position'''

new_anchor = '''	ok_btn.position.y += 215
	field.add_child(ok_btn)

	## 双血条（主角左 / 敌人右，显示 HP 数值）
	var hero_max := maxf(float(result.get("hero_max", 1500)), 1.0)
	var enemy_max := maxf(float(result.get("enemy_max", 1000)), 1.0)
	var hero_cur := float(result.get("hero_hp", hero_max))
	var enemy_cur := float(result.get("enemy_hp", enemy_max))
	var hero_bar := ProgressBar.new()
	hero_bar.max_value = hero_max
	hero_bar.value = hero_max
	hero_bar.custom_minimum_size = Vector2(170, 16)
	hero_bar.position = Vector2(vw * 0.5 - 195, vh * 0.5 + 62)
	hero_bar.show_percentage = false
	field.add_child(hero_bar)
	var hero_bar_txt := _mk_label("", 12)
	hero_bar_txt.position = Vector2(vw * 0.5 - 195, vh * 0.5 + 80)
	field.add_child(hero_bar_txt)
	hero_bar_txt.text = "HP %d/%d" % [int(hero_max), int(hero_max)]
	var enemy_bar := ProgressBar.new()
	enemy_bar.max_value = enemy_max
	enemy_bar.value = enemy_max
	enemy_bar.custom_minimum_size = Vector2(170, 16)
	enemy_bar.position = Vector2(vw * 0.5 + 25, vh * 0.5 + 62)
	enemy_bar.show_percentage = false
	field.add_child(enemy_bar)
	var enemy_bar_txt := _mk_label("", 12)
	enemy_bar_txt.position = Vector2(vw * 0.5 + 25, vh * 0.5 + 80)
	field.add_child(enemy_bar_txt)
	enemy_bar_txt.text = "HP %d/%d" % [int(enemy_max), int(enemy_max)]
	## 血条颜色（主角月白绿 / 敌人朱砂）
	var hero_style := StyleBoxFlat.new()
	hero_style.bg_color = Color(0.2, 0.3, 0.25, 1.0)
	hero_style.set_corner_radius_all(3)
	hero_bar.add_theme_stylebox_override("background", hero_style)
	var hero_fill := StyleBoxFlat.new()
	hero_fill.bg_color = Color(0.5, 0.8, 0.55, 1.0)
	hero_fill.set_corner_radius_all(3)
	hero_bar.add_theme_stylebox_override("fill", hero_fill)
	var enemy_style := StyleBoxFlat.new()
	enemy_style.bg_color = Color(0.3, 0.16, 0.14, 1.0)
	enemy_style.set_corner_radius_all(3)
	enemy_bar.add_theme_stylebox_override("background", enemy_style)
	var enemy_fill := StyleBoxFlat.new()
	enemy_fill.bg_color = Color(0.85, 0.35, 0.3, 1.0)
	enemy_fill.set_corner_radius_all(3)
	enemy_bar.add_theme_stylebox_override("fill", enemy_fill)
	## 演出用伤害序列（与模拟一致；不足 2 回合用兜底）
	var hero_dmgs: Array = result.get("hero_dmgs", [150.0, 120.0])
	var enemy_dmgs: Array = result.get("enemy_dmgs", [300.0, 200.0])
	var hero_left := hero_cur
	var enemy_left := enemy_cur

	_battle_layer.visible = true
	var win := String(result.get("winner", "")) == "player"
	var rounds := int(result.get("rounds", 1))
	var hero_home := hero_img.position
	var enemy_home := enemy_img.position'''

assert old_anchor in s, "anchor not found"
s = s.replace(old_anchor, new_anchor)
io.open(p, 'w', encoding='utf-8').write(s)
print("血条 UI 已插入")
