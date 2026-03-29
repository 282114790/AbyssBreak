# DailyChallenge.gd
# 每日挑战 - 固定种子生成特殊游戏配置，每日一次
extends Node

# 每日挑战完成后的奖励
const DAILY_REWARD_SOULS: int = 50

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# ── 今日种子 ────────────────────────────────────────────
func get_today_seed() -> int:
	var date = Time.get_date_dict_from_system()
	# 用年月日组合成整数种子
	return date["year"] * 10000 + date["month"] * 100 + date["day"]

# ── 挑战配置 ────────────────────────────────────────────
func get_challenge_config() -> Dictionary:
	var seed_val = get_today_seed()
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val

	# 随机角色（0=法师, 1=战士, 2=猎手）
	var char_ids = ["mage", "warrior", "hunter"]
	var char_id = char_ids[rng.randi() % char_ids.size()]

	# 随机难度（偏向困难/深渊，增加挑战性）
	var diff_ids = ["normal", "hard", "abyss"]
	var diff_id = diff_ids[min(rng.randi() % 3, 2)]

	# modifier 类型（seed%3）
	var mod_type = seed_val % 3
	var modifier_name: String
	var modifier_desc: String
	match mod_type:
		0:
			modifier_name = "冰封时代"
			modifier_desc = "敌人速度+50% / 玩家移速+30%"
		1:
			modifier_name = "脆弱时刻"
			modifier_desc = "玩家最大HP减半 / 技能伤害+50%"
		2:
			modifier_name = "魔力枯竭"
			modifier_desc = "所有技能冷却×2"

	return {
		"char_id": char_id,
		"difficulty_id": diff_id,
		"modifier_type": mod_type,
		"modifier_name": modifier_name,
		"modifier_desc": modifier_desc,
		"seed": seed_val,
	}

# ── 今日是否已完成 ───────────────────────────────────────
func is_completed_today() -> bool:
	var save_data = _load_daily_save()
	if save_data == null:
		return false
	var today_key = _get_today_key()
	return save_data.get(today_key, false)

# ── 标记今日完成 ─────────────────────────────────────────
func mark_completed(meta_progress: Node) -> void:
	var save_data = _load_daily_save()
	if save_data == null:
		save_data = {}
	var today_key = _get_today_key()
	if save_data.get(today_key, false):
		return  # 已完成，不重复奖励
	save_data[today_key] = true
	# 奖励魂石
	if meta_progress:
		meta_progress.soul_stones += DAILY_REWARD_SOULS
		meta_progress.save()
	_save_daily_save(save_data)

# ── 应用 modifier 到游戏 ─────────────────────────────────
func apply_modifier(modifier_type: int, player: Node, wave_manager: Node) -> void:
	match modifier_type:
		0:  # 冰封时代：敌人+50%速度（WaveManager），玩家+30%移速
			if wave_manager:
				wave_manager.set_meta("daily_enemy_speed_mult", 1.5)
			if player and player.get("move_speed") != null:
				player.move_speed *= 1.3
		1:  # 脆弱时刻：玩家HP减半，技能伤害+50%
			if player:
				if player.get("max_hp") != null:
					player.max_hp = max(1.0, player.max_hp * 0.5)
					player.hp = min(player.hp, player.max_hp)
				if player.get("damage_multiplier") != null:
					player.damage_multiplier *= 1.5
		2:  # 魔力枯竭：所有技能冷却×2
			if player and player.get("skills") != null:
				for skill in player.skills:
					if skill.get("data") != null and skill.data.get("cooldown") != null:
						skill.data.cooldown *= 2.0

# ── 私有工具函数 ─────────────────────────────────────────
func _get_today_key() -> String:
	var date = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [date["year"], date["month"], date["day"]]

func _load_daily_save() -> Variant:
	if not FileAccess.file_exists("user://daily_challenge.json"):
		return null
	var f = FileAccess.open("user://daily_challenge.json", FileAccess.READ)
	if not f:
		return null
	var text = f.get_as_text()
	f.close()
	return JSON.parse_string(text)

func _save_daily_save(data: Dictionary) -> void:
	var f = FileAccess.open("user://daily_challenge.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()
