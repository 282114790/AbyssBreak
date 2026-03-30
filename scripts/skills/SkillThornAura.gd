@tool
# SkillThornAura.gd
# 荆棘护甲：受到伤害时反弹伤害给攻击者，周身荆棘光环
extends SkillBase
class_name SkillThornAura

const REFLECT_RATIO_BASE := 0.5  # 反弹50%伤害

var _connected := false

func activate() -> void:
	if not owner_player: return
	_setup_aura()

func _setup_aura() -> void:
	if _connected: return
	_connected = true
	# 连接玩家受伤信号
	if owner_player.has_signal("took_damage"):
		owner_player.took_damage.connect(_on_player_hit)
	_spawn_aura_visual()

func _on_player_hit(dmg: float, attacker: Node2D) -> void:
	if not is_instance_valid(attacker): return
	var lv = level if data else 1
	var reflect = dmg * (REFLECT_RATIO_BASE + lv * 0.1)
	if attacker.has_method("take_damage"):
		attacker.take_damage(reflect)
		EventBus.damage_dealt.emit(attacker.global_position, int(reflect), Color(0.2, 0.9, 0.3))
	# 视觉反馈
	_flash_thorns()

func _spawn_aura_visual() -> void:
	if not is_instance_valid(owner_player): return
	var aura = Node2D.new()
	aura.name = "ThornAura"
	aura.z_index = 2
	owner_player.add_child(aura)

	var lv = level if data else 1
	var spike_count = 8 + lv * 2
	for i in range(spike_count):
		var angle = TAU * i / spike_count
		var spike = ColorRect.new()
		spike.size = Vector2(3, 14 + lv * 2)
		spike.position = Vector2(-1.5, -(20 + lv * 3))
		spike.rotation = angle
		spike.color = Color(0.1, 0.8, 0.2, 0.6)
		aura.add_child(spike)

func _flash_thorns() -> void:
	if not is_instance_valid(owner_player): return
	var aura = owner_player.get_node_or_null("ThornAura")
	if not aura: return
	aura.modulate = Color(0.3, 1.0, 0.3, 1.0)
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(aura):
		aura.modulate = Color(1.0, 1.0, 1.0, 0.7)

func _process(delta: float) -> void:
	cooldown_timer -= delta
	# 荆棘护甲是持续被动，无冷却触发概念，直接不调用父类 activate
	if not is_instance_valid(owner_player): return
	var aura = owner_player.get_node_or_null("ThornAura")
	if aura:
		aura.rotation += delta * 0.8
