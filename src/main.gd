extends Control
## 遮天 Sprint 2 主控制器（角色养成 + 抽卡）
## 闭环：修炼（多修炼位并行放置）-> 收菜 -> 突破（主角）-> 推关
##       + 抽卡（券/保底可见/紫气演出）-> 图鉴（收集/详情）-> 上阵（换人）
## UI 程序化构建；三层 IA：顶部资源栏 + 页签（修炼/抽卡/图鉴）+ 内容区
## 注：UI 层不持业务状态，仅调用核心服务（core/*.gd）；多角色汇总速率暂居 UI 层（Sprint 3 迁 core）

const HERO_ID := "ye_fan"
const MAX_SLICE_STAGES := 30         ## Sprint 3：主线全量 30 关（6 章 × 5 关）
const CAP_OFFLINE_SEC := 43200       ## 离线封顶 12h（REQ-001-3.2.3）
const EFF_OFFLINE := 0.8             ## 离线效率 80%
const WAIT_DEMO_SCALE := 1.0 / 360.0 ## 演示：大境界等待 3600s -> 10s（正式数值以 realm.json 为准）
const TICKETS_NEW := 30              ## MVP 演示：新档赠送抽卡券（GDD-002：抽卡券=付费/活动获取）
const TICKETS_MIGRATE := 10          ## 旧档（v1 无券字段）迁移补发

## 主题色（美术圣经 §3.1 简版）
const C_BG := Color("#101B17")      ## 主背景：深墨绿黑（荒古苍凉）
const C_BG_DEEP := Color("#0A120F") ## 更深一档（页面底）
const C_PANEL := Color("#16251F")   ## 面板底（暗色分层第二层）
const C_PANEL_HI := Color("#1D3028")## 面板高亮（hover/激活）
const C_TEXT := Color("#E8E4D8")    ## 主文本：月白
const C_TEXT_HI := Color("#F5F0E4") ## 高亮文本
const C_GOLD := Color("#C9A86A")    ## 鎏金（主强调）
const C_GOLD_DIM := Color("#8A7348")## 鎏金弱化（边框/未激活）
const C_PURPLE := Color("#4A3E6E")  ## 星紫（紫气/稀有）
const C_DIM := Color("#8FA29A")     ## 弱化文本
const C_VERMILION := Color("#A83232") ## 朱砂（点缀 ≤5%）
const C_SLOT := Color("#1A2B24")    ## 修炼位卡片底
const C_EDGE := Color("#C9A86A")    ## 面板细边框（鎏金 1px）

## 稀有度色阶（美术圣经 §5.4 简版；正式色板后续核对）
const RARITY_COLOR := {
	"fan": Color("#9E9E9E"), "ling": Color("#6FBF73"), "xuan": Color("#5B9BD5"),
	"di": Color("#9C6ADE"), "tian": Color("#E6B84C"), "di_pin": Color("#C65D4E"),
}
const RARITY_NAME := {
	"fan": "凡品", "ling": "灵品", "xuan": "玄品",
	"di": "地品", "tian": "天品", "di_pin": "帝品",
}

## preload 引用核心脚本（autoload/主场景解析期不依赖全局类缓存，headless/CI 确定性）
const RealmEngineScript := preload("res://src/core/realm_engine.gd")
const IdleIncomeEngineScript := preload("res://src/core/idle_income_engine.gd")
const BattleServiceScript := preload("res://src/core/battle_service.gd")
const SaveModelScript := preload("res://src/core/save_model.gd")
const CharacterServiceScript := preload("res://src/core/character_service.gd")
const GachaServiceScript := preload("res://src/core/gacha_service.gd")
const DropServiceScript := preload("res://src/core/drop_service.gd")
const AuthServiceScript := preload("res://src/core/auth_service.gd")
const ArenaServiceScript := preload("res://src/core/arena_service.gd")
const EquipmentServiceScript := preload("res://src/core/equipment_service.gd")
const SkillServiceScript := preload("res://src/core/skill_service.gd")
const FONT_SC := preload("res://assets/fonts/NotoSansSC-Regular.ttf")

var _realm: RealmEngineScript
var _idle: IdleIncomeEngineScript
var _battle: BattleServiceScript
var _char_svc: CharacterServiceScript
var _gacha_svc: GachaServiceScript
var _drop_svc: DropServiceScript
var _arena_svc: ArenaServiceScript
var _eq_svc: EquipmentServiceScript
var _sk_svc: SkillServiceScript
var _model: SaveModelScript
var _realm_tbl: Dictionary
var _battle_tbl: Dictionary
var _char_tbl: Dictionary
var _gacha_tbl: Dictionary
var _drop_tbl: Dictionary
var _eq_tbl: Dictionary
var _sk_tbl: Dictionary

## UI 引用
var _content: Control
var _ling_label: Button
var _yuan_label: Button
var _ticket_label: Button
var _realm_label: Label
var _stage_label: Label
var _collect_label: Label
var _status_label: Label
var _btn_collect: Button
var _btn_break: Button
var _btn_stage: Button
var _btn_wait_speed: Button
var _wait_bar: ProgressBar
var _slots_row: HBoxContainer
var _gacha_stage: TextureRect
var _gacha_info: Label
var _popup: Control
var _pop_box: VBoxContainer
var _battle_layer: Control
var _popup_title: Label
var _popup_label: Label
var _flash: ColorRect
var _tab_btns := {}

## 状态
var _cur_tab := "main"
var _pending_ling := 0.0
var _waiting := false
var _wait_for_sub := 0
var _wait_start_ts := 0
var _wait_end_ts := 0
var _stage_order := 1
var _gacha_seq := 0  ## 演出序号（区分连续演出）
var _auth: AuthServiceScript
var _login_layer: Control

## 紫气演出背景帧（美术线 Sprint 2 资产）
var _ziqi_frames: Array[Texture2D] = []


func _ready() -> void:
	_auth = AuthServiceScript.new()
	## 多账号：已登录加载该账号存档；未登录显示登录层（登录后加载）
	if _auth.is_logged_in():
		_model = SaveManager.load_save(_auth.current_user())
	else:
		_model = SaveManager.load_save()  ## 临时默认档（登录层覆盖，登录后重载）
	_realm_tbl = ResourceManager.load_table("res://data/tables/realm.json")
	_battle_tbl = ResourceManager.load_table("res://data/tables/battle.json")
	_char_tbl = ResourceManager.load_table("res://data/tables/character.json")
	_gacha_tbl = ResourceManager.load_table("res://data/tables/gacha.json")
	_drop_tbl = ResourceManager.load_table("res://data/tables/drop.json")
	_realm = RealmEngineScript.new(_realm_tbl.get("breakthrough_costs", []))
	_idle = IdleIncomeEngineScript.new()
	_battle = BattleServiceScript.new()
	_char_svc = CharacterServiceScript.new(_char_tbl)
	_gacha_svc = GachaServiceScript.new(_gacha_tbl)
	_drop_svc = DropServiceScript.new(_drop_tbl)
	_arena_svc = ArenaServiceScript.new()
	_eq_tbl = ResourceManager.load_table("res://data/tables/equipment.json")
	_sk_tbl = ResourceManager.load_table("res://data/tables/skill_sets.json")
	_eq_svc = EquipmentServiceScript.new(_eq_tbl)
	_sk_svc = SkillServiceScript.new(_sk_tbl)
	print("[Main] boot: stages=%d, slots=%d, characters=%d, energy=%d/%d" % [_battle_tbl.get("stages", []).size(), _model.slots.size(), _model.characters.size(), _model.energy, _model.ENERGY_CAP])
	_load_ziqi_frames()
	_migrate_save()
	_build_shell()
	_stage_order = clampi(_model.highest_cleared_order() + 1, 1, MAX_SLICE_STAGES)
	_boot_offline_settle()
	_switch_tab("main")
	_refresh_hud()
	print("[遮天] Sprint 3 启动：境界=%s 已通关=%d 券=%d 角色=%d" % [
		_realm_name(), _model.highest_cleared_order(), _model.gacha_tickets, _model.characters.size()])
	## 多账号：未登录显示登录层
	if not _auth.is_logged_in():
		_show_login_layer()


# --------------------------- 初始化 ---------------------------

func _load_ziqi_frames() -> void:
	for i in [1, 2, 3]:
		var t: Texture2D = load("res://assets/gacha/gacha_bg_ziqi_f%d.png" % i)
		if t != null:
			_ziqi_frames.append(t)


## 存档兼容迁移：v1 切片档 slots 空 -> 主角挂槽 0；无券补发
func _migrate_save() -> void:
	if _model.slots.is_empty() and _model.characters.has(HERO_ID):
		_model.slots[0] = HERO_ID
	if _model.gacha_tickets <= 0:
		_model.gacha_tickets = TICKETS_MIGRATE


