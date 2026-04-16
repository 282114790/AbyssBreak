@tool
# SkillRuneBlast.gd
extends SkillBase
class_name SkillRuneBlast

var explosion_radius: float = 100.0
var _rune_tex: Texture2D = null
var _expl_tex_1: Texture2D = null
var _expl_tex_2: Texture2D = null

func _get_rune_texture() -> Texture2D:
	if _rune_tex == null:
		_rune_tex = load("res://assets/sprites/effects/skills/area_rune_circle.png")
	return _rune_tex

func _get_expl_textures() -> Array[Texture2D]:
	if _expl_tex_1 == null:
		_expl_tex_1 = load("res://assets/sprites/effects/skills/expl_rune_1.png")
	if _expl_tex_2 == null:
		_expl_tex_2 = load("res://assets/sprites/effects/skills/expl_rune_2.png")
	return [_expl_tex_1, _expl_tex_2]

func activate() -> void:
	var enemies = _get_enemies()
	if enemies.is_empty():
		return
	var best_pos = _find_densest_cluster(enemies)
	_spawn_rune(best_pos)

func _find_densest_cluster(enemies: Array) -> Vector2:
	var best_pos = enemies[0].global_position
	var best_count = 0
	for e in enemies:
		if not is_instance_valid(e): continue
		var count = 0
		for other in enemies:
			if not is_instance_valid(other): continue
			if e.global_position.distance_to(other.global_position) < explosion_radius * 2.5:
				count += 1
		if count > best_count:
			best_count = count
			best_pos = e.global_position
	return best_pos

func _spawn_rune(pos: Vector2) -> void:
	var rune_node = Node2D.new()
	rune_node.global_position = pos
	_get_spawn_root().add_child(rune_node)

	var sprite = Sprite2D.new()
	sprite.texture = _get_rune_texture()
	sprite.scale = Vector2(0.5, 0.5)
	sprite.modulate = Color(1.0, 0.8, 1.0, 0.8)
	rune_node.add_child(sprite)

	rune_node.set_meta("damage", get_current_damage())

	var spin_tween = sprite.create_tween()
	spin_tween.tween_property(sprite, "rotation_degrees", 180.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	spin_tween.tween_property(sprite, "rotation_degrees", 720.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var scale_tween = sprite.create_tween()
	scale_tween.tween_property(sprite, "scale", Vector2(0.65, 0.65), 1.0)
	scale_tween.tween_property(sprite, "scale", Vector2(0.9, 0.9), 0.3).set_trans(Tween.TRANS_BACK)

	var blink_timer = get_tree().create_timer(0.9)
	blink_timer.timeout.connect(func():
		if not is_instance_valid(rune_node): return
		var blink_tween = rune_node.create_tween().set_loops(6)
		blink_tween.tween_property(rune_node, "modulate:a", 0.3, 0.04)
		blink_tween.tween_property(rune_node, "modulate:a", 1.0, 0.04)
	)

	get_tree().create_timer(1.3).timeout.connect(_explode.bind(rune_node))

func _explode(rune_node: Node2D) -> void:
	if not is_instance_valid(rune_node):
		return

	var pos = rune_node.global_position
	var dmg = rune_node.get_meta("damage")

	var enemies = _get_enemies()
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if pos.distance_to(enemy.global_position) <= explosion_radius * 2.0:
			deal_damage(enemy, dmg)

	damage_props_in_radius(pos, explosion_radius * 2.0, dmg)
	_spawn_explosion_visual(pos)
	_spawn_explosion_particles(pos)

	var snd = get_tree().get_first_node_in_group("sound_manager")
	if snd:
		snd.play_explosion()

	rune_node.queue_free()

func _spawn_explosion_visual(pos: Vector2) -> void:
	var textures = _get_expl_textures()

	for ring in range(2):
		var expl = Sprite2D.new()
		expl.texture = textures[ring % textures.size()]
		expl.global_position = pos
		expl.z_index = 10
		expl.scale = Vector2(0.3, 0.3)
		expl.modulate = Color(1.0, 0.7, 1.0, 0.8 - ring * 0.2)
		_get_spawn_root().add_child(expl)

		var target_scale = Vector2(3.0 + ring * 1.5, 3.0 + ring * 1.5)
		var delay = ring * 0.06
		var tween = expl.create_tween()
		tween.set_parallel(true)
		tween.tween_property(expl, "scale", target_scale, 0.4).set_delay(delay)
		tween.tween_property(expl, "modulate:a", 0.0, 0.4).set_delay(delay)
		tween.tween_callback(expl.queue_free).set_delay(delay + 0.4)

func _spawn_explosion_particles(pos: Vector2) -> void:
	var burst = GPUParticles2D.new()
	burst.emitting = false
	burst.amount = 32
	burst.lifetime = 0.5
	burst.explosiveness = 0.95
	burst.one_shot = true
	burst.local_coords = false
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 80.0
	pm.initial_velocity_max = 200.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 3.0
	pm.scale_max = 8.0
	var g = Gradient.new()
	g.set_color(0, Color(1.0, 0.7, 1.0, 1.0))
	g.set_color(1, Color(0.6, 0.2, 0.8, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	burst.process_material = pm
	_get_spawn_root().add_child(burst)
	burst.global_position = pos
	burst.emitting = true
	get_tree().create_timer(0.6).timeout.connect(burst.queue_free)
