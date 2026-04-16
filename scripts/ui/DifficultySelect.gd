# DifficultySelect.gd
# 难度选择 — 默会知识原则：
# 1. 颜色梯度传达危险程度：绿→橙→红，无需文字说明
# 2. 收益/代价用颜色分离，▲绿=好处 ▼橙=风险
# 3. 点击卡片直接进入，去掉冗余的"已选择"状态和确认按钮
# 4. 图标→名称→收益→代价→魂石奖励，自上而下焦点递减
extends CanvasLayer
class_name DifficultySelect

const DD = preload("res://scripts/systems/DifficultyData.gd")

signal difficulty_selected(diff_data)

var _difficulties: Array = []

func _ready() -> void:
	layer = 21
	visible = false
	_build_difficulties()

func _build_difficulties() -> void:
	_difficulties = [
		_make_diff("normal", "普通", 1.0, 1.0, 1.0, 1.0, 1.0, 1.0),
		_make_diff("hard",   "困难", 1.5, 1.3, 1.1, 1.3, 1.2, 1.5),
		_make_diff("abyss",  "深渊", 2.5, 2.0, 1.2, 1.8, 1.5, 2.0),
	]

func _make_diff(id_: String, name_: String, hp: float, dmg: float, spd: float, cnt: float, exp_m: float, soul: float) -> Resource:
	var d = DD.new()
	d.id = id_; d.display_name = name_; d.description = ""
	d.enemy_hp_mult = hp; d.enemy_dmg_mult = dmg; d.enemy_speed_mult = spd
	d.enemy_count_mult = cnt; d.exp_mult = exp_m; d.soul_stone_mult = soul
	return d

func show_screen() -> void:
	visible = true
	_build_ui()

func _build_ui() -> void:
	for c in get_children(): c.queue_free()
	await get_tree().process_frame

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.03, 0.08, 0.95)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.custom_minimum_size = Vector2(760, 380)
	root.position = Vector2(-380, -190)
	root.add_theme_constant_override("separation", 22)
	add_child(root)

	var title = Label.new()
	title.text = "选择难度"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(hbox)

	var configs = [
		{
			"idx": 0,
			"icon": "🟢",
			"tc": Color(0.35, 0.9, 0.35),
			"bg": Color(0.05, 0.13, 0.05, 0.95),
			"benefits": ["平衡的初始体验"],
			"costs": [],
		},
		{
			"idx": 1,
			"icon": "🔥",
			"tc": Color(1.0, 0.62, 0.1),
			"bg": Color(0.14, 0.08, 0.02, 0.95),
			"benefits": ["经验 ×1.2", "魂石 ×1.5"],
			"costs": ["敌人血量 ×1.5", "伤害 ×1.3", "数量 ×1.3"],
		},
		{
			"idx": 2,
			"icon": "💀",
			"tc": Color(0.9, 0.2, 0.2),
			"bg": Color(0.15, 0.03, 0.03, 0.95),
			"benefits": ["经验 ×1.5", "魂石 ×2.0"],
			"costs": ["敌人血量 ×2.5", "伤害 ×2.0", "速度 ×1.2", "数量 ×1.8"],
		},
	]

	for cfg in configs:
		_build_card(hbox, _difficulties[cfg["idx"]], cfg)

func _build_card(parent: HBoxContainer, diff: Resource, cfg: Dictionary) -> void:
	var tc: Color = cfg["tc"]
	var bg_col: Color = cfg["bg"]

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(230, 310)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = bg_col
	card_style.border_width_left = 2; card_style.border_width_right = 2
	card_style.border_width_top = 2; card_style.border_width_bottom = 2
	card_style.border_color = Color(tc.r * 0.45, tc.g * 0.45, tc.b * 0.45, 0.5)
	card_style.corner_radius_top_left = 10; card_style.corner_radius_top_right = 10
	card_style.corner_radius_bottom_left = 10; card_style.corner_radius_bottom_right = 10
	card_style.content_margin_left = 16; card_style.content_margin_right = 16
	card_style.content_margin_top = 0; card_style.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", card_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	# ── 顶部色条 ──
	var accent = ColorRect.new()
	accent.custom_minimum_size = Vector2(0, 4)
	accent.color = tc
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(accent)

	# ── 图标 ──
	var icon_lbl = Label.new()
	icon_lbl.text = cfg["icon"]
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 38)
	icon_lbl.custom_minimum_size = Vector2(0, 58)
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_lbl)

	# ── 名称 ──
	var name_lbl = Label.new()
	name_lbl.text = diff.display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", tc)
	name_lbl.custom_minimum_size = Vector2(0, 32)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	# ── 分割线 ──
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(tc.r, tc.g, tc.b, 0.2)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer1)

	# ── 收益 ──
	for b in cfg["benefits"]:
		var lbl = Label.new()
		lbl.text = "▲ " + b
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.45))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(lbl)

	if not cfg["costs"].is_empty():
		var spacer2 = Control.new()
		spacer2.custom_minimum_size = Vector2(0, 4)
		vbox.add_child(spacer2)

	# ── 代价 ──
	for c in cfg["costs"]:
		var lbl = Label.new()
		lbl.text = "▼ " + c
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(lbl)

	# ── 弹性间距 ──
	var flex = Control.new()
	flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	flex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(flex)

	# ── 魂石奖励（底部锚定）──
	var soul_sep = ColorRect.new()
	soul_sep.custom_minimum_size = Vector2(0, 1)
	soul_sep.color = Color(0.5, 0.85, 1.0, 0.15)
	soul_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(soul_sep)

	var soul_lbl = Label.new()
	soul_lbl.text = "💎 魂石奖励 ×%.1f" % diff.soul_stone_mult
	soul_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	soul_lbl.add_theme_font_size_override("font_size", 13)
	soul_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	soul_lbl.custom_minimum_size = Vector2(0, 24)
	soul_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(soul_lbl)

	# ── Hover / Click ──
	var hover_style = card_style.duplicate()
	hover_style.bg_color = Color(bg_col.r + 0.04, bg_col.g + 0.04, bg_col.b + 0.04, 0.98)
	hover_style.border_color = Color(tc.r, tc.g, tc.b, 0.85)
	hover_style.border_width_left = 3; hover_style.border_width_right = 3
	hover_style.border_width_top = 3; hover_style.border_width_bottom = 3

	card.mouse_entered.connect(func():
		card.add_theme_stylebox_override("panel", hover_style)
		var tw = card.create_tween()
		tw.tween_property(card, "scale", Vector2(1.03, 1.03), 0.1).set_ease(Tween.EASE_OUT)
	)
	card.mouse_exited.connect(func():
		card.add_theme_stylebox_override("panel", card_style)
		var tw = card.create_tween()
		tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)
	)
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			visible = false
			emit_signal("difficulty_selected", diff)
	)

	parent.add_child(card)