func _build_shell() -> void:
	# 背景（美术占位图）+ 方舟式暗色叠加层（统一色调 + 网格质感）
	var bg := TextureRect.new()
	bg.texture = load("res://assets/placeholder/main_bg_huanggu.png")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(bg)
	## 暗色叠加（方舟式"压暗背景凸出 UI"手法）
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.08, 0.06, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	## 星辉网格（横向细线，方舟网格质感修仙化）
	var grid := Control.new()
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grid)
	var gd := grid.draw.connect(func() -> void:
		var w := grid.size.x
		var h := grid.size.y
		var dc := grid.get_canvas_item()
		RenderingServer.canvas_item_add_line(dc, Vector2(0, h * 0.5), Vector2(w, h * 0.5), Color(0.79, 0.66, 0.42, 0.10), 1.0)
		RenderingServer.canvas_item_add_line(dc, Vector2(0, h * 0.72), Vector2(w, h * 0.72), Color(0.79, 0.66, 0.42, 0.07), 1.0))

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	root.offset_left = 28
	root.offset_top = 20
	root.offset_right = -28
	root.offset_bottom = -28
	## 全局主题字体（root 上设置 -> 递归应用到所有子 Label/Button 默认字体）
	root.add_theme_font_override("font", FONT_SC)
	add_child(root)

	var title := Label.new()
	title.text = "遮天 · 仙路争锋"
	title.add_theme_font_override("font", FONT_SC)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", C_GOLD)
	root.add_child(title)

	# 顶部资源栏（带 icon）
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 26)
	root.add_child(bar)
	_ling_label = _mk_icon_label("灵石 0", "res://assets/icons/res_ling.webp", 20)
	_yuan_label = _mk_icon_label("源石 0", "res://assets/icons/res_yuan.webp", 20)
	_ticket_label = _mk_icon_label("体力 0/0 · 券 0", "res://assets/icons/gacha_ticket.webp", 20)
	bar.add_child(_ling_label)
	bar.add_child(_yuan_label)
	bar.add_child(_ticket_label)

	# 页签行（方舟式：下划线 tab）
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	root.add_child(tab_row)
	_tab_btns["main"] = _mk_tab("修炼", func() -> void: _switch_tab("main"))
	_tab_btns["gacha"] = _mk_tab("抽卡", func() -> void: _switch_tab("gacha"))
	_tab_btns["equip"] = _mk_tab("装备", func() -> void: _switch_tab("equip"))
	_tab_btns["dungeon"] = _mk_tab("副本", func() -> void: _switch_tab("dungeon"))
	_tab_btns["skill"] = _mk_tab("功法", func() -> void: _switch_tab("skill"))
	_tab_btns["bag"] = _mk_tab("背包", func() -> void: _switch_tab("bag"))
	for k in _tab_btns:
		tab_row.add_child(_tab_btns[k])
	## 页签下垫一条鎏金细线（方舟 tab 底轨）
	var tab_rail := ColorRect.new()
	tab_rail.color = Color(C_GOLD_DIM.r, C_GOLD_DIM.g, C_GOLD_DIM.b, 0.35)
	tab_rail.custom_minimum_size = Vector2(0, 1)
	root.add_child(tab_rail)

	# 状态行
	var state_row := HBoxContainer.new()
	state_row.add_theme_constant_override("separation", 28)
	root.add_child(state_row)
	_realm_label = _mk_label("", 19)
	_stage_label = _mk_label("", 19)
	state_row.add_child(_realm_label)
	state_row.add_child(_stage_label)

	# 内容区（页签切换时重建）
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_content)

	_status_label = _mk_label("", 15)
	_status_label.add_theme_color_override("font_color", C_DIM)
	root.add_child(_status_label)

	# 弹窗（模态）
	_popup = Control.new()
	_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup.visible = false
	add_child(_popup)
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.66)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup.add_child(overlay)
	## 弹窗主体：双层面板（标题条鎏金顶 + 内容区暗底），方舟式结构
	_pop_box = VBoxContainer.new()
	_pop_box.set_anchors_preset(Control.PRESET_CENTER)
	_pop_box.custom_minimum_size = Vector2(540, 0)
	_pop_box.add_theme_constant_override("separation", 0)
	_popup.add_child(_pop_box)
	## 标题条（暗金底 + 鎏金顶条 + 标题 + 分隔线）
	var title_bar := VBoxContainer.new()
	title_bar.add_theme_stylebox_override("panel", _panel_style(Color("#1A241E"), C_GOLD))
	title_bar.add_theme_constant_override("separation", 8)
	_pop_box.add_child(title_bar)
	_popup_title = _mk_label("", 22)
	_popup_title.add_theme_color_override("font_color", C_TEXT_HI)
	_popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_bar.add_child(_popup_title)
	var title_rule := ColorRect.new()
	title_rule.color = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.45)
	title_rule.custom_minimum_size = Vector2(0, 1)
	title_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title_rule)
	## 内容区（暗底面板）
	var body_box := VBoxContainer.new()
	body_box.add_theme_stylebox_override("panel", _panel_style(C_BG_DEEP, C_GOLD_DIM))
	body_box.add_theme_constant_override("separation", 14)
	_pop_box.add_child(body_box)
	_popup_label = _mk_label("", 16)
	_popup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_box.add_child(_popup_label)
	var ok_btn := _mk_button("确定", func() -> void: _popup.visible = false)
	ok_btn.custom_minimum_size = Vector2(160, 46)
	body_box.add_child(ok_btn)

	# 紫气全屏演出（突破/抽卡瞬间闪）
	_flash = ColorRect.new()
	_flash.color = Color(C_PURPLE.r, C_PURPLE.g, C_PURPLE.b, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


func _mk_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT_SC)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", C_TEXT)
	return l


