# RelicDrop.gd
# 遗物掉落物——玩家触碰后自动随机获得
extends Area2D

var _collected: bool = false
var _label: Label
var _bob_offset: float = 0.0
var _bob_time: float = 0.0
var relics_to_offer: Array = []

func _ready() -> void:
	# 碰撞层：layer=4(遗物), mask=1(玩家)
	collision_layer = 4
	collision_mask = 1
	body_entered.connect(_on_body_entered)

	# 视觉：魔法宝箱图标
	var sprite = Sprite2D.new()
	sprite.name = "RelicSprite"
	var icon_path := "res://assets/ui/relic_drop.png"
	if ResourceLoader.exists(icon_path):
		sprite.texture = load(icon_path)
		sprite.scale = Vector2(0.7, 0.7)
	add_child(sprite)

	_label = Label.new()
	_label.text = "遗物"
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-18, 20)
	add_child(_label)

	var col = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 28.0
	col.shape = circle_shape
	add_child(col)

	# 出现动画
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK)

func _process(delta: float) -> void:
	# 上下漂浮
	_bob_time += delta * 2.5
	_bob_offset = sin(_bob_time) * 5.0
	position.y += _bob_offset * delta  # 微量叠加，实际用tween或直接改y

func setup(choices: Array) -> void:
	relics_to_offer = choices

func _on_body_entered(body: Node) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	EventBus.emit_signal("relic_drop_touched", relics_to_offer)
	queue_free()
