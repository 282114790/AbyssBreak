@tool
# SkillBase.gd
# 所有技能的基类，新技能继承此类即可
extends Node2D
class_name SkillBase

var data: SkillData
var level: int = 1
var owner_player: Node2D
var cooldown_timer: float = 0.0
# 投射物/特效生成父节点（默认 null=用 current_scene；编辑器预览时注入 SubViewport 根）
var spawn_root: Node = null

func _get_spawn_root() -> Node:
	if spawn_root != null and is_instance_valid(spawn_root):
		return spawn_root
	return get_tree().current_scene

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if data == null: return  # 编辑器预览时 data 未注入则跳过
	# 主动技能：等待按键输入
	if data.is_active:
		cooldown_timer -= delta
		var action = "skill_q" if data.active_slot == 0 else "skill_e"
		if Input.is_action_just_pressed(action) and cooldown_timer <= 0:
			var current_cooldown = data.cooldown + data.level_up_cooldown * (level - 1)
			cooldown_timer = max(current_cooldown, 0.1)
			activate()
		return
	# 自动技能：倒计时自动触发
	cooldown_timer -= delta
	if cooldown_timer <= 0:
		var current_cooldown = data.cooldown + data.level_up_cooldown * (level - 1)
		cooldown_timer = max(current_cooldown, 0.1)
		activate()

func activate() -> void:
	# 施法动画：通知 player 播放 cast 动画
	if is_instance_valid(owner_player) and owner_player.has_method("play_cast_anim"):
		owner_player.play_cast_anim()
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

# 计算实际伤害（含暴击判断），返回 [final_dmg, is_crit]
func calc_damage(base_dmg: float = -1.0) -> Array:
	var dmg = base_dmg if base_dmg >= 0.0 else get_current_damage()
	if owner_player:
		dmg *= owner_player.damage_multiplier
	var crit_chance = owner_player.crit_chance if owner_player else 0.05
	var crit_mult   = owner_player.crit_mult   if owner_player else 1.5
	var is_crit = randf() < crit_chance
	if is_crit:
		dmg *= crit_mult
	return [dmg, is_crit]

# 对单个敌人造成伤害（自动含暴击+分级音效，#5）
func deal_damage(enemy: Node, base_dmg: float = -1.0) -> void:
	if not is_instance_valid(enemy): return
	var result = calc_damage(base_dmg)
	var final_dmg: float = result[0]
	var is_crit: bool = result[1]
	enemy.take_damage(final_dmg, is_crit)
	# 分级音效
	var snd = get_tree().get_first_node_in_group("sound_manager")
	if snd:
		if is_crit:
			snd.play_crit(final_dmg)
		else:
			snd.play_hit(final_dmg)

func can_evolve(passive_ids: Array) -> bool:
	return data.evolve_passive_id != "" and data.evolve_passive_id in passive_ids

# 获取敌人列表：优先从 spawn_root 查找（支持编辑器 SubViewport），回退到主场景树
func _get_enemies() -> Array:
	if spawn_root != null and is_instance_valid(spawn_root):
		return spawn_root.get_children().filter(func(n): return n.is_in_group("enemies"))
	return get_tree().get_nodes_in_group("enemies")

# 找最近的敌人（支持瞄准优先级：精英>低血>最近，#14）
func get_nearest_enemy() -> Node2D:
	var enemies = _get_enemies()
	if enemies.is_empty(): return null
	# 优先精英
	var elites = enemies.filter(func(e): return e.data and (e.data.get("is_elite") if e.data.get("is_elite") != null else false))
	if not elites.is_empty():
		elites.sort_custom(func(a,b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
		return elites[0]
	# 次优先：血量最低
	var lowest = enemies[0]
	for e in enemies:
		if e.hp < lowest.hp: lowest = e
	# 如果最低血量敌人比最近敌人近2倍以上，优先打最近
	var nearest: Node2D = null
	var min_dist = INF
	for e in enemies:
		var d = global_position.distance_to(e.global_position)
		if d < min_dist: min_dist = d; nearest = e
	var dist_lowest = global_position.distance_to(lowest.global_position)
	if dist_lowest < min_dist * 2.0:
		return lowest
	return nearest

# 找范围内所有敌人
func get_enemies_in_radius(radius: float) -> Array:
	var enemies = _get_enemies()
	return enemies.filter(func(e): return global_position.distance_to(e.global_position) <= radius)
