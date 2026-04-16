extends Area2D
class_name DestructibleProp

# 道具类型决定交互效果
enum PropType { BARREL, CHEST, CRYSTAL, MUSHROOM, MAGIC_CIRCLE }

var prop_type: PropType = PropType.BARREL
var prop_hp: float = 1.0
var is_destroyed: bool = false
var _visual: Sprite2D = null
var _light: PointLight2D = null
var _triggered: bool = false

# 道具配置表
const PROP_CONFIG := {
	PropType.BARREL: {
		"hp": 1.0,
		"aoe_radius": 120.0,
		"aoe_damage": 40.0,
		"color": Color(0.9, 0.5, 0.1),
		"light_color": Color(1.0, 0.6, 0.2),
	},
	PropType.CHEST: {
		"hp": 0.0,  # 0 = 靠近自动触发
		"gold_min": 3,
		"gold_max": 8,
		"color": Color(1.0, 0.85, 0.2),
		"light_color": Color(1.0, 0.9, 0.4),
	},
	PropType.CRYSTAL: {
		"hp": 1.0,
		"freeze_radius": 140.0,
		"freeze_duration": 2.5,
		"color": Color(0.4, 0.7, 1.0),
		"light_color": Color(0.5, 0.8, 1.0),
	},
	PropType.MUSHROOM: {
		"hp": 1.0,
		"poison_radius": 100.0,
		"poison_damage": 8.0,
		"poison_duration": 3.0,
		"color": Color(0.3, 0.8, 0.2),
		"light_color": Color(0.4, 0.9, 0.3),
	},
	PropType.MAGIC_CIRCLE: {
		"hp": 0.0,  # 靠近自动触发
		"buff_duration": 6.0,
		"damage_bonus": 0.15,
		"color": Color(0.8, 0.5, 1.0),
		"light_color": Color(0.7, 0.4, 1.0),
	},
}

func setup(type: PropType, sprite: Sprite2D) -> void:
	prop_type = type
	_visual = sprite
	var cfg = PROP_CONFIG[type]
	prop_hp = cfg.hp
	add_to_group("destructible_props")

	# Layer 4 (value 8) = destructible_props
	collision_layer = 8
	collision_mask = 0
	monitoring = true
	monitorable = true

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 28.0
	shape.shape = circle
	add_child(shape)

	# 箱子和法阵用玩家接近触发
	if type == PropType.CHEST or type == PropType.MAGIC_CIRCLE:
		collision_mask = 1  # 检测玩家
		body_entered.connect(_on_player_enter)

	_setup_ambient_light(cfg.light_color)

func _setup_ambient_light(color: Color) -> void:
	_light = PointLight2D.new()
	_light.texture = _make_light_tex(64)
	_light.color = color
	_light.energy = 0.5
	_light.texture_scale = 2.0
	_light.shadow_enabled = false
	_light.z_index = -6
	add_child(_light)
	_pulse_light()

func _pulse_light() -> void:
	if not is_instance_valid(_light) or is_destroyed:
		return
	var tw = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_light, "energy", randf_range(0.35, 0.65), randf_range(0.8, 1.5))
	tw.tween_callback(_pulse_light)

func _on_player_enter(body: Node2D) -> void:
	if _triggered or is_destroyed:
		return
	if not body.is_in_group("player"):
		return
	_triggered = true
	match prop_type:
		PropType.CHEST:
			_effect_chest(body)
		PropType.MAGIC_CIRCLE:
			_effect_magic_circle(body)

func hit_by_skill(damage: float, _skill_pos: Vector2) -> void:
	if is_destroyed:
		return
	if prop_type == PropType.CHEST or prop_type == PropType.MAGIC_CIRCLE:
		return  # 这类道具不受攻击
	prop_hp -= 1.0
	if prop_hp <= 0:
		_destroy()

func _destroy() -> void:
	is_destroyed = true
	match prop_type:
		PropType.BARREL:
			_effect_barrel_explode()
		PropType.CRYSTAL:
			_effect_crystal_freeze()
		PropType.MUSHROOM:
			_effect_mushroom_poison()
		_:
			_cleanup()

# ── 桶：爆炸 AOE ────────────────────────────────────
func _effect_barrel_explode() -> void:
	var cfg = PROP_CONFIG[PropType.BARREL]
	var pos = global_position

	# 对范围内敌人造成伤害
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and pos.distance_to(enemy.global_position) <= cfg.aoe_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(cfg.aoe_damage, pos)

	_spawn_explosion_vfx(cfg.color, cfg.aoe_radius)
	EventBus.emit_signal("prop_destroyed", pos, "barrel")
	_cleanup()

