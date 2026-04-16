# Main.gd
# 游戏主入口 - 程序化创建所有节点，无需美术资源直接运行
extends Node2D

const DifficultyDataScript = preload("res://scripts/systems/DifficultyData.gd")

# ── 子系统引用 ──
var player: CharacterBody2D
var wave_manager: Node
var camera: Camera2D
var hud_layer: CanvasLayer
var screen_shake: Node
var sound_mgr: Node
var meta_progress: Node
var result_screen: CanvasLayer
var unlock_screen: CanvasLayer
var char_registry: Node
var char_select_screen: CanvasLayer
var achievement_system: Node
var map_registry: Node
var abyss_layer_system: Node

# ── 经验宝石池 ──
var gem_pool: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_object_pool()
	_setup_meta_progress()
	_setup_char_registry()
	_setup_map_registry()
	_setup_achievement_system()
	_connect_event_bus()
	_setup_camera()
	_setup_result_screen()
	_setup_sound_manager()
	_show_char_select()

func _setup_object_pool() -> void:
	var pool = Node.new()
	pool.set_script(load("res://scripts/systems/ObjectPool.gd"))
	pool.name = "ObjectPool"
	add_child(pool)

# ────────────────────────────────────────
# 成就系统
# ────────────────────────────────────────
func _setup_achievement_system() -> void:
	achievement_system = Node.new()
	achievement_system.set_script(load("res://scripts/systems/AchievementSystem.gd"))
	achievement_system.name = "AchievementSystem"
	add_child(achievement_system)
	achievement_system.set_meta_progress(meta_progress)

# ────────────────────────────────────────
# 事件总线连接
# ────────────────────────────────────────
func _connect_event_bus() -> void:
	EventBus.player_died.connect(_on_player_died)
	EventBus.upgrade_chosen.connect(_on_upgrade_chosen)
	EventBus.upgrade_panel_closed.connect(_on_upgrade_panel_closed)
	EventBus.show_level_up_panel.connect(_on_show_level_up)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.wave_changed.connect(_on_wave_changed_relic)
	EventBus.relic_drop_touched.connect(_on_relic_drop_touched)
	EventBus.pickup_float_text.connect(_on_pickup_float_text)

# ────────────────────────────────────────
# 摄像机
# ────────────────────────────────────────
func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.position = Vector2(640, 360)
	camera.zoom = Vector2(1, 1)
	add_child(camera)
	camera.make_current()
	# 创建屏幕震动节点
	screen_shake = Node.new()
	screen_shake.set_script(load("res://scripts/systems/ScreenShake.gd"))
	screen_shake.name = "ScreenShake"
	add_child(screen_shake)
	screen_shake.camera = camera

# ────────────────────────────────────────
# 背景（程序生成网格）
# ────────────────────────────────────────
func _setup_background() -> void:
	var map_data = map_registry.get_map(map_registry.selected_id) if map_registry else null

	var cm := CanvasModulate.new()
	cm.name = "CanvasModulate"
	cm.color = map_data.canvas_modulate_color if map_data else Color(0.75, 0.70, 0.72)
	add_child(cm)

	var bg_script_path := "res://scripts/systems/TileMapBackgroundV2.gd"
	if map_data:
		bg_script_path = map_data.bg_script_path

	var bg = Node2D.new()
	bg.set_script(load(bg_script_path))
	bg.name = "TileMapBackground"
	if map_data and "bg_theme" in map_data and map_data.bg_theme != "":
		bg.map_theme = map_data.bg_theme
	add_child(bg)

	var half : float = map_data.world_half_size if map_data else 3000.0
	var border_color = Color(0.9, 0.2, 0.2, 0.8)
	var border_segs = [
		[Vector2(-half, -half), Vector2(half, -half)],
		[Vector2(half, -half), Vector2(half, half)],
		[Vector2(half, half), Vector2(-half, half)],
		[Vector2(-half, half), Vector2(-half, -half)]
	]
	for seg in border_segs:
		var line = Line2D.new()
		line.add_point(seg[0]); line.add_point(seg[1])
		line.default_color = border_color
		line.width = 3.0; line.z_index = -7
		add_child(line)

# ────────────────────────────────────────
# 玩家
# ────────────────────────────────────────
func _setup_player() -> void:
	player = CharacterBody2D.new()
	player.set_script(load("res://scripts/player/Player.gd"))
	player.name = "Player"
	player.position = Vector2(0, 0)
	# 传入选中的角色数据
	if char_registry:
		var char_data = char_registry.get_character(char_registry.selected_id)
		if char_data:
			player.set_meta("char_data", char_data)
	add_child(player)

# ────────────────────────────────────────
# 波次管理器
# ────────────────────────────────────────
func _setup_wave_manager() -> void:
	wave_manager = Node.new()
	wave_manager.set_script(load("res://scripts/systems/WaveManager.gd"))
	wave_manager.name = "WaveManager"
	add_child(wave_manager)

# ────────────────────────────────────────
# 音效管理器
# ────────────────────────────────────────
func _setup_sound_manager() -> void:
	sound_mgr = Node.new()
	sound_mgr.set_script(load("res://scripts/systems/SoundManager.gd"))
	sound_mgr.name = "SoundManager"
	add_child(sound_mgr)

# ────────────────────────────────────────
# HUD
# ────────────────────────────────────────
func _setup_meta_progress() -> void:
	meta_progress = Node.new()
	meta_progress.set_script(load("res://scripts/systems/MetaProgress.gd"))
	meta_progress.name = "MetaProgress"
	add_child(meta_progress)

func _setup_result_screen() -> void:
	result_screen = CanvasLayer.new()
	result_screen.set_script(load("res://scripts/ui/RunResultScreen.gd"))
	result_screen.name = "RunResultScreen"
	result_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(result_screen)

	unlock_screen = CanvasLayer.new()
	unlock_screen.set_script(load("res://scripts/ui/UnlockScreen.gd"))
	unlock_screen.name = "UnlockScreen"
	unlock_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(unlock_screen)

func _setup_char_registry() -> void:
	char_registry = Node.new()
	char_registry.set_script(load("res://scripts/player/CharacterRegistry.gd"))
	char_registry.name = "CharacterRegistry"
	add_child(char_registry)

func _setup_map_registry() -> void:
	map_registry = Node.new()
	map_registry.set_script(load("res://scripts/systems/MapRegistry.gd"))
	map_registry.name = "MapRegistry"
	add_child(map_registry)

func _show_char_select() -> void:
	char_select_screen = CanvasLayer.new()
	char_select_screen.set_script(load("res://scripts/ui/CharacterSelectScreen.gd"))
	char_select_screen.name = "CharacterSelectScreen"
	char_select_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(char_select_screen)
	await get_tree().process_frame
	char_select_screen.show_screen(char_registry, meta_progress)
	char_select_screen.character_selected.connect(_on_character_selected)
	char_select_screen.daily_challenge_requested.connect(_on_daily_challenge_requested)

func _on_character_selected(char_id: String) -> void:
	char_registry.selected_id = char_id
	char_select_screen.queue_free()
	_show_map_select()

var map_select_screen: CanvasLayer = null

func _show_map_select() -> void:
	map_select_screen = CanvasLayer.new()
	map_select_screen.set_script(load("res://scripts/ui/MapSelectScreen.gd"))
	map_select_screen.name = "MapSelectScreen"
	map_select_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(map_select_screen)
	await get_tree().process_frame
	map_select_screen.show_screen(map_registry)
	map_select_screen.map_selected.connect(_on_map_selected)

func _on_map_selected(map_id: String) -> void:
	map_registry.selected_id = map_id
	map_select_screen.queue_free()
	_show_difficulty_select()

var difficulty_screen: CanvasLayer = null
var current_difficulty = null  # DifficultyData
var daily_challenge: Node = null       # DailyChallenge 节点
var daily_modifier_type: int = -1      # -1=无modifier，0/1/2=有modifier

func _show_difficulty_select() -> void:
	difficulty_screen = CanvasLayer.new()
	difficulty_screen.set_script(load("res://scripts/ui/DifficultySelect.gd"))
	difficulty_screen.name = "DifficultySelect"
	difficulty_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(difficulty_screen)
	await get_tree().process_frame
	difficulty_screen.show_screen()
	difficulty_screen.difficulty_selected.connect(_on_difficulty_selected)

func _on_difficulty_selected(diff) -> void:
	current_difficulty = diff
	difficulty_screen.queue_free()
	_show_route_select()

var route_screen: CanvasLayer = null
var selected_route: Dictionary = {}

func _show_route_select() -> void:
	route_screen = CanvasLayer.new()
	route_screen.set_script(load("res://scripts/ui/RouteSelectScreen.gd"))
	route_screen.name = "RouteSelectScreen"
	route_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(route_screen)
	await get_tree().process_frame
	route_screen.show_screen()
	route_screen.route_selected.connect(_on_route_selected)

func _on_route_selected(route: Dictionary) -> void:
	selected_route = route
	route_screen.queue_free()
	_start_game()

