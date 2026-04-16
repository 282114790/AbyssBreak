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

# 技能图标文件映射（独立 PNG）
var _skill_icon_files := {
	"fireball": "fireball", "orbital": "orbital", "lightning": "lightning",
	"iceblade": "iceblade", "ice_blade": "iceblade",
	"frostzone": "frostzone", "runeblast": "runeblast",
	"poison_cloud": "poison_cloud", "void_rift": "void_rift",
	"blood_nova": "blood_nova", "time_slow": "time_slow",
	"thorn_aura": "thorn_aura", "meteor_shower": "meteor_shower",
	"chain_lance": "chain_lance", "holywave": "holywave",
	"arcane_orb": "arcane_orb",
}
var _passive_icon_files := {
	"boots": "boots", "power_ring": "power_ring", "iron_heart": "iron_heart",
	"toxic_vial": "toxic_vial", "mana_crystal": "mana_crystal",
	"shadow_cloak": "shadow_cloak", "attack_speed": "attack_speed",
	"exp_ring": "exp_ring",
}

func _ready() -> void:
	EventBus.player_damaged.connect(_on_hp_changed)
	EventBus.player_hp_changed.connect(_on_hp_changed)
	EventBus.player_exp_changed.connect(_on_exp_changed)
	EventBus.player_leveled_up.connect(_on_level_up)
	EventBus.wave_changed.connect(_on_wave_changed)
	EventBus.show_level_up_panel.connect(_show_upgrade_panel)
	EventBus.game_over.connect(_on_game_over)
	if EventBus.has_signal("player_won"):
		EventBus.player_won.connect(_on_victory)
	EventBus.show_skill_replace_panel.connect(_show_replace_panel)
	EventBus.synergy_activated.connect(_on_synergy_activated)
	EventBus.element_resonance_activated.connect(_on_element_resonance)
	EventBus.chapter_changed.connect(_on_chapter_changed)
	EventBus.build_discovered.connect(_on_build_discovered)
	_setup_gameplay_hud()
	_setup_debug_hud()

func _process(_delta: float) -> void:
	if game_manager and timer_label:
		var t = int(game_manager.game_time)
		timer_label.text = "⏱ %02d:%02d" % [t / 60, t % 60]
	if wave_label and game_manager:
		var wm = game_manager.get("wave_manager")
		if wm:
			var total_waves = wm.wave_configs.size()
			if wm.is_endless:
				wave_label.text = "🌊 第 %d 波 / ∞" % wm.current_wave
			else:
				wave_label.text = "🌊 第 %d 波 / %d" % [wm.current_wave, total_waves]
	# 实时更新金币
	if game_manager:
		var gold_lbl = get_meta("gold_label") if has_meta("gold_label") else null
		if gold_lbl and is_instance_valid(gold_lbl):
			var p = game_manager.get("player")
			if p and is_instance_valid(p):
				gold_lbl.text = "💰 金币：%d" % p.gold
	_update_difficulty_badge()
	_update_gameplay_hud()
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
		if wave_label:
			wave_label.text = "⚠ 精英波 ⚠"
			wave_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.0))
		_show_elite_alert()
		return
	if wave_label:
		wave_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	if wave_label and game_manager:
		var wm = game_manager.get("wave_manager")
		if wm:
			var total = wm.wave_configs.size()
			wave_label.text = "🌊 第 %d 波 / %d" % [wave, total]
		else:
			wave_label.text = "🌊 第 %d 波" % wave

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
var _picks_remaining: int = 0
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
	_picks_remaining = 2
	_first_pick_done = false
	_reroll_count = 0
	_set_upgrade_panel_visible(true)
	get_tree().paused = true
	var snd = get_tree().get_first_node_in_group("sound_manager")
	if snd: snd.play_level_up()
	_rebuild_choice_buttons()

var _reroll_count: int = 0

