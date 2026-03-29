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

# ── 经验宝石池 ──
var gem_pool: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_meta_progress()
	_setup_char_registry()
	_setup_achievement_system()
	_connect_event_bus()
	_setup_camera()
	_setup_background()
	_setup_result_screen()
	_setup_sound_manager()
	# 先弹角色选择，选完再初始化玩家/波次/HUD
	_show_char_select()

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
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_died.connect(_on_player_died)
	EventBus.upgrade_chosen.connect(_on_upgrade_chosen)
	EventBus.show_level_up_panel.connect(_on_show_level_up)
	EventBus.player_damaged.connect(_on_player_damaged)

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
	# 用 TileMapBackground 脚本铺设 Kenney 地砖
	var bg = Node2D.new()
	bg.set_script(load("res://scripts/systems/TileMapBackground.gd"))
	bg.name = "TileMapBackground"
	add_child(bg)

	# 地图边界（世界坐标红色警戒线）
	var border_color = Color(0.9, 0.2, 0.2, 0.8)
	var half = 1500.0
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
	_setup_player()
	_setup_wave_manager()
	_setup_hud()
	_register_demo_content()
	if current_difficulty and wave_manager:
		wave_manager.set_meta("difficulty", current_difficulty)
		set_meta("current_difficulty_mult", current_difficulty.soul_stone_mult)
	wave_manager.start(player)

