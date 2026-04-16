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
var _endless_spawn_interval: float = 0.06
var _endless_max_enemies: int = 9999
var _endless_hp_mult: float = 1.0
var _endless_count_mult: float = 1.0
var enemy_count_mult: float = 1.0  # 难度的敌人数量倍率
var _adaptive_spawn_mult: float = 1.0
var _adaptive_update_timer: float = 0.0

# 波次配置
var wave_configs: Array = [
	{"time": 0,   "wave": 1, "interval": 0.6,  "types": [0, 1],                "max": 80},
	{"time": 30,  "wave": 2, "interval": 0.4,  "types": [0, 1, 2, 5],          "max": 160},
	{"time": 60,  "wave": 3, "interval": 0.25, "types": [0, 1, 2, 4, 6],       "max": 300},
	{"time": 90,  "wave": 4, "interval": 0.15, "types": [0, 2, 3, 5, 7, 8],    "max": 600, "boss": true},
	{"time": 120, "wave": 5, "interval": 0.08, "types": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], "max": 9999},
]
var current_config: Dictionary = {}

# 敌人类型预设（5种完整敌人）
var enemy_presets: Array = [
	{"name":"小恶魔",   "hp":20, "dmg":5,  "spd":65,  "size":14, "color":Color(0.9,0.2,0.2), "exp":3,  "atk_cd":1.2, "move_type": EnemyData.MoveType.CHASE},
	{"name":"石头怪",   "hp":80, "dmg":12, "spd":30,  "size":24, "color":Color(0.5,0.5,0.5), "exp":10, "atk_cd":2.0, "move_type": EnemyData.MoveType.TANK, "armor": 5.0},
	{"name":"暗影弓手", "hp":35, "dmg":8,  "spd":55,  "size":16, "color":Color(0.3,0.1,0.5), "exp":7,  "atk_cd":1.3, "move_type": EnemyData.MoveType.RANGED, "atk_range": 300.0},
	{"name":"火焰精灵", "hp":45, "dmg":15, "spd":85,  "size":12, "color":Color(1.0,0.5,0.1), "exp":12, "atk_cd":1.0, "move_type": EnemyData.MoveType.EXPLODE},
	{"name":"骷髅战士", "hp":60, "dmg":10, "spd":45,  "size":20, "color":Color(0.9,0.9,0.8), "exp":9,  "atk_cd":1.5, "move_type": EnemyData.MoveType.CHASE},
	{"name":"裂变虫",   "hp":50, "dmg":8,  "spd":55,  "size":16, "color":Color(0.4,0.8,0.2), "exp":8,  "atk_cd":1.2, "move_type": EnemyData.MoveType.SPLITTER},
	{"name":"幽影刺客", "hp":30, "dmg":18, "spd":40,  "size":14, "color":Color(0.2,0.1,0.3), "exp":12, "atk_cd":1.0, "move_type": EnemyData.MoveType.TELEPORTER},
	{"name":"铁盾卫兵", "hp":90, "dmg":10, "spd":35,  "size":22, "color":Color(0.4,0.5,0.7), "exp":11, "atk_cd":1.8, "move_type": EnemyData.MoveType.SHIELDER, "armor": 3.0},
	{"name":"亡灵法师", "hp":40, "dmg":6,  "spd":30,  "size":16, "color":Color(0.6,0.1,0.6), "exp":15, "atk_cd":2.0, "move_type": EnemyData.MoveType.SUMMONER},
	{"name":"巡逻傀儡", "hp":70, "dmg":25, "spd":70,  "size":20, "color":Color(0.7,0.7,0.2), "exp":10, "atk_cd":1.0, "move_type": EnemyData.MoveType.PATROL},
]