func _rebuild_choice_buttons() -> void:
	for child in choice_buttons.get_children(): child.queue_free()

	# 剩余选择次数提示
	var pick_hint = get_meta("pick_hint_label") if has_meta("pick_hint_label") else null
	if is_instance_valid(pick_hint):
		pick_hint.text = "选择 %d/%d" % [2 - _picks_remaining + 1, 2]
		pick_hint.visible = true
	elif level_up_panel:
		pick_hint = Label.new()
		pick_hint.name = "PickHintLabel"
		pick_hint.text = "选择 %d/%d" % [2 - _picks_remaining + 1, 2]
		pick_hint.add_theme_font_size_override("font_size", 14)
		pick_hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
		pick_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pick_hint.position = Vector2(0, -28)
		pick_hint.size = Vector2(level_up_panel.size.x, 24)
		level_up_panel.add_child(pick_hint)
		set_meta("pick_hint_label", pick_hint)

	for i in range(_pending_choices.size()):
		var choice = _pending_choices[i]
		var ctype = choice.get("type", "")

		var tc     : Color
		var bg_col : Color
		match ctype:
			"curse":
				tc = Color(1.0, 0.4, 0.15)
				bg_col = Color(0.14, 0.04, 0.04, 0.96)
			"evolve":
				tc = Color(0.75, 0.45, 1.0)
				bg_col = Color(0.1, 0.06, 0.18, 0.96)
			"heal":
				tc = Color(0.35, 0.95, 0.5)
				bg_col = Color(0.04, 0.1, 0.06, 0.96)
			"skill_replace":
				tc = Color(0.9, 0.6, 0.2)
				bg_col = Color(0.12, 0.08, 0.03, 0.96)
			_:
				if choice.has("skill_id"):
					tc = Color(0.45, 0.7, 1.0)
					bg_col = Color(0.05, 0.06, 0.16, 0.96)
				else:
					tc = Color(0.4, 0.9, 0.55)
					bg_col = Color(0.04, 0.08, 0.06, 0.96)

		var card_style = StyleBoxFlat.new()
		card_style.bg_color = bg_col
		card_style.border_width_left = 2; card_style.border_width_right = 2
		card_style.border_width_top = 2; card_style.border_width_bottom = 2
		card_style.border_color = Color(tc.r * 0.5, tc.g * 0.5, tc.b * 0.5, 0.45)
		card_style.corner_radius_top_left = 8; card_style.corner_radius_top_right = 8
		card_style.corner_radius_bottom_left = 8; card_style.corner_radius_bottom_right = 8
		card_style.content_margin_left = 8; card_style.content_margin_right = 8
		card_style.content_margin_top = 0; card_style.content_margin_bottom = 6

		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(130, 0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.add_theme_stylebox_override("panel", card_style)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(vbox)

		var accent = ColorRect.new()
		accent.custom_minimum_size = Vector2(0, 3)
		accent.color = tc
		accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(accent)

		var icon_center = CenterContainer.new()
		icon_center.custom_minimum_size = Vector2(0, 50)
		icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(icon_center)

		var sid = choice.get("skill_id", choice.get("passive_id", ""))
		var icon_loaded := false

		if _skill_icon_files.has(sid):
			var icon_path = "res://assets/ui/skill_icons/%s.png" % _skill_icon_files[sid]
			if ResourceLoader.exists(icon_path):
				var ir = TextureRect.new()
				ir.texture = load(icon_path)
				ir.custom_minimum_size = Vector2(44, 44)
				ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				ir.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
				icon_center.add_child(ir)
				icon_loaded = true

		if not icon_loaded and _passive_icon_files.has(sid):
			var picon_path = "res://assets/ui/passive_icons/%s.png" % _passive_icon_files[sid]
			if ResourceLoader.exists(picon_path):
				var ir = TextureRect.new()
				ir.texture = load(picon_path)
				ir.custom_minimum_size = Vector2(44, 44)
				ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				ir.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
				icon_center.add_child(ir)
				icon_loaded = true

		if not icon_loaded:
			var emoji_lbl = Label.new()
			match ctype:
				"curse":  emoji_lbl.text = "💀"
				"heal":   emoji_lbl.text = "💚"
				"evolve": emoji_lbl.text = "⭐"
				_:        emoji_lbl.text = "✦"
			emoji_lbl.add_theme_font_size_override("font_size", 26)
			emoji_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_center.add_child(emoji_lbl)

		var raw_name: String = choice.get("display_name", "???")
		var clean_name := raw_name
		for prefix in ["新技能: ", "新技能:", "升级 ", "升级"]:
			if clean_name.begins_with(prefix):
				clean_name = clean_name.substr(prefix.length())
				break

		var name_lbl = Label.new()
		name_lbl.text = clean_name
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", tc)
		name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		name_lbl.add_theme_constant_override("shadow_offset_x", 1)
		name_lbl.add_theme_constant_override("shadow_offset_y", 1)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(name_lbl)

		var is_upgrade = raw_name.find("升级") >= 0 or raw_name.find("Lv") >= 0
		if is_upgrade:
			var lv_lbl = Label.new()
			var cur_lv = choice.get("current_level", 0)
			if cur_lv > 0:
				lv_lbl.text = "Lv%d → Lv%d" % [cur_lv, cur_lv + 1]
			else:
				lv_lbl.text = "等级提升"
			lv_lbl.add_theme_font_size_override("font_size", 9)
			lv_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
			lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lv_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(lv_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = choice.get("description", "")
		desc_lbl.add_theme_font_size_override("font_size", 9)
		desc_lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.72))
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(desc_lbl)

		var key_lbl = Label.new()
		key_lbl.text = "[%d]" % (i + 1)
		key_lbl.add_theme_font_size_override("font_size", 8)
		key_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.25))
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(key_lbl)

		var hover_style = card_style.duplicate()
		hover_style.bg_color = Color(
			clampf(bg_col.r + 0.04, 0, 1),
			clampf(bg_col.g + 0.04, 0, 1),
			clampf(bg_col.b + 0.05, 0, 1), 0.98)
		hover_style.border_color = Color(tc.r, tc.g, tc.b, 0.85)

		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_on_choice_selected(choice, i)
		)
		card.mouse_entered.connect(func() -> void:
			card.add_theme_stylebox_override("panel", hover_style)
			var tw = card.create_tween()
			tw.tween_property(card, "scale", Vector2(1.03, 1.03), 0.1).set_ease(Tween.EASE_OUT)
		)
		card.mouse_exited.connect(func() -> void:
			card.add_theme_stylebox_override("panel", card_style)
			var tw = card.create_tween()
			tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)
		)

		choice_buttons.add_child(card)

	# reroll button
	var reroll_cost = 20 + _reroll_count * 15
	var reroll_card = PanelContainer.new()
	var rs = StyleBoxFlat.new()
	rs.bg_color = Color(0.12, 0.10, 0.06, 0.92)
	rs.border_width_left = 2; rs.border_width_right = 2
	rs.border_width_top = 2; rs.border_width_bottom = 2
	rs.border_color = Color(0.6, 0.5, 0.2, 0.5)
	rs.corner_radius_top_left = 8; rs.corner_radius_top_right = 8
	rs.corner_radius_bottom_left = 8; rs.corner_radius_bottom_right = 8
	rs.content_margin_left = 8; rs.content_margin_right = 8
	rs.content_margin_top = 12; rs.content_margin_bottom = 12
	reroll_card.add_theme_stylebox_override("panel", rs)
	reroll_card.custom_minimum_size = Vector2(80, 0)
	reroll_card.mouse_filter = Control.MOUSE_FILTER_STOP
	reroll_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var rv = VBoxContainer.new()
	rv.add_theme_constant_override("separation", 6)
	rv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reroll_card.add_child(rv)
	var rl1 = Label.new()
	rl1.text = "🔄"
	rl1.add_theme_font_size_override("font_size", 22)
	rl1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rl1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rv.add_child(rl1)
	var rl2 = Label.new()
	rl2.text = "重投"
	rl2.add_theme_font_size_override("font_size", 11)
	rl2.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	rl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rl2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rv.add_child(rl2)
	var rl3 = Label.new()
	rl3.text = "%d金" % reroll_cost
	rl3.add_theme_font_size_override("font_size", 9)
	rl3.add_theme_color_override("font_color", Color(0.6, 0.6, 0.4))
	rl3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rl3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rv.add_child(rl3)
	reroll_card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_reroll(reroll_cost)
	)
	var rh = rs.duplicate()
	rh.bg_color = Color(0.18, 0.15, 0.08, 0.96)
	rh.border_color = Color(0.9, 0.8, 0.3, 0.8)
	reroll_card.mouse_entered.connect(func(): reroll_card.add_theme_stylebox_override("panel", rh))
	reroll_card.mouse_exited.connect(func(): reroll_card.add_theme_stylebox_override("panel", rs))
	choice_buttons.add_child(reroll_card)

