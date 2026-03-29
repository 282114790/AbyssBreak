# CharacterSelectScreen.gd
# 角色选择界面 - 游戏开始前展示
extends CanvasLayer

signal character_selected(character_id: String)

var _registry: Node = null
var _meta: Node = null
var _selected_id: String = "mage"

func _ready() -> void:
	layer = 20
	visible = false

func show_screen(registry: Node, meta: Node) -> void:
	_registry = registry
	_meta = meta
	_selected_id = registry.selected_id
	visible = true
	_build_ui()

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
		emit_signal("character_selected", _selected_id)
	)
	add_child(start_btn)

func _make_card(char_data: Resource, unlocked: bool) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 300)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	# 头像区域（临时：大emoji + 背景色块）
	var avatar_bg = ColorRect.new()
	avatar_bg.color = char_data.icon_color if unlocked else Color(0.2, 0.2, 0.2)
	avatar_bg.custom_minimum_size = Vector2(200, 120)
	vbox.add_child(avatar_bg)

	var avatar_lbl = Label.new()
	avatar_lbl.text = char_data.icon_emoji if unlocked else "🔒"
	avatar_lbl.add_theme_font_size_override("font_size", 56)
	avatar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 叠加在色块上
	avatar_bg.add_child(avatar_lbl)
	avatar_lbl.set_anchors_preset(Control.PRESET_CENTER)

	# 名称
	var name_lbl = Label.new()
	name_lbl.text = char_data.display_name if unlocked else "???"
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	# 特性
	var trait_lbl = Label.new()
	trait_lbl.text = char_data.trait_desc if unlocked else "需要解锁"
	trait_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6) if unlocked else Color(0.5, 0.5, 0.5))
	trait_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trait_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(trait_lbl)

	# 描述
	var desc_lbl = Label.new()
	desc_lbl.text = char_data.description if unlocked else ""
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_lbl)

	# 选择按钮
	if unlocked:
		var btn = Button.new()
		btn.text = "✅ 已选择" if char_data.id == _selected_id else "选择"
		btn.pressed.connect(func():
			_selected_id = char_data.id
			_build_ui()   # 刷新高亮
		)
		vbox.add_child(btn)

		# 高亮选中边框
		if char_data.id == _selected_id:
			var style = StyleBoxFlat.new()
			style.border_color = Color(1.0, 0.9, 0.2)
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_width_top = 3
			style.border_width_bottom = 3
			style.bg_color = Color(0.12, 0.12, 0.25)
			card.add_theme_stylebox_override("panel", style)

	return card