func _on_daily_challenge_requested() -> void:
	# 获取每日挑战配置，直接开始游戏
	char_select_screen.queue_free()

	var dc_script = load("res://scripts/systems/DailyChallenge.gd")
	daily_challenge = Node.new()
	daily_challenge.set_script(dc_script)
	daily_challenge.name = "DailyChallenge"
	add_child(daily_challenge)

	var cfg = daily_challenge.get_challenge_config()
	daily_modifier_type = cfg.get("modifier_type", -1)

	# 设置角色
	char_registry.selected_id = cfg.get("char_id", "mage")

	# 构建难度（复用 DifficultySelect 的逻辑）
	var DD = load("res://scripts/systems/DifficultyData.gd")
	var diff_map := {
		"normal": [1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
		"hard":   [1.5, 1.3, 1.1, 1.3, 1.2, 1.5],
		"abyss":  [2.5, 2.0, 1.2, 1.8, 1.5, 2.0],
	}
	var diff_names := {"normal":"普通", "hard":"困难", "abyss":"深渊"}
	var diff_id = cfg.get("difficulty_id", "normal")
	var d_params = diff_map.get(diff_id, diff_map["normal"])
	var d = DD.new()
	d.id = diff_id
	d.display_name = diff_names.get(diff_id, "普通")
	d.enemy_hp_mult = d_params[0]; d.enemy_dmg_mult = d_params[1]
	d.enemy_speed_mult = d_params[2]; d.enemy_count_mult = d_params[3]
	d.exp_mult = d_params[4]; d.soul_stone_mult = d_params[5]
	current_difficulty = d

	_start_game()
	# 开始后应用modifier（需等玩家完全初始化）
	await get_tree().process_frame
	await get_tree().process_frame
	if daily_modifier_type >= 0 and is_instance_valid(player):
		daily_challenge.apply_modifier(daily_modifier_type, player, wave_manager)

func _start_game() -> void:
	_setup_background()
	_setup_player()
	_setup_wave_manager()
	_setup_hud()
	_register_demo_content()
	_setup_debug_skill_panel()
	_setup_synergy_system()
	_setup_merchant()
	_setup_random_events()
	_setup_tutorial()
	_setup_drop_system()
	if current_difficulty and wave_manager:
		wave_manager.set_meta("difficulty", current_difficulty)
		set_meta("current_difficulty_mult", current_difficulty.soul_stone_mult)
		set_meta("difficulty_exp_mult", current_difficulty.exp_mult)
		wave_manager.enemy_count_mult = current_difficulty.enemy_count_mult
	_apply_route_effects()
	_setup_abyss_layer()
	wave_manager.start(player)

func _apply_route_effects() -> void:
	if selected_route.is_empty():
		return
	# Merchant interval
	if selected_route.has("merchant_interval"):
		var ms = get_tree().root.find_child("MerchantSystem", true, false)
		if ms:
			ms.set("APPEAR_EVERY_WAVES", selected_route["merchant_interval"])
	# Starting gold bonus from soul_start_mult
	if selected_route.has("soul_start_mult") and is_instance_valid(player):
		player.gold += int(20 * selected_route["soul_start_mult"])
	# Enemy HP mult (applied on top of difficulty)
	if selected_route.has("enemy_hp_mult") and wave_manager and wave_manager.has_meta("difficulty"):
		var diff = wave_manager.get_meta("difficulty")
		diff.enemy_hp_mult *= selected_route["enemy_hp_mult"]
	# Store route data for other systems to read
	set_meta("route_relic_bonus", selected_route.get("relic_bonus", 1.0))
	set_meta("route_exp_bonus", selected_route.get("exp_bonus", 1.0))
	set_meta("route_soul_mult", selected_route.get("soul_mult", 1.0))

func _setup_merchant() -> void:
	var m = Node.new()
	m.set_script(load("res://scripts/systems/MerchantSystem.gd"))
	m.name = "MerchantSystem"
	add_child(m)

func _setup_abyss_layer() -> void:
	abyss_layer_system = Node.new()
	abyss_layer_system.set_script(load("res://scripts/systems/AbyssLayerSystem.gd"))
	abyss_layer_system.name = "AbyssLayerSystem"
	add_child(abyss_layer_system)
	if wave_manager:
		abyss_layer_system.apply_to_wave_manager(wave_manager)
	if is_instance_valid(player) and abyss_layer_system.has_method("apply_initial_effects"):
		abyss_layer_system.apply_initial_effects(player)

func _setup_random_events() -> void:
	var r = Node.new()
	r.set_script(load("res://scripts/systems/RandomEventSystem.gd"))
	r.name = "RandomEventSystem"
	add_child(r)

func _setup_tutorial() -> void:
	var t = Node.new()
	t.set_script(load("res://scripts/systems/TutorialSystem.gd"))
	t.name = "TutorialSystem"
	add_child(t)

func _setup_drop_system() -> void:
	var ds = Node.new()
	ds.set_script(load("res://scripts/systems/DropSystem.gd"))
	ds.name = "DropSystem"
	add_child(ds)

var synergy_system: Node = null
var _build_codex: Node = null

func _setup_synergy_system() -> void:
	synergy_system = Node.new()
	synergy_system.set_script(load("res://scripts/systems/SynergySystem.gd"))
	synergy_system.name = "SynergySystem"
	add_child(synergy_system)
	EventBus.synergy_activated.connect(_on_synergy_activated)
	_build_codex = Node.new()
	_build_codex.set_script(load("res://scripts/systems/BuildCodex.gd"))
	_build_codex.name = "BuildCodex"
	add_child(_build_codex)

func _on_synergy_activated(syn: Dictionary) -> void:
	if not hud_layer: return
	var lbl = Label.new()
	lbl.text = "✨ 协同激活：%s\n%s" % [syn["name"], syn["desc"]]
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", syn.get("color", Color.WHITE))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.anchor_left = 0.5; lbl.anchor_right = 0.5
	lbl.anchor_top = 0.7; lbl.anchor_bottom = 0.7
	lbl.offset_left = -150; lbl.offset_right = 150; lbl.offset_top = -15; lbl.offset_bottom = 15
	hud_layer.add_child(lbl)
	var t = lbl.create_tween()
	t.tween_interval(2.0)
	t.tween_property(lbl, "modulate:a", 0.0, 0.5)
	t.tween_callback(lbl.queue_free)

func _make_bar_style(color: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 2; sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2; sb.corner_radius_bottom_right = 2
	sb.content_margin_top = 0; sb.content_margin_bottom = 0
	sb.content_margin_left = 0; sb.content_margin_right = 0
	return sb

func _setup_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.set_script(load("res://scripts/ui/HUD.gd"))
	hud_layer.name = "HUD"
	hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时HUD仍然响应
	add_child(hud_layer)  # 先加入树，_ready 会执行连接信号

	# ═══ 顶部信息栏 — 容器布局，自动垂直居中 ═══
	var top_bg = ColorRect.new()
	top_bg.name = "TopBarBG"
	top_bg.color = Color(0.0, 0.0, 0.0, 0.45)
	top_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bg.offset_bottom = 78
	top_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(top_bg)

	# 左侧面板：VBox 管理三行
	var left_panel = VBoxContainer.new()
	left_panel.position = Vector2(10, 4)
	left_panel.size = Vector2(360, 70)
	left_panel.add_theme_constant_override("separation", 3)
	left_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(left_panel)

	# ── 第一行：HP ──
	var hp_row = HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 6)
	hp_row.custom_minimum_size = Vector2(0, 22)
	hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_panel.add_child(hp_row)

	var hp_icon = Label.new()
	hp_icon.text = "❤"
	hp_icon.add_theme_font_size_override("font_size", 15)
	hp_icon.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	hp_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_row.add_child(hp_icon)

	var hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(160, 16)
	hp_bar.max_value = 100; hp_bar.value = 100
	hp_bar.show_percentage = false
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_row.add_child(hp_bar)
	hud_layer.hp_bar = hp_bar
	var hp_bg_sb = _make_bar_style(Color(0.15, 0.05, 0.05, 0.9))
	var hp_fill_sb = _make_bar_style(Color(0.85, 0.2, 0.2))
	hp_bar.add_theme_stylebox_override("background", hp_bg_sb)
	hp_bar.add_theme_stylebox_override("fill", hp_fill_sb)

	var hp_label = Label.new()
	hp_label.text = "100 / 100"
	hp_label.add_theme_font_size_override("font_size", 14)
	hp_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
	hp_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_row.add_child(hp_label)
	hud_layer.hp_label = hp_label

	# ── 第二行：EXP ──
	var exp_row = HBoxContainer.new()
	exp_row.add_theme_constant_override("separation", 6)
	exp_row.custom_minimum_size = Vector2(0, 22)
	exp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_panel.add_child(exp_row)

	var exp_icon = Label.new()
	exp_icon.text = "⭐"
	exp_icon.add_theme_font_size_override("font_size", 15)
	exp_icon.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	exp_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	exp_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	exp_row.add_child(exp_icon)

	var exp_bar = ProgressBar.new()
	exp_bar.custom_minimum_size = Vector2(160, 16)
	exp_bar.max_value = 100; exp_bar.value = 0
	exp_bar.show_percentage = false
	exp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	exp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	exp_row.add_child(exp_bar)
	hud_layer.exp_bar = exp_bar
	var exp_bg_sb = _make_bar_style(Color(0.12, 0.1, 0.02, 0.9))
	var exp_fill_sb = _make_bar_style(Color(0.9, 0.8, 0.15))
	exp_bar.add_theme_stylebox_override("background", exp_bg_sb)
	exp_bar.add_theme_stylebox_override("fill", exp_fill_sb)

	var lv_label = Label.new()
	lv_label.text = "Lv.1"
	lv_label.add_theme_font_size_override("font_size", 14)
	lv_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
	lv_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lv_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	exp_row.add_child(lv_label)
	hud_layer.level_label = lv_label

	# ── 第三行：波次 ──
	var wave_lbl = Label.new()
	wave_lbl.text = "🌊 第 1 波"
	wave_lbl.add_theme_font_size_override("font_size", 15)
	wave_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	wave_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_panel.add_child(wave_lbl)
	hud_layer.wave_label = wave_lbl

	# ── 中部区：计时器 ──
	var timer_lbl = Label.new()
	timer_lbl.name = "TimerLabel"
	timer_lbl.text = "⏱ 00:00"
	timer_lbl.add_theme_font_size_override("font_size", 24)
	timer_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	timer_lbl.anchor_left = 0.5; timer_lbl.anchor_right = 0.5
	timer_lbl.offset_left = -60; timer_lbl.offset_right = 60
	timer_lbl.offset_top = 6; timer_lbl.offset_bottom = 38
	timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(timer_lbl)
	hud_layer.timer_label = timer_lbl

	# ── 右侧区：金币 + 魂石 ──
	var gold_lbl = Label.new()
	gold_lbl.name = "GoldLabel"
	gold_lbl.text = "💰 金币：0"
	gold_lbl.add_theme_font_size_override("font_size", 15)
	gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	gold_lbl.anchor_left = 1.0; gold_lbl.anchor_right = 1.0
	gold_lbl.offset_left = -180; gold_lbl.offset_right = -10
	gold_lbl.offset_top = 8; gold_lbl.offset_bottom = 30
	gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(gold_lbl)
	hud_layer.set_meta("gold_label", gold_lbl)

	var soul_lbl = Label.new()
	soul_lbl.name = "SoulStoneLabel"
	soul_lbl.text = "💎 魂石：%d" % (meta_progress.soul_stones if meta_progress else 0)
	soul_lbl.add_theme_font_size_override("font_size", 15)
	soul_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	soul_lbl.anchor_left = 1.0; soul_lbl.anchor_right = 1.0
	soul_lbl.offset_left = -180; soul_lbl.offset_right = -10
	soul_lbl.offset_top = 34; soul_lbl.offset_bottom = 56
	soul_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	soul_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(soul_lbl)
	hud_layer.set_meta("soul_label", soul_lbl)

	# ── 升级面板：无标题栏，卡片即内容 ──────────────────────────
	const PANEL_W := 1100
	const PANEL_H := 220
	const VP_W   := 1280
	const VP_H   := 720

	var overlay = ColorRect.new()
	overlay.name = "UpgradeOverlay"
	overlay.visible = false
	overlay.position = Vector2(0, 0)
	overlay.size = Vector2(VP_W, VP_H)
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_layer.add_child(overlay)

	var panel = Panel.new()
	panel.name = "UpgradePanel"
	panel.visible = false
	panel.position = Vector2((VP_W - PANEL_W) / 2.0, (VP_H - PANEL_H) / 2.0)
	panel.size = Vector2(PANEL_W, PANEL_H)
	panel.clip_contents = true
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.08, 0.0)
	style.border_width_left = 0; style.border_width_right = 0
	style.border_width_top = 0; style.border_width_bottom = 0
	panel.add_theme_stylebox_override("panel", style)
	hud_layer.add_child(panel)

	var choices = HBoxContainer.new()
	choices.name = "ChoiceButtons"
	choices.position = Vector2(0, 0)
	choices.size = Vector2(PANEL_W, PANEL_H)
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 8)
	panel.add_child(choices)

	hud_layer.level_up_panel = panel
	hud_layer.set_meta("upgrade_overlay", overlay)
	hud_layer.choice_buttons = choices

	# ── 技能栏（底部居中）──
	var skill_bar = HBoxContainer.new()
	skill_bar.anchor_left = 0.5; skill_bar.anchor_right = 0.5
	skill_bar.anchor_top = 1.0; skill_bar.anchor_bottom = 1.0
	skill_bar.offset_left = -210; skill_bar.offset_right = 210
	skill_bar.offset_top = -84; skill_bar.offset_bottom = -4
	skill_bar.add_theme_constant_override("separation", 6)
	skill_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	hud_layer.add_child(skill_bar)
	hud_layer.set_meta("skill_bar", skill_bar)

	# 技能 Tooltip（悬停时显示详细信息）
	var tooltip_panel = PanelContainer.new()
	tooltip_panel.name = "SkillTooltip"
	tooltip_panel.visible = false
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.z_index = 50
	var tp_style = StyleBoxFlat.new()
	tp_style.bg_color = Color(0.04, 0.04, 0.12, 0.94)
	tp_style.border_color = Color(0.45, 0.65, 1.0, 0.6)
	tp_style.border_width_left = 1; tp_style.border_width_right = 1
	tp_style.border_width_top = 1; tp_style.border_width_bottom = 1
	tp_style.corner_radius_top_left = 6; tp_style.corner_radius_top_right = 6
	tp_style.corner_radius_bottom_left = 6; tp_style.corner_radius_bottom_right = 6
	tp_style.content_margin_left = 10; tp_style.content_margin_right = 10
	tp_style.content_margin_top = 8; tp_style.content_margin_bottom = 8
	tooltip_panel.add_theme_stylebox_override("panel", tp_style)
	hud_layer.add_child(tooltip_panel)
	hud_layer.set_meta("skill_tooltip", tooltip_panel)

	var tp_vbox = VBoxContainer.new()
	tp_vbox.name = "TooltipVBox"
	tp_vbox.add_theme_constant_override("separation", 3)
	tp_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.add_child(tp_vbox)

	# 注入 game_manager 引用（用于计时）
	hud_layer.game_manager = self

	# ── 难度徽章（计时器下方，小号、半透明，背景信息不抢焦点）──
	var diff_badge = Label.new()
	diff_badge.name = "DifficultyBadge"
	diff_badge.text = "🟢 普通"
	diff_badge.add_theme_font_size_override("font_size", 10)
	diff_badge.modulate = Color(1, 1, 1, 0.7)
	diff_badge.anchor_left = 0.5; diff_badge.anchor_right = 0.5
	diff_badge.offset_left = -50; diff_badge.offset_right = 50
	diff_badge.offset_top = 38; diff_badge.offset_bottom = 56
	diff_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(diff_badge)
	hud_layer.difficulty_badge = diff_badge

