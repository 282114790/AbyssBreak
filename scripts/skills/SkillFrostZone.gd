@tool
# SkillFrostZone.gd
# 寒冰领域 - 玩家脚下的持续冰冻区域，减速并持续伤害 + 冰晶粒子特效
extends SkillBase
class_name SkillFrostZone

var zone: Area2D = null
var tick_timer: float = 0.0
var slowed_enemies: Array = []  # 存放已减速的敌人实例ID
var crystal_timer: float = 0.0

func _ready() -> void:
	call_deferred("_create_zone")

func _create_zone() -> void:
	if zone != null and is_instance_valid(zone):
		zone.queue_free()
	slowed_enemies.clear()

	zone = Area2D.new()

	# 碰撞体（圆形）
	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = _get_radius()
	col.shape = circle
	zone.add_child(col)

	# 视觉：用 Polygon2D 画真正的圆形（替代矩形 ColorRect）
	var r = _get_radius()
	var visual = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in range(48):
		var a = (TAU / 48.0) * i
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	visual.polygon = pts
	visual.color = Color(0.3, 0.7, 1.0, 0.18)
	zone.add_child(visual)

	# 边缘光圈
	var rim = Polygon2D.new()
	var rim_pts = PackedVector2Array()
	for i in range(48):
		var a = (TAU / 48.0) * i
		rim_pts.append(Vector2(cos(a) * r, sin(a) * r))
	rim.polygon = rim_pts
	rim.color = Color(0.5, 0.9, 1.0, 0.0)
	# 用 Line2D 做边缘线
	var edge = Line2D.new()
	for i in range(49):
		var a = (TAU / 48.0) * i
		edge.add_point(Vector2(cos(a) * r, sin(a) * r))
	edge.default_color = Color(0.4, 0.85, 1.0, 0.5)
	edge.width = 2.0
	zone.add_child(edge)

	# 连接信号
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)

	# 挂在玩家下面，跟随移动
	if owner_player != null:
		owner_player.add_child(zone)
	else:
		_get_spawn_root().add_child(zone)

func _get_radius() -> float:
	if data != null:
		return 80.0 + level * 15.0
	return 80.0

# 兼容旧代码，内部也用 _get_radius
func _get_current_radius() -> float:
	return _get_radius()

func _process(delta: float) -> void:
	if EventBus.game_logic_paused:
		return
	# 不走父类的 cooldown 逻辑（持续技能）
	# 清理无效引用
	_clean_invalid_slowed()

	# Tick 伤害
	tick_timer -= delta
	if tick_timer <= 0.0:
		tick_timer = data.cooldown if data != null else 0.5
		_apply_tick_damage()

	# 冰晶粒子
	crystal_timer -= delta
	if crystal_timer <= 0:
		crystal_timer = 0.3
		_spawn_crystal()

func _apply_tick_damage() -> void:
	if zone == null or not is_instance_valid(zone):
		return
	var bodies = zone.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("enemies"):
			body.take_damage(get_current_damage())

func _spawn_crystal() -> void:
	if not owner_player:
		return
	var radius = _get_current_radius()
	var angle = randf() * TAU
	var dist = randf() * radius
	var spawn_pos = owner_player.global_position + Vector2(cos(angle), sin(angle)) * dist

	var crystal = Polygon2D.new()
	crystal.color = Color(0.6, 0.9, 1.0, 0.8)
	var pts = PackedVector2Array()
	for i in range(6):
		var a = (PI / 3.0) * i
		pts.append(Vector2(cos(a) * 4, sin(a) * 4))
	crystal.polygon = pts
	crystal.global_position = spawn_pos
	crystal.z_index = 5
	_get_spawn_root().add_child(crystal)

	var tween = crystal.create_tween()
	tween.set_parallel(true)
	tween.tween_property(crystal, "rotation_degrees", 180.0, 0.6)
	tween.tween_property(crystal, "position:y", crystal.position.y - 20, 0.6)
	tween.tween_property(crystal, "modulate:a", 0.0, 0.6)
	tween.tween_callback(crystal.queue_free).set_delay(0.6)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return
	var uid = body.get_instance_id()
	if uid in slowed_enemies:
		return
	slowed_enemies.append(uid)
	# 变蓝视觉
	if body.get("visual") != null and is_instance_valid(body.visual):
		body.visual.modulate = Color(0.5, 0.7, 1.0)
	# 减速：修改实例自己的 base_move_speed 缓存，不动共享 data
	if body.get("is_slowed") != null and not body.is_slowed:
		body.is_slowed = true
		# 用实例变量存当前速度，避免污染共享 Resource
		if body.get("base_move_speed") != null:
			body.set_meta("frost_original_speed", body.base_move_speed)
			body.base_move_speed = body.base_move_speed * 0.5

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return
	var uid = body.get_instance_id()
	if uid not in slowed_enemies:
		return
	slowed_enemies.erase(uid)
	# 恢复颜色
	if body.get("visual") != null and is_instance_valid(body.visual):
		body.visual.modulate = Color(1.0, 1.0, 1.0)
	# 恢复速度
	if body.get("is_slowed") != null:
		body.is_slowed = false
	if body.has_meta("frost_original_speed"):
		body.base_move_speed = body.get_meta("frost_original_speed")
		body.remove_meta("frost_original_speed")

func _clean_invalid_slowed() -> void:
	var to_remove: Array = []
	for uid in slowed_enemies:
		var obj = instance_from_id(uid)
		if not is_instance_valid(obj):
			to_remove.append(uid)
	for uid in to_remove:
		slowed_enemies.erase(uid)

func on_level_up() -> void:
	# 重建区域以更新半径
	_create_zone()
