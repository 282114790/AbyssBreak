@tool
# SkillTimeSlow.gd
# 时间减速：短暂减慢所有敌人速度80%，持续时间随等级增加
extends SkillBase
class_name SkillTimeSlow

const SLOW_RATIO := 0.2  # 减速后为原速20%
var _active := false

func activate() -> void:
	if not owner_player or _active: return
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm: sm.play_shoot()
	_do_slow()

func _do_slow() -> void:
	_active = true
	var lv = level if data else 1
	var duration = 2.0 + lv * 0.5  # Lv1=2.5s, Lv5=4.5s

	# 视觉：蓝紫色全屏闪光
	_show_slow_vfx(duration)

	# 减速所有敌人
	var enemies = _get_enemies()
	var original_speeds := {}
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		if enemy.has_meta("base_speed"):
			original_speeds[enemy] = enemy.get_meta("base_speed")
		elif "speed" in enemy:
			original_speeds[enemy] = enemy.speed
			enemy.speed *= SLOW_RATIO
		elif "move_speed" in enemy:
			original_speeds[enemy] = enemy.move_speed
			enemy.move_speed *= SLOW_RATIO

	await get_tree().create_timer(duration).timeout

	# 恢复速度
	for enemy in original_speeds:
		if not is_instance_valid(enemy): continue
		if "speed" in enemy:
			enemy.speed = original_speeds[enemy]
		elif "move_speed" in enemy:
			enemy.move_speed = original_speeds[enemy]

	_active = false

func _show_slow_vfx(duration: float) -> void:
	if not owner_player: return
	var vfx = Node2D.new()
	vfx.global_position = owner_player.global_position
	vfx.z_index = 5
	_get_spawn_root().add_child(vfx)

	# 时钟慢指针效果：辐射状蓝色光线
	for i in range(8):
		var ray = ColorRect.new()
		ray.size = Vector2(3, 120)
		ray.position = Vector2(-1.5, 0)
		ray.rotation = TAU * i / 8
		ray.color = Color(0.3, 0.5, 1.0, 0.4)
		vfx.add_child(ray)

	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if not is_instance_valid(vfx): return
		vfx.global_position = owner_player.global_position
		var pulse = 0.7 + sin(elapsed * 4.0) * 0.3
		vfx.modulate = Color(0.4, 0.6, 1.0, pulse * (1.0 - elapsed/duration))

	if is_instance_valid(vfx):
		vfx.queue_free()