# ────────────────────────────────────────
# 注册演示内容（初始一把技能 + 被动）
# ────────────────────────────────────────
func _register_demo_content() -> void:
	# ── 技能注册 ──

	# 火焰术
	var fireball_data = load("res://scripts/skills/SkillData.gd").new()
	fireball_data.id = "fireball"
	fireball_data.display_name = "🔥 火焰术"
	fireball_data.description = "向最近敌人发射追踪火球，范围爆炸"
	fireball_data.max_level = 5
	fireball_data.cooldown = 0.6
	fireball_data.scene_path = "res://scripts/skills/SkillFireball.gd"
	fireball_data.damage = 25.0
	fireball_data.speed = 400.0
	fireball_data.level_up_damage = 15.0
	fireball_data.level_up_cooldown = -0.08
	fireball_data.evolve_passive_id = "power_ring"
	fireball_data.evolved_skill_id = "fireball_evolved"
	fireball_data.element = SkillData.Element.FIRE
	UpgradeSystem.available_skills.append(fireball_data)

	# 元素壁垒
	var orbital_data = load("res://scripts/skills/SkillData.gd").new()
	orbital_data.id = "orbital"
	orbital_data.display_name = "🛡 元素壁垒"
	orbital_data.description = "环形魔法壁垒围绕旋转，撞击敌人造成伤害和击退，并为你叠加减伤护盾"
	orbital_data.max_level = 5
	orbital_data.cooldown = 0.0
	orbital_data.scene_path = "res://scripts/skills/SkillOrbital.gd"
	orbital_data.damage = 15.0
	orbital_data.level_up_damage = 10.0
	orbital_data.evolve_passive_id = "boots"
	orbital_data.evolved_skill_id = "orbital_evolved"
	orbital_data.element = SkillData.Element.ARCANE
	UpgradeSystem.available_skills.append(orbital_data)

	# 雷击链
	var lightning_data = load("res://scripts/skills/SkillData.gd").new()
	lightning_data.id = "lightning"
	lightning_data.display_name = "⚡ 雷击链"
	lightning_data.description = "闪电在敌人间弹跳3次"
	lightning_data.max_level = 5
	lightning_data.cooldown = 1.0
	lightning_data.scene_path = "res://scripts/skills/SkillLightning.gd"
	lightning_data.damage = 25.0
	lightning_data.level_up_damage = 12.0
	lightning_data.evolve_passive_id = "mana_crystal"
	lightning_data.evolved_skill_id = "lightning_evolved"
	lightning_data.element = SkillData.Element.LIGHTNING
	UpgradeSystem.available_skills.append(lightning_data)

	# 冰刃术
	var iceblade_data = load("res://scripts/skills/SkillData.gd").new()
	iceblade_data.id = "iceblade"
	iceblade_data.display_name = "❄ 冰刃术"
	iceblade_data.description = "直线冰刃穿透所有敌人"
	iceblade_data.max_level = 5
	iceblade_data.cooldown = 0.8
	iceblade_data.scene_path = "res://scripts/skills/SkillIceBlade.gd"
	iceblade_data.damage = 30.0
	iceblade_data.level_up_damage = 18.0
	iceblade_data.evolve_passive_id = "iron_heart"
	iceblade_data.evolved_skill_id = "iceblade_evolved"
	iceblade_data.element = SkillData.Element.ICE
	UpgradeSystem.available_skills.append(iceblade_data)

	# 寒冰领域
	var frostzone_data = load("res://scripts/skills/SkillData.gd").new()
	frostzone_data.id = "frostzone"
	frostzone_data.display_name = "🌀 寒冰领域"
	frostzone_data.description = "范围内敌人减速50%并持续受伤"
	frostzone_data.max_level = 5
	frostzone_data.cooldown = 0.3
	frostzone_data.scene_path = "res://scripts/skills/SkillFrostZone.gd"
	frostzone_data.damage = 10.0
	frostzone_data.level_up_damage = 8.0
	frostzone_data.element = SkillData.Element.ICE
	UpgradeSystem.available_skills.append(frostzone_data)

	# 爆裂符文
	var runeblast_data = load("res://scripts/skills/SkillData.gd").new()
	runeblast_data.id = "runeblast"
	runeblast_data.display_name = "💥 爆裂符文"
	runeblast_data.description = "在敌人脚下放置符文，1.5秒后爆炸"
	runeblast_data.max_level = 5
	runeblast_data.cooldown = 1.5
	runeblast_data.scene_path = "res://scripts/skills/SkillRuneBlast.gd"
	runeblast_data.damage = 50.0
	runeblast_data.level_up_damage = 25.0
	runeblast_data.element = SkillData.Element.ARCANE
	UpgradeSystem.available_skills.append(runeblast_data)

	# ── 被动注册 ──

	# 移速被动
	var speed_passive = load("res://scripts/systems/PassiveData.gd").new()
	speed_passive.id = "boots"
	speed_passive.display_name = "疾风之靴"
	speed_passive.description = "移动速度 +20%"
	speed_passive.max_level = 5
	speed_passive.move_speed_bonus = 0.20
	UpgradeSystem.available_passives.append(speed_passive)

	# 攻击力被动
	var dmg_passive = load("res://scripts/systems/PassiveData.gd").new()
	dmg_passive.id = "power_ring"
	dmg_passive.display_name = "力量戒指"
	dmg_passive.description = "技能伤害 +25%"
	dmg_passive.max_level = 5
	dmg_passive.damage_bonus = 0.25
	UpgradeSystem.available_passives.append(dmg_passive)

	# 生命值被动
	var hp_passive = load("res://scripts/systems/PassiveData.gd").new()
	hp_passive.id = "iron_heart"
	hp_passive.display_name = "钢铁之心"
	hp_passive.description = "最大生命值 +30"
	hp_passive.max_level = 5
	hp_passive.hp_bonus = 30.0
	UpgradeSystem.available_passives.append(hp_passive)

	# 圣光波
	var holywave_data = load("res://scripts/skills/SkillData.gd").new()
	holywave_data.id = "holywave"
	holywave_data.display_name = "✨ 圣光波"
	holywave_data.description = "向8方向发射扩散光波，覆盖全屏"
	holywave_data.max_level = 5
	holywave_data.cooldown = 5.0
	holywave_data.level_up_cooldown = -0.2
	holywave_data.scene_path = "res://scripts/skills/SkillHolyWave.gd"
	holywave_data.damage = 15.0
	holywave_data.level_up_damage = 8.0
	holywave_data.element = SkillData.Element.HOLY
	UpgradeSystem.available_skills.append(holywave_data)

	# ── 新增技能 ──

	# 毒雾领域
	var poison_data = load("res://scripts/skills/SkillData.gd").new()
	poison_data.id = "poison_cloud"
	poison_data.display_name = "☠ 毒雾领域"
	poison_data.description = "周身毒雾持续中毒敌人，升级扩大范围"
	poison_data.max_level = 5
	poison_data.cooldown = 0.0
	poison_data.scene_path = "res://scripts/skills/SkillPoisonCloud.gd"
	poison_data.damage = 8.0
	poison_data.level_up_damage = 5.0
	poison_data.evolve_passive_id = "toxic_vial"
	poison_data.evolved_skill_id = "poison_evolved"
	poison_data.element = SkillData.Element.POISON
	UpgradeSystem.available_skills.append(poison_data)

	# 虚空裂缝
	var void_data = load("res://scripts/skills/SkillData.gd").new()
	void_data.id = "void_rift"
	void_data.display_name = "🌑 虚空裂缝"
	void_data.description = "生成黑洞吸引并持续伤害周围敌人"
	void_data.max_level = 5
	void_data.cooldown = 6.0
	void_data.level_up_cooldown = -0.3
	void_data.scene_path = "res://scripts/skills/SkillVoidRift.gd"
	void_data.damage = 20.0
	void_data.level_up_damage = 10.0
	void_data.is_active = true
	void_data.active_slot = 0
	void_data.element = SkillData.Element.DARK
	UpgradeSystem.available_skills.append(void_data)

	# 奥术弹幕
	var orb_data = load("res://scripts/skills/SkillData.gd").new()
	orb_data.id = "arcane_orb"
	orb_data.display_name = "💠 奥术弹幕"
	orb_data.description = "多颗弹幕公转后向外飞射，升级增加数量"
	orb_data.max_level = 5
	orb_data.cooldown = 2.5
	orb_data.level_up_cooldown = -0.2
	orb_data.scene_path = "res://scripts/skills/SkillArcaneOrb.gd"
	orb_data.damage = 22.0
	orb_data.level_up_damage = 12.0
	orb_data.evolve_passive_id = "power_ring"
	orb_data.evolved_skill_id = "arcane_evolved"
	orb_data.element = SkillData.Element.ARCANE
	UpgradeSystem.available_skills.append(orb_data)

	# 血月新星
	var nova_data = load("res://scripts/skills/SkillData.gd").new()
	nova_data.id = "blood_nova"
	nova_data.display_name = "🩸 血月新星"
	nova_data.description = "消耗5%HP释放血色冲击波，HP越低伤害越高"
	nova_data.max_level = 5
	nova_data.cooldown = 3.5
	nova_data.level_up_cooldown = -0.2
	nova_data.scene_path = "res://scripts/skills/SkillBloodNova.gd"
	nova_data.damage = 35.0
	nova_data.level_up_damage = 18.0
	nova_data.evolve_passive_id = "shadow_cloak"
	nova_data.evolved_skill_id = "blood_nova_evolved"
	nova_data.element = SkillData.Element.DARK
	UpgradeSystem.available_skills.append(nova_data)

	# 时间减速
	var slow_data = load("res://scripts/skills/SkillData.gd").new()
	slow_data.id = "time_slow"
	slow_data.display_name = "⏳ 时间减速"
	slow_data.description = "减慢所有敌人80%速度，持续时间随等级增加"
	slow_data.max_level = 5
	slow_data.cooldown = 8.0
	slow_data.level_up_cooldown = -0.5
	slow_data.scene_path = "res://scripts/skills/SkillTimeSlow.gd"
	slow_data.damage = 0.0
	slow_data.level_up_damage = 0.0
	slow_data.is_active = true
	slow_data.active_slot = 1
	slow_data.element = SkillData.Element.ARCANE
	UpgradeSystem.available_skills.append(slow_data)

	# 荆棘护甲
	var thorn_data = load("res://scripts/skills/SkillData.gd").new()
	thorn_data.id = "thorn_aura"
	thorn_data.display_name = "🌿 荆棘护甲"
	thorn_data.description = "受击时反弹50%伤害，周身荆棘光环"
	thorn_data.max_level = 5
	thorn_data.cooldown = 0.0
	thorn_data.scene_path = "res://scripts/skills/SkillThornAura.gd"
	thorn_data.damage = 0.0
	thorn_data.level_up_damage = 0.0
	thorn_data.element = SkillData.Element.POISON
	UpgradeSystem.available_skills.append(thorn_data)

	# 陨石雨
	var meteor_data = load("res://scripts/skills/SkillData.gd").new()
	meteor_data.id = "meteor_shower"
	meteor_data.display_name = "☄ 陨石雨"
	meteor_data.description = "从天而降多颗陨石砸向敌人密集区域"
	meteor_data.max_level = 5
	meteor_data.cooldown = 5.0
	meteor_data.level_up_cooldown = -0.3
	meteor_data.scene_path = "res://scripts/skills/SkillMeteorShower.gd"
	meteor_data.damage = 40.0
	meteor_data.level_up_damage = 20.0
	meteor_data.evolve_passive_id = "mana_crystal"
	meteor_data.evolved_skill_id = "meteor_evolved"
	meteor_data.element = SkillData.Element.FIRE
	UpgradeSystem.available_skills.append(meteor_data)

	# 穿刺长枪
	var lance_data = load("res://scripts/skills/SkillData.gd").new()
	lance_data.id = "chain_lance"
	lance_data.display_name = "🏹 穿刺长枪"
	lance_data.description = "穿透长枪贯穿多个敌人，升级增加穿透数"
	lance_data.max_level = 5
	lance_data.cooldown = 1.2
	lance_data.level_up_cooldown = -0.1
	lance_data.scene_path = "res://scripts/skills/SkillChainLance.gd"
	lance_data.damage = 35.0
	lance_data.level_up_damage = 18.0
	lance_data.evolve_passive_id = "iron_heart"
	lance_data.evolved_skill_id = "chain_lance_evolved"
	lance_data.element = SkillData.Element.HOLY
	UpgradeSystem.available_skills.append(lance_data)

	# 天罚之柱
	var pillar_data = load("res://scripts/skills/SkillData.gd").new()
	pillar_data.id = "pillar"
	pillar_data.display_name = "✟ 天罚之柱"
	pillar_data.description = "金色光柱从天而降，对柱内敌人持续灼烧"
	pillar_data.max_level = 5
	pillar_data.cooldown = 4.0
	pillar_data.level_up_cooldown = -0.25
	pillar_data.scene_path = "res://scripts/skills/SkillPillar.gd"
	pillar_data.damage = 30.0
	pillar_data.level_up_damage = 15.0
	pillar_data.element = SkillData.Element.HOLY
	UpgradeSystem.available_skills.append(pillar_data)

	# 龙息
	var dragon_data = load("res://scripts/skills/SkillData.gd").new()
	dragon_data.id = "dragon_breath"
	dragon_data.display_name = "🐉 龙息"
	dragon_data.description = "朝敌人方向喷射扇形火焰，持续灼烧"
	dragon_data.max_level = 5
	dragon_data.cooldown = 3.5
	dragon_data.level_up_cooldown = -0.2
	dragon_data.scene_path = "res://scripts/skills/SkillDragonBreath.gd"
	dragon_data.damage = 25.0
	dragon_data.level_up_damage = 12.0
	dragon_data.element = SkillData.Element.FIRE
	UpgradeSystem.available_skills.append(dragon_data)

	# 灵魂风暴
	var spirit_data = load("res://scripts/skills/SkillData.gd").new()
	spirit_data.id = "spirit_storm"
	spirit_data.display_name = "👻 灵魂风暴"
	spirit_data.description = "召唤幽蓝灵魂螺旋盘旋后齐射敌人"
	spirit_data.max_level = 5
	spirit_data.cooldown = 4.5
	spirit_data.level_up_cooldown = -0.25
	spirit_data.scene_path = "res://scripts/skills/SkillSpiritStorm.gd"
	spirit_data.damage = 28.0
	spirit_data.level_up_damage = 14.0
	spirit_data.element = SkillData.Element.DARK
	UpgradeSystem.available_skills.append(spirit_data)

	# 冰封绝对零度
	var azero_data = load("res://scripts/skills/SkillData.gd").new()
	azero_data.id = "absolute_zero"
	azero_data.display_name = "❄ 绝对零度"
	azero_data.description = "收缩能量后冰爆扩散，冻结敌人后碎裂造成二段伤害"
	azero_data.max_level = 5
	azero_data.cooldown = 6.0
	azero_data.level_up_cooldown = -0.3
	azero_data.scene_path = "res://scripts/skills/SkillAbsoluteZero.gd"
	azero_data.damage = 35.0
	azero_data.level_up_damage = 18.0
	azero_data.element = SkillData.Element.ICE
	UpgradeSystem.available_skills.append(azero_data)

	# ── 新增被动 ──

	# 毒液瓶（毒雾进化用）
	var toxic_passive = load("res://scripts/systems/PassiveData.gd").new()
	toxic_passive.id = "toxic_vial"
	toxic_passive.display_name = "毒液瓶"
	toxic_passive.description = "技能伤害+20%，中毒效果持续时间+1s"
	toxic_passive.max_level = 5
	toxic_passive.damage_bonus = 0.20
	UpgradeSystem.available_passives.append(toxic_passive)

	# 法力水晶
	var mana_passive = load("res://scripts/systems/PassiveData.gd").new()
	mana_passive.id = "mana_crystal"
	mana_passive.display_name = "法力水晶"
	mana_passive.description = "技能冷却时间-15%"
	mana_passive.max_level = 5
	mana_passive.cooldown_bonus = -0.15
	UpgradeSystem.available_passives.append(mana_passive)

	# 暗影斗篷
	var shadow_passive = load("res://scripts/systems/PassiveData.gd").new()
	shadow_passive.id = "shadow_cloak"
	shadow_passive.display_name = "暗影斗篷"
	shadow_passive.description = "移动速度+15%，击杀敌人恢复1HP"
	shadow_passive.max_level = 5
	shadow_passive.move_speed_bonus = 0.15
	UpgradeSystem.available_passives.append(shadow_passive)

	# ── 机制型被动（12 个新增）──

	var p_blaze = PassiveData.new()
	p_blaze.id = "blaze_trail"
	p_blaze.display_name = "烈焰足迹"
	p_blaze.description = "暴击后在敌人脚下留下燃烧区域，持续2秒"
	p_blaze.max_level = 3
	p_blaze.damage_bonus = 0.05
	UpgradeSystem.available_passives.append(p_blaze)

	var p_dodge_wave = PassiveData.new()
	p_dodge_wave.id = "dodge_shockwave"
	p_dodge_wave.display_name = "冲击翻滚"
	p_dodge_wave.description = "翻滚结束时释放冲击波，对周围敌人造成50伤害"
	p_dodge_wave.max_level = 3
	p_dodge_wave.move_speed_bonus = 0.05
	UpgradeSystem.available_passives.append(p_dodge_wave)

	var p_berserker = PassiveData.new()
	p_berserker.id = "low_hp_fury"
	p_berserker.display_name = "狂暴本能"
	p_berserker.description = "血量低于30%时伤害翻倍，攻速+50%"
	p_berserker.max_level = 1
	p_berserker.damage_bonus = 0.10
	UpgradeSystem.available_passives.append(p_berserker)

	var p_killstreak = PassiveData.new()
	p_killstreak.id = "kill_streak"
	p_killstreak.display_name = "连杀狂热"
	p_killstreak.description = "每击杀30个敌人永久获得+2%伤害（无上限）"
	p_killstreak.max_level = 1
	p_killstreak.damage_bonus = 0.05
	UpgradeSystem.available_passives.append(p_killstreak)

	var p_thorns = PassiveData.new()
	p_thorns.id = "reflect_thorns"
	p_thorns.display_name = "反伤荆棘"
	p_thorns.description = "受到伤害时反弹30%给攻击者"
	p_thorns.max_level = 3
	p_thorns.hp_bonus = 30.0
	UpgradeSystem.available_passives.append(p_thorns)

	var p_magnet = PassiveData.new()
	p_magnet.id = "super_magnet"
	p_magnet.display_name = "超级磁场"
	p_magnet.description = "拾取范围+50%，拾取经验宝石时回复1%HP"
	p_magnet.max_level = 3
	p_magnet.pickup_radius_bonus = 30.0
	UpgradeSystem.available_passives.append(p_magnet)

	var p_gambler = PassiveData.new()
	p_gambler.id = "lucky_gambler"
	p_gambler.display_name = "赌徒之心"
	p_gambler.description = "击杀时10%概率掉落双倍经验宝石"
	p_gambler.max_level = 3
	p_gambler.exp_bonus = 0.10
	UpgradeSystem.available_passives.append(p_gambler)

	var p_vamp = PassiveData.new()
	p_vamp.id = "vampiric_touch"
	p_vamp.display_name = "吸血之触"
	p_vamp.description = "造成伤害的2%转为治疗（每级+1%）"
	p_vamp.max_level = 5
	p_vamp.regen_bonus = 0.5
	UpgradeSystem.available_passives.append(p_vamp)

	var p_executioner = PassiveData.new()
	p_executioner.id = "executioner"
	p_executioner.display_name = "处刑者"
	p_executioner.description = "对血量低于25%的敌人造成双倍伤害"
	p_executioner.max_level = 1
	p_executioner.damage_bonus = 0.08
	UpgradeSystem.available_passives.append(p_executioner)

	var p_overclock = PassiveData.new()
	p_overclock.id = "overclock"
	p_overclock.display_name = "超频核心"
	p_overclock.description = "攻击速度+20%，但每次施法消耗1HP"
	p_overclock.max_level = 3
	p_overclock.attack_speed_bonus = 0.20
	UpgradeSystem.available_passives.append(p_overclock)

	var p_second_wind = PassiveData.new()
	p_second_wind.id = "second_wind"
	p_second_wind.display_name = "绝处逢生"
	p_second_wind.description = "致死伤害时50%概率保留1HP并获得3秒无敌"
	p_second_wind.max_level = 1
	p_second_wind.hp_bonus = 50.0
	UpgradeSystem.available_passives.append(p_second_wind)

	var p_gold_fever = PassiveData.new()
	p_gold_fever.id = "gold_fever"
	p_gold_fever.display_name = "黄金热"
	p_gold_fever.description = "击杀敌人时额外掉落金币概率+15%"
	p_gold_fever.max_level = 3
	p_gold_fever.exp_bonus = 0.05
	UpgradeSystem.available_passives.append(p_gold_fever)

	# ── 给玩家装备初始技能（根据角色选择）──
	var char_data = player.get_meta("char_data", null)
	var start_ids: Array = ["fireball"]  # 默认
	if char_data and char_data.start_skill_ids.size() > 0:
		start_ids = char_data.start_skill_ids

	# 技能ID → 脚本路径映射
	var skill_script_map := {
		"fireball":      "res://scripts/skills/SkillFireball.gd",
		"lightning":     "res://scripts/skills/SkillLightning.gd",
		"ice_blade":     "res://scripts/skills/SkillIceBlade.gd",
		"iceblade":      "res://scripts/skills/SkillIceBlade.gd",
		"orbital":       "res://scripts/skills/SkillOrbital.gd",
		"holywave":      "res://scripts/skills/SkillHolyWave.gd",
		"frostzone":     "res://scripts/skills/SkillFrostZone.gd",
		"runeblast":     "res://scripts/skills/SkillRuneBlast.gd",
		"poison_cloud":  "res://scripts/skills/SkillPoisonCloud.gd",
		"void_rift":     "res://scripts/skills/SkillVoidRift.gd",
		"arcane_orb":    "res://scripts/skills/SkillArcaneOrb.gd",
		"blood_nova":    "res://scripts/skills/SkillBloodNova.gd",
		"time_slow":     "res://scripts/skills/SkillTimeSlow.gd",
		"thorn_aura":    "res://scripts/skills/SkillThornAura.gd",
		"meteor_shower": "res://scripts/skills/SkillMeteorShower.gd",
		"chain_lance":   "res://scripts/skills/SkillChainLance.gd",
	}

	for sid in start_ids:
		# 从已注册技能里找数据
		var found_data: SkillData = null
		for sd_item in UpgradeSystem.available_skills:
			if sd_item.id == sid:
				found_data = sd_item; break
		if found_data == null: continue

		var script_path = skill_script_map.get(sid, "")
		if script_path == "": continue

		var skill_node = Node2D.new()
		skill_node.set_script(load(script_path))
		skill_node.name = "Skill_" + sid
		skill_node.data = found_data
		player.add_skill(skill_node)

