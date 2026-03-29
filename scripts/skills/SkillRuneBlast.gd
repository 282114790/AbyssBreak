# SkillRuneBlast.gd
# 爆裂符文 - 在随机敌人脚下放置旋转符文，1.5秒后大爆炸
extends SkillBase
class_name SkillRuneBlast

var explosion_radius: float = 100.0

func activate() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	var target = enemies[randi() % enemies.size()]
	if not is_instance_valid(target):
		return
	_spawn_rune(target.global_position)

func _spawn_rune(pos: Vector2) -> void:
	var rune_node = Node2D.new()
	rune_node.global_position = pos
	get_tree().current_scene.add_child(rune_node)

	# 创建显眼符文视觉
	var rune_visual = _create_rune_visual()
	rune_node.add_child(rune_visual)
	rune_node.set_meta("damage", get_current_damage())

	# 倒计时变红闪烁（tween 在最后0.5秒快速闪烁）
	var blink_timer = get_tree().create_timer(1.0)
	blink_timer.timeout.connect(func():
		if not is_instance_valid(rune_node):
			return
		var blink_tween = rune_node.create_tween().set_loops(5)
		blink_tween.tween_property(rune_node, "modulate:a", 0.2, 0.05)
		blink_tween.tween_property(rune_node, "modulate:a", 1.0, 0.05)
	)

	# 1.5秒后爆炸
	get_tree().create_timer(1.5).timeout.connect(_explode.bind(rune_node))

func _create_rune_visual() -> Node2D:
	var root = Node2D.new()

	# 外六边形（旋转）
	var outer = Polygon2D.new()
	outer.color = Color(1.0, 0.6, 0.1, 0.8)
	var pts = PackedVector2Array()
	for i in range(6):
		var a = (PI / 3.0) * i
		pts.append(Vector2(cos(a) * 18, sin(a) * 18))
	outer.polygon = pts
	root.add_child(outer)

	# 内方块（反向旋转）
	var inner = ColorRect.new()
	inner.size = Vector2(14, 14)
	inner.position = Vector2(-7, -7)
	inner.color = Color(1.0, 0.3, 0.0)
	root.add_child(inner)

	# 旋转动画（循环）
	var tween = root.create_tween().set_loops()
	tween.set_parallel(true)
	tween.tween_property(outer, "rotation_degrees", 360.0, 1.5)
	tween.tween_property(inner, "rotation_degrees", -360.0, 1.0)

	return root

func _explode(rune_node: Node2D) -> void:
	if not is_instance_valid(rune_node):
		return

	var pos = rune_node.global_position
	var dmg = rune_node.get_meta("damage")

	# 爆炸伤害范围内所有敌人
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if pos.distance_to(enemy.global_position) <= explosion_radius * 2.0:
			enemy.take_damage(dmg)

	# 爆炸视觉：多圈扩散
	_spawn_explosion_visual(pos)

	# 爆炸音效
	var snd = get_tree().get_first_node_in_group("sound_manager")
	if snd:
		snd.play_explosion()

	rune_node.queue_free()

func _spawn_explosion_visual(pos: Vector2) -> void:
	# 多圈扩散爆炸
	for ring in range(3):
		var circle = Polygon2D.new()
		circle.color = Color(1.0, 0.5 - ring * 0.15, 0.0, 0.7 - ring * 0.2)
		var pts = PackedVector2Array()
		for i in range(16):
			var a = (TAU / 16.0) * i
			pts.append(Vector2(cos(a) * 20, sin(a) * 20))
		circle.polygon = pts
		circle.global_position = pos
		circle.z_index = 10
		get_tree().current_scene.add_child(circle)
		var target_scale = Vector2(4.0 + ring * 2.0, 4.0 + ring * 2.0)
		var delay = ring * 0.06
		var tween = circle.create_tween()
		tween.set_parallel(true)
		tween.tween_property(circle, "scale", target_scale, 0.4).set_delay(delay)
		tween.tween_property(circle, "modulate:a", 0.0, 0.4).set_delay(delay)
		tween.tween_callback(circle.queue_free).set_delay(delay + 0.4)
