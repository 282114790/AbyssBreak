# RelicSelectPanel.gd
# 遗物3选1面板（CanvasLayer）
extends CanvasLayer

var _panel: PanelContainer
var _choices: Array = []
var _player: Node = null

signal relic_chosen(relic: RelicData)

func setup(choices: Array, player: Node) -> void:
	_choices = choices
	_player  = player
	_build_ui()

func _build_ui() -> void:
	# 半透明遮罩
	var overlay = ColorRect.new()
	overlay.anchor_right = 1.0; overlay.anchor_bottom = 1.0
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	add_child(overlay)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(680, 300)
	_panel.anchor_left   = 0.5; _panel.anchor_right  = 0.5
	_panel.anchor_top    = 0.5; _panel.anchor_bottom = 0.5
	_panel.offset_left   = -340; _panel.offset_right  = 340
	_panel.offset_top    = -150; _panel.offset_bottom = 150
	add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(vbox)

	# 标题
	var title = Label.new()
	title.text = "✨ 获得遗物"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	vbox.add_child(title)

	var spacer = Control.new(); spacer.custom_minimum_size = Vector2(0, 12); vbox.add_child(spacer)

	# 3个选项横排
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	var rarity_colors = {1: Color(0.8, 0.8, 0.8), 2: Color(0.7, 0.4, 1.0), 3: Color(1.0, 0.7, 0.1)}

	for i in range(_choices.size()):
		var relic = _choices[i]
		var card = _make_card(relic, rarity_colors.get(relic.rarity, Color.WHITE), i)
		hbox.add_child(card)

func _make_card(relic: RelicData, color: Color, idx: int) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(190, 200)

	var ss = StyleBoxFlat.new()
	ss.bg_color = Color(color.r * 0.15, color.g * 0.15, color.b * 0.15, 0.92)
	ss.border_color = color
	ss.border_width_left = 2; ss.border_width_right  = 2
	ss.border_width_top  = 2; ss.border_width_bottom = 2
	ss.corner_radius_top_left = 8; ss.corner_radius_top_right = 8
	ss.corner_radius_bottom_left = 8; ss.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", ss)

	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vb)

	# 图标
	var icon_lbl = Label.new()
	icon_lbl.text = relic.icon_emoji
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 42)
	vb.add_child(icon_lbl)

	# 名称
	var name_lbl = Label.new()
	name_lbl.text = relic.display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", color)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(name_lbl)

	# 描述
	var desc_lbl = Label.new()
	desc_lbl.text = relic.description
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.custom_minimum_size = Vector2(170, 0)
	vb.add_child(desc_lbl)

	var sp = Control.new(); sp.custom_minimum_size = Vector2(0, 8); vb.add_child(sp)

	# 选择按钮
	var btn = Button.new()
	btn.text = "选择"
	btn.custom_minimum_size = Vector2(140, 36)
	btn.add_theme_color_override("font_color", Color.WHITE)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(color.r * 0.4, color.g * 0.4, color.b * 0.4, 1.0)
	btn_style.corner_radius_top_left = 4; btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4; btn_style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.pressed.connect(func(): _on_chosen(relic))
	vb.add_child(btn)

	# 悬停高亮
	card.mouse_entered.connect(func():
		ss.border_width_left = 3; ss.border_width_right  = 3
		ss.border_width_top  = 3; ss.border_width_bottom = 3
	)
	card.mouse_exited.connect(func():
		ss.border_width_left = 2; ss.border_width_right  = 2
		ss.border_width_top  = 2; ss.border_width_bottom = 2
	)

	return card

func _on_chosen(relic: RelicData) -> void:
	if is_instance_valid(_player):
		relic.apply_to_player(_player)
		if not _player.get("relic_ids"):
			_player.set("relic_ids", [])
		_player.relic_ids.append(relic.id)
	relic_chosen.emit(relic)
	# 恢复游戏
	EventBus.game_logic_paused = false
	get_tree().paused = false
	queue_free()
