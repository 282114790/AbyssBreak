# RouteSelectScreen.gd
# 路线选择 — 运用默会知识原则：
# 1. 视觉先于文字：颜色、图标、大小传达含义
# 2. 收益/代价分离：绿色=收益，橙色=代价，无需标注
# 3. 整张卡片可点击：取消多余按钮，hover 反馈暗示可交互
# 4. 焦点层次：图标→名称→收益→代价，从上到下递减
extends CanvasLayer

signal route_selected(route: Dictionary)

const ROUTES := [
	{
		"icon": "💎",
		"name": "遗物之路",
		"theme_color": Color(0.95, 0.75, 0.15),
		"benefits": ["遗物掉落频率 ×2"],
		"costs": ["敌人数量 +20%"],
		"relic_bonus": 2.0,
		"enemy_mult": 1.2,
		"merchant_bonus": 1.0,
		"soul_mult": 1.0,
	},
	{
		"icon": "⚔",
		"name": "鲜血之路",
		"theme_color": Color(1.0, 0.3, 0.3),
		"benefits": ["击杀经验 ×1.5", "魂石奖励 ×1.3"],
		"costs": ["敌人血量 +30%"],
		"relic_bonus": 1.0,
		"enemy_mult": 1.0,
		"enemy_hp_mult": 1.3,
		"exp_bonus": 1.5,
		"soul_mult": 1.3,
	},
	{
		"icon": "🧙",
		"name": "商旅之路",
		"theme_color": Color(0.35, 0.8, 1.0),
		"benefits": ["商人每 3 波出现", "起始金币 ×1.5"],
		"costs": ["无额外增益"],
		"relic_bonus": 1.0,
		"enemy_mult": 1.0,
		"merchant_interval": 3,
		"soul_start_mult": 1.5,
		"soul_mult": 1.0,
	},
]

func _ready() -> void:
	layer = 8
	visible = false

func show_screen() -> void:
	visible = true
	_build_ui()

func _build_ui() -> void:
	for c in get_children(): c.queue_free()

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.9)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var root = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.custom_minimum_size = Vector2(750, 360)
	root.position = Vector2(-375, -180)
	root.add_theme_constant_override("separation", 20)
	add_child(root)

	# 标题：极简，让卡片成为视觉焦点
	var title = Label.new()
	title.text = "选择路线"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(hbox)

	for route in ROUTES:
		_build_card(hbox, route)

func _build_card(parent: HBoxContainer, route: Dictionary) -> void:
	var tc: Color = route["theme_color"]

	# 卡片容器
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 280)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.06, 0.06, 0.12, 0.95)
	card_style.border_width_left = 2; card_style.border_width_right = 2
	card_style.border_width_top = 2; card_style.border_width_bottom = 2
	card_style.border_color = Color(tc.r * 0.5, tc.g * 0.5, tc.b * 0.5, 0.6)
	card_style.corner_radius_top_left = 10; card_style.corner_radius_top_right = 10
	card_style.corner_radius_bottom_left = 10; card_style.corner_radius_bottom_right = 10
	card_style.content_margin_left = 16; card_style.content_margin_right = 16
	card_style.content_margin_top = 0; card_style.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", card_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	# ── 顶部色条：路线的「气质」，一眼感知 ──
	var accent_bar = ColorRect.new()
	accent_bar.custom_minimum_size = Vector2(0, 4)
	accent_bar.color = tc
	accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(accent_bar)

	# ── 图标：视觉焦点中心 ──
	var icon_lbl = Label.new()
	icon_lbl.text = route["icon"]
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 42)
	icon_lbl.custom_minimum_size = Vector2(0, 64)
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_lbl)

	# ── 名称：次焦点 ──
	var name_lbl = Label.new()
	name_lbl.text = route["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", tc)
	name_lbl.custom_minimum_size = Vector2(0, 28)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	# ── 分割线 ──
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(tc.r, tc.g, tc.b, 0.25)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	# ── 间距 ──
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer1)

	# ── 收益区：绿色，无需标注"优势" ──
	for b in route["benefits"]:
		var lbl = Label.new()
		lbl.text = "▲ " + b
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.45))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(lbl)

	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer2)

	# ── 代价区：橙红色，玩家本能感知风险 ──
	for c in route["costs"]:
		var lbl = Label.new()
		lbl.text = "▼ " + c
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.3))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(lbl)

	# ── Hover / Click ──
	var hover_style = card_style.duplicate()
	hover_style.bg_color = Color(tc.r * 0.12 + 0.04, tc.g * 0.12 + 0.04, tc.b * 0.12 + 0.04, 0.98)
	hover_style.border_color = Color(tc.r, tc.g, tc.b, 0.9)
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
			_select_route(route)
	)

	parent.add_child(card)

func _select_route(route: Dictionary) -> void:
	visible = false
	emit_signal("route_selected", route)
