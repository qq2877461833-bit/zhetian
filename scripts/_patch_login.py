# -*- coding: utf-8 -*-
"""登录层 + 登出函数追加到 main.gd 末尾"""
import io

p = 'src/main.gd'
s = io.open(p, encoding='utf-8').read()

funcs = '''

# --------------------------- 账号系统（登录层） ---------------------------

## 登录层：全屏覆盖，用户名/密码 + 登录/注册
func _show_login_layer() -> void:
	if _login_layer != null:
		_login_layer.queue_free()
	_login_layer = Control.new()
	_login_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_login_layer)
	## 暗色底（复用主题）
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.09, 0.07, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_login_layer.add_child(bg)
	## 居中的登录卡片
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 10)
	panel.add_theme_stylebox_override("panel", _panel_style(C_BG_DEEP, C_GOLD))
	panel.custom_minimum_size = Vector2(340, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	_login_layer.add_child(panel)
	var title := _mk_title("遮天 · 仙路争锋", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	var sub := _mk_dim("登录后开始修仙 · 进度自动保存", 13)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(sub)

	var user_edit := LineEdit.new()
	user_edit.placeholder_text = "用户名（2-16 字符）"
	user_edit.add_theme_font_override("font", FONT_SC)
	user_edit.custom_minimum_size = Vector2(0, 40)
	panel.add_child(user_edit)
	var pwd_edit := LineEdit.new()
	pwd_edit.placeholder_text = "密码（至少 4 位）"
	pwd_edit.secret = true
	pwd_edit.add_theme_font_override("font", FONT_SC)
	pwd_edit.custom_minimum_size = Vector2(0, 40)
	panel.add_child(pwd_edit)

	var err_label := _mk_label("", 13)
	err_label.add_theme_color_override("font_color", C_VERMILION)
	err_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(err_label)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	panel.add_child(btns)
	var login_btn := _mk_button("登录", func() -> void:
		var u := user_edit.text
		var pw := pwd_edit.text
		var r := _auth.login(u, pw)
		if not r.get("ok", false):
			err_label.text = String(r.get("reason", "?"))
			return
		_on_login_success())
	btns.add_child(login_btn)
	var reg_btn := _mk_button("注册新账号", func() -> void:
		var u := user_edit.text
		var pw := pwd_edit.text
		var r := _auth.register(u, pw)
		if not r.get("ok", false):
			err_label.text = String(r.get("reason", "?"))
			return
		_on_login_success(), Color("#9C6ADE"))
	btns.add_child(reg_btn)

	var hint := _mk_dim("新玩家点「注册新账号」；已有账号直接登录。", 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(hint)
	## 回车登录
	user_edit.text_submitted.connect(func(_t: String) -> void: login_btn.pressed.emit())
	pwd_edit.text_submitted.connect(func(_t: String) -> void: login_btn.pressed.emit())
	user_edit.grab_focus()


## 登录成功：重载该账号存档 + 关闭登录层 + 刷新界面
func _on_login_success() -> void:
	var user := _auth.current_user()
	## 保存临时默认档进度（若登录前已产生）→ 转给当前账号（新档即默认档）
	_model = SaveManager.load_save(user)
	if _login_layer != null:
		_login_layer.queue_free()
		_login_layer = null
	_stage_order = clampi(_model.highest_cleared_order() + 1, 1, MAX_SLICE_STAGES)
	_switch_tab("main")
	_refresh_hud()
	_save()
	_show_popup("欢迎", "道友 %s 请开始修仙！" % user)


## 登出：返回登录界面（进度已存）
func _logout() -> void:
	_save()
	_auth.logout()
	get_tree().reload_current_scene()
'''

s = s.rstrip() + funcs
io.open(p, 'w', encoding='utf-8').write(s)
print("登录层函数已追加")
