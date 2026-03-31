# SynergySystem.gd
# 技能协同提示系统（#17）— 检测玩家技能组合，显示协同提示
extends Node

# 协同对：{skills:[], name, desc, color}
const SYNERGIES := [
	{
		"skills": ["fireball", "lightning"],
		"name": "🔥⚡ 火雷连击",
		"desc": "火焰+闪电：燃烧敌人被闪电击中时伤害×2",
		"color": Color(1.0, 0.7, 0.1)
	},
	{
		"skills": ["iceblade", "frostzone"],
		"name": "❄ 寒冰法则",
		"desc": "冰刃+寒冰领域：减速敌人受冰刃暴击率+30%",
		"color": Color(0.4, 0.85, 1.0)
	},
	{
		"skills": ["thorn_aura", "poison_cloud"],
		"name": "🌿 毒刺领域",
		"desc": "荆棘+毒云：中毒敌人被荆棘击中出血",
		"color": Color(0.3, 0.9, 0.3)
	},
	{
		"skills": ["void_rift", "arcane_orb"],
		"name": "🌑💠 深渊奥术",
		"desc": "虚空+奥术：弹幕在黑洞中伤害×1.8",
		"color": Color(0.6, 0.2, 1.0)
	},
	{
		"skills": ["blood_nova", "orbital"],
		"name": "🩸🌀 血旋领域",
		"desc": "血新星+旋转护盾：护盾旋转速度+50%",
		"color": Color(0.9, 0.15, 0.3)
	},
	{
		"skills": ["time_slow", "meteor_shower"],
		"name": "⏳☄ 时空陨石",
		"desc": "时间减速+陨石雨：慢速状态下陨石数量×2",
		"color": Color(1.0, 0.5, 0.0)
	},
]

var _active_synergies: Array = []
var _last_skill_ids: Array = []

func check_synergies(player: Node) -> void:
	if not is_instance_valid(player): return
	var skill_ids = player.skills.map(func(s): return s.data.id if s.data else "")
	if skill_ids == _last_skill_ids: return
	_last_skill_ids = skill_ids.duplicate()

	var found = []
	for syn in SYNERGIES:
		var match_count = 0
		for sid in syn["skills"]:
			if sid in skill_ids: match_count += 1
		if match_count >= 2:
			found.append(syn)

	# 新发现的协同才弹提示
	for syn in found:
		if syn not in _active_synergies:
			_active_synergies.append(syn)
			EventBus.emit_signal("synergy_activated", syn)
	# 失效的协同
	_active_synergies = _active_synergies.filter(func(s): return s in found)

func get_active_synergies() -> Array:
	return _active_synergies
