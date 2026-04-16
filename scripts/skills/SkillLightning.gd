@tool
# SkillLightning.gd
# 雷击链 - 锯齿闪电连线弹跳，随关卡增加弹跳数和亮度
extends SkillBase
class_name SkillLightning

var bounce_radius: float = 380.0

func activate() -> void:
	if not owner_player:
		return
	var enemies = _get_enemies()
	if enemies.is_empty():
		return

	enemies.sort_custom(func(a, b): return owner_player.global_position.distance_to(a.global_position) < owner_player.global_position.distance_to(b.global_position))

	var chain_count = 2 + level  # Lv1=3跳 Lv5=7跳
	var targets = []
	var used = {}
	targets.append(owner_player)
	var last = owner_player
	for i in range(min(chain_count, enemies.size())):
		var best = null
		var best_dist = 999999.0
		for e in enemies:
			if used.has(e.get_instance_id()): continue
			var d = last.global_position.distance_to(e.global_position)
			if d < best_dist and d < bounce_radius:
				best_dist = d
				best = e
		if best == null: break
		targets.append(best)
		used[best.get_instance_id()] = true
		last = best

	# 序列播放闪电，每跳0.06s延迟
	for i in range(targets.size() - 1):
		var from_node = targets[i]
		var to_node = targets[i + 1]
		var delay = i * 0.06
		get_tree().create_timer(delay).timeout.connect(
			func():
				if not is_instance_valid(from_node) or not is_instance_valid(to_node):
					return
				deal_damage(to_node)
				_draw_lightning(from_node.global_position, to_node.global_position)
				_spawn_hit_flash(to_node.global_position)
		)

func _draw_lightning(from: Vector2, to: Vector2) -> void:
	# 随等级颜色变化：低级蓝白，高级黄橙
	var t = clamp((level - 1) / 4.0, 0.0, 1.0)
	var bolt_color = Color(
		lerp(0.4, 1.0, t),   # R
		lerp(0.9, 1.0, t),   # G
		lerp(1.0, 0.2, t),   # B
		1.0
	)

	var main_line = Line2D.new()
	main_line.width = 4.0 + level * 0.6
	main_line.default_color = bolt_color
	main_line.z_index = 10
	main_line.joint_mode = Line2D.LINE_JOINT_ROUND

	var seg_count = 8 + level
	main_line.add_point(from)
	for s in range(1, seg_count):
		var a = float(s) / seg_count
		var base = from.lerp(to, a)
		var perp = (to - from).rotated(PI / 2.0).normalized()
		var offset_scale = from.distance_to(to) * 0.18
		var offset = perp * randf_range(-offset_scale, offset_scale)
		main_line.add_point(base + offset)
	main_line.add_point(to)
	_get_spawn_root().add_child(main_line)

	var sub_line = Line2D.new()
	sub_line.width = 2.0 + level * 0.3
	sub_line.default_color = Color(bolt_color.r, bolt_color.g, bolt_color.b, 0.55)
	sub_line.z_index = 9
	sub_line.joint_mode = Line2D.LINE_JOINT_ROUND
	sub_line.add_point(from)
	for s in range(1, 6):
		var a = float(s) / 6.0
		var base = from.lerp(to, a)
		var perp = (to - from).rotated(PI / 2.0).normalized()
		base += perp * randf_range(-from.distance_to(to) * 0.12, from.distance_to(to) * 0.12)
		sub_line.add_point(base)
	sub_line.add_point(to)
	_get_spawn_root().add_child(sub_line)

	var fork_lines: Array[Line2D] = []
	for branch_i in range(2 + level / 2):
		var fork_line = Line2D.new()
		fork_line.width = 1.5
		fork_line.default_color = Color(bolt_color.r, bolt_color.g, bolt_color.b, 0.4)
		fork_line.z_index = 8
		var fork_start_t = randf_range(0.2, 0.8)
		var fork_origin = from.lerp(to, fork_start_t)
		var perp = (to - from).rotated(PI / 2.0).normalized()
		var fork_dir = perp * (1.0 if randf() > 0.5 else -1.0)
		var fork_len = from.distance_to(to) * randf_range(0.15, 0.35)
		fork_line.add_point(fork_origin)
		fork_line.add_point(fork_origin + fork_dir * fork_len * 0.5 + (to - from).normalized() * fork_len * 0.3)
		fork_line.add_point(fork_origin + fork_dir * fork_len)
		_get_spawn_root().add_child(fork_line)
		fork_lines.append(fork_line)

	var core_line = Line2D.new()
	core_line.width = 1.5
	core_line.default_color = Color(1.0, 1.0, 1.0, 0.95)
	core_line.z_index = 11
	core_line.add_point(from)
	core_line.add_point(to)
	_get_spawn_root().add_child(core_line)

	var all_lines: Array = [main_line, sub_line, core_line] + fork_lines
	for line in all_lines:
		var tween = line.create_tween()
		tween.tween_interval(0.06)
		tween.tween_property(line, "modulate:a", 0.0, 0.2)
		tween.tween_callback(line.queue_free)

func _spawn_hit_flash(pos: Vector2) -> void:
	var spark = GPUParticles2D.new()
	spark.emitting = false
	spark.amount = 24 + level * 4
	spark.lifetime = 0.35
	spark.explosiveness = 0.95
	spark.one_shot = true
	spark.local_coords = false

	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 70.0
	pm.initial_velocity_max = 180.0
	pm.gravity = Vector3(0, 0, 0)
	pm.scale_min = 2.5
	pm.scale_max = 8.0
	var t = clamp((level - 1) / 4.0, 0.0, 1.0)
	var spark_color = Color(lerp(0.4, 1.0, t), lerp(0.9, 1.0, t), lerp(1.0, 0.2, t), 1.0)
	var g = Gradient.new()
	g.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	g.set_color(1, spark_color * Color(1,1,1,0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	spark.process_material = pm

	_get_spawn_root().add_child(spark)
	spark.global_position = pos
	spark.emitting = true
	get_tree().create_timer(0.5).timeout.connect(spark.queue_free)
