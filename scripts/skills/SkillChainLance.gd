@tool
# SkillChainLance.gd
extends SkillBase
class_name SkillChainLance

const FRAME_COUNT := 4
const FRAME_SIZE := 64

var _sheet_tex: Texture2D = null
var _frame_textures: Array[AtlasTexture] = []

func _ensure_textures() -> void:
	if _sheet_tex != null:
		return
	_sheet_tex = load("res://assets/sprites/effects/skills/lance_sheet.png")
	_frame_textures.clear()
	for i in range(FRAME_COUNT):
		var at = AtlasTexture.new()
		at.atlas = _sheet_tex
		at.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
		_frame_textures.append(at)

func activate() -> void:
	if not owner_player: return
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm: sm.play_shoot()
	_fire_lance()

func _fire_lance() -> void:
	_ensure_textures()
	var lv = level if data else 1
	var enemies = _get_enemies()
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
	_get_spawn_root().add_child(lance)

	var anim = AnimatedSprite2D.new()
	var frames = SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("fly")
	frames.set_animation_speed("fly", 10.0)
	frames.set_animation_loop("fly", true)
	for i in range(FRAME_COUNT):
		frames.add_frame("fly", _frame_textures[i])
	anim.sprite_frames = frames
	anim.animation = "fly"
	anim.scale = Vector2(0.7, 0.5)
	anim.rotation = direction.angle()
	anim.play()
	lance.add_child(anim)

	var trail = GPUParticles2D.new()
	trail.emitting = true
	trail.amount = 16
	trail.lifetime = 0.3
	trail.explosiveness = 0.0
	trail.local_coords = false
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(-direction.x, -direction.y, 0)
	pm.spread = 20.0
	pm.initial_velocity_min = 10.0
	pm.initial_velocity_max = 30.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 2.0
	pm.scale_max = 5.0
	var g = Gradient.new()
	g.set_color(0, Color(0.8, 1.0, 0.3, 0.7))
	g.set_color(1, Color(0.4, 0.7, 0.1, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	trail.process_material = pm
	lance.add_child(trail)

	var speed = 500.0 + lv * 30.0
	var max_pierce = 2 + lv
	var dmg = get_current_damage()
	var hit_set = {}
	var elapsed := 0.0

	var pulse_time := 0.0
	while elapsed < 2.0:
		await get_tree().process_frame
		var d = get_process_delta_time()
		elapsed += d
		pulse_time += d
		if not is_instance_valid(lance): return
		lance.global_position += direction * speed * d

		var pulse = 0.85 + sin(pulse_time * 12.0) * 0.15
		anim.modulate = Color(pulse * 1.2, pulse * 1.1, pulse * 0.8, 1.0)

		for enemy in _get_enemies():
			if not is_instance_valid(enemy): continue
			if hit_set.has(enemy): continue
			if lance.global_position.distance_to(enemy.global_position) < 28:
				hit_set[enemy] = true
				deal_damage(enemy)
				_spawn_pierce_spark(lance.global_position)
				if hit_set.size() >= max_pierce: break

		if hit_set.size() >= max_pierce: break
		if lance.global_position.distance_to(owner_player.global_position) > 900: break

	if is_instance_valid(lance):
		_spawn_end_burst(lance.global_position, dmg * 0.5, lv)
		lance.queue_free()

func _spawn_pierce_spark(pos: Vector2) -> void:
	var spark = GPUParticles2D.new()
	spark.emitting = false
	spark.amount = 10
	spark.lifetime = 0.2
	spark.explosiveness = 0.95
	spark.one_shot = true
	spark.local_coords = false
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 40.0
	pm.initial_velocity_max = 100.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 1.5
	pm.scale_max = 4.0
	var g = Gradient.new()
	g.set_color(0, Color(1.0, 1.0, 0.6, 1.0))
	g.set_color(1, Color(0.8, 1.0, 0.3, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	spark.process_material = pm
	_get_spawn_root().add_child(spark)
	spark.global_position = pos
	spark.emitting = true
	get_tree().create_timer(0.3).timeout.connect(spark.queue_free)

func _spawn_end_burst(pos: Vector2, dmg: float, lv: int) -> void:
	var burst_radius = 35.0 + lv * 8.0

	var ring = Line2D.new()
	ring.width = 2.5
	ring.default_color = Color(0.9, 1.0, 0.4, 0.8)
	for i in range(25):
		var a = (TAU / 24.0) * i
		ring.add_point(Vector2(cos(a) * 5, sin(a) * 5))
	ring.z_index = 8
	_get_spawn_root().add_child(ring)
	ring.global_position = pos
	var tw = ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(burst_radius / 5.0, burst_radius / 5.0), 0.18)
	tw.tween_property(ring, "modulate:a", 0.0, 0.22)
	tw.tween_callback(ring.queue_free).set_delay(0.22)

	var burst = GPUParticles2D.new()
	burst.emitting = false
	burst.amount = 16
	burst.lifetime = 0.35
	burst.explosiveness = 0.95
	burst.one_shot = true
	burst.local_coords = false
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 50.0
	pm.initial_velocity_max = 130.0
	pm.gravity = Vector3(0, 30, 0)
	pm.scale_min = 2.0
	pm.scale_max = 5.0
	var g = Gradient.new()
	g.set_color(0, Color(0.9, 1.0, 0.5, 1.0))
	g.set_color(1, Color(0.5, 0.8, 0.1, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	burst.process_material = pm
	_get_spawn_root().add_child(burst)
	burst.global_position = pos
	burst.emitting = true
	get_tree().create_timer(0.5).timeout.connect(burst.queue_free)

	for enemy in _get_enemies():
		if not is_instance_valid(enemy): continue
		if enemy.global_position.distance_to(pos) <= burst_radius:
			deal_damage(enemy, dmg)
