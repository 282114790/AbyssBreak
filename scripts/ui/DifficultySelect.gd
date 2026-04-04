# DifficultySelect.gd
extends CanvasLayer
class_name DifficultySelect

const DD = preload("res://scripts/systems/DifficultyData.gd")

signal difficulty_selected(diff_data)

var _selected = null  # DifficultyData
var _difficulties: Array = []

func _ready() -> void:
	layer = 21
	visible = false
	_build_difficulties()

func _build_difficulties() -> void:
	_difficulties = [
		_make_diff("normal", "普通", "适合初次体验\n敌人数量×1.0，伤害×1.0", 1.0, 1.0, 1.0, 1.0, 1.0, 1.0),
		_make_diff("hard",   "困难", "挑战老手\n敌人血量×1.5，伤害×1.3，数量×1.3，经验×1.2，魂石×1.5", 1.5, 1.3, 1.1, 1.3, 1.2, 1.5),
		_make_diff("abyss",  "深渊", "极限挑战，魂石双倍\n敌人血量×2.5，伤害×2.0，速度×1.2，数量×1.8", 2.5, 2.0, 1.2, 1.8, 1.5, 2.0),
	]

func _make_diff(id_: String, name_: String, desc_: String, hp: float, dmg: float, spd: float, cnt: float, exp_m: float, soul: float) -> Resource:
	var d = DD.new()
	d.id = id_; d.display_name = name_; d.description = desc_
	d.enemy_hp_mult = hp; d.enemy_dmg_mult = dmg; d.enemy_speed_mult = spd
	d.enemy_count_mult = cnt; d.exp_mult = exp_m; d.soul_stone_mult = soul
	return d

func show_screen() -> void:
	visible = true
	_build_ui()

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame

	# 背景
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.04, 0.10, 0.96)
	add_child(bg)

	# 标题
	var title = Label.new()
	title.text = "选择难度"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 50; title.offset_bottom = 100
	add_child(title)

	# 副标题
	var sub = Label.new()
	sub.text = "难度越高，魂石奖励越丰厚"
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.62, 0.62, 0.72))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 100; sub.offset_bottom = 132
	add_child(sub)

	# 卡片容器
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_CENTER)
	hbox.offset_left = -440; hbox.offset_right  =  440
	hbox.offset_top  = -140; hbox.offset_bottom =  155
	hbox.add_theme_constant_override("separation", 20)
	add_child(hbox)

	var bg_colors = [
		Color(0.06, 0.16, 0.06, 0.92),
		Color(0.16, 0.09, 0.02, 0.92),
		Color(0.17, 0.04, 0.04, 0.92),
	]
	var border_colors = [
		Color(0.35, 0.90, 0.35),
		Color(1.00, 0.62, 0.10),
		Color(0.90, 0.18, 0.18),
	]

	if _selected == null:
		_selected = _difficulties[0]

	for i in range(_difficulties.size()):
		hbox.add_child(_make_card(_difficulties[i], bg_colors[i], border_colors[i]))

	# 分割线
	var divider = ColorRect.new()
	divider.color = Color(1, 1, 1, 0.07)
	divider.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	divider.offset_top = -105; divider.offset_bottom = -104
	add_child(divider)

	# 进入按钮
	var enter_btn = Button.new()
	enter_btn.text = "▶  进入深渊"
	enter_btn.add_theme_font_size_override("font_size", 22)
	enter_btn.custom_minimum_size = Vector2(260, 56)
	enter_btn.anchor_left   = 0.5;  enter_btn.anchor_right  = 0.5
	enter_btn.anchor_top    = 1.0;  enter_btn.anchor_bottom = 1.0
	enter_btn.offset_left   = -130; enter_btn.offset_right  = 130
	enter_btn.offset_top    = -92;  enter_btn.offset_bottom = -36

	var es = StyleBoxFlat.new()
	es.bg_color = Color(0.14, 0.09, 0.28)
	es.border_color = Color(0.65, 0.48, 1.0)
	es.border_width_left = 2; es.border_width_right  = 2
	es.border_width_top  = 2; es.border_width_bottom = 2
	es.corner_radius_top_left = 6; es.corner_radius_top_right   = 6
	es.corner_radius_bottom_left = 6; es.corner_radius_bottom_right = 6
	var eh = es.duplicate()
	eh.bg_color = Color(0.20, 0.13, 0.40)
	eh.border_color = Color(0.85, 0.70, 1.0)
	enter_btn.add_theme_stylebox_override("normal",  es)
	enter_btn.add_theme_stylebox_override("hover",   eh)
	enter_btn.add_theme_stylebox_override("pressed", eh)
	enter_btn.pressed.connect(func():
		if _selected:
			visible = false
			emit_signal("difficulty_selected", _selected)
	)
	add_child(enter_btn)

