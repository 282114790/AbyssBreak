# SkillBase.gd
# 所有技能的基类，新技能继承此类即可
extends Node2D
class_name SkillBase

var data: SkillData
var level: int = 1
var owner_player: Node2D
var cooldown_timer: float = 0.0

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	cooldown_timer -= delta
	if cooldown_timer <= 0:
		var current_cooldown = data.cooldown + data.level_up_cooldown * (level - 1)
		cooldown_timer = max(current_cooldown, 0.1)
		activate()

func activate() -> void:
	# 子类重写此方法实现具体攻击逻辑
	pass

func level_up() -> void:
	level = min(level + 1, data.max_level)
	on_level_up()

func on_level_up() -> void:
	# 子类可重写做特殊升级效果
	pass

func get_current_damage() -> float:
	return data.damage + data.level_up_damage * (level - 1)

func can_evolve(passive_ids: Array) -> bool:
	return data.evolve_passive_id != "" and data.evolve_passive_id in passive_ids

# 找最近的敌人
func get_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var min_dist = INF
	for e in enemies:
		var d = global_position.distance_to(e.global_position)
		if d < min_dist:
			min_dist = d
			nearest = e
	return nearest

# 找范围内所有敌人
func get_enemies_in_radius(radius: float) -> Array:
	var enemies = get_tree().get_nodes_in_group("enemies")
	return enemies.filter(func(e): return global_position.distance_to(e.global_position) <= radius)