func _on_reroll(cost: int) -> void:
	if not game_manager: return
	var p = game_manager.get("player")
	if not is_instance_valid(p): return
	if p.gold < cost:
		EventBus.emit_signal("pickup_float_text", p.global_position + Vector2(0, -40),
			"金币不足！需要 %d 金" % cost, Color(1.0, 0.3, 0.3))
		return
	p.gold -= cost
	_reroll_count += 1
	var meta = get_tree().root.find_child("MetaProgress", true, false)
	var max_choices := 5
	if meta and meta.get_upgrade_choices_count() == 4:
		max_choices = 6
	_pending_choices = UpgradeSystem.generate_choices(p, max_choices)
	_rebuild_choice_buttons()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_toggle_codex_panel()
		get_viewport().set_input_as_handled()
		return
	if not level_up_panel or not level_up_panel.visible: return
	for i in range(1, 7):
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
		_set_upgrade_panel_visible(false)
		var pick_hint = get_meta("pick_hint_label") if has_meta("pick_hint_label") else null
		if is_instance_valid(pick_hint): pick_hint.visible = false
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

# ── 终结技量表 / 消耗道具 / 深渊层数 HUD ──────────────────
var _ult_bar_r: ProgressBar = null
var _ult_bar_t: ProgressBar = null
var _ult_label_r: Label = null
var _ult_label_t: Label = null
var _consumable_label: Label = null
var _abyss_label: Label = null

