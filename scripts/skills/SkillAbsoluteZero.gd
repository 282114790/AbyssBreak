@tool
# SkillAbsoluteZero.gd
# 冰封绝对零度 — 收缩蓄力→冰爆扩散→冻结→碎裂二段伤害
extends SkillBase
class_name SkillAbsoluteZero

func activate() -> void:
	if not owner_player: return
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm: sm.play_explosion()
	_cast_absolute_zero()

func _cast_absolute_zero() -> void:
	var lv = level if data else 1
	var freeze_radius = 125.0 + lv * 22.0
	var freeze_duration = 1.2 + lv * 0.15
	var dmg = get_current_damage()
	var shatter_dmg = dmg * 0.6

	var center = owner_player.global_position
	var root = Node2D.new()
	root.global_position = center
	root.z_index = 8
	_get_spawn_root().add_child(root)

	# ══════ 阶段1：收缩蓄力（0.4s）══════

	# 多层收缩圈（从外到内逐渐变亮）
	var shrink_rings: Array = []
	for ri in range(3):
		var ring = Line2D.new()
		ring.width = 2.5 - ri * 0.5
		ring.default_color = Color(0.5 + ri * 0.15, 0.8, 1.0, 0.0)
		var ring_r = freeze_radius * (1.6 - ri * 0.2)
		for i in range(33):
			var a = (TAU / 32.0) * i
			ring.add_point(Vector2(cos(a) * ring_r, sin(a) * ring_r))
		root.add_child(ring)
		shrink_rings.append(ring)

	# 向内吸的冰晶粒子
	var suction = GPUParticles2D.new()
	suction.emitting = true
	suction.amount = 40
	suction.lifetime = 0.4
	suction.explosiveness = 0.0
	suction.local_coords = false
	var suc_pm = ParticleProcessMaterial.new()
	suc_pm.direction = Vector3(0, 0, 0)
	suc_pm.spread = 180.0
	suc_pm.initial_velocity_min = -freeze_radius * 2.0
	suc_pm.initial_velocity_max = -freeze_radius * 1.0
	suc_pm.gravity = Vector3.ZERO
	suc_pm.scale_min = 1.5
	suc_pm.scale_max = 4.0
	suc_pm.angular_velocity_min = -180.0
	suc_pm.angular_velocity_max = 180.0
	suc_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	suc_pm.emission_ring_radius = freeze_radius * 1.3
	suc_pm.emission_ring_inner_radius = freeze_radius * 0.7
	suc_pm.emission_ring_height = 0.0
	suc_pm.emission_ring_axis = Vector3(0, 0, 1)
	var suc_g = Gradient.new()
	suc_g.set_color(0, Color(0.6, 0.9, 1.0, 0.9))
	suc_g.set_color(1, Color(0.8, 0.95, 1.0, 0.0))
	var suc_gt = GradientTexture1D.new()
	suc_gt.gradient = suc_g
	suc_pm.color_ramp = suc_gt
	suction.process_material = suc_pm
	root.add_child(suction)

	# 中心蓄力光球（逐渐变亮变大）
	var charge_orb = Sprite2D.new()
	var orb_img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for ox in range(16):
		for oy in range(16):
			var dist = Vector2(ox - 7.5, oy - 7.5).length() / 7.5
			var alpha = clampf(1.0 - dist * dist, 0.0, 1.0) * 0.6
			orb_img.set_pixel(ox, oy, Color(0.6, 0.85, 1.0, alpha))
	charge_orb.texture = ImageTexture.create_from_image(orb_img)
	charge_orb.scale = Vector2(0.5, 0.5)
	charge_orb.z_index = 10
	root.add_child(charge_orb)

	var shrink_time = 0.4
	var elapsed = 0.0
	while elapsed < shrink_time:
		if not is_inside_tree(): return
		await get_tree().process_frame
		if not is_inside_tree(): return
		var d = get_process_delta_time()
		elapsed += d
		if not is_instance_valid(root): return
		if not is_instance_valid(owner_player): return
		root.global_position = owner_player.global_position

		var progress = elapsed / shrink_time

		for ri in range(shrink_rings.size()):
			var ring = shrink_rings[ri]
			if not is_instance_valid(ring): continue
			var scale_val = 1.0 - progress * (0.75 + ri * 0.05)
			ring.scale = Vector2(scale_val, scale_val)
			ring.default_color.a = progress * (0.5 + ri * 0.1)
			ring.rotation += d * (2.0 + ri * 1.5)

		if is_instance_valid(charge_orb):
			var orb_scale = 0.5 + progress * 3.0
			charge_orb.scale = Vector2(orb_scale, orb_scale)
			charge_orb.modulate.a = 0.3 + progress * 0.7
			var pulse = 1.0 + sin(elapsed * 20.0) * 0.1
			charge_orb.scale *= Vector2(pulse, pulse)

	if not is_instance_valid(root): return
	center = owner_player.global_position
	root.global_position = center

	suction.emitting = false

	# ══════ 阶段2：冰爆扩散 ══════

	# 白闪（径向渐变圆，线性过滤避免方块）
	var flash = Sprite2D.new()
	var flash_size = 32
	var flash_img = Image.create(flash_size, flash_size, false, Image.FORMAT_RGBA8)
	var half = flash_size / 2.0 - 0.5
	for fx in range(flash_size):
		for fy in range(flash_size):
			var dist = Vector2(fx - half, fy - half).length() / half
			var alpha = clampf(1.0 - dist * dist, 0.0, 1.0)
			flash_img.set_pixel(fx, fy, Color(0.85, 0.93, 1.0, alpha))
	flash.texture = ImageTexture.create_from_image(flash_img)
	flash.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var flash_base = freeze_radius * 0.2
	flash.scale = Vector2(flash_base, flash_base)
	flash.z_index = 13
	root.add_child(flash)
	var fl_tw = flash.create_tween()
	fl_tw.set_parallel(true)
	fl_tw.tween_property(flash, "scale", Vector2(flash_base * 1.8, flash_base * 1.8), 0.1)
	fl_tw.tween_property(flash, "modulate:a", 0.0, 0.18)
	fl_tw.tween_callback(flash.queue_free).set_delay(0.18)

	# 移除蓄力球
	if is_instance_valid(charge_orb): charge_orb.queue_free()

	# 双层冲击波
	for sw_i in range(2):
		var sw = Line2D.new()
		sw.width = 4.0 - sw_i * 1.5
		sw.default_color = Color(0.65 + sw_i * 0.2, 0.88, 1.0, 0.9 - sw_i * 0.2)
		for i in range(33):
			var a = (TAU / 32.0) * i
			sw.add_point(Vector2(cos(a) * 8, sin(a) * 8))
		sw.z_index = 11 - sw_i
		root.add_child(sw)
		var target_scale = freeze_radius / 8.0 * (1.0 + sw_i * 0.2)
		var sw_tw = sw.create_tween()
		sw_tw.set_parallel(true)
		sw_tw.tween_property(sw, "scale", Vector2(target_scale, target_scale), 0.2 + sw_i * 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(sw_i * 0.05)
		sw_tw.tween_property(sw, "modulate:a", 0.0, 0.28 + sw_i * 0.05).set_delay(sw_i * 0.05)

	# 碎冰粒子爆射
	var ice_burst = GPUParticles2D.new()
	ice_burst.emitting = false
	ice_burst.amount = 45 + lv * 8
	ice_burst.lifetime = 0.55
	ice_burst.explosiveness = 0.95
	ice_burst.one_shot = true
	ice_burst.local_coords = false
	var ib_pm = ParticleProcessMaterial.new()
	ib_pm.direction = Vector3(0, -1, 0)
	ib_pm.spread = 180.0
	ib_pm.initial_velocity_min = 120.0
	ib_pm.initial_velocity_max = 320.0
	ib_pm.gravity = Vector3(0, 50, 0)
	ib_pm.scale_min = 2.0
	ib_pm.scale_max = 6.0
	ib_pm.angular_velocity_min = -300.0
	ib_pm.angular_velocity_max = 300.0
	var ib_g = Gradient.new()
	ib_g.set_color(0, Color(0.9, 0.97, 1.0, 1.0))
	ib_g.set_color(1, Color(0.4, 0.7, 1.0, 0.0))
	var ib_gt = GradientTexture1D.new()
	ib_gt.gradient = ib_g
	ib_pm.color_ramp = ib_gt
	ice_burst.process_material = ib_pm
	root.add_child(ice_burst)
	ice_burst.emitting = true

	# 细碎冰尘
	var ice_dust = GPUParticles2D.new()
	ice_dust.emitting = false
	ice_dust.amount = 30
	ice_dust.lifetime = 0.7
	ice_dust.explosiveness = 0.9
	ice_dust.one_shot = true
	ice_dust.local_coords = false
	var id_pm = ParticleProcessMaterial.new()
	id_pm.direction = Vector3(0, 0, 0)
	id_pm.spread = 180.0
	id_pm.initial_velocity_min = 50.0
	id_pm.initial_velocity_max = 180.0
	id_pm.gravity = Vector3(0, 20, 0)
	id_pm.scale_min = 1.0
	id_pm.scale_max = 3.0
	var id_g = Gradient.new()
	id_g.set_color(0, Color(0.7, 0.9, 1.0, 0.6))
	id_g.set_color(1, Color(0.5, 0.75, 1.0, 0.0))
	var id_gt = GradientTexture1D.new()
	id_gt.gradient = id_g
	id_pm.color_ramp = id_gt
	ice_dust.process_material = id_pm
	root.add_child(ice_dust)
	ice_dust.emitting = true

	# 地面冰霜纹路
	_spawn_frost_ground(center, freeze_radius)
	_screen_shake(3.5 + lv * 0.5)

	# ══════ 冻结敌人 ══════
	var frozen_enemies: Array = []
	for enemy in _get_enemies():
		if not is_instance_valid(enemy): continue
		if enemy.global_position.distance_to(center) <= freeze_radius:
			deal_damage(enemy, dmg)
			if is_instance_valid(enemy) and enemy.get("base_move_speed") != null:
				var orig_spd = enemy.base_move_speed
				frozen_enemies.append({"enemy": enemy, "orig_spd": orig_spd})
				enemy.base_move_speed = 0
				enemy.modulate = Color(0.45, 0.65, 1.0, 1.0)
				_spawn_freeze_indicator(enemy)

	damage_props_in_radius(center, freeze_radius, dmg)

	# ══════ 阶段3：冻结等待→碎裂 ══════
	if not is_inside_tree(): return
	await get_tree().create_timer(freeze_duration).timeout
	if not is_inside_tree(): return

	for entry in frozen_enemies:
		var enemy = entry["enemy"]
		if not is_instance_valid(enemy): continue

		_spawn_shatter_effect(enemy.global_position)
		deal_damage(enemy, shatter_dmg)

		if is_instance_valid(enemy):
			enemy.modulate = Color(1, 1, 1, 1)
			if enemy.get("base_move_speed") != null:
				enemy.base_move_speed = entry["orig_spd"]

	_screen_shake(2.0)

	if is_instance_valid(root):
		var fade = root.create_tween()
		fade.tween_property(root, "modulate:a", 0.0, 0.3)
		fade.tween_callback(root.queue_free)

func _spawn_freeze_indicator(enemy: Node2D) -> void:
	if not is_instance_valid(enemy): return
	var indicator = Node2D.new()
	indicator.name = "FreezeVFX"
	indicator.z_index = 5

	var ice_ring = Line2D.new()
	ice_ring.width = 1.5
	ice_ring.default_color = Color(0.5, 0.8, 1.0, 0.5)
	var r = 18.0
	for i in range(9):
		var a = (TAU / 8.0) * i
		ice_ring.add_point(Vector2(cos(a) * r, sin(a) * r))
	indicator.add_child(ice_ring)

	var sparkle = GPUParticles2D.new()
	sparkle.emitting = true
	sparkle.amount = 4
	sparkle.lifetime = 0.8
	sparkle.explosiveness = 0.0
	sparkle.local_coords = false
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 15.0
	pm.gravity = Vector3(0, -5, 0)
	pm.scale_min = 1.0
	pm.scale_max = 2.5
	var g = Gradient.new()
	g.set_color(0, Color(0.7, 0.9, 1.0, 0.7))
	g.set_color(1, Color(0.5, 0.8, 1.0, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	sparkle.process_material = pm
	indicator.add_child(sparkle)

	enemy.add_child(indicator)

	get_tree().create_timer(2.5).timeout.connect(func():
		if is_instance_valid(indicator): indicator.queue_free()
	)

func _spawn_frost_ground(center: Vector2, radius: float) -> void:
	var frost = Node2D.new()
	frost.global_position = center
	frost.z_index = -1
	_get_spawn_root().add_child(frost)

	# 渐变填充底圈
	var glow = Sprite2D.new()
	var glow_img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for gx in range(16):
		for gy in range(16):
			var dist = Vector2(gx - 7.5, gy - 7.5).length() / 7.5
			var alpha = clampf(1.0 - dist, 0.0, 1.0) * 0.2
			glow_img.set_pixel(gx, gy, Color(0.5, 0.8, 1.0, alpha))
	glow.texture = ImageTexture.create_from_image(glow_img)
	glow.scale = Vector2(radius / 4.0, radius / 4.0)
	frost.add_child(glow)

	# 冰霜纹路圈
	for ring_i in range(4):
		var ring = Line2D.new()
		var r = radius * (0.3 + ring_i * 0.2)
		ring.width = 1.5 - ring_i * 0.2
		ring.default_color = Color(0.55, 0.82, 1.0, 0.4 - ring_i * 0.08)

		var seg_count = 24 + ring_i * 4
		for i in range(seg_count + 1):
			var a = (TAU / seg_count) * i
			var jitter = randf_range(-r * 0.06, r * 0.06)
			ring.add_point(Vector2(cos(a) * (r + jitter), sin(a) * (r + jitter)))
		frost.add_child(ring)

	# 放射冰纹线
	for i in range(8):
		var line = Line2D.new()
		line.width = 1.0
		line.default_color = Color(0.6, 0.85, 1.0, 0.25)
		var a = TAU / 8.0 * i + randf_range(-0.15, 0.15)
		var len_val = radius * randf_range(0.4, 0.9)
		line.add_point(Vector2.ZERO)
		var mid = Vector2(cos(a), sin(a)) * len_val * 0.5
		mid += Vector2(randf_range(-8, 8), randf_range(-8, 8))
		line.add_point(mid)
		line.add_point(Vector2(cos(a), sin(a)) * len_val)
		frost.add_child(line)

	var fade = frost.create_tween()
	fade.tween_interval(1.5)
	fade.tween_property(frost, "modulate:a", 0.0, 2.0)
	fade.tween_callback(frost.queue_free)

func _spawn_shatter_effect(pos: Vector2) -> void:
	# 碎裂冲击波
	var ring = Line2D.new()
	ring.width = 2.5
	ring.default_color = Color(0.6, 0.85, 1.0, 0.8)
	for i in range(25):
		var a = (TAU / 24.0) * i
		ring.add_point(Vector2(cos(a) * 5, sin(a) * 5))
	ring.z_index = 9
	_get_spawn_root().add_child(ring)
	ring.global_position = pos
	var rtw = ring.create_tween()
	rtw.set_parallel(true)
	rtw.tween_property(ring, "scale", Vector2(6.0, 6.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rtw.tween_property(ring, "modulate:a", 0.0, 0.18)
	rtw.tween_callback(ring.queue_free).set_delay(0.18)

	# 碎冰粒子
	var shatter = GPUParticles2D.new()
	shatter.emitting = false
	shatter.amount = 18
	shatter.lifetime = 0.4
	shatter.explosiveness = 0.95
	shatter.one_shot = true
	shatter.local_coords = false
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 80.0
	pm.initial_velocity_max = 200.0
	pm.gravity = Vector3(0, 70, 0)
	pm.scale_min = 2.0
	pm.scale_max = 5.0
	pm.angular_velocity_min = -400.0
	pm.angular_velocity_max = 400.0
	var g = Gradient.new()
	g.set_color(0, Color(0.85, 0.95, 1.0, 1.0))
	g.set_color(1, Color(0.5, 0.75, 1.0, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	shatter.process_material = pm
	_get_spawn_root().add_child(shatter)
	shatter.global_position = pos
	shatter.emitting = true

	# 白蓝闪光
	var flash = Sprite2D.new()
	var flash_img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for fx in range(8):
		for fy in range(8):
			var dist = Vector2(fx - 3.5, fy - 3.5).length() / 3.5
			var alpha = clampf(1.0 - dist, 0.0, 1.0)
			flash_img.set_pixel(fx, fy, Color(0.7, 0.9, 1.0, alpha))
	flash.texture = ImageTexture.create_from_image(flash_img)
	flash.scale = Vector2(3.0, 3.0)
	flash.z_index = 12
	_get_spawn_root().add_child(flash)
	flash.global_position = pos
	var ftw = flash.create_tween()
	ftw.set_parallel(true)
	ftw.tween_property(flash, "scale", Vector2(7.0, 7.0), 0.1)
	ftw.tween_property(flash, "modulate:a", 0.0, 0.13)
	ftw.tween_callback(flash.queue_free).set_delay(0.13)

	get_tree().create_timer(0.5).timeout.connect(shatter.queue_free)

func _screen_shake(intensity: float) -> void:
	var cam = get_viewport().get_camera_2d()
	if not cam: return
	var orig = cam.offset
	var tween = cam.create_tween()
	for i in range(5):
		var falloff = 1.0 - i / 5.0
		tween.tween_property(cam, "offset", orig + Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)) * falloff, 0.03)
	tween.tween_property(cam, "offset", orig, 0.04)
