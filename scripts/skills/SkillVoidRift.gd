# SkillVoidRift.gd
# 虚空裂缝：在随机位置生成黑洞，吸引并持续伤害敌人
extends SkillBase
class_name SkillVoidRift

const RIFT_DURATION := 4.0
const PULL_FORCE := 120.0
const RIFT_RADIUS := 100.0

func activate() -> void:
	if not owner_player: return
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm: sm.play_shoot()
	EventBus.skill_activated.emit("void_rift")
	_spawn_rift()

func _spawn_rift() -> void:
	var lv = data.level if data else 1
	var count = 1 + lv / 3  # Lv3=2个, Lv5=2个

	for i in range(count):
		var angle = TAU * i / count + randf() * 0.5
		var dist = randf_range(80, 160)
		var pos = owner_player.global_position + Vector2(cos(angle), sin(angle)) * dist
		_create_rift_at(pos)

func _create_rift_at(pos: Vector2) -> void:
	var lv = data.level if data else 1
	var rift = Node2D.new()
	rift.global_position = pos
	get_tree().current_scene.add_child(rift)

	# 视觉：黑洞圆圈 + 旋转环
	for ring in range(3):
		var r_node = Node2D.new()
		rift.add_child(r_node)
		var radius = 8.0 + ring * 10.0
		var seg = 12
		for s in range(seg):
			var dot = ColorRect.new()
			dot.size = Vector2(4, 4)
			var a = TAU * s / seg
			dot.position = Vector2(cos(a) * radius - 2, sin(a) * radius - 2)
			var alpha = 0.6 - ring * 0.15
			dot.color = Color(0.4, 0.0, 0.8, alpha)
			r_node.add_child(dot)

	# 中心黑点
	var core = ColorRect.new()
	core.size = Vector2(14, 14)
	core.position = Vector2(-7, -7)
	core.color = Color(0.05, 0.0, 0.1, 0.95)
	rift.add_child(core)

	# 定时器驱动：持续吸引+伤害
	var timer = 0.0
	var duration = RIFT_DURATION + lv * 0.5
	var dmg = get_current_damage()
	var tick_acc = 0.0
	var rot_acc = 0.0

	rift.set_script(null)
	# 用 SceneTreeTimer 替代，避免 set_script 冲突
	_run_rift_logic(rift, duration, dmg)

func _run_rift_logic(rift: Node2D, duration: float, dmg: float) -> void:
	var elapsed := 0.0
	var tick := 0.0
	var rot := 0.0

	while elapsed < duration:
		await get_tree().process_frame
		var d = get_process_delta_time()
		elapsed += d
		tick += d
		rot += d * 2.0

		if not is_instance_valid(rift):
			return

		# 旋转视觉
		for child in rift.get_children():
			if child is Node2D:
				child.rotation += d * (1.5 + rift.get_children().find(child) * 0.3)

		# 吸引+伤害
		if tick >= 0.3:
			tick = 0.0
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(enemy): continue
				var dist = enemy.global_position.distance_to(rift.global_position)
				if dist < RIFT_RADIUS:
					# 吸引
					var dir = (rift.global_position - enemy.global_position).normalized()
					enemy.global_position += dir * PULL_FORCE * 0.3
					# 伤害
					if enemy.has_method("take_damage"):
						enemy.take_damage(dmg * 0.4)
						EventBus.damage_dealt.emit(enemy.global_position, int(dmg * 0.4), Color(0.5, 0.0, 1.0))

		# 淡出
		var fade = 1.0 - (elapsed / duration)
		if is_instance_valid(rift):
			rift.modulate.a = fade

	if is_instance_valid(rift):
		rift.queue_free()