# 精英预设（每种普通敌人的精英版：血量×3，速度×1.2，发光橙色，奖励×3）
var elite_presets: Array = [
	{"name":"小恶魔",   "hp":60,  "dmg":10, "spd":78,  "size":18, "color":Color(1.0,0.5,0.0), "exp":15, "atk_cd":1.0, "is_elite":true},
	{"name":"石头怪",   "hp":240, "dmg":22, "spd":36,  "size":28, "color":Color(0.8,0.6,0.1), "exp":35, "atk_cd":1.8, "is_elite":true},
	{"name":"暗影弓手", "hp":105, "dmg":16, "spd":66,  "size":20, "color":Color(0.7,0.3,1.0), "exp":25, "atk_cd":1.0, "is_elite":true, "move_type": EnemyData.MoveType.RANGED, "atk_range": 350.0},
	{"name":"火焰精灵", "hp":135, "dmg":28, "spd":100, "size":16, "color":Color(1.0,0.75,0.0),"exp":40, "atk_cd":0.8, "is_elite":true},
	{"name":"骷髅战士", "hp":180, "dmg":20, "spd":54,  "size":24, "color":Color(1.0,0.85,0.2),"exp":30, "atk_cd":1.2, "is_elite":true},
	{"name":"裂变虫",   "hp":150, "dmg":16, "spd":66,  "size":20, "color":Color(0.6,1.0,0.3),"exp":25, "atk_cd":1.0, "is_elite":true, "move_type": EnemyData.MoveType.SPLITTER},
	{"name":"幽影刺客", "hp":90,  "dmg":35, "spd":48,  "size":18, "color":Color(0.4,0.2,0.6),"exp":35, "atk_cd":0.8, "is_elite":true, "move_type": EnemyData.MoveType.TELEPORTER},
	{"name":"铁盾卫兵", "hp":270, "dmg":18, "spd":42,  "size":26, "color":Color(0.6,0.7,0.9),"exp":30, "atk_cd":1.5, "is_elite":true, "move_type": EnemyData.MoveType.SHIELDER, "armor": 6.0},
	{"name":"亡灵法师", "hp":120, "dmg":12, "spd":36,  "size":20, "color":Color(0.8,0.2,0.8),"exp":40, "atk_cd":1.5, "is_elite":true, "move_type": EnemyData.MoveType.SUMMONER},
	{"name":"巡逻傀儡", "hp":210, "dmg":45, "spd":84,  "size":24, "color":Color(0.9,0.9,0.3),"exp":35, "atk_cd":0.8, "is_elite":true, "move_type": EnemyData.MoveType.PATROL},
]

# Boss 预设（按时间线出现）
var boss_presets: Array = [
	{"name":"深渊骑士","hp":600,"dmg":20,"spd":50,"size":32,"color":Color(0.2,0.4,0.9),"exp":60,"atk_cd":1.5,"boss_id":0},
	{"name":"深渊魔王","hp":1200,"dmg":30,"spd":45,"size":36,"color":Color(0.8,0.1,0.8),"exp":100,"atk_cd":1.2,"boss_id":1},
	{"name":"虚空主宰","hp":2500,"dmg":45,"spd":55,"size":42,"color":Color(0.9,0.2,0.1),"exp":200,"atk_cd":1.0,"boss_id":2},
]
var boss_spawn_times: Array = [300.0, 600.0, 850.0]
var _next_boss_idx: int = 0
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
			_endless_spawn_interval = max(0.03, 0.06 - endless_wave_bonus * 0.003)

	# 时间线 Boss 生成
	if _next_boss_idx < boss_spawn_times.size() and game_time >= boss_spawn_times[_next_boss_idx]:
		_spawn_timed_boss(_next_boss_idx)
		_next_boss_idx += 1

	# ── 自适应刷怪密度 ──
	_adaptive_update_timer -= delta
	if _adaptive_update_timer <= 0:
		_adaptive_update_timer = 0.5
		var current_count = get_tree().get_nodes_in_group("enemies").size()
		var target_count = max(current_config.get("max", 80) * 0.4 * enemy_count_mult, 5.0)
		var ratio = current_count / target_count
		if ratio < 0.3:
			_adaptive_spawn_mult = lerpf(_adaptive_spawn_mult, 3.0, 0.1)
		elif ratio > 0.7:
			_adaptive_spawn_mult = lerpf(_adaptive_spawn_mult, 1.0, 0.1)

	# ── 阶段状态机 ──────────────────────────────
	_tick_phase(delta)

	# 生成逻辑
	if spawn_timer <= 0 and current_phase != WavePhase.REST:
		_do_spawn()

