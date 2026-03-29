# SkillOrbital.gd
# 绕身旋转类技能（魔法护盾）— 使用 shield.png spritesheet
extends SkillBase
class_name SkillOrbital

var orbs: Array = []
var rotation_speed: float = 3.5
var angle_offset: float = 0.0
var hit_cooldowns: Dictionary = {}

func _ready() -> void:
	call_deferred("_spawn_orbs")

func _process(delta: float) -> void:
	if EventBus.game_logic_paused:
		return
	angle_offset += rotation_speed * delta
	if owner_player and is_instance_valid(owner_player):
		_update_orb_positions()

func activate() -> void:
	pass

func _spawn_orbs() -> void:
	for o in orbs:
		if is_instance_valid(o): o.queue_free()
	orbs.clear()
	if data == null:
		return
	var count = max(1, data.projectile_count + (level - 1))
	for i in range(count):
		var orb = _create_orb()
		add_child(orb)
		orbs.append(orb)

func _create_orb() -> Node2D:
	var orb = Area2D.new()

	# 碰撞体
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	orb.add_child(shape)

	# 用 shield.png spritesheet 做动画
	var tex = load("res://assets/sprites/effects/shield.png")
	if tex:
		var anim = AnimatedSprite2D.new()
		anim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		anim.scale = Vector2(0.22, 0.22)   # 每帧256x279，显示约60px
		var sf = SpriteFrames.new()
		sf.add_animation("spin")
		sf.set_animation_loop("spin", true)
		sf.set_animation_speed("spin", 10.0)
		for i in range(8):
			var atlas = AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * 256, 0, 256, 279)
			atlas.filter_clip = true
			sf.add_frame("spin", atlas)
		anim.sprite_frames = sf
		anim.play("spin")
		orb.add_child(anim)
	else:
		# 兜底：发光圆
		var poly = Polygon2D.new()
		poly.color = Color(0.3, 0.85, 1.0)
		var pts = PackedVector2Array()
		for i in range(12):
			var a = (TAU / 12.0) * i
			pts.append(Vector2(cos(a) * 16.0, sin(a) * 16.0))
		poly.polygon = pts
		orb.add_child(poly)

	# 粒子拖尾（替代 Line2D）
	var trail = GPUParticles2D.new()
	trail.emitting = true
	trail.amount = 8
	trail.lifetime = 0.3
	trail.explosiveness = 0.0
	trail.local_coords = false

	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, 0, 0)
	pm.scale_min = 2.0
	pm.scale_max = 5.0
	var g = Gradient.new()
	g.set_color(0, Color(0.4, 0.8, 1.0, 0.7))
	g.set_color(1, Color(0.1, 0.5, 1.0, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	trail.process_material = pm
	orb.add_child(trail)

	orb.add_to_group("player_projectiles")
	orb.body_entered.connect(_on_orb_hit.bind(orb))
	return orb

func _update_orb_positions() -> void:
	var radius = 90.0 + level * 15.0
	for i in range(orbs.size()):
		if not is_instance_valid(orbs[i]):
			continue
		var angle = angle_offset + (TAU / orbs.size()) * i
		orbs[i].global_position = owner_player.global_position + Vector2(cos(angle), sin(angle)) * radius

func _on_orb_hit(body: Node2D, _orb: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return
	var uid = body.get_instance_id()
	if hit_cooldowns.get(uid, 0.0) > 0.0:
		return
	body.take_damage(get_current_damage())
	hit_cooldowns[uid] = 0.4

func _physics_process(delta: float) -> void:
	for k in hit_cooldowns.keys():
		hit_cooldowns[k] -= delta
		if hit_cooldowns[k] <= 0:
			hit_cooldowns.erase(k)

func on_level_up() -> void:
	_spawn_orbs()