func _make_card(diff, bg_color: Color, border_color: Color) -> Button:
	var is_selected = (_selected != null and _selected.id == diff.id)

	var card = Button.new()
	card.custom_minimum_size = Vector2(240, 280)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_NONE

	# 普通样式
	var sn = StyleBoxFlat.new()
	sn.bg_color = bg_color
	sn.corner_radius_top_left    = 10; sn.corner_radius_top_right    = 10
	sn.corner_radius_bottom_left = 10; sn.corner_radius_bottom_right = 10
	if is_selected:
		sn.border_color = Color(1.0, 0.88, 0.2)
		sn.border_width_left = 3; sn.border_width_right  = 3
		sn.border_width_top  = 3; sn.border_width_bottom = 3
	else:
		sn.border_color = Color(border_color.r, border_color.g, border_color.b, 0.45)
		sn.border_width_left = 1; sn.border_width_right  = 1
		sn.border_width_top  = 1; sn.border_width_bottom = 1

	# hover 样式
	var sh = sn.duplicate()
	sh.bg_color = bg_color.lightened(0.10)
	sh.border_color = Color(1.0, 0.88, 0.2, 0.70)
	sh.border_width_left = 2; sh.border_width_right  = 2
	sh.border_width_top  = 2; sh.border_width_bottom = 2

	card.add_theme_stylebox_override("normal",  sn)
	card.add_theme_stylebox_override("hover",   sh)
	card.add_theme_stylebox_override("pressed", sh)
	card.add_theme_stylebox_override("focus",   sn)

	# 点卡片只切换选中，不直接进入
	card.pressed.connect(func():
		_selected = diff
		_build_ui()
	)

	# VBox 撑满卡片
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	# 难度名（大标题）
	var name_lbl = Label.new()
	name_lbl.text = diff.display_name
	name_lbl.add_theme_font_size_override("font_size", 30)
	name_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.88, 0.2) if is_selected else border_color)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	# 分割线
	var sep = HSeparator.new()
	sep.add_theme_color_override("color",
		Color(border_color.r, border_color.g, border_color.b, 0.35))
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	# 描述：短标语（大） + 详细数值（小）
	var lines = diff.description.split("\n")
	if lines.size() >= 1:
		var tagline = Label.new()
		tagline.text = lines[0]
		tagline.add_theme_font_size_override("font_size", 15)
		tagline.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
		tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(tagline)
	if lines.size() >= 2:
		var detail = Label.new()
		detail.text = lines[1]
		detail.add_theme_font_size_override("font_size", 11)
		detail.add_theme_color_override("font_color", Color(0.68, 0.68, 0.68))
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(detail)

	# 弹性间距
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)

	# 魂石奖励
	var soul_lbl = Label.new()
	soul_lbl.text = "💎  魂石奖励  ×%.1f" % diff.soul_stone_mult
	soul_lbl.add_theme_font_size_override("font_size", 14)
	soul_lbl.add_theme_color_override("font_color", Color(0.50, 0.85, 1.0))
	soul_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	soul_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(soul_lbl)

	# 已选中标识
	var state_lbl = Label.new()
	state_lbl.text = "✦  已选择" if is_selected else " "
	state_lbl.add_theme_font_size_override("font_size", 13)
	state_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	state_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(state_lbl)

	return card
