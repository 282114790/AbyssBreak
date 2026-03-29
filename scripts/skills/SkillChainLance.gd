# SkillChainLance.gd
# 穿刺长枪：向最近敌人发射穿透长枪，最多穿透5个敌人
extends SkillBase
class_name SkillChainLance

func activate() -> void:
	if not owner_player: return
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm: sm.play_shoot()
	_fire_lance()

func _fire_lance() -> void:
	var lv = data.level if data else 1
	# 找最近敌人定方向
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var min_dist := 9999.0
	for e in enemies:
		if not is_instance_valid(e): continue
		var d = e.global_position.distance_to(owner_player.global_position)
		if d < min_dist:
			min_dist = d; nearest = e

	var direction: Vector2
	if nearest:
		direction = (nearest.global_position - owner_player.global_position).normalized()
	else:
		direction = Vector2.RIGHT.rotated(owner_player.rotation)

	var lance = Node2D.new()
	lance.global_position = owner_player.global_position
	lance.rotation = direction.angle()
	get_tree().current_scene.add_child(lance)

	# 视觉：黄绿色细长矩形
	var body = ColorRect.new()
	body.size = Vector2(40 + lv * 5, 6)
	body.position = Vector2(0, -3)
	body.color = Color(0.7, 1.0, 0.2, 0.95)
	lance.add_child(body)
	var tip = ColorRect.new()
	tip.size = Vector2(10, 10)
	tip.position = Vector2(body.size.x - 2, -5)
	tip.color = Color(1.0, 1.0, 0.5, 1.0)
	lance.add_child(tip)

	var speed = 500.0 + lv * 30.0
	var max_pierce = 2 + lv  # Lv1=3, Lv5=7
	var dmg = get_current_damage()
	var hit_set = {}
	var elapsed := 0.0

	while elapsed < 2.0:
		await get_tree().process_frame
		var d = get_process_delta_time()
		elapsed += d
		if not is_instance_valid(lance): return
		lance.global_position += direction * speed * d

		# 碰撞检测
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy): continue
			if hit_set.has(enemy): continue
			if lance.global_position.distance_to(enemy.global_position) < 28:
				hit_set[enemy] = true
				if enemy.has_method("take_damage"):
					enemy.take_damage(dmg)
					EventBus.damage_dealt.emit(enemy.global_position, int(dmg), Color(0.7, 1.0, 0.2))
				var sm2 = get_tree().get_first_node_in_group("sound_manager")
				if sm2: sm2.play_hit()
				if hit_set.size() >= max_pierce: break

		if hit_set.size() >= max_pierce: break
		if lance.global_position.distance_to(owner_player.global_position) > 900: break

	if is_instance_valid(lance):
		lance.queue_free()
