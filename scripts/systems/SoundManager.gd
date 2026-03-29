extends Node
# 音效管理器 - SFX 音效池 + BGM 独立播放器

var _players: Array = []
var _pool_size: int = 12
var _bgm_player: AudioStreamPlayer = null
var _current_bgm: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("sound_manager")
	# SFX 音效池
	for i in range(_pool_size):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	# BGM 专用播放器
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = -8.0  # BGM 略低于音效
	add_child(_bgm_player)
	# 游戏启动后自动播放战斗BGM
	play_bgm_battle()

func play_bgm_battle() -> void:
	_play_bgm("res://assets/audio/bgm/bgm_battle.mp3")

func play_bgm_boss() -> void:
	# Boss BGM（暂时用battle代替，等Boss BGM生成后替换）
	_play_bgm("res://assets/audio/bgm/bgm_battle.mp3")

func play_bgm_menu() -> void:
	_play_bgm("res://assets/audio/bgm/bgm_menu.mp3")

func stop_bgm() -> void:
	if _bgm_player and _bgm_player.playing:
		_bgm_player.stop()
	_current_bgm = ""

func _play_bgm(path: String) -> void:
	if _current_bgm == path: return  # 已在播放同一首，不重复
	var stream = load(path)
	if stream == null:
		push_warning("BGM not found: " + path)
		return
	_bgm_player.stream = stream
	_bgm_player.stream.loop = true if stream.has_method("set_loop") else false
	_bgm_player.play()
	_current_bgm = path

func _get_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]

func _play(path: String, volume_db: float = 0.0) -> void:
	if EventBus.game_logic_paused:
		return
	var stream = load(path)
	if stream == null:
		return
	var p = _get_player()
	p.stream = stream
	p.volume_db = volume_db
	p.play()

func play_hit() -> void:         _play("res://assets/sfx/hit.wav", -4.0)
func play_enemy_die() -> void:   _play("res://assets/sfx/enemy_die.wav", -2.0)
func play_player_hurt() -> void: _play("res://assets/sfx/player_hurt.wav", -2.0)
func play_gem_pickup() -> void:  _play("res://assets/sfx/gem_pickup.wav", -8.0)
func play_shoot() -> void:       _play("res://assets/sfx/shoot.wav", -6.0)
func play_explosion() -> void:   _play("res://assets/sfx/explosion.wav", -2.0)
func play_evolve() -> void:      _play("res://assets/sfx/evolve.wav", 0.0)
func play_level_up() -> void:
	var stream = load("res://assets/sfx/level_up.wav")
	if stream == null: return
	var p = _get_player()
	p.stream = stream; p.volume_db = 0.0; p.play()

