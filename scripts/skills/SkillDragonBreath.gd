@tool
# SkillDragonBreath.gd
# 龙息 — 扇形火焰喷射，多层火焰+热浪+地面灼烧
extends SkillBase
class_name SkillDragonBreath

func activate() -> void:
	if not owner_player: return
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm: sm.play_explosion()
	_breathe_fire()

func _breathe_fire() -> void:
	var lv = level if data else 1
	var cone_angle = deg_to_rad(28.0 + lv * 5.0)
	var cone_range = 170.0 + lv * 22.0
	var duration = 0.85
	var tick_rate = 0.08
	var dmg_per_tick = get_current_damage() * 0.2

	var target = get_nearest_enemy()
	var aim_dir: Vector2
	if target:
		aim_dir = (target.global_position - owner_player.global_position).normalized()
	else:
		aim_dir = Vector2.RIGHT

	var breath_root = Node2D.new()
	breath_root.global_position = owner_player.global_position
	breath_root.z_index = 5
	_get_spawn_root().add_child(breath_root)

	# --- 起手蓄力闪光（径向渐变）---
	var charge_flash = Sprite2D.new()
	var cf_sz = 20
	var flash_img = Image.create(cf_sz, cf_sz, false, Image.FORMAT_RGBA8)
	var cf_half = cf_sz / 2.0 - 0.5
	for cfx in range(cf_sz):
		for cfy in range(cf_sz):
			var cfd = Vector2(cfx - cf_half, cfy - cf_half).length() / cf_half
			var cfa = clampf(1.0 - cfd * cfd, 0.0, 1.0)
			flash_img.set_pixel(cfx, cfy, Color(1.0, 0.85, 0.4, cfa))
	charge_flash.texture = ImageTexture.create_from_image(flash_img)
	charge_flash.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	charge_flash.scale = Vector2(1.5, 1.5)
	charge_flash.z_index = 12
	charge_flash.position = aim_dir * 15.0
	breath_root.add_child(charge_flash)
	var cf_tw = charge_flash.create_tween()
	cf_tw.tween_property(charge_flash, "scale", Vector2(4.5, 4.5), 0.1)
	cf_tw.parallel().tween_property(charge_flash, "modulate:a", 0.0, 0.15)
	cf_tw.tween_callback(charge_flash.queue_free)

	# --- 圆形粒子纹理（避免方形点）---
	var ptex = _get_soft_circle_texture()
	var spread_deg = rad_to_deg(cone_angle)

	# --- 多层火焰粒子 ---
	# 设计思路：所有层都从原点发射，用速度覆盖整个锥形
	# 白芯：最快最小，飞到锥尖   橙焰：稍慢稍大，覆盖中段
	# 暗红：与橙焰同速但更大更透明，叠在下面形成底色   黑烟：大而淡，弥漫感
	var particle_layers: Array = []
	# vel * lifetime 必须 >= cone_range，确保粒子能飞到扇形边缘
	var layer_configs = [
		{"amount": 50 + lv * 6, "vel_min": cone_range * 2.8, "vel_max": cone_range * 4.2,
		 "scale_min": 0.05, "scale_max": 0.12, "lifetime": 0.38, "damp": 18.0,
		 "c0": Color(1.0, 1.0, 0.95, 1.0), "c1": Color(1.0, 0.9, 0.5, 0.0)},
		{"amount": 65 + lv * 6, "vel_min": cone_range * 2.0, "vel_max": cone_range * 3.5,
		 "scale_min": 0.08, "scale_max": 0.2, "lifetime": 0.42, "damp": 15.0,
		 "c0": Color(1.0, 0.65, 0.1, 0.9), "c1": Color(0.9, 0.3, 0.0, 0.0)},
		{"amount": 55 + lv * 5, "vel_min": cone_range * 1.6, "vel_max": cone_range * 3.0,
		 "scale_min": 0.12, "scale_max": 0.28, "lifetime": 0.48, "damp": 12.0,
		 "c0": Color(0.75, 0.15, 0.0, 0.55), "c1": Color(0.25, 0.03, 0.0, 0.0)},
		{"amount": 30 + lv * 3, "vel_min": cone_range * 1.2, "vel_max": cone_range * 2.2,
		 "scale_min": 0.15, "scale_max": 0.35, "lifetime": 0.55, "damp": 8.0,
		 "c0": Color(0.12, 0.08, 0.05, 0.3), "c1": Color(0.04, 0.02, 0.01, 0.0)},
	]
	for cfg in layer_configs:
		var p = GPUParticles2D.new()
		p.emitting = true
		p.amount = cfg["amount"]
		p.lifetime = cfg["lifetime"]
		p.explosiveness = 0.0
		p.local_coords = false
		p.texture = ptex
		var pm = ParticleProcessMaterial.new()
		pm.direction = Vector3(aim_dir.x, aim_dir.y, 0)
		pm.spread = spread_deg
		pm.initial_velocity_min = cfg["vel_min"]
		pm.initial_velocity_max = cfg["vel_max"]
		pm.gravity = Vector3(0, 0, 0)
		pm.scale_min = cfg["scale_min"]
		pm.scale_max = cfg["scale_max"]
		pm.damping_min = cfg["damp"] * 0.6
		pm.damping_max = cfg["damp"]
		var g = Gradient.new()
		g.set_color(0, cfg["c0"])
		g.set_color(1, cfg["c1"])
		var gt = GradientTexture1D.new()
		gt.gradient = g
		pm.color_ramp = gt
		p.process_material = pm
		breath_root.add_child(p)
		particle_layers.append(p)

	# --- 锥形填充视觉（多层半透明扇面）---
	var cone_vis = _create_filled_cone(aim_dir, cone_angle, cone_range)
	breath_root.add_child(cone_vis)

	# --- 热浪涟漪粒子（轻微向上飘散）---
	var heat_wave = GPUParticles2D.new()
	heat_wave.emitting = true
	heat_wave.amount = 16
	heat_wave.lifetime = 0.6
	heat_wave.explosiveness = 0.0
	heat_wave.local_coords = false
	heat_wave.texture = ptex
	var hw_pm = ParticleProcessMaterial.new()
	hw_pm.direction = Vector3(aim_dir.x * 0.5, aim_dir.y * 0.5 - 0.5, 0)
	hw_pm.spread = spread_deg * 0.9
	hw_pm.initial_velocity_min = cone_range * 0.15
	hw_pm.initial_velocity_max = cone_range * 0.4
	hw_pm.gravity = Vector3(0, -25, 0)
	hw_pm.scale_min = 0.3
	hw_pm.scale_max = 0.7
	hw_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	hw_pm.emission_box_extents = Vector3(15, 15, 0)
	var hw_g = Gradient.new()
	hw_g.set_color(0, Color(1.0, 0.7, 0.3, 0.15))
	hw_g.set_color(1, Color(1.0, 0.5, 0.1, 0.0))
	var hw_gt = GradientTexture1D.new()
	hw_gt.gradient = hw_g
	hw_pm.color_ramp = hw_gt
	heat_wave.process_material = hw_pm
	breath_root.add_child(heat_wave)

	_screen_shake(1.5 + lv * 0.3)

	# --- 持续伤害循环 ---
	var elapsed = 0.0
	var tick_acc = 0.0
	while elapsed < duration:
		if not is_inside_tree(): return
		await get_tree().process_frame
		if not is_inside_tree(): return
		var d = get_process_delta_time()
		elapsed += d
		tick_acc += d
		if not is_instance_valid(breath_root): return
		if not is_instance_valid(owner_player): return

		breath_root.global_position = owner_player.global_position

		var t = elapsed / duration
		var pulse = 0.7 + sin(elapsed * 16.0) * 0.2
		cone_vis.modulate.a = pulse * (1.0 - t * 0.3)

		if tick_acc >= tick_rate:
			tick_acc -= tick_rate
			for enemy in _get_enemies():
				if not is_instance_valid(enemy): continue
				if _is_in_cone(enemy.global_position, owner_player.global_position, aim_dir, cone_angle, cone_range):
					deal_damage(enemy, dmg_per_tick)
					if randf() < 0.3:
						_spawn_hit_ember(enemy.global_position)

	# --- 结束灼烧痕迹 ---
	_spawn_scorch_mark(owner_player.global_position, aim_dir, cone_range, cone_angle)

	if is_instance_valid(breath_root):
		for p in particle_layers:
			if is_instance_valid(p): p.emitting = false
		if is_instance_valid(heat_wave): heat_wave.emitting = false
		var fade = breath_root.create_tween()
		fade.tween_property(breath_root, "modulate:a", 0.0, 0.25)
		fade.tween_callback(breath_root.queue_free)

