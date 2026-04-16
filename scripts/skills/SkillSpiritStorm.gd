@tool
# SkillSpiritStorm.gd
# 灵魂风暴 — 幽蓝灵魂体螺旋盘旋蓄力后齐射
extends SkillBase
class_name SkillSpiritStorm

func activate() -> void:
	if not owner_player: return
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm: sm.play_shoot()
	_summon_spirits()

func _summon_spirits() -> void:
	var lv = level if data else 1
	var spirit_count = 4 + lv
	var orbit_radius = 55.0 + lv * 3.0
	var orbit_time = 0.9
	var dmg = get_current_damage()

	var spirits: Array = []

	# --- 召唤环闪 ---
	var summon_ring = Line2D.new()
	summon_ring.width = 2.0
	summon_ring.default_color = Color(0.4, 0.6, 1.0, 0.0)
	for ri in range(33):
		var a = (TAU / 32.0) * ri
		summon_ring.add_point(Vector2(cos(a) * 8, sin(a) * 8))
	summon_ring.z_index = 7
	_get_spawn_root().add_child(summon_ring)
	summon_ring.global_position = owner_player.global_position
	var sr_tw = summon_ring.create_tween()
	sr_tw.set_parallel(true)
	sr_tw.tween_property(summon_ring, "scale", Vector2(orbit_radius / 8.0, orbit_radius / 8.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	sr_tw.tween_property(summon_ring, "default_color:a", 0.5, 0.1)
	sr_tw.tween_property(summon_ring, "default_color:a", 0.0, 0.15).set_delay(0.15)
	sr_tw.tween_callback(summon_ring.queue_free).set_delay(0.3)

	for i in range(spirit_count):
		var spirit = Node2D.new()
		spirit.z_index = 8

		# 径向渐变发光球体
		var glow = Sprite2D.new()
		var glow_img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for gx in range(16):
			for gy in range(16):
				var dist = Vector2(gx - 7.5, gy - 7.5).length() / 7.5
				var alpha = clampf(1.0 - dist * dist, 0.0, 1.0) * 0.7
				glow_img.set_pixel(gx, gy, Color(0.4, 0.6, 1.0, alpha))
		glow.texture = ImageTexture.create_from_image(glow_img)
		glow.scale = Vector2(1.8, 1.8)
		spirit.add_child(glow)

		# 白色亮芯
		var core = Sprite2D.new()
		var core_img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		for cx in range(8):
			for cy in range(8):
				var dist = Vector2(cx - 3.5, cy - 3.5).length() / 3.5
				var alpha = clampf(1.0 - dist, 0.0, 1.0)
				core_img.set_pixel(cx, cy, Color(0.85, 0.92, 1.0, alpha))
		core.texture = ImageTexture.create_from_image(core_img)
		core.scale = Vector2(1.0, 1.0)
		spirit.add_child(core)

		# 拖尾粒子
		var trail = GPUParticles2D.new()
		trail.emitting = true
		trail.amount = 14
		trail.lifetime = 0.35
		trail.explosiveness = 0.0
		trail.local_coords = false
		var pm = ParticleProcessMaterial.new()
		pm.direction = Vector3(0, 0, 0)
		pm.spread = 180.0
		pm.initial_velocity_min = 3.0
		pm.initial_velocity_max = 12.0
		pm.gravity = Vector3.ZERO
		pm.scale_min = 1.5
		pm.scale_max = 4.0
		var g = Gradient.new()
		g.set_color(0, Color(0.45, 0.65, 1.0, 0.7))
		g.set_color(1, Color(0.2, 0.35, 0.9, 0.0))
		var gt = GradientTexture1D.new()
		gt.gradient = g
		pm.color_ramp = gt
		trail.process_material = pm
		spirit.add_child(trail)

		_get_spawn_root().add_child(spirit)
		spirit.global_position = owner_player.global_position
		spirit.modulate.a = 0.0
		spirits.append({"node": spirit, "angle": TAU / spirit_count * i, "glow": glow, "core": core, "trail": trail})

	# --- 螺旋盘旋阶段（加速蓄力）---
	var elapsed = 0.0
	while elapsed < orbit_time:
		if not is_inside_tree(): break
		await get_tree().process_frame
		if not is_inside_tree(): break
		var d = get_process_delta_time()
		elapsed += d
		if not is_instance_valid(owner_player): break

		var progress = elapsed / orbit_time
		var current_radius = orbit_radius * min(progress * 2.5, 1.0)
		var rotation_speed = 6.0 + progress * progress * 18.0
		var appear = min(progress * 4.0, 1.0)

		for si in range(spirits.size()):
			var s = spirits[si]
			if not is_instance_valid(s["node"]): continue
			s["angle"] += rotation_speed * d
			var offset = Vector2(cos(s["angle"]), sin(s["angle"])) * current_radius
			s["node"].global_position = owner_player.global_position + offset

			s["node"].modulate.a = appear
			var pulse = 0.85 + sin(elapsed * 12.0 + si * 1.3) * 0.15
			if is_instance_valid(s["glow"]):
				s["glow"].scale = Vector2(1.8 * pulse, 1.8 * pulse)
			if is_instance_valid(s["core"]):
				s["core"].modulate.a = pulse

	# --- 蓄力完成闪光（径向渐变）---
	if is_instance_valid(owner_player):
		var charge_flash = Sprite2D.new()
		var cf_sz = 24
		var cf_img = Image.create(cf_sz, cf_sz, false, Image.FORMAT_RGBA8)
		var cf_half = cf_sz / 2.0 - 0.5
		for cfx in range(cf_sz):
			for cfy in range(cf_sz):
				var cfd = Vector2(cfx - cf_half, cfy - cf_half).length() / cf_half
				var cfa = clampf(1.0 - cfd * cfd, 0.0, 1.0)
				cf_img.set_pixel(cfx, cfy, Color(0.6, 0.8, 1.0, cfa))
		charge_flash.texture = ImageTexture.create_from_image(cf_img)
		charge_flash.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		charge_flash.scale = Vector2(2.5, 2.5)
		charge_flash.z_index = 12
		_get_spawn_root().add_child(charge_flash)
		charge_flash.global_position = owner_player.global_position
		var cftw = charge_flash.create_tween()
		cftw.set_parallel(true)
		cftw.tween_property(charge_flash, "scale", Vector2(7.0, 7.0), 0.12)
		cftw.tween_property(charge_flash, "modulate:a", 0.0, 0.15)
		cftw.tween_callback(charge_flash.queue_free).set_delay(0.15)

	# --- 齐射阶段 ---
	var enemies = _get_enemies()
	var alive = enemies.filter(func(e): return is_instance_valid(e))
	alive.sort_custom(func(a, b):
		return owner_player.global_position.distance_to(a.global_position) < owner_player.global_position.distance_to(b.global_position)
	)

	for i in range(spirits.size()):
		var s = spirits[i]
		if not is_instance_valid(s["node"]): continue

		var target_enemy: Node2D = null
		if alive.size() > 0:
			target_enemy = alive[i % alive.size()]

		if target_enemy and is_instance_valid(target_enemy):
			_fire_spirit(s["node"], s["trail"], target_enemy, dmg)
		else:
			var random_dir = Vector2.RIGHT.rotated(randf() * TAU)
			_fire_spirit_dir(s["node"], s["trail"], random_dir, dmg)

func _fire_spirit(spirit: Node2D, trail: GPUParticles2D, target: Node2D, dmg: float) -> void:
	var speed = 650.0
	var elapsed = 0.0
	var max_time = 1.5
	var start_pos = spirit.global_position

	# 增加拖尾粒子量
	if is_instance_valid(trail):
		trail.amount = 22
		trail.lifetime = 0.25

	while elapsed < max_time:
		if not is_inside_tree(): return
		await get_tree().process_frame
		if not is_inside_tree(): return
		var d = get_process_delta_time()
		elapsed += d
		if not is_instance_valid(spirit): return

		var target_pos: Vector2
		if is_instance_valid(target):
			target_pos = target.global_position
		else:
			spirit.queue_free()
			return

		var dir = (target_pos - spirit.global_position).normalized()
		spirit.global_position += dir * speed * d
		speed += d * 400.0

		if spirit.global_position.distance_to(target_pos) < 22.0:
			deal_damage(target, dmg)
			_spawn_impact(spirit.global_position)
			# 命中敌人蓝色闪光
			if is_instance_valid(target):
				target.modulate = Color(0.5, 0.7, 1.5, 1.0)
				get_tree().create_timer(0.12).timeout.connect(func():
					if is_instance_valid(target): target.modulate = Color(1, 1, 1, 1)
				)
			spirit.queue_free()
			return

	if is_instance_valid(spirit):
		spirit.queue_free()

func _fire_spirit_dir(spirit: Node2D, trail: GPUParticles2D, dir: Vector2, dmg: float) -> void:
	var speed = 550.0
	var start_pos = spirit.global_position
	var elapsed = 0.0

	if is_instance_valid(trail):
		trail.amount = 22
		trail.lifetime = 0.25

	while elapsed < 1.0:
		if not is_inside_tree(): return
		await get_tree().process_frame
		if not is_inside_tree(): return
		var d = get_process_delta_time()
		elapsed += d
		if not is_instance_valid(spirit): return
		spirit.global_position += dir * speed * d
		speed += d * 300.0

		for enemy in _get_enemies():
			if not is_instance_valid(enemy): continue
			if spirit.global_position.distance_to(enemy.global_position) < 24.0:
				deal_damage(enemy, dmg)
				_spawn_impact(spirit.global_position)
				if is_instance_valid(enemy):
					enemy.modulate = Color(0.5, 0.7, 1.5, 1.0)
					get_tree().create_timer(0.12).timeout.connect(func():
						if is_instance_valid(enemy): enemy.modulate = Color(1, 1, 1, 1)
					)
				spirit.queue_free()
				return

		if spirit.global_position.distance_to(start_pos) > 650:
			break

	if is_instance_valid(spirit):
		spirit.queue_free()

func _spawn_impact(pos: Vector2) -> void:
	# 冲击波环
	var ring = Line2D.new()
	ring.width = 2.0
	ring.default_color = Color(0.5, 0.7, 1.0, 0.8)
	for i in range(25):
		var a = (TAU / 24.0) * i
		ring.add_point(Vector2(cos(a) * 5, sin(a) * 5))
	ring.z_index = 9
	_get_spawn_root().add_child(ring)
	ring.global_position = pos
	var rtw = ring.create_tween()
	rtw.set_parallel(true)
	rtw.tween_property(ring, "scale", Vector2(6.0, 6.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rtw.tween_property(ring, "modulate:a", 0.0, 0.2)
	rtw.tween_callback(ring.queue_free).set_delay(0.2)

	# 粒子爆发
	var burst = GPUParticles2D.new()
	burst.emitting = false
	burst.amount = 22
	burst.lifetime = 0.3
	burst.explosiveness = 0.95
	burst.one_shot = true
	burst.local_coords = false
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 60.0
	pm.initial_velocity_max = 160.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 2.0
	pm.scale_max = 5.0
	var g = Gradient.new()
	g.set_color(0, Color(0.7, 0.85, 1.0, 1.0))
	g.set_color(1, Color(0.3, 0.5, 1.0, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	burst.process_material = pm
	_get_spawn_root().add_child(burst)
	burst.global_position = pos
	burst.emitting = true

	# 白色闪光球
	var flash = Sprite2D.new()
	var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for gx in range(8):
		for gy in range(8):
			var dist = Vector2(gx - 3.5, gy - 3.5).length() / 3.5
			var alpha = clampf(1.0 - dist, 0.0, 1.0)
			img.set_pixel(gx, gy, Color(0.7, 0.85, 1.0, alpha))
	flash.texture = ImageTexture.create_from_image(img)
	flash.scale = Vector2(4.0, 4.0)
	flash.z_index = 12
	_get_spawn_root().add_child(flash)
	flash.global_position = pos
	var ftw = flash.create_tween()
	ftw.set_parallel(true)
	ftw.tween_property(flash, "scale", Vector2(9.0, 9.0), 0.12)
	ftw.tween_property(flash, "modulate:a", 0.0, 0.15)
	ftw.tween_callback(flash.queue_free).set_delay(0.15)

	get_tree().create_timer(0.5).timeout.connect(burst.queue_free)
