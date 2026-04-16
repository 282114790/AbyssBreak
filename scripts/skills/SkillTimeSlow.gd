@tool
# SkillTimeSlow.gd
extends SkillBase
class_name SkillTimeSlow

const SLOW_RATIO := 0.2
var _active := false
var _time_aura_tex: Texture2D = null
var _time_particle_tex: Texture2D = null

func _get_time_aura_texture() -> Texture2D:
	if _time_aura_tex == null:
		_time_aura_tex = load("res://assets/sprites/effects/skills/area_time_aura.png")
	return _time_aura_tex

func _get_time_particle_texture() -> Texture2D:
	if _time_particle_tex == null:
		_time_particle_tex = load("res://assets/sprites/effects/skills/particle_time_fragment.png")
	return _time_particle_tex

func activate() -> void:
	if not owner_player or _active: return
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm: sm.play_shoot()
	_do_slow()

func _do_slow() -> void:
	_active = true
	var lv = level if data else 1
	var duration = 2.0 + lv * 0.5

	_show_slow_vfx(duration)

	var original_speeds := {}
	var slowed_set := {}

	var _apply_slow = func(enemy: Node) -> void:
		if not is_instance_valid(enemy): return
		if slowed_set.has(enemy.get_instance_id()): return
		slowed_set[enemy.get_instance_id()] = true
		if "speed" in enemy:
			original_speeds[enemy] = enemy.speed
			enemy.speed *= SLOW_RATIO
		elif "move_speed" in enemy:
			original_speeds[enemy] = enemy.move_speed
			enemy.move_speed *= SLOW_RATIO
		if enemy.get("visual") != null and is_instance_valid(enemy.visual):
			enemy.visual.modulate = Color(0.5, 0.7, 1.0)

	for enemy in _get_enemies():
		_apply_slow.call(enemy)

	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		for enemy in _get_enemies():
			_apply_slow.call(enemy)

	for enemy in original_speeds:
		if not is_instance_valid(enemy): continue
		if "speed" in enemy:
			enemy.speed = original_speeds[enemy]
		elif "move_speed" in enemy:
			enemy.move_speed = original_speeds[enemy]
		if enemy.get("visual") != null and is_instance_valid(enemy.visual):
			enemy.visual.modulate = Color(1.0, 1.0, 1.0)

	_active = false

func _show_slow_vfx(duration: float) -> void:
	if not owner_player: return
	var vfx = Node2D.new()
	vfx.global_position = owner_player.global_position
	vfx.z_index = 5
	_get_spawn_root().add_child(vfx)

	var sprite = Sprite2D.new()
	sprite.texture = _get_time_aura_texture()
	sprite.scale = Vector2(0.8, 0.8)
	sprite.modulate = Color(1.0, 0.95, 0.7, 0.6)
	vfx.add_child(sprite)

	var particles = GPUParticles2D.new()
	particles.emitting = true
	particles.amount = 12
	particles.lifetime = 1.0
	particles.local_coords = false
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 10.0
	pm.initial_velocity_max = 30.0
	pm.gravity = Vector3(0, -15, 0)
	pm.scale_min = 0.8
	pm.scale_max = 1.5
	var g = Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.5, 0.8))
	g.set_color(1, Color(1.0, 0.8, 0.3, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	particles.process_material = pm
	particles.texture = _get_time_particle_texture()
	vfx.add_child(particles)

	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if not is_instance_valid(vfx): return
		vfx.global_position = owner_player.global_position
		sprite.rotation += get_process_delta_time() * 0.5
		var pulse = 0.5 + sin(elapsed * 3.0) * 0.2
		vfx.modulate = Color(1.0, 0.95, 0.7, pulse * (1.0 - elapsed / duration))

	if is_instance_valid(vfx):
		vfx.queue_free()
