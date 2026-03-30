# WaveManager.gd
# 波次管理器 - 程序化生成敌人，无需外部场景文件
extends Node
class_name WaveManager

var current_wave: int = 0
var game_time: float = 0.0
var spawn_timer: float = 0.0
var is_running: bool = false
var player: Node2D = null
var boss_spawned: bool = false   # Boss 只生成一次

# ── 波次节奏状态机 ─────────────────────────────
enum WavePhase { SMALL, ELITE, REST, BOSS }
var current_phase: WavePhase = WavePhase.SMALL
var phase_timer: float = 0.0        # 当前阶段剩余时间
var wave_cycle: int = 0             # 已完成的完整循环次数（用于难度递增）
var elite_count_remaining: int = 0  # 本精英波还需生成几只

# ── 无尽模式 ──
var is_endless: bool = false
var endless_wave_bonus: int = 0
var _endless_spawn_interval: float = 0.12
var _endless_max_enemies: int = 9999
var _endless_hp_mult: float = 1.0
var _endless_count_mult: float = 1.0

# 波次配置
var wave_configs: Array = [
	{"time": 0,   "wave": 1, "interval": 1.2,  "types": [0, 1],          "max": 40},
	{"time": 30,  "wave": 2, "interval": 0.8,  "types": [0, 1, 2],       "max": 80},
	{"time": 60,  "wave": 3, "interval": 0.5,  "types": [0, 1, 2, 4],    "max": 150},
	{"time": 90,  "wave": 4, "interval": 0.3,  "types": [0, 2, 3, 4],    "max": 300, "boss": true},
	{"time": 120, "wave": 5, "interval": 0.15, "types": [0, 1, 2, 3, 4], "max": 9999},
]
var current_config: Dictionary = {}

# 敌人类型预设（5种完整敌人）
var enemy_presets: Array = [
	{"name":"小恶魔",   "hp":20, "dmg":5,  "spd":65,  "size":14, "color":Color(0.9,0.2,0.2), "exp":3,  "atk_cd":1.2},
	{"name":"石头怪",   "hp":80, "dmg":12, "spd":30,  "size":24, "color":Color(0.5,0.5,0.5), "exp":10, "atk_cd":2.0},
	{"name":"暗影弓手", "hp":35, "dmg":8,  "spd":55,  "size":16, "color":Color(0.3,0.1,0.5), "exp":7,  "atk_cd":1.3},
	{"name":"火焰精灵", "hp":45, "dmg":15, "spd":85,  "size":12, "color":Color(1.0,0.5,0.1), "exp":12, "atk_cd":1.0},
	{"name":"骷髅战士", "hp":60, "dmg":10, "spd":45,  "size":20, "color":Color(0.9,0.9,0.8), "exp":9,  "atk_cd":1.5},
]

# 精英预设（每种普通敌人的精英版：血量×3，速度×1.2，发光橙色，奖励×3）
var elite_presets: Array = [
	{"name":"小恶魔",   "hp":60,  "dmg":10, "spd":78,  "size":18, "color":Color(1.0,0.5,0.0), "exp":15, "atk_cd":1.0, "is_elite":true},
	{"name":"石头怪",   "hp":240, "dmg":22, "spd":36,  "size":28, "color":Color(0.8,0.6,0.1), "exp":35, "atk_cd":1.8, "is_elite":true},
	{"name":"暗影弓手", "hp":105, "dmg":16, "spd":66,  "size":20, "color":Color(0.7,0.3,1.0), "exp":25, "atk_cd":1.0, "is_elite":true},
	{"name":"火焰精灵", "hp":135, "dmg":28, "spd":100, "size":16, "color":Color(1.0,0.75,0.0),"exp":40, "atk_cd":0.8, "is_elite":true},
	{"name":"骷髅战士", "hp":180, "dmg":20, "spd":54,  "size":24, "color":Color(1.0,0.85,0.2),"exp":30, "atk_cd":1.2, "is_elite":true},
]