## 带 icon 的标签（资源栏用）：透明 Button（icon + text，兼容 .text 刷新）
func _mk_icon_label(text: String, icon_path: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.add_theme_font_override("font", FONT_SC)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_color_override("font_hover_color", C_TEXT_HI)
	var tex: Texture2D = load(icon_path)
	if tex != null:
		b.icon = tex
		b.add_theme_constant_override("icon_max_width", 26)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = true  ## 不可点击，纯展示
	return b


func _mk_button(text: String, cb: Callable, accent: Color = C_GOLD) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", FONT_SC)
	b.custom_minimum_size = Vector2(132, 42)
	## 方舟式：暗底 + 强调色细框 + hover 提亮 + 光晕（普通=鎏金，主操作可传朱砂/紫）
	b.add_theme_stylebox_override("normal", _btn_style(C_PANEL, accent))
	b.add_theme_stylebox_override("hover", _btn_style(C_PANEL_HI, accent.lightened(0.25), 1.6))
	b.add_theme_stylebox_override("pressed", _btn_style(C_PANEL_HI, accent.lightened(0.4), 2.0))
	b.add_theme_stylebox_override("focus", _btn_style(C_PANEL, accent))
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_color_override("font_hover_color", C_TEXT_HI)
	b.add_theme_color_override("font_pressed_color", accent)
	## hover 提亮动画（防生硬）
	b.mouse_entered.connect(func() -> void:
		var tw2 := create_tween()
		tw2.tween_property(b, "modulate", Color(1.0, 1.0, 1.0), 0.12))
	b.mouse_exited.connect(func() -> void:
		var tw3 := create_tween()
		tw3.tween_property(b, "modulate", Color(1.0, 1.0, 1.0), 0.12))
	b.pressed.connect(cb)
	return b


## 方舟式按钮 StyleBoxFlat：暗底 + 强调色细边框
func _btn_style(bg: Color, accent: Color = C_GOLD, border_w: float = 1.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = Color(accent.r, accent.g, accent.b, 0.65)
	s.set_border_width_all(int(border_w))
	s.set_corner_radius_all(2)
	s.content_margin_left = 14.0
	s.content_margin_right = 14.0
	s.content_margin_top = 8.0
	s.content_margin_bottom = 8.0
	return s


## 面板样式（方舟卡片语言）：暗底 + 鎏金细框 + 顶部 accent 色条（2px）
## Godot 4.4 StyleBoxFlat 边框颜色统一，仅宽度可单边 → 顶条用 border 宽度 + 统一色（简化：顶部边框加粗同色）
func _panel_style(bg: Color, accent: Color = C_GOLD) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = accent
	s.set_border_width_all(1)
	s.border_width_top = 3
	s.set_corner_radius_all(3)
	s.content_margin_left = 14.0
	s.content_margin_right = 14.0
	s.content_margin_top = 10.0
	s.content_margin_bottom = 10.0
	return s


## 方舟式标题（大字距鎏金，带左右装饰线）
func _mk_title(text: String, size: int = 20) -> Label:
	var l := _mk_label(text, size)
	l.add_theme_color_override("font_color", C_GOLD)
	l.add_theme_constant_override("line_spacing", 2)
	return l


## 弱化提示文本
func _mk_dim(text: String, size: int = 14) -> Label:
	var l := _mk_label(text, size)
	l.add_theme_color_override("font_color", C_DIM)
	return l


# --------------------------- 页签切换 ---------------------------

## 方舟式页签按钮（无框文字 + 激活时鎏金下划线 + 提亮）
func _mk_tab(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", FONT_SC)
	b.custom_minimum_size = Vector2(96, 38)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", s)
	b.add_theme_stylebox_override("pressed", s)
	b.add_theme_stylebox_override("focus", s)
	b.add_theme_color_override("font_color", C_DIM)
	b.add_theme_color_override("font_hover_color", C_TEXT)
	b.add_theme_color_override("font_pressed_color", C_GOLD)
	b.pressed.connect(cb)
	return b


func _switch_tab(name: String) -> void:
	_cur_tab = name
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	## 页签激活态：当前页专属强调色 + 下划线（修炼金/抽卡紫/图鉴月白/副本铜/帝路朱砂）
	var tab_accent := {
		"main": C_GOLD, "gacha": Color("#9C6ADE"), "equip": C_TEXT,
		"dungeon": Color("#B08968"), "skill": C_VERMILION, "bag": C_GOLD,
	}
	for k in _tab_btns:
		var b: Button = _tab_btns[k]
		var active: bool = k == name
		var accent: Color = tab_accent.get(k, C_GOLD)
		b.add_theme_color_override("font_color", accent if active else C_DIM)
		b.add_theme_stylebox_override("normal", _tab_style(active, accent))
		b.add_theme_stylebox_override("hover", _tab_style(active, accent))
		b.add_theme_stylebox_override("pressed", _tab_style(active, accent))
		b.add_theme_stylebox_override("focus", _tab_style(active, accent))
	match name:
		"gacha":
			_build_gacha()
		"equip":
			_build_equip()
		"dungeon":
			_build_dungeon()
		"skill":
			_build_skill()
		"bag":
			_build_bag()
		_:
			_build_main()
	## 页签切换：内容淡入（防生硬）
	_content.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_content, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_refresh_hud()


## 页签 StyleBox：激活态底部 2px 强调色线（方舟 tab 下划线，色随页签）
func _tab_style(active: bool, accent: Color = C_GOLD) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	if active:
		s.border_color = accent
		s.border_width_bottom = 2
	s.content_margin_bottom = 6.0
	return s


## 主角属性详情：五维 + 装备/功法加成明细
func _show_hero_detail() -> void:
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
	box.custom_minimum_size = Vector2(470, 0)

	var head := _mk_title("叶凡 · %s" % _realm_name(), 22)
	box.add_child(head)
	box.add_child(_mk_dim("境界进度：%s / %s · 修炼速率 +%.1f 灵/秒" % [_sub_name(sub), _next_sub_name(sub), _sum_rate()], 14))

	var sec1 := _mk_label("—— 核心属性 ——", 15)
	sec1.add_theme_color_override("font_color", C_GOLD)
	box.add_child(sec1)
	box.add_child(_mk_label("攻击 %d  = 基础 %d × 功法x%.2f + 装备 %d" % [total_atk, int(base_atk), 1.0 + sk.atk, equip.atk], 14))
	box.add_child(_mk_label("防御 %d  = 基础 %d + 装备 %d" % [total_def, int(base_def), equip.def], 14))
	box.add_child(_mk_label("生命 %d  = 基础 %d + 装备 %d" % [total_hp, int(base_hp), equip.hp], 14))
	box.add_child(_mk_label("速度 %d（行动条基础，越高越先手）" % int(base_spd), 14))

	var sec1b := _mk_label("—— 进阶属性 ——", 15)
	sec1b.add_theme_color_override("font_color", C_GOLD)
	box.add_child(sec1b)
	var base_matk := float(base.get("matk", 0))
	var total_matk := int(base_matk) + int(equip.matk)
	var base_crit := float(base.get("crit_rate", 0.05))
	var total_crit := clampf(base_crit + equip.crit_rate, 0.0, 0.9)
	var base_cdmg := float(base.get("crit_dmg", 1.5))
	var total_cdmg: float = base_cdmg + float(equip.get("crit_dmg", 0.0))
	var base_dodge := float(base.get("dodge", 0.03))
	var total_dodge := clampf(base_dodge + equip.dodge, 0.0, 0.6)
	box.add_child(_mk_label("特攻 %d（神通/法术伤害，装备可加）" % total_matk, 14))
	box.add_child(_mk_label("暴击率 %d%%（攻击时几率造成暴击）" % int(total_crit * 100), 14))
	box.add_child(_mk_label("暴击伤害 %.0f%%（暴击时伤害倍率）" % (total_cdmg * 100), 14))
	box.add_child(_mk_label("闪避率 %d%%（几率闪避敌方攻击）" % int(total_dodge * 100), 14))

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
		var matk_b := int(float(item.get("base_matk", 0)) * (1.0 + growth * (lv - 1)))
		var def_b := int(float(item.get("base_def", 0)) * (1.0 + growth * (lv - 1)))
		var hp_b := int(float(item.get("base_hp", 0)) * (1.0 + growth * (lv - 1)))
		var extra := ""
		if float(item.get("crit_rate", 0.0)) > 0.0:
			extra += " 暴击+%d%%" % int(float(item.get("crit_rate", 0.0)) * 100)
		if float(item.get("crit_dmg", 0.0)) > 0.0:
			extra += " 暴伤+%.0f%%" % (float(item.get("crit_dmg", 0.0)) * 100)
		if float(item.get("dodge", 0.0)) > 0.0:
			extra += " 闪避+%d%%" % int(float(item.get("dodge", 0.0)) * 100)
		box.add_child(_mk_label("%s：%s Lv.%d（攻+%d 特攻+%d 防+%d 血+%d%s）" % [sl.get("name", sid), item.get("name", item_id), lv, atk_b, matk_b, def_b, hp_b, extra], 13))

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
			var eff_txt := "%s +%d%%" % [eff_name.get(String(bk.get("effect", "")), "?"), int(float(bk.get("value", 0.0)) * lv2 * (1.0 + 0.25 * con) * 100)]
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


# --------------------------- 主界面（修炼） ---------------------------

func _build_main() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 10)
	box.offset_left = 4
	box.offset_top = 4
	_content.add_child(box)

## 单主角修仙主角面板（替代多修炼位）
	var hero_def: Dictionary = _char_def(HERO_ID)
	var hero_sub := int(_model.get_character(HERO_ID).get("sub_index", 0))
	var panel := HBoxContainer.new()
	panel.add_theme_constant_override("separation", 16)
	panel.add_theme_stylebox_override("panel", _panel_style(C_PANEL, C_GOLD))
	box.add_child(panel)
	# Q版头像（点击切换装备页）
	var avatar_btn := Button.new()
	avatar_btn.custom_minimum_size = Vector2(80, 80)
	avatar_btn.icon = load("res://assets/hero_ye_fan_q.webp")
	avatar_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_btn.expand_icon = true
	avatar_btn.pressed.connect(func() -> void: _switch_tab("equip"))
	panel.add_child(avatar_btn)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	panel.add_child(info)
	info.add_child(_mk_label("%s · 叶凡" % _sub_name(hero_sub), 22))
	info.add_child(_mk_dim("战力 %d · %s" % [int(_team_power()), _realm_name()], 14))
	# 快捷入口
	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation", 8)
	info.add_child(quick)
	quick.add_child(_mk_button("装备培养", func() -> void: _switch_tab("equip"), C_GOLD))
	quick.add_child(_mk_button("功法修习", func() -> void: _switch_tab("skill"), Color("#9C6ADE")))
	quick.add_child(_mk_button("属性", func() -> void: _show_hero_detail(), C_TEXT))
	quick.add_child(_mk_button("切换账号", func() -> void: _logout(), C_VERMILION))

	# 修炼产出（单主角）
	var rate := _calc_hero_rate(hero_sub)
	var equip := _eq_svc.total_bonus(_model)
	var sk_bonus := _sk_svc.total_bonus(_model)
	var total_rate: float = rate * (1.0 + float(sk_bonus.get("idle_rate", 0.0)))
	box.add_child(_mk_label("修炼速率：+%.1f 灵/秒 · 待领取 %d 灵" % [total_rate, int(_pending_ling)], 16))

	_collect_label = _mk_label("待领取 %d 灵" % int(_pending_ling), 18)
	box.add_child(_collect_label)

	# 操作区
	var ops := HBoxContainer.new()
	ops.add_theme_constant_override("separation", 14)
	box.add_child(ops)
	_btn_collect = _mk_button("出关（收菜）", _on_collect_pressed, C_GOLD)
	_btn_break = _mk_button("突破", _on_break_pressed, C_VERMILION)
	_btn_break.icon = load("res://assets/icons/breakthrough.webp")
	_btn_break.add_theme_constant_override("icon_max_width", 20)
	_btn_stage = _mk_button("推关", _on_stage_pressed, Color("#9C6ADE"))
	ops.add_child(_btn_collect)
	ops.add_child(_btn_break)
	ops.add_child(_btn_stage)

	# 大境界等待条
	var wait_row := HBoxContainer.new()
	wait_row.add_theme_constant_override("separation", 12)
	box.add_child(wait_row)
	_wait_bar = ProgressBar.new()
	_wait_bar.custom_minimum_size = Vector2(360, 22)
	_wait_bar.max_value = 1.0
	_wait_bar.value = 0.0
	_wait_bar.visible = false
	wait_row.add_child(_wait_bar)
	_btn_wait_speed = _mk_button("加速(演示)", _on_wait_speed_pressed)
	_btn_wait_speed.visible = false
	wait_row.add_child(_btn_wait_speed)

	var hint := _mk_dim("单主角修仙：主角修炼→突破→推关；装备功法提升战力", 14)
	box.add_child(hint)

	## 测试版调试区（正式版隐藏：URL 加 ?debug=1 或编辑器模式开启）
	if _debug_mode():
		var dbg := VBoxContainer.new()
		dbg.add_theme_constant_override("separation", 8)
		box.add_child(dbg)
		dbg.add_child(_mk_label("—— 测试调试区（正式版不显示）——", 14))
		var dbg_row := HBoxContainer.new()
		dbg_row.add_theme_constant_override("separation", 8)
		dbg.add_child(dbg_row)
		dbg_row.add_child(_mk_button("回满体力", func() -> void:
			_model.energy = _model.ENERGY_CAP
			_save(); _refresh_hud(); _show_popup("调试", "体力已回满 120/120")))
		dbg_row.add_child(_mk_button("送灵石+500万", func() -> void:
			_model.ling += 5000000
			_save(); _refresh_hud(); _show_popup("调试", "灵石 +500万")))
		dbg_row.add_child(_mk_button("送源石+100", func() -> void:
			_model.yuan += 100
			_save(); _refresh_hud(); _show_popup("调试", "源石 +100")))
		dbg_row.add_child(_mk_button("送抽卡券+100", func() -> void:
			_model.gacha_tickets += 100
			_save(); _refresh_hud(); _show_popup("调试", "抽卡券 +100")))
		dbg_row.add_child(_mk_button("重置存档", _on_debug_reset))


func _refresh_slots() -> void:
	if _slots_row == null:
		return
	for c in _slots_row.get_children():
		_slots_row.remove_child(c)
		c.queue_free()
	var main_sub := _hero_sub()
	for i in range(3):
		var card := _mk_slot_card(i, main_sub)
		_slots_row.add_child(card)


func _mk_slot_card(i: int, main_sub: int) -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(250, 150)
	card.add_theme_constant_override("separation", 4)
	## 背景
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _slot_style())
	panel.add_child(card)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := _mk_label("修炼位%d" % (i + 1), 17)
	title.add_theme_color_override("font_color", C_GOLD)
	card.add_child(title)

	var unlocked := _slot_unlocked(i)
	var cid := String(_model.slots.get(i, ""))
	if not unlocked:
		var need := "轮海毕业解锁" if i == 1 else "道宫毕业解锁"
		card.add_child(_mk_label("未解锁（%s）" % need, 14))
		card.add_child(_mk_label("境界不足", 13))
	elif cid.is_empty():
		card.add_child(_mk_label("空闲", 15))
		card.add_child(_mk_label("点击上阵角色", 13))
	else:
		var def: Dictionary = _char_def(cid)
		var c: Dictionary = _model.get_character(cid)
		var sub := int(c.get("sub_index", 0))
		var rate := _idle.calc_rate(floori(sub / 4.0), sub)
		var n := String(def.get("name", cid))
		card.add_child(_mk_label(n, 16))
		card.add_child(_mk_label(_sub_name(sub), 13))
		card.add_child(_mk_label("产出 +%.1f 灵/秒" % rate, 13))
		card.add_child(_mk_label("等级 %d  星级 %d" % [int(c.get("level", 1)), int(c.get("star", 1))], 12))

	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if unlocked and ev is InputEventMouseButton and ev.pressed:
			_open_swap_popup(i))
	return panel


func _slot_style() -> StyleBoxFlat:
	return _panel_style(C_SLOT, C_GOLD)


## 修炼位解锁（GDD-001 §3.2.4 口径）：0 初始 / 1 轮海毕业(sub>=3) / 2 道宫毕业(sub>=8)
func _slot_unlocked(i: int) -> bool:
	if i == 0:
		return true
	var main_sub := _hero_sub()
	return main_sub >= (3 if i == 1 else 8)