# 掉落逻辑已移至 DropSystem.gd

# ────────────────────────────────────────
# 升级处理
# ────────────────────────────────────────
func _on_show_level_up(choices: Array) -> void:
	get_tree().paused = true

func _on_upgrade_chosen(choice: Dictionary) -> void:
	# 只应用升级，不解锁游戏（HUD负责判断是否还有第二次选择）
	_apply_upgrade(choice)

func _on_upgrade_panel_closed() -> void:
	# 面板全部关闭后解锁 player 状态
	if is_instance_valid(player):
		player.is_showing_upgrade = false

var _pending_replace_skill_data = null

func _apply_upgrade(choice: Dictionary) -> void:
	match choice.get("type", ""):
		"skill_levelup":
			for skill in player.skills:
				if skill.data.id == choice["skill_id"]:
					skill.level_up()
		"skill_new":
			for sd in UpgradeSystem.available_skills:
				if sd.id == choice["skill_id"]:
					var s = Node2D.new()
					s.set_script(load(sd.scene_path if sd.scene_path != "" else "res://scripts/skills/SkillFireball.gd"))
					s.data = sd
					player.add_skill(s)
		"skill_replace":
			for sd in UpgradeSystem.available_skills:
				if sd.id == choice["skill_id"]:
					_pending_replace_skill_data = sd
					EventBus.emit_signal("show_skill_replace_panel", sd, Callable(self, "_on_replace_slot_chosen"))
					return
		"passive":
			for pd in UpgradeSystem.available_passives:
				if pd.id == choice["passive_id"]:
					player.apply_passive(pd)
					if achievement_system:
						achievement_system.on_passive_picked()
		"heal":
			player.heal(player.max_hp * 0.3)
		"evolve":
			_apply_evolve(choice)
		"curse":
			_apply_curse(choice)
		"affix":
			_apply_affix(choice)

