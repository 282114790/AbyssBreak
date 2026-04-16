# BuildCodex.gd
# Build 图鉴系统 — 记录玩家在游戏中发现的技能组合与 Build 配方
extends Node

const BUILD_DEFS := [
	{"id": "fire_master", "name": "烈焰支配者", "desc": "同时拥有3个火系技能",
	 "condition": "element", "element": "fire", "count": 3},
	{"id": "ice_master", "name": "寒冰领主", "desc": "同时拥有3个冰系技能",
	 "condition": "element", "element": "ice", "count": 3},
	{"id": "lightning_master", "name": "雷霆之王", "desc": "同时拥有3个雷系技能",
	 "condition": "element", "element": "lightning", "count": 3},
	{"id": "dark_master", "name": "暗影主宰", "desc": "同时拥有3个暗系技能",
	 "condition": "element", "element": "dark", "count": 3},
	{"id": "holy_master", "name": "圣光守护者", "desc": "同时拥有3个圣系技能",
	 "condition": "element", "element": "holy", "count": 3},
	{"id": "elementalist", "name": "元素使者", "desc": "同时拥有4种不同元素的技能",
	 "condition": "diversity", "count": 4},
	{"id": "glass_cannon", "name": "玻璃大炮", "desc": "选择玻璃炮诅咒后击败Boss",
	 "condition": "curse_clear", "curse_id": "glass_cannon"},
	{"id": "speed_demon", "name": "速度恶魔", "desc": "猎人在移速加成>100%时",
	 "condition": "speed_threshold", "threshold": 2.0},
	{"id": "full_evolved", "name": "终极进化", "desc": "同时拥有2个进化技能",
	 "condition": "evolved_count", "count": 2},
	{"id": "synergy_collector", "name": "协同大师", "desc": "同时激活3个技能协同",
	 "condition": "synergy_count", "count": 3},
]

var discovered_builds: Array = []  # Array of build_id strings
var _checked_this_run: Dictionary = {}

func _ready() -> void:
	_load()

func check_builds(player: Node) -> void:
	if not is_instance_valid(player): return

	var elem_counts: Dictionary = {}
	var elem_set: Dictionary = {}
	var evolved_count := 0

	for skill in player.skills:
		if not skill.data: continue
		var elem = skill.data.element
		if elem != SkillData.Element.NONE:
			var ename = _elem_name(elem)
			elem_counts[ename] = elem_counts.get(ename, 0) + 1
			elem_set[ename] = true
		if skill.data.id.ends_with("_evolved"):
			evolved_count += 1

	for build_def in BUILD_DEFS:
		var bid = build_def["id"]
		if bid in _checked_this_run:
			continue
		var matched := false
		match build_def["condition"]:
			"element":
				matched = elem_counts.get(build_def["element"], 0) >= build_def["count"]
			"diversity":
				matched = elem_set.size() >= build_def["count"]
			"evolved_count":
				matched = evolved_count >= build_def["count"]
			"synergy_count":
				var syn_sys = get_tree().get_first_node_in_group("synergy_system")
				if syn_sys == null:
					var main = get_tree().root.find_child("Main", true, false)
					if main and main.get("synergy_system"):
						syn_sys = main.synergy_system
				if syn_sys:
					matched = syn_sys.get_active_synergies().size() >= build_def["count"]
			"speed_threshold":
				matched = player.move_speed >= player.base_move_speed * build_def["threshold"]

		if matched:
			_checked_this_run[bid] = true
			if bid not in discovered_builds:
				discovered_builds.append(bid)
				_save()
				EventBus.emit_signal("build_discovered", bid, build_def["name"])

func reset_run() -> void:
	_checked_this_run.clear()

func _elem_name(elem: int) -> String:
	match elem:
		0: return "fire"
		1: return "ice"
		2: return "lightning"
		3: return "dark"
		4: return "holy"
		5: return "poison"
		6: return "arcane"
	return ""

func get_all_builds() -> Array:
	var result = []
	for bd in BUILD_DEFS:
		var entry = bd.duplicate()
		entry["discovered"] = bd["id"] in discovered_builds
		result.append(entry)
	return result

func _save() -> void:
	var meta = get_tree().root.find_child("MetaProgress", true, false)
	if meta:
		meta.set_meta("build_codex", discovered_builds)
		meta.save()

func _load() -> void:
	var meta = get_tree().root.find_child("MetaProgress", true, false)
	if meta and meta.has_meta("build_codex"):
		discovered_builds = meta.get_meta("build_codex")
