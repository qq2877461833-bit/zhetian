

# --------------------------- 装备页 ---------------------------

func _build_equip() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 10)
	box.offset_left = 4; box.offset_top = 4
	_content.add_child(box)
	box.add_child(_mk_title("装备培养 · 强化升阶", 20))
	var bonus := _eq_svc.total_bonus(_model)
	box.add_child(_mk_label("总加成：ATK+%d  DEF+%d  HP+%d" % [bonus.atk, bonus.def, bonus.hp], 15))
	for sl in _eq_tbl.get("slots", []):
		var sid := String(sl.get("id", ""))
		var item_id := String(_model.equipment.get(sid, ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		var item_name := "空" if item_id.is_empty() else String(_eq_svc.find_item(item_id).get("name", item_id))
		var lv := int(_model.stats.get("eq_lv_%s" % sid, 1))
		row.add_child(_mk_label("%s: %s Lv.%d" % [sl.get("name", "?"), item_name, lv], 15))
		if not item_id.is_empty():
			row.add_child(_mk_button("强化", func(sid_v: String = sid) -> void: _on_enhance(sid_v)))

func _on_enhance(slot_id: String) -> void:
	var r := _eq_svc.enhance(_model, slot_id)
	if not r.get("ok", false):
		_show_popup("强化失败", String(r.get("reason", "?")))
		return
	_show_popup("强化成功", "%s 强化完成（ATK+%d DEF+%d HP+%d）" % [slot_id, r.atk_bonus, r.def_bonus, r.hp_bonus])
	_refresh_hud()
	_save()


# --------------------------- 功法页 ---------------------------

func _build_skill() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 10)
	box.offset_left = 4; box.offset_top = 4
	_content.add_child(box)
	box.add_child(_mk_title("功法修习", 20))
	var names := PackedStringArray()
	for sid in _model.active_skills:
		names.append(String(_sk_svc.find_book(String(sid)).get("name", sid)))
	box.add_child(_mk_label("已装备：%s（最多 %d 格）" % [" · ".join(names) if not names.is_empty() else "无", _sk_tbl.get("active_slots", 3)], 15))
	for b in _sk_tbl.get("books", []):
		var bid := String(b.get("id", ""))
		var lv := int(_model.stats.get("sk_lv_%s" % bid, 1))
		var equipped := _model.active_skills.has(bid)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		row.add_child(_mk_label("%s Lv.%d [%s]%s" % [b.get("name", "?"), lv, b.get("category", "?"), " (已装备)" if equipped else ""], 15))
		row.add_child(_mk_button("修炼", func(bid_v: String = bid) -> void: _on_train_skill(bid_v)))
		row.add_child(_mk_button("装备" if not equipped else "卸下", func(bid_v: String = bid) -> void: _on_toggle_skill(bid_v)))

func _on_train_skill(book_id: String) -> void:
	var r := _sk_svc.train(_model, book_id)
	if not r.get("ok", false):
		_show_popup("修炼失败", String(r.get("reason", "?")))
		return
	_show_popup("修炼成功", "%s 修炼完成 Lv.%d" % [_sk_svc.find_book(book_id).get("name", book_id), r.level])
	_refresh_hud()
	_save()

func _on_toggle_skill(book_id: String) -> void:
	var r := _sk_svc.equip_skill(_model, book_id)
	if not r.get("ok", false):
		_show_popup("功法", String(r.get("reason", "?")))
		return
	_show_popup("功法", "%s %s" % [_sk_svc.find_book(book_id).get("name", book_id), "已卸下" if r.has("unequipped") else "已装备"])
	_refresh_hud()
	_save()
