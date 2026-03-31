# RouteSelectScreen.gd
# 关卡选择地图（#24）— 游戏开始时三选一路线
# 路线类型：遗物路 / 战斗路 / 商人路
extends CanvasLayer

signal route_selected(route: Dictionary)

const ROUTES := [
	{
		"name": "💎 遗物之路",
		"desc": "遗物掉落频率 ×2\n敌人数量 +20%",
		"color": Color(1.0, 0.85, 0.2),
		"relic_bonus": 2.0,
		"enemy_mult": 1.2,
		"merchant_bonus": 1.0,
		"soul_mult": 1.0,
	},
	{
		"name": "⚔ 鲜血之路",
		"desc": "击杀奖励经验 ×1.5\n敌人更强（+30%血量）",
		"color": Color(1.0, 0.25, 0.25),
		"relic_bonus": 1.0,
		"enemy_mult": 1.0,
		"enemy_hp_mult": 1.3,
		"exp_bonus": 1.5,
		"soul_mult": 1.3,
	},
	{
		"name": "🧙 商旅之路",
		"desc": "商人每3波出现（默认5波）\n获得额外起始魂石×1.5",
		"color": Color(0.4, 0.85, 1.0),
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
	overlay.color = Color(0, 0, 0, 0.88)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(700, 320)
	vbox.position = Vector2(-350, -160)
	vbox.add_theme_constant_override("separation", 18)
	add_child(vbox)

	var title = Label.new()
	title.text = "🗺 选择你的路线"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 1, 0.7))
	vbox.add_child(title)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	for route in ROUTES:
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(200, 220)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(card)

		var cvbox = VBoxContainer.new()
		cvbox.add_theme_constant_override("separation", 8)
		card.add_child(cvbox)

		var name_lbl = Label.new()
		name_lbl.text = route["name"]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", route["color"])
		cvbox.add_child(name_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = route["desc"]
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cvbox.add_child(desc_lbl)

		var btn = Button.new()
		btn.text = "选择此路线"
		btn.custom_minimum_size = Vector2(160, 40)
		var r = route
		btn.pressed.connect(func(): _select_route(r))
		cvbox.add_child(btn)

func _select_route(route: Dictionary) -> void:
	visible = false
	emit_signal("route_selected", route)
