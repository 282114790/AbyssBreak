# SkillIceBlade.gd
# 冰刃术 - 真实雪花图形，6尖角+6短臂，随等级增加方向数
extends SkillBase
class_name SkillIceBlade

func activate() -> void:
	if not owner_player:
		return
	# Lv1=4, Lv2=5, Lv3=6, Lv4=7, Lv5=8
	var dir_count = max(4, min(8, level + 3))

	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm: sm.play_shoot()

	for i in range(dir_count):
		var angle = (TAU / dir_count) * i
		var dir = Vector2(cos(angle), sin(angle))
		_spawn_snowflake(dir)

func _make_snowflake_polygon(outer_r: float, inner_r: float, arm_w: float) -> PackedVector2Array:
	# 真实雪花：6个主尖角 + 6个短臂（每个主臂中间有两个小侧刺）
	var pts = PackedVector2Array()
	var arms = 6
	for i in range(arms):
		var base_angle = (TAU / arms) * i - PI / 2.0
		# 主臂尖端
		pts.append(Vector2(cos(base_angle) * outer_r, sin(base_angle) * outer_r))
		# 右侧刺（60%处向右）
		var mid_angle_r = base_angle + deg_to_rad(18)
		pts.append(Vector2(cos(mid_angle_r) * inner_r * 1.1, sin(mid_angle_r) * inner_r * 1.1))
		# 主臂中心点（向内收）
		pts.append(Vector2(cos(base_angle) * arm_w, sin(base_angle) * arm_w))
		# 左侧刺（60%处向左）
		var mid_angle_l = base_angle - deg_to_rad(18)
		pts.append(Vector2(cos(mid_angle_l) * inner_r * 1.1, sin(mid_angle_l) * inner_r * 1.1))
		# 下一个臂之间的凹陷
		var next_angle = base_angle + (TAU / arms)
		var between = base_angle + (TAU / arms) / 2.0
		pts.append(Vector2(cos(between) * arm_w * 0.6, sin(between) * arm_w * 0.6))
	return pts

func _spawn_snowflake(dir: Vector2) -> void:
	var proj = Area2D.new()
	proj.add_to_group("player_projectiles")
	proj.collision_layer = 4
	proj.collision_mask = 2
	proj.monitoring = true

	# 碰撞体（圆形）
	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 14.0
	col.shape = circle
	proj.add_child(col)

	# 外发光（淡蓝圆）
	var glow = Polygon2D.new()
	var glow_pts = PackedVector2Array()
	for i in range(16):
		var a = (TAU / 16.0) * i
		glow_pts.append(Vector2(cos(a) * 22, sin(a) * 22))
	glow.polygon = glow_pts
	glow.color = Color(0.3, 0.75, 1.0, 0.22)
	proj.add_child(glow)

	# 雪花主体（白蓝色）
	var flake = Polygon2D.new()
	flake.polygon = _make_snowflake_polygon(14.0, 7.0, 3.5)
	flake.color = Color(0.75, 0.95, 1.0)
	proj.add_child(flake)

	# 雪花中心小六边形
	var center = Polygon2D.new()
	var cpts = PackedVector2Array()
	for i in range(6):
		var a = (TAU / 6.0) * i
		cpts.append(Vector2(cos(a) * 4.0, sin(a) * 4.0))
	center.polygon = cpts
	center.color = Color(1.0, 1.0, 1.0, 0.9)
	proj.add_child(center)

	get_tree().current_scene.add_child(proj)
	proj.global_position = owner_player.global_position

	# 雪花自旋动画
	var tween_spin = flake.create_tween().set_loops()
	tween_spin.tween_property(flake, "rotation_degrees", 60.0, 0.8)

	var dmg = get_current_damage()
	var hit_enemies = {}
	proj.body_entered.connect(func(body):
		if body.is_in_group("enemies") and not hit_enemies.has(body.get_instance_id()):
			hit_enemies[body.get_instance_id()] = true
			body.take_damage(dmg)
	)

	# 直线飞行
	var target_pos = owner_player.global_position + dir * 900
	var move_tween = proj.create_tween()
	move_tween.tween_property(proj, "global_position", target_pos, 900.0 / 520.0)
	move_tween.tween_callback(proj.queue_free)
