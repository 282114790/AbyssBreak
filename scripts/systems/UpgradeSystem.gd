# UpgradeSystem.gd
# 升级选项生成系统 - 随机生成3个升级选项
extends Node

# 所有可用技能数据（在GameManager中注册）
static var available_skills: Array = []
static var available_passives: Array = []

# 进化表：技能ID -> {passive_id, evolved_name, evolved_desc, damage_mult}
static var evolve_table: Dictionary = {
	"fireball": {
		"passive_id": "power_ring",
		"evolved_name": "☄ 陨石术",
		"evolved_desc": "超级火球爆炸，damage×3，范围打3个敌人",
		"damage_mult": 3.0,
		"evolved_id": "fireball_evolved"
	},
	"orbital": {
		"passive_id": "boots",
		"evolved_name": "🌪 死亡旋涡",
		"evolved_desc": "超速旋涡护盾，体积×2，damage×2",
		"damage_mult": 2.0,
		"evolved_id": "orbital_evolved"
	}
}

# 生成升级选项（3选1）
static func generate_choices(player: Player) -> Array:
	var choices = []
	var pool = _build_pool(player)
	pool.shuffle()
	for i in range(min(3, pool.size())):
		choices.append(pool[i])
	return choices

static func _build_pool(player: Player) -> Array:
	var pool = []

	# ── 进化检测（最高优先级，强制插入）──
	var evolve_choices = _check_evolve(player)
	pool.append_array(evolve_choices)

	# 已有技能可升级
	for skill in player.skills:
		if skill.level < skill.data.max_level:
			pool.append({
				"type": "skill_levelup",
				"skill_id": skill.data.id,
				"display_name": "升级 " + skill.data.display_name,
				"description": "Lv%d → Lv%d" % [skill.level, skill.level + 1],
				"weight": 3
			})

	# 新技能（最多6个槽位）
	if player.skills.size() < player.max_skill_slots:
		var owned_ids = player.skills.map(func(s): return s.data.id)
		for sd in available_skills:
			if sd.id not in owned_ids:
				pool.append({
					"type": "skill_new",
					"skill_id": sd.id,
					"display_name": "新技能: " + sd.display_name,
					"description": sd.description,
					"weight": 2
				})

	# 被动技能
	for pd in available_passives:
		var owned_count = player.passive_ids.count(pd.id)
		if owned_count < pd.max_level:
			pool.append({
				"type": "passive",
				"passive_id": pd.id,
				"display_name": pd.display_name + (" Lv%d" % (owned_count + 1)),
				"description": pd.description,
				"weight": 2
			})

	# 回血选项（保底）
	pool.append({
		"type": "heal",
		"display_name": "恢复生命",
		"description": "恢复30%最大生命值",
		"weight": 1
	})

	return pool

static func _check_evolve(player: Player) -> Array:
	var evolve_choices = []
	for skill in player.skills:
		var sid = skill.data.id
		if not evolve_table.has(sid):
			continue
		# 检查是否满级
		if skill.level < skill.data.max_level:
			continue
		# 检查是否已经进化（evolved_id 已在技能中）
		var et = evolve_table[sid]
		var already_evolved = false
		for s in player.skills:
			if s.data.id == et["evolved_id"]:
				already_evolved = true
				break
		if already_evolved:
			continue
		# 检查是否拥有对应被动
		var needed_passive = et["passive_id"]
		if needed_passive not in player.passive_ids:
			continue
		# 满足条件，插入进化选项
		evolve_choices.append({
			"type": "evolve",
			"skill_id": sid,
			"evolved_id": et["evolved_id"],
			"evolved_name": et["evolved_name"],
			"evolved_desc": et["evolved_desc"],
			"damage_mult": et["damage_mult"],
			"display_name": "✨ 进化: " + et["evolved_name"],
			"description": et["evolved_desc"],
			"weight": 10
		})
	return evolve_choices
