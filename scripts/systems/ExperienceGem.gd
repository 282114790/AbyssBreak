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

	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/effects/exp_gem.png")
	_sprite.scale = Vector2(0.45, 0.45)
	add_child(_sprite)

	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 10.0
	col.shape = circle
	add_child(col)

	var tween = create_tween().set_loops()
	tween.tween_property(_sprite, "scale", Vector2(0.5, 0.5), 0.5).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_sprite, "scale", Vector2(0.45, 0.45), 0.5).set_ease(Tween.EASE_IN_OUT)

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
		_sprite.modulate = Color(1.3, 1.3, 1.5)

func _collect() -> void:
	if not is_instance_valid(player):
		return
	player.gain_exp(exp_value)
	var snd = get_tree().get_first_node_in_group("sound_manager")
	if snd:
		snd.play_gem_pickup()
	EventBus.gem_collected.emit(exp_value)
	EventBus.emit_signal("pickup_float_text", global_position, "+%d EXP" % exp_value, Color(0.5, 0.8, 1.0))
	queue_free()

func _on_collected(body: Node2D) -> void:
	if body.is_in_group("player"):
		_collect()
