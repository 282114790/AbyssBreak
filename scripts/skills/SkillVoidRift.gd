@tool
# SkillVoidRift.gd
extends SkillBase
class_name SkillVoidRift

const RIFT_DURATION := 4.0
const PULL_FORCE := 120.0
const RIFT_RADIUS := 100.0

var _vortex_tex: Texture2D = null

func _get_vortex_texture() -> Texture2D:
	if _vortex_tex == null:
		_vortex_tex = load("res://assets/sprites/effects/skills/area_void_vortex.png")
	return _vortex_tex

func activate() -> void:
	if not owner_player: return
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm: sm.play_shoot()
	EventBus.skill_activated.emit("void_rift")
	_spawn_rift()

func _spawn_rift() -> void:
	var lv = level if data else 1
	var count = 1 + lv / 3

	for i in range(count):
		var angle = TAU * i / count + randf() * 0.5
		var dist = randf_range(80, 160)
		var pos = owner_player.global_position + Vector2(cos(angle), sin(angle)) * dist
		_create_rift_at(pos)

func _create_rift_at(pos: Vector2) -> void:
	var lv = level if data else 1
	var rift = Node2D.new()
	rift.global_position = pos
	_get_spawn_root().add_child(rift)

	var sprite = Sprite2D.new()
	sprite.texture = _get_vortex_texture()
	sprite.scale = Vector2(0.8, 0.8)
	sprite.modulate = Color(0.8, 0.6, 1.0, 0.85)
	rift.add_child(sprite)

	var suction = GPUParticles2D.new()
	suction.emitting = true
	suction.amount = 24
	suction.lifetime = 0.8
	suction.local_coords = true
	var pm = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_radius = RIFT_RADIUS
	pm.emission_ring_inner_radius = RIFT_RADIUS * 0.8
	pm.emission_ring_height = 0.0
	pm.emission_ring_axis = Vector3(0, 0, 1)
	pm.direction = Vector3(0, 0, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = -60.0
	pm.initial_velocity_max = -30.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 2.0
	pm.scale_max = 5.0
	var g = Gradient.new()
	g.set_color(0, Color(0.6, 0.3, 1.0, 0.7))
	g.set_color(1, Color(0.3, 0.0, 0.6, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	suction.process_material = pm
	rift.add_child(suction)

	var glow = Sprite2D.new()
	glow.texture = _get_vortex_texture()
	glow.scale = Vector2(1.2, 1.2)
	glow.modulate = Color(0.5, 0.2, 0.8, 0.25)
	rift.add_child(glow)

	var duration = RIFT_DURATION + lv * 0.5
	var dmg = get_current_damage()
	_run_rift_logic(rift, sprite, duration, dmg)

func _run_rift_logic(rift: Node2D, sprite: Sprite2D, duration: float, dmg: float) -> void:
	var elapsed := 0.0
	var tick := 0.0

	while elapsed < duration:
		await get_tree().process_frame
		var d = get_process_delta_time()
		elapsed += d
		tick += d

		if not is_instance_valid(rift):
			return

		sprite.rotation += d * 3.0

		if tick >= 0.3:
			tick = 0.0
			for enemy in _get_enemies():
				if not is_instance_valid(enemy): continue
				var dist = enemy.global_position.distance_to(rift.global_position)
				if dist < RIFT_RADIUS:
					var dir = (rift.global_position - enemy.global_position).normalized()
					var pull = PULL_FORCE * 0.3 * (1.0 + level * 0.15)
					enemy.global_position += dir * pull
					deal_damage(enemy, dmg * 0.4)

		var fade = 1.0 - (elapsed / duration)
		if is_instance_valid(rift):
			rift.modulate.a = fade

	if is_instance_valid(rift):
		rift.queue_free()