func _on_replace_slot_chosen(slot_idx: int) -> void:
	if not _pending_replace_skill_data or not is_instance_valid(player):
		return
	var sd = _pending_replace_skill_data
	_pending_replace_skill_data = null
	var new_skill = Node2D.new()
	new_skill.set_script(load(sd.scene_path if sd.scene_path != "" else "res://scripts/skills/SkillFireball.gd"))
	new_skill.data = sd
	player.replace_skill(slot_idx, new_skill)

func _apply_affix(choice: Dictionary) -> void:
	if not is_instance_valid(player): return
	var sid = choice.get("skill_id", "")
	var affix_id = choice.get("affix_id", "")
	for skill in player.skills:
		if skill.data.id == sid and affix_id not in skill.data.affixes:
			skill.data.affixes.append(affix_id)
			break

func _apply_curse(choice: Dictionary) -> void:
	if not is_instance_valid(player): return
	var cid = choice.get("curse_id", "")
	if not player.curse_ids:
		player.curse_ids = []
	player.curse_ids.append(cid)
	# 应用诅咒效果
	var hp_m = choice.get("hp_mult", 1.0)
	var spd_m = choice.get("speed_mult", 1.0)
	var cd_m = choice.get("cooldown_mult", 1.0)
	var regen_b = choice.get("regen_bonus", 0.0)
	var exp_m = choice.get("exp_mult", 1.0)
	var cc = choice.get("crit_chance", 0.0)
	var cm = choice.get("crit_mult", 1.0)
	if hp_m != 1.0:
		var lost = player.max_hp * (1.0 - hp_m)
		player.max_hp = max(10.0, player.max_hp * hp_m)
		player.current_hp = max(1.0, player.current_hp - lost)
		EventBus.emit_signal("player_damaged", player.current_hp, player.max_hp)
	if spd_m != 1.0:
		player.move_speed *= spd_m
	if cd_m != 1.0:
		for skill in player.skills:
			if skill.data:
				skill.data.cooldown = max(0.08, skill.data.cooldown * cd_m)
	if regen_b != 0.0:
		player.regen_per_second += regen_b
	if exp_m != 1.0:
		player.exp_multiplier *= exp_m
	if cc != 0.0:
		player.crit_chance += cc
	if cm != 1.0:
		player.crit_mult *= cm
	if choice.get("disable_heal", false):
		player.heal_disabled = true
	# 红色闪光提示诅咒生效
	if is_instance_valid(player) and player.visual:
		var t = player.visual.create_tween()
		t.tween_property(player.visual, "modulate", Color(1.5, 0.2, 0.2), 0.1)
		t.tween_property(player.visual, "modulate", Color(1,1,1), 0.3)

func _apply_evolve(choice: Dictionary) -> void:
	var base_skill_id = choice.get("skill_id", "")
	var evolved_id = choice.get("evolved_id", "")
	var dmg_mult = choice.get("damage_mult", 2.0)
	var evolved_name = choice.get("evolved_name", "进化技能")
	var evolved_desc = choice.get("evolved_desc", "")

	for skill in player.skills:
		if skill.data.id != base_skill_id:
			continue
		# 创建进化版 SkillData
		var evolved_data = SkillData.new()
		evolved_data.id = evolved_id
		evolved_data.display_name = evolved_name
		evolved_data.description = evolved_desc
		evolved_data.max_level = skill.data.max_level
		evolved_data.cooldown = skill.data.cooldown * 0.8  # 进化后冷却缩短20%
		evolved_data.damage = skill.data.damage * dmg_mult
		evolved_data.level_up_damage = skill.data.level_up_damage * dmg_mult
		evolved_data.speed = skill.data.speed
		evolved_data.pierce_count = skill.data.pierce_count
		evolved_data.projectile_count = skill.data.projectile_count + 2  # 多射2个
		evolved_data.scene_path = skill.data.scene_path  # 复用相同技能脚本

		# 替换技能数据
		skill.data = evolved_data
		skill.level = evolved_data.max_level  # 进化后保持满级

		if skill.has_method("on_evolve"):
			skill.on_evolve()
		# 进化全屏视觉反馈
		_show_evolve_vfx(evolved_name)
		break

