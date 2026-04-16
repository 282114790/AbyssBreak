# SynergySystem.gd
# 技能协同系统（#17）— 检测玩家技能组合，提供伤害/属性加成
extends Node

# 协同对：skills[], name, desc, color, effects{}
# effects 支持: damage_mult(对组内技能), crit_bonus, speed_mult
const SYNERGIES := [
	{
		"skills": ["fireball", "lightning"],
		"name": "🔥⚡ 火雷连击",
		"desc": "火焰+闪电：组合技能伤害×1.8",
		"color": Color(1.0, 0.7, 0.1),
		"effects": {"damage_mult": 1.8}
	},
	{
		"skills": ["iceblade", "frostzone"],
		"name": "❄ 寒冰法则",
		"desc": "冰刃+寒冰领域：暴击率+25%，命中冻结0.5秒",
		"color": Color(0.4, 0.85, 1.0),
		"effects": {"crit_bonus": 0.25, "freeze_duration": 0.5}
	},
	{
		"skills": ["thorn_aura", "poison_cloud"],
		"name": "🌿 毒刺领域",
		"desc": "荆棘+毒云：组合技能伤害×1.6",
		"color": Color(0.3, 0.9, 0.3),
		"effects": {"damage_mult": 1.6}
	},
	{
		"skills": ["void_rift", "arcane_orb"],
		"name": "🌑💠 深渊奥术",
		"desc": "虚空+奥术：组合技能伤害×1.8",
		"color": Color(0.6, 0.2, 1.0),
		"effects": {"damage_mult": 1.8}
	},
	{
		"skills": ["blood_nova", "orbital"],
		"name": "🩸🌀 血旋领域",
		"desc": "血新星+护盾：组合技能伤害×1.5，暴击率+15%",
		"color": Color(0.9, 0.15, 0.3),
		"effects": {"damage_mult": 1.5, "crit_bonus": 0.15}
	},
	{
		"skills": ["time_slow", "meteor_shower"],
		"name": "⏳☄ 时空陨石",
		"desc": "时间减速+陨石雨：陨石数量×2，伤害×1.5",
		"color": Color(1.0, 0.5, 0.0),
		"effects": {"damage_mult": 1.5, "projectile_count_mult": 2}
	},
	{
		"skills": ["fireball", "iceblade"],
		"name": "🔥❄ 冰火交融",
		"desc": "火焰+冰刃：组合技能伤害×1.6，冻结概率+20%",
		"color": Color(0.8, 0.4, 0.9),
		"effects": {"damage_mult": 1.6, "crit_bonus": 0.10}
	},
	{
		"skills": ["lightning", "chain_lance"],
		"name": "⚡🏹 雷贯长空",
		"desc": "闪电+长枪：穿透伤害×1.7",
		"color": Color(0.9, 0.9, 0.3),
		"effects": {"damage_mult": 1.7}
	},
	{
		"skills": ["holywave", "blood_nova"],
		"name": "✨🩸 圣血裁决",
		"desc": "圣光+血月：组合暴击率+20%，暴击伤害×1.5",
		"color": Color(1.0, 0.6, 0.7),
		"effects": {"crit_bonus": 0.20, "damage_mult": 1.3}
	},
	{
		"skills": ["poison_cloud", "frostzone"],
		"name": "☠❄ 冰毒领域",
		"desc": "毒雾+冰域：减速效果加强，领域伤害×1.8",
		"color": Color(0.3, 0.7, 0.5),
		"effects": {"damage_mult": 1.8}
	},
	{
		"skills": ["runeblast", "arcane_orb"],
		"name": "💥💠 奥术引爆",
		"desc": "符文+奥术：爆炸范围×1.5，伤害×1.6",
		"color": Color(0.5, 0.3, 0.9),
		"effects": {"damage_mult": 1.6}
	},
	{
		"skills": ["meteor_shower", "fireball"],
		"name": "☄🔥 天降火雨",
		"desc": "陨石+火球：火系技能伤害×1.7",
		"color": Color(1.0, 0.35, 0.1),
		"effects": {"damage_mult": 1.7}
	},
	{
		"skills": ["void_rift", "time_slow"],
		"name": "🌑⏳ 时空撕裂",
		"desc": "虚空+时间：主动技能冷却-30%，伤害×1.5",
		"color": Color(0.4, 0.1, 0.6),
		"effects": {"damage_mult": 1.5, "cooldown_reduction": 0.3}
	},
	{
		"skills": ["chain_lance", "holywave"],
		"name": "🏹✨ 圣枪审判",
		"desc": "长枪+圣光：穿透+2，组合伤害×1.4",
		"color": Color(1.0, 0.95, 0.7),
		"effects": {"damage_mult": 1.4, "crit_bonus": 0.10, "extra_pierce": 2}
	},
]

var _active_synergies: Array = []
var _last_skill_ids: Array = []
var _active_element_resonances: Dictionary = {}  # element_name -> count
var _element_bonuses: Dictionary = {}  # element_enum_val -> {damage_mult, cooldown_reduction, ...}

const ELEMENT_NAMES := {
	0: "fire", 1: "ice", 2: "lightning", 3: "dark", 4: "holy", 5: "poison", 6: "arcane",
}

