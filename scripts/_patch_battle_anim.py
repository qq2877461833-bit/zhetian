# -*- coding: utf-8 -*-
"""战斗演出加怪物反击：交替回合制"""
import io

p = 'src/main.gd'
s = io.open(p, encoding='utf-8').read()

old = '''	_battle_layer.visible = true
	var win := String(result.get("winner", "")) == "player"
	var rounds := int(result.get("rounds", 1))
	var hero_home := hero_img.position
	var tw := create_tween()
	tw.tween_property(hero_img, "position", Vector2(hero_home.x + 130, hero_home.y), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(hero_img, "position", hero_home, 0.18)
	tw.tween_callback(func() -> void:
		dmg.text = "伤害 %d" % (300 + rounds * 7))
	tw.tween_property(dmg, "modulate:a", 1.0, 0.1)
	tw.tween_property(dmg, "position:y", dmg.position.y - 40, 0.5)
	tw.tween_property(dmg, "modulate:a", 0.0, 0.3)
	tw.tween_property(hero_img, "position", Vector2(hero_home.x + 130, hero_home.y), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(hero_img, "position", hero_home, 0.18)
	tw.tween_callback(func() -> void:
		dmg.text = "伤害 %d" % (200 + rounds * 5))
	tw.tween_property(dmg, "modulate:a", 1.0, 0.1)
	tw.tween_property(dmg, "position:y", dmg.position.y - 40, 0.5)
	tw.tween_property(dmg, "modulate:a", 0.0, 0.3)
	if win:
		tw.tween_property(enemy_img, "position", Vector2(enemy_img.position.x + 40, enemy_img.position.y + 24), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(enemy_img, "modulate:a", 0.3, 0.2)
		tw.tween_callback(func() -> void:
			result_label.text = "胜！%d 回合 · %d 星" % [rounds, int(result.get("stars", 3))])
	else:
		tw.tween_property(hero_img, "position", Vector2(hero_home.x - 40, hero_home.y + 24), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(hero_img, "modulate", Color(0.4, 0.4, 0.4, 1.0), 0.3)
		tw.tween_callback(func() -> void:
			result_label.text = "败 · %d 回合" % rounds)
	tw.tween_callback(func() -> void:
		result_label.text += "\\n" + note)
	ok_btn.modulate.a = 0.0
	tw.tween_property(ok_btn, "modulate:a", 1.0, 0.2)'''

new = '''	_battle_layer.visible = true
	var win := String(result.get("winner", "")) == "player"
	var rounds := int(result.get("rounds", 1))
	var hero_home := hero_img.position
	var enemy_home := enemy_img.position
	## 主角受击闪红（怪物反击时）
	var hero_flash := ColorRect.new()
	hero_flash.color = Color(C_VERMILION.r, C_VERMILION.g, C_VERMILION.b, 0.0)
	hero_flash.size = hero_img.size
	hero_flash.position = hero_home
	field.add_child(hero_flash)
	var enemy_flash := ColorRect.new()
	enemy_flash.color = Color(C_VERMILION.r, C_VERMILION.g, C_VERMILION.b, 0.0)
	enemy_flash.size = enemy_img.size
	enemy_flash.position = enemy_home
	field.add_child(enemy_flash)

	var tw := create_tween()
	## 回合 1：主角攻 → 怪物反击
	tw.tween_property(hero_img, "position", Vector2(hero_home.x + 130, hero_home.y), 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(hero_img, "position", hero_home, 0.16)
	tw.tween_callback(func() -> void:
		dmg.text = "伤害 %d" % (300 + rounds * 7))
	tw.tween_property(dmg, "modulate:a", 1.0, 0.08)
	tw.tween_property(dmg, "position:y", dmg.position.y - 40, 0.5)
	tw.tween_property(dmg, "modulate:a", 0.0, 0.28)
	tw.tween_property(enemy_flash, "color:a", 0.5, 0.06)
	tw.tween_property(enemy_flash, "color:a", 0.0, 0.2)
	## 怪物反击（前冲 + 主角受击闪红 + 敌方飘字）
	tw.tween_property(enemy_img, "position", Vector2(enemy_home.x - 130, enemy_home.y), 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(enemy_img, "position", enemy_home, 0.16)
	tw.tween_callback(func() -> void:
		dmg.text = "敌伤 %d" % (150 + rounds * 4))
	tw.tween_property(dmg, "modulate:a", 1.0, 0.08)
	tw.tween_property(dmg, "position:y", dmg.position.y - 40, 0.5)
	tw.tween_property(dmg, "modulate:a", 0.0, 0.28)
	tw.tween_property(hero_flash, "color:a", 0.45, 0.06)
	tw.tween_property(hero_flash, "color:a", 0.0, 0.2)
	## 回合 2：主角攻 → 怪物反击
	tw.tween_property(hero_img, "position", Vector2(hero_home.x + 130, hero_home.y), 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(hero_img, "position", hero_home, 0.16)
	tw.tween_callback(func() -> void:
		dmg.text = "伤害 %d" % (200 + rounds * 5))
	tw.tween_property(dmg, "modulate:a", 1.0, 0.08)
	tw.tween_property(dmg, "position:y", dmg.position.y - 40, 0.5)
	tw.tween_property(dmg, "modulate:a", 0.0, 0.28)
	tw.tween_property(enemy_flash, "color:a", 0.5, 0.06)
	tw.tween_property(enemy_flash, "color:a", 0.0, 0.2)
	tw.tween_property(enemy_img, "position", Vector2(enemy_home.x - 130, enemy_home.y), 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(enemy_img, "position", enemy_home, 0.16)
	tw.tween_callback(func() -> void:
		dmg.text = "敌伤 %d" % (120 + rounds * 3))
	tw.tween_property(dmg, "modulate:a", 1.0, 0.08)
	tw.tween_property(dmg, "position:y", dmg.position.y - 40, 0.5)
	tw.tween_property(dmg, "modulate:a", 0.0, 0.28)
	tw.tween_property(hero_flash, "color:a", 0.45, 0.06)
	tw.tween_property(hero_flash, "color:a", 0.0, 0.2)
	## 胜负演出
	if win:
		tw.tween_property(enemy_img, "position", Vector2(enemy_home.x + 40, enemy_home.y + 24), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(enemy_img, "modulate:a", 0.3, 0.2)
		tw.tween_callback(func() -> void:
			result_label.text = "胜！%d 回合 · %d 星" % [rounds, int(result.get("stars", 3))])
	else:
		tw.tween_property(hero_img, "position", Vector2(hero_home.x - 40, hero_home.y + 24), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(hero_img, "modulate", Color(0.4, 0.4, 0.4, 1.0), 0.3)
		tw.tween_callback(func() -> void:
			result_label.text = "败 · %d 回合" % rounds)
	tw.tween_callback(func() -> void:
		result_label.text += "\\n" + note)
	ok_btn.modulate.a = 0.0
	tw.tween_property(ok_btn, "modulate:a", 1.0, 0.2)'''

assert old in s, "battle anim pattern not found"
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8').write(s)
print("怪物反击动画已加入")
