extends Area2D
class_name GoldCoin

var gold_value: int = 1
var attract_speed: float = 350.0
var is_attracting: bool = false
var player: Node2D = null

func setup(value: int) -> void:
	gold_value = value

func _ready() -> void:
	add_to_group("gold_coins")
	player = get_tree().get_first_node_in_group("player")
	collision_layer = 8
	collision_mask = 1
	monitoring = true

	var sprite = Sprite2D.new()
	sprite.texture = load("res://assets/sprites/effects/gold_coin.png")
	sprite.scale = Vector2(0.5, 0.5)
	add_child(sprite)

	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 10.0
	col.shape = circle
	add_child(col)

	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "scale", Vector2(0.55, 0.45), 0.35).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.35).set_ease(Tween.EASE_IN_OUT)

	body_entered.connect(_on_collected)

	var timer = get_tree().create_timer(10.0)
	timer.timeout.connect(queue_free)

func _process(delta: float) -> void:
	if not is_attracting or not is_instance_valid(player):
		return
	var dist = global_position.distance_to(player.global_position)
	if dist <= 15.0:
		_collect()
		return
	var speed = clamp(attract_speed + (100.0 - dist) * 3.5, attract_speed, 700.0)
	var dir = global_position.direction_to(player.global_position)
	global_position += dir * speed * delta

func attract() -> void:
	is_attracting = true
	modulate = Color(1.4, 1.2, 0.6)

func _collect() -> void:
	if not is_instance_valid(player):
		return
	player.gold += gold_value
	EventBus.emit_signal("pickup_float_text", global_position, "+%d 金币" % gold_value, Color(1.0, 0.85, 0.2))
	queue_free()

func _on_collected(body: Node2D) -> void:
	if body.is_in_group("player"):
		_collect()
