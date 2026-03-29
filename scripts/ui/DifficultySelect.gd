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
	# 清除旧子节点（保留CanvasLayer自身）
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame

	# 背景
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.04, 0.1, 0.95)
	add_child(bg)

	# 标题
	var title = Label.new()
	title.text = "选择难度"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 60; title.offset_left = -120; title.offset_right = 120
	add_child(title)

	# 副标题
	var sub = Label.new()
	sub.text = "困难模式将获得更多魂石奖励"
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.offset_top = 108; sub.offset_left = -200; sub.offset_right = 200
	add_child(sub)

	# 难度卡片容器
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_CENTER)
	hbox.offset_left = -420; hbox.offset_right = 420
	hbox.offset_top = -120; hbox.offset_bottom = 180
	hbox.add_theme_constant_override("separation", 20)
	add_child(hbox)

	var colors = [
		Color(0.1, 0.5, 0.1, 0.8),   # 普通 绿
		Color(0.5, 0.3, 0.0, 0.8),   # 困难 橙
		Color(0.4, 0.0, 0.0, 0.8),   # 深渊 红
	]
	var border_colors = [
		Color(0.3, 0.9, 0.3), Color(1.0, 0.6, 0.1), Color(0.9, 0.1, 0.1)
	]

	for i in range(_difficulties.size()):
		var diff = _difficulties[i]
		var card = _make_card(diff, colors[i], border_colors[i])
		hbox.add_child(card)

	# 默认选中普通
	_selected = _difficulties[0]

func _make_card(diff, bg_color: Color, border_color: Color) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(240, 280)
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2; style.border_width_bottom = 2
	style.corner_radius_top_left = 8; style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8; style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = diff.display_name
	name_lbl.add_theme_font_size_override("font_size", 28)
	name_lbl.add_theme_color_override("font_color", border_color)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var desc_lbl = Label.new()
	desc_lbl.text = diff.description
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# 魂石倍率提示
	var soul_lbl = Label.new()
	soul_lbl.text = "魂石奖励 ×%.1f" % diff.soul_stone_mult
	soul_lbl.add_theme_font_size_override("font_size", 14)
	soul_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	soul_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(soul_lbl)

	var btn = Button.new()
	btn.text = "选择此难度"
	btn.add_theme_font_size_override("font_size", 16)
	vbox.add_child(btn)

	btn.pressed.connect(func():
		_selected = diff
		visible = false
		emit_signal("difficulty_selected", diff)
	)
	return card
