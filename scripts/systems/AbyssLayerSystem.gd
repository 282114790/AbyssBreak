# AbyssLayerSystem.gd
# 深渊层数系统 — 每次通关后解锁下一层，每层增加全局修正器
extends Node

const MAX_LAYER := 20

const LAYER_MODIFIERS := {
	2:  {"id": "poison_death",    "name": "死亡毒雾",     "desc": "敌人死后留下毒雾区域2秒",        "enemy_hp_mult": 1.0, "enemy_dmg_mult": 1.0},
	3:  {"id": "fast_elite",      "name": "精英加速",     "desc": "精英移速+40%",                  "enemy_hp_mult": 1.0, "enemy_dmg_mult": 1.0},
	4:  {"id": "hp_regen_enemy",  "name": "敌人回血",     "desc": "敌人每秒回复1%最大HP",           "enemy_hp_mult": 1.1, "enemy_dmg_mult": 1.0},
	5:  {"id": "meteor_rain",     "name": "陨石风暴",     "desc": "每60秒随机陨石雨",              "enemy_hp_mult": 1.0, "enemy_dmg_mult": 1.0},
	6:  {"id": "merchant_greed",  "name": "商人贪婪",     "desc": "商人物价翻倍，但遗物品质提升",    "enemy_hp_mult": 1.0, "enemy_dmg_mult": 1.0},
	7:  {"id": "exp_drain",       "name": "经验衰减",     "desc": "经验获取-20%",                  "enemy_hp_mult": 1.15, "enemy_dmg_mult": 1.1},
	8:  {"id": "epic_relics",     "name": "史诗宝藏",     "desc": "遗物必出史诗，但敌人HP+30%",     "enemy_hp_mult": 1.3, "enemy_dmg_mult": 1.0},
	9:  {"id": "speed_demons",    "name": "疾风恶魔",     "desc": "所有敌人移速+25%",              "enemy_hp_mult": 1.0, "enemy_dmg_mult": 1.15},
	10: {"id": "twin_boss",       "name": "双生Boss",     "desc": "Boss同时出现两个",              "enemy_hp_mult": 1.2, "enemy_dmg_mult": 1.2},
	11: {"id": "curse_start",     "name": "初始诅咒",     "desc": "开局自带一个随机诅咒",           "enemy_hp_mult": 1.0, "enemy_dmg_mult": 1.0},
	12: {"id": "no_heal_zone",    "name": "禁疗时刻",     "desc": "每3分钟有30秒无法回血",          "enemy_hp_mult": 1.1, "enemy_dmg_mult": 1.1},
	13: {"id": "explode_death",   "name": "亡者之怒",     "desc": "敌人死亡时爆炸造成小范围伤害",    "enemy_hp_mult": 1.15, "enemy_dmg_mult": 1.15},
	14: {"id": "armor_all",       "name": "铁甲军团",     "desc": "所有敌人获得5点护甲",            "enemy_hp_mult": 1.2, "enemy_dmg_mult": 1.1},
	15: {"id": "skill_lock",      "name": "技能封印",     "desc": "开局随机封印1个技能槽",          "enemy_hp_mult": 1.0, "enemy_dmg_mult": 1.0},
	16: {"id": "darkness",        "name": "深渊黑暗",     "desc": "视野范围-30%",                  "enemy_hp_mult": 1.25, "enemy_dmg_mult": 1.2},
	17: {"id": "bloodlust",       "name": "嗜血",        "desc": "敌人击中玩家回复5%HP",           "enemy_hp_mult": 1.3, "enemy_dmg_mult": 1.2},
	18: {"id": "endless_swarm",   "name": "无尽虫群",     "desc": "敌人数量上限+50%",              "enemy_hp_mult": 1.2, "enemy_dmg_mult": 1.25},
	19: {"id": "final_curse",     "name": "终极诅咒",     "desc": "所有诅咒效果翻倍",              "enemy_hp_mult": 1.3, "enemy_dmg_mult": 1.3},
	20: {"id": "true_abyss",      "name": "真·深渊",      "desc": "敌人HP×2，攻击×2，掉落×2",     "enemy_hp_mult": 2.0, "enemy_dmg_mult": 2.0},
}

var current_layer: int = 1
var active_modifiers: Array = []

func _ready() -> void:
	_load_layer()

func _load_layer() -> void:
	var meta = get_tree().root.find_child("MetaProgress", true, false)
	if meta and "abyss_layer" in meta:
		current_layer = meta.abyss_layer
	else:
		current_layer = 1

func get_active_modifiers() -> Array:
	var mods = []
	for layer_num in LAYER_MODIFIERS:
		if layer_num <= current_layer:
			mods.append(LAYER_MODIFIERS[layer_num])
	return mods

func get_total_enemy_hp_mult() -> float:
	var mult = 1.0
	for mod in get_active_modifiers():
		mult *= mod.get("enemy_hp_mult", 1.0)
	return mult

func get_total_enemy_dmg_mult() -> float:
	var mult = 1.0
	for mod in get_active_modifiers():
		mult *= mod.get("enemy_dmg_mult", 1.0)
	return mult

func advance_layer() -> void:
	current_layer = min(current_layer + 1, MAX_LAYER)
	var meta = get_tree().root.find_child("MetaProgress", true, false)
	if meta:
		meta.abyss_layer = current_layer
		meta.save()

func has_modifier(mod_id: String) -> bool:
	for mod in get_active_modifiers():
		if mod["id"] == mod_id:
			return true
	return false