# Boss 屏幕级血条
var _boss_name_label: Label = null
var _boss_hp_bar: ProgressBar = null
var _tracked_boss: Node = null

func _setup_gameplay_hud() -> void:
	# R: 深渊脉冲 bar (bottom-left)
	_ult_label_r = Label.new()
	_ult_label_r.text = "[R] 脉冲"
	_ult_label_r.add_theme_font_size_override("font_size", 10)
	_ult_label_r.add_theme_color_override("font_color", Color(0.5, 0.4, 0.2))
	_ult_label_r.anchor_left = 0.0; _ult_label_r.anchor_top = 1.0
	_ult_label_r.offset_left = 10; _ult_label_r.offset_top = -90
	_ult_label_r.offset_right = 90; _ult_label_r.offset_bottom = -77
	add_child(_ult_label_r)

	_ult_bar_r = ProgressBar.new()
	_ult_bar_r.min_value = 0; _ult_bar_r.max_value = 100; _ult_bar_r.value = 0
	_ult_bar_r.show_percentage = false
	_ult_bar_r.custom_minimum_size = Vector2(80, 10)
	_ult_bar_r.anchor_left = 0.0; _ult_bar_r.anchor_top = 1.0
	_ult_bar_r.offset_left = 10; _ult_bar_r.offset_top = -76
	_ult_bar_r.offset_right = 90; _ult_bar_r.offset_bottom = -66
	var sb_bg_r = StyleBoxFlat.new()
	sb_bg_r.bg_color = Color(0.15, 0.1, 0.05)
	sb_bg_r.corner_radius_top_left = 3; sb_bg_r.corner_radius_top_right = 3
	sb_bg_r.corner_radius_bottom_left = 3; sb_bg_r.corner_radius_bottom_right = 3
	_ult_bar_r.add_theme_stylebox_override("background", sb_bg_r)
	var sb_fill_r = StyleBoxFlat.new()
	sb_fill_r.bg_color = Color(0.6, 0.5, 0.15)
	sb_fill_r.corner_radius_top_left = 3; sb_fill_r.corner_radius_top_right = 3
	sb_fill_r.corner_radius_bottom_left = 3; sb_fill_r.corner_radius_bottom_right = 3
	_ult_bar_r.add_theme_stylebox_override("fill", sb_fill_r)
	add_child(_ult_bar_r)

	# T: 虚空崩裂 bar (next to R)
	_ult_label_t = Label.new()
	_ult_label_t.text = "[T] 黑洞"
	_ult_label_t.add_theme_font_size_override("font_size", 10)
	_ult_label_t.add_theme_color_override("font_color", Color(0.35, 0.2, 0.5))
	_ult_label_t.anchor_left = 0.0; _ult_label_t.anchor_top = 1.0
	_ult_label_t.offset_left = 100; _ult_label_t.offset_top = -90
	_ult_label_t.offset_right = 180; _ult_label_t.offset_bottom = -77
	add_child(_ult_label_t)

	_ult_bar_t = ProgressBar.new()
	_ult_bar_t.min_value = 0; _ult_bar_t.max_value = 130; _ult_bar_t.value = 0
	_ult_bar_t.show_percentage = false
	_ult_bar_t.custom_minimum_size = Vector2(80, 10)
	_ult_bar_t.anchor_left = 0.0; _ult_bar_t.anchor_top = 1.0
	_ult_bar_t.offset_left = 100; _ult_bar_t.offset_top = -76
	_ult_bar_t.offset_right = 180; _ult_bar_t.offset_bottom = -66
	var sb_bg_t = StyleBoxFlat.new()
	sb_bg_t.bg_color = Color(0.1, 0.05, 0.15)
	sb_bg_t.corner_radius_top_left = 3; sb_bg_t.corner_radius_top_right = 3
	sb_bg_t.corner_radius_bottom_left = 3; sb_bg_t.corner_radius_bottom_right = 3
	_ult_bar_t.add_theme_stylebox_override("background", sb_bg_t)
	var sb_fill_t = StyleBoxFlat.new()
	sb_fill_t.bg_color = Color(0.35, 0.15, 0.5)
	sb_fill_t.corner_radius_top_left = 3; sb_fill_t.corner_radius_top_right = 3
	sb_fill_t.corner_radius_bottom_left = 3; sb_fill_t.corner_radius_bottom_right = 3
	_ult_bar_t.add_theme_stylebox_override("fill", sb_fill_t)
	add_child(_ult_bar_t)

	# Consumable slots (bottom-center)
	_consumable_label = Label.new()
	_consumable_label.add_theme_font_size_override("font_size", 11)
	_consumable_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	_consumable_label.anchor_left = 0.5; _consumable_label.anchor_top = 1.0
	_consumable_label.offset_left = -120; _consumable_label.offset_top = -30
	_consumable_label.offset_right = 120; _consumable_label.offset_bottom = -8
	_consumable_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_consumable_label)

	# Abyss layer indicator (top-right)
	_abyss_label = Label.new()
	_abyss_label.add_theme_font_size_override("font_size", 11)
	_abyss_label.add_theme_color_override("font_color", Color(0.7, 0.3, 0.9))
	_abyss_label.anchor_left = 1.0; _abyss_label.anchor_top = 0.0
	_abyss_label.offset_left = -160; _abyss_label.offset_top = 35
	_abyss_label.offset_right = -10; _abyss_label.offset_bottom = 50
	_abyss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_abyss_label)

	# Boss HP bar (screen top, hidden by default)
	_boss_name_label = Label.new()
	_boss_name_label.add_theme_font_size_override("font_size", 16)
	_boss_name_label.add_theme_color_override("font_color", Color(0.8, 0.2, 1.0))
	_boss_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_boss_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_boss_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_label.anchor_left = 0.5; _boss_name_label.anchor_right = 0.5
	_boss_name_label.anchor_top = 0.0
	_boss_name_label.offset_left = -200; _boss_name_label.offset_right = 200
	_boss_name_label.offset_top = 6; _boss_name_label.offset_bottom = 26
	_boss_name_label.visible = false
	add_child(_boss_name_label)

	_boss_hp_bar = ProgressBar.new()
	_boss_hp_bar.min_value = 0; _boss_hp_bar.max_value = 100; _boss_hp_bar.value = 100
	_boss_hp_bar.show_percentage = false
	_boss_hp_bar.anchor_left = 0.15; _boss_hp_bar.anchor_right = 0.85
	_boss_hp_bar.anchor_top = 0.0
	_boss_hp_bar.offset_top = 28; _boss_hp_bar.offset_bottom = 42
	var boss_bg = StyleBoxFlat.new()
	boss_bg.bg_color = Color(0.15, 0.05, 0.15)
	boss_bg.corner_radius_top_left = 4; boss_bg.corner_radius_top_right = 4
	boss_bg.corner_radius_bottom_left = 4; boss_bg.corner_radius_bottom_right = 4
	_boss_hp_bar.add_theme_stylebox_override("background", boss_bg)
	var boss_fill = StyleBoxFlat.new()
	boss_fill.bg_color = Color(0.7, 0.15, 0.9)
	boss_fill.corner_radius_top_left = 4; boss_fill.corner_radius_top_right = 4
	boss_fill.corner_radius_bottom_left = 4; boss_fill.corner_radius_bottom_right = 4
	_boss_hp_bar.add_theme_stylebox_override("fill", boss_fill)
	_boss_hp_bar.visible = false
	add_child(_boss_hp_bar)

