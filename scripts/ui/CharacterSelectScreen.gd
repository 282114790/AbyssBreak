# CharacterSelectScreen.gd
# 角色选择 — 默会知识原则：
# 1. 主题色气质：紫=法师魔力 橙=战士力量 绿=猎手敏捷，一眼识别
# 2. 收益/代价分离：▲绿=优势 ▼橙=劣势，不需文字标注
# 3. 点击即出发：去掉"进入深渊"按钮，选中即开始
# 4. 锁定可见化：展示具体解锁条件，激发目标感
# 5. 焦点层次：色条→图标→名称→优势→劣势→初始技能
extends CanvasLayer

signal character_selected(character_id: String)
signal daily_challenge_requested

var _registry: Node = null
var _meta: Node = null
var _daily_challenge: Node = null

const CHAR_CONFIGS := {
	"mage": {
		"tc": Color(0.6, 0.35, 1.0),
		"bg": Color(0.08, 0.04, 0.16, 0.95),
		"benefits": ["伤害 ×1.2"],
		"costs": [],
		"skill_tag": "🔥 火球术",
		"unlock_hint": "",
	},
	"warrior": {
		"tc": Color(0.95, 0.5, 0.1),
		"bg": Color(0.14, 0.08, 0.02, 0.95),
		"benefits": ["HP ×1.8", "每秒回血 3"],
		"costs": ["移速 ×0.85", "拾取 ×0.8"],
		"skill_tag": "❄ 冰刃斩",
		"unlock_hint": "完成 3 局后解锁",
	},
	"hunter": {
		"tc": Color(0.2, 0.85, 0.45),
		"bg": Color(0.03, 0.12, 0.05, 0.95),
		"benefits": ["移速 ×1.35", "拾取范围 ×1.3"],
		"costs": ["HP ×0.75"],
		"skill_tag": "⚡ 闪电链",
		"unlock_hint": "完成 5 局并取得积分后解锁",
	},
}

func _ready() -> void:
	layer = 20
	visible = false

func show_screen(registry: Node, meta: Node) -> void:
	_registry = registry
	_meta = meta
	visible = true
	_daily_challenge = Node.new()
	_daily_challenge.set_script(load("res://scripts/systems/DailyChallenge.gd"))
	add_child(_daily_challenge)
	_build_ui()
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_bgm_menu"): sm.play_bgm_menu()

func _build_ui() -> void:
	for c in get_children(): c.queue_free()

	var bg = ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.08, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.custom_minimum_size = Vector2(780, 420)
	root.position = Vector2(-390, -210)
	root.add_theme_constant_override("separation", 18)
	add_child(root)

	var title = Label.new()
	title.text = "选择角色"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(hbox)

	for char_data in _registry.all_characters:
		var unlocked = _registry.is_unlocked(char_data.id, _meta)
		var cfg = CHAR_CONFIGS.get(char_data.id, {})
		_build_card(hbox, char_data, cfg, unlocked)

	# ── 每日挑战 ──
	var dc_config: Dictionary = {}
	var is_done := false
	if _daily_challenge:
		is_done = _daily_challenge.is_completed_today()
		dc_config = _daily_challenge.get_challenge_config()

	if not dc_config.is_empty():
		var dc_box = HBoxContainer.new()
		dc_box.alignment = BoxContainer.ALIGNMENT_CENTER
		dc_box.add_theme_constant_override("separation", 10)
		root.add_child(dc_box)

		var dc_card = PanelContainer.new()
		dc_card.custom_minimum_size = Vector2(380, 42)
		var dc_style = StyleBoxFlat.new()
		dc_style.bg_color = Color(0.06, 0.08, 0.18, 0.9) if not is_done else Color(0.04, 0.06, 0.1, 0.6)
		dc_style.border_width_left = 1; dc_style.border_width_right = 1
		dc_style.border_width_top = 1; dc_style.border_width_bottom = 1
		dc_style.border_color = Color(0.4, 0.6, 1.0, 0.4) if not is_done else Color(0.3, 0.4, 0.5, 0.3)
		dc_style.corner_radius_top_left = 6; dc_style.corner_radius_top_right = 6
		dc_style.corner_radius_bottom_left = 6; dc_style.corner_radius_bottom_right = 6
		dc_style.content_margin_left = 12; dc_style.content_margin_right = 12
		dc_style.content_margin_top = 4; dc_style.content_margin_bottom = 4
		dc_card.add_theme_stylebox_override("panel", dc_style)

		var dc_vbox = VBoxContainer.new()
		dc_vbox.add_theme_constant_override("separation", 2)
		dc_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dc_card.add_child(dc_vbox)

		var dc_title_lbl = Label.new()
		if is_done:
			dc_title_lbl.text = "✅ 每日挑战（已完成）"
			dc_title_lbl.add_theme_color_override("font_color", Color(0.45, 0.55, 0.65))
		else:
			dc_title_lbl.text = "📅 每日挑战 — %s" % dc_config.get("modifier_name", "")
			dc_title_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
		dc_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dc_title_lbl.add_theme_font_size_override("font_size", 13)
		dc_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dc_vbox.add_child(dc_title_lbl)

		if not is_done:
			var dc_desc_lbl = Label.new()
			dc_desc_lbl.text = dc_config.get("modifier_desc", "")
			dc_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			dc_desc_lbl.add_theme_font_size_override("font_size", 11)
			dc_desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.75))
			dc_desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dc_vbox.add_child(dc_desc_lbl)

			dc_card.mouse_filter = Control.MOUSE_FILTER_STOP
			dc_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

			var dc_hover = dc_style.duplicate()
			dc_hover.bg_color = Color(0.08, 0.12, 0.25, 0.95)
			dc_hover.border_color = Color(0.5, 0.7, 1.0, 0.7)

			dc_card.mouse_entered.connect(func():
				dc_card.add_theme_stylebox_override("panel", dc_hover)
			)
			dc_card.mouse_exited.connect(func():
				dc_card.add_theme_stylebox_override("panel", dc_style)
			)
			dc_card.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					visible = false
					emit_signal("daily_challenge_requested")
			)

		dc_box.add_child(dc_card)

