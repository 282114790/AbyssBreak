# UpgradeSystem.gd
# 升级选项生成系统 - 5选2，含诅咒选项（风险换高收益）
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

# 诅咒选项池（风险换高收益）
static var curse_pool: Array = [
	{
		"type": "curse",
		"curse_id": "glass_cannon",
		"display_name": "⚠ 诅咒：玻璃炮",
		"description": "最大血量-30%，但伤害+50%",
		"hp_mult": 0.7, "damage_bonus": 0.5
	},
	{
		"type": "curse",
		"curse_id": "cursed_speed",
		"display_name": "⚠ 诅咒：狂乱",
		"description": "移动速度-20%，但所有冷却-25%",
		"speed_mult": 0.8, "cooldown_mult": 0.75
	},
	{
		"type": "curse",
		"curse_id": "soul_pact",
		"display_name": "⚠ 诅咒：灵魂契约",
		"description": "每5秒损失5HP，但经验获取+60%",
		"regen_bonus": -5.0, "exp_mult": 1.6
	},
	{
		"type": "curse",
		"curse_id": "berserker",
		"display_name": "⚠ 诅咒：狂战士",
		"description": "无法回血，但暴击率+25%暴击倍率×2",
		"disable_heal": true, "crit_chance": 0.25, "crit_mult": 2.0
	},
]

# 生成升级选项（5选2）
static func generate_choices(player: Player) -> Array:
	var choices = []
	var pool = _build_pool(player)
	pool.shuffle()
	# 进化选项优先排到最前（不打乱）
	var evolve_choices = pool.filter(func(c): return c.get("type") == "evolve")
	var normal_choices = pool.filter(func(c): return c.get("type") != "evolve")
	normal_choices.shuffle()
	var final_pool = evolve_choices + normal_choices
	for i in range(min(5, final_pool.size())):
		choices.append(final_pool[i])
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

	# 诅咒选项（每次升级30%概率出现1个）
	var owned_curses = player.get("curse_ids") if player.get("curse_ids") != null else []
	var available_curses = curse_pool.filter(func(c): return c["curse_id"] not in owned_curses)
	if available_curses.size() > 0 and randf() < 0.30:
		available_curses.shuffle()
		pool.append(available_curses[0])

	# 回血选项（保底）
	pool.append({
		"type": "heal",
		"display_name": "🩹 恢复生命",
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
		if skill.level < skill.data.max_level:
			continue
		var et = evolve_table[sid]
		var already_evolved = false
		for s in player.skills:
			if s.data.id == et["evolved_id"]:
				already_evolved = true
				break
		if already_evolved:
			continue
		var needed_passive = et["passive_id"]
		if needed_passive not in player.passive_ids:
			continue
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
