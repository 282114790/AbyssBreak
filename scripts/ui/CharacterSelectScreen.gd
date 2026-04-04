# CharacterSelectScreen.gd
# 角色选择界面 - 游戏开始前展示
extends CanvasLayer

signal character_selected(character_id: String)
signal daily_challenge_requested

var _registry: Node = null
var _meta: Node = null
var _selected_id: String = "mage"
var _daily_challenge: Node = null

func _ready() -> void:
	layer = 20
	visible = false

func show_screen(registry: Node, meta: Node) -> void:
	_registry = registry
	_meta = meta
	_selected_id = registry.selected_id
	visible = true
	# 初始化每日挑战
	_daily_challenge = Node.new()
	_daily_challenge.set_script(load("res://scripts/systems/DailyChallenge.gd"))
	add_child(_daily_challenge)
	_build_ui()
	# 播放菜单BGM
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_bgm_menu"): sm.play_bgm_menu()

func _build_ui() -> void:
	for c in get_children(): c.queue_free()

	# 背景
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.14, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 标题
	var title = Label.new()
	title.text = "选择你的角色"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 40
	title.offset_bottom = 90
	add_child(title)

	# 角色卡片区域
	var cards_container = HBoxContainer.new()
	cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_container.add_theme_constant_override("separation", 24)
	cards_container.set_anchors_preset(Control.PRESET_CENTER)
	cards_container.offset_left   = -500
	cards_container.offset_right  = 500
	cards_container.offset_top    = -160
	cards_container.offset_bottom = 180
	add_child(cards_container)

	for char_data in _registry.all_characters:
		var unlocked = _registry.is_unlocked(char_data.id, _meta)
		cards_container.add_child(_make_card(char_data, unlocked))

	# 开始按钮
	var start_btn = Button.new()
	start_btn.text = "▶  进入深渊"
	start_btn.add_theme_font_size_override("font_size", 22)
	start_btn.custom_minimum_size = Vector2(240, 56)
	start_btn.anchor_left   = 0.5
	start_btn.anchor_right  = 0.5
	start_btn.anchor_top    = 1.0
	start_btn.anchor_bottom = 1.0
	start_btn.offset_left   = -120
	start_btn.offset_right  = 120
	start_btn.offset_top    = -80
	start_btn.offset_bottom = -24
	start_btn.pressed.connect(func():
		_registry.selected_id = _selected_id
		visible = false
		# 切换到战斗BGM
		var sm = get_tree().get_first_node_in_group("sound_manager")
		if sm and sm.has_method("play_bgm_battle"): sm.play_bgm_battle()
		emit_signal("character_selected", _selected_id)
	)
	add_child(start_btn)

	# ── 每日挑战按钮 ──
	var daily_btn = Button.new()
	var is_done = _daily_challenge and _daily_challenge.is_completed_today()
	var dc_config: Dictionary = {}
	if _daily_challenge:
		dc_config = _daily_challenge.get_challenge_config()

	if is_done:
		daily_btn.text = "✅ 每日挑战（今日已完成）"
		daily_btn.disabled = true
	else:
		var mod_name = dc_config.get("modifier_name", "")
		daily_btn.text = "📅 每日挑战 — %s" % mod_name

	daily_btn.add_theme_font_size_override("font_size", 16)
	daily_btn.custom_minimum_size = Vector2(340, 48)
	daily_btn.anchor_left   = 0.5
	daily_btn.anchor_right  = 0.5
	daily_btn.anchor_top    = 1.0
	daily_btn.anchor_bottom = 1.0
	daily_btn.offset_left   = -170
	daily_btn.offset_right  = 170
	daily_btn.offset_top    = -150
	daily_btn.offset_bottom = -100

	if not is_done and not dc_config.is_empty():
		var dc_style = StyleBoxFlat.new()
		dc_style.bg_color = Color(0.08, 0.12, 0.25)
		dc_style.border_color = Color(0.5, 0.7, 1.0)
		dc_style.border_width_left = 2; dc_style.border_width_right = 2
		dc_style.border_width_top = 2; dc_style.border_width_bottom = 2
		dc_style.corner_radius_top_left = 4; dc_style.corner_radius_top_right = 4
		dc_style.corner_radius_bottom_left = 4; dc_style.corner_radius_bottom_right = 4
		daily_btn.add_theme_stylebox_override("normal", dc_style)

	daily_btn.pressed.connect(func():
		if _daily_challenge:
			visible = false
			emit_signal("daily_challenge_requested")
	)
	add_child(daily_btn)

	# 每日挑战描述
	if not is_done and not dc_config.is_empty():
		var dc_desc = Label.new()
		dc_desc.text = "%s  |  %s" % [dc_config.get("modifier_name", ""), dc_config.get("modifier_desc", "")]
		dc_desc.add_theme_font_size_override("font_size", 13)
		dc_desc.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
		dc_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dc_desc.anchor_left   = 0.5
		dc_desc.anchor_right  = 0.5
		dc_desc.anchor_top    = 1.0
		dc_desc.anchor_bottom = 1.0
		dc_desc.offset_left   = -300
		dc_desc.offset_right  = 300
		dc_desc.offset_top    = -100
		dc_desc.offset_bottom = -80
		add_child(dc_desc)