func _show_evolve_vfx(evolved_name: String) -> void:
	if not hud_layer: return
	var flash = ColorRect.new()
	flash.color = Color(1.0, 0.9, 0.3, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(flash)
	var tw = flash.create_tween()
	tw.tween_property(flash, "color:a", 0.5, 0.15)
	tw.tween_property(flash, "color:a", 0.0, 0.4)
	tw.tween_callback(flash.queue_free)

	var label = Label.new()
	label.text = "进化! %s" % evolved_name
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchor_left = 0.5; label.anchor_right = 0.5
	label.anchor_top = 0.3
	label.offset_left = -250; label.offset_right = 250
	label.modulate.a = 0.0
	hud_layer.add_child(label)
	var tw2 = label.create_tween()
	tw2.tween_property(label, "modulate:a", 1.0, 0.2)
	tw2.tween_property(label, "scale", Vector2(1.1, 1.1), 0.15).set_ease(Tween.EASE_OUT)
	tw2.tween_property(label, "scale", Vector2(1.0, 1.0), 0.1)
	tw2.tween_interval(2.0)
	tw2.tween_property(label, "modulate:a", 0.0, 0.5)
	tw2.tween_callback(label.queue_free)

	if is_instance_valid(player) and player.visual:
		var vt = player.visual.create_tween()
		vt.tween_property(player.visual, "modulate", Color(1.5, 1.3, 0.5), 0.15)
		vt.tween_property(player.visual, "modulate", Color(1, 1, 1), 0.5)
	var snd = get_tree().get_first_node_in_group("sound_manager")
	if snd: snd.play_evolve()

func _on_player_damaged(_current_hp: float, _max_hp: float) -> void:
	if screen_shake:
		screen_shake.start(4.0)

func _on_player_died() -> void:
	# #27 死亡慢镜头：0.3秒内减速到0.15x，然后暂停
	Engine.time_scale = 1.0
	var slow_tween = create_tween()
	slow_tween.tween_property(Engine, "time_scale", 0.15, 0.3)
	slow_tween.tween_callback(func():
		Engine.time_scale = 1.0
		get_tree().paused = true
	)
	# 死亡时屏幕变灰
	if hud_layer:
		var gray = ColorRect.new()
		gray.color = Color(0.1, 0.1, 0.15, 0.0)
		gray.set_anchors_preset(Control.PRESET_FULL_RECT)
		gray.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_layer.add_child(gray)
		var gt = gray.create_tween()
		gt.tween_property(gray, "color:a", 0.65, 0.5)
	EventBus.emit_signal("game_over", game_time, player.total_score if is_instance_valid(player) else 0)
	if daily_challenge and daily_modifier_type >= 0:
		daily_challenge.mark_completed(meta_progress)
	# 延迟1.2秒再弹结算（比原来长，因为慢镜头）
	get_tree().create_timer(1.2, true).timeout.connect(func():
		if is_instance_valid(result_screen):
			result_screen.show_result(
				wave_manager.current_wave,
				player.total_score if is_instance_valid(player) else 0,
				game_time,
				EventBus.total_kills if "total_kills" in EventBus else 0,
				false
			)
	)

# ────────────────────────────────────────
# 摄像机跟随
# ────────────────────────────────────────
func _process(_delta: float) -> void:
	if is_instance_valid(player) and is_instance_valid(camera):
		camera.global_position = player.global_position
	# 更新魂石显示
	if meta_progress and hud_layer and hud_layer.has_meta("soul_label"):
		var lbl = hud_layer.get_meta("soul_label")
		if is_instance_valid(lbl):
			lbl.text = "💎 魂石：%d" % meta_progress.soul_stones
	# 更新技能槽（重建结构）
	_update_skill_bar()
	# 更新CD显示（每帧）
	_update_skill_cd()
	# 检测技能协同（#17）
	if synergy_system and is_instance_valid(player):
		synergy_system.check_synergies(player)
	# 章节系统检测
	_check_chapter_transition()
	# Build 图鉴检测
	if _build_codex and is_instance_valid(player):
		_build_codex.check_builds(player)

# HUD 需要的 game_time 接口
var game_time: float = 0.0
var game_over_flag: bool = false

# 章节系统
var current_chapter: int = 0
const CHAPTER_TIMES := [0.0, 300.0, 720.0]  # 第1幕:0s, 第2幕:5min, 第3幕:12min
const CHAPTER_TITLES := ["探索期", "成型期", "爆发期"]

func _check_chapter_transition() -> void:
	if not wave_manager or game_over_flag: return
	var gt = wave_manager.game_time
	game_time = gt
	var target_chapter = 0
	for i in range(CHAPTER_TIMES.size()):
		if gt >= CHAPTER_TIMES[i]:
			target_chapter = i + 1
	if target_chapter > current_chapter and target_chapter <= CHAPTER_TITLES.size():
		current_chapter = target_chapter
		EventBus.emit_signal("chapter_changed", current_chapter, CHAPTER_TITLES[current_chapter - 1])

var _skill_bar_cache: int = -1  # 技能数量缓存，变化时才重建

# #9 每帧更新技能CD遮罩（ProgressBar形式）
func _update_skill_cd() -> void:
	if not hud_layer or not hud_layer.has_meta("skill_bar"): return
	if not is_instance_valid(player): return
	var bar = hud_layer.get_meta("skill_bar")
	if not is_instance_valid(bar): return
	var slots = bar.get_children()
	for i in range(min(slots.size(), player.skills.size())):
		var slot = slots[i]
		var skill = player.skills[i]
		if not is_instance_valid(skill) or not skill.data: continue
		var cd_bar = slot.find_child("CdBar", true, false)
		if cd_bar == null: continue
		var total_cd = max(skill.data.cooldown + skill.data.level_up_cooldown * (skill.level - 1), 0.1)
		var ratio = clamp(skill.cooldown_timer / total_cd, 0.0, 1.0)
		cd_bar.value = ratio * 100.0
		cd_bar.modulate.a = 0.65 if ratio > 0.0 else 0.0
		if ratio <= 0.0:
			var ready_flash = slot.find_child("ReadyFlash", true, false)
			if ready_flash and not ready_flash.get_meta("flashing", false):
				ready_flash.set_meta("flashing", true)
				var t = ready_flash.create_tween()
				t.tween_property(ready_flash, "modulate:a", 0.7, 0.15)
				t.tween_property(ready_flash, "modulate:a", 0.0, 0.25)
				t.tween_callback(func(): if is_instance_valid(ready_flash): ready_flash.set_meta("flashing", false))

func _update_skill_bar() -> void:
	if not hud_layer or not hud_layer.has_meta("skill_bar"): return
	if not is_instance_valid(player): return
	var bar = hud_layer.get_meta("skill_bar")
	if not is_instance_valid(bar): return

	var skill_count = player.skills.size()
	if skill_count == _skill_bar_cache: return
	_skill_bar_cache = skill_count

	for c in bar.get_children(): c.queue_free()

	var icon_file_map := {
		"fireball": "fireball", "orbital": "orbital", "lightning": "lightning",
		"iceblade": "iceblade", "ice_blade": "iceblade",
		"frostzone": "frostzone", "runeblast": "runeblast",
		"poison_cloud": "poison_cloud", "void_rift": "void_rift",
		"blood_nova": "blood_nova", "time_slow": "time_slow",
		"thorn_aura": "thorn_aura", "meteor_shower": "meteor_shower",
		"chain_lance": "chain_lance", "holywave": "holywave",
		"arcane_orb": "arcane_orb",
	}

	var short_names := {
		"fireball": "火焰术", "orbital": "壁垒", "lightning": "雷击链",
		"iceblade": "冰刃", "ice_blade": "冰刃",
		"frostzone": "冰域", "runeblast": "符文",
		"poison_cloud": "毒雾", "void_rift": "虚空",
		"blood_nova": "血月", "time_slow": "减速",
		"thorn_aura": "荆棘", "meteor_shower": "陨石",
		"chain_lance": "长枪", "holywave": "圣光",
		"arcane_orb": "奥术",
	}

	for i in range(skill_count):
		var skill = player.skills[i]
		if not is_instance_valid(skill) or not skill.data: continue
		var sid = skill.data.id
		var sdata = skill.data

		var col = VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.mouse_filter = Control.MOUSE_FILTER_STOP

		var slot = Panel.new()
		slot.custom_minimum_size = Vector2(54, 54)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var slot_style = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.05, 0.05, 0.12, 0.92)
		slot_style.border_width_left = 2; slot_style.border_width_right = 2
		slot_style.border_width_top = 2; slot_style.border_width_bottom = 2
		slot_style.border_color = Color(0.3, 0.45, 0.75, 0.6)
		slot_style.corner_radius_top_left = 6; slot_style.corner_radius_top_right = 6
		slot_style.corner_radius_bottom_left = 6; slot_style.corner_radius_bottom_right = 6
		slot.add_theme_stylebox_override("panel", slot_style)
		col.add_child(slot)

		var icon_path := "res://assets/ui/skill_icons/%s.png" % icon_file_map.get(sid, sid)
		if ResourceLoader.exists(icon_path):
			var ir = TextureRect.new()
			ir.texture = load(icon_path)
			ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ir.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ir.set_anchors_preset(Control.PRESET_FULL_RECT)
			ir.offset_left = 2; ir.offset_top = 2
			ir.offset_right = -2; ir.offset_bottom = -2
			ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(ir)

		if sdata.is_active:
			var key_lbl = Label.new()
			key_lbl.text = "[Q]" if sdata.active_slot == 0 else "[E]"
			key_lbl.add_theme_font_size_override("font_size", 9)
			key_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
			key_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
			key_lbl.add_theme_constant_override("shadow_offset_x", 1)
			key_lbl.add_theme_constant_override("shadow_offset_y", 1)
			key_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
			key_lbl.offset_left = 1; key_lbl.offset_top = 0
			key_lbl.offset_right = 20; key_lbl.offset_bottom = 14
			key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(key_lbl)

		var lv_lbl = Label.new()
		lv_lbl.text = "Lv%d" % skill.level
		lv_lbl.add_theme_font_size_override("font_size", 8)
		lv_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		lv_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		lv_lbl.add_theme_constant_override("shadow_offset_x", 1)
		lv_lbl.add_theme_constant_override("shadow_offset_y", 1)
		lv_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		lv_lbl.offset_left = -26; lv_lbl.offset_right = -1
		lv_lbl.offset_top = -13; lv_lbl.offset_bottom = 0
		lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lv_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(lv_lbl)

		var cd_bar = ProgressBar.new()
		cd_bar.name = "CdBar"
		cd_bar.max_value = 100; cd_bar.value = 0
		cd_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
		cd_bar.fill_mode = ProgressBar.FILL_TOP_TO_BOTTOM
		cd_bar.modulate = Color(0, 0, 0, 0.6)
		cd_bar.show_percentage = false
		var cd_fill = StyleBoxFlat.new()
		cd_fill.bg_color = Color(0, 0, 0, 0.7)
		cd_fill.content_margin_top = 0; cd_fill.content_margin_bottom = 0
		cd_fill.content_margin_left = 0; cd_fill.content_margin_right = 0
		cd_bar.add_theme_stylebox_override("fill", cd_fill)
		var cd_empty = StyleBoxFlat.new()
		cd_empty.bg_color = Color(0, 0, 0, 0)
		cd_empty.content_margin_top = 0; cd_empty.content_margin_bottom = 0
		cd_empty.content_margin_left = 0; cd_empty.content_margin_right = 0
		cd_bar.add_theme_stylebox_override("background", cd_empty)
		cd_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(cd_bar)

		var ready_flash = ColorRect.new()
		ready_flash.name = "ReadyFlash"
		ready_flash.color = Color(1, 1, 0.5, 0.0)
		ready_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		ready_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(ready_flash)

		var name_lbl = Label.new()
		name_lbl.text = short_names.get(sid, sdata.display_name.substr(2))
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
		name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		name_lbl.add_theme_constant_override("shadow_offset_x", 1)
		name_lbl.add_theme_constant_override("shadow_offset_y", 1)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(name_lbl)

		var skill_ref = skill
		var normal_style = slot_style
		var hover_style = slot_style.duplicate()
		hover_style.border_color = Color(0.5, 0.7, 1.0, 0.9)
		hover_style.bg_color = Color(0.08, 0.08, 0.18, 0.95)
		col.mouse_entered.connect(func():
			slot.add_theme_stylebox_override("panel", hover_style)
			_show_skill_tooltip(skill_ref, col)
		)
		col.mouse_exited.connect(func():
			slot.add_theme_stylebox_override("panel", normal_style)
			_hide_skill_tooltip()
		)

		bar.add_child(col)

func _show_skill_tooltip(skill, slot: Control) -> void:
	if not hud_layer or not hud_layer.has_meta("skill_tooltip"): return
	if not is_instance_valid(skill): return
	var tp = hud_layer.get_meta("skill_tooltip")
	if not is_instance_valid(tp): return
	var vbox = tp.get_node_or_null("TooltipVBox")
	if not vbox: return

	for c in vbox.get_children(): c.queue_free()

	var sdata = skill.data
	if not sdata: return

	# 名称
	var name_lbl = Label.new()
	name_lbl.text = sdata.display_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.65, 0.82, 1.0))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	# 触发方式
	var trigger_lbl = Label.new()
	if sdata.is_active:
		var key = "Q" if sdata.active_slot == 0 else "E"
		trigger_lbl.text = "按 [%s] 手动释放" % key
		trigger_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	else:
		trigger_lbl.text = "自动释放（每 %.1f 秒）" % max(sdata.cooldown + sdata.level_up_cooldown * (skill.level - 1), 0.1)
		trigger_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	trigger_lbl.add_theme_font_size_override("font_size", 10)
	trigger_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(trigger_lbl)

	# 分割线
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(0.4, 0.5, 0.8, 0.25)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	# 描述
	var desc_lbl = Label.new()
	desc_lbl.text = sdata.description
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.75, 0.85))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(180, 0)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_lbl)

	# 数值
	var actual_dmg = sdata.damage + sdata.level_up_damage * (skill.level - 1)
	var actual_cd = max(sdata.cooldown + sdata.level_up_cooldown * (skill.level - 1), 0.1)
	var stat_lbl = Label.new()
	stat_lbl.text = "伤害 %d  ·  冷却 %.1fs  ·  Lv.%d/%d" % [int(actual_dmg), actual_cd, skill.level, sdata.max_level]
	stat_lbl.add_theme_font_size_override("font_size", 9)
	stat_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.45))
	stat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(stat_lbl)

	# 定位到槽位上方
	tp.visible = true
	await get_tree().process_frame
	var slot_rect = slot.get_global_rect()
	tp.anchor_left = 0; tp.anchor_right = 0; tp.anchor_top = 0; tp.anchor_bottom = 0
	var tp_w = tp.size.x if tp.size.x > 0 else 200
	var tp_h = tp.size.y if tp.size.y > 0 else 100
	tp.offset_left = slot_rect.position.x + slot_rect.size.x / 2.0 - tp_w / 2.0
	tp.offset_top = slot_rect.position.y - tp_h - 6
	tp.offset_right = tp.offset_left + tp_w
	tp.offset_bottom = tp.offset_top + tp_h

