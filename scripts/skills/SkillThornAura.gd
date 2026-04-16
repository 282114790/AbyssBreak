@tool
# SkillThornAura.gd
extends SkillBase
class_name SkillThornAura

const REFLECT_RATIO_BASE := 0.5

var _connected := false
var _thorn_tex: Texture2D = null
var _debris_nodes: Array = []

func _get_thorn_texture() -> Texture2D:
	if _thorn_tex == null:
		_thorn_tex = load("res://assets/sprites/effects/skills/area_thorn_ring.png")
	return _thorn_tex

func activate() -> void:
	if not owner_player: return
	_setup_aura()

func _setup_aura() -> void:
	if _connected: return
	_connected = true
	if owner_player.has_signal("took_damage"):
		owner_player.took_damage.connect(_on_player_hit)
	_spawn_aura_visual()

func _on_player_hit(dmg: float, attacker: Node2D) -> void:
	if not is_instance_valid(attacker): return
	var lv = level if data else 1
	var reflect = dmg * (REFLECT_RATIO_BASE + lv * 0.1)
	deal_damage(attacker, reflect)
	_draw_reflect_line(attacker.global_position)
	_flash_thorns()

func _spawn_aura_visual() -> void:
	if not is_instance_valid(owner_player): return
	var aura = Node2D.new()
	aura.name = "ThornAura"
	aura.z_index = 2
	owner_player.add_child(aura)

	var lv = level if data else 1
	var sprite = Sprite2D.new()
	sprite.texture = _get_thorn_texture()
	var aura_scale = (0.3 + lv * 0.05)
	sprite.scale = Vector2(aura_scale, aura_scale)
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.7)
	aura.add_child(sprite)

	var orbit_particles = GPUParticles2D.new()
	orbit_particles.emitting = true
	orbit_particles.amount = 8
	orbit_particles.lifetime = 1.2
	orbit_particles.explosiveness = 0.0
	orbit_particles.local_coords = false
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 15.0
	pm.gravity = Vector3(0, -10, 0)
	pm.scale_min = 1.5
	pm.scale_max = 3.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_radius = 30.0
	pm.emission_ring_inner_radius = 20.0
	pm.emission_ring_height = 0.0
	pm.emission_ring_axis = Vector3(0, 0, 1)
	var g = Gradient.new()
	g.set_color(0, Color(0.3, 0.8, 0.2, 0.6))
	g.set_color(1, Color(0.2, 0.5, 0.1, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	orbit_particles.process_material = pm
	aura.add_child(orbit_particles)

	_debris_nodes.clear()
	var debris_count = 4 + int(lv / 2)
	for i in range(debris_count):
		var debris = Sprite2D.new()
		var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.3, 0.7, 0.2))
		debris.texture = ImageTexture.create_from_image(img)
		debris.scale = Vector2(0.8 + randf() * 0.4, 0.8 + randf() * 0.4)
		debris.modulate = Color(0.4, 0.8, 0.3, 0.7)
		debris.z_index = 3
		aura.add_child(debris)
		_debris_nodes.append({"node": debris, "angle": TAU / debris_count * i, "radius": 25.0 + randf() * 10.0, "phase": randf() * TAU})

func _draw_reflect_line(target_pos: Vector2) -> void:
	if not is_instance_valid(owner_player): return
	var from = owner_player.global_position
	var to = target_pos

	var line = Line2D.new()
	line.width = 3.0
	line.default_color = Color(0.3, 1.0, 0.3, 0.8)
	var seg = 6
	for i in range(seg + 1):
		var t = float(i) / seg
		var base = from.lerp(to, t)
		var perp = (to - from).rotated(PI / 2.0).normalized()
		var wave = perp * sin(t * PI * 3) * 8.0
		line.add_point(base + wave)
	line.z_index = 10
	_get_spawn_root().add_child(line)
	var tween = line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.25)
	tween.tween_callback(line.queue_free)

	var vine_particles = GPUParticles2D.new()
	vine_particles.emitting = false
	vine_particles.amount = 12
	vine_particles.lifetime = 0.3
	vine_particles.explosiveness = 0.9
	vine_particles.one_shot = true
	vine_particles.local_coords = false
	var pm = ParticleProcessMaterial.new()
	var dir3 = Vector3((to - from).normalized().x, (to - from).normalized().y, 0)
	pm.direction = dir3
	pm.spread = 30.0
	pm.initial_velocity_min = 60.0
	pm.initial_velocity_max = 150.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 1.5
	pm.scale_max = 4.0
	var g = Gradient.new()
	g.set_color(0, Color(0.4, 1.0, 0.3, 0.9))
	g.set_color(1, Color(0.2, 0.6, 0.1, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	vine_particles.process_material = pm
	_get_spawn_root().add_child(vine_particles)
	vine_particles.global_position = from
	vine_particles.emitting = true
	get_tree().create_timer(0.4).timeout.connect(vine_particles.queue_free)

func _flash_thorns() -> void:
	if not is_instance_valid(owner_player): return
	var aura = owner_player.get_node_or_null("ThornAura")
	if not aura: return
	aura.modulate = Color(0.3, 1.0, 0.3, 1.0)
	var scale_tween = aura.create_tween()
	scale_tween.tween_property(aura, "scale", Vector2(1.3, 1.3), 0.08)
	scale_tween.tween_property(aura, "scale", Vector2(1.0, 1.0), 0.12)
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(aura):
		aura.modulate = Color(1.0, 1.0, 1.0, 0.7)

var _pulse_time := 0.0

func _process(delta: float) -> void:
	cooldown_timer -= delta
	if not is_instance_valid(owner_player): return
	_pulse_time += delta
	var aura = owner_player.get_node_or_null("ThornAura")
	if aura:
		aura.rotation += delta * 0.8
		var pulse = 0.95 + sin(_pulse_time * 2.0) * 0.05
		aura.scale = Vector2(pulse, pulse)
		var alpha = 0.6 + sin(_pulse_time * 3.0) * 0.1
		aura.modulate.a = alpha

	for d in _debris_nodes:
		if not is_instance_valid(d["node"]): continue
		d["angle"] += delta * 1.5
		var float_y = sin(_pulse_time * 2.5 + d["phase"]) * 5.0
		var r = d["radius"]
		d["node"].position = Vector2(cos(d["angle"]) * r, sin(d["angle"]) * r + float_y)