func _open_swap_popup(slot_i: int) -> void:
	if _popup.visible:
		return
	var lines := PackedStringArray()
	var cid_now := String(_model.slots.get(slot_i, ""))
	if not cid_now.is_empty():
		lines.append("当前：%s（点击上方确定可换下）" % _char_name(cid_now))
	## 已收集且未占位（含当前占用者，可重复放置）
	var picked := ""
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	for cid in _model.characters:
		var def: Dictionary = _char_def(cid)
		var name := String(def.get("name", cid))
		var in_slot := _role_in_slot(cid)
		var tag := "（修炼位%d）" % (in_slot + 1) if in_slot >= 0 else ""
		var b := Button.new()
		b.text = "%s%s" % [name, tag]
		b.add_theme_font_override("font", FONT_SC)
		b.custom_minimum_size = Vector2(260, 38)
		b.pressed.connect(func(cid_v: String = cid) -> void:
			_popup.set_meta("swap_pick", cid_v)
			_popup_label.text = "已选 %s，点击确定上阵到修炼位%d" % [_char_name(cid_v), slot_i + 1])
		box.add_child(b)
	_popup_title.text = "选择角色上阵 · 修炼位%d" % (slot_i + 1)
	_popup_label.text = "点击下方角色进行选择" + lines[0] if not lines.is_empty() else "点击下方角色进行选择"
	## 替换弹窗内容：先清空旧内容（除确定按钮外）——简化：pop 用列表，点选后确定上阵
	_popup.set_meta("swap_slot", slot_i)
	_popup.set_meta("swap_pick", "")
	_show_custom_popup("选择角色上阵 · 修炼位%d" % (slot_i + 1), box, func() -> bool:
		var pick := String(_popup.get_meta("swap_pick", ""))
		if pick.is_empty():
			return false
		_model.assign_slot(slot_i, pick)
		_save()
		_refresh_slots()
		_refresh_hud()
		return true)


func _show_custom_popup(title: String, body: Control, on_ok: Callable) -> void:
	## 弹窗：标题 + body + 确定按钮（on_ok 返回 false 则不关闭）
	## 注意：pop_box 内的 _popup_title/_popup_label 是常驻引用，不可 queue_free，
	## 只清 body 与旧确定按钮，重建时保持 title/label 引用有效。
	_popup_title.text = title
	_popup_title.visible = true
	_popup_label.visible = true
	for c in _popup.get_children():
		if c is VBoxContainer:
			## 移除旧 body（非 title/label 的常驻子节点）与旧确定按钮
			for cc in c.get_children():
				if cc != _popup_title and cc != _popup_label:
					cc.queue_free()
			c.add_child(body)
			var ok_btn := Button.new()
			ok_btn.text = "确定"
			ok_btn.add_theme_font_override("font", FONT_SC)
			ok_btn.custom_minimum_size = Vector2(140, 44)
			ok_btn.pressed.connect(func() -> void:
				if on_ok.call():
					_popup.visible = false)
			c.add_child(ok_btn)
	_popup.visible = true


# --------------------------- 收菜 / 离线结算（多角色） ---------------------------

func _boot_offline_settle() -> void:
	var now_ts := TimeService.now()
	var delta := now_ts - _model.last_offline_ts
	if _model.last_offline_ts > 0 and delta > 0:
		var rate := _sum_rate()
		var capped := mini(delta, CAP_OFFLINE_SEC)
		var gain := int(rate * EFF_OFFLINE * capped)
		_model.ling += gain
		_model.last_offline_ts = now_ts
		_show_popup("闭关结算", "闭关 %d 分钟（封顶 12h）\n产出灵石 +%d（效率 80%%）" % [delta / 60, gain])
		_save()
	else:
		_model.last_offline_ts = now_ts
		_save()


## 多修炼位产出汇总：Σ R_c（各角色按自身境界）
func _sum_rate() -> float:
	## 单主角修仙：单主角修炼速率（+功法加成）
	var sub := _hero_sub()
	var base := _idle.calc_rate(floori(sub / 4.0), sub)
	var sk_bonus := _sk_svc.total_bonus(_model)
	return base * (1.0 + sk_bonus.idle_rate)


func _calc_hero_rate(sub: int) -> float:
	## 单主角修炼速率（供 UI 显示，不含功法加成）
	return _idle.calc_rate(floori(sub / 4.0), sub)


func _active_count() -> int:
	return 1


func _on_collect_pressed() -> void:
	var gain := int(_pending_ling)
	if gain > 0:
		_model.ling += gain
		_pending_ling = 0.0
		_show_popup("收菜", "领取灵石 +%d" % gain)
		_refresh_main_light()
		_save()
	else:
		_show_popup("收菜", "暂无待领取（正在修炼中…）")


# --------------------------- 突破（主角） ---------------------------

func _on_break_pressed() -> void:
	if _waiting:
		return
	var c := _model.get_character(HERO_ID)
	var sub := int(c.get("sub_index", 0))
	if sub >= 8:
		_show_popup("突破", "已达 MVP 境界上限（道宫·肾藏）")
		return
	var cost := _realm.calc_cost(sub)
	if _model.ling < cost.ling:
		_show_popup("突破", "灵石不足：还差 %d" % (cost.ling - _model.ling))
		return
	if _model.yuan < cost.yuan:
		_show_popup("突破", "源石不足：还差 %d" % (cost.yuan - _model.yuan))
		return
	if _model.highest_cleared_order() < cost.stage_req:
		_show_popup("突破", "需通过第 %d 关（当前已通 %d 关）" % [cost.stage_req, _model.highest_cleared_order()])
		return
	_model.ling -= cost.ling
	_model.yuan -= cost.yuan
	var next_sub := sub + 1
	if next_sub >= 4:
		_start_big_wait(sub)
	else:
		_do_breakthrough(sub)


func _do_breakthrough(old_sub: int) -> void:
	var c := _model.get_character(HERO_ID)
	c["sub_index"] = old_sub + 1
	_model.characters[HERO_ID] = c
	_flash_purple()
	_show_popup("* 破境 *", "%s -> %s" % [_sub_name(old_sub), _sub_name(old_sub + 1)])
	_refresh_slots()
	_refresh_hud()
	_save()


func _start_big_wait(old_sub: int) -> void:
	_waiting = true
	_wait_for_sub = old_sub
	var params: Dictionary = _realm_tbl.get("params", {})
	var waits: Dictionary = params.get("big_breakthrough_wait_sec", {})
	var wait_sec := float(waits.get("lunhai_to_daogong", 3600.0))
	var demo_sec := int(wait_sec * WAIT_DEMO_SCALE)
	_wait_start_ts = TimeService.now()
	_wait_end_ts = _wait_start_ts + demo_sec
	_wait_bar.max_value = float(demo_sec)
	_wait_bar.value = 0.0
	_wait_bar.visible = true
	_btn_wait_speed.visible = true
	_show_popup("破境中", "轮海毕业 -> 道宫（演示加速 %d 秒…）" % demo_sec)


func _on_wait_speed_pressed() -> void:
	if _waiting:
		_wait_end_ts = TimeService.now()


# --------------------------- 推关 ---------------------------

func _on_stage_pressed() -> void:
	if _waiting:
		return
	if _stage_order > MAX_SLICE_STAGES:
		_show_popup("推关", "主线已通关全部 30 关（后续章节 Sprint 4+）")
		return
	var stage := _find_stage(_stage_order)
	if stage.is_empty():
		_show_popup("推关", "关卡数据缺失（battle.json）")
		return
	## 体力消耗（GDD-003 §3.5：主线关消耗体力）
	var stage_cost := int(_battle_tbl.get("energy", {}).get("stage_cost", 10))
	if _model.energy < stage_cost:
		_show_popup("推关", "体力不足（需 %d 点，当前 %d）\n体力每 5 分钟恢复 1 点" % [stage_cost, _model.energy])
		return
	_model.energy -= stage_cost
	## 单主角修仙单主角战斗（装备+功法加成）——取代 4 人队
	var hero_def: Dictionary = _char_def(HERO_ID)
	var hero_base := {
		"atk": float(hero_def.get("base", {}).get("atk", 120)),
		"def": float(hero_def.get("base", {}).get("def", 80)),
		"hp":  float(hero_def.get("base", {}).get("hp", 1500)),
	}
	var equip_bonus := _eq_svc.total_bonus(_model)
	var skill_bonus := _sk_svc.total_bonus(_model)
	var result := _battle.simulate_solo(hero_base, equip_bonus, skill_bonus, stage)
	if String(result.get("winner", "")) == "player":
		_model.cleared_stages.append(stage.id)
		var fc: Dictionary = stage.get("first_clear", {})
		var ling_gain := int(fc.get("ling", 0))
		var yuan_gain := int(fc.get("yuan", 0))
		_model.ling += ling_gain
		_model.yuan += yuan_gain
		_stage_order += 1
		_show_battle_result(stage.get("name", "关卡"), result, "推关胜利！首通灵石 +%d / 源石 +%d" % [ling_gain, yuan_gain], "beast" if _stage_order % 2 == 1 else "demon")
	else:
		_show_battle_result(stage.get("name", "关卡"), result, "战力不足，修炼/装备后再战", "beast" if _stage_order % 2 == 1 else "demon")
	_refresh_hud()
	_save()


## 组装 4 人队（修炼位上阵角色 → 角色定义 + 技能解析）
func _mk_team_from_slots() -> Array:
	var team: Array = []
	for i in range(3):
		var cid := String(_model.slots.get(i, ""))
		if cid.is_empty():
			continue
		var def: Dictionary = _char_def(cid)
		if def.is_empty():
			continue
		var skills: Array = []
		for sid in def.get("skills", []):
			var sk: Dictionary = _char_tbl.get("skills", {}).get(String(sid), {})
			if not sk.is_empty():
				skills.append(sk)
		team.append({
			"id": cid, "class": def.get("class", ""), "base": def.get("base", {}),
			"skills": skills,
		})
	return team


func _find_stage(order: int) -> Dictionary:
	for s in _battle_tbl.get("stages", []):
		if int(s.get("order", -1)) == order:
			return s
	return {}


## 按 stage_id 找关卡（如 s007）
func _find_stage_by_id(stage_id: String) -> Dictionary:
	for s in _battle_tbl.get("stages", []):
		if String(s.get("id", "")) == stage_id:
			return s
	return {}


# --------------------------- 抽卡页 ---------------------------

