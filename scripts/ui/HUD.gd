# HUD.gd
extends CanvasLayer

var game_manager: Node = null

var hp_bar: ProgressBar
var hp_label: Label
var exp_bar: ProgressBar
var level_label: Label
var timer_label: Label
var wave_label: Label
var level_up_panel: Control
var choice_buttons: HBoxContainer
var difficulty_badge: Label = null

var _pending_choices: Array = []

# 图标资源（只加载一次）
var _skill_icon_map := {
	"fireball":0,"orbital":1,"lightning":2,"iceblade":3,"ice_blade":3,
	"frostzone":4,"runeblast":5,"poison_cloud":6,"void_rift":7,"blood_nova":8,
	"time_slow":9,"thorn_aura":10,"meteor_shower":11,"chain_lance":12,
	"holywave":13,"arcane_orb":14
}
var _passive_icon_map := {
	"boots":0,"power_ring":1,"iron_heart":2,"toxic_vial":3,
	"mana_crystal":4,"shadow_cloak":5,"attack_speed":6,"exp_ring":7
}
var _sktex = null
var _pstex = null

func _ready() -> void:
	EventBus.player_damaged.connect(_on_hp_changed)
	EventBus.player_exp_changed.connect(_on_exp_changed)
	EventBus.player_leveled_up.connect(_on_level_up)
	EventBus.wave_changed.connect(_on_wave_changed)
	EventBus.show_level_up_panel.connect(_show_upgrade_panel)
	EventBus.game_over.connect(_on_game_over)
	if EventBus.has_signal("player_won"):
		EventBus.player_won.connect(_on_victory)
	# 预加载图标纹理
	if ResourceLoader.exists("res://assets/ui/skill_icons.png"):
		_sktex = load("res://assets/ui/skill_icons.png")
	if ResourceLoader.exists("res://assets/ui/passive_icons.png"):
		_pstex = load("res://assets/ui/passive_icons.png")
	_setup_debug_hud()

func _process(_delta: float) -> void:
	if game_manager and timer_label:
		var t = int(game_manager.game_time)
		timer_label.text = "%02d:%02d" % [t / 60, t % 60]
	if wave_label and game_manager:
		var wm = game_manager.get("wave_manager")
		if wm:
			var total_waves = wm.wave_configs.size()
			if wm.is_endless:
				wave_label.text = "Wave %d / ∞" % wm.current_wave
			else:
				wave_label.text = "Wave %d / %d" % [wm.current_wave, total_waves]
	_update_difficulty_badge()
	_update_debug_hud()

func _update_difficulty_badge() -> void:
	if not difficulty_badge or not game_manager: return
	var diff = game_manager.get("current_difficulty")
	if diff == null: return
	# DifficultyData 是 Resource，直接读属性 .id
	var diff_id: String = diff.id if diff is Resource else str(diff.get("id", ""))
	match diff_id:
		"normal":
			difficulty_badge.text = "🟢 普通"
			difficulty_badge.add_theme_color_override("font_color", Color(0.3,1.0,0.3))
		"hard":
			difficulty_badge.text = "🟠 困难"
			difficulty_badge.add_theme_color_override("font_color", Color(1.0,0.6,0.1))
		"abyss":
			difficulty_badge.text = "🔴 深渊"
			difficulty_badge.add_theme_color_override("font_color", Color(1.0,0.2,0.2))
		_:
			if diff_id != "" and diff_id != "null":
				difficulty_badge.text = "⚙ " + diff_id
				difficulty_badge.add_theme_color_override("font_color", Color.WHITE)

func _on_hp_changed(current: float, maximum: float) -> void:
	if hp_bar:
		hp_bar.max_value = maximum
		hp_bar.value = current
	if hp_label:
		hp_label.text = "%d / %d" % [int(current), int(maximum)]

func _on_exp_changed(current: int, required: int) -> void:
	if exp_bar:
		exp_bar.max_value = required
		exp_bar.value = current

func _on_level_up(new_level: int) -> void:
	if level_label:
		level_label.text = "Lv." + str(new_level)