func _setup_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.set_script(load("res://scripts/ui/HUD.gd"))
	hud_layer.name = "HUD"
	hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时HUD仍然响应
	add_child(hud_layer)  # 先加入树，_ready 会执行连接信号

	# 血条
	var hp_bar = ProgressBar.new()
	hp_bar.position = Vector2(10,10); hp_bar.size = Vector2(220,20)
	hp_bar.max_value = 100; hp_bar.value = 100
	hud_layer.add_child(hp_bar)
	hud_layer.hp_bar = hp_bar
	hp_bar.modulate = Color(0.9, 0.2, 0.2)

	var hp_label = Label.new()
	hp_label.position = Vector2(235,10); hp_label.size = Vector2(110,20); hp_label.text = "100 / 100"
	hud_layer.add_child(hp_label)
	hud_layer.hp_label = hp_label

	# 经验条
	var exp_bar = ProgressBar.new()
	exp_bar.position = Vector2(10,35); exp_bar.size = Vector2(300,12)
	exp_bar.max_value = 10; exp_bar.value = 0
	hud_layer.add_child(exp_bar)
	hud_layer.exp_bar = exp_bar
	exp_bar.modulate = Color(0.9, 0.8, 0.1)

	# 等级
	var lv_label = Label.new()
	lv_label.position = Vector2(315,10); lv_label.size = Vector2(70,20); lv_label.text = "Lv.1"
	hud_layer.add_child(lv_label)
	hud_layer.level_label = lv_label

	# 计时器
	var timer_lbl = Label.new()
	timer_lbl.position = Vector2(580,10); timer_lbl.size = Vector2(120,20); timer_lbl.text = "00:00"
	hud_layer.add_child(timer_lbl)
	hud_layer.timer_label = timer_lbl

	# 魂石显示（右上角，图标+数值）
	var soul_row = HBoxContainer.new()
	soul_row.position = Vector2(1100, 10)
	soul_row.add_theme_constant_override("separation", 4)
	hud_layer.add_child(soul_row)

	var soul_icon = TextureRect.new()
	soul_icon.texture = load("res://assets/ui/icon_soul_stone.png")
	soul_icon.custom_minimum_size = Vector2(24, 24)
	soul_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	soul_row.add_child(soul_icon)

	var soul_lbl = Label.new()
	soul_lbl.text = str(meta_progress.soul_stones if meta_progress else 0)
	soul_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	soul_lbl.name = "SoulStoneLabel"
	soul_row.add_child(soul_lbl)
	hud_layer.set_meta("soul_label", soul_lbl)

	# 波次
	var wave_lbl = Label.new()
	wave_lbl.position = Vector2(10,52); wave_lbl.size = Vector2(160,20); wave_lbl.text = "Wave 1 / 5"
	hud_layer.add_child(wave_lbl)
	hud_layer.wave_label = wave_lbl

	# 升级面板（隐藏）
	var panel = Panel.new()
	panel.visible = false
	panel.position = Vector2(140, 160)
	panel.size = Vector2(1000, 340)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.2, 0.92)
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2; style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.5, 1.0)
	style.corner_radius_top_left = 8; style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8; style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	# 石纹背景纹理叠加
	if ResourceLoader.exists("res://assets/ui/ui_panel_bg.png"):
		var bg_rect = TextureRect.new()
		bg_rect.texture = load("res://assets/ui/ui_panel_bg.png")
		bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_rect.stretch_mode = TextureRect.STRETCH_TILE
		bg_rect.modulate = Color(1,1,1,0.18)
		bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(bg_rect)
	hud_layer.add_child(panel)
	hud_layer.level_up_panel = panel

	var ptitle = Label.new()
	ptitle.text = "⬆  选择升级"
	ptitle.position = Vector2(0, 10); ptitle.size = Vector2(1000, 44)
	ptitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ptitle.add_theme_font_size_override("font_size", 28)
	panel.add_child(ptitle)

	var choices = HBoxContainer.new()
	choices.position = Vector2(20, 65)
	choices.size = Vector2(960, 250)
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 16)
	panel.add_child(choices)
	hud_layer.choice_buttons = choices

	# 技能槽（底部居中，最多6个）
	var skill_bar = HBoxContainer.new()
	skill_bar.anchor_left   = 0.5
	skill_bar.anchor_right  = 0.5
	skill_bar.anchor_top    = 1.0
	skill_bar.anchor_bottom = 1.0
	skill_bar.offset_left   = -240
	skill_bar.offset_right  = 240
	skill_bar.offset_top    = -88
	skill_bar.offset_bottom = -8
	skill_bar.add_theme_constant_override("separation", 8)
	hud_layer.add_child(skill_bar)
	hud_layer.set_meta("skill_bar", skill_bar)

	# 注入 game_manager 引用（用于计时）
	hud_layer.game_manager = self

	# ── 难度徽章（右上角）──
	var diff_badge = Label.new()
	diff_badge.name = "DifficultyBadge"
	diff_badge.text = "🟢 普通"
	diff_badge.add_theme_font_size_override("font_size", 16)
	diff_badge.anchor_left   = 1.0
	diff_badge.anchor_right  = 1.0
	diff_badge.anchor_top    = 0.0
	diff_badge.anchor_bottom = 0.0
	diff_badge.offset_left   = -180
	diff_badge.offset_right  = -10
	diff_badge.offset_top    = 38
	diff_badge.offset_bottom = 62
	diff_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_layer.add_child(diff_badge)
	hud_layer.difficulty_badge = diff_badge

	# ── 顶部中央难度标识 ──
	var center_diff_lbl = Label.new()
	center_diff_lbl.name = "CenterDiffLabel"
	center_diff_lbl.text = ""
	center_diff_lbl.add_theme_font_size_override("font_size", 14)
	center_diff_lbl.anchor_left   = 0.5
	center_diff_lbl.anchor_right  = 0.5
	center_diff_lbl.anchor_top    = 0.0
	center_diff_lbl.anchor_bottom = 0.0
	center_diff_lbl.offset_left   = -100
	center_diff_lbl.offset_right  = 100
	center_diff_lbl.offset_top    = 10
	center_diff_lbl.offset_bottom = 32
	center_diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_layer.add_child(center_diff_lbl)

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
	fireball_data.level_up_damage = 15.0
	fireball_data.level_up_cooldown = -0.08
	fireball_data.evolve_passive_id = "power_ring"
	fireball_data.evolved_skill_id = "fireball_evolved"
	UpgradeSystem.available_skills.append(fireball_data)

	# 魔法护盾
	var orbital_data = load("res://scripts/skills/SkillData.gd").new()
	orbital_data.id = "orbital"
	orbital_data.display_name = "🛡 魔法护盾"
	orbital_data.description = "绕身旋转的魔法护盾，持续伤害近身敌人"
	orbital_data.max_level = 5
	orbital_data.cooldown = 0.0
	orbital_data.scene_path = "res://scripts/skills/SkillOrbital.gd"
	orbital_data.damage = 12.0
	orbital_data.level_up_damage = 10.0
	orbital_data.evolve_passive_id = "boots"
	orbital_data.evolved_skill_id = "orbital_evolved"
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
	UpgradeSystem.available_skills.append(lance_data)

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

# ────────────────────────────────────────
# 经验宝石生成
# ────────────────────────────────────────
func _on_enemy_died(pos: Vector2, exp_val: int) -> void:
	EventBus.total_kills += 1   # 击杀计数
	# Boss死亡：exp_val >= 100 判断为boss，强震
	if screen_shake:
		if exp_val >= 100:
			screen_shake.start(15.0)
		else:
			screen_shake.start(2.0)
	var gem = Area2D.new()
	gem.set_script(load("res://scripts/systems/ExperienceGem.gd"))
	add_child(gem)
	gem.global_position = pos
	gem.setup(exp_val)  # 经验值正常，不额外倍增

# ────────────────────────────────────────
# 升级处理
# ────────────────────────────────────────
func _on_show_level_up(choices: Array) -> void:
	get_tree().paused = true

func _on_upgrade_chosen(choice: Dictionary) -> void:
	EventBus.game_logic_paused = false  # 恢复敌人移动和波次
	get_tree().paused = false
	if is_instance_valid(player):
		player.is_showing_upgrade = false
	_apply_upgrade(choice)

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
		"passive":
			for pd in UpgradeSystem.available_passives:
				if pd.id == choice["passive_id"]:
					player.apply_passive(pd)
					# 通知成就系统
					if achievement_system:
						achievement_system.on_passive_picked()
		"heal":
			player.heal(player.max_hp * 0.3)
		"evolve":
			_apply_evolve(choice)

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

		# 进化视觉效果：给技能施加金色高亮 tween
		if skill.has_method("on_evolve"):
			skill.on_evolve()
		break