func _build_gacha() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 10)
	box.offset_left = 4
	box.offset_top = 4
	_content.add_child(box)

	var pool := _pool()
	var info := _mk_label("", 15)
	info.add_theme_color_override("font_color", C_DIM)
	box.add_child(info)
	_gacha_info = info

	var stage_row := HBoxContainer.new()
	stage_row.add_theme_constant_override("separation", 12)
	box.add_child(stage_row)
	# 演出区（紫气背景）
	var stage_panel := PanelContainer.new()
	stage_panel.custom_minimum_size = Vector2(420, 236)
	stage_panel.add_theme_stylebox_override("panel", _slot_style())
	_gacha_stage = TextureRect.new()
	_gacha_stage.custom_minimum_size = Vector2(400, 216)
	_gacha_stage.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gacha_stage.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if not _ziqi_frames.is_empty():
		_gacha_stage.texture = _ziqi_frames[0]
	stage_panel.add_child(_gacha_stage)
	stage_row.add_child(stage_panel)

	# 右侧操作列
	var ops := VBoxContainer.new()
	ops.add_theme_constant_override("separation", 10)
	ops.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_row.add_child(ops)
	var pool_name := _mk_label("常驻池", 22)
	pool_name.add_theme_color_override("font_color", C_GOLD)
	ops.add_child(pool_name)
	ops.add_child(_mk_label("保底：60 抽必出 >= 地品 / 90 抽必出 >= 天品", 14))
	ops.add_child(_mk_label("副产物：每抽 +1 源石碎片（升星用）", 14))
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 12)
	ops.add_child(row1)
	var btn1 := _mk_button("单抽（1 券）", func() -> void: _do_gacha(1))
	btn1.custom_minimum_size = Vector2(150, 44)
	row1.add_child(btn1)
	var btn10 := _mk_button("十连（10 券）", func() -> void: _do_gacha(10))
	btn10.custom_minimum_size = Vector2(150, 44)
	row1.add_child(btn10)

	var last := _mk_label("", 14)
	last.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ops.add_child(last)

	_refresh_gacha()


func _pool() -> Dictionary:
	var pools: Array = _gacha_tbl.get("pools", [])
	return pools[0] if not pools.is_empty() else {}


func _refresh_gacha() -> void:
	if _gacha_info == null:
		return
	var pool := _pool()
	var pid := String(pool.get("id", "standard"))
	var p: Dictionary = _model.gacha.get(pid, { "di_pity": 0, "tian_pity": 0 })
	var di := int(p.get("di_pity", 0))
	var tian := int(p.get("tian_pity", 0))
	var pity_di := int(pool.get("pity_di", 60))
	var pity_tian := int(pool.get("pity_tian", 90))
	_gacha_info.text = "宝物池（帝兵/功法/材料） · 当前保底：再 %d 抽必出 >= 地品 | 再 %d 抽必出 >= 天品" % [
		maxi(pity_di - di, 0), maxi(pity_tian - tian, 0)]
	_ticket_label.text = "抽卡券 %d" % _model.gacha_tickets


func _do_gacha(times: int) -> void:
	if _model.gacha_tickets < times:
		_show_popup("抽卡", "抽卡券不足：需要 %d 张（当前 %d）" % [times, _model.gacha_tickets])
		return
	var pool := _pool()
	if pool.is_empty():
		_show_popup("抽卡", "卡池数据缺失（gacha.json）")
		return
	_model.gacha_tickets -= times
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var results: Array = []
	for i in range(times):
		results.append(_draw_one(pool, rng))
	_gacha_seq += 1
	_play_gacha_show(results, times)
	_refresh_gacha()
	_save()


func _draw_one(pool: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var pid := String(pool.get("id", "standard"))
	var hero_c := _model.get_character(HERO_ID)
	var hero_sub := int(hero_c.get("sub_index", 8))
	var r := _gacha_svc.draw(_model, pid, rng, hero_sub)
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
			_model.inventory["mat_yuan_shard"] = int(_model.inventory.get("mat_yuan_shard", 0)) + 1
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
			_model.inventory["mat_yuan_shard"] = int(_model.inventory.get("mat_yuan_shard", 0)) + 1
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
	## G-05：源石碎片副产物入背包（原只返回不持久化 → 丢失）
	_model.inventory["mat_yuan_shard"] = int(_model.inventory.get("mat_yuan_shard", 0)) + int(r.get("yuan_shards", 1))
	return { "ok": true, "rarity": String(r.get("rarity", "fan")), "item_id": iid, "type": itype, "yuan_shards": 1, "fresh": fresh, "dup": dup }


## 抽卡演出：紫气三帧轮播 -> 展示最后一张卡面
func _play_gacha_show(results: Array, times: int) -> void:
	var seq := _gacha_seq
	var last: Dictionary = results[results.size() - 1]
	var dur := 0.35
	if not _ziqi_frames.is_empty():
		for i in range(_ziqi_frames.size()):
			var idx := i
			get_tree().create_timer(dur * i).timeout.connect(func() -> void:
				if seq != _gacha_seq or not is_instance_valid(_gacha_stage):
					return
				_gacha_stage.texture = _ziqi_frames[idx])
	## 结尾展示卡面（或结果文本）
	get_tree().create_timer(dur * 3).timeout.connect(func() -> void:
		if seq != _gacha_seq or not is_instance_valid(_gacha_stage):
			return
		_show_last_result(last))
	## 结果弹窗
	get_tree().create_timer(dur * 4.2).timeout.connect(func() -> void:
		if seq != _gacha_seq:
			return
		_show_gacha_summary(results, times))
	_flash_purple()


func _show_last_result(last: Dictionary) -> void:
	var iid := String(last.get("item_id", ""))
	var itype := String(last.get("type", "material"))
	if iid.is_empty() or itype == "material":
		_gacha_stage.texture = _ziqi_frames[0] if not _ziqi_frames.is_empty() else null
		return
	var tex: Texture2D = load(_treasure_icon_path(itype, iid))
	_gacha_stage.texture = tex if tex != null else (_ziqi_frames[0] if not _ziqi_frames.is_empty() else null)


func _show_gacha_summary(results: Array, times: int) -> void:
	var lines := PackedStringArray()
	var rarity_count := {}
	for r in results:
		var rar := String(r.get("rarity", "fan"))
		rarity_count[rar] = int(rarity_count.get(rar, 0)) + 1
		var iid := String(r.get("item_id", ""))
		var itype := String(r.get("type", "material"))
		var fresh := "（新）" if int(r.get("fresh", 0)) > 0 else ""
		lines.append("%s %s%s" % [_rarity_name(rar), _treasure_name(itype, iid), fresh])
	var count_parts := PackedStringArray()
	for k in rarity_count:
		count_parts.append("%s x%d" % [_rarity_name(k), rarity_count[k]])
	var count_txt := " | ".join(count_parts)
	_show_popup("抽卡结果 · %d 连" % times, "%s\n\n%s" % [count_txt, "\n".join(lines)])
	## 演出结束后舞台复位
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if _gacha_stage != null and is_instance_valid(_gacha_stage) and not _ziqi_frames.is_empty():
			_gacha_stage.texture = _ziqi_frames[0])


# --------------------------- 副本页（Sprint 3：5 资源副本 + 试炼塔） ---------------------------

func _build_dungeon() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 10)
	box.offset_left = 4
	box.offset_top = 4
	_content.add_child(box)

	var sec_title := _mk_title("副本 · 试炼（源石不入挂机，副本管质）")
	box.add_child(sec_title)

	var day := _day_key()
	## 副本列表（drop.json dungeons）——带 icon 行
	var dun_icons := {
		"yuanshi_mijing": "res://assets/icons/dun_yuanshi.webp",
		"lingshi_kuangmai": "res://assets/icons/dun_lingshi.webp",
	}
	for dun in _drop_tbl.get("dungeons", []):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_theme_stylebox_override("panel", _panel_style(C_PANEL, C_GOLD_DIM))
		box.add_child(row)
		var did := String(dun.get("id", ""))
		var done := int(_model.stats.get("dun_%s_%s" % [did, day], 0))
		var limit := int(dun.get("daily_limit", 99))
		var cost := int(dun.get("energy_cost", 10))
		var icon := TextureRect.new()
		var tex: Texture2D = load(String(dun_icons.get(did, "res://assets/icons/dun_lingshi.webp")))
		if tex != null:
			icon.texture = tex
			icon.custom_minimum_size = Vector2(36, 36)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			row.add_child(icon)
		var desc := _mk_label("%s（%d/%d 次 · 耗体 %d）" % [dun.get("name", did), done, limit, cost], 15)
		row.add_child(desc)
		var btn := _mk_button("挑战", func(did_v: String = did, cost_v: int = cost) -> void:
			_on_dungeon_pressed(did_v, cost_v))
		row.add_child(btn)

	## 试炼塔（带塔 icon）
	var tower: Dictionary = _drop_tbl.get("tower", {})
	var tfloor := int(_model.stats.get("tower_floor", 1))
	var tcost := int(tower.get("energy_per_floor", 5))
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 12)
	trow.add_theme_stylebox_override("panel", _panel_style(C_PANEL, Color("#9C6ADE")))
	box.add_child(trow)
	var ticon := TextureRect.new()
	var ttex: Texture2D = load("res://assets/icons/tower.webp")
	if ttex != null:
		ticon.texture = ttex
		ticon.custom_minimum_size = Vector2(36, 36)
		ticon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ticon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		trow.add_child(ticon)
	trow.add_child(_mk_label("试炼塔（当前第 %d 层 · 耗体 %d · 每 10 层奖源石）" % [tfloor, tcost], 15))
	trow.add_child(_mk_button("挑战", _on_tower_pressed))

	var hint := _mk_label("提示：源石秘境出源石（破境用）| 灵石矿脉出灵石 | 试炼塔节点奖源石 | 每日次数与体力共用上限", 14)
	hint.add_theme_color_override("font_color", C_DIM)
	box.add_child(hint)


func _on_dungeon_pressed(dungeon_id: String, _cost: int) -> void:
	var day := _day_key()
	var r := _drop_svc.run_dungeon(_model, dungeon_id, 1, day)
	if not r.get("ok", false):
		var reasons := { "no_energy": "体力不足", "daily_limit": "今日次数已用完", "dungeon_not_found": "副本不存在", "tier_not_found": "档位未解锁" }
		_show_battle_result("副本 · %s" % dungeon_id, { "winner": "enemy", "rounds": 4, "stars": 0 },
			String(reasons.get(String(r.get("reason", "?")), String(r.get("reason", "?")))), "demon")
		return
	var drops: Dictionary = r.get("drops", {})
	var lines := PackedStringArray()
	if drops.has("yuan"):
		lines.append("源石 +%d" % drops["yuan"])
	if drops.has("ling"):
		lines.append("灵石 +%d" % drops["ling"])
	if drops.has("yuan_shard"):
		lines.append("源石碎片 +%d" % drops["yuan_shard"])
	if drops.has("exp_book"):
		lines.append("经验书 +%d" % drops["exp_book"])
	var dun_name := dungeon_id
	for dun in _drop_tbl.get("dungeons", []):
		if String(dun.get("id", "")) == dungeon_id:
			dun_name = String(dun.get("name", dungeon_id))
			break
	_show_battle_result("副本 · %s" % dun_name, { "winner": "player", "rounds": 3, "stars": 3 },
		"掉落：%s" % ("，".join(lines) if not lines.is_empty() else "无"), "demon")
	_refresh_hud()
	_save()


