# RelicDrop.gd
# 遗物掉落物节点——玩家走过去触发3选1面板
extends Area2D

var _collected: bool = false
var _label: Label
var _bob_offset: float = 0.0
var _bob_time: float = 0.0
var relics_to_offer: Array = []  # 3个RelicData候选

func _ready() -> void:
	# 碰撞层：layer=4(遗物), mask=1(玩家)
	collision_layer = 4
	collision_mask = 1
	body_entered.connect(_on_body_entered)

	# 视觉：发光圆圈 + emoji标签
	var circle = ColorRect.new()
	circle.size = Vector2(36, 36)
	circle.position = Vector2(-18, -18)
	circle.color = Color(0.9, 0.75, 0.1, 0.85)  # 金色
	add_child(circle)

	_label = Label.new()
	_label.text = "🎁"
	_label.add_theme_font_size_override("font_size", 28)
	_label.position = Vector2(-16, -22)
	add_child(_label)

	# 提示文字
	var hint = Label.new()
	hint.text = "遗物"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	hint.position = Vector2(-18, 20)
	add_child(hint)

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
	if choices.size() > 0:
		_label.text = choices[0].icon_emoji

func _on_body_entered(body: Node) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	EventBus.emit_signal("relic_drop_touched", relics_to_offer)
	queue_free()