# ── 箱子：掉金币 ─────────────────────────────────────
func _effect_chest(player: Node2D) -> void:
	var cfg = PROP_CONFIG[PropType.CHEST]
	var gold_amount = randi_range(cfg.gold_min, cfg.gold_max)

	# 弹出金币
	var main = get_tree().current_scene
	for i in range(mini(gold_amount, 5)):
		var coin = Area2D.new()
		if ResourceLoader.exists("res://scripts/systems/GoldCoin.gd"):
			coin.set_script(load("res://scripts/systems/GoldCoin.gd"))
			main.add_child(coin)
			coin.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
			coin.setup(maxi(1, gold_amount / 5))

	_spawn_open_vfx(cfg.color)
	EventBus.emit_signal("prop_destroyed", global_position, "chest")
	EventBus.emit_signal("pickup_float_text", global_position, "📦 宝箱!", Color(1.0, 0.85, 0.2))
	_cleanup()

# ── 水晶：冻结周围敌人 ───────────────────────────────
func _effect_crystal_freeze() -> void:
	var cfg = PROP_CONFIG[PropType.CRYSTAL]
	var pos = global_position

	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and pos.distance_to(enemy.global_position) <= cfg.freeze_radius:
			if enemy.has_method("apply_slow"):
				enemy.apply_slow(0.1, cfg.freeze_duration)
			elif "is_slowed" in enemy:
				enemy.is_slowed = true
				var orig_speed = enemy.base_move_speed if "base_move_speed" in enemy else 60.0
				if enemy.data:
					enemy.data.move_speed = orig_speed * 0.1
				get_tree().create_timer(cfg.freeze_duration).timeout.connect(func():
					if is_instance_valid(enemy) and enemy.data:
						enemy.data.move_speed = orig_speed
						enemy.is_slowed = false
				)

	_spawn_freeze_vfx(cfg.color, cfg.freeze_radius)
	EventBus.emit_signal("prop_destroyed", pos, "crystal")
	_cleanup()

# ── 蘑菇：毒雾区域 ──────────────────────────────────
func _effect_mushroom_poison() -> void:
	var cfg = PROP_CONFIG[PropType.MUSHROOM]
	var pos = global_position

	# 创建持续毒雾区域
	var poison_zone = Area2D.new()
	poison_zone.global_position = pos
	poison_zone.collision_layer = 0
	poison_zone.collision_mask = 2 | 1  # 检测敌人和玩家

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = cfg.poison_radius
	shape.shape = circle
	poison_zone.add_child(shape)

	var main = get_tree().current_scene
	main.add_child(poison_zone)

	# 毒雾视觉
	var vfx = CPUParticles2D.new()
	vfx.amount = 20
	vfx.lifetime = 1.5
	vfx.explosiveness = 0.0
	vfx.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	vfx.emission_sphere_radius = cfg.poison_radius * 0.6
	vfx.direction = Vector2(0, -1)
	vfx.spread = 60.0
	vfx.initial_velocity_min = 5.0
	vfx.initial_velocity_max = 15.0
	vfx.scale_amount_min = 4.0
	vfx.scale_amount_max = 10.0
	var grad = Gradient.new()
	grad.add_point(0.0, Color(0.2, 0.7, 0.1, 0.0))
	grad.add_point(0.2, Color(0.2, 0.7, 0.1, 0.35))
	grad.add_point(0.8, Color(0.4, 0.6, 0.1, 0.2))
	grad.add_point(1.0, Color(0.4, 0.6, 0.1, 0.0))
	vfx.color_ramp = grad
	vfx.z_index = -4
	poison_zone.add_child(vfx)

	# 持续伤害计时器
	var ticks_left := int(cfg.poison_duration / 0.5)
	var tick_timer = Timer.new()
	tick_timer.wait_time = 0.5
	tick_timer.autostart = true
	poison_zone.add_child(tick_timer)
	tick_timer.timeout.connect(func():
		ticks_left -= 1
		if ticks_left <= 0:
			poison_zone.queue_free()
			return
		var bodies = poison_zone.get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("enemies") and body.has_method("take_damage"):
				body.take_damage(cfg.poison_damage, pos)
	)

	EventBus.emit_signal("prop_destroyed", pos, "mushroom")
	_cleanup()

# ── 法阵：临时增伤 buff ──────────────────────────────
func _effect_magic_circle(player: Node2D) -> void:
	var cfg = PROP_CONFIG[PropType.MAGIC_CIRCLE]

	if "damage_multiplier" in player:
		var original_mult: float = player.damage_multiplier
		player.damage_multiplier += cfg.damage_bonus
		EventBus.emit_signal("pickup_float_text", global_position,
			"✨ 力量涌动! 伤害+%d%%" % int(cfg.damage_bonus * 100),
			Color(0.8, 0.5, 1.0))

		# buff 到期后恢复
		get_tree().create_timer(cfg.buff_duration).timeout.connect(func():
			if is_instance_valid(player):
				player.damage_multiplier = maxf(original_mult, player.damage_multiplier - cfg.damage_bonus)
		)

	_spawn_magic_vfx(cfg.color)
	EventBus.emit_signal("prop_destroyed", global_position, "magic_circle")
	_cleanup()

# ── VFX 辅助方法 ─────────────────────────────────────