func _is_in_cone(pos: Vector2, origin: Vector2, dir: Vector2, half_angle: float, range_dist: float) -> bool:
	var to_pos = pos - origin
	var dist = to_pos.length()
	if dist > range_dist or dist < 5.0:
		return false
	return abs(to_pos.angle_to(dir)) <= half_angle

func _create_filled_cone(dir: Vector2, half_angle: float, range_dist: float) -> Node2D:
	var vis = Node2D.new()

	for layer_i in range(5):
		var fill = Line2D.new()
		var r = range_dist * (0.25 + layer_i * 0.18)
		var w = r * sin(half_angle) * 2.0
		fill.width = w * (1.0 - layer_i * 0.1)
		var alpha = 0.2 - layer_i * 0.03
		var colors := [
			Color(1.0, 1.0, 0.9, alpha),
			Color(1.0, 0.85, 0.4, alpha),
			Color(1.0, 0.6, 0.15, alpha),
			Color(0.9, 0.35, 0.05, alpha),
			Color(0.6, 0.15, 0.0, alpha * 0.7),
		]
		fill.default_color = colors[layer_i]
		var mid = dir * r
		var perp = dir.rotated(PI / 2.0) * 2.0
		fill.add_point(mid - perp)
		fill.add_point(mid + perp)
		fill.z_index = 4 - layer_i
		vis.add_child(fill)

	var edge = Line2D.new()
	edge.width = 1.5
	edge.default_color = Color(1.0, 0.8, 0.2, 0.3)
	var segs = 16
	for i in range(segs + 1):
		var a = dir.angle() - half_angle + (half_angle * 2.0 / segs) * i
		edge.add_point(Vector2(cos(a) * range_dist, sin(a) * range_dist))
	edge.add_point(Vector2.ZERO)
	edge.add_point(Vector2(cos(dir.angle() - half_angle) * range_dist, sin(dir.angle() - half_angle) * range_dist))
	edge.z_index = 6
	vis.add_child(edge)

	return vis

