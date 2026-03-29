# SkillPoisonCloud.gd
# 毒雾领域：在玩家周围释放持续毒雾，范围内敌人持续中毒
extends SkillBase
class_name SkillPoisonCloud

const CLOUD_RADIUS_BASE := 80.0
const TICK_INTERVAL := 0.5

var _tick_timer := 0.0
var _cloud_visual: Node2D = null
var _pulse_time := 0.0

func activate() -> void:
	if not owner_player: return
	_spawn_cloud()

func _spawn_cloud() -> void:
	if is_instance_valid(_cloud_visual):
		_cloud_visual.queue_free()

	var lv = _get_level()
	var radius = CLOUD_RADIUS_BASE + lv * 15.0

	_cloud_visual = Node2D.new()
	_cloud_visual.z_index = -1
	owner_player.add_child(_cloud_visual)

	# 主圆圈
	var circle = Node2D.new()
	circle.set_script(null)
	_cloud_visual.add_child(circle)

	# 用多个小Sprite2D模拟毒雾粒子
	var rng = RandomNumberGenerator.new()
	rng.seed = 999
	for i in range(24 + lv * 4):
		var sp = ColorRect.new()
		var angle = rng.randf() * TAU
		var dist = rng.randf_range(0, radius * 0.9)
		sp.position = Vector2(cos(angle) * dist - 6, sin(angle) * dist - 6)
		sp.size = Vector2(12, 12)
		var alpha = rng.randf_range(0.15, 0.35)
		sp.color = Color(0.2, 0.85, 0.1, alpha)
		_cloud_visual.add_child(sp)

func _process(delta: float) -> void:
	_pulse_time += delta
	if is_instance_valid(_cloud_visual):
		var pulse = 0.85 + sin(_pulse_time * 3.0) * 0.15
		_cloud_visual.scale = Vector2(pulse, pulse)

	cooldown_timer -= delta
	if cooldown_timer > 0: return
	_tick_timer += delta
	if _tick_timer < TICK_INTERVAL: return
	_tick_timer = 0.0
	_do_poison_tick()

func _do_poison_tick() -> void:
	if not owner_player: return
	var lv = _get_level()
	var radius = CLOUD_RADIUS_BASE + lv * 15.0
	var dmg = get_current_damage() * 0.3

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy): continue
		if enemy.global_position.distance_to(owner_player.global_position) <= radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(dmg)
				# 毒绿色伤害数字
				EventBus.damage_dealt.emit(enemy.global_position, int(dmg), Color(0.2, 0.9, 0.1))

func _get_level() -> int:
	return data.level if data else 1