const ELEMENT_MASTERY_EFFECTS := {
	"fire":      {"name": "火焰精通", "effect": "敌人持续燃烧", "damage_mult": 1.25, "cooldown_reduction": 0.25},
	"ice":       {"name": "寒冰精通", "effect": "冻结持续+1s", "damage_mult": 1.2, "cooldown_reduction": 0.2},
	"lightning": {"name": "雷霆精通", "effect": "连锁弹跳+2", "damage_mult": 1.25, "cooldown_reduction": 0.2},
	"dark":      {"name": "暗影精通", "effect": "击杀回复HP", "damage_mult": 1.2, "cooldown_reduction": 0.25},
	"holy":      {"name": "圣光精通", "effect": "受伤减免15%", "damage_mult": 1.2, "cooldown_reduction": 0.2},
	"poison":    {"name": "剧毒精通", "effect": "中毒扩散", "damage_mult": 1.2, "cooldown_reduction": 0.2},
	"arcane":    {"name": "奥术精通", "effect": "投射物+1", "damage_mult": 1.25, "cooldown_reduction": 0.25},
}

func check_synergies(player: Node) -> void:
	if not is_instance_valid(player): return
	var skill_ids = player.skills.map(func(s): return s.data.id if s.data else "")
	if skill_ids == _last_skill_ids: return
	_last_skill_ids = skill_ids.duplicate()

	# Skill-pair synergies
	var found = []
	for syn in SYNERGIES:
		var match_count = 0
		for sid in syn["skills"]:
			if sid in skill_ids: match_count += 1
		if match_count >= 2:
			found.append(syn)

	for syn in found:
		if syn not in _active_synergies:
			_active_synergies.append(syn)
			EventBus.emit_signal("synergy_activated", syn)
	_active_synergies = _active_synergies.filter(func(s): return s in found)

	# Element resonance / mastery
	var elem_counts: Dictionary = {}
	for skill in player.skills:
		if not skill.data: continue
		var elem = skill.data.element
		if elem == SkillData.Element.NONE: continue
		var ename = ELEMENT_NAMES.get(elem, "")
		if ename == "": continue
		elem_counts[ename] = elem_counts.get(ename, 0) + 1

	var new_resonances: Dictionary = {}
	for ename in elem_counts:
		var cnt = elem_counts[ename]
		if cnt >= 2:
			new_resonances[ename] = cnt

	for ename in new_resonances:
		var cnt = new_resonances[ename]
		var old_cnt = _active_element_resonances.get(ename, 0)
		if cnt >= 2 and old_cnt < 2:
			var effects = {"damage_mult": 1.2}
			EventBus.emit_signal("element_resonance_activated", ename, 2, effects)
		if cnt >= 3 and old_cnt < 3:
			var mastery = ELEMENT_MASTERY_EFFECTS.get(ename, {})
			var effects = {"damage_mult": mastery.get("damage_mult", 1.2), "cooldown_reduction": mastery.get("cooldown_reduction", 0.2)}
			EventBus.emit_signal("element_resonance_activated", ename, 3, effects)
	_active_element_resonances = new_resonances

	# Cache element bonuses for damage queries
	_element_bonuses.clear()
	for ename in _active_element_resonances:
		var cnt = _active_element_resonances[ename]
		var elem_val = -1
		for k in ELEMENT_NAMES:
			if ELEMENT_NAMES[k] == ename: elem_val = k; break
		if elem_val < 0: continue
		var bonus := {"damage_mult": 1.0, "cooldown_reduction": 0.0}
		if cnt >= 2:
			bonus["damage_mult"] = 1.2
		if cnt >= 3:
			var mastery = ELEMENT_MASTERY_EFFECTS.get(ename, {})
			bonus["damage_mult"] = mastery.get("damage_mult", 1.25)
			bonus["cooldown_reduction"] = mastery.get("cooldown_reduction", 0.2)
		_element_bonuses[elem_val] = bonus

func get_active_synergies() -> Array:
	return _active_synergies

func get_synergy_bonus_for_skill(skill_id: String, skill_element: int = -1) -> Dictionary:
	var bonus := {
		"damage_mult": 1.0, "crit_bonus": 0.0,
		"freeze_duration": 0.0, "projectile_count_mult": 1,
		"cooldown_reduction": 0.0, "extra_pierce": 0,
	}
	for syn in _active_synergies:
		if skill_id in syn["skills"]:
			var fx = syn.get("effects", {})
			bonus["damage_mult"] *= fx.get("damage_mult", 1.0)
			bonus["crit_bonus"] += fx.get("crit_bonus", 0.0)
			bonus["freeze_duration"] = maxf(bonus["freeze_duration"], fx.get("freeze_duration", 0.0))
			bonus["projectile_count_mult"] = maxi(bonus["projectile_count_mult"], fx.get("projectile_count_mult", 1))
			bonus["cooldown_reduction"] = maxf(bonus["cooldown_reduction"], fx.get("cooldown_reduction", 0.0))
			bonus["extra_pierce"] += fx.get("extra_pierce", 0)
	# Element resonance / mastery bonus
	if skill_element >= 0 and _element_bonuses.has(skill_element):
		var eb = _element_bonuses[skill_element]
		bonus["damage_mult"] *= eb.get("damage_mult", 1.0)
		bonus["cooldown_reduction"] = maxf(bonus["cooldown_reduction"], eb.get("cooldown_reduction", 0.0))
	bonus["damage_mult"] = minf(bonus["damage_mult"], 4.0)
	return bonus