func _hide_skill_tooltip() -> void:
	if not hud_layer or not hud_layer.has_meta("skill_tooltip"): return
	var tp = hud_layer.get_meta("skill_tooltip")
	if is_instance_valid(tp):
		tp.visible = false

func _physics_process(delta: float) -> void:
	if not get_tree().paused:
		game_time += delta
		# 胜利检测：15分钟 = 900秒
		if not game_over_flag and game_time >= 900.0:
			game_over_flag = true
			get_tree().paused = true
			EventBus.emit_signal("player_won", game_time, player.total_score if is_instance_valid(player) else 0)
			if is_instance_valid(abyss_layer_system):
				abyss_layer_system.advance_layer()
			if daily_challenge and daily_modifier_type >= 0:
				daily_challenge.mark_completed(meta_progress)
			get_tree().create_timer(1.0, true).timeout.connect(func():
				if is_instance_valid(result_screen):
					result_screen.show_result(
						wave_manager.current_wave,
						player.total_score if is_instance_valid(player) else 0,
						game_time,
						EventBus.total_kills if "total_kills" in EventBus else 0,
						true
					)
			)
		pass

var _pause_menu: CanvasLayer = null

func _input(event: InputEvent) -> void:
	# R 键重新开始（game over 或 victory 后）
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if game_over_flag or (is_instance_valid(player) and player.is_dead):
			get_tree().paused = false
			get_tree().reload_current_scene()
	# F9 怪物检阅台
	if event is InputEventKey and event.pressed and event.keycode == KEY_F9:
		_debug_enemy_showcase()
	# ESC / P 暂停菜单（#28）
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_P):
		if game_over_flag: return
		if hud_layer and hud_layer.has_meta("level_up_panel"):
			var lup = hud_layer.get_meta("level_up_panel")
			if is_instance_valid(lup) and lup.visible: return  # 升级面板打开时不触发暂停
		_toggle_pause_menu()

# ────────────────────────────────────────
# 遗物系统
# ────────────────────────────────────────
var _last_relic_wave: int = 0   # 上次掉落遗物的波次

func _on_wave_changed_relic(wave: int) -> void:
	if wave <= 1:
		return
	var relic_bonus = get_meta("route_relic_bonus") if has_meta("route_relic_bonus") else 1.0
	var interval = 2 if relic_bonus >= 2.0 else 3
	if wave - _last_relic_wave >= interval:
		_last_relic_wave = wave
		_drop_relic_near_player()
		if relic_bonus >= 2.0:
			_drop_relic_near_player()

func _drop_relic_near_player() -> void:
	if not is_instance_valid(player): return
	var owned = player.relic_ids if "relic_ids" in player else []
	var choices = RelicRegistry.get_random_choices(1, owned)
	if choices.is_empty(): return
	var drop = Area2D.new()
	drop.set_script(load("res://scripts/systems/RelicDrop.gd"))
	add_child(drop)
	drop.global_position = player.global_position + Vector2(randf_range(80, 140), randf_range(-60, 60))
	drop.setup(choices)

# 精英/Boss死亡时在指定位置掉落遗物（#18）
func _drop_relic_at(pos: Vector2) -> void:
	if not is_instance_valid(player): return
	var owned = player.relic_ids if "relic_ids" in player else []
	var choices = RelicRegistry.get_random_choices(1, owned)
	if choices.is_empty(): return
	var drop = Area2D.new()
	drop.set_script(load("res://scripts/systems/RelicDrop.gd"))
	add_child(drop)
	drop.global_position = pos
	drop.setup(choices)

func _on_relic_drop_touched(choices: Array) -> void:
	if not is_instance_valid(player):
		return
	if choices.is_empty():
		return
	# 随机选一个，直接应用，不暂停
	var relic: RelicData = choices[randi() % choices.size()]
	relic.apply_to_player(player)
	if not player.relic_ids.has(relic.id):
		player.relic_ids.append(relic.id)
	EventBus.emit_signal("relic_collected", relic.id)
	_show_relic_toast(relic)

func _build_relic_stat_text(relic: RelicData) -> String:
	var parts: Array[String] = []
	if relic.hp_bonus != 0.0:
		parts.append("HP +%d" % int(relic.hp_bonus))
	if relic.hp_mult != 1.0:
		parts.append("HP ×%.1f" % relic.hp_mult)
	if relic.damage_bonus != 0.0:
		parts.append("伤害 +%d%%" % int(relic.damage_bonus * 100))
	if relic.damage_mult != 1.0:
		parts.append("伤害 ×%.1f" % relic.damage_mult)
	if relic.speed_bonus != 0.0:
		parts.append("移速 +%d" % int(relic.speed_bonus))
	if relic.cooldown_mult != 1.0:
		parts.append("冷却 ×%.2f" % relic.cooldown_mult)
	if relic.pickup_bonus != 0.0:
		parts.append("拾取范围 +%d" % int(relic.pickup_bonus))
	if relic.regen_bonus != 0.0:
		parts.append("回血 +%.1f/秒" % relic.regen_bonus)
	if relic.exp_mult != 1.0:
		parts.append("经验 ×%.1f" % relic.exp_mult)
	if relic.crit_chance != 0.0:
		parts.append("暴击率 +%d%%" % int(relic.crit_chance * 100))
	if relic.crit_mult != 1.0:
		parts.append("暴击伤害 ×%.1f" % relic.crit_mult)
	if relic.projectile_bonus != 0:
		parts.append("投射物 +%d" % relic.projectile_bonus)
	if relic.dodge_recharge != 0.0:
		parts.append("翻滚冷却 -%.1f秒" % relic.dodge_recharge)
	if relic.aoe_mult != 1.0:
		parts.append("范围 ×%.1f" % relic.aoe_mult)
	if parts.is_empty():
		return relic.description
	return "  ".join(parts)

func _show_relic_toast(relic: RelicData) -> void:
	if not hud_layer:
		return
	var rarity_colors = {1: Color(0.8, 0.8, 0.8), 2: Color(0.7, 0.4, 1.0), 3: Color(1.0, 0.7, 0.1)}
	var col = rarity_colors.get(relic.rarity, Color.WHITE)

	var toast = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.15, 0.92)
	style.border_color = col
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 1; style.border_width_bottom = 1
	style.corner_radius_top_left = 6; style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6; style.corner_radius_bottom_right = 6
	style.content_margin_left = 14; style.content_margin_right = 14
	style.content_margin_top = 8; style.content_margin_bottom = 8
	toast.add_theme_stylebox_override("panel", style)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_child(hbox)

	var icon_lbl = Label.new()
	icon_lbl.text = relic.icon_emoji
	icon_lbl.add_theme_font_size_override("font_size", 22)
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_lbl)

	var text_vbox = VBoxContainer.new()
	text_vbox.add_theme_constant_override("separation", 2)
	text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(text_vbox)

	var name_lbl = Label.new()
	name_lbl.text = relic.display_name
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", col)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vbox.add_child(name_lbl)

	var stat_lbl = Label.new()
	stat_lbl.text = _build_relic_stat_text(relic)
	stat_lbl.add_theme_font_size_override("font_size", 12)
	stat_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	stat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vbox.add_child(stat_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = relic.description
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vbox.add_child(desc_lbl)

	toast.anchor_left = 0.5; toast.anchor_right = 0.5
	toast.anchor_top = 0.12; toast.anchor_bottom = 0.12
	toast.offset_left = -180; toast.offset_right = 180
	toast.offset_top = 0; toast.offset_bottom = 60
	toast.modulate = Color(1, 1, 1, 0)
	hud_layer.add_child(toast)

	var tw = toast.create_tween()
	tw.tween_property(toast, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.5)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(toast.queue_free)

# ────────────────────────────────────────
# 通用拾取飘字（世界坐标上方浮出）
# ────────────────────────────────────────
var _active_float_labels: int = 0
const MAX_FLOAT_LABELS := 12

func _on_pickup_float_text(world_pos: Vector2, text: String, color: Color) -> void:
	if _active_float_labels >= MAX_FLOAT_LABELS:
		return
	_active_float_labels += 1

	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.z_index = 100
	var offset_x = randf_range(-20, 20)
	lbl.global_position = world_pos + Vector2(-40 + offset_x, -30)
	add_child(lbl)

	var tw = lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", world_pos.y - 80, 1.0).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tw.set_parallel(false)
	tw.tween_callback(func():
		_active_float_labels -= 1
		lbl.queue_free()
	)

# 30秒事件已整合至 RandomEventSystem._trigger_minor_event()

func _toggle_pause_menu() -> void:
	if is_instance_valid(_pause_menu):
		# 关闭暂停菜单
		_pause_menu.queue_free()
		_pause_menu = null
		get_tree().paused = false
		return
	# 打开暂停菜单
	get_tree().paused = true
	_pause_menu = CanvasLayer.new()
	_pause_menu.layer = 15
	_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_menu)
	# 背景遮罩
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_menu.add_child(overlay)
	# 面板
	var panel = VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(260, 200)
	panel.position = Vector2(-130, -100)
	panel.add_theme_constant_override("separation", 5)
	_pause_menu.add_child(panel)
	# 标题
	var title = Label.new()
	title.text = "⏸ 已暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1, 1, 0.7))
	panel.add_child(title)
	# 分割线
	panel.add_child(_make_hsep())
	# 技能Build展示
	if is_instance_valid(player):
		var sk_lbl = Label.new()
		sk_lbl.text = "⚔ 当前技能"
		sk_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		sk_lbl.add_theme_font_size_override("font_size", 7)
		panel.add_child(sk_lbl)
		for skill in player.skills:
			if skill.data:
				var row = Label.new()
				var prefix = "[Q] " if (skill.data.is_active and skill.data.active_slot == 0) else ("[E] " if (skill.data.is_active and skill.data.active_slot == 1) else "  ")
				row.text = "  %s%s  Lv%d  —  伤害 %.0f  CD %.1fs" % [prefix, skill.data.display_name, skill.level, skill.get_current_damage(), max(skill.data.cooldown + skill.data.level_up_cooldown * (skill.level-1), 0.1)]
				row.add_theme_font_size_override("font_size", 6)
				panel.add_child(row)
		panel.add_child(_make_hsep())
		# 遗物
		var rel_lbl = Label.new()
		rel_lbl.text = "💎 当前遗物"
		rel_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		rel_lbl.add_theme_font_size_override("font_size", 7)
		panel.add_child(rel_lbl)
		if player.relic_ids.is_empty():
			var none_lbl = Label.new(); none_lbl.text = "  （暂无遗物）"
			none_lbl.add_theme_font_size_override("font_size", 6); panel.add_child(none_lbl)
		else:
			for rid in player.relic_ids:
				var rdata = RelicRegistry.get_relic(rid)
				var r_row = Label.new()
				r_row.text = "  %s  —  %s" % [rdata.display_name if rdata else rid, rdata.description if rdata else ""]
				r_row.add_theme_font_size_override("font_size", 6); panel.add_child(r_row)
		panel.add_child(_make_hsep())
		# 诅咒
		if player.curse_ids.size() > 0:
			var c_lbl = Label.new()
			c_lbl.text = "☠ 诅咒"
			c_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
			c_lbl.add_theme_font_size_override("font_size", 7); panel.add_child(c_lbl)
			for cid in player.curse_ids:
				var cr = Label.new(); cr.text = "  " + cid
				cr.add_theme_font_size_override("font_size", 6); panel.add_child(cr)
			panel.add_child(_make_hsep())
	# 按钮
	var btn_resume = Button.new()
	btn_resume.text = "▶ 继续游戏 (ESC/P)"
	btn_resume.custom_minimum_size = Vector2(130, 20)
	btn_resume.pressed.connect(_toggle_pause_menu)
	panel.add_child(btn_resume)
	var btn_restart = Button.new()
	btn_restart.text = "🔄 重新开始"
	btn_restart.custom_minimum_size = Vector2(130, 20)
	btn_restart.pressed.connect(func():
		get_tree().paused = false
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
	)
	panel.add_child(btn_restart)