func _update_gameplay_hud() -> void:
	if not game_manager: return
	var p = game_manager.get("player")
	if not is_instance_valid(p): return
	# R bar
	if _ult_bar_r:
		_ult_bar_r.value = p.get("ult_charge_r") if p.get("ult_charge_r") != null else 0
		var sb_r = _ult_bar_r.get_theme_stylebox("fill")
		if sb_r is StyleBoxFlat:
			sb_r.bg_color = Color(1.0, 0.9, 0.2) if p.get("ult_ready_r") else Color(0.6, 0.5, 0.15)
	if _ult_label_r:
		if p.get("ult_ready_r"):
			_ult_label_r.text = "[R] 就绪!"
			_ult_label_r.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		else:
			_ult_label_r.text = "[R] 脉冲"
			_ult_label_r.add_theme_color_override("font_color", Color(0.5, 0.4, 0.2))
	# T bar
	if _ult_bar_t:
		_ult_bar_t.value = p.get("ult_charge_t") if p.get("ult_charge_t") != null else 0
		var sb_t = _ult_bar_t.get_theme_stylebox("fill")
		if sb_t is StyleBoxFlat:
			sb_t.bg_color = Color(0.7, 0.4, 1.0) if p.get("ult_ready_t") else Color(0.35, 0.15, 0.5)
	if _ult_label_t:
		if p.get("ult_ready_t"):
			_ult_label_t.text = "[T] 就绪!"
			_ult_label_t.add_theme_color_override("font_color", Color(0.7, 0.4, 1.0))
		else:
			_ult_label_t.text = "[T] 黑洞"
			_ult_label_t.add_theme_color_override("font_color", Color(0.35, 0.2, 0.5))
	# Consumables
	if _consumable_label and "consumables" in p:
		var parts = []
		for i in range(p.consumables.size()):
			parts.append("[%d] %s ×%d" % [i + 1, p.consumables[i]["name"], p.consumables[i]["count"]])
		_consumable_label.text = " | ".join(parts) if parts.size() > 0 else ""
	# Abyss layer
	if _abyss_label:
		var als = game_manager.get("abyss_layer_system")
		if als and is_instance_valid(als):
			var layer = als.get("current_layer") if als else 1
			_abyss_label.text = "深渊第 %d 层" % layer if layer > 1 else ""
	# Boss HP bar
	_update_boss_bar()