func _on_player_damaged(_current_hp: float, _max_hp: float) -> void:
	if screen_shake:
		screen_shake.start(8.0)

func _on_player_died() -> void:
	get_tree().paused = true
	EventBus.emit_signal("game_over", game_time, player.total_score if is_instance_valid(player) else 0)
	# 每日挑战：标记完成
	if daily_challenge and daily_modifier_type >= 0:
		daily_challenge.mark_completed(meta_progress)
	# 延迟0.8秒再弹结算，让死亡特效播完
	get_tree().create_timer(0.8, true).timeout.connect(func():
		if is_instance_valid(result_screen):
			var kills = get_tree().get_nodes_in_group("enemies").size()  # 粗略，后续用计数器
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
			lbl.text = str(meta_progress.soul_stones)
	# 更新技能槽
	_update_skill_bar()

# HUD 需要的 game_time 接口
var game_time: float = 0.0
var game_over_flag: bool = false

var _skill_bar_cache: int = -1  # 技能数量缓存，变化时才重建

func _update_skill_bar() -> void:
	if not hud_layer or not hud_layer.has_meta("skill_bar"): return
	if not is_instance_valid(player): return
	var bar = hud_layer.get_meta("skill_bar")
	if not is_instance_valid(bar): return

	var skill_count = player.skills.size()
	if skill_count == _skill_bar_cache: return
	_skill_bar_cache = skill_count

	for c in bar.get_children(): c.queue_free()

	# 技能id → 图标列索引（对应 skill_icons.png 480x32，15列）
	var icon_map := {
		"fireball":      0,
		"orbital":       1,
		"lightning":     2,
		"iceblade":      3,
		"ice_blade":     3,
		"frostzone":     4,
		"runeblast":     5,
		"poison_cloud":  6,
		"void_rift":     7,
		"blood_nova":    8,
		"time_slow":     9,
		"thorn_aura":    10,
		"meteor_shower": 11,
		"chain_lance":   12,
		"holywave":      13,
		"arcane_orb":    14,
	}
	var icons_tex = load("res://assets/ui/skill_icons.png") if ResourceLoader.exists("res://assets/ui/skill_icons.png") else null
	var slot_tex = load("res://assets/ui/ui_skill_slot.png") if ResourceLoader.exists("res://assets/ui/ui_skill_slot.png") else null

	for i in range(max(skill_count, 1)):
		var slot = TextureRect.new()
		if slot_tex: slot.texture = slot_tex
		slot.custom_minimum_size = Vector2(72, 72)
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		if i < skill_count:
			var skill = player.skills[i]
			var sid = skill.data.id if skill.data else ""

			# 图标
			if icons_tex and icon_map.has(sid):
				var col = icon_map[sid]
				var icon_rect = TextureRect.new()
				var atlas = AtlasTexture.new()
				atlas.atlas = icons_tex
				atlas.region = Rect2(col * 32, 0, 32, 32)
				icon_rect.texture = atlas
				icon_rect.custom_minimum_size = Vector2(32, 32)
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_rect.set_anchors_preset(Control.PRESET_CENTER)
				icon_rect.offset_left = -16; icon_rect.offset_right = 16
				icon_rect.offset_top = -22; icon_rect.offset_bottom = 10
				slot.add_child(icon_rect)

			var lv_lbl = Label.new()
			lv_lbl.text = "Lv%d" % (skill.data.level if skill.data else 1)
			lv_lbl.add_theme_font_size_override("font_size", 9)
			lv_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3))
			lv_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			lv_lbl.offset_left = -24; lv_lbl.offset_top = 2
			slot.add_child(lv_lbl)

			var name_lbl = Label.new()
			name_lbl.text = skill.data.display_name.substr(2) if skill.data else "?"  # 去掉emoji前缀
			name_lbl.add_theme_font_size_override("font_size", 9)
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			name_lbl.offset_bottom = 0; name_lbl.offset_top = -16
			slot.add_child(name_lbl)

		bar.add_child(slot)

func _physics_process(delta: float) -> void:
	if not get_tree().paused:
		game_time += delta
		# 胜利检测：5分钟 = 300秒（测试阶段）
		if not game_over_flag and game_time >= 300.0:
			game_over_flag = true
			get_tree().paused = true
			EventBus.emit_signal("player_won", game_time, player.total_score if is_instance_valid(player) else 0)

func _input(event: InputEvent) -> void:
	# R 键重新开始（game over 或 victory 后）
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if game_over_flag or (is_instance_valid(player) and player.is_dead):
			get_tree().paused = false
			get_tree().reload_current_scene()