func _make_hsep() -> HSeparator:
	var s = HSeparator.new()
	s.add_theme_color_override("color", Color(1,1,1,0.18))
	return s

# ═══════════════════════════════════════════════════════════════
# 调试技能面板 — 右侧浮动列表，点击切换为单一技能，方便逐个验证视觉
# ═══════════════════════════════════════════════════════════════
var _debug_skill_panel: Control = null
var _debug_solo_id: String = ""
var _debug_original_skills: Array = []

const DEBUG_SKILL_LIST := [
	["fireball",      "🔥 火焰术"],
	["iceblade",      "❄ 冰刃术"],
	["lightning",     "⚡ 雷击链"],
	["orbital",       "🛡 元素壁垒"],
	["holywave",      "✨ 圣光波"],
	["frostzone",     "🌀 寒冰领域"],
	["runeblast",     "💥 爆裂符文"],
	["poison_cloud",  "☠ 毒雾领域"],
	["void_rift",     "🌑 虚空裂缝"],
	["arcane_orb",    "💠 奥术弹幕"],
	["blood_nova",    "🩸 血月新星"],
	["time_slow",     "⏳ 时间减速"],
	["thorn_aura",    "🌿 荆棘护甲"],
	["meteor_shower", "☄ 陨石雨"],
	["chain_lance",   "🏹 穿刺长枪"],
	["pillar",        "✟ 天罚之柱"],
	["dragon_breath", "🐉 龙息"],
	["spirit_storm",  "👻 灵魂风暴"],
	["absolute_zero", "❄ 绝对零度"],
]

const DEBUG_SCRIPT_MAP := {
	"fireball":      "res://scripts/skills/SkillFireball.gd",
	"iceblade":      "res://scripts/skills/SkillIceBlade.gd",
	"lightning":     "res://scripts/skills/SkillLightning.gd",
	"orbital":       "res://scripts/skills/SkillOrbital.gd",
	"holywave":      "res://scripts/skills/SkillHolyWave.gd",
	"frostzone":     "res://scripts/skills/SkillFrostZone.gd",
	"runeblast":     "res://scripts/skills/SkillRuneBlast.gd",
	"poison_cloud":  "res://scripts/skills/SkillPoisonCloud.gd",
	"void_rift":     "res://scripts/skills/SkillVoidRift.gd",
	"arcane_orb":    "res://scripts/skills/SkillArcaneOrb.gd",
	"blood_nova":    "res://scripts/skills/SkillBloodNova.gd",
	"time_slow":     "res://scripts/skills/SkillTimeSlow.gd",
	"thorn_aura":    "res://scripts/skills/SkillThornAura.gd",
	"meteor_shower": "res://scripts/skills/SkillMeteorShower.gd",
	"chain_lance":   "res://scripts/skills/SkillChainLance.gd",
	"pillar":        "res://scripts/skills/SkillPillar.gd",
	"dragon_breath": "res://scripts/skills/SkillDragonBreath.gd",
	"spirit_storm":  "res://scripts/skills/SkillSpiritStorm.gd",
	"absolute_zero": "res://scripts/skills/SkillAbsoluteZero.gd",
}

func _setup_debug_skill_panel() -> void:
	if not hud_layer: return

	var panel_bg = PanelContainer.new()
	panel_bg.name = "DebugSkillPanel"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.65)
	style.corner_radius_top_left = 6; style.corner_radius_bottom_left = 6
	style.content_margin_left = 6; style.content_margin_right = 6
	style.content_margin_top = 4; style.content_margin_bottom = 4
	panel_bg.add_theme_stylebox_override("panel", style)
	panel_bg.anchor_right = 1.0; panel_bg.anchor_top = 0.0; panel_bg.anchor_bottom = 1.0
	panel_bg.anchor_left = 1.0
	panel_bg.offset_left = -130; panel_bg.offset_right = 0
	panel_bg.offset_top = 80; panel_bg.offset_bottom = -10
	panel_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_layer.add_child(panel_bg)
	_debug_skill_panel = panel_bg

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_bg.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var title = Label.new()
	title.text = "🔧 技能调试"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var btn_all = Button.new()
	btn_all.text = "▶ 全部恢复"
	btn_all.add_theme_font_size_override("font_size", 10)
	btn_all.custom_minimum_size = Vector2(0, 22)
	btn_all.pressed.connect(_debug_restore_all_skills)
	vbox.add_child(btn_all)

	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color(1,1,1,0.15))
	vbox.add_child(sep)

	for entry in DEBUG_SKILL_LIST:
		var sid: String = entry[0]
		var sname: String = entry[1]
		var btn = Button.new()
		btn.text = sname
		btn.add_theme_font_size_override("font_size", 9)
		btn.custom_minimum_size = Vector2(0, 20)
		btn.pressed.connect(_debug_solo_skill.bind(sid))
		vbox.add_child(btn)

func _debug_solo_skill(skill_id: String) -> void:
	if not is_instance_valid(player): return

	if _debug_original_skills.is_empty():
		for sk in player.skills:
			if is_instance_valid(sk) and sk.data:
				_debug_original_skills.append({"id": sk.data.id, "level": sk.level})

	for sk in player.skills.duplicate():
		if is_instance_valid(sk):
			sk.queue_free()
	player.skills.clear()
	_skill_bar_cache = -1

	var found_data: SkillData = null
	for sd in UpgradeSystem.available_skills:
		if sd.id == skill_id:
			found_data = sd; break
	if found_data == null: return

	var script_path = DEBUG_SCRIPT_MAP.get(skill_id, "")
	if script_path == "": return

	var test_data = found_data.duplicate()
	test_data.is_active = false
	test_data.cooldown = min(test_data.cooldown, 1.5)

	var skill_node = Node2D.new()
	skill_node.set_script(load(script_path))
	skill_node.name = "Skill_" + skill_id
	skill_node.data = test_data
	skill_node.level = 3
	player.add_skill(skill_node)

	_debug_solo_id = skill_id
	print("[DEBUG] Solo skill: %s (cd=%.1fs, lv=3)" % [skill_id, test_data.cooldown])

func _debug_restore_all_skills() -> void:
	if not is_instance_valid(player): return
	if _debug_original_skills.is_empty(): return

	for sk in player.skills.duplicate():
		if is_instance_valid(sk):
			sk.queue_free()
	player.skills.clear()
	_skill_bar_cache = -1

	for entry in _debug_original_skills:
		var sid: String = entry["id"]
		var lv: int = entry["level"]
		var found_data: SkillData = null
		for sd in UpgradeSystem.available_skills:
			if sd.id == sid:
				found_data = sd; break
		if found_data == null: continue
		var script_path = DEBUG_SCRIPT_MAP.get(sid, "")
		if script_path == "": continue
		var skill_node = Node2D.new()
		skill_node.set_script(load(script_path))
		skill_node.name = "Skill_" + sid
		skill_node.data = found_data
		skill_node.level = lv
		player.add_skill(skill_node)

	_debug_original_skills.clear()
	_debug_solo_id = ""
	print("[DEBUG] All skills restored")

# ═══════════════════════════════════════════════════════════════
# 怪物检阅台 — F9 清场后在玩家前方排列生成全部怪物类型，附名字标签
# ═══════════════════════════════════════════════════════════════
var _showcase_active: bool = false

func _debug_enemy_showcase() -> void:
	if not is_instance_valid(player): return

	if _showcase_active:
		_debug_clear_showcase()
		return

	# 暂停刷怪
	if wave_manager:
		wave_manager.is_running = false

	# 清场
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.queue_free()

	_showcase_active = true
	EventBus.game_logic_paused = true

	var all_presets: Array = []
	for p in wave_manager.enemy_presets:
		all_presets.append(p.duplicate())
	all_presets.append(wave_manager.elite_presets[0].duplicate())
	for bp in wave_manager.boss_presets:
		var d = bp.duplicate()
		d["is_boss"] = true
		all_presets.append(d)
	var derived := [
		{"name":"分裂体",   "hp":25, "dmg":4,  "spd":0,  "size":10, "color":Color(0.5,0.9,0.3), "exp":2,  "atk_cd":1.5, "move_type": EnemyData.MoveType.CHASE},
		{"name":"仆从",     "hp":20, "dmg":3,  "spd":0,  "size":10, "color":Color(0.7,0.3,0.7), "exp":2,  "atk_cd":1.5, "move_type": EnemyData.MoveType.CHASE},
		{"name":"深渊仆从", "hp":30, "dmg":5,  "spd":0,  "size":12, "color":Color(0.5,0.1,0.5), "exp":3,  "atk_cd":1.5, "move_type": EnemyData.MoveType.CHASE},
	]
	all_presets.append_array(derived)

	var cols := 5
	var spacing := Vector2(160, 200)
	var origin := player.global_position + Vector2(-spacing.x * (cols - 1) / 2.0, -300)

	for i in range(all_presets.size()):
		var preset = all_presets[i]
		var col = i % cols
		var row = i / cols
		var pos = origin + Vector2(col * spacing.x, row * spacing.y)

		var enemy = CharacterBody2D.new()
		enemy.set_script(load("res://scripts/enemies/EnemyBase.gd"))
		enemy.add_to_group("enemies")
		enemy.add_to_group("showcase_enemy")
		add_child(enemy)

		var ed = EnemyData.new()
		ed.display_name    = preset["name"]
		ed.max_hp          = preset.get("hp", 50)
		ed.damage          = 0
		ed.move_speed      = 0
		ed.size            = preset.get("size", 16)
		ed.color           = preset.get("color", Color.WHITE)
		ed.exp_reward      = preset.get("exp", 5)
		ed.attack_cooldown = 99.0
		ed.is_elite        = preset.get("is_elite", false)
		ed.move_type       = preset.get("move_type", EnemyData.MoveType.CHASE)
		ed.armor           = preset.get("armor", 0.0)
		enemy.setup(ed)
		enemy.global_position = pos

		var label = Label.new()
		label.text = preset["name"]
		if preset.get("is_elite", false):
			label.text += " [精英]"
		if preset.get("is_boss", false):
			label.text += " [BOSS]"
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(1, 1, 0.7))
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.position = Vector2(-40, -60)
		enemy.add_child(label)

	print("[DEBUG] 怪物检阅台：已生成 %d 种怪物，再按 F9 关闭" % all_presets.size())

func _debug_clear_showcase() -> void:
	for e in get_tree().get_nodes_in_group("showcase_enemy"):
		if is_instance_valid(e):
			e.queue_free()
	_showcase_active = false
	EventBus.game_logic_paused = false
	if wave_manager:
		wave_manager.is_running = true
	print("[DEBUG] 检阅台已关闭，恢复刷怪")
