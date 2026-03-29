# ExperienceGem.gd
# 经验宝石 - 怪物死亡掉落
extends Area2D
class_name ExperienceGem

var exp_value: int = 5
var attract_speed: float = 400.0
var is_attracting: bool = false
var player: Node2D = null
var _sprite: Sprite2D = null

func setup(value: int) -> void:
	exp_value = value

func _ready() -> void:
	add_to_group("exp_gems")
	player = get_tree().get_first_node_in_group("player")
	collision_layer = 8
	collision_mask = 1
	monitoring = true

	# 精灵图
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/effects/gem.png")
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(2.5, 2.5)
	add_child(_sprite)

	# 碰撞体
	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 10.0
	col.shape = circle
	add_child(col)

	# 旋转动画
	var tween = create_tween().set_loops()
	tween.tween_property(_sprite, "rotation_degrees", 360.0, 1.2)

	body_entered.connect(_on_collected)

	# 8秒后自动消失
	var timer = get_tree().create_timer(8.0)
	timer.timeout.connect(queue_free)

func _process(delta: float) -> void:
	if not is_attracting or not is_instance_valid(player):
		return
	var dist = global_position.distance_to(player.global_position)
	# 加速：越近越快（最高800），到达15px内直接拾取
	if dist <= 15.0:
		_collect()
		return
	var speed = clamp(attract_speed + (120.0 - dist) * 4.0, attract_speed, 800.0)
	var dir = global_position.direction_to(player.global_position)
	global_position += dir * speed * delta

func attract() -> void:
	is_attracting = true
	# 吸附时宝石变亮
	if _sprite:
		_sprite.modulate = Color(1.5, 1.5, 1.0)

func _collect() -> void:
	if not is_instance_valid(player):
		return
	player.gain_exp(exp_value)
	var snd = get_tree().get_first_node_in_group("sound_manager")
	if snd:
		snd.play_gem_pickup()
	EventBus.gem_collected.emit(exp_value)
	queue_free()

func _on_collected(body: Node2D) -> void:
	if body.is_in_group("player"):
		_collect()
