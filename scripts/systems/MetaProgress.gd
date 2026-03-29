# MetaProgress.gd
# 局外成长系统 - 魂石货币 + 永久解锁树
# 存档路径: user://save.json
extends Node

# ── 解锁树节点定义 ──────────────────────────────────────
# 每个节点: {id, name, desc, cost, max_level, column, row, requires}
const UNLOCK_NODES := [
	# 攻击列 (column=0)
	{"id":"atk1",    "name":"力量凝聚 I",   "desc":"全局伤害 +10%",        "cost":30,  "max_level":3, "col":0, "row":0, "requires":[]},
	{"id":"atk2",    "name":"力量凝聚 II",  "desc":"全局伤害 +15%",        "cost":60,  "max_level":3, "col":0, "row":1, "requires":["atk1"]},
	{"id":"atk3",    "name":"爆裂之心",     "desc":"暴击率 +10%，暴击伤害 ×1.5", "cost":100, "max_level":1, "col":0, "row":2, "requires":["atk2"]},
	{"id":"atkspd1", "name":"疾速咒语 I",   "desc":"攻击速度 +10%",        "cost":40,  "max_level":3, "col":0, "row":3, "requires":["atk1"]},
	{"id":"atkspd2", "name":"疾速咒语 II",  "desc":"攻击速度 +15%",        "cost":80,  "max_level":2, "col":0, "row":4, "requires":["atkspd1"]},

	# 防御列 (column=1)
	{"id":"hp1",     "name":"铁甲之躯 I",   "desc":"最大生命值 +15%",      "cost":30,  "max_level":3, "col":1, "row":0, "requires":[]},
	{"id":"hp2",     "name":"铁甲之躯 II",  "desc":"最大生命值 +20%",      "cost":60,  "max_level":3, "col":1, "row":1, "requires":["hp1"]},
	{"id":"regen1",  "name":"生命回响",     "desc":"每秒回复 2 HP",        "cost":50,  "max_level":3, "col":1, "row":2, "requires":["hp1"]},
	{"id":"regen2",  "name":"涅槃之力",     "desc":"每秒回复 5 HP + 受伤后3秒无敌", "cost":120,"max_level":1,"col":1,"row":3,"requires":["regen1","hp2"]},
	{"id":"spd1",    "name":"疾风步 I",     "desc":"移动速度 +10%",        "cost":35,  "max_level":3, "col":1, "row":4, "requires":["hp1"]},

	# 特殊列 (column=2)
	{"id":"exp1",    "name":"贪婪之眼 I",   "desc":"经验获取 +15%",        "cost":25,  "max_level":3, "col":2, "row":0, "requires":[]},
	{"id":"exp2",    "name":"贪婪之眼 II",  "desc":"经验获取 +25%",        "cost":55,  "max_level":2, "col":2, "row":1, "requires":["exp1"]},
	{"id":"pickup1", "name":"吸附磁场",     "desc":"拾取范围 +30%",        "cost":40,  "max_level":2, "col":2, "row":2, "requires":["exp1"]},
	{"id":"slot1",   "name":"技能扩展槽",   "desc":"技能槽位 +1（最多8个）","cost":80,  "max_level":2, "col":2, "row":3, "requires":["exp2"]},
	{"id":"luck1",   "name":"命运眷顾",     "desc":"升级选项变为4选1",     "cost":150, "max_level":1, "col":2, "row":4, "requires":["slot1","exp2"]},
]

# ── 存档数据 ────────────────────────────────────────────
var soul_stones: int = 0          # 当前魂石数量
var unlocked: Dictionary = {}     # {node_id: current_level}
var total_runs: int = 0
var best_wave: int = 0
var best_score: int = 0

# ── 单例 ────────────────────────────────────────────────
static var instance: Node = null

func _ready() -> void:
	instance = self
	load_save()

