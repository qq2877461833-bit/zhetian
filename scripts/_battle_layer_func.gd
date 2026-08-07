func _show_battle_result(stage_name: String, result: Dictionary, note: String) -> void:
	## 独立演出层（不复用 _popup 常驻结构，避免破坏弹窗引用）
	if _battle_layer == null:
		_battle_layer = Control.new()
		_battle_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_battle_layer.visible = false
		add_child(_battle_layer)
	else:
		for c in _battle_layer.get_children():
			_battle_layer.remove_child(c)
			c.queue_free()

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_battle_layer.add_child(overlay)

	var field := Control.new()
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	_battle_layer.add_child(field)
	var vw := get_viewport_rect().size.x
	var vh := get_viewport_rect().size.y

	var title := _mk_title("论道 · %s" % stage_name, 22)
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position.y -= 170
	field.add_child(title)

	var hero_img := TextureRect.new()
	var hero_tex: Texture2D = load("res://assets/hero_ye_fan_q.webp")
	if hero_tex != null:
		hero_img.texture = hero_tex
		hero_img.custom_minimum_size = Vector2(120, 120)
		hero_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hero_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_img.position = Vector2(vw * 0.5 - 190, vh * 0.5 - 70)
	field.add_child(hero_img)

	var enemy_img := TextureRect.new()
	var etex: Texture2D = load("res://assets/icons/enemy_beast.webp")
	if etex != null:
		enemy_img.texture = etex
		enemy_img.custom_minimum_size = Vector2(120, 120)
		enemy_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		enemy_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_img.position = Vector2(vw * 0.5 + 70, vh * 0.5 - 70)
	field.add_child(enemy_img)

	var vs := _mk_title("VS", 30)
	vs.set_anchors_preset(Control.PRESET_CENTER)
	vs.position.y -= 20
	field.add_child(vs)

	var dmg := _mk_label("", 30)
	dmg.add_theme_color_override("font_color", C_GOLD)
	dmg.set_anchors_preset(Control.PRESET_CENTER)
	field.add_child(dmg)

	var result_label := _mk_label("", 22)
	result_label.add_theme_color_override("font_color", C_TEXT_HI)
	result_label.set_anchors_preset(Control.PRESET_CENTER)
	result_label.position.y += 150
	field.add_child(result_label)

	var ok_btn := _mk_button("确定", func() -> void: _battle_layer.visible = false, C_GOLD)
	ok_btn.set_anchors_preset(Control.PRESET_CENTER)
	ok_btn.position.y += 215
	field.add_child(ok_btn)

	_battle_layer.visible = true
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
		result_label.text += "\n" + note)
	ok_btn.modulate.a = 0.0
	tw.tween_property(ok_btn, "modulate:a", 1.0, 0.2)
