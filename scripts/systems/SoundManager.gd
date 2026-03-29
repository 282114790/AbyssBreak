extends Node
# 音效管理器 - 加载真实WAV文件播放

var _players: Array = []
var _pool_size: int = 12

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("sound_manager")
	for i in range(_pool_size):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

func _get_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]

func _play(path: String, volume_db: float = 0.0) -> void:
	# 逻辑暂停时（升级面板）不播放战斗音效
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
# 升级音效不受暂停影响（面板出现时就是要播的）
func play_level_up() -> void:
	var stream = load("res://assets/sfx/level_up.wav")
	if stream == null: return
	var p = _get_player()
	p.stream = stream; p.volume_db = 0.0; p.play()