# ── 存档 ────────────────────────────────────────────────
func save() -> void:
	var data := {
		"soul_stones": soul_stones,
		"unlocked": unlocked,
		"total_runs": total_runs,
		"best_wave": best_wave,
		"best_score": best_score,
	}
	var f := FileAccess.open("user://save.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func load_save() -> void:
	if not FileAccess.file_exists("user://save.json"):
		return
	var f := FileAccess.open("user://save.json", FileAccess.READ)
	if not f:
		return
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if parsed == null:
		return
	soul_stones = parsed.get("soul_stones", 0)
	unlocked    = parsed.get("unlocked", {})
	total_runs  = parsed.get("total_runs", 0)
	best_wave   = parsed.get("best_wave", 0)
	best_score  = parsed.get("best_score", 0)

# ── 解锁操作 ────────────────────────────────────────────
func can_unlock(node_id: String) -> bool:
	var node = _get_node_def(node_id)
	if node == null: return false
	var cur_lv = unlocked.get(node_id, 0)
	if cur_lv >= node["max_level"]: return false
	if soul_stones < node["cost"]: return false
	for req in node["requires"]:
		if unlocked.get(req, 0) == 0: return false
	return true

func unlock(node_id: String) -> bool:
	if not can_unlock(node_id): return false
	var node = _get_node_def(node_id)
	soul_stones -= node["cost"]
	unlocked[node_id] = unlocked.get(node_id, 0) + 1
	save()
	return true

func _get_node_def(node_id: String) -> Dictionary:
	for n in UNLOCK_NODES:
		if n["id"] == node_id:
			return n
	return {}

# ── 获取当前加成值（供 Player 读取）────────────────────
func get_damage_bonus() -> float:
	var bonus := 1.0
	bonus += unlocked.get("atk1", 0) * 0.10
	bonus += unlocked.get("atk2", 0) * 0.15
	if unlocked.get("atk3", 0) > 0: bonus += 0.05  # 暴击基础加成
	return bonus

func get_attack_speed_bonus() -> float:
	var bonus := 1.0
	bonus += unlocked.get("atkspd1", 0) * 0.10
	bonus += unlocked.get("atkspd2", 0) * 0.15
	return bonus

func get_hp_bonus() -> float:
	var bonus := 1.0
	bonus += unlocked.get("hp1", 0) * 0.15
	bonus += unlocked.get("hp2", 0) * 0.20
	return bonus

func get_regen_bonus() -> float:
	var regen := 0.0
	regen += unlocked.get("regen1", 0) * 2.0
	regen += unlocked.get("regen2", 0) * 5.0
	return regen

func get_speed_bonus() -> float:
	var bonus := 1.0
	bonus += unlocked.get("spd1", 0) * 0.10
	return bonus

func get_exp_bonus() -> float:
	var bonus := 1.0
	bonus += unlocked.get("exp1", 0) * 0.15
	bonus += unlocked.get("exp2", 0) * 0.25
	return bonus

func get_pickup_bonus() -> float:
	var bonus := 1.0
	bonus += unlocked.get("pickup1", 0) * 0.30
	return bonus

func get_extra_skill_slots() -> int:
	return unlocked.get("slot1", 0)

func get_upgrade_choices_count() -> int:
	return 4 if unlocked.get("luck1", 0) > 0 else 3

# ── 局结束：计算并发放魂石 ──────────────────────────────
func on_run_ended(wave: int, score: int, survive_seconds: float, kills: int) -> int:
	total_runs += 1
	best_wave  = max(best_wave, wave)
	best_score = max(best_score, score)

	var earned := 0
	earned += wave * 5
	earned += kills / 10
	earned += int(survive_seconds / 10)
	earned = max(earned, 3)

	# 应用难度魂石倍率
	var gm = get_tree().root.find_child("Main", true, false)
	if gm and gm.has_meta("current_difficulty_mult"):
		earned = int(earned * gm.get_meta("current_difficulty_mult"))

	soul_stones += earned
	save()
	return earned