# Boss 预设
var boss_preset: Dictionary = {"name":"深渊魔王","hp":500,"dmg":25,"spd":45,"size":36,"color":Color(0.8,0.1,0.8),"exp":100,"atk_cd":1.5}

# ── 阶段时长配置 ──────────────────────────────
const SMALL_PHASE_DURATION: float = 25.0   # 小波：25秒
const ELITE_PHASE_DURATION: float = 18.0   # 精英波：18秒（生成2+cycle精英）
const REST_PHASE_DURATION:  float = 8.0    # 喘息期：8秒（无敌人出现）
const BOSS_PHASE_DURATION:  float = 60.0   # Boss波（第4轮才触发）
const ELITE_WAVE_EVERY:     int   = 3       # 每3次循环才出一次精英波

func start(p: Node2D) -> void:
	player = p
	is_running = true
	_apply_config(wave_configs[0])
	current_phase = WavePhase.SMALL
	phase_timer = SMALL_PHASE_DURATION

func _process(delta: float) -> void:
	if not is_running or not is_instance_valid(player):
		return
	if EventBus.game_logic_paused:
		return
	game_time += delta
	spawn_timer -= delta
	phase_timer -= delta

	# ── 无尽模式触发检测 ──
	if not is_endless and game_time >= 1800.0 and current_wave >= wave_configs.back()["wave"]:
		is_endless = true
		endless_wave_bonus = 0
		EventBus.emit_signal("wave_changed", current_wave)

	# 波次切换（非无尽）
	if not is_endless:
		for cfg in wave_configs:
			if game_time >= cfg["time"] and cfg["wave"] > current_wave:
				_apply_config(cfg)

	# 无尽模式难度递增
	if is_endless:
		var endless_cycle = int(game_time - 1800.0) / 30
		if endless_cycle > endless_wave_bonus:
			endless_wave_bonus = endless_cycle
			_endless_hp_mult = 1.0 + endless_wave_bonus * 0.10
			_endless_count_mult = 1.0 + endless_wave_bonus * 0.10
			_endless_spawn_interval = max(0.05, 0.12 - endless_wave_bonus * 0.005)

	# ── 阶段状态机 ──────────────────────────────
	_tick_phase(delta)

	# 生成逻辑
	if spawn_timer <= 0 and current_phase != WavePhase.REST:
		_do_spawn()

func _tick_phase(_delta: float) -> void:
	if phase_timer > 0:
		return
	# 当前阶段结束，推进到下一阶段
	match current_phase:
		WavePhase.SMALL:
			# 每N轮进入精英波，否则直接喘息
			if wave_cycle % ELITE_WAVE_EVERY == (ELITE_WAVE_EVERY - 1):
				_enter_elite_phase()
			else:
				_enter_rest_phase()
		WavePhase.ELITE:
			_enter_rest_phase()
		WavePhase.REST:
			wave_cycle += 1
			current_wave += 1
			EventBus.emit_signal("wave_changed", current_wave)
			# 第4波触发Boss
			if current_wave == 4 and not boss_spawned:
				_enter_boss_phase()
			else:
				_enter_small_phase()
		WavePhase.BOSS:
			_enter_small_phase()

func _enter_small_phase() -> void:
	current_phase = WavePhase.SMALL
	phase_timer = SMALL_PHASE_DURATION
	spawn_timer = 0.0

func _enter_elite_phase() -> void:
	current_phase = WavePhase.ELITE
	phase_timer = ELITE_PHASE_DURATION
	elite_count_remaining = 2 + wave_cycle  # 随时间增多
	spawn_timer = 0.0
	# 屏幕提示
	EventBus.emit_signal("wave_changed", -1)  # -1表示精英波通知

func _enter_rest_phase() -> void:
	current_phase = WavePhase.REST
	phase_timer = REST_PHASE_DURATION
	# 清理场景内过多的小怪（喘息时最多保留5只）
	var enemies = get_tree().get_nodes_in_group("enemies")
	var to_remove = enemies.size() - 5
	if to_remove > 0:
		for i in range(to_remove):
			if i < enemies.size() and is_instance_valid(enemies[i]):
				# 不直接 queue_free，让它们自然死亡（给玩家最后一波伤害机会）
				pass