func _spawn_explosion_vfx(color: Color, radius: float) -> void:
	var main = get_tree().current_scene
	var vfx = Node2D.new()
	vfx.global_position = global_position
	main.add_child(vfx)

	var burst = GPUParticles2D.new()
	burst.amount = 24
	burst.lifetime = 0.4
	burst.explosiveness = 0.95
	burst.one_shot = true
	burst.local_coords = false
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 60.0
	pm.initial_velocity_max = radius * 0.8
	pm.gravity = Vector3(0, 40, 0)
	pm.scale_min = 3.0
	pm.scale_max = 8.0
	var g = Gradient.new()
	g.set_color(0, Color(color.r * 1.5, color.g * 1.3, 0.2, 1.0))
	g.set_color(1, Color(color.r, 0.1, 0.0, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	burst.process_material = pm
	vfx.add_child(burst)
	burst.emitting = true

	# 爆炸闪光
	var flash = PointLight2D.new()
	flash.texture = _make_light_tex(64)
	flash.color = Color(color.r * 1.3, color.g * 1.1, 0.3)
	flash.energy = 3.0
	flash.texture_scale = radius / 30.0
	flash.shadow_enabled = false
	vfx.add_child(flash)
	var ftw = flash.create_tween()
	ftw.tween_property(flash, "energy", 0.0, 0.35)

	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(vfx): vfx.queue_free()
	)

func _spawn_open_vfx(color: Color) -> void:
	var main = get_tree().current_scene
	var sparkle = CPUParticles2D.new()
	sparkle.global_position = global_position
	sparkle.one_shot = true
	sparkle.emitting = false
	sparkle.amount = 12
	sparkle.lifetime = 0.6
	sparkle.explosiveness = 0.9
	sparkle.direction = Vector2(0, -1)
	sparkle.spread = 60.0
	sparkle.initial_velocity_min = 30.0
	sparkle.initial_velocity_max = 80.0
	sparkle.gravity = Vector2(0, 60)
	sparkle.scale_amount_min = 2.0
	sparkle.scale_amount_max = 4.0
	sparkle.color = color
	sparkle.z_index = 5
	main.add_child(sparkle)
	sparkle.emitting = true
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(sparkle): sparkle.queue_free()
	)

func _spawn_freeze_vfx(color: Color, radius: float) -> void:
	var main = get_tree().current_scene
	var ring = CPUParticles2D.new()
	ring.global_position = global_position
	ring.one_shot = true
	ring.emitting = false
	ring.amount = 30
	ring.lifetime = 0.5
	ring.explosiveness = 0.95
	ring.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	ring.emission_ring_radius = radius * 0.8
	ring.emission_ring_inner_radius = radius * 0.2
	ring.emission_ring_height = 0.0
	ring.emission_ring_axis = Vector3(0, 0, 1)
	ring.direction = Vector2(0, -1)
	ring.spread = 30.0
	ring.initial_velocity_min = 10.0
	ring.initial_velocity_max = 40.0
	ring.scale_amount_min = 3.0
	ring.scale_amount_max = 7.0
	ring.color = Color(color.r, color.g, color.b, 0.7)
	ring.z_index = 5
	main.add_child(ring)
	ring.emitting = true

	var flash = PointLight2D.new()
	flash.global_position = global_position
	flash.texture = _make_light_tex(64)
	flash.color = color
	flash.energy = 2.5
	flash.texture_scale = radius / 25.0
	flash.shadow_enabled = false
	main.add_child(flash)
	var ftw = flash.create_tween()
	ftw.tween_property(flash, "energy", 0.0, 0.5)
	ftw.tween_callback(flash.queue_free)

	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(ring): ring.queue_free()
	)

func _spawn_magic_vfx(color: Color) -> void:
	var main = get_tree().current_scene
	var glow = CPUParticles2D.new()
	glow.global_position = global_position
	glow.one_shot = true
	glow.emitting = false
	glow.amount = 16
	glow.lifetime = 0.8
	glow.explosiveness = 0.85
	glow.direction = Vector2(0, -1)
	glow.spread = 20.0
	glow.initial_velocity_min = 40.0
	glow.initial_velocity_max = 100.0
	glow.scale_amount_min = 2.0
	glow.scale_amount_max = 5.0
	glow.color = Color(color.r, color.g, color.b, 0.8)
	glow.z_index = 5
	main.add_child(glow)
	glow.emitting = true
	get_tree().create_timer(1.2).timeout.connect(func():
		if is_instance_valid(glow): glow.queue_free()
	)

func _cleanup() -> void:
	if is_instance_valid(_visual):
		# 隐藏 sprite 而非销毁，因为它可能还在背景系统的对象池中
		_visual.visible = false
	queue_free()

static func _make_light_tex(sz: int) -> ImageTexture:
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var center := Vector2(sz * 0.5, sz * 0.5)
	for y in range(sz):
		for x in range(sz):
			var dist := Vector2(x, y).distance_to(center) / (sz * 0.5)
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			alpha = alpha * alpha
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)
