@tool
# SkillMeteorShower.gd
extends SkillBase
class_name SkillMeteorShower

const FRAME_COUNT := 4
const FRAME_SIZE := 64
const FALL_ANGLE := PI / 2.0

var _sheet_tex: Texture2D = null
var _frame_textures: Array[AtlasTexture] = []
var _expl_tex_1: Texture2D = null
var _expl_tex_2: Texture2D = null

func _ensure_textures() -> void:
	if _sheet_tex != null:
		return
	_sheet_tex = load("res://assets/sprites/effects/skills/meteor_sheet.png")
	_frame_textures.clear()
	for i in range(FRAME_COUNT):
		var at = AtlasTexture.new()
		at.atlas = _sheet_tex
		at.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
		_frame_textures.append(at)

func _get_expl_textures() -> Array[Texture2D]:
	if _expl_tex_1 == null:
		_expl_tex_1 = load("res://assets/sprites/effects/skills/expl_meteor_1.png")
	if _expl_tex_2 == null:
		_expl_tex_2 = load("res://assets/sprites/effects/skills/expl_meteor_2.png")
	return [_expl_tex_1, _expl_tex_2]

func activate() -> void:
	if not owner_player: return
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm: sm.play_explosion()
	EventBus.skill_activated.emit("meteor_shower")
	_start_shower()

func _start_shower() -> void:
	var lv = level if data else 1
	var count = 4 + lv * 2
	var interval = 0.15

	for i in range(count):
		await get_tree().create_timer(interval * i).timeout
		if not is_instance_valid(owner_player): return
		_drop_meteor()

func _drop_meteor() -> void:
	if not owner_player: return
	_ensure_textures()
	var lv = level if data else 1

	var target_pos = owner_player.global_position
	var enemies = _get_enemies()
	var alive = enemies.filter(func(e): return is_instance_valid(e))
	if alive.size() > 0:
		var picked = alive[randi() % alive.size()]
		target_pos = picked.global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
	else:
		target_pos += Vector2(randf_range(-200, 200), randf_range(-200, 200))

	var explode_radius = 48.0 + lv * 8.0
	_spawn_warning_circle(target_pos, explode_radius)

	var meteor = Node2D.new()
	var start_pos = target_pos + Vector2(randf_range(-30, 30), -300)
	meteor.global_position = start_pos
	_get_spawn_root().add_child(meteor)

	var fall_dir = (target_pos - start_pos).normalized()

	var anim = AnimatedSprite2D.new()
	var frames = SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("fall")
	frames.set_animation_speed("fall", 10.0)
	frames.set_animation_loop("fall", true)
	for i in range(FRAME_COUNT):
		frames.add_frame("fall", _frame_textures[i])
	anim.sprite_frames = frames
	anim.animation = "fall"
	anim.scale = Vector2(0.5, 0.5)
	anim.rotation = fall_dir.angle() - FALL_ANGLE
	anim.play()
	meteor.add_child(anim)

	var elapsed := 0.0
	var fall_time := 0.4
	var dmg = get_current_damage()

	while elapsed < fall_time:
		await get_tree().process_frame
		var d = get_process_delta_time()
		elapsed += d
		if not is_instance_valid(meteor): return
		var t = elapsed / fall_time
		meteor.global_position = start_pos.lerp(target_pos, t)

	if is_instance_valid(meteor):
		meteor.queue_free()
	_explode_at(target_pos, explode_radius, dmg)
	_screen_shake()

func _explode_at(pos: Vector2, radius: float, dmg: float) -> void:
	var textures = _get_expl_textures()

	var boom = Node2D.new()
	boom.global_position = pos
	_get_spawn_root().add_child(boom)

	var expl_sprite = Sprite2D.new()
	expl_sprite.texture = textures[randi() % textures.size()]
	expl_sprite.scale = Vector2(radius / 32.0, radius / 32.0)
	boom.add_child(expl_sprite)

	for enemy in _get_enemies():
		if not is_instance_valid(enemy): continue
		if enemy.global_position.distance_to(pos) <= radius:
			deal_damage(enemy, dmg)

	damage_props_in_radius(pos, radius, dmg)

	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm: sm.play_explosion()

	_spawn_explosion_particles(pos, radius)

	var tween = boom.create_tween()
	tween.set_parallel(true)
	tween.tween_property(boom, "scale", Vector2(1.4, 1.4), 0.3)
	tween.tween_property(boom, "modulate:a", 0.0, 0.3)
	tween.tween_callback(boom.queue_free).set_delay(0.3)

func _spawn_warning_circle(pos: Vector2, radius: float) -> void:
	var warning = Node2D.new()
	warning.global_position = pos
	warning.z_index = -1
	_get_spawn_root().add_child(warning)
	var line = Line2D.new()
	line.width = 2.0
	line.default_color = Color(1.0, 0.3, 0.1, 0.6)
	for i in range(33):
		var a = (TAU / 32.0) * i
		line.add_point(Vector2(cos(a) * radius, sin(a) * radius))
	warning.add_child(line)
	var tween = warning.create_tween()
	tween.tween_property(warning, "modulate:a", 0.0, 0.4)
	tween.tween_callback(warning.queue_free)

func _spawn_explosion_particles(pos: Vector2, radius: float) -> void:
	var burst = GPUParticles2D.new()
	burst.emitting = false
	burst.amount = 28
	burst.lifetime = 0.5
	burst.explosiveness = 0.95
	burst.one_shot = true
	burst.local_coords = false
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 60.0
	pm.initial_velocity_max = 180.0
	pm.gravity = Vector3(0, 60, 0)
	pm.scale_min = 3.0
	pm.scale_max = 8.0
	var g = Gradient.new()
	g.set_color(0, Color(1.0, 0.7, 0.2, 1.0))
	g.set_color(1, Color(0.8, 0.2, 0.0, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	burst.process_material = pm
	_get_spawn_root().add_child(burst)
	burst.global_position = pos
	burst.emitting = true
	get_tree().create_timer(0.6).timeout.connect(burst.queue_free)

func _screen_shake() -> void:
	var cam = get_viewport().get_camera_2d()
	if not cam: return
	var orig = cam.offset
	var tween = cam.create_tween()
	for i in range(4):
		var off = Vector2(randf_range(-3, 3), randf_range(-3, 3))
		tween.tween_property(cam, "offset", orig + off, 0.03)
	tween.tween_property(cam, "offset", orig, 0.03)
