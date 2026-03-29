# SkillMeteorShower.gd
# 陨石雨：从天而降多颗陨石砸向敌人密集区域
extends SkillBase
class_name SkillMeteorShower

func activate() -> void:
	if not owner_player: return
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm: sm.play_explosion()
	EventBus.skill_activated.emit("meteor_shower")
	_start_shower()

func _start_shower() -> void:
	var lv = data.level if data else 1
	var count = 4 + lv * 2  # Lv1=6颗, Lv5=14颗
	var interval = 0.15

	for i in range(count):
		await get_tree().create_timer(interval * i).timeout
		if not is_instance_valid(owner_player): return
		_drop_meteor()

func _drop_meteor() -> void:
	if not owner_player: return
	var lv = data.level if data else 1

	# 选目标：随机敌人附近，或随机位置
	var target_pos = owner_player.global_position
	var enemies = get_tree().get_nodes_in_group("enemies")
	var alive = enemies.filter(func(e): return is_instance_valid(e))
	if alive.size() > 0:
		var picked = alive[randi() % alive.size()]
		target_pos = picked.global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
	else:
		target_pos += Vector2(randf_range(-200, 200), randf_range(-200, 200))

	var meteor = Node2D.new()
	var start_pos = target_pos + Vector2(randf_range(-30, 30), -300)
	meteor.global_position = start_pos
	get_tree().current_scene.add_child(meteor)

	# 视觉：橙红色方块+尾迹
	var body = ColorRect.new()
	body.size = Vector2(16, 16)
	body.position = Vector2(-8, -8)
	body.color = Color(1.0, 0.4, 0.1, 0.95)
	meteor.add_child(body)
	var trail = ColorRect.new()
	trail.size = Vector2(8, 24)
	trail.position = Vector2(-4, -28)
	trail.color = Color(1.0, 0.7, 0.2, 0.5)
	meteor.add_child(trail)

	# 飞落动画
	var elapsed := 0.0
	var fall_time := 0.4
	var dmg = get_current_damage()
	var explode_radius = 48.0 + lv * 8.0

	while elapsed < fall_time:
		await get_tree().process_frame
		var d = get_process_delta_time()
		elapsed += d
		if not is_instance_valid(meteor): return
		var t = elapsed / fall_time
		meteor.global_position = start_pos.lerp(target_pos, t)
		meteor.rotation += d * 3.0

	# 爆炸
	if is_instance_valid(meteor):
		meteor.queue_free()
	_explode_at(target_pos, explode_radius, dmg)

func _explode_at(pos: Vector2, radius: float, dmg: float) -> void:
	# 爆炸特效
	var boom = Node2D.new()
	boom.global_position = pos
	get_tree().current_scene.add_child(boom)
	var flash = ColorRect.new()
	flash.size = Vector2(radius * 2, radius * 2)
	flash.position = Vector2(-radius, -radius)
	flash.color = Color(1.0, 0.5, 0.1, 0.7)
	boom.add_child(flash)

	# 伤害
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy): continue
		if enemy.global_position.distance_to(pos) <= radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(dmg)
				EventBus.damage_dealt.emit(enemy.global_position, int(dmg), Color(1.0, 0.5, 0.1))

	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm: sm.play_explosion()

	# 淡出
	var elapsed := 0.0
	while elapsed < 0.3:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if not is_instance_valid(boom): return
		boom.modulate.a = 1.0 - elapsed / 0.3
	if is_instance_valid(boom):
		boom.queue_free()
