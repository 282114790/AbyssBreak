@tool
# SkillPoisonCloud.gd
extends SkillBase
class_name SkillPoisonCloud

const CLOUD_RADIUS_BASE := 80.0
const TICK_INTERVAL := 0.5

var _tick_timer := 0.0
var _cloud_visual: Node2D = null
var _pulse_time := 0.0
var _poison_tex_a: Texture2D = null
var _poison_tex_b: Texture2D = null

func _get_poison_textures() -> Array[Texture2D]:
	if _poison_tex_a == null:
		_poison_tex_a = load("res://assets/sprites/effects/skills/area_poison_a.png")
	if _poison_tex_b == null:
		_poison_tex_b = load("res://assets/sprites/effects/skills/area_poison_b.png")
	return [_poison_tex_a, _poison_tex_b]

func activate() -> void:
	if not owner_player: return
	_spawn_cloud()

func _spawn_cloud() -> void:
	if is_instance_valid(_cloud_visual):
		_cloud_visual.queue_free()

	var lv = _get_level()
	var radius = CLOUD_RADIUS_BASE + lv * 15.0
	var textures = _get_poison_textures()

	_cloud_visual = Node2D.new()
	_cloud_visual.z_index = -1
	owner_player.add_child(_cloud_visual)

	var sprite_a = Sprite2D.new()
	sprite_a.texture = textures[0]
	sprite_a.scale = Vector2(radius / 64.0, radius / 64.0)
	sprite_a.modulate = Color(1.0, 1.0, 1.0, 0.55)
	_cloud_visual.add_child(sprite_a)

	var sprite_b = Sprite2D.new()
	sprite_b.texture = textures[1]
	sprite_b.scale = Vector2(radius / 80.0, radius / 80.0)
	sprite_b.modulate = Color(0.8, 1.0, 0.8, 0.4)
	sprite_b.position = Vector2(radius * 0.15, radius * 0.1)
	_cloud_visual.add_child(sprite_b)

	var smoke = GPUParticles2D.new()
	smoke.emitting = true
	smoke.amount = 16
	smoke.lifetime = 1.0
	smoke.local_coords = true
	var pm = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radius * 0.6
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 15.0
	pm.gravity = Vector3(0, -10, 0)
	pm.scale_min = 5.0
	pm.scale_max = 12.0
	var g = Gradient.new()
	g.set_color(0, Color(0.3, 0.8, 0.1, 0.35))
	g.set_color(1, Color(0.1, 0.5, 0.0, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	smoke.process_material = pm
	_cloud_visual.add_child(smoke)

func _process(delta: float) -> void:
	_pulse_time += delta
	if is_instance_valid(_cloud_visual):
		var pulse = 0.9 + sin(_pulse_time * 2.5) * 0.1
		_cloud_visual.scale = Vector2(pulse, pulse)
		for i in range(_cloud_visual.get_child_count()):
			var child = _cloud_visual.get_child(i)
			child.rotation += delta * (0.3 if i == 0 else -0.2)

	cooldown_timer -= delta
	if cooldown_timer > 0: return
	_tick_timer += delta
	if _tick_timer < TICK_INTERVAL: return
	_tick_timer = 0.0
	_do_poison_tick()

func _do_poison_tick() -> void:
	if not owner_player: return
	var lv = _get_level()
	var radius = CLOUD_RADIUS_BASE + lv * 15.0
	var dmg = get_current_damage() * 0.5

	for enemy in _get_enemies():
		if not is_instance_valid(enemy): continue
		if enemy.global_position.distance_to(owner_player.global_position) <= radius:
			deal_damage(enemy, dmg)
			if enemy.get("visual") != null and is_instance_valid(enemy.visual):
				enemy.visual.modulate = Color(0.6, 1.0, 0.4)
				get_tree().create_timer(0.8).timeout.connect(func():
					if is_instance_valid(enemy) and is_instance_valid(enemy.visual):
						enemy.visual.modulate = Color(1, 1, 1)
				)

func _get_level() -> int:
	return level if data else 1
