@tool
# SkillFrostZone.gd
extends SkillBase
class_name SkillFrostZone

var zone: Area2D = null
var tick_timer: float = 0.0
var slowed_enemies: Array = []
var crystal_timer: float = 0.0
var _frost_tex: Texture2D = null
var _crystal_tex: Texture2D = null

func _get_frost_texture() -> Texture2D:
	if _frost_tex == null:
		_frost_tex = load("res://assets/sprites/effects/skills/area_frost_ground.png")
	return _frost_tex

func _get_crystal_texture() -> Texture2D:
	if _crystal_tex == null:
		_crystal_tex = load("res://assets/sprites/effects/skills/particle_ice_crystal.png")
	return _crystal_tex

func _ready() -> void:
	call_deferred("_create_zone")

func _create_zone() -> void:
	if zone != null and is_instance_valid(zone):
		zone.queue_free()
	slowed_enemies.clear()

	zone = Area2D.new()

	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = _get_radius()
	col.shape = circle
	zone.add_child(col)

	var r = _get_radius()
	var sprite = Sprite2D.new()
	sprite.texture = _get_frost_texture()
	sprite.scale = Vector2(r / 64.0, r / 64.0)
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.6)
	zone.add_child(sprite)

	var edge_line = Line2D.new()
	edge_line.width = 2.0
	edge_line.default_color = Color(0.5, 0.8, 1.0, 0.5)
	edge_line.joint_mode = Line2D.LINE_JOINT_ROUND
	for i in range(65):
		var a = (TAU / 64.0) * i
		edge_line.add_point(Vector2(cos(a) * r, sin(a) * r))
	zone.add_child(edge_line)

	var fog = GPUParticles2D.new()
	fog.emitting = true
	fog.amount = 20
	fog.lifetime = 1.2
	fog.local_coords = true
	var pm = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = r * 0.8
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 10.0
	pm.gravity = Vector3(0, -8, 0)
	pm.scale_min = 4.0
	pm.scale_max = 10.0
	var g = Gradient.new()
	g.set_color(0, Color(0.6, 0.85, 1.0, 0.4))
	g.set_color(1, Color(0.4, 0.7, 1.0, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	fog.process_material = pm
	zone.add_child(fog)

	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)

	if owner_player != null:
		owner_player.add_child(zone)
	else:
		_get_spawn_root().add_child(zone)

func _get_radius() -> float:
	if data != null:
		return 80.0 + level * 15.0
	return 80.0

func _get_current_radius() -> float:
	return _get_radius()

func _process(delta: float) -> void:
	if EventBus.game_logic_paused:
		return
	_clean_invalid_slowed()

	tick_timer -= delta
	if tick_timer <= 0.0:
		tick_timer = data.cooldown if data != null else 0.5
		_apply_tick_damage()

	crystal_timer -= delta
	if crystal_timer <= 0:
		crystal_timer = 0.3
		_spawn_crystal()

func _apply_tick_damage() -> void:
	if zone == null or not is_instance_valid(zone):
		return
	var bodies = zone.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("enemies"):
			deal_damage(body)

func _spawn_crystal() -> void:
	if not owner_player:
		return
	var radius = _get_current_radius()
	var angle = randf() * TAU
	var dist = randf() * radius
	var spawn_pos = owner_player.global_position + Vector2(cos(angle), sin(angle)) * dist

	var crystal = Sprite2D.new()
	crystal.texture = _get_crystal_texture()
	crystal.scale = Vector2(0.5, 0.5)
	crystal.global_position = spawn_pos
	crystal.z_index = 5
	crystal.modulate = Color(0.6, 0.9, 1.0, 0.8)
	_get_spawn_root().add_child(crystal)

	var tween = crystal.create_tween()
	tween.set_parallel(true)
	tween.tween_property(crystal, "rotation_degrees", 180.0, 0.6)
	tween.tween_property(crystal, "position:y", crystal.position.y - 20, 0.6)
	tween.tween_property(crystal, "modulate:a", 0.0, 0.6)
	tween.tween_callback(crystal.queue_free).set_delay(0.6)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return
	var uid = body.get_instance_id()
	if uid in slowed_enemies:
		return
	slowed_enemies.append(uid)
	if body.get("visual") != null and is_instance_valid(body.visual):
		body.visual.modulate = Color(0.5, 0.7, 1.0)
	if body.get("is_slowed") != null and not body.is_slowed:
		body.is_slowed = true
		if body.get("base_move_speed") != null:
			body.set_meta("frost_original_speed", body.base_move_speed)
			body.base_move_speed = body.base_move_speed * 0.5

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return
	var uid = body.get_instance_id()
	if uid not in slowed_enemies:
		return
	slowed_enemies.erase(uid)
	if body.get("visual") != null and is_instance_valid(body.visual):
		body.visual.modulate = Color(1.0, 1.0, 1.0)
	if body.get("is_slowed") != null:
		body.is_slowed = false
	if body.has_meta("frost_original_speed"):
		body.base_move_speed = body.get_meta("frost_original_speed")
		body.remove_meta("frost_original_speed")

func _clean_invalid_slowed() -> void:
	var to_remove: Array = []
	for uid in slowed_enemies:
		var obj = instance_from_id(uid)
		if not is_instance_valid(obj):
			to_remove.append(uid)
	for uid in to_remove:
		slowed_enemies.erase(uid)

func on_level_up() -> void:
	_create_zone()
