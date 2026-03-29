# SkillBloodNova.gd
# 血月新星：消耗少量HP，释放全方向血色冲击波
extends SkillBase
class_name SkillBloodNova

const HP_COST_RATIO := 0.05  # 消耗当前HP的5%

func activate() -> void:
	if not owner_player: return
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm: sm.play_explosion()
	_spend_hp_and_blast()

func _spend_hp_and_blast() -> void:
	var lv = data.level if data else 1
	# 消耗HP
	var cost = owner_player.hp * HP_COST_RATIO
	cost = max(cost, 1.0)
	owner_player.hp -= cost

	# 爆发圆圈
	var nova = Node2D.new()
	nova.global_position = owner_player.global_position
	get_tree().current_scene.add_child(nova)

	# 径向射线视觉
	var ray_count = 16 + lv * 2
	for i in range(ray_count):
		var angle = TAU * i / ray_count
		var ray = ColorRect.new()
		ray.size = Vector2(4, 30 + lv * 5)
		ray.position = Vector2(-2, 0)
		ray.rotation = angle
		ray.color = Color(0.9, 0.1, 0.2, 0.7)
		nova.add_child(ray)

	# 中心光圈
	var core = ColorRect.new()
	core.size = Vector2(20, 20)
	core.position = Vector2(-10, -10)
	core.color = Color(1.0, 0.3, 0.4, 0.9)
	nova.add_child(core)

	# 伤害判断（即时全屏范围）
	var radius = 120.0 + lv * 20.0
	var dmg = get_current_damage() * (1.0 + cost / 10.0)  # HP消耗越高伤害越大

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy): continue
		if enemy.global_position.distance_to(owner_player.global_position) <= radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(dmg)
				EventBus.damage_dealt.emit(enemy.global_position, int(dmg), Color(1.0, 0.1, 0.2))

	# 扩散动画
	_animate_nova(nova)

func _animate_nova(nova: Node2D) -> void:
	var elapsed := 0.0
	var duration := 0.5
	while elapsed < duration:
		await get_tree().process_frame
		var d = get_process_delta_time()
		elapsed += d
		if not is_instance_valid(nova): return
		var t = elapsed / duration
		nova.scale = Vector2(1.0 + t * 1.5, 1.0 + t * 1.5)
		nova.modulate.a = 1.0 - t
	if is_instance_valid(nova):
		nova.queue_free()
