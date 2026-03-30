@tool
# SkillArcaneOrb.gd
# 奥术弹幕：发射多个旋转弹幕，绕玩家公转后向外飞出
extends SkillBase
class_name SkillArcaneOrb

func activate() -> void:
	if not owner_player: return
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm: sm.play_shoot()
	_spawn_orbs()

func _spawn_orbs() -> void:
	var lv = level if data else 1
	var count = 3 + lv  # Lv1=4, Lv5=8

	for i in range(count):
		var angle = TAU * i / count
		_launch_orb(angle)

func _launch_orb(start_angle: float) -> void:
	var lv = level if data else 1
	var orb = Node2D.new()
	orb.global_position = owner_player.global_position
	_get_spawn_root().add_child(orb)

	# 视觉：蓝色发光圆
	var glow = ColorRect.new()
	glow.size = Vector2(14, 14)
	glow.position = Vector2(-7, -7)
	glow.color = Color(0.3, 0.6, 1.0, 0.9)
	orb.add_child(glow)
	var inner = ColorRect.new()
	inner.size = Vector2(6, 6)
	inner.position = Vector2(-3, -3)
	inner.color = Color(0.8, 0.95, 1.0, 1.0)
	orb.add_child(inner)

	var dmg = get_current_damage()
	var orbit_time = 0.6  # 公转时间
	var orbit_radius = 50.0
	var elapsed = 0.0
	var launched = false
	var velocity = Vector2.ZERO
	var speed = 280.0 + lv * 20.0
	var hit_enemies = {}

	while true:
		await get_tree().process_frame
		var d = get_process_delta_time()
		elapsed += d

		if not is_instance_valid(orb): return
		if not is_instance_valid(owner_player):
			orb.queue_free(); return

		if not launched:
			# 公转阶段
			var angle = start_angle + elapsed / orbit_time * TAU
			orb.global_position = owner_player.global_position + Vector2(cos(angle), sin(angle)) * orbit_radius
			if elapsed >= orbit_time:
				launched = true
				velocity = Vector2(cos(start_angle), sin(start_angle)) * speed
		else:
			# 飞出阶段
			orb.global_position += velocity * d
			# 检测碰撞
			for enemy in _get_enemies():
				if not is_instance_valid(enemy): continue
				if hit_enemies.has(enemy): continue
				if orb.global_position.distance_to(enemy.global_position) < 24:
					hit_enemies[enemy] = true
					if enemy.has_method("take_damage"):
						enemy.take_damage(dmg)
						EventBus.damage_dealt.emit(enemy.global_position, int(dmg), Color(0.3, 0.7, 1.0))
					var sm = get_tree().get_first_node_in_group("sound_manager")
					if sm: sm.play_hit()

			# 出界销毁
			if orb.global_position.distance_to(owner_player.global_position) > 800:
				break
			if elapsed > 5.0: break

	if is_instance_valid(orb):
		orb.queue_free()
