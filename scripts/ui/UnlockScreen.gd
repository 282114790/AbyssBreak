# UnlockScreen.gd
# 局外解锁界面 - 魂石消费 + 永久强化树
extends CanvasLayer

var _meta: Node = null
var _btn_map: Dictionary = {}   # node_id -> Button

func _ready() -> void:
	layer = 11
	visible = false

func show_screen() -> void:
	_meta = get_tree().root.find_child("MetaProgress", true, false)
	visible = true
	_build_ui()

func _build_ui() -> void:
	for c in get_children(): c.queue_free()

	var overlay = ColorRect.new()
	overlay.color = Color(0.04, 0.04, 0.12, 0.95)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# 顶部标题 + 魂石显示
	var top_bar = HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size = Vector2(0, 56)
	top_bar.add_theme_constant_override("separation", 20)
	add_child(top_bar)

	var title = Label.new()
	title.text = "⚗ 深渊强化"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title)

	var soul_lbl = Label.new()
	soul_lbl.name = "SoulLabel"
	soul_lbl.text = "💎 %d" % _meta.soul_stones
	soul_lbl.add_theme_font_size_override("font_size", 20)
	soul_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	top_bar.add_child(soul_lbl)

	var close_btn = Button.new()
	close_btn.text = "✕ 关闭"
	close_btn.pressed.connect(func(): visible = false)
	top_bar.add_child(close_btn)

	# 三列解锁树
	var cols_container = HBoxContainer.new()
	cols_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	cols_container.offset_top = 64
	cols_container.add_theme_constant_override("separation", 12)
	add_child(cols_container)

	var col_names = ["⚔ 攻击", "🛡 防御", "✨ 特殊"]
	for col_idx in range(3):
		var col_box = VBoxContainer.new()
		col_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col_box.add_theme_constant_override("separation", 10)
		cols_container.add_child(col_box)

		var col_title = Label.new()
		col_title.text = col_names[col_idx]
		col_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col_title.add_theme_font_size_override("font_size", 18)
		col_box.add_child(col_title)

		col_box.add_child(_make_hsep())

		# 该列的节点
		var nodes_in_col = _meta.UNLOCK_NODES.filter(func(n): return n["col"] == col_idx)
		nodes_in_col.sort_custom(func(a, b): return a["row"] < b["row"])

		for node_def in nodes_in_col:
			col_box.add_child(_make_node_card(node_def))

	# 底部返回
	var back_btn = Button.new()
	back_btn.text = "← 返回"
	back_btn.anchor_left   = 0.0
	back_btn.anchor_right  = 0.0
	back_btn.anchor_top    = 1.0
	back_btn.anchor_bottom = 1.0
	back_btn.offset_left   = 20
	back_btn.offset_right  = 180
	back_btn.offset_top    = -60
	back_btn.offset_bottom = -16
	back_btn.pressed.connect(func(): visible = false)
	add_child(back_btn)

func _make_node_card(node_def: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	var cur_lv = _meta.unlocked.get(node_def["id"], 0)
	var maxed  = cur_lv >= node_def["max_level"]
	var locked_req = false
	for req in node_def["requires"]:
		if _meta.unlocked.get(req, 0) == 0:
			locked_req = true; break

	var vbox = VBoxContainer.new()
	card.add_child(vbox)

	# 名称行
	var name_row = HBoxContainer.new()
	var name_lbl = Label.new()
	name_lbl.text = node_def["name"]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lv_lbl = Label.new()
	lv_lbl.text = "Lv %d/%d" % [cur_lv, node_def["max_level"]]
	lv_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6) if maxed else Color(0.8, 0.8, 0.8))
	name_row.add_child(name_lbl)
	name_row.add_child(lv_lbl)
	vbox.add_child(name_row)

	# 描述
	var desc_lbl = Label.new()
	desc_lbl.text = node_def["desc"]
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_lbl)

	# 解锁按钮
	var btn = Button.new()
	if maxed:
		btn.text = "✅ 已满级"
		btn.disabled = true
	elif locked_req:
		btn.text = "🔒 需要前置"
		btn.disabled = true
	elif _meta.soul_stones < node_def["cost"]:
		btn.text = "💎 %d（魂石不足）" % node_def["cost"]
		btn.disabled = true
	else:
		btn.text = "💎 %d 解锁" % node_def["cost"]
		btn.disabled = false

	btn.pressed.connect(func():
		if _meta.unlock(node_def["id"]):
			_refresh_ui()
	)
	_btn_map[node_def["id"]] = btn
	vbox.add_child(btn)
	return card

func _refresh_ui() -> void:
	_build_ui()

func _make_hsep() -> HSeparator:
	return HSeparator.new()
