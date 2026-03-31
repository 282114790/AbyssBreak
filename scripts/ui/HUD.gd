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

func _show_upgrade_panel(choices: Array) -> void:
	if not level_up_panel or not choice_buttons: return
	_pending_choices = choices
	_picks_remaining = 2      # 5选2
	_first_pick_done = false
	level_up_panel.visible = true
	get_tree().paused = true
	var snd = get_tree().get_first_node_in_group("sound_manager")
	if snd: snd.play_level_up()
	_rebuild_choice_buttons()

func _rebuild_choice_buttons() -> void:
	for child in choice_buttons.get_children(): child.free()

	# 标题更新
	var ptitle = level_up_panel.get_child(0) if level_up_panel.get_child_count() > 0 else null
	if ptitle and ptitle is Label:
		if _picks_remaining == 2:
			ptitle.text = "⬆  选择升级（选 2 个）"
		else:
			ptitle.text = "⬆  再选 1 个"

	for i in range(_pending_choices.size()):
		var choice = _pending_choices[i]
		var is_curse = choice.get("type", "") == "curse"
		var btn = Button.new()
		btn.text = "[%d] %s\n%s" % [i+1, choice["display_name"], choice.get("description","")]
		btn.custom_minimum_size = Vector2(190, 120)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_on_choice_selected.bind(choice, i))

		var border_color = Color(1.0, 0.4, 0.1) if is_curse else Color(0.4, 0.6, 1.0)
		var bs = StyleBoxFlat.new()
		bs.bg_color = Color(0.25, 0.04, 0.04) if is_curse else Color(0.08, 0.08, 0.25)
		bs.border_width_left = 2; bs.border_width_right = 2
		bs.border_width_top = 2; bs.border_width_bottom = 2
		bs.border_color = border_color
		bs.corner_radius_top_left = 4; bs.corner_radius_top_right = 4
		bs.corner_radius_bottom_left = 4; bs.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", bs)
		var hs = bs.duplicate()
		hs.bg_color = Color(0.4, 0.1, 0.1) if is_curse else Color(0.15, 0.15, 0.4)
		hs.border_color = Color(1.0, 0.6, 0.2) if is_curse else Color(0.6, 0.8, 1.0)
		btn.add_theme_stylebox_override("hover", hs)

		# 图标
		var sid = choice.get("skill_id", choice.get("passive_id",""))
		var itex = null; var icol = -1
		if _sktex and _skill_icon_map.has(sid):
			itex = _sktex; icol = _skill_icon_map[sid]
		elif _pstex and _passive_icon_map.has(sid):
			itex = _pstex; icol = _passive_icon_map[sid]
		if itex and icol >= 0:
			var ir = TextureRect.new(); var at = AtlasTexture.new()
			at.atlas = itex; at.region = Rect2(icol*32, 0, 32, 32)
			ir.texture = at; ir.custom_minimum_size = Vector2(32,32)
			ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ir.set_anchors_preset(Control.PRESET_TOP_LEFT)
			ir.offset_left=6; ir.offset_top=6; ir.offset_right=38; ir.offset_bottom=38
			btn.add_child(ir)

		choice_buttons.add_child(btn)

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
		if level_up_panel: level_up_panel.visible = false
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