func _update_boss_bar() -> void:
	if not _boss_hp_bar: return
	if not is_instance_valid(_tracked_boss) or _tracked_boss.is_dead:
		_tracked_boss = null
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and e.data and e.data.exp_reward >= 50 and not e.is_dead:
				_tracked_boss = e
				break
	if _tracked_boss and is_instance_valid(_tracked_boss):
		_boss_name_label.visible = true
		_boss_hp_bar.visible = true
		_boss_name_label.text = _tracked_boss.data.display_name if _tracked_boss.data else "Boss"
		_boss_hp_bar.max_value = _tracked_boss.data.max_hp
		_boss_hp_bar.value = maxf(_tracked_boss.hp, 0)
	else:
		_boss_name_label.visible = false
		_boss_hp_bar.visible = false

func _setup_debug_hud() -> void:
	if not OS.is_debug_build():
		return
	_debug_label = Label.new()
	_debug_label.name = "DebugLabel"
	_debug_label.add_theme_font_size_override("font_size", 11)
	_debug_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5, 0.6))
	_debug_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_debug_label.offset_left  = -200
	_debug_label.offset_right = -8
	_debug_label.offset_top   = -80
	_debug_label.offset_bottom = -8
	_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_debug_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(_debug_label)

func _update_debug_hud() -> void:
	if not _debug_label: return
	var fps = Engine.get_frames_per_second()
	var node_count = get_tree().get_node_count()
	var enemy_count = get_tree().get_nodes_in_group("enemies").size()
	var proj_count  = get_tree().get_nodes_in_group("player_projectiles").size()
	_debug_label.text = "FPS: %d\nNodes: %d\nEnemies: %d\nProjectiles: %d" % [
		fps, node_count, enemy_count, proj_count
	]
	if fps < 30:
		_debug_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	elif fps < 50:
		_debug_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	else:
		_debug_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))

# ── 技能替换面板 ──────────────────────────────────────────
var _replace_panel: Control = null
var _replace_callback: Callable

