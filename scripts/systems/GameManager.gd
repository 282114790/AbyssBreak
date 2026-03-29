# GameManager.gd
# 游戏主控制器 - 管理游戏流程
extends Node
class_name GameManager

@onready var wave_manager: WaveManager = $WaveManager
@onready var player: Player = $Player

var game_time: float = 0.0
var is_paused: bool = false
var score: int = 0

func _ready() -> void:
	_connect_events()
	_start_game()

func _connect_events() -> void:
	EventBus.player_died.connect(_on_player_died)
	EventBus.show_level_up_panel.connect(_on_level_up)
	EventBus.upgrade_chosen.connect(_on_upgrade_chosen)
	EventBus.enemy_died.connect(_on_enemy_died)

func _start_game() -> void:
	game_time = 0.0
	wave_manager.start(player)
	EventBus.emit_signal("game_started")

func _process(delta: float) -> void:
	if is_paused:
		return
	game_time += delta

func _on_player_died() -> void:
	is_paused = true
	get_tree().paused = true
	EventBus.emit_signal("game_over", game_time, score)

func _on_level_up(choices: Array) -> void:
	get_tree().paused = true
	is_paused = true

func _on_upgrade_chosen(choice: Dictionary) -> void:
	get_tree().paused = false
	is_paused = false
	_apply_upgrade(choice)

func _apply_upgrade(choice: Dictionary) -> void:
	match choice["type"]:
		"skill_levelup":
			for skill in player.skills:
				if skill.data.id == choice["skill_id"]:
					skill.level_up()
					EventBus.emit_signal("skill_leveled_up", skill.data.id, skill.level)
		"skill_new":
			var skill_data = _find_skill_data(choice["skill_id"])
			if skill_data:
				var scene = load(skill_data.scene_path)
				if scene:
					var instance = scene.instantiate()
					instance.data = skill_data
					player.add_skill(instance)
		"passive":
			var passive_data = _find_passive_data(choice["passive_id"])
			if passive_data:
				player.apply_passive(passive_data)
		"heal":
			player.heal(player.max_hp * 0.3)

func _find_skill_data(id: String) -> SkillData:
	for sd in UpgradeSystem.available_skills:
		if sd.id == id:
			return sd
	return null

func _find_passive_data(id: String) -> PassiveData:
	for pd in UpgradeSystem.available_passives:
		if pd.id == id:
			return pd
	return null

func _on_enemy_died(pos: Vector2, exp_val: int) -> void:
	score += exp_val
	# 生成经验宝石
	var gem_scene = load("res://scenes/world/ExperienceGem.tscn")
	if gem_scene:
		var gem = gem_scene.instantiate()
		get_tree().current_scene.add_child(gem)
		gem.global_position = pos
		gem.setup(exp_val)
