@tool
# SkillIceBlade.gd
extends SkillBase
class_name SkillIceBlade

const FRAME_COUNT := 4
const FRAME_SIZE := 64

var _sheet_tex: Texture2D = null
var _frame_textures: Array[AtlasTexture] = []

func _ensure_textures() -> void:
	if _sheet_tex != null:
		return
	_sheet_tex = load("res://assets/sprites/effects/skills/iceblade_sheet.png")
	_frame_textures.clear()
	for i in range(FRAME_COUNT):
		var at = AtlasTexture.new()
		at.atlas = _sheet_tex
		at.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
		_frame_textures.append(at)

func activate() -> void:
	if not owner_player:
		return
	var dir_count = max(4, min(8, level + 3))

	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm: sm.play_shoot()

	_spawn_ice_ring()

	for i in range(dir_count):
		var angle = (TAU / dir_count) * i
		var dir = Vector2(cos(angle), sin(angle))
		_spawn_blade(dir)

func _spawn_ice_ring() -> void:
	var ring = Line2D.new()
	ring.width = 2.5
	ring.default_color = Color(0.5, 0.85, 1.0, 0.7)
	for i in range(33):
		var a = (TAU / 32.0) * i
		ring.add_point(Vector2(cos(a) * 8, sin(a) * 8))
	ring.z_index = 7
	_get_spawn_root().add_child(ring)
	ring.global_position = owner_player.global_position
	var tw = ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(8.0, 8.0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, 0.35)
	tw.tween_callback(ring.queue_free).set_delay(0.35)

func _spawn_blade(dir: Vector2) -> void:
	_ensure_textures()

	var proj = Area2D.new()
	proj.add_to_group("player_projectiles")
	proj.collision_layer = 4
	proj.collision_mask = 2
	proj.monitoring = true

	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 14.0
	col.shape = circle
	proj.add_child(col)

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
	anim.scale = Vector2(0.55, 0.55)
	anim.rotation = dir.angle()
	anim.play()
	proj.add_child(anim)

	var trail = GPUParticles2D.new()
	trail.emitting = true
	trail.amount = 16
	trail.lifetime = 0.35
	trail.explosiveness = 0.0
	trail.local_coords = false
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(-dir.x, -dir.y, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 15.0
	pm.initial_velocity_max = 40.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 2.0
	pm.scale_max = 5.0
	var g = Gradient.new()
	g.set_color(0, Color(0.6, 0.9, 1.0, 0.8))
	g.set_color(1, Color(0.3, 0.6, 1.0, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	trail.process_material = pm
	proj.add_child(trail)

	_get_spawn_root().add_child(proj)
	proj.global_position = owner_player.global_position

	var hit_enemies = {}
	proj.body_entered.connect(func(body):
		if body.is_in_group("enemies") and not hit_enemies.has(body.get_instance_id()):
			hit_enemies[body.get_instance_id()] = true
			deal_damage(body)
			if body.get("base_move_speed") != null and not body.get("is_slowed"):
				var orig_spd = body.base_move_speed
				body.base_move_speed *= 0.6
				get_tree().create_timer(1.5).timeout.connect(func():
					if is_instance_valid(body): body.base_move_speed = orig_spd
				)
	)

	var target_pos = owner_player.global_position + dir * 900
	var skill_ref = self
	var move_tween = proj.create_tween()
	move_tween.tween_property(proj, "global_position", target_pos, 900.0 / 520.0)
	move_tween.tween_callback(func():
		if is_instance_valid(proj) and is_instance_valid(skill_ref):
			skill_ref._spawn_shatter(proj.global_position)
			proj.queue_free()
	)

func _spawn_shatter(pos: Vector2) -> void:
	var burst = GPUParticles2D.new()
	burst.emitting = false
	burst.amount = 16
	burst.lifetime = 0.4
	burst.explosiveness = 0.95
	burst.one_shot = true
	burst.local_coords = false

	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 40.0
	pm.initial_velocity_max = 120.0
	pm.gravity = Vector3(0, 50, 0)
	pm.scale_min = 2.0
	pm.scale_max = 5.0
	pm.angular_velocity_min = -200.0
	pm.angular_velocity_max = 200.0
	var g = Gradient.new()
	g.set_color(0, Color(0.7, 0.9, 1.0, 1.0))
	g.set_color(1, Color(0.3, 0.6, 1.0, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	burst.process_material = pm
	_get_spawn_root().add_child(burst)
	burst.global_position = pos
	burst.emitting = true

	var lv = level if data else 1
	var shatter_radius = 30.0 + lv * 5.0
	for enemy in _get_enemies():
		if not is_instance_valid(enemy): continue
		if enemy.global_position.distance_to(pos) <= shatter_radius:
			deal_damage(enemy, get_current_damage() * 0.3)

	get_tree().create_timer(0.5).timeout.connect(burst.queue_free)