func _on_wave_changed(wave: int) -> void:
	if wave == -1:
		# 精英波通知
		if wave_label:
			wave_label.text = "⚠ 精英波 ⚠"
			wave_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.0))
		_show_elite_alert()
		return
	if wave_label:
		wave_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	if wave_label and game_manager:
		var wm = game_manager.get("wave_manager")
		if wm:
			var total = wm.wave_configs.size()
			wave_label.text = "Wave %d / %d" % [wave, total]
		else:
			wave_label.text = "Wave %d" % wave

func _show_elite_alert() -> void:
	# 屏幕中央弹出精英警告文字，1.5秒后淡出
	var alert = Label.new()
	alert.text = "⚠  精英敌人来袭！  ⚠"
	alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert.add_theme_font_size_override("font_size", 32)
	alert.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))
	alert.anchor_left   = 0.5; alert.anchor_right  = 0.5
	alert.anchor_top    = 0.35; alert.anchor_bottom = 0.35
	alert.offset_left = -300; alert.offset_right = 300
	alert.offset_top  = -30;  alert.offset_bottom = 30
	add_child(alert)
	var tween = alert.create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(alert, "modulate:a", 0.0, 0.5)
	tween.tween_callback(alert.queue_free)

# ── 升级面板 ──────────────────────────────────────────────────────────────────
var _picks_remaining: int = 0   # 本次升级还剩几次选择（5选2 → picks=2）
var _first_pick_done: bool = false

func _set_upgrade_panel_visible(v: bool) -> void:
	if level_up_panel:
		level_up_panel.visible = v
	# 同步遮罩
	var overlay = level_up_panel.get_parent().get_node_or_null("UpgradeOverlay") if level_up_panel else null
	if overlay:
		overlay.visible = v

func _show_upgrade_panel(choices: Array) -> void:
	if not level_up_panel or not choice_buttons: return
	_pending_choices = choices
	_picks_remaining = 2      # 5选2
	_first_pick_done = false
	_set_upgrade_panel_visible(true)
	get_tree().paused = true
	var snd = get_tree().get_first_node_in_group("sound_manager")
	if snd: snd.play_level_up()
	_rebuild_choice_buttons()

