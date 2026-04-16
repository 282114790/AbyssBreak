@tool
# SkillPillar.gd
# 天罚之柱 — 金色光柱从天而降，锁定敌人位置，光柱内持续伤害
extends SkillBase
class_name SkillPillar

func activate() -> void:
	if not owner_player: return
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm: sm.play_explosion()
	_cast_pillar()

func _cast_pillar() -> void:
	var lv = level if data else 1
	var count = 1 + int(lv / 2)
	var enemies = _get_enemies()
	var alive = enemies.filter(func(e): return is_instance_valid(e))
	alive.sort_custom(func(a, b):
		return owner_player.global_position.distance_to(a.global_position) < owner_player.global_position.distance_to(b.global_position)
	)

	for i in range(count):
		var delay = i * 0.22
		get_tree().create_timer(delay).timeout.connect(func():
			if not is_instance_valid(owner_player): return
			var target_pos: Vector2
			if i < alive.size() and is_instance_valid(alive[i]):
				target_pos = alive[i].global_position
			else:
				target_pos = owner_player.global_position + Vector2(randf_range(-120, 120), randf_range(-120, 120))
			_spawn_warning(target_pos)
			get_tree().create_timer(0.25).timeout.connect(func():
				_spawn_pillar(target_pos)
			)
		)

func _spawn_warning(pos: Vector2) -> void:
	var lv = level if data else 1
	var pillar_radius = (32.0 + lv * 8.0) * 0.8

	var warning = Node2D.new()
	warning.global_position = pos
	warning.z_index = 5
	_get_spawn_root().add_child(warning)

	var ring = Line2D.new()
	ring.width = 1.5
	ring.default_color = Color(1.0, 0.85, 0.3, 0.0)
	for i in range(33):
		var a = (TAU / 32.0) * i
		ring.add_point(Vector2(cos(a) * pillar_radius, sin(a) * pillar_radius))
	warning.add_child(ring)

	var cross1 = Line2D.new()
	cross1.width = 1.0
	cross1.default_color = Color(1.0, 0.8, 0.2, 0.0)
	cross1.add_point(Vector2(-pillar_radius * 0.5, 0))
	cross1.add_point(Vector2(pillar_radius * 0.5, 0))
	warning.add_child(cross1)
	var cross2 = Line2D.new()
	cross2.width = 1.0
	cross2.default_color = Color(1.0, 0.8, 0.2, 0.0)
	cross2.add_point(Vector2(0, -pillar_radius * 0.5))
	cross2.add_point(Vector2(0, pillar_radius * 0.5))
	warning.add_child(cross2)

	var tw = warning.create_tween()
	tw.tween_property(ring, "default_color:a", 0.6, 0.15)
	tw.parallel().tween_property(cross1, "default_color:a", 0.5, 0.15)
	tw.parallel().tween_property(cross2, "default_color:a", 0.5, 0.15)
	tw.tween_property(ring, "default_color:a", 0.0, 0.12)
	tw.parallel().tween_property(cross1, "default_color:a", 0.0, 0.12)
	tw.parallel().tween_property(cross2, "default_color:a", 0.0, 0.12)
	tw.tween_callback(warning.queue_free)