func _make_card(char_data: Resource, unlocked: bool) -> Button:
	# 整张卡片改为 Button，这样全区域都可以点击
	var card = Button.new()
	card.custom_minimum_size = Vector2(220, 300)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_NONE

	# 卡片样式
	var is_selected = unlocked and char_data.id == _selected_id
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.10, 0.10, 0.22)
	style_normal.corner_radius_top_left    = 8
	style_normal.corner_radius_top_right   = 8
	style_normal.corner_radius_bottom_left = 8
	style_normal.corner_radius_bottom_right = 8
	if is_selected:
		style_normal.border_color = Color(1.0, 0.88, 0.2)
		style_normal.border_width_left   = 3
		style_normal.border_width_right  = 3
		style_normal.border_width_top    = 3
		style_normal.border_width_bottom = 3
		style_normal.bg_color = Color(0.14, 0.13, 0.28)

	# hover 样式：边框变亮
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.16, 0.15, 0.32)
	if not is_selected:
		style_hover.border_color = Color(0.7, 0.7, 0.9, 0.6)
		style_hover.border_width_left   = 2
		style_hover.border_width_right  = 2
		style_hover.border_width_top    = 2
		style_hover.border_width_bottom = 2

	card.add_theme_stylebox_override("normal",   style_normal)
	card.add_theme_stylebox_override("hover",    style_hover)
	card.add_theme_stylebox_override("pressed",  style_hover)
	card.add_theme_stylebox_override("focus",    style_normal)
	card.add_theme_stylebox_override("disabled", style_normal)

	if not unlocked:
		card.disabled = true
	else:
		card.pressed.connect(func():
			_selected_id = char_data.id
			_build_ui()
		)

	# 内容布局：SIZE_EXPAND_FILL 撑满 Button 宽度
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	# 头像区域：用 Control 自绘背景色，emoji Label 锚点居中
	var avatar_ctrl = Control.new()
	avatar_ctrl.custom_minimum_size = Vector2(0, 130)
	avatar_ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	avatar_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var avatar_color = char_data.icon_color if unlocked else Color(0.2, 0.2, 0.2)
	# 用 draw 回调绘制纯色背景（不受 padding 影响）
	avatar_ctrl.draw.connect(func():
		avatar_ctrl.draw_rect(Rect2(Vector2.ZERO, avatar_ctrl.size), avatar_color)
	)
	avatar_ctrl.resized.connect(func(): avatar_ctrl.queue_redraw())
	vbox.add_child(avatar_ctrl)

	var avatar_lbl = Label.new()
	avatar_lbl.text = char_data.icon_emoji if unlocked else "🔒"
	avatar_lbl.add_theme_font_size_override("font_size", 72)
	avatar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	avatar_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	avatar_ctrl.add_child(avatar_lbl)

	# 名称
	var name_lbl = Label.new()
	name_lbl.text = char_data.display_name if unlocked else "???"
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	# 特性
	var trait_lbl = Label.new()
	trait_lbl.text = char_data.trait_desc if unlocked else "需要解锁"
	trait_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6) if unlocked else Color(0.5, 0.5, 0.5))
	trait_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trait_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	trait_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(trait_lbl)

	# 描述
	var desc_lbl = Label.new()
	desc_lbl.text = char_data.description if unlocked else ""
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_lbl)

	# （无底部状态文字）

	return card