func _rebuild_choice_buttons() -> void:
	for child in choice_buttons.get_children(): child.queue_free()

	# 标题更新（PanelTitle 在 panel_vbox 的第一个子节点 title_bar 里）
	var ptitle = level_up_panel.find_child("PanelTitle", true, false) if level_up_panel else null
	if ptitle and ptitle is Label:
		if _picks_remaining == 2:
			ptitle.text = "✨  选择升级（选 2 个）"
		else:
			ptitle.text = "✨  再选 1 个"

	for i in range(_pending_choices.size()):
		var choice = _pending_choices[i]
		var is_curse = choice.get("type", "") == "curse"
		var ctype   = choice.get("type", "")

		# ── 卡片容器（PanelContainer 作为点击区域）────────────────
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(168, 240)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical   = Control.SIZE_FILL
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		# 卡片配色
		var bg_col     : Color
		var border_col : Color
		var accent_col : Color
		match ctype:
			"curse":
				bg_col = Color(0.20, 0.04, 0.04, 0.96)
				border_col = Color(0.9, 0.35, 0.1)
				accent_col = Color(1.0, 0.5, 0.2)
			"evolve":
				bg_col = Color(0.10, 0.08, 0.22, 0.96)
				border_col = Color(0.7, 0.4, 1.0)
				accent_col = Color(0.85, 0.6, 1.0)
			"heal":
				bg_col = Color(0.04, 0.16, 0.08, 0.96)
				border_col = Color(0.3, 0.9, 0.45)
				accent_col = Color(0.5, 1.0, 0.6)
			_:
				bg_col = Color(0.06, 0.08, 0.22, 0.96)
				border_col = Color(0.38, 0.58, 1.0)
				accent_col = Color(0.65, 0.82, 1.0)

		var card_style = StyleBoxFlat.new()
		card_style.bg_color = bg_col
		card_style.border_width_left = 2; card_style.border_width_right  = 2
		card_style.border_width_top  = 2; card_style.border_width_bottom = 2
		card_style.border_color = border_col
		card_style.corner_radius_top_left    = 8; card_style.corner_radius_top_right    = 8
		card_style.corner_radius_bottom_left = 8; card_style.corner_radius_bottom_right = 8
		card_style.content_margin_left  = 0; card_style.content_margin_right  = 0
		card_style.content_margin_top   = 0; card_style.content_margin_bottom = 0
		card.add_theme_stylebox_override("panel", card_style)

		# ── 卡片内布局：垂直分三区 ─────────────────────────────
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 0)
		card.add_child(vbox)

		# 区域1：顶部色条（accent）
		var top_bar = ColorRect.new()
		top_bar.custom_minimum_size = Vector2(0, 4)
		top_bar.color = border_col
		top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(top_bar)

		# 区域2：图标区（用 PanelContainer 当背景色 + CenterContainer 居中图标）
		var icon_panel = PanelContainer.new()
		icon_panel.custom_minimum_size = Vector2(0, 72)
		icon_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_bg_style = StyleBoxFlat.new()
		icon_bg_style.bg_color = Color(bg_col.r * 0.55, bg_col.g * 0.55, bg_col.b * 0.6, 0.95)
		icon_bg_style.content_margin_left = 0; icon_bg_style.content_margin_right  = 0
		icon_bg_style.content_margin_top  = 0; icon_bg_style.content_margin_bottom = 0
		icon_panel.add_theme_stylebox_override("panel", icon_bg_style)
		vbox.add_child(icon_panel)

		# CenterContainer 居中图标内容
		var icon_center = CenterContainer.new()
		icon_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon_center.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_panel.add_child(icon_center)

		# 图标居中 HBox
		var icon_hbox = HBoxContainer.new()
		icon_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		icon_hbox.add_theme_constant_override("separation", 0)
		icon_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_center.add_child(icon_hbox)

		# 图标
		var sid = choice.get("skill_id", choice.get("passive_id", ""))
		var itex = null; var icol = -1
		if _sktex and _skill_icon_map.has(sid):
			itex = _sktex; icol = _skill_icon_map[sid]
		elif _pstex and _passive_icon_map.has(sid):
			itex = _pstex; icol = _passive_icon_map[sid]

		if itex and icol >= 0:
			var ir = TextureRect.new()
			var at = AtlasTexture.new()
			at.atlas = itex; at.region = Rect2(icol * 32, 0, 32, 32)
			ir.texture = at
			ir.custom_minimum_size = Vector2(48, 48)
			ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_hbox.add_child(ir)
		else:
			# 无图标时用 emoji 大字
			var emoji_lbl = Label.new()
			match ctype:
				"curse":  emoji_lbl.text = "💀"
				"heal":   emoji_lbl.text = "💊"
				"evolve": emoji_lbl.text = "⭐"
				_:        emoji_lbl.text = "✦"
			emoji_lbl.add_theme_font_size_override("font_size", 32)
			emoji_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_hbox.add_child(emoji_lbl)

		# 区域3：文字区（名称 + 描述）
		var text_pad = MarginContainer.new()
		text_pad.add_theme_constant_override("margin_left",  10)
		text_pad.add_theme_constant_override("margin_right", 10)
		text_pad.add_theme_constant_override("margin_top",    8)
		text_pad.add_theme_constant_override("margin_bottom", 8)
		text_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
		text_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(text_pad)

		var text_vbox = VBoxContainer.new()
		text_vbox.add_theme_constant_override("separation", 4)
		text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_pad.add_child(text_vbox)

		var name_lbl = Label.new()
		name_lbl.text = "[%d] %s" % [i + 1, choice.get("display_name", "???")]
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", accent_col)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		text_vbox.add_child(name_lbl)

		var sep_line = ColorRect.new()
		sep_line.custom_minimum_size = Vector2(0, 1)
		sep_line.color = Color(border_col.r, border_col.g, border_col.b, 0.4)
		sep_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_vbox.add_child(sep_line)

		var desc_lbl = Label.new()
		desc_lbl.text = choice.get("description", "")
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.9))
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desc_lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		text_vbox.add_child(desc_lbl)

		# ── 悬停高亮（GuiInput 模拟 hover 效果）─────────────────
		var hover_style = card_style.duplicate()
		hover_style.bg_color = Color(
			clampf(bg_col.r + 0.10, 0, 1),
			clampf(bg_col.g + 0.10, 0, 1),
			clampf(bg_col.b + 0.12, 0, 1), 0.98)
		hover_style.border_color = accent_col
		hover_style.border_width_left = 3; hover_style.border_width_right  = 3
		hover_style.border_width_top  = 3; hover_style.border_width_bottom = 3

		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_on_choice_selected(choice, i)
		)
		card.mouse_entered.connect(func() -> void:
			card.add_theme_stylebox_override("panel", hover_style)
		)
		card.mouse_exited.connect(func() -> void:
			card.add_theme_stylebox_override("panel", card_style)
		)

		choice_buttons.add_child(card)

	# ── 调试：下一帧打印实际尺寸 ──
	await get_tree().process_frame
	print("[HUD DEBUG] level_up_panel visible=", level_up_panel.visible if level_up_panel else "null",
		  " size=", level_up_panel.size if level_up_panel else "null")
	print("[HUD DEBUG] choice_buttons size=", choice_buttons.size,
		  " children=", choice_buttons.get_child_count())
	for ch in choice_buttons.get_children():
		print("  card: ", ch.get_class(), " size=", ch.size,
			  " min=", ch.custom_minimum_size, " visible=", ch.visible)

