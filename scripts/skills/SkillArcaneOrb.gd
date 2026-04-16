@tool
# SkillArcaneOrb.gd
extends SkillBase
class_name SkillArcaneOrb

var _orb_tex: Texture2D = null

func _get_orb_texture() -> Texture2D:
	if _orb_tex == null:
		_orb_tex = load("res://assets/sprites/effects/skills/proj_arcane_orb.png")
	return _orb_tex

func activate() -> void:
	if not owner_player: return
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm: sm.play_shoot()
	_spawn_orbs()

func _spawn_orbs() -> void:
	var lv = level if data else 1
	var count = 3 + lv

	for i in range(count):
		var angle = TAU * i / count
		_launch_orb(angle)

func _launch_orb(start_angle: float) -> void:
	var lv = level if data else 1
	var orb = Node2D.new()
	orb.global_position = owner_player.global_position
	_get_spawn_root().add_child(orb)

	var sprite = Sprite2D.new()
	sprite.texture = _get_orb_texture()
	sprite.scale = Vector2(0.4, 0.4)
	orb.add_child(sprite)

	var trail = GPUParticles2D.new()
	trail.emitting = true
	trail.amount = 14
	trail.lifetime = 0.3
	trail.explosiveness = 0.0
	trail.local_coords = false
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 2.0
	pm.scale_max = 5.0
	var g = Gradient.new()
	g.set_color(0, Color(0.4, 0.6, 1.0, 0.6))
	g.set_color(1, Color(0.2, 0.3, 0.9, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	trail.process_material = pm
	orb.add_child(trail)

	var dmg = get_current_damage()
	var orbit_time = 0.6
	var orbit_radius = 50.0
	var elapsed = 0.0
	var launched = false
	var velocity = Vector2.ZERO
	var speed = 500.0 + lv * 30.0
	var hit_enemies = {}

	while true:
		await get_tree().process_frame
		var d = get_process_delta_time()
		elapsed += d

		if not is_instance_valid(orb): return
		if not is_instance_valid(owner_player):
			orb.queue_free(); return

		sprite.rotation += d * 3.0

		if not launched:
			var angle = start_angle + elapsed / orbit_time * TAU
			orb.global_position = owner_player.global_position + Vector2(cos(angle), sin(angle)) * orbit_radius
			if elapsed >= orbit_time:
				launched = true
				velocity = Vector2(cos(start_angle), sin(start_angle)) * speed
		else:
			orb.global_position += velocity * d
			for enemy in _get_enemies():
				if not is_instance_valid(enemy): continue
				if hit_enemies.has(enemy): continue
				if orb.global_position.distance_to(enemy.global_position) < 24:
					hit_enemies[enemy] = true
					deal_damage(enemy)
					_spawn_hit_spark(orb.global_position)

			if orb.global_position.distance_to(owner_player.global_position) > 800:
				break
			if elapsed > 5.0: break

	if is_instance_valid(orb):
		orb.queue_free()

func _spawn_hit_spark(pos: Vector2) -> void:
	var spark = GPUParticles2D.new()
	spark.emitting = false
	spark.amount = 10
	spark.lifetime = 0.25
	spark.explosiveness = 0.95
	spark.one_shot = true
	spark.local_coords = false
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 40.0
	pm.initial_velocity_max = 100.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 2.0
	pm.scale_max = 5.0
	var g = Gradient.new()
	g.set_color(0, Color(0.5, 0.7, 1.0, 1.0))
	g.set_color(1, Color(0.2, 0.4, 0.9, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	spark.process_material = pm
	_get_spawn_root().add_child(spark)
	spark.global_position = pos
	spark.emitting = true
	get_tree().create_timer(0.4).timeout.connect(spark.queue_free)
