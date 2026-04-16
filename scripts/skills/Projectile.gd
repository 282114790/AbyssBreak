# Projectile.gd
# 通用投射物脚本
extends Area2D
class_name Projectile

var damage: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.ZERO
var target: Node2D = null
var speed: float = 400.0
var pierce_count: int = 1
var hit_enemies: Array = []
var is_homing: bool = true   # 是否追踪目标
var lifetime: float = 5.0
var owner_skill: SkillBase = null  # 用于暴击计算

# 拖尾
var trail: Line2D
var trail_positions: Array = []   # 历史全局位置

func setup(_damage: float, _target: Node2D, _speed: float, _pierce: int, _homing: bool = true) -> void:
	damage = _damage
	target = _target
	speed = _speed
	pierce_count = _pierce
	is_homing = _homing
	if target:
		velocity = global_position.direction_to(target.global_position) * speed
		direction = velocity.normalized()

func setup_dir(dmg: float, dir: Vector2, spd: float, pierce: int = 1) -> void:
	damage = dmg
	speed = spd
	pierce_count = pierce
	direction = dir.normalized()
	velocity = direction * speed
	target = null
	collision_mask = 2 | 8
	body_entered.connect(_on_hit)

func _ready() -> void:
	add_to_group("player_projectiles")
	# 碰撞层：layer 3=player_projectiles(value=4), mask 2=enemies(value=2) + 4=props(value=8)
	collision_layer = 4
	collision_mask = 2 | 8
	monitoring = true
	monitorable = true
	if not body_entered.is_connected(_on_hit):
		body_entered.connect(_on_hit)
	if not area_entered.is_connected(_on_area_hit):
		area_entered.connect(_on_area_hit)
	# 自动销毁（优先归还对象池）
	var timer = get_tree().create_timer(lifetime)
	timer.timeout.connect(_return_to_pool)

func _process(delta: float) -> void:
	if EventBus.game_logic_paused:
		return
	if target != null and is_instance_valid(target):
		if is_homing:
			var dir = global_position.direction_to(target.global_position)
			velocity = velocity.lerp(dir * speed, 0.1)
			direction = velocity.normalized()
		else:
			direction = global_position.direction_to(target.global_position)
			velocity = direction * speed
	global_position += direction * speed * delta
	# Line2D 拖尾已移除，尾迹由 SkillFireball 的 GPUParticles2D 负责

func _on_hit(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return
	if body in hit_enemies:
		return
	hit_enemies.append(body)
	# 暴击判断
	if owner_skill and is_instance_valid(owner_skill):
		owner_skill.deal_damage(body, damage)
	else:
		body.take_damage(damage)
	_spawn_hit_effect()
	pierce_count -= 1
	if pierce_count <= 0:
		_return_to_pool()

func _on_area_hit(area: Area2D) -> void:
	if area.has_method("hit_by_skill"):
		area.hit_by_skill(damage, global_position)

func _return_to_pool() -> void:
	var pool = get_tree().current_scene.get_node_or_null("ObjectPool")
	if pool and pool.has_method("release"):
		pool.release(self)
	else:
		queue_free()

func reset_for_pool() -> void:
	visible = false
	velocity = Vector2.ZERO
	target = null
	pierce_count = 1

func _spawn_hit_effect() -> void:
	var hit = GPUParticles2D.new()
	hit.emitting = false
	hit.amount = 12
	hit.lifetime = 0.25
	hit.explosiveness = 0.95
	hit.one_shot = true
	hit.local_coords = false

	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 60.0
	pm.initial_velocity_max = 120.0
	pm.gravity = Vector3(0, 0, 0)
	pm.scale_min = 3.0
	pm.scale_max = 7.0
	var g = Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.4, 1.0))
	g.set_color(1, Color(0.9, 0.2, 0.0, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	hit.process_material = pm

	get_tree().current_scene.add_child(hit)
	hit.global_position = global_position
	hit.emitting = true

	# 自动清理
	get_tree().create_timer(0.5).timeout.connect(hit.queue_free)
