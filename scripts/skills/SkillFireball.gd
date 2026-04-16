@tool
# SkillFireball.gd
extends SkillBase
class_name SkillFireball

const FRAME_COUNT := 4
const FRAME_SIZE := 64

var _sheet_tex: Texture2D = null
var _frame_textures: Array[AtlasTexture] = []

func _ensure_textures() -> void:
	if _sheet_tex != null:
		return
	_sheet_tex = load("res://assets/sprites/effects/skills/fireball_sheet.png")
	_frame_textures.clear()
	for i in range(FRAME_COUNT):
		var at = AtlasTexture.new()
		at.atlas = _sheet_tex
		at.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
		_frame_textures.append(at)

func activate() -> void:
	if not owner_player or not is_instance_valid(owner_player):
		return
	var target = get_nearest_enemy()
	if not target:
		return
	var shoot_count = level
	var base_dir = owner_player.global_position.direction_to(target.global_position)
	var base_angle = base_dir.angle()
	var spread = deg_to_rad(15.0)
	for i in range(shoot_count):
		var offset = 0.0
		if shoot_count > 1:
			offset = spread * (i - (shoot_count - 1) / 2.0)
		var dir = Vector2(cos(base_angle + offset), sin(base_angle + offset))
		_spawn_projectile_dir(dir)
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm:
		sm.play_shoot()

func _spawn_projectile_dir(dir: Vector2) -> void:
	_ensure_textures()

	var proj = Area2D.new()
	proj.set_script(load("res://scripts/skills/Projectile.gd"))
	proj.add_to_group("player_projectiles")

	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 10.0
	col.shape = circle
	proj.add_child(col)

	var anim = AnimatedSprite2D.new()
	var frames = SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("fly")
	frames.set_animation_speed("fly", 12.0)
	frames.set_animation_loop("fly", true)
	for i in range(FRAME_COUNT):
		frames.add_frame("fly", _frame_textures[i])
	anim.sprite_frames = frames
	anim.animation = "fly"
	anim.scale = Vector2(0.55, 0.55)
	anim.rotation = dir.angle()
	anim.play()
	proj.add_child(anim)

	var trail = GPUParticles2D.new()
	trail.emitting = true
	trail.amount = 28
	trail.lifetime = 0.45
	trail.explosiveness = 0.0
	trail.randomness = 0.2
	trail.local_coords = false

	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(-1, 0, 0)
	pm.spread = 30.0
	pm.initial_velocity_min = 25.0
	pm.initial_velocity_max = 70.0
	pm.gravity = Vector3(0, 0, 0)
	pm.scale_min = 2.5
	pm.scale_max = 7.0
	var grad = Gradient.new()
	grad.set_color(0, Color(1.0, 0.8, 0.1, 0.9))
	grad.set_color(1, Color(0.8, 0.1, 0.0, 0.0))
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = grad
	pm.color_ramp = grad_tex
	trail.process_material = pm
	proj.add_child(trail)
	proj.move_child(trail, 0)

	_get_spawn_root().add_child(proj)
	proj.global_position = owner_player.global_position

	var angle_deg = rad_to_deg(dir.angle()) + 180.0
	trail.rotation_degrees = angle_deg

	proj.setup_dir(get_current_damage(), dir, data.speed if data else 350.0, data.pierce_count if data else 1)
	proj.owner_skill = self

	proj.body_entered.connect(func(body):
		if body.is_in_group("enemies"):
			_on_fireball_impact(proj.global_position)
	)

func _on_fireball_impact(pos: Vector2) -> void:
	var lv = level if data else 1
	var explode_radius = 40.0 + lv * 10.0
	var explode_dmg = get_current_damage() * 0.4

	var ring = Line2D.new()
	ring.width = 3.0
	ring.default_color = Color(1.0, 0.6, 0.1, 0.8)
	for i in range(25):
		var a = (TAU / 24.0) * i
		ring.add_point(Vector2(cos(a) * 5, sin(a) * 5))
	ring.z_index = 8
	_get_spawn_root().add_child(ring)
	ring.global_position = pos
	var ring_tw = ring.create_tween()
	ring_tw.set_parallel(true)
	ring_tw.tween_property(ring, "scale", Vector2(explode_radius / 5.0, explode_radius / 5.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring_tw.tween_property(ring, "modulate:a", 0.0, 0.2)
	ring_tw.tween_callback(ring.queue_free).set_delay(0.2)

	var burst = GPUParticles2D.new()
	burst.emitting = false
	burst.amount = 20
	burst.lifetime = 0.35
	burst.explosiveness = 0.95
	burst.one_shot = true
	burst.local_coords = false
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 50.0
	pm.initial_velocity_max = 140.0
	pm.gravity = Vector3(0, 40, 0)
	pm.scale_min = 2.5
	pm.scale_max = 6.0
	var g = Gradient.new()
	g.set_color(0, Color(1.0, 0.8, 0.2, 1.0))
	g.set_color(1, Color(0.9, 0.2, 0.0, 0.0))
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
		if enemy.global_position.distance_to(pos) <= explode_radius:
			deal_damage(enemy, explode_dmg)

	_spawn_scorch(pos, explode_radius * 0.7)

func _spawn_scorch(pos: Vector2, radius: float) -> void:
	var scorch = Node2D.new()
	scorch.global_position = pos
	scorch.z_index = -2
	_get_spawn_root().add_child(scorch)

	var circle = Line2D.new()
	circle.width = radius * 1.2
	circle.default_color = Color(0.3, 0.15, 0.0, 0.25)
	circle.add_point(Vector2(-radius * 0.3, 0))
	circle.add_point(Vector2(radius * 0.3, 0))
	scorch.add_child(circle)

	var glow = Line2D.new()
	glow.width = 1.5
	glow.default_color = Color(1.0, 0.4, 0.0, 0.3)
	for i in range(17):
		var a = (TAU / 16.0) * i
		glow.add_point(Vector2(cos(a) * radius, sin(a) * radius))
	scorch.add_child(glow)

	var fade = scorch.create_tween()
	fade.tween_property(scorch, "modulate:a", 0.0, 1.5)
	fade.tween_callback(scorch.queue_free)