func _enter_boss_phase() -> void:
	current_phase = WavePhase.BOSS
	phase_timer = BOSS_PHASE_DURATION
	boss_spawned = true
	_create_enemy_from_preset(boss_preset)
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm: sm.play_bgm_boss()
	EventBus.emit_signal("boss_spawned")

func _do_spawn() -> void:
	match current_phase:
		WavePhase.SMALL:
			if is_endless:
				spawn_timer = _endless_spawn_interval
				if get_tree().get_nodes_in_group("enemies").size() < int(_endless_max_enemies):
					_spawn_enemy()
			else:
				spawn_timer = current_config.get("interval", 2.0)
				var max_e = current_config.get("max", 30)
				if get_tree().get_nodes_in_group("enemies").size() < max_e:
					_spawn_enemy()
		WavePhase.ELITE:
			if elite_count_remaining > 0:
				spawn_timer = 3.0  # 精英间隔3秒，给玩家反应时间
				elite_count_remaining -= 1
				_spawn_elite()
		WavePhase.BOSS:
			# Boss波只额外补充少量小怪增加压迫感
			spawn_timer = 1.5
			if get_tree().get_nodes_in_group("enemies").size() < 20:
				_spawn_enemy()

func _apply_config(cfg: Dictionary) -> void:
	current_config = cfg
	current_wave = cfg["wave"]
	EventBus.emit_signal("wave_changed", current_wave)

func _spawn_enemy() -> void:
	var types: Array = current_config.get("types", [0])
	var preset = enemy_presets[types[randi() % types.size()]]
	_create_enemy_from_preset(preset)

func _spawn_elite() -> void:
	# 从当前波次可用类型里随机选一个精英
	var types: Array = current_config.get("types", [0])
	var elite_idx = types[randi() % types.size()]
	elite_idx = clamp(elite_idx, 0, elite_presets.size() - 1)
	_create_enemy_from_preset(elite_presets[elite_idx])

func _create_enemy_from_preset(preset: Dictionary) -> void:
	var enemy = CharacterBody2D.new()
	enemy.set_script(load("res://scripts/enemies/EnemyBase.gd"))
	enemy.add_to_group("enemies")
	get_tree().current_scene.add_child(enemy)

	# 读取难度倍率
	var diff = get_meta("difficulty") if has_meta("difficulty") else null
	var hp_m   = diff.enemy_hp_mult    if diff else 1.0
	var dmg_m  = diff.enemy_dmg_mult   if diff else 1.0
	var spd_m  = diff.enemy_speed_mult if diff else 1.0

	# 无尽模式叠加倍率
	if is_endless:
		hp_m  *= _endless_hp_mult
		spd_m *= min(1.0 + endless_wave_bonus * 0.05, 2.0)

	var ed = EnemyData.new()
	ed.display_name    = preset["name"]
	ed.max_hp          = preset["hp"]   * hp_m
	ed.damage          = preset["dmg"]  * dmg_m
	ed.move_speed      = preset["spd"]  * spd_m
	ed.size            = preset["size"]
	ed.color           = preset["color"]
	ed.exp_reward      = preset["exp"]
	ed.attack_cooldown = preset["atk_cd"]
	enemy.setup(ed)
	enemy.global_position = _get_spawn_position()

	# 精英特殊标记：放大+发光效果
	if preset.get("is_elite", false):
		enemy.scale = Vector2(1.4, 1.4)
		# 金色描边（如果有shader）
		if enemy.visual and enemy.visual.material == null:
			var shader_mat = ShaderMaterial.new()
			var outline_shader = load("res://assets/shaders/character_outline.gdshader")
			if outline_shader:
				shader_mat.shader = outline_shader
				shader_mat.set_shader_parameter("outline_color", Color(1.0, 0.7, 0.0, 1.0))
				shader_mat.set_shader_parameter("outline_width", 3.0)
				shader_mat.set_shader_parameter("shadow_color", Color(0,0,0,0))
				shader_mat.set_shader_parameter("shadow_offset", Vector2.ZERO)
				enemy.visual.material = shader_mat

