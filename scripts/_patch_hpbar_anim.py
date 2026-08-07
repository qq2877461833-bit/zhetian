# -*- coding: utf-8 -*-
"""动画段加血条扣减"""
import io

p = 'src/main.gd'
s = io.open(p, encoding='utf-8').read()

# 回合1主角攻：在 enemy_flash 闪烁后加血条扣减
old1 = '''	tw.tween_property(enemy_flash, "color:a", 0.5, 0.06)
	tw.tween_property(enemy_flash, "color:a", 0.0, 0.2)
	## 怪物反击（前冲 + 主角受击闪红 + 敌方飘字）'''
new1 = '''	tw.tween_property(enemy_flash, "color:a", 0.5, 0.06)
	tw.tween_property(enemy_flash, "color:a", 0.0, 0.2)
	tw.tween_callback(func() -> void:
		enemy_left = maxf(enemy_left - float(enemy_dmgs[0]), 0.0)
		enemy_bar.value = enemy_left
		enemy_bar_txt.text = "HP %d/%d" % [int(enemy_left), int(enemy_max)])
	## 怪物反击（前冲 + 主角受击闪红 + 敌方飘字）'''
assert old1 in s, "seg1 not found"
s = s.replace(old1, new1)

# 怪物反击后：扣主角血
old2 = '''	tw.tween_property(hero_flash, "color:a", 0.45, 0.06)
	tw.tween_property(hero_flash, "color:a", 0.0, 0.2)
	## 回合 2：主角攻 → 怪物反击'''
new2 = '''	tw.tween_property(hero_flash, "color:a", 0.45, 0.06)
	tw.tween_property(hero_flash, "color:a", 0.0, 0.2)
	tw.tween_callback(func() -> void:
		hero_left = maxf(hero_left - float(hero_dmgs[0]), 0.0)
		hero_bar.value = hero_left
		hero_bar_txt.text = "HP %d/%d" % [int(hero_left), int(hero_max)])
	## 回合 2：主角攻 → 怪物反击'''
assert old2 in s, "seg2 not found"
s = s.replace(old2, new2)

# 回合2主角攻后：扣怪物血（用 enemy_dmgs[1]，不足则兜底）
old3 = '''	tw.tween_property(enemy_flash, "color:a", 0.5, 0.06)
	tw.tween_property(enemy_flash, "color:a", 0.0, 0.2)
	tw.tween_property(enemy_img, "position", Vector2(enemy_home.x - 130, enemy_home.y), 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)'''
new3 = '''	tw.tween_property(enemy_flash, "color:a", 0.5, 0.06)
	tw.tween_property(enemy_flash, "color:a", 0.0, 0.2)
	tw.tween_callback(func() -> void:
		var d2 := float(enemy_dmgs[1]) if enemy_dmgs.size() > 1 else 100.0
		enemy_left = maxf(enemy_left - d2, 0.0)
		enemy_bar.value = enemy_left
		enemy_bar_txt.text = "HP %d/%d" % [int(enemy_left), int(enemy_max)])
	tw.tween_property(enemy_img, "position", Vector2(enemy_home.x - 130, enemy_home.y), 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)'''
assert old3 in s, "seg3 not found"
s = s.replace(old3, new3)

# 回合2怪物反击后：扣主角血（用 hero_dmgs[1]）
old4 = '''	tw.tween_property(hero_flash, "color:a", 0.45, 0.06)
	tw.tween_property(hero_flash, "color:a", 0.0, 0.2)
	## 胜负演出'''
new4 = '''	tw.tween_property(hero_flash, "color:a", 0.45, 0.06)
	tw.tween_property(hero_flash, "color:a", 0.0, 0.2)
	tw.tween_callback(func() -> void:
		var d2 := float(hero_dmgs[1]) if hero_dmgs.size() > 1 else 100.0
		hero_left = maxf(hero_left - d2, 0.0)
		hero_bar.value = hero_left
		hero_bar_txt.text = "HP %d/%d" % [int(hero_left), int(hero_max)])
	## 胜负演出'''
assert old4 in s, "seg4 not found"
s = s.replace(old4, new4)

io.open(p, 'w', encoding='utf-8').write(s)
print("血条扣减动画已接入")
