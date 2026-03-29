# Main.gd
# 游戏主入口 - 程序化创建所有节点，无需美术资源直接运行
extends Node2D

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

# ── 经验宝石池 ──
var gem_pool: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_meta_progress()
	_setup_char_registry()
	_connect_event_bus()
	_setup_camera()
	_setup_background()
	_setup_result_screen()
	_setup_sound_manager()
	# 先弹角色选择，选完再初始化玩家/波次/HUD
	_show_char_select()

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

func _on_character_selected(char_id: String) -> void:
	char_registry.selected_id = char_id
	char_select_screen.queue_free()
	_start_game()

func _start_game() -> void:
	_setup_player()
	_setup_wave_manager()
	_setup_hud()
	_register_demo_content()
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
	wave_lbl.position = Vector2(10,52); wave_lbl.size = Vector2(140,20); wave_lbl.text = "第 1 波"
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

	# ── 给玩家装备初始技能（根据角色选择）──
	var char_data = player.get_meta("char_data", null)
	var start_ids: Array = ["fireball"]  # 默认
	if char_data and char_data.start_skill_ids.size() > 0:
		start_ids = char_data.start_skill_ids

	# 技能ID → 脚本路径映射
	var skill_script_map := {
		"fireball":  "res://scripts/skills/SkillFireball.gd",
		"lightning": "res://scripts/skills/SkillLightning.gd",
		"ice_blade": "res://scripts/skills/SkillIceBlade.gd",
		"iceblade":  "res://scripts/skills/SkillIceBlade.gd",
		"orbital":   "res://scripts/skills/SkillOrbital.gd",
		"holywave":  "res://scripts/skills/SkillHolyWave.gd",
		"frostzone": "res://scripts/skills/SkillFrostZone.gd",
		"runeblast": "res://scripts/skills/SkillRuneBlast.gd",
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
	if skill_count == _skill_bar_cache: return  # 没变化不重建
	_skill_bar_cache = skill_count

	for c in bar.get_children(): c.queue_free()

	var slot_tex = load("res://assets/ui/ui_skill_slot.png")
	for i in range(max(skill_count, 1)):
		var slot = TextureRect.new()
		slot.texture = slot_tex
		slot.custom_minimum_size = Vector2(72, 72)
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		if i < skill_count:
			var skill = player.skills[i]
			var name_lbl = Label.new()
			name_lbl.text = skill.data.display_name if skill.data else "?"
			name_lbl.add_theme_font_size_override("font_size", 10)
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			name_lbl.offset_bottom = 0
			name_lbl.offset_top = -18
			slot.add_child(name_lbl)

			var lv_lbl = Label.new()
			lv_lbl.text = "Lv%d" % skill.level
			lv_lbl.add_theme_font_size_override("font_size", 9)
			lv_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3))
			lv_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			lv_lbl.offset_left = -24; lv_lbl.offset_top = 2
			slot.add_child(lv_lbl)

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