func _spawn_pillar(target_pos: Vector2) -> void:
	var lv = level if data else 1
	var pillar_width = 36.0 + lv * 10.0
	var pillar_radius = pillar_width * 0.9
	var dmg = get_current_damage()
	var duration = 0.55 + lv * 0.05

	var root_node = Node2D.new()
	root_node.global_position = target_pos
	root_node.z_index = 10
	_get_spawn_root().add_child(root_node)

	# --- 地面发光标记 ---
	var ground_glow = Sprite2D.new()
	var glow_img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for gx in range(16):
		for gy in range(16):
			var dist = Vector2(gx - 7.5, gy - 7.5).length() / 7.5
			var alpha = clampf(1.0 - dist, 0.0, 1.0) * 0.5
			glow_img.set_pixel(gx, gy, Color(1.0, 0.9, 0.5, alpha))
	ground_glow.texture = ImageTexture.create_from_image(glow_img)
	ground_glow.scale = Vector2(pillar_radius / 4.0, pillar_radius / 4.0)
	ground_glow.z_index = -1
	root_node.add_child(ground_glow)

	for ring_i in range(2):
		var ring = Line2D.new()
		var r = pillar_radius * (1.0 + ring_i * 0.35)
		ring.width = 2.0 - ring_i * 0.5
		ring.default_color = Color(1.0, 0.85, 0.3, 0.5 - ring_i * 0.15)
		for i in range(33):
			var a = (TAU / 32.0) * i
			ring.add_point(Vector2(cos(a) * r, sin(a) * r))
		ring.z_index = -1
		root_node.add_child(ring)

	# --- 光柱（锥形 width_curve：底粗顶细）---
	var pillar_height = 550.0

	var outer_beam = Line2D.new()
	outer_beam.width = pillar_width * 1.3
	outer_beam.default_color = Color(1.0, 0.8, 0.2, 0.45)
	var outer_curve = Curve.new()
	outer_curve.add_point(Vector2(0.0, 1.0))
	outer_curve.add_point(Vector2(0.3, 0.7))
	outer_curve.add_point(Vector2(1.0, 0.15))
	outer_beam.width_curve = outer_curve
	outer_beam.add_point(Vector2(0, 0))
	outer_beam.add_point(Vector2(0, -pillar_height * 0.3))
	outer_beam.add_point(Vector2(0, -pillar_height * 0.7))
	outer_beam.add_point(Vector2(0, -pillar_height))
	outer_beam.z_index = 9
	root_node.add_child(outer_beam)

	var mid_beam = Line2D.new()
	mid_beam.width = pillar_width * 0.8
	mid_beam.default_color = Color(1.0, 0.92, 0.55, 0.55)
	var mid_curve = Curve.new()
	mid_curve.add_point(Vector2(0.0, 1.0))
	mid_curve.add_point(Vector2(0.4, 0.65))
	mid_curve.add_point(Vector2(1.0, 0.1))
	mid_beam.width_curve = mid_curve
	mid_beam.add_point(Vector2(0, 0))
	mid_beam.add_point(Vector2(0, -pillar_height * 0.3))
	mid_beam.add_point(Vector2(0, -pillar_height * 0.7))
	mid_beam.add_point(Vector2(0, -pillar_height))
	mid_beam.z_index = 10
	root_node.add_child(mid_beam)

	var inner_beam = Line2D.new()
	inner_beam.width = pillar_width * 0.35
	inner_beam.default_color = Color(1.0, 1.0, 0.95, 0.9)
	var inner_curve = Curve.new()
	inner_curve.add_point(Vector2(0.0, 1.0))
	inner_curve.add_point(Vector2(0.5, 0.5))
	inner_curve.add_point(Vector2(1.0, 0.05))
	inner_beam.width_curve = inner_curve
	inner_beam.add_point(Vector2(0, 0))
	inner_beam.add_point(Vector2(0, -pillar_height * 0.5))
	inner_beam.add_point(Vector2(0, -pillar_height))
	inner_beam.z_index = 11
	root_node.add_child(inner_beam)

	# --- 着地白闪（径向渐变圆）---
	var flash = Sprite2D.new()
	var fl_sz = 32
	var flash_img = Image.create(fl_sz, fl_sz, false, Image.FORMAT_RGBA8)
	var fl_half = fl_sz / 2.0 - 0.5
	for fxi in range(fl_sz):
		for fyi in range(fl_sz):
			var fd = Vector2(fxi - fl_half, fyi - fl_half).length() / fl_half
			var fa = clampf(1.0 - fd * fd, 0.0, 1.0)
			flash_img.set_pixel(fxi, fyi, Color(1.0, 0.95, 0.8, fa))
	flash.texture = ImageTexture.create_from_image(flash_img)
	flash.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var fl_base = pillar_radius * 0.25
	flash.scale = Vector2(fl_base, fl_base)
	flash.z_index = 12
	root_node.add_child(flash)
	var flash_tw = flash.create_tween()
	flash_tw.set_parallel(true)
	flash_tw.tween_property(flash, "scale", Vector2(fl_base * 2.0, fl_base * 2.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flash_tw.tween_property(flash, "modulate:a", 0.0, 0.18)
	flash_tw.tween_callback(flash.queue_free).set_delay(0.18)

	# --- 着地冲击波环 ---
	var shockwave = Line2D.new()
	shockwave.width = 3.0
	shockwave.default_color = Color(1.0, 0.9, 0.5, 0.8)
	for i in range(33):
		var a = (TAU / 32.0) * i
		shockwave.add_point(Vector2(cos(a) * 8, sin(a) * 8))
	shockwave.z_index = 8
	root_node.add_child(shockwave)
	var sw_tw = shockwave.create_tween()
	sw_tw.set_parallel(true)
	sw_tw.tween_property(shockwave, "scale", Vector2(pillar_radius * 0.25, pillar_radius * 0.25), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	sw_tw.tween_property(shockwave, "modulate:a", 0.0, 0.25)

	_spawn_rising_particles(root_node, pillar_width)
	_spawn_ground_burst(root_node, pillar_radius)
	_screen_shake(2.0 + lv * 0.5)

	# --- 光柱呼吸 + 持续伤害循环 ---
	var elapsed = 0.0
	var hit_this_tick: Dictionary = {}
	while elapsed < duration:
		if not is_inside_tree(): return
		await get_tree().process_frame
		if not is_inside_tree(): return
		var d = get_process_delta_time()
		elapsed += d
		if not is_instance_valid(root_node): return

		var t = elapsed / duration
		var pulse = 0.8 + sin(elapsed * 18.0) * 0.2
		var width_pulse = 1.0 + sin(elapsed * 14.0) * 0.08
		outer_beam.width = pillar_width * 1.3 * width_pulse
		mid_beam.width = pillar_width * 0.8 * width_pulse
		inner_beam.modulate.a = pulse
		outer_beam.modulate.a = pulse * 0.6

		if is_instance_valid(ground_glow):
			ground_glow.modulate.a = 0.6 + sin(elapsed * 12.0) * 0.2

		hit_this_tick.clear()
		for enemy in _get_enemies():
			if not is_instance_valid(enemy): continue
			if enemy.global_position.distance_to(target_pos) <= pillar_radius:
				if not hit_this_tick.has(enemy.get_instance_id()):
					hit_this_tick[enemy.get_instance_id()] = true
					deal_damage(enemy, dmg * d / 0.12)

	# --- 结束爆发 ---
	_spawn_end_burst(target_pos, pillar_radius, lv)

	if is_instance_valid(root_node):
		var fade = root_node.create_tween()
		fade.tween_property(root_node, "modulate:a", 0.0, 0.2)
		fade.tween_callback(root_node.queue_free)

func _spawn_rising_particles(parent: Node2D, width: float) -> void:
	var particles = GPUParticles2D.new()
	particles.emitting = true
	particles.amount = 40
	particles.lifetime = 0.5
	particles.explosiveness = 0.0
	particles.local_coords = false

	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 100.0
	pm.initial_velocity_max = 250.0
	pm.gravity = Vector3(0, -30, 0)
	pm.scale_min = 1.5
	pm.scale_max = 4.5
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(width * 0.25, 5, 0)

	var g = Gradient.new()
	g.set_color(0, Color(1.0, 1.0, 0.9, 1.0))
	g.set_color(1, Color(1.0, 0.7, 0.15, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	particles.process_material = pm
	parent.add_child(particles)

	var side_particles = GPUParticles2D.new()
	side_particles.emitting = true
	side_particles.amount = 16
	side_particles.lifetime = 0.4
	side_particles.explosiveness = 0.0
	side_particles.local_coords = false
	var pm2 = ParticleProcessMaterial.new()
	pm2.direction = Vector3(0, 0, 0)
	pm2.spread = 180.0
	pm2.initial_velocity_min = 20.0
	pm2.initial_velocity_max = 50.0
	pm2.gravity = Vector3(0, -40, 0)
	pm2.scale_min = 1.0
	pm2.scale_max = 3.0
	pm2.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm2.emission_box_extents = Vector3(width * 0.4, 3, 0)
	var g2 = Gradient.new()
	g2.set_color(0, Color(1.0, 0.85, 0.3, 0.6))
	g2.set_color(1, Color(1.0, 0.6, 0.1, 0.0))
	var gt2 = GradientTexture1D.new()
	gt2.gradient = g2
	pm2.color_ramp = gt2
	side_particles.process_material = pm2
	parent.add_child(side_particles)

func _spawn_ground_burst(parent: Node2D, radius: float) -> void:
	var burst = GPUParticles2D.new()
	burst.emitting = false
	burst.amount = 28
	burst.lifetime = 0.4
	burst.explosiveness = 0.95
	burst.one_shot = true
	burst.local_coords = false

	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 50.0
	pm.initial_velocity_max = 150.0
	pm.gravity = Vector3(0, 80, 0)
	pm.scale_min = 2.0
	pm.scale_max = 6.0
	var g = Gradient.new()
	g.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	g.set_color(1, Color(0.9, 0.6, 0.1, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	burst.process_material = pm
	parent.add_child(burst)
	burst.emitting = true

func _spawn_end_burst(pos: Vector2, radius: float, lv: int) -> void:
	var dust = GPUParticles2D.new()
	dust.emitting = false
	dust.amount = 20 + lv * 4
	dust.lifetime = 0.5
	dust.explosiveness = 0.9
	dust.one_shot = true
	dust.local_coords = false
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 40.0
	pm.initial_velocity_max = 100.0
	pm.gravity = Vector3(0, 50, 0)
	pm.scale_min = 2.5
	pm.scale_max = 6.0
	var g = Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.4, 0.8))
	g.set_color(1, Color(0.7, 0.4, 0.05, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	dust.process_material = pm
	_get_spawn_root().add_child(dust)
	dust.global_position = pos
	dust.emitting = true

	var end_ring = Line2D.new()
	end_ring.width = 2.5
	end_ring.default_color = Color(1.0, 0.85, 0.3, 0.6)
	for i in range(33):
		var a = (TAU / 32.0) * i
		end_ring.add_point(Vector2(cos(a) * 6, sin(a) * 6))
	end_ring.z_index = 8
	_get_spawn_root().add_child(end_ring)
	end_ring.global_position = pos
	var etw = end_ring.create_tween()
	etw.set_parallel(true)
	etw.tween_property(end_ring, "scale", Vector2(radius * 0.2, radius * 0.2), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	etw.tween_property(end_ring, "modulate:a", 0.0, 0.25)
	etw.tween_callback(end_ring.queue_free).set_delay(0.25)

	get_tree().create_timer(0.6).timeout.connect(dust.queue_free)

func _screen_shake(intensity: float = 3.0) -> void:
	var cam = get_viewport().get_camera_2d()
	if not cam: return
	var orig = cam.offset
	var tween = cam.create_tween()
	for i in range(5):
		var falloff = 1.0 - i / 5.0
		var off = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)) * falloff
		tween.tween_property(cam, "offset", orig + off, 0.03)
	tween.tween_property(cam, "offset", orig, 0.04)