func _on_tower_pressed() -> void:
	var power := _team_power()
	var day := _day_key()
	var r := _drop_svc.run_tower(_model, power, day)
	if not r.get("ok", false):
		var reasons := { "no_energy": "体力不足", "daily_limit": "今日已爬满上限层数", "tower_cleared": "已通关全部层", "defeat": "战力不足，挑战失败（不推进）" }
		_show_battle_result("试炼塔", { "winner": "enemy", "rounds": 5, "stars": 0 },
			String(reasons.get(String(r.get("reason", "?")), String(r.get("reason", "?")))))
		_refresh_hud()
		_save()
		return
	var drops: Dictionary = r.get("drops", {})
	var lines := PackedStringArray()
	for k in drops:
		lines.append("%s +%d" % [_drop_name(k), drops[k]])
	_show_battle_result("试炼塔 · 第 %d 层" % int(r.get("floor", 0)),
		{ "winner": "player", "rounds": 4, "stars": 3 },
		"奖励：%s" % ("，".join(lines) if not lines.is_empty() else "无"))
	_refresh_hud()
	_save()


func _team_power() -> float:
	## 单主角修仙：主角战力（含装备加成）
	var hero_def: Dictionary = _char_def(HERO_ID)
	var base: Dictionary = hero_def.get("base", {})
	var equip := _eq_svc.total_bonus(_model)
	var atk := float(base.get("atk", 120)) + float(equip.get("atk", 0))
	var def_ := float(base.get("def", 80)) + float(equip.get("def", 0))
	var hp := float(base.get("hp", 1500)) + float(equip.get("hp", 0))
	return atk * 2.0 + def_ * 1.5 + hp * 0.05


func _drop_name(k: String) -> String:
	var names := { "ling": "灵石", "yuan": "源石", "yuan_shard": "源石碎片", "exp_book": "经验书", "artifact_mat": "法宝材料", "skill_mat": "功法材料", "gacha_ticket": "抽卡券" }
	return String(names.get(k, k))


## 日键（本地日期 yyyymmdd；服务端权威后改服务器日期）
func _day_key() -> String:
	var dt := Time.get_date_dict_from_unix_time(TimeService.now())
	return "%04d%02d%02d" % [dt.year, dt.month, dt.day]


func _mk_roster_card(cid: String) -> Control:
	var def: Dictionary = _char_def(cid)
	var c: Dictionary = _model.get_character(cid)
	var rar := String(def.get("rarity", "fan"))
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(0, 190)
	card.add_theme_constant_override("separation", 3)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _slot_style())
	panel.add_child(card)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(88, 88)
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var tex: Texture2D = load(_char_avatar_path(cid))
	if tex != null:
		avatar.texture = tex
	card.add_child(avatar)

	var name_l := _mk_label(String(def.get("name", cid)), 16)
	name_l.add_theme_color_override("font_color", RARITY_COLOR.get(rar, C_TEXT))
	card.add_child(name_l)
	card.add_child(_mk_label("%s · %s" % [_rarity_name(rar), _class_name(def)], 13))
	card.add_child(_mk_label(_sub_name(int(c.get("sub_index", 0))), 13))
	card.add_child(_mk_label("Lv.%d  ★%d" % [int(c.get("level", 1)), int(c.get("star", 1))], 12))

	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_open_char_detail(cid))
	return panel


func _open_char_detail(cid: String) -> void:
	var def: Dictionary = _char_def(cid)
	var c: Dictionary = _model.get_character(cid)
	var rar := String(def.get("rarity", "fan"))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	body.add_child(head)
	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(96, 96)
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var tex: Texture2D = load(_char_card_path(cid))
	if tex != null:
		avatar.texture = tex
	head.add_child(avatar)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	head.add_child(info)
	var nm := _mk_label(String(def.get("name", cid)), 20)
	nm.add_theme_color_override("font_color", RARITY_COLOR.get(rar, C_TEXT))
	info.add_child(nm)
	info.add_child(_mk_label("%s · %s · %s" % [_rarity_name(rar), _class_name(def), _faction_name(def)], 14))
	info.add_child(_mk_label("境界：%s" % _sub_name(int(c.get("sub_index", 0))), 14))
	info.add_child(_mk_label("等级 %d  星级 %d  碎片 %d" % [
		int(c.get("level", 1)), int(c.get("star", 1)), int(c.get("fragments", 0))], 14))
	body.add_child(_mk_label("缘语：%s" % String(def.get("flavor", "")), 14))
	var skills: Array = def.get("skills", [])
	var skill_names := PackedStringArray()
	for sid in skills:
		var sk: Dictionary = _char_tbl.get("skills", {}).get(String(sid), {})
		skill_names.append(String(sk.get("name", sid)))
	body.add_child(_mk_label("功法：%s" % " / ".join(skill_names), 13))
	var in_slot := _role_in_slot(cid)
	body.add_child(_mk_label("上阵：%s" % ("修炼位%d" % (in_slot + 1) if in_slot >= 0 else "未上阵"), 13))
	_show_custom_popup("角色详情", body, func() -> bool: return true)


# --------------------------- 主循环 / 刷新 / 存档 ---------------------------

func _process(delta: float) -> void:
	if not _waiting:
		_pending_ling += _sum_rate() * delta
		if _cur_tab == "main" and _collect_label != null:
			_collect_label.text = "待领取 %d 灵" % int(_pending_ling)
	else:
		var now_ts := TimeService.now()
		var total := float(_wait_end_ts - _wait_start_ts)
		if total > 0.0 and _wait_bar != null:
			_wait_bar.value = float(now_ts - _wait_start_ts)
		if now_ts >= _wait_end_ts:
			_waiting = false
			if _wait_bar != null and is_instance_valid(_wait_bar):
				_wait_bar.visible = false
			if _btn_wait_speed != null and is_instance_valid(_btn_wait_speed):
				_btn_wait_speed.visible = false
			_do_breakthrough(_wait_for_sub)
			_show_popup("破境完成", "轮海毕业 -> 道宫！紫气东来")


func _refresh_main_light() -> void:
	_collect_label.text = "待领取 %d 灵" % int(_pending_ling)


func _refresh_hud() -> void:
	_ling_label.text = "灵石 %d" % _model.ling
	_yuan_label.text = "源石 %d" % _model.yuan
	_ticket_label.text = "体力 %d/%d · 抽卡券 %d" % [_model.energy, _model.ENERGY_CAP, _model.gacha_tickets]
	## 资源色彩分级（可读性）：灵石=鎏金、源石=星紫、体力=锈铜
	_ling_label.add_theme_color_override("font_color", C_GOLD)
	_yuan_label.add_theme_color_override("font_color", Color("#9C6ADE"))
	_ticket_label.add_theme_color_override("font_color", Color("#B08968"))
	_realm_label.text = _realm_name()
	_stage_label.text = "已通关 %d/%d 关" % [min(_model.highest_cleared_order(), MAX_SLICE_STAGES), MAX_SLICE_STAGES]
	_refresh_gacha()
	if _cur_tab == "main":
		_status_label.text = "下一关：第 %d 关 | 修炼位 %d/3 已占用 | 推关耗体力 %d" % [_stage_order, _active_count(), int(_battle_tbl.get("energy", {}).get("stage_cost", 10))]
	elif _cur_tab == "gacha":
		_status_label.text = "抽卡券余额 %d | 保底跨池继承，出 >= 地品后重置地保底" % _model.gacha_tickets
	elif _cur_tab == "dungeon":
		_status_label.text = "副本每日有次数限制，体力共担；试炼塔每 10 层奖源石" 
	else:
		_status_label.text = "图鉴 %d/6 | 点击角色查看详情，修炼位上阵可并行产出" % _model.characters.size()


# --------------------------- 数据查询 ---------------------------

func _char_def(char_id: String) -> Dictionary:
	for c in _char_tbl.get("characters", []):
		if c.get("id") == char_id:
			return c
	return {}


func _char_name(char_id: String) -> String:
	return String(_char_def(char_id).get("name", char_id))


## 宝物名称（装备查 equipment.json / 功法查 skill_sets.json / 材料）
func _treasure_name(itype: String, iid: String) -> String:
	if itype == "equipment":
		return String(_eq_svc.find_item(iid).get("name", iid))
	if itype == "skill":
		return String(_sk_svc.find_book(iid).get("name", iid))
	if itype == "material":
		if iid == "mat_ling_pack":
			return "灵石包"
		if iid == "mat_yuan_shard":
			return "源石碎片"
		return iid
	return iid


## 宝物 icon 路径（装备按槽位图 / 功法按分类图 / 材料占位）
func _treasure_icon_path(itype: String, iid: String) -> String:
	if itype == "equipment":
		var item := _eq_svc.find_item(iid)
		var slot_id := String(item.get("slot", ""))
		var icon_map := {
			"weapon": "res://assets/icons/equip_weapon.webp",
			"armor": "res://assets/icons/equip_armor.webp",
			"accessory": "res://assets/icons/equip_accessory.webp",
			"talisman": "res://assets/icons/equip_talisman.webp",
		}
		return String(icon_map.get(slot_id, "res://assets/icons/equip_weapon.webp"))
	if itype == "skill":
		var book := _sk_svc.find_book(iid)
		var cat := String(book.get("category", ""))
		if cat == "cultivation":
			return "res://assets/icons/skill_cultivation.webp"
		if cat == "combat":
			return "res://assets/icons/skill_combat.webp"
		return "res://assets/icons/skill_book.webp"
	return "res://assets/icons/res_ling.webp"


func _class_name(def: Dictionary) -> String:
	var names: Dictionary = _char_tbl.get("class_names", {})
	return String(names.get(String(def.get("class", "")), "?")) if not def.is_empty() else "?"


func _faction_name(def: Dictionary) -> String:
	var m := { "donghuang": "东荒", "zhongzhou": "中州", "beidou": "北斗" }
	return String(m.get(String(def.get("faction", "")), String(def.get("faction", "?"))))


func _rarity_name(r: String) -> String:
	return String(RARITY_NAME.get(r, r))


func _char_card_path(cid: String) -> String:
	return "res://assets/characters/character_%s_card.png" % cid


func _char_avatar_path(cid: String) -> String:
	return "res://assets/characters/character_%s_avatar.png" % cid


func _role_in_slot(char_id: String) -> int:
	for i in range(3):
		if String(_model.slots.get(i, "")) == char_id:
			return i
	return -1


func _hero_sub() -> int:
	var c := _model.get_character(HERO_ID)
	return int(c.get("sub_index", 0))


func _realm_name() -> String:
	var sub := _hero_sub()
	var def := _char_def(HERO_ID)
	var realm_id := String(def.get("realm", "lunhai")) if not def.is_empty() else "lunhai"
	return "%s · %s" % [realm_id.to_upper(), _sub_name(sub)]