func _get_spawn_position() -> Vector2:
	var side = randi() % 4
	var screen_w = 1280.0
	var screen_h = 720.0
	var margin = 80.0
	match side:
		0: return player.global_position + Vector2(randf_range(-screen_w/2, screen_w/2), -screen_h/2 - margin)
		1: return player.global_position + Vector2(randf_range(-screen_w/2, screen_w/2), screen_h/2 + margin)
		2: return player.global_position + Vector2(-screen_w/2 - margin, randf_range(-screen_h/2, screen_h/2))
		3: return player.global_position + Vector2(screen_w/2 + margin, randf_range(-screen_h/2, screen_h/2))
	return player.global_position


var current_wave: int = 0
var game_time: float = 0.0
var spawn_timer: float = 0.0
var is_running: bool = false
var player: Node2D = null
var boss_spawned: bool = false   # Boss 只生成一次

# ── 无尽模式 ──
var is_endless: bool = false
var endless_wave_bonus: int = 0   # 无尽模式已循环次数（每次+1）
var _endless_spawn_interval: float = 0.12
var _endless_max_enemies: int = 9999
var _endless_hp_mult: float = 1.0
var _endless_count_mult: float = 1.0

# 波次配置
var wave_configs: Array = [
	{"time": 0,   "wave": 1, "interval": 1.2,  "types": [0, 1],          "max": 40},
	{"time": 30,  "wave": 2, "interval": 0.8,  "types": [0, 1, 2],       "max": 80},
	{"time": 60,  "wave": 3, "interval": 0.5,  "types": [0, 1, 2, 4],    "max": 150},
	{"time": 90,  "wave": 4, "interval": 0.3,  "types": [0, 2, 3, 4],    "max": 300, "boss": true},
	{"time": 120, "wave": 5, "interval": 0.15, "types": [0, 1, 2, 3, 4], "max": 9999},
]
var current_config: Dictionary = {}

# 敌人类型预设（5种完整敌人）
var enemy_presets: Array = [
	# 0: 小恶魔 - 快速低血
	{"name":"小恶魔",   "hp":20, "dmg":5,  "spd":65,  "size":14, "color":Color(0.9,0.2,0.2), "exp":3,  "atk_cd":1.2},
	# 1: 石头怪 - 慢速高血
	{"name":"石头怪",   "hp":80, "dmg":12, "spd":30,  "size":24, "color":Color(0.5,0.5,0.5), "exp":10, "atk_cd":2.0},
	# 2: 暗影弓手 - 中速中血
	{"name":"暗影弓手", "hp":35, "dmg":8,  "spd":55,  "size":16, "color":Color(0.3,0.1,0.5), "exp":7,  "atk_cd":1.3},
	# 3: 火焰精灵 - 高速低血
	{"name":"火焰精灵", "hp":45, "dmg":15, "spd":85,  "size":12, "color":Color(1.0,0.5,0.1), "exp":12, "atk_cd":1.0},
	# 4: 骷髅战士 - 中速中高血
	{"name":"骷髅战士", "hp":60, "dmg":10, "spd":45,  "size":20, "color":Color(0.9,0.9,0.8), "exp":9,  "atk_cd":1.5},
]

# Boss 预设
var boss_preset: Dictionary = {"name":"深渊魔王","hp":500,"dmg":25,"spd":45,"size":36,"color":Color(0.8,0.1,0.8),"exp":100,"atk_cd":1.5}

func start(p: Node2D) -> void:
	player = p
	is_running = true
	_apply_config(wave_configs[0])