func _spawn_hit_ember(pos: Vector2) -> void:
	var ember = GPUParticles2D.new()
	ember.emitting = false
	ember.amount = 8
	ember.lifetime = 0.25
	ember.explosiveness = 0.95
	ember.one_shot = true
	ember.local_coords = false
	ember.texture = _get_soft_circle_texture()
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 120.0
	pm.initial_velocity_min = 25.0
	pm.initial_velocity_max = 70.0
	pm.gravity = Vector3(0, -20, 0)
	pm.scale_min = 0.04
	pm.scale_max = 0.12
	var g = Gradient.new()
	g.set_color(0, Color(1.0, 0.8, 0.3, 1.0))
	g.set_color(1, Color(1.0, 0.3, 0.0, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	ember.process_material = pm
	_get_spawn_root().add_child(ember)
	ember.global_position = pos
	ember.emitting = true
	get_tree().create_timer(0.4).timeout.connect(ember.queue_free)

func _spawn_scorch_mark(origin: Vector2, dir: Vector2, dist: float, half_angle: float) -> void:
	var scorch = Node2D.new()
	scorch.global_position = origin
	scorch.z_index = -2
	_get_spawn_root().add_child(scorch)

	for layer in range(3):
		var mark = Line2D.new()
		var r = dist * (0.4 + layer * 0.2)
		var w = r * sin(half_angle) * 1.5
		mark.width = w
		mark.default_color = Color(0.25 - layer * 0.05, 0.1, 0.0, 0.2 - layer * 0.05)
		var mid = dir * r
		var perp = dir.rotated(PI / 2.0) * 2.0
		mark.add_point(mid - perp)
		mark.add_point(mid + perp)
		scorch.add_child(mark)

	var glow_edge = Line2D.new()
	glow_edge.width = 2.0
	glow_edge.default_color = Color(1.0, 0.4, 0.0, 0.25)
	var segs = 10
	for i in range(segs + 1):
		var a = dir.angle() - half_angle * 0.8 + (half_angle * 1.6 / segs) * i
		glow_edge.add_point(Vector2(cos(a) * dist * 0.7, sin(a) * dist * 0.7))
	scorch.add_child(glow_edge)

	var embers = GPUParticles2D.new()
	embers.emitting = true
	embers.amount = 10
	embers.lifetime = 1.0
	embers.explosiveness = 0.0
	embers.local_coords = false
	embers.texture = _get_soft_circle_texture()
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 30.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 15.0
	pm.gravity = Vector3(0, -8, 0)
	pm.scale_min = 0.02
	pm.scale_max = 0.06
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(dist * 0.3, 10, 0)
	var g = Gradient.new()
	g.set_color(0, Color(1.0, 0.5, 0.1, 0.5))
	g.set_color(1, Color(0.5, 0.15, 0.0, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	embers.process_material = pm
	embers.position = dir * dist * 0.4
	scorch.add_child(embers)

	var fade = scorch.create_tween()
	fade.tween_interval(1.5)
	fade.tween_property(scorch, "modulate:a", 0.0, 1.5)
	fade.tween_callback(scorch.queue_free)

func _screen_shake(intensity: float) -> void:
	var cam = get_viewport().get_camera_2d()
	if not cam: return
	var orig = cam.offset
	var tween = cam.create_tween()
	for i in range(4):
		var falloff = 1.0 - i / 4.0
		tween.tween_property(cam, "offset", orig + Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)) * falloff, 0.03)
	tween.tween_property(cam, "offset", orig, 0.04)

var _cached_circle_tex: Texture2D = null

func _get_soft_circle_texture() -> Texture2D:
	if _cached_circle_tex != null:
		return _cached_circle_tex
	var sz = 64
	var img = Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var half = sz / 2.0 - 0.5
	for x in range(sz):
		for y in range(sz):
			var dist = Vector2(x - half, y - half).length() / half
			var alpha = clampf(1.0 - dist * dist, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_cached_circle_tex = ImageTexture.create_from_image(img)
	return _cached_circle_tex
