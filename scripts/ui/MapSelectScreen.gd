# MapSelectScreen.gd
# 地图选择界面 — 角色选择后、难度选择前
extends CanvasLayer

signal map_selected(map_id: String)

var _registry: Node = null
var _selected_id: String = "dark_stone"

func _ready() -> void:
	layer = 20
	visible = false

func show_screen(registry: Node) -> void:
	_registry = registry
	_selected_id = registry.selected_id
	visible = true
	_build_ui()

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.14, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title = Label.new()
	title.text = "选择地图"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 40
	title.offset_bottom = 90
	add_child(title)

	var subtitle = Label.new()
	subtitle.text = "后续将持续扩展更多地图"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle.offset_top = 90
	subtitle.offset_bottom = 115
	add_child(subtitle)

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 30
	scroll.offset_right = -30
	scroll.offset_top = 120
	scroll.offset_bottom = -100
	add_child(scroll)

	var cards_container = HBoxContainer.new()
	cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_container.add_theme_constant_override("separation", 20)
	cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(cards_container)

	for map_data in _registry.all_maps:
		cards_container.add_child(_make_card(map_data))

func _make_card(map_data) -> Button:
	var card = Button.new()
	card.custom_minimum_size = Vector2(220, 280)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_NONE

	var is_selected = map_data.id == _selected_id
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

	card.pressed.connect(func():
		_selected_id = map_data.id
		_registry.selected_id = _selected_id
		visible = false
		emit_signal("map_selected", _selected_id)
	)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	var preview_ctrl = Control.new()
	preview_ctrl.custom_minimum_size = Vector2(0, 140)
	preview_ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var preview_color : Color = map_data.preview_color
	preview_ctrl.draw.connect(func():
		preview_ctrl.draw_rect(Rect2(Vector2.ZERO, preview_ctrl.size), preview_color)
	)
	preview_ctrl.resized.connect(func(): preview_ctrl.queue_redraw())
	vbox.add_child(preview_ctrl)

	var emoji_lbl = Label.new()
	emoji_lbl.text = map_data.icon_emoji
	emoji_lbl.add_theme_font_size_override("font_size", 56)
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	emoji_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_ctrl.add_child(emoji_lbl)

	var name_lbl = Label.new()
	name_lbl.text = map_data.display_name
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = map_data.description
	desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_lbl)

	if is_selected:
		var sel_lbl = Label.new()
		sel_lbl.text = "[ 已选择 ]"
		sel_lbl.add_theme_font_size_override("font_size", 14)
		sel_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
		sel_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sel_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(sel_lbl)

	return card