func _process(delta: float) -> void:
	if not is_running or not is_instance_valid(player):
		return
	if EventBus.game_logic_paused:
		return
	game_time += delta
	spawn_timer -= delta

	# ── 无尽模式触发检测 ──
	# 30分钟 = 1800秒，且已经是最后一波
	if not is_endless and game_time >= 1800.0 and current_wave >= wave_configs.back()["wave"]:
		is_endless = true
		endless_wave_bonus = 0
		EventBus.emit_signal("wave_changed", current_wave)  # 刷新HUD显示∞

	# 波次切换（非无尽模式）
	if not is_endless:
		for cfg in wave_configs:
			if game_time >= cfg["time"] and cfg["wave"] > current_wave:
				_apply_config(cfg)

	# 无尽模式：每30秒循环一次，递增难度
	if is_endless:
		var endless_cycle = int(game_time - 1800.0) / 30
		if endless_cycle > endless_wave_bonus:
			endless_wave_bonus = endless_cycle
			_endless_hp_mult = 1.0 + endless_wave_bonus * 0.10
			_endless_count_mult = 1.0 + endless_wave_bonus * 0.10
			_endless_spawn_interval = max(0.05, 0.12 - endless_wave_bonus * 0.005)

	# 生成敌人
	if spawn_timer <= 0:
		if is_endless:
			spawn_timer = _endless_spawn_interval
			var cur_enemies = get_tree().get_nodes_in_group("enemies").size()
			if cur_enemies < int(_endless_max_enemies):
				_spawn_enemy()
		else:
			spawn_timer = current_config.get("interval", 2.0)
			var max_e = current_config.get("max", 30)
			if get_tree().get_nodes_in_group("enemies").size() < max_e:
				_spawn_enemy()

func _apply_config(cfg: Dictionary) -> void:
	current_config = cfg
	current_wave = cfg["wave"]
	EventBus.emit_signal("wave_changed", current_wave)

func _spawn_enemy() -> void:
	# 第4波且 Boss 未生成 → 生成 Boss，切换BGM
	if current_wave == 4 and not boss_spawned and current_config.get("boss", false):
		boss_spawned = true
		_create_enemy_from_preset(boss_preset)
		var sm = get_tree().get_first_node_in_group("sound_manager")
		if sm: sm.play_bgm_boss()

	var types: Array = current_config.get("types", [0])
	var preset = enemy_presets[types[randi() % types.size()]]
	_create_enemy_from_preset(preset)

func _create_enemy_from_preset(preset: Dictionary) -> void:
	var enemy = CharacterBody2D.new()
	enemy.set_script(load("res://scripts/enemies/EnemyBase.gd"))
	enemy.add_to_group("enemies")
	get_tree().current_scene.add_child(enemy)

	# 读取难度倍率
	var diff = get_meta("difficulty") if has_meta("difficulty") else null
	var hp_m   = diff.enemy_hp_mult    if diff else 1.0
	var dmg_m  = diff.enemy_dmg_mult   if diff else 1.0
	var spd_m  = diff.enemy_speed_mult if diff else 1.0

	# 无尽模式叠加倍率
	if is_endless:
		hp_m  *= _endless_hp_mult
		spd_m *= min(1.0 + endless_wave_bonus * 0.05, 2.0)  # 速度最多翻倍

	var ed = EnemyData.new()
	ed.display_name    = preset["name"]
	ed.max_hp          = preset["hp"]   * hp_m
	ed.damage          = preset["dmg"]  * dmg_m
	ed.move_speed      = preset["spd"]  * spd_m
	ed.size            = preset["size"]
	ed.color           = preset["color"]
	ed.exp_reward      = preset["exp"]
	ed.attack_cooldown = preset["atk_cd"]
	enemy.setup(ed)
	enemy.global_position = _get_spawn_position()

func _get_spawn_position() -> Vector2:
	var side = randi() % 4  # 0=上 1=下 2=左 3=右
	var screen_w = 1280.0
	var screen_h = 720.0
	var margin = 80.0
	match side:
		0: return player.global_position + Vector2(randf_range(-screen_w/2, screen_w/2), -screen_h/2 - margin)
		1: return player.global_position + Vector2(randf_range(-screen_w/2, screen_w/2), screen_h/2 + margin)
		2: return player.global_position + Vector2(-screen_w/2 - margin, randf_range(-screen_h/2, screen_h/2))
		3: return player.global_position + Vector2(screen_w/2 + margin, randf_range(-screen_h/2, screen_h/2))
	return player.global_position