func _tick_phase(_delta: float) -> void:
	if phase_timer > 0:
		return
	match current_phase:
		WavePhase.SMALL:
			if wave_cycle > 0 and wave_cycle % 4 == 3 and _next_boss_idx < boss_presets.size():
				_enter_boss_phase()
			elif wave_cycle % ELITE_WAVE_EVERY == (ELITE_WAVE_EVERY - 1):
				_enter_elite_phase()
			else:
				_enter_rest_phase()
		WavePhase.ELITE:
			_enter_rest_phase()
		WavePhase.REST:
			wave_cycle += 1
			current_wave += 1
			EventBus.emit_signal("wave_changed", current_wave)
			_enter_small_phase()
		WavePhase.BOSS:
			_enter_rest_phase()

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

func _enter_boss_phase() -> void:
	current_phase = WavePhase.BOSS
	phase_timer = BOSS_PHASE_DURATION
	boss_spawned = true
	_spawn_timed_boss(_next_boss_idx)
	_next_boss_idx += 1

func _do_spawn() -> void:
	match current_phase:
		WavePhase.SMALL:
			var batch_size = 1
			if game_time >= 90.0:
				batch_size = clampi(int(game_time / 120.0), 2, 6)
			if is_endless:
				spawn_timer = _endless_spawn_interval / _adaptive_spawn_mult
				if get_tree().get_nodes_in_group("enemies").size() < int(_endless_max_enemies * enemy_count_mult):
					for _b in range(batch_size):
						_spawn_enemy()
			else:
				spawn_timer = current_config.get("interval", 2.0) / _adaptive_spawn_mult
				var max_e = int(current_config.get("max", 30) * enemy_count_mult)
				if get_tree().get_nodes_in_group("enemies").size() < max_e:
					for _b in range(batch_size):
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

	# 时间递增缩放：前60秒平稳，之后指数增长匹配玩家成长
	var time_scale = 1.0 + pow(max(game_time - 60.0, 0.0) / 120.0, 1.6) * 0.8
	hp_m *= time_scale
	dmg_m *= (1.0 + (time_scale - 1.0) * 0.5)

	# 波次循环递增：每完成一轮循环敌人+12% HP
	var cycle_scale = 1.0 + wave_cycle * 0.12
	hp_m *= cycle_scale

	var ed = EnemyData.new()
	ed.display_name    = preset["name"]
	ed.max_hp          = preset["hp"]   * hp_m
	ed.damage          = preset["dmg"]  * dmg_m
	ed.move_speed      = preset["spd"]  * spd_m
	ed.size            = preset["size"]
	ed.color           = preset["color"]
	ed.exp_reward      = preset["exp"]
	ed.attack_cooldown = preset["atk_cd"]
	ed.is_elite        = preset.get("is_elite", false)
	ed.move_type       = preset.get("move_type", EnemyData.MoveType.CHASE)
	ed.armor           = preset.get("armor", 0.0)
	ed.attack_range    = preset.get("atk_range", 0.0)
	enemy.setup(ed)
	enemy.global_position = _get_spawn_position()

	# 精英/Boss 视觉效果已由 EnemyBase._apply_enemy_style() 内部处理

func _spawn_timed_boss(idx: int) -> void:
	if idx >= boss_presets.size(): return
	var preset = boss_presets[idx].duplicate()
	var diff = get_meta("difficulty") if has_meta("difficulty") else null
	var hp_m = diff.enemy_hp_mult if diff else 1.0
	var dmg_m = diff.enemy_dmg_mult if diff else 1.0
	preset["hp"] = preset["hp"] * hp_m
	preset["dmg"] = preset["dmg"] * dmg_m
	_create_enemy_from_preset(preset)
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm: sm.play_bgm_boss()
	EventBus.emit_signal("boss_spawned")

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