func _show_replace_panel(new_skill_data, callback: Callable) -> void:
	_replace_callback = callback
	if _replace_panel and is_instance_valid(_replace_panel):
		_replace_panel.queue_free()
	_replace_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.12, 0.96)
	style.border_color = Color(0.6, 0.3, 0.9, 0.7)
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2; style.border_width_bottom = 2
	style.corner_radius_top_left = 12; style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12; style.corner_radius_bottom_right = 12
	style.content_margin_left = 16; style.content_margin_right = 16
	style.content_margin_top = 12; style.content_margin_bottom = 12
	_replace_panel.add_theme_stylebox_override("panel", style)
	_replace_panel.anchor_left = 0.5; _replace_panel.anchor_right = 0.5
	_replace_panel.anchor_top = 0.5; _replace_panel.anchor_bottom = 0.5
	_replace_panel.offset_left = -250; _replace_panel.offset_right = 250
	_replace_panel.offset_top = -120; _replace_panel.offset_bottom = 120
	add_child(_replace_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_replace_panel.add_child(vbox)

	var title = Label.new()
	title.text = "选择一个技能替换为: %s" % new_skill_data.display_name
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var hint = Label.new()
	hint.text = "被替换技能的残响将保留50%伤害效果"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	if not game_manager: return
	var p = game_manager.get("player")
	if not is_instance_valid(p): return

	for i in range(p.skills.size()):
		var sk = p.skills[i]
		var btn = Button.new()
		btn.text = "%s Lv%d" % [sk.data.display_name, sk.level]
		btn.custom_minimum_size = Vector2(100, 40)
		btn.add_theme_font_size_override("font_size", 11)
		var idx = i
		btn.pressed.connect(func():
			if _replace_callback.is_valid():
				_replace_callback.call(idx)
			if _replace_panel and is_instance_valid(_replace_panel):
				_replace_panel.queue_free()
				_replace_panel = null
		)
		hbox.add_child(btn)

# ── 协同触发全屏提示 ──────────────────────────────────────
func _on_synergy_activated(synergy: Dictionary) -> void:
	var banner = PanelContainer.new()
	var style = StyleBoxFlat.new()
	var syn_color: Color = synergy.get("color", Color(1.0, 0.8, 0.2))
	style.bg_color = Color(syn_color.r * 0.15, syn_color.g * 0.15, syn_color.b * 0.15, 0.92)
	style.border_color = syn_color
	style.border_width_top = 2; style.border_width_bottom = 2
	style.corner_radius_top_left = 6; style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6; style.corner_radius_bottom_right = 6
	style.content_margin_left = 20; style.content_margin_right = 20
	style.content_margin_top = 8; style.content_margin_bottom = 8
	banner.add_theme_stylebox_override("panel", style)
	banner.anchor_left = 0.5; banner.anchor_right = 0.5
	banner.anchor_top = 0.2
	banner.offset_left = -200; banner.offset_right = 200
	banner.offset_top = 0; banner.offset_bottom = 60
	banner.modulate.a = 0.0
	add_child(banner)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	banner.add_child(vb)

	var syn_name = Label.new()
	syn_name.text = synergy.get("name", "协同触发!")
	syn_name.add_theme_font_size_override("font_size", 20)
	syn_name.add_theme_color_override("font_color", syn_color)
	syn_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(syn_name)

	var syn_desc = Label.new()
	syn_desc.text = synergy.get("desc", "")
	syn_desc.add_theme_font_size_override("font_size", 11)
	syn_desc.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	syn_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	syn_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(syn_desc)

	var tw = banner.create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.5)
	tw.tween_property(banner, "modulate:a", 0.0, 0.5)
	tw.tween_callback(banner.queue_free)

	var snd = get_tree().get_first_node_in_group("sound_manager")
	if snd: snd.play_evolve()

# ── 元素共鸣提示 ──────────────────────────────────────
func _on_element_resonance(element: String, count: int, effects: Dictionary) -> void:
	var elem_colors := {
		"fire": Color(1.0, 0.4, 0.1), "ice": Color(0.3, 0.8, 1.0),
		"lightning": Color(1.0, 1.0, 0.3), "dark": Color(0.5, 0.2, 0.8),
		"holy": Color(1.0, 0.95, 0.7), "poison": Color(0.3, 0.9, 0.2),
		"arcane": Color(0.6, 0.3, 1.0),
	}
	var ec = elem_colors.get(element, Color(0.8, 0.8, 0.8))
	var tier = "共鸣" if count == 2 else "精通"
	var notice = Label.new()
	notice.text = "%s元素%s！" % [element.to_upper(), tier]
	notice.add_theme_font_size_override("font_size", 22)
	notice.add_theme_color_override("font_color", ec)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.anchor_left = 0.5; notice.anchor_right = 0.5
	notice.anchor_top = 0.15
	notice.offset_left = -200; notice.offset_right = 200
	notice.modulate.a = 0.0
	add_child(notice)
	var tw = notice.create_tween()
	tw.tween_property(notice, "modulate:a", 1.0, 0.15)
	tw.tween_property(notice, "offset_top", notice.offset_top - 20, 0.3)
	tw.tween_interval(2.0)
	tw.tween_property(notice, "modulate:a", 0.0, 0.4)
	tw.tween_callback(notice.queue_free)

