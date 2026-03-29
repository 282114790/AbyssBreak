extends Node2D
# 敌人死亡爆炸特效 - GPUParticles2D 实现

func setup(color: Color) -> void:
	# ── 第一波：冲击波扩散（快速向外爆开）──────────────
	var burst = GPUParticles2D.new()
	burst.emitting = false
	burst.amount = 32
	burst.lifetime = 0.35
	burst.explosiveness = 0.95   # 几乎同时爆出
	burst.randomness = 0.1
	burst.one_shot = true
	burst.local_coords = false

	var pm1 = ParticleProcessMaterial.new()
	pm1.direction = Vector3(0, -1, 0)
	pm1.spread = 180.0           # 全方向
	pm1.initial_velocity_min = 80.0
	pm1.initial_velocity_max = 160.0
	pm1.gravity = Vector3(0, 0, 0)
	pm1.scale_min = 4.0
	pm1.scale_max = 10.0
	var g1 = Gradient.new()
	g1.set_color(0, Color(color.r * 1.5, color.g * 1.2, 0.1, 1.0))
	g1.set_color(1, Color(color.r, 0.1, 0.0, 0.0))
	var gt1 = GradientTexture1D.new()
	gt1.gradient = g1
	pm1.color_ramp = gt1
	burst.process_material = pm1
	add_child(burst)

	# ── 第二波：火星四溅（慢速飘落）──────────────────
	var sparks = GPUParticles2D.new()
	sparks.emitting = false
	sparks.amount = 16
	sparks.lifetime = 0.6
	sparks.explosiveness = 0.8
	sparks.one_shot = true
	sparks.local_coords = false

	var pm2 = ParticleProcessMaterial.new()
	pm2.direction = Vector3(0, -1, 0)
	pm2.spread = 180.0
	pm2.initial_velocity_min = 40.0
	pm2.initial_velocity_max = 100.0
	pm2.gravity = Vector3(0, 80, 0)   # 向下掉落
	pm2.scale_min = 2.0
	pm2.scale_max = 5.0
	var g2 = Gradient.new()
	g2.set_color(0, Color(1.0, 0.9, 0.3, 1.0))
	g2.set_color(1, Color(0.8, 0.2, 0.0, 0.0))
	var gt2 = GradientTexture1D.new()
	gt2.gradient = g2
	pm2.color_ramp = gt2
	sparks.process_material = pm2
	add_child(sparks)

	# ── 第三波：烟雾扩散（缓慢膨胀消散）──────────────
	var smoke = GPUParticles2D.new()
	smoke.emitting = false
	smoke.amount = 8
	smoke.lifetime = 0.8
	smoke.explosiveness = 0.9
	smoke.one_shot = true
	smoke.local_coords = false

	var pm3 = ParticleProcessMaterial.new()
	pm3.direction = Vector3(0, -1, 0)
	pm3.spread = 60.0
	pm3.initial_velocity_min = 10.0
	pm3.initial_velocity_max = 30.0
	pm3.gravity = Vector3(0, -20, 0)   # 烟雾上升
	pm3.scale_min = 12.0
	pm3.scale_max = 22.0
	var g3 = Gradient.new()
	g3.set_color(0, Color(0.4, 0.3, 0.3, 0.5))
	g3.set_color(1, Color(0.2, 0.2, 0.2, 0.0))
	var gt3 = GradientTexture1D.new()
	gt3.gradient = g3
	pm3.color_ramp = gt3
	smoke.process_material = pm3
	add_child(smoke)

	# 同时触发三波
	burst.emitting = true
	sparks.emitting = true
	smoke.emitting = true

	# 1秒后清理
	await get_tree().create_timer(1.0).timeout
	queue_free()