func _sub_name(sub: int) -> String:
	for r in _realm_tbl.get("realms", []):
		for s in r.get("sub_stages", []):
			if int(s.get("index", -1)) == sub:
				return String(s.get("name", "?"))
	return "境界 %d" % sub


func _show_popup(title: String, msg: String) -> void:
	_popup_title.text = title
	_popup_label.text = msg
	_popup.visible = true
	## 入场动画：弹窗缩放回弹 + 淡入（方舟式弹窗手感）
	_pop_box.scale = Vector2(0.88, 0.88)
	_pop_box.modulate.a = 0.0
	_popup.modulate.a = 1.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_pop_box, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_pop_box, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _flash_purple() -> void:
	_flash.color = Color(C_PURPLE.r, C_PURPLE.g, C_PURPLE.b, 0.55)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 1.2)


## 战斗演出层（主角 vs 敌人 · 攻防动画 · 飘字 · 胜负）
## 独立挂载到 _battle_layer（新建节点），绝不碰 _popup 常驻弹窗结构


func _show_battle_result(stage_name: String, result: Dictionary, note: String, enemy_kind: String = "beast") -> void:
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
	var enemy_path := "res://assets/icons/enemy_beast.webp"
	if enemy_kind == "demon":
		enemy_path = "res://assets/icons/enemy_demon.webp"
	var etex: Texture2D = load(enemy_path)
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
	## 血条从满血起步，逐回合扣真实伤害，结算时对齐最终血量（修复：原误用最终值起步）
	var hero_left := hero_max
	var enemy_left := enemy_max

	_battle_layer.visible = true
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
		dmg.text = "伤害 %d" % int(enemy_dmgs[0]))
	tw.tween_property(dmg, "modulate:a", 1.0, 0.08)
	tw.tween_property(dmg, "position:y", dmg.position.y - 40, 0.5)
	tw.tween_property(dmg, "modulate:a", 0.0, 0.28)
	tw.tween_property(enemy_flash, "color:a", 0.5, 0.06)
	tw.tween_property(enemy_flash, "color:a", 0.0, 0.2)
	tw.tween_callback(func() -> void:
		enemy_left = maxf(enemy_left - float(enemy_dmgs[0]), 0.0)
		enemy_bar.value = enemy_left
		enemy_bar_txt.text = "HP %d/%d" % [int(enemy_left), int(enemy_max)])
	## 怪物反击（前冲 + 主角受击闪红 + 敌方飘字）
	tw.tween_property(enemy_img, "position", Vector2(enemy_home.x - 130, enemy_home.y), 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(enemy_img, "position", enemy_home, 0.16)
	tw.tween_callback(func() -> void:
		dmg.text = "敌伤 %d" % int(hero_dmgs[0]))
	tw.tween_property(dmg, "modulate:a", 1.0, 0.08)
	tw.tween_property(dmg, "position:y", dmg.position.y - 40, 0.5)
	tw.tween_property(dmg, "modulate:a", 0.0, 0.28)
	tw.tween_property(hero_flash, "color:a", 0.45, 0.06)
	tw.tween_property(hero_flash, "color:a", 0.0, 0.2)
	tw.tween_callback(func() -> void:
		hero_left = maxf(hero_left - float(hero_dmgs[0]), 0.0)
		hero_bar.value = hero_left
		hero_bar_txt.text = "HP %d/%d" % [int(hero_left), int(hero_max)])
	## 回合 2：主角攻 → 怪物反击
	tw.tween_property(hero_img, "position", Vector2(hero_home.x + 130, hero_home.y), 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(hero_img, "position", hero_home, 0.16)
	tw.tween_callback(func() -> void:
		dmg.text = ("伤害 %d" % int(enemy_dmgs[1])) if enemy_dmgs.size() > 1 else ("伤害 %d" % int(enemy_dmgs[0])))
	tw.tween_property(dmg, "modulate:a", 1.0, 0.08)
	tw.tween_property(dmg, "position:y", dmg.position.y - 40, 0.5)
	tw.tween_property(dmg, "modulate:a", 0.0, 0.28)
	tw.tween_property(enemy_flash, "color:a", 0.5, 0.06)
	tw.tween_property(enemy_flash, "color:a", 0.0, 0.2)
	tw.tween_callback(func() -> void:
		var d2 := float(enemy_dmgs[1]) if enemy_dmgs.size() > 1 else 100.0
		enemy_left = maxf(enemy_left - d2, 0.0)
		enemy_bar.value = enemy_left
		enemy_bar_txt.text = "HP %d/%d" % [int(enemy_left), int(enemy_max)])
	tw.tween_property(enemy_img, "position", Vector2(enemy_home.x - 130, enemy_home.y), 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(enemy_img, "position", enemy_home, 0.16)
	tw.tween_callback(func() -> void:
		dmg.text = ("敌伤 %d" % int(hero_dmgs[1])) if hero_dmgs.size() > 1 else ("敌伤 %d" % int(hero_dmgs[0])))
	tw.tween_property(dmg, "modulate:a", 1.0, 0.08)
	tw.tween_property(dmg, "position:y", dmg.position.y - 40, 0.5)
	tw.tween_property(dmg, "modulate:a", 0.0, 0.28)
	tw.tween_property(hero_flash, "color:a", 0.45, 0.06)
	tw.tween_property(hero_flash, "color:a", 0.0, 0.2)
	tw.tween_callback(func() -> void:
		var d2 := float(hero_dmgs[1]) if hero_dmgs.size() > 1 else 100.0
		hero_left = maxf(hero_left - d2, 0.0)
		hero_bar.value = hero_left
		hero_bar_txt.text = "HP %d/%d" % [int(hero_left), int(hero_max)])
	## 胜负演出：血条对齐真实结算血量（播完 2 回合后跳转最终值）
	tw.tween_callback(func() -> void:
		hero_bar.value = hero_cur
		hero_bar_txt.text = "HP %d/%d" % [int(hero_cur), int(hero_max)]
		enemy_bar.value = enemy_cur
		enemy_bar_txt.text = "HP %d/%d" % [int(enemy_cur), int(enemy_max)])
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
		var stats_txt := ""
		var cc := int(result.get("crit_count", 0))
		var dc := int(result.get("dodge_count", 0))
		if cc > 0: stats_txt += "暴击 %d 次" % cc
		if dc > 0: stats_txt += (" · " if stats_txt != "" else "") + "闪避 %d 次" % dc
		result_label.text += "\n" + note + (("  （" + stats_txt + "）") if stats_txt != "" else ""))
	ok_btn.modulate.a = 0.0
	tw.tween_property(ok_btn, "modulate:a", 1.0, 0.2)


func _save() -> void:
	_model.last_offline_ts = TimeService.now()
	if _auth != null and _auth.is_logged_in():
		SaveManager.save(_model, _auth.current_user())
	else:
		SaveManager.save(_model)


## 测试/正式版区分：编辑器模式 或 URL 带 ?debug=1 时启用调试区（正式发布关掉）
func _debug_mode() -> bool:
	if OS.has_feature("editor"):
		return true
	if OS.has_feature("web"):
		var q: String = JavaScriptBridge.eval("window.location.search")
		return q.contains("debug=1")
	return false


## 调试：重置存档（删 user:// 存档并重开新档）
func _on_debug_reset() -> void:
	SaveManager.delete_save()
	_model = SaveModel.default_save()
	_model.gacha_tickets = 30
	_stage_order = 1
	_pending_ling = 0.0
	_waiting = false
	_refresh_slots()
	_refresh_hud()
	_show_popup("调试", "存档已重置（新档 30 抽卡券）")


# --------------------------- 装备页 ---------------------------

func _build_equip() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 10)
	box.offset_left = 4; box.offset_top = 4
	_content.add_child(box)
	box.add_child(_mk_title("装备培养 · 强化升阶", 20))
	var bonus := _eq_svc.total_bonus(_model)
	box.add_child(_mk_icon_label("总加成：ATK+%d  DEF+%d  HP+%d" % [bonus.atk, bonus.def, bonus.hp], "res://assets/icons/equip_weapon.webp", 15))
	## 装备格（4 槽：武器/防具/饰品/符箓）——格子卡片 + icon
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 12)
	box.add_child(grid)
	for sl in _eq_tbl.get("slots", []):
		var sid := String(sl.get("id", ""))
		var item_id := String(_model.equipment.get(sid, ""))
		var lv := int(_model.stats.get("eq_lv_%s" % sid, 1))
		## 槽位格子（PanelContainer 卡片）
		var cell := PanelContainer.new()
		cell.add_theme_stylebox_override("panel", _panel_style(C_SLOT, C_GOLD))
		cell.custom_minimum_size = Vector2(150, 170)
		grid.add_child(cell)
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		cell.add_child(vbox)
		## 槽位 icon（武器/防具/饰品/符箓各一张）
		var icon_map := {
			"weapon": "res://assets/icons/equip_weapon.webp",
			"armor": "res://assets/icons/equip_armor.webp",
			"accessory": "res://assets/icons/equip_accessory.webp",
			"talisman": "res://assets/icons/equip_talisman.webp",
		}
		var icon := TextureRect.new()
		var tex: Texture2D = load(String(icon_map.get(sid, "")))
		if tex != null:
			icon.texture = tex
			icon.custom_minimum_size = Vector2(64, 64)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			vbox.add_child(icon)
		vbox.add_child(_mk_label("%s" % sl.get("name", "?"), 15))
		var item_name := "空" if item_id.is_empty() else String(_eq_svc.find_item(item_id).get("name", item_id))
		vbox.add_child(_mk_dim("%s Lv.%d" % [item_name, lv], 13))
		var btns := HBoxContainer.new()
		btns.add_theme_constant_override("separation", 6)
		vbox.add_child(btns)
		var en_btn := _mk_button("强化", func(sid_v: String = sid) -> void: _on_enhance(sid_v))
		en_btn.disabled = item_id.is_empty()
		btns.add_child(en_btn)
		var info_btn := _mk_button("详情", func(sid_v: String = sid) -> void: _show_equip_detail(sid_v))
		info_btn.disabled = item_id.is_empty()
		btns.add_child(info_btn)
	box.add_child(_mk_dim("提示：武器=atk / 防具=def+hp / 饰品=均衡 / 符箓=减伤；强化消耗灵石提升属性", 14))

func _on_enhance(slot_id: String) -> void:
	var r := _eq_svc.enhance(_model, slot_id)
	if not r.get("ok", false):
		_show_popup("强化失败", String(r.get("reason", "?")))
		return
	_show_popup("强化成功", "%s 强化完成（ATK+%d DEF+%d HP+%d）" % [slot_id, r.atk_bonus, r.def_bonus, r.hp_bonus])
	_refresh_hud()
	_save()


