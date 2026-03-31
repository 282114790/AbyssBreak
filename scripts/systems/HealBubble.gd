# HealBubble.gd
# 治疗气泡 - 玩家走过拾取恢复血量
extends Area2D

var heal_amount: float = 20.0
var _collected: bool = false
var _bob_time: float = 0.0

func _ready() -> void:
	add_to_group("heal_bubbles")
	collision_layer = 8
	collision_mask = 1
	body_entered.connect(_on_body_entered)

	# 绿色气泡外观
	var circle = ColorRect.new()
	circle.size = Vector2(28, 28)
	circle.position = Vector2(-14, -14)
	circle.color = Color(0.2, 0.9, 0.3, 0.85)
	add_child(circle)

	var lbl = Label.new()
	lbl.text = "💚"
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.position = Vector2(-12, -16)
	add_child(lbl)

	var col = CollisionShape2D.new()
	var cs = CircleShape2D.new()
	cs.radius = 20.0
	col.shape = cs
	add_child(col)

	# 出现动画
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK)
	# 30秒后自动消失
	get_tree().create_timer(30.0).timeout.connect(func():
		if is_instance_valid(self): queue_free()
	)

func setup(amount: float) -> void:
	heal_amount = amount

func _process(delta: float) -> void:
	_bob_time += delta * 3.0
	position.y = position.y + sin(_bob_time) * 0.3

func _on_body_entered(body: Node) -> void:
	if _collected or not body.is_in_group("player"): return
	_collected = true
	body.heal(heal_amount)
	# 拾取特效
	var fx = GPUParticles2D.new()
	fx.emitting = false
	fx.one_shot = true
	fx.amount = 10
	fx.lifetime = 0.4
	fx.explosiveness = 0.9
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 40.0
	pm.initial_velocity_max = 80.0
	pm.gravity = Vector3(0, 0, 0)
	pm.scale_min = 4.0
	pm.scale_max = 8.0
	var g = Gradient.new()
	g.set_color(0, Color(0.3, 1.0, 0.4, 1.0))
	g.set_color(1, Color(0.1, 0.8, 0.2, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	fx.process_material = pm
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position
	fx.emitting = true
	get_tree().create_timer(0.5).timeout.connect(fx.queue_free)
	queue_free()