func _input(event: InputEvent) -> void:
	if not level_up_panel or not level_up_panel.visible: return
	for i in range(1, 6):  # 1-5 键对应最多5个选项
		if event is InputEventKey and event.pressed and event.keycode == (KEY_0 + i):
			if i - 1 < _pending_choices.size():
				_on_choice_selected(_pending_choices[i - 1], i - 1)
				get_viewport().set_input_as_handled()

func _on_choice_selected(choice: Dictionary, idx: int) -> void:
	# 立即应用该选择（不等第二次）
	EventBus.emit_signal("upgrade_chosen", choice)
	_first_pick_done = true
	_picks_remaining -= 1

	# 从列表里移除已选的
	_pending_choices.remove_at(idx)

	if _picks_remaining <= 0 or _pending_choices.is_empty():
		# 选完了，关闭面板
		_set_upgrade_panel_visible(false)
		EventBus.game_logic_paused = false
		get_tree().paused = false
		EventBus.emit_signal("upgrade_panel_closed")
	else:
		# 还有一次，重建按钮
		_rebuild_choice_buttons()

# ── 结算界面 ──────────────────────────────────────────────────────────────────
func _on_game_over(survived_time: float, score: int) -> void:
	_show_end_screen(false, survived_time, score)

func _on_victory(survived_time: float, score: int) -> void:
	_show_end_screen(true, survived_time, score)

func _show_end_screen(is_victory: bool, survived_time: float, score: int) -> void:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var title = Label.new()
	title.text = "🏆 Victory!" if is_victory else "💀 Game Over"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color",
		Color(1.0,0.85,0.1) if is_victory else Color(1.0,0.3,0.3))
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position.y = -80
	overlay.add_child(title)

	var t = int(survived_time)
	var stats = Label.new()
	stats.text = "存活时间：%02d:%02d    得分：%d" % [t/60, t%60, score]
	stats.add_theme_font_size_override("font_size", 28)
	stats.add_theme_color_override("font_color", Color.WHITE)
	stats.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.add_child(stats)

	var hint = Label.new()
	hint.text = "按 R 重新开始"
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.5,0.8,1.0))
	hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.position.y = 80
	overlay.add_child(hint)

# ── 调试信息 HUD（FPS + 对象数量）────────────────────────────────────────────
var _debug_label: Label = null

func _setup_debug_hud() -> void:
	_debug_label = Label.new()
	_debug_label.name = "DebugLabel"
	_debug_label.add_theme_font_size_override("font_size", 13)
	_debug_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))
	# 右上角
	_debug_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_debug_label.offset_left  = -220
	_debug_label.offset_right = -8
	_debug_label.offset_top   = 8
	_debug_label.offset_bottom = 120
	_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_debug_label)

func _update_debug_hud() -> void:
	if not _debug_label: return
	var fps = Engine.get_frames_per_second()
	var node_count = get_tree().get_node_count()
	# 统计敌人、投射物数量
	var enemy_count = get_tree().get_nodes_in_group("enemies").size()
	var proj_count  = get_tree().get_nodes_in_group("player_projectiles").size()
	_debug_label.text = "FPS: %d\nNodes: %d\nEnemies: %d\nProjectiles: %d" % [
		fps, node_count, enemy_count, proj_count
	]
	# FPS 颜色警告
	if fps < 30:
		_debug_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	elif fps < 50:
		_debug_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	else:
		_debug_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))