## 装备详情弹窗：稀有度/等级/属性/描述
func _show_equip_detail(slot_id: String) -> void:
	var item_id := String(_model.equipment.get(slot_id, ""))
	if item_id.is_empty():
		return
	var item := _eq_svc.find_item(item_id)
	if item.is_empty():
		return
	var lv := int(_model.stats.get("eq_lv_%s" % slot_id, 1))
	var growth := float(item.get("growth", 0.10))
	var atk := int(float(item.get("base_atk", 0)) * (1.0 + growth * (lv - 1)))
	var def_ := int(float(item.get("base_def", 0)) * (1.0 + growth * (lv - 1)))
	var hp := int(float(item.get("base_hp", 0)) * (1.0 + growth * (lv - 1)))
	var lines := PackedStringArray()
	lines.append("【%s】%s" % [_rarity_name(String(item.get("rarity", "fan"))), item.get("name", item_id)])
	lines.append("部位：%s · 等级 Lv.%d" % [item.get("slot", "?"), lv])
	if atk > 0: lines.append("攻击 +%d" % atk)
	if def_ > 0: lines.append("防御 +%d" % def_)
	if hp > 0: lines.append("生命 +%d" % hp)
	lines.append("")
	lines.append(String(item.get("desc", "")))
	_show_popup("装备详情", "\n".join(lines))


# --------------------------- 背包页 ---------------------------

func _build_bag() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 8)
	box.offset_left = 4; box.offset_top = 4
	_content.add_child(box)
	box.add_child(_mk_title("背包 · 所有获得物", 20))
	var items: Array = _model.inventory.keys()
	if items.is_empty():
		box.add_child(_mk_dim("背包空空如也——抽卡/副本获得物品会显示在这里", 14))
		return
	for k in items:
		var iid := String(k)
		var count := int(_model.inventory[iid])
		if count <= 0:
			continue
		var name := _treasure_name("", iid)
		var kind := _bag_kind(iid)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_theme_stylebox_override("panel", _panel_style(C_PANEL, C_GOLD_DIM))
		box.add_child(row)
		var icon := TextureRect.new()
		var tex: Texture2D = load(_bag_icon(iid))
		if tex != null:
			icon.texture = tex
			icon.custom_minimum_size = Vector2(32, 32)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			row.add_child(icon)
		row.add_child(_mk_label("%s ×%d" % [name, count], 15))
		row.add_child(_mk_dim(kind, 13))
		## NUM-023：源石碎片 5:1 兑换源石
		if iid == "mat_yuan_shard" and count >= 5:
			row.add_child(_mk_button("兑换源石", func() -> void: _on_exchange_shards(), C_GOLD))
	box.add_child(_mk_dim("提示：重复帝兵/功法会转化为命座或残卷材料；装备强化/功法修炼消耗灵石与残卷；源石碎片 5:1 可兑换源石", 13))


## NUM-023：源石碎片 5:1 兑换源石（死货币消费路径）
func _on_exchange_shards() -> void:
	var shards := int(_model.inventory.get("mat_yuan_shard", 0))
	var exchange := shards / 5
	if exchange <= 0:
		_show_popup("兑换", "源石碎片不足 5 个")
		return
	_model.inventory["mat_yuan_shard"] = shards - exchange * 5
	_model.yuan += exchange
	_save()
	_switch_tab("bag")
	_show_popup("兑换成功", "源石碎片 ×%d 兑换为 源石 +%d（余 %d 碎片）" % [exchange * 5, exchange, shards - exchange * 5])


## 背包物品类别
func _bag_kind(iid: String) -> String:
	if iid.begins_with("e_"):
		return "帝兵"
	if iid.begins_with("sk_"):
		return "功法"
	if iid == "mat_equip_shard":
		return "装备残卷"
	if iid == "mat_skill_shard":
		return "功法残卷"
	if iid == "mat_ling_pack":
		return "灵石包"
	if iid == "mat_yuan_shard":
		return "源石碎片"
	return "材料"


## 背包物品 icon
func _bag_icon(iid: String) -> String:
	if iid.begins_with("e_"):
		var item := _eq_svc.find_item(iid)
		var slot := String(item.get("slot", ""))
		var m := {"weapon": "equip_weapon", "armor": "equip_armor", "accessory": "equip_accessory", "talisman": "equip_talisman"}
		return "res://assets/icons/%s.webp" % String(m.get(slot, "equip_weapon"))
	if iid.begins_with("sk_"):
		var book := _sk_svc.find_book(iid)
		var cat := String(book.get("category", ""))
		if cat == "cultivation": return "res://assets/icons/skill_cultivation.webp"
		if cat == "combat": return "res://assets/icons/skill_combat.webp"
		return "res://assets/icons/skill_book.webp"
	if iid == "mat_ling_pack": return "res://assets/icons/res_ling.webp"
	if iid == "mat_yuan_shard": return "res://assets/icons/res_yuan.webp"
	return "res://assets/icons/skill_book.webp"


# --------------------------- 功法页 ---------------------------

func _build_skill() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 10)
	box.offset_left = 4; box.offset_top = 4
	_content.add_child(box)
	box.add_child(_mk_title("功法修习 · 修仙", 20))
	## 已装备功法格（3 格，格子卡片 + icon）
	var slots := int(_sk_tbl.get("active_slots", 3))
	var eq_row := HBoxContainer.new()
	eq_row.add_theme_constant_override("separation", 10)
	box.add_child(eq_row)
	for i in range(slots):
		var cell := PanelContainer.new()
		cell.add_theme_stylebox_override("panel", _panel_style(C_SLOT, Color("#9C6ADE")))
		cell.custom_minimum_size = Vector2(160, 120)
		eq_row.add_child(cell)
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		cell.add_child(vbox)
		var book_id := String(_model.active_skills[i]) if i < _model.active_skills.size() else ""
		if not book_id.is_empty():
			var bk := _sk_svc.find_book(book_id)
			var icon := TextureRect.new()
			var tex: Texture2D = load("res://assets/icons/skill_book.webp")
			if tex != null:
				icon.texture = tex
				icon.custom_minimum_size = Vector2(40, 40)
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				vbox.add_child(icon)
			vbox.add_child(_mk_label("%s" % bk.get("name", book_id), 14))
			vbox.add_child(_mk_dim("Lv.%d" % int(_model.stats.get("sk_lv_%s" % book_id, 1)), 12))
		else:
			vbox.add_child(_mk_label("空", 14))
			vbox.add_child(_mk_dim("点击下方功法装备", 11))
	## 功法列表（格子卡片：icon + 名称 + 等级 + 修炼/装备）
	var list_title := _mk_label("—— 已解锁功法 ——", 15)
	list_title.add_theme_color_override("font_color", C_DIM)
	box.add_child(list_title)
	var unlocked_arr := String(_model.stats.get("unlocked_skills", "")).split(",", false)
	for b in _sk_tbl.get("books", []):
		var bid := String(b.get("id", ""))
		if not unlocked_arr.has(bid) and not _model.active_skills.has(bid):
			continue
		var lv := int(_model.stats.get("sk_lv_%s" % bid, 1))
		var equipped := _model.active_skills.has(bid)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_theme_stylebox_override("panel", _panel_style(C_PANEL, C_GOLD_DIM))
		box.add_child(row)
		var icon := TextureRect.new()
		var cat2 := String(b.get("category", ""))
		var icon_path2 := "res://assets/icons/skill_book.webp"
		if cat2 == "cultivation":
			icon_path2 = "res://assets/icons/skill_cultivation.webp"
		elif cat2 == "combat":
			icon_path2 = "res://assets/icons/skill_combat.webp"
		var tex2: Texture2D = load(icon_path2)
		if tex2 != null:
			icon.texture = tex2
			icon.custom_minimum_size = Vector2(36, 36)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			row.add_child(icon)
		row.add_child(_mk_label("%s Lv.%d [%s]%s" % [b.get("name", "?"), lv, b.get("category", "?"), " (已装备)" if equipped else ""], 15))
		var con := int(_model.stats.get("sk_con_%s" % bid, 0))
		if con > 0:
			row.add_child(_mk_label("命座%d" % con, 13))
		row.add_child(_mk_button("修炼", func(bid_v: String = bid) -> void: _on_train_skill(bid_v)))
		row.add_child(_mk_button("装备" if not equipped else "卸下", func(bid_v: String = bid) -> void: _on_toggle_skill(bid_v)))
		row.add_child(_mk_button("详情", func(bid_v: String = bid) -> void: _show_skill_detail(bid_v)))

func _on_train_skill(book_id: String) -> void:
	var r := _sk_svc.train(_model, book_id)
	if not r.get("ok", false):
		var reason := String(r.get("reason", "?"))
		if reason == "no_shard":
			_show_popup("修炼失败", "功法残卷不足（Lv5 后每级需 1 残卷）——重复抽取同名功法可获残卷")
		else:
			_show_popup("修炼失败", String(r.get("reason", "?")))
		return
	var cost_txt := "消耗灵石 %d" % r.cost
	if int(r.get("shard_cost", 0)) > 0:
		cost_txt += " · 功法残卷 %d" % r.shard_cost
	_show_popup("修炼成功", "%s 修炼完成 Lv.%d（%s）" % [_sk_svc.find_book(book_id).get("name", book_id), r.level, cost_txt])
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

## 功法详情弹窗：稀有度/等级/效果/命座/描述
func _show_skill_detail(book_id: String) -> void:
	var book := _sk_svc.find_book(book_id)
	if book.is_empty():
		return
	var lv := int(_model.stats.get("sk_lv_%s" % book_id, 1))
	var con := int(_model.stats.get("sk_con_%s" % book_id, 0))
	var eff_name := {"idle_rate": "修炼速率", "atk_bonus": "攻击力", "energy_recover": "体力恢复", "yuan_bonus": "源石收益"}
	var lines := PackedStringArray()
	lines.append("【%s】%s" % [_rarity_name(String(book.get("rarity", "fan"))), book.get("name", book_id)])
	lines.append("类别：%s · 等级 Lv.%d" % [book.get("category", "?"), lv])
	lines.append("效果：%s +%d%%" % [eff_name.get(String(book.get("effect", "")), "?"), int(float(book.get("value", 0.0)) * lv * 100)])
	if con > 0:
		lines.append("命座：%d 阶（效果 ×%.1f）" % [con, 1.0 + 0.25 * con])
	lines.append("")
	lines.append(String(book.get("desc", "")))
	_show_popup("功法详情", "
".join(lines))

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
