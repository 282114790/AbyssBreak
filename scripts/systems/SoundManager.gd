extends Node
# SoundManager - #5 音效层级分离
# 4条独立总线：Normal（普攻）/ Skill（技能）/ Crit（暴击）/ Death（死亡）
# 音量与伤害量正相关

var _buses := {}   # bus_name -> Array[AudioStreamPlayer]
var _pool_size := 6
var _bgm_player: AudioStreamPlayer = null
var _current_bgm: String = ""

const BUS_NORMAL := "SFX_Normal"
const BUS_SKILL  := "SFX_Skill"
const BUS_CRIT   := "SFX_Crit"
const BUS_DEATH  := "SFX_Death"
const BUS_UI     := "SFX_UI"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("sound_manager")
	_setup_buses()
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = -10.0
	add_child(_bgm_player)
	play_bgm_battle()

func _setup_buses() -> void:
	# 创建 5 条总线（若已存在则复用）
	for bus_name in [BUS_NORMAL, BUS_SKILL, BUS_CRIT, BUS_DEATH, BUS_UI]:
		var idx = AudioServer.get_bus_index(bus_name)
		if idx == -1:
			AudioServer.add_bus()
			idx = AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
		_buses[bus_name] = []
		for i in range(_pool_size):
			var p = AudioStreamPlayer.new()
			p.bus = bus_name
			add_child(p)
			_buses[bus_name].append(p)

func _get_player(bus_name: String) -> AudioStreamPlayer:
	var pool: Array = _buses.get(bus_name, [])
	for p in pool:
		if not p.playing: return p
	return pool[0] if not pool.is_empty() else null

func _play_on(bus_name: String, path: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if EventBus.game_logic_paused: return
	var p = _get_player(bus_name)
	if not p: return
	var stream = load(path)
	if not stream: return
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()

# ─── 普通攻击 ─────────────────────────────────────
func play_hit(damage: float = 10.0) -> void:
	# 伤害越高音量越大（10~100映射-8~0 dB）
	var vol = clamp(lerp(-8.0, 0.0, (damage - 10.0) / 90.0), -10.0, 2.0)
	var pitch = randf_range(0.9, 1.1)
	_play_on(BUS_NORMAL, "res://assets/sfx/hit.wav", vol, pitch)

func play_shoot(damage: float = 10.0) -> void:
	var vol = clamp(lerp(-8.0, -2.0, (damage - 5.0) / 50.0), -10.0, 0.0)
	_play_on(BUS_NORMAL, "res://assets/sfx/shoot.wav", vol, randf_range(0.92, 1.08))

# ─── 技能 ─────────────────────────────────────────
func play_skill_cast() -> void:
	_play_on(BUS_SKILL, "res://assets/sfx/shoot.wav", -3.0, 0.75)

func play_explosion(damage: float = 30.0) -> void:
	var vol = clamp(lerp(-4.0, 2.0, (damage - 20.0) / 80.0), -6.0, 4.0)
	_play_on(BUS_SKILL, "res://assets/sfx/explosion.wav", vol)

func play_evolve() -> void:
	_play_on(BUS_SKILL, "res://assets/sfx/evolve.wav", 0.0)

# ─── 暴击 ─────────────────────────────────────────
func play_crit(damage: float = 30.0) -> void:
	# 暴击：音调偏高 + 独立总线，让玩家有明显区分感
	var vol = clamp(lerp(-4.0, 2.0, (damage - 15.0) / 60.0), -6.0, 4.0)
	_play_on(BUS_CRIT, "res://assets/sfx/hit.wav", vol, 1.35)

# ─── 死亡 ─────────────────────────────────────────
func play_enemy_die() -> void:
	_play_on(BUS_DEATH, "res://assets/sfx/enemy_die.wav", -2.0, randf_range(0.85, 1.15))

func play_player_hurt(damage: float = 10.0) -> void:
	var vol = clamp(lerp(-4.0, 2.0, (damage - 5.0) / 45.0), -6.0, 4.0)
	_play_on(BUS_DEATH, "res://assets/sfx/player_hurt.wav", vol)

# ─── UI ───────────────────────────────────────────
func play_gem_pickup() -> void:  _play_on(BUS_UI, "res://assets/sfx/gem_pickup.wav", -8.0)
func play_level_up() -> void:    _play_on(BUS_UI, "res://assets/sfx/level_up.wav", 0.0)
func play_relic_get() -> void:   _play_on(BUS_UI, "res://assets/sfx/evolve.wav", -3.0, 0.85)

# ─── BGM ──────────────────────────────────────────
func play_bgm_battle() -> void: _play_bgm("res://assets/audio/bgm/bgm_battle.mp3")
func play_bgm_boss()   -> void: _play_bgm("res://assets/audio/bgm/bgm_boss.mp3")
func play_bgm_menu()   -> void: _play_bgm("res://assets/audio/bgm/bgm_menu.mp3")
func stop_bgm()        -> void:
	if _bgm_player and _bgm_player.playing: _bgm_player.stop()
	_current_bgm = ""

func _play_bgm(path: String) -> void:
	if _current_bgm == path: return
	var stream = load(path)
	if not stream: push_warning("BGM not found: " + path); return
	_bgm_player.stream = stream
	_bgm_player.play()
	_current_bgm = path