func _build_card(parent: HBoxContainer, char_data: Resource, cfg: Dictionary, unlocked: bool) -> void:
	var tc: Color = cfg.get("tc", Color(0.5, 0.5, 0.6))
	var bg_col: Color = cfg.get("bg", Color(0.06, 0.06, 0.12, 0.95))

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(230, 320)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var card_style = StyleBoxFlat.new()
	card_style.corner_radius_top_left = 10; card_style.corner_radius_top_right = 10
	card_style.corner_radius_bottom_left = 10; card_style.corner_radius_bottom_right = 10
	card_style.content_margin_left = 16; card_style.content_margin_right = 16
	card_style.content_margin_top = 0; card_style.content_margin_bottom = 14
	card_style.border_width_left = 2; card_style.border_width_right = 2
	card_style.border_width_top = 2; card_style.border_width_bottom = 2

	if unlocked:
		card_style.bg_color = bg_col
		card_style.border_color = Color(tc.r * 0.45, tc.g * 0.45, tc.b * 0.45, 0.5)
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		card_style.bg_color = Color(0.06, 0.06, 0.08, 0.85)
		card_style.border_color = Color(0.25, 0.25, 0.3, 0.4)

	card.add_theme_stylebox_override("panel", card_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	# ── 顶部色条 ──
	var accent = ColorRect.new()
	accent.custom_minimum_size = Vector2(0, 4)
	accent.color = tc if unlocked else Color(0.3, 0.3, 0.35, 0.5)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(accent)

	# ── 图标 ──
	var icon_lbl = Label.new()
	icon_lbl.text = char_data.icon_emoji if unlocked else "🔒"
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 46)
	icon_lbl.custom_minimum_size = Vector2(0, 72)
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not unlocked:
		icon_lbl.modulate = Color(0.5, 0.5, 0.5)
	vbox.add_child(icon_lbl)

	# ── 名称 ──
	var name_lbl = Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.custom_minimum_size = Vector2(0, 30)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if unlocked:
		name_lbl.text = char_data.display_name
		name_lbl.add_theme_color_override("font_color", tc)
	else:
		name_lbl.text = char_data.display_name
		name_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	vbox.add_child(name_lbl)

	# ── 分割线 ──
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(tc.r, tc.g, tc.b, 0.2) if unlocked else Color(0.3, 0.3, 0.35, 0.15)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer1)

	if unlocked:
		# ── 收益 ──
		for b in cfg.get("benefits", []):
			var lbl = Label.new()
			lbl.text = "▲ " + b
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.45))
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(lbl)

		var costs: Array = cfg.get("costs", [])
		if not costs.is_empty():
			var spacer2 = Control.new()
			spacer2.custom_minimum_size = Vector2(0, 4)
			vbox.add_child(spacer2)

		# ── 代价 ──
		for c in costs:
			var lbl = Label.new()
			lbl.text = "▼ " + c
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.3))
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(lbl)
	else:
		# ── 解锁条件 ──
		var hint_lbl = Label.new()
		hint_lbl.text = cfg.get("unlock_hint", "需要解锁")
		hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_lbl.add_theme_font_size_override("font_size", 12)
		hint_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(hint_lbl)

	# ── 弹性间距 ──
	var flex = Control.new()
	flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	flex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(flex)

	# ── 底部：初始技能标签 ──
	if unlocked:
		var skill_sep = ColorRect.new()
		skill_sep.custom_minimum_size = Vector2(0, 1)
		skill_sep.color = Color(tc.r, tc.g, tc.b, 0.15)
		skill_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(skill_sep)

		var skill_lbl = Label.new()
		skill_lbl.text = cfg.get("skill_tag", "")
		skill_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skill_lbl.add_theme_font_size_override("font_size", 12)
		skill_lbl.add_theme_color_override("font_color", Color(tc.r * 0.7 + 0.3, tc.g * 0.7 + 0.3, tc.b * 0.7 + 0.3, 0.85))
		skill_lbl.custom_minimum_size = Vector2(0, 22)
		skill_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(skill_lbl)

	# ── Hover / Click ──
	if unlocked:
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
				_select_character(char_data.id)
		)

	parent.add_child(card)

func _select_character(char_id: String) -> void:
	_registry.selected_id = char_id
	visible = false
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_bgm_battle"): sm.play_bgm_battle()
	emit_signal("character_selected", char_id)