# ── 章节变更提示 ──────────────────────────────────────
func _on_chapter_changed(chapter: int, title: String) -> void:
	var overlay = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var chapter_label = Label.new()
	chapter_label.text = "第 %d 幕" % chapter
	chapter_label.add_theme_font_size_override("font_size", 18)
	chapter_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.8))
	chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter_label.anchor_left = 0.5; chapter_label.anchor_right = 0.5
	chapter_label.anchor_top = 0.35
	chapter_label.offset_left = -200; chapter_label.offset_right = 200
	chapter_label.modulate.a = 0.0
	overlay.add_child(chapter_label)

	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.anchor_left = 0.5; title_label.anchor_right = 0.5
	title_label.anchor_top = 0.4
	title_label.offset_left = -300; title_label.offset_right = 300
	title_label.modulate.a = 0.0
	overlay.add_child(title_label)

	var tw = overlay.create_tween()
	tw.tween_property(overlay, "color:a", 0.4, 0.5)
	tw.parallel().tween_property(chapter_label, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(title_label, "modulate:a", 1.0, 0.5)
	tw.tween_interval(2.5)
	tw.tween_property(overlay, "color:a", 0.0, 0.8)
	tw.parallel().tween_property(chapter_label, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(title_label, "modulate:a", 0.0, 0.6)
	tw.tween_callback(overlay.queue_free)

# ── Build 图鉴发现提示 ──────────────────────────────────
func _on_build_discovered(build_id: String, build_name: String) -> void:
	var notice = Label.new()
	notice.text = "Build 发现: %s" % build_name
	notice.add_theme_font_size_override("font_size", 16)
	notice.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.anchor_left = 0.5; notice.anchor_right = 0.5
	notice.anchor_top = 0.25
	notice.offset_left = -200; notice.offset_right = 200
	notice.modulate.a = 0.0
	add_child(notice)
	var tw = notice.create_tween()
	tw.tween_property(notice, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.0)
	tw.tween_property(notice, "modulate:a", 0.0, 0.5)
	tw.tween_callback(notice.queue_free)

# ── Build 图鉴面板（Tab 键切换）──────────────────────────
var _codex_panel: PanelContainer = null

func _toggle_codex_panel() -> void:
	if _codex_panel and is_instance_valid(_codex_panel):
		_codex_panel.queue_free()
		_codex_panel = null
		return
	_build_codex_panel()

func _build_codex_panel() -> void:
	var codex_node = null
	if game_manager:
		codex_node = game_manager.get("_build_codex")
	if codex_node == null:
		var main = get_tree().root.find_child("Main", true, false)
		if main: codex_node = main.get("_build_codex")
	if codex_node == null: return

	var builds: Array = codex_node.get_all_builds()

	_codex_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.1, 0.95)
	style.border_color = Color(0.5, 0.4, 0.8, 0.6)
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2; style.border_width_bottom = 2
	style.corner_radius_top_left = 10; style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10; style.corner_radius_bottom_right = 10
	style.content_margin_left = 16; style.content_margin_right = 16
	style.content_margin_top = 12; style.content_margin_bottom = 12
	_codex_panel.add_theme_stylebox_override("panel", style)
	_codex_panel.anchor_left = 0.5; _codex_panel.anchor_right = 0.5
	_codex_panel.anchor_top = 0.5; _codex_panel.anchor_bottom = 0.5
	_codex_panel.offset_left = -220; _codex_panel.offset_right = 220
	_codex_panel.offset_top = -200; _codex_panel.offset_bottom = 200
	add_child(_codex_panel)

	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_codex_panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var title = Label.new()
	title.text = "Build 图鉴  [Tab 关闭]"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var discovered_count := 0
	for b in builds:
		if b.get("discovered", false): discovered_count += 1
	var progress_lbl = Label.new()
	progress_lbl.text = "已发现 %d / %d" % [discovered_count, builds.size()]
	progress_lbl.add_theme_font_size_override("font_size", 11)
	progress_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	progress_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(progress_lbl)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	vbox.add_child(sep)

	for b in builds:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vbox.add_child(row)

		var is_found: bool = b.get("discovered", false)

		var icon = Label.new()
		icon.text = "★" if is_found else "☆"
		icon.add_theme_font_size_override("font_size", 16)
		icon.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if is_found else Color(0.3, 0.3, 0.35))
		icon.custom_minimum_size = Vector2(22, 0)
		row.add_child(icon)

		var info_vbox = VBoxContainer.new()
		info_vbox.add_theme_constant_override("separation", 1)
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info_vbox)

		var name_lbl = Label.new()
		name_lbl.text = b["name"] if is_found else "???"
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7) if is_found else Color(0.4, 0.4, 0.45))
		info_vbox.add_child(name_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = b["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.65) if is_found else Color(0.3, 0.32, 0.35))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_vbox.add_child(desc_lbl)