var _no_heal_timer: float = 0.0
var _meteor_timer: float = 0.0

var _poison_death_enabled: bool = false
var _explode_death_enabled: bool = false
var _bloodlust_enabled: bool = false

func _process(delta: float) -> void:
	if EventBus.game_logic_paused: return
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player): return

	# 层4: 敌人每秒回复1%最大HP
	if has_modifier("hp_regen_enemy"):
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and not e.is_dead and e.data:
				e.hp = minf(e.hp + e.data.max_hp * 0.01 * delta, e.data.max_hp)

	# 层5: 每60秒随机陨石雨
	if has_modifier("meteor_rain"):
		_meteor_timer += delta
		if _meteor_timer >= 60.0:
			_meteor_timer = 0.0
			_spawn_meteor_rain(player)

	# 层12: 每3分钟30秒禁疗
	if has_modifier("no_heal_zone"):
		_no_heal_timer += delta
		var cycle_pos = fmod(_no_heal_timer, 180.0)
		player.heal_disabled = cycle_pos >= 150.0

func apply_initial_effects(player: Node) -> void:
	# 层2: 死亡毒雾（标记，实际在 on_enemy_died 处理）
	_poison_death_enabled = has_modifier("poison_death")
	# 层3: 精英加速（在 apply_to_wave_manager 处理）
	# 层7: 经验衰减
	if has_modifier("exp_drain"):
		player.exp_multiplier *= 0.8
	# 层11: 开局随机诅咒
	if has_modifier("curse_start") and not UpgradeSystem.curse_pool.is_empty():
		var curse = UpgradeSystem.curse_pool[randi() % UpgradeSystem.curse_pool.size()]
		player.curse_ids.append(curse["curse_id"])
	# 层13: 敌人死亡爆炸
	_explode_death_enabled = has_modifier("explode_death")
	# 层14: 所有敌人护甲+5（在 apply_to_wave_manager 处理）
	# 层15: 封印1个技能槽
	if has_modifier("skill_lock"):
		player.max_skill_slots = max(player.max_skill_slots - 1, 2)
	# 层16: 视野-30%
	if has_modifier("darkness"):
		var cam = get_tree().root.find_child("Camera2D", true, false)
		if cam: cam.zoom *= 1.3
	# 层17: 嗜血
	_bloodlust_enabled = has_modifier("bloodlust")
	# 连接敌人死亡信号
	if not EventBus.enemy_died.is_connected(_on_enemy_died_modifier):
		EventBus.enemy_died.connect(_on_enemy_died_modifier)

func _on_enemy_died_modifier(pos: Vector2, _exp: int) -> void:
	# 层2: 死亡毒雾
	if _poison_death_enabled:
		_spawn_poison_cloud(pos)
	# 层13: 死亡爆炸
	if _explode_death_enabled:
		_spawn_death_explosion(pos)

func _spawn_poison_cloud(pos: Vector2) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player): return
	var cloud_dmg = 8.0
	var cloud_radius = 50.0
	var duration = 2.0
	var elapsed = 0.0
	while elapsed < duration:
		await get_tree().create_timer(0.5).timeout
		if not is_inside_tree(): return
		elapsed += 0.5
		var p = get_tree().get_first_node_in_group("player")
		if is_instance_valid(p) and pos.distance_to(p.global_position) < cloud_radius:
			p.take_damage(cloud_dmg)

func _spawn_death_explosion(pos: Vector2) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player): return
	if pos.distance_to(player.global_position) < 60.0:
		player.take_damage(player.max_hp * 0.03)

func on_enemy_hit_player(enemy: Node) -> void:
	if _bloodlust_enabled and is_instance_valid(enemy) and enemy.data:
		enemy.hp = minf(enemy.hp + enemy.data.max_hp * 0.05, enemy.data.max_hp)

func _spawn_meteor_rain(player: Node) -> void:
	EventBus.emit_signal("pickup_float_text", player.global_position + Vector2(0, -50),
		"☄ 陨石风暴！", Color(1.0, 0.4, 0.1))
	for i in range(5):
		var offset = Vector2(randf_range(-300, 300), randf_range(-300, 300))
		var pos = player.global_position + offset
		get_tree().create_timer(randf_range(0.2, 1.5)).timeout.connect(func():
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and not e.is_dead and pos.distance_to(e.global_position) < 60:
					e.take_damage(e.data.max_hp * 0.15 if e.data else 30.0)
			var p = get_tree().get_first_node_in_group("player")
			if is_instance_valid(p) and pos.distance_to(p.global_position) < 50:
				p.take_damage(p.max_hp * 0.08)
		)

func apply_to_wave_manager(wm: Node) -> void:
	if not wm or not wm.has_meta("difficulty"): return
	var diff = wm.get_meta("difficulty")
	diff.enemy_hp_mult *= get_total_enemy_hp_mult()
	diff.enemy_dmg_mult *= get_total_enemy_dmg_mult()
	if has_modifier("speed_demons"):
		diff.enemy_speed_mult *= 1.25
	if has_modifier("fast_elite"):
		for ep in wm.elite_presets:
			ep["spd"] = int(ep["spd"] * 1.4)
	if has_modifier("endless_swarm"):
		wm.enemy_count_mult *= 1.5
	# 层14: 全体护甲+5
	if has_modifier("armor_all"):
		for ep in wm.enemy_presets:
			ep["armor"] = ep.get("armor", 0.0) + 5.0
		for ep in wm.elite_presets:
			ep["armor"] = ep.get("armor", 0.0) + 5.0
