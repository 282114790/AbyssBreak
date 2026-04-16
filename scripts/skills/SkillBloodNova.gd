@tool
# SkillBloodNova.gd
extends SkillBase
class_name SkillBloodNova

const HP_COST_RATIO := 0.05

var _nova_tex: Texture2D = null

func _get_nova_texture() -> Texture2D:
	if _nova_tex == null:
		_nova_tex = load("res://assets/sprites/effects/skills/area_blood_nova.png")
	return _nova_tex

func activate() -> void:
	if not owner_player: return
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm: sm.play_explosion()
	_spend_hp_and_blast()

func _spend_hp_and_blast() -> void:
	var lv = level if data else 1
	var cost = owner_player.max_hp * HP_COST_RATIO
	cost = max(cost, 1.0)
	owner_player.take_damage(cost)

	var nova = Node2D.new()
	nova.global_position = owner_player.global_position
	_get_spawn_root().add_child(nova)

	var sprite = Sprite2D.new()
	sprite.texture = _get_nova_texture()
	sprite.scale = Vector2(0.3, 0.3)
	sprite.modulate = Color(1.0, 0.3, 0.3, 0.9)
	nova.add_child(sprite)

	var radius = 120.0 + lv * 20.0
	var dmg_base = get_current_damage() * (1.0 + cost / 10.0)

	for enemy in _get_enemies():
		if not is_instance_valid(enemy): continue
		if enemy.global_position.distance_to(owner_player.global_position) <= radius:
			deal_damage(enemy, dmg_base)

	_spawn_blood_particles(owner_player.global_position, radius)
	_animate_nova(nova, radius)
	_screen_shake()

func _animate_nova(nova: Node2D, radius: float) -> void:
	var target_scale = radius / 64.0 * 2.0
	var tween = nova.create_tween()
	tween.set_parallel(true)
	tween.tween_property(nova, "scale", Vector2(target_scale, target_scale), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(nova, "modulate:a", 0.0, 0.5)
	tween.tween_callback(nova.queue_free).set_delay(0.5)

func _spawn_blood_particles(pos: Vector2, radius: float) -> void:
	var burst = GPUParticles2D.new()
	burst.emitting = false
	burst.amount = 40 + level * 6
	burst.lifetime = 0.6
	burst.explosiveness = 0.9
	burst.one_shot = true
	burst.local_coords = false
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 100.0
	pm.initial_velocity_max = 280.0
	pm.gravity = Vector3(0, 80, 0)
	pm.scale_min = 3.0
	pm.scale_max = 8.0
	var g = Gradient.new()
	g.set_color(0, Color(1.0, 0.2, 0.1, 1.0))
	g.set_color(1, Color(0.5, 0.0, 0.0, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	burst.process_material = pm
	_get_spawn_root().add_child(burst)
	burst.global_position = pos
	burst.emitting = true
	get_tree().create_timer(0.8).timeout.connect(burst.queue_free)

func _screen_shake() -> void:
	var cam = get_viewport().get_camera_2d()
	if not cam: return
	var orig = cam.offset
	var tween = cam.create_tween()
	for i in range(6):
		var off = Vector2(randf_range(-4, 4), randf_range(-4, 4))
		tween.tween_property(cam, "offset", orig + off, 0.03)
	tween.tween_property(cam, "offset", orig, 0.03)
