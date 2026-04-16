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
		"evolved_name": "🌪 湮灭壁垒",
		"evolved_desc": "三层壁垒全开，伤害×2，击退×2，减伤上限提升至60%",
		"damage_mult": 2.0,
		"evolved_id": "orbital_evolved"
	},
	"poison_cloud": {
		"passive_id": "toxic_vial",
		"evolved_name": "☠ 瘟疫瘴气",
		"evolved_desc": "毒雾范围×2，持续伤害×2.5，中毒敌人死亡时扩散",
		"damage_mult": 2.5,
		"evolved_id": "poison_evolved"
	},
	"arcane_orb": {
		"passive_id": "power_ring",
		"evolved_name": "💠 奥术风暴",
		"evolved_desc": "弹幕数量×2，爆炸时释放连锁闪电",
		"damage_mult": 2.0,
		"evolved_id": "arcane_evolved"
	},
	"lightning": {
		"passive_id": "mana_crystal",
		"evolved_name": "⚡ 雷神审判",
		"evolved_desc": "闪电弹跳次数×2，每次弹跳伤害递增而非递减",
		"damage_mult": 2.5,
		"evolved_id": "lightning_evolved"
	},
	"iceblade": {
		"passive_id": "iron_heart",
		"evolved_name": "❄ 霜寒之怒",
		"evolved_desc": "冰刃变为三向扇形，命中敌人冻结1秒",
		"damage_mult": 2.0,
		"evolved_id": "iceblade_evolved"
	},
	"blood_nova": {
		"passive_id": "shadow_cloak",
		"evolved_name": "🩸 血色黄昏",
		"evolved_desc": "血月脉冲持续环绕，HP越低范围越大，击杀回血",
		"damage_mult": 2.5,
		"evolved_id": "blood_nova_evolved"
	},
	"meteor_shower": {
		"passive_id": "mana_crystal",
		"evolved_name": "☄ 天罚陨星",
		"evolved_desc": "陨石数量×3，落点产生持续燃烧区域",
		"damage_mult": 2.0,
		"evolved_id": "meteor_evolved"
	},
	"chain_lance": {
		"passive_id": "iron_heart",
		"evolved_name": "🏹 湮灭之枪",
		"evolved_desc": "长枪穿透无限敌人，尾迹留下伤害区域",
		"damage_mult": 2.5,
		"evolved_id": "chain_lance_evolved"
	},
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

# 生成升级选项（加权随机采样）
static func generate_choices(player: Player, max_choices: int = 5) -> Array:
	var pool = _build_pool(player)
	# 进化选项强制优先
	var evolve_choices = pool.filter(func(c): return c.get("type") == "evolve")
	var normal_choices = pool.filter(func(c): return c.get("type") != "evolve")

	var choices: Array = []
	choices.append_array(evolve_choices)

	# 剩余名额用加权随机从 normal_choices 中采样
	var remaining = max_choices - choices.size()
	for _i in range(remaining):
		if normal_choices.is_empty():
			break
		var total_weight := 0.0
		for c in normal_choices:
			total_weight += c.get("weight", 1)
		var roll := randf() * total_weight
		var cumulative := 0.0
		var picked_idx := 0
		for j in range(normal_choices.size()):
			cumulative += normal_choices[j].get("weight", 1)
			if roll <= cumulative:
				picked_idx = j
				break
		choices.append(normal_choices[picked_idx])
		normal_choices.remove_at(picked_idx)

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

	# 新技能
	var owned_ids = player.skills.map(func(s): return s.data.id)
	var slots_full = player.skills.size() >= player.max_skill_slots
	for sd in available_skills:
		if sd.id not in owned_ids:
			if slots_full:
				pool.append({
					"type": "skill_replace",
					"skill_id": sd.id,
					"display_name": "替换: " + sd.display_name,
					"description": sd.description + "\n（需替换一个已有技能，残响保留50%效果）",
					"weight": 1
				})
			else:
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

	# 武器词缀（玩家有至少1个可加词缀的技能时出现）
	var affix_defs = [
		{"id": "split",         "name": "分裂",   "desc": "投射物命中后分裂为2个小弹"},
		{"id": "lifesteal",     "name": "吸血",   "desc": "伤害的5%转为治疗"},
		{"id": "chain",         "name": "连锁",   "desc": "攻击跳跃到附近1个敌人"},
		{"id": "explosive",     "name": "爆裂",   "desc": "命中时对周围敌人造成30%溅射伤害"},
		{"id": "piercing_plus", "name": "穿透强化", "desc": "穿透次数+2"},
		{"id": "homing",        "name": "追踪强化", "desc": "投射物追踪能力大幅提升"},
	]
	var eligible_skills = player.skills.filter(func(s): return s.data and s.data.affixes.size() < 3)
	if eligible_skills.size() > 0 and randf() < 0.35:
		var sk = eligible_skills[randi() % eligible_skills.size()]
		var available_affixes = affix_defs.filter(func(a): return a["id"] not in sk.data.affixes)
		if available_affixes.size() > 0:
			available_affixes.shuffle()
			var af = available_affixes[0]
			pool.append({
				"type": "affix",
				"skill_id": sk.data.id,
				"affix_id": af["id"],
				"display_name": sk.data.display_name + " +" + af["name"],
				"description": af["desc"],
				"weight": 4
			})

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
