@tool
# SkillHolyWave.gd
# 圣光波：神圣光环从玩家向外爆发扩散，GPUParticles2D 实现
extends SkillBase
class_name SkillHolyWave

# 生成一个圆形粒子纹理（16×16 软边圆）
func _make_circle_texture(size: int = 16) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = size * 0.5
	var radius = center - 1.0
	for y in range(size):
		for x in range(size):
			var dist = Vector2(x + 0.5 - center, y + 0.5 - center).length()
			var alpha = clampf(1.0 - (dist / radius), 0.0, 1.0)
			alpha = alpha * alpha  # 软边
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)

func activate() -> void:
	if not owner_player:
		return
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm: sm.play_shoot()

	# 只保留扩散圆环，去掉中心爆发
	_spawn_ring_wave()

# ── 中心爆发光粒子 ─────────────────────────────────────────
func _spawn_holy_burst() -> void:
	# 第一层：向外爆散的白金色光粒子（更小更克制）
	var burst = GPUParticles2D.new()
	burst.emitting = false
	burst.amount = 32
	burst.lifetime = 0.9
	burst.explosiveness = 0.85
	burst.one_shot = true
	burst.local_coords = false

	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 80.0
	pm.initial_velocity_max = 200.0 + level * 15.0
	pm.gravity = Vector3(0, 0, 0)
	pm.scale_min = 2.0
	pm.scale_max = 6.0
	var g = Gradient.new()
	g.set_color(0, Color(1.0, 1.0, 0.85, 1.0))   # 白金，不刺眼
	g.set_color(1, Color(1.0, 0.85, 0.5, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	burst.process_material = pm
	burst.texture = _make_circle_texture(16)  # 圆形粒子
	_get_spawn_root().add_child(burst)
	burst.global_position = owner_player.global_position
	burst.emitting = true

	# 第二层：慢速飘散的白色光尘（数量减半）
	var dust = GPUParticles2D.new()
	dust.emitting = false
	dust.amount = 12
	dust.lifetime = 1.2
	dust.explosiveness = 0.7
	dust.one_shot = true
	dust.local_coords = false

	var pm2 = ParticleProcessMaterial.new()
	pm2.direction = Vector3(0, -1, 0)
	pm2.spread = 180.0
	pm2.initial_velocity_min = 20.0
	pm2.initial_velocity_max = 50.0
	pm2.gravity = Vector3(0, -20, 0)
	pm2.scale_min = 3.0
	pm2.scale_max = 7.0
	var g2 = Gradient.new()
	g2.set_color(0, Color(1.0, 1.0, 1.0, 0.6))
	g2.set_color(1, Color(0.9, 0.95, 1.0, 0.0))
	var gt2 = GradientTexture1D.new()
	gt2.gradient = g2
	pm2.color_ramp = gt2
	dust.process_material = pm2
	dust.texture = _make_circle_texture(12)  # 圆形粒子（稍小）
	_get_spawn_root().add_child(dust)
	dust.global_position = owner_player.global_position
	dust.emitting = true

	get_tree().create_timer(1.5).timeout.connect(burst.queue_free)
	get_tree().create_timer(1.5).timeout.connect(dust.queue_free)

# ── 扩散光环（碰撞伤害）──────────────────────────────────
func _spawn_ring_wave() -> void:
	var ring = Area2D.new()
	ring.add_to_group("player_projectiles")
	ring.collision_layer = 4
	ring.collision_mask = 2
	ring.monitoring = true
	ring.global_position = owner_player.global_position

	# 视觉：只画一条细线圆环（Line2D），中间完全透明
	var line = Line2D.new()
	line.width = 3.0
	line.default_color = Color(1.0, 1.0, 0.8, 0.9)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	for i in range(65):  # 多一个点闭合
		var a = (TAU / 64.0) * i
		line.add_point(Vector2(cos(a) * 28, sin(a) * 28))
	ring.add_child(line)

	# 环边缘少量尾波粒子（仅在圆周上生成，不往内扩散）
	var rim_particles = GPUParticles2D.new()
	rim_particles.emitting = true
	rim_particles.amount = 20
	rim_particles.lifetime = 0.4
	rim_particles.explosiveness = 0.0
	rim_particles.local_coords = true

	var rp = ParticleProcessMaterial.new()
	rp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	rp.emission_ring_radius = 28.0
	rp.emission_ring_inner_radius = 26.0
	rp.emission_ring_height = 0.0
	rp.emission_ring_axis = Vector3(0, 0, 1)
	rp.direction = Vector3(0, 0, 1)
	rp.spread = 0.0
	rp.initial_velocity_min = 0.0
	rp.initial_velocity_max = 0.0
	rp.gravity = Vector3(0, 0, 0)
	rp.scale_min = 1.5
	rp.scale_max = 3.5
	var rg = Gradient.new()
	rg.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	rg.set_color(1, Color(1.0, 0.8, 0.3, 0.0))
	var rgt = GradientTexture1D.new()
	rgt.gradient = rg
	rp.color_ramp = rgt
	rim_particles.process_material = rp
	rim_particles.texture = _make_circle_texture(8)
	ring.add_child(rim_particles)

	# 碰撞
	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 28.0
	col.shape = circle
	ring.add_child(col)

	_get_spawn_root().add_child(ring)

	# 伤害
	var dmg = get_current_damage()
	var hit_enemies = {}
	ring.body_entered.connect(func(body):
		if body.is_in_group("enemies") and not hit_enemies.has(body.get_instance_id()):
			hit_enemies[body.get_instance_id()] = true
			body.take_damage(dmg)
	)

	# 扩散：匀速扩散
	var max_scale = 18.0
	var duration = 0.9 + level * 0.03
	var tween = ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(max_scale, max_scale), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, duration * 0.85).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(ring.queue_free).set_delay(duration)

	# 余波：0.15s 后出现一个较慢的细环跟在后面
	get_tree().create_timer(0.15).timeout.connect(func():
		if not is_instance_valid(owner_player): return
		var echo = Area2D.new()
		echo.collision_layer = 0
		echo.collision_mask = 0
		echo.global_position = owner_player.global_position
		var echo_line = Line2D.new()
		echo_line.width = 1.5
		echo_line.default_color = Color(1.0, 1.0, 0.7, 0.5)
		echo_line.joint_mode = Line2D.LINE_JOINT_ROUND
		for i in range(65):
			var a2 = (TAU / 64.0) * i
			echo_line.add_point(Vector2(cos(a2) * 28, sin(a2) * 28))
		echo.add_child(echo_line)
		_get_spawn_root().add_child(echo)
		var echo_tween = echo.create_tween()
		echo_tween.set_parallel(true)
		echo_tween.tween_property(echo, "scale", Vector2(max_scale * 0.75, max_scale * 0.75), duration * 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		echo_tween.tween_property(echo, "modulate:a", 0.0, duration * 0.9).set_trans(Tween.TRANS_QUAD)
		echo_tween.tween_callback(echo.queue_free).set_delay(duration * 1.1)
	)
