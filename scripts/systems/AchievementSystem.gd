# AchievementSystem.gd
# 成就系统 - 30个成就，自动追踪进度，解锁时右下角弹窗
# 作为 Node 节点由 Main.gd 的 _ready() add_child 加入
extends Node

# ── 成就定义（30个）────────────────────────────────────
var achievements: Array = [
	# 战斗类
	{"id":"first_blood",    "name":"初次献血",     "desc":"首次击杀敌人",                "icon_emoji":"🩸", "condition_value":1,    "reward_souls":5,  "unlocked":false},
	{"id":"slayer_10",      "name":"初露锋芒",     "desc":"累计击杀10个敌人",            "icon_emoji":"⚔", "condition_value":10,   "reward_souls":10, "unlocked":false},
	{"id":"slayer_100",     "name":"百人斩",       "desc":"累计击杀100个敌人",           "icon_emoji":"💀", "condition_value":100,  "reward_souls":20, "unlocked":false},
	{"id":"slayer_500",     "name":"死神使者",     "desc":"累计击杀500个敌人",           "icon_emoji":"☠", "condition_value":500,  "reward_souls":50, "unlocked":false},
	{"id":"boss_slayer",    "name":"深渊猎手",     "desc":"击败深渊领主Boss",            "icon_emoji":"👹", "condition_value":1,    "reward_souls":30, "unlocked":false},
	{"id":"overkill",       "name":"过度伤害",     "desc":"单次伤害达到200点",           "icon_emoji":"💥", "condition_value":200,  "reward_souls":15, "unlocked":false},
	{"id":"speed_kill",     "name":"连环收割",     "desc":"10秒内击杀10个敌人",         "icon_emoji":"⚡", "condition_value":10,   "reward_souls":20, "unlocked":false},
	{"id":"multi_kill_5",   "name":"五杀",         "desc":"3秒内击杀5个敌人",           "icon_emoji":"🔥", "condition_value":5,    "reward_souls":20, "unlocked":false},
	# 生存类
	{"id":"survivor_60",    "name":"初入深渊",     "desc":"存活60秒",                    "icon_emoji":"⏱", "condition_value":60,   "reward_souls":5,  "unlocked":false},
	{"id":"survivor_300",   "name":"深渊老兵",     "desc":"存活5分钟",                   "icon_emoji":"🛡", "condition_value":300,  "reward_souls":15, "unlocked":false},
	{"id":"survivor_600",   "name":"深渊传说",     "desc":"存活10分钟",                  "icon_emoji":"🏆", "condition_value":600,  "reward_souls":40, "unlocked":false},
	{"id":"low_hp_30",      "name":"命悬一线",     "desc":"HP低于20%时存活超30秒",       "icon_emoji":"❤", "condition_value":30,   "reward_souls":25, "unlocked":false},
	{"id":"abyss_mode",     "name":"深渊征服者",   "desc":"在深渊难度完成一局",          "icon_emoji":"🌑", "condition_value":1,    "reward_souls":100,"unlocked":false},
	{"id":"no_passive_run", "name":"裸跑",         "desc":"整局不拾取被动道具完成",      "icon_emoji":"🎯", "condition_value":1,    "reward_souls":50, "unlocked":false},
	# 收集类
	{"id":"soul_100",       "name":"魂石收藏家",   "desc":"累计获得100魂石",             "icon_emoji":"💎", "condition_value":100,  "reward_souls":10, "unlocked":false},
	{"id":"soul_500",       "name":"魂石大亨",     "desc":"累计获得500魂石",             "icon_emoji":"💠", "condition_value":500,  "reward_souls":30, "unlocked":false},
	{"id":"collect_gems_50","name":"宝石猎人",     "desc":"单局收集50个经验宝石",        "icon_emoji":"💚", "condition_value":50,   "reward_souls":15, "unlocked":false},
	{"id":"all_char_unlocked","name":"全员集结",   "desc":"解锁所有角色",               "icon_emoji":"👥", "condition_value":1,    "reward_souls":80, "unlocked":false},
	# 技能类
	{"id":"level_5",        "name":"初窥门径",     "desc":"达到5级",                     "icon_emoji":"⭐", "condition_value":5,    "reward_souls":10, "unlocked":false},
	{"id":"level_10",       "name":"渐入佳境",     "desc":"达到10级",                    "icon_emoji":"🌟", "condition_value":10,   "reward_souls":20, "unlocked":false},
	{"id":"level_20",       "name":"登峰造极",     "desc":"达到20级",                    "icon_emoji":"✨", "condition_value":20,   "reward_souls":50, "unlocked":false},
	{"id":"max_skills",     "name":"技能满载",     "desc":"同时拥有6个技能",             "icon_emoji":"🎮", "condition_value":6,    "reward_souls":30, "unlocked":false},
	{"id":"skill_master",   "name":"技能宗师",     "desc":"任意技能升到5级",             "icon_emoji":"🔮", "condition_value":5,    "reward_souls":25, "unlocked":false},
	{"id":"first_evolve",   "name":"进化之路",     "desc":"完成首次技能进化",            "icon_emoji":"🦋", "condition_value":1,    "reward_souls":30, "unlocked":false},
	{"id":"wave_5",         "name":"浴血第五波",   "desc":"到达第5波",                   "icon_emoji":"🌊", "condition_value":5,    "reward_souls":10, "unlocked":false},
	{"id":"wave_10",        "name":"深渊之巅",     "desc":"到达第10波",                  "icon_emoji":"🏔", "condition_value":10,   "reward_souls":30, "unlocked":false},
	# 特殊类
	{"id":"first_run",      "name":"踏入深渊",     "desc":"完成首次游戏",                "icon_emoji":"🎮", "condition_value":1,    "reward_souls":5,  "unlocked":false},
	{"id":"meteor_user",    "name":"天降神罚",     "desc":"激活陨石雨技能",              "icon_emoji":"☄", "condition_value":1,    "reward_souls":10, "unlocked":false},
	{"id":"void_user",      "name":"虚空掌控者",   "desc":"激活虚空裂缝技能",            "icon_emoji":"🕳", "condition_value":1,    "reward_souls":10, "unlocked":false},
	{"id":"perfectionist",  "name":"完美主义者",   "desc":"单局内解锁3个成就",           "icon_emoji":"🥇", "condition_value":3,    "reward_souls":40, "unlocked":false},
]

# ── 本局会话状态 ────────────────────────────────────────
var session_kills: int = 0
var session_start_time: float = 0.0
var session_evolutions: int = 0
var session_achievements_unlocked: int = 0
var recent_kills: Array = []
var low_hp_start_time: float = -1
var session_gems: int = 0
var session_passives: int = 0

# 累计击杀（持久化）
var total_kills: int = 0

# 内部
var _popup_queue: Array = []
var _popup_active: bool = false
var _meta_progress: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_achievements()
	# 延迟连接，等 EventBus 就绪
	await get_tree().process_frame
	_connect_signals()
	session_start_time = Time.get_ticks_msec() / 1000.0

func _connect_signals() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.player_leveled_up.connect(_on_level_up)
	EventBus.wave_changed.connect(_on_wave_changed)
	EventBus.player_died.connect(_on_player_died)
	EventBus.skill_evolved.connect(_on_skill_evolved)
	EventBus.skill_leveled_up.connect(_on_skill_leveled_up)
	if EventBus.has_signal("gem_collected"):
		EventBus.gem_collected.connect(_on_gem_collected)
	if EventBus.has_signal("skill_activated"):
		EventBus.skill_activated.connect(_on_skill_activated_signal)
	EventBus.damage_dealt.connect(_on_damage_dealt)

func set_meta_progress(mp: Node) -> void:
	_meta_progress = mp

# ── 信号处理 ────────────────────────────────────────────
func _on_enemy_died(pos: Vector2, exp_val: int) -> void:
	session_kills += 1
	total_kills += 1
	var now = Time.get_ticks_msec() / 1000.0
	recent_kills.append(now)
	# 清理10秒前的记录
	recent_kills = recent_kills.filter(func(t): return now - t <= 10.0)

	# Boss检测
	if exp_val >= 100:
		_try_unlock("boss_slayer")

	# 击杀计数成就
	_try_unlock_with_value("first_blood", total_kills)
	_try_unlock_with_value("slayer_10", total_kills)
	_try_unlock_with_value("slayer_100", total_kills)
	_try_unlock_with_value("slayer_500", total_kills)

	# speed_kill: 10秒内击杀10个
	if recent_kills.size() >= 10:
		_try_unlock("speed_kill")

	# multi_kill_5: 3秒内击杀5个
	var kills_3s = recent_kills.filter(func(t): return now - t <= 3.0)
	if kills_3s.size() >= 5:
		_try_unlock("multi_kill_5")

func _on_damage_dealt(pos: Vector2, amount: int, color: Color) -> void:
	if amount >= 200:
		_try_unlock("overkill")

func _on_player_damaged(current_hp: float, max_hp: float) -> void:
	var ratio = current_hp / max(max_hp, 1.0)
	if ratio < 0.2:
		if low_hp_start_time < 0:
			low_hp_start_time = Time.get_ticks_msec() / 1000.0
	else:
		low_hp_start_time = -1

func _on_level_up(new_level: int) -> void:
	_try_unlock_with_value("level_5", new_level)
	_try_unlock_with_value("level_10", new_level)
	_try_unlock_with_value("level_20", new_level)

func _on_wave_changed(wave: int) -> void:
	_try_unlock_with_value("wave_5", wave)
	_try_unlock_with_value("wave_10", wave)

func _on_player_died() -> void:
	_try_unlock("first_run")
	# 深渊模式检测
	var main = get_tree().root.find_child("Main", true, false)
	if main and main.get("current_difficulty") != null:
		var diff = main.current_difficulty
		if diff and diff.id == "abyss":
			_try_unlock("abyss_mode")
	# no_passive_run: 不拾取被动完成
	if session_passives == 0:
		_try_unlock("no_passive_run")
	_save_achievements()

func _on_skill_evolved(old_id: String, new_id: String) -> void:
	session_evolutions += 1
	_try_unlock("first_evolve")

func _on_skill_leveled_up(skill_id: String, new_level: int) -> void:
	if new_level >= 5:
		_try_unlock("skill_master")

func _on_gem_collected(_amount: int) -> void:
	session_gems += 1
	_try_unlock_with_value("collect_gems_50", session_gems)

func _on_skill_activated_signal(skill_id: String) -> void:
	on_skill_activated(skill_id)

func on_skill_activated(skill_id: String) -> void:
	if skill_id == "meteor_shower":
		_try_unlock("meteor_user")
	elif skill_id == "void_rift":
		_try_unlock("void_user")

func on_passive_picked() -> void:
	session_passives += 1

# ── 每帧检测（时间/HP相关）──────────────────────────────
func _process(_delta: float) -> void:
	if get_tree().paused:
		return
	var now = Time.get_ticks_msec() / 1000.0

	# 存活时间成就
	var elapsed = now - session_start_time
	_try_unlock_with_value("survivor_60", int(elapsed))
	_try_unlock_with_value("survivor_300", int(elapsed))
	_try_unlock_with_value("survivor_600", int(elapsed))

	# 低HP存活30秒
	if low_hp_start_time >= 0:
		var low_hp_elapsed = now - low_hp_start_time
		if low_hp_elapsed >= 30.0:
			_try_unlock("low_hp_30")

	# 魂石成就（检查 MetaProgress）
	if _meta_progress:
		var souls = _meta_progress.soul_stones
		_try_unlock_with_value("soul_100", souls)
		_try_unlock_with_value("soul_500", souls)

	# max_skills：检查玩家技能数
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("skills") != null:
		if player.skills.size() >= 6:
			_try_unlock("max_skills")

	# all_char_unlocked
	var char_reg = get_tree().root.find_child("CharacterRegistry", true, false)
	if char_reg and char_reg.get("all_characters") != null and _meta_progress:
		var all_unlocked = true
		for c in char_reg.all_characters:
			if not char_reg.is_unlocked(c.id, _meta_progress):
				all_unlocked = false
				break
		if all_unlocked:
			_try_unlock("all_char_unlocked")

# ── 解锁逻辑 ────────────────────────────────────────────
func _try_unlock(achievement_id: String) -> void:
	for ach in achievements:
		if ach["id"] == achievement_id:
			if not ach["unlocked"]:
				ach["unlocked"] = true
				session_achievements_unlocked += 1
				_on_achievement_unlocked(ach)
				# perfectionist: 单局解锁3个
				if session_achievements_unlocked >= 3:
					_try_unlock("perfectionist")
			return

func _try_unlock_with_value(achievement_id: String, current_value: int) -> void:
	for ach in achievements:
		if ach["id"] == achievement_id:
			if not ach["unlocked"] and current_value >= ach["condition_value"]:
				ach["unlocked"] = true
				session_achievements_unlocked += 1
				_on_achievement_unlocked(ach)
				if session_achievements_unlocked >= 3:
					_try_unlock("perfectionist")
			return

func _on_achievement_unlocked(ach: Dictionary) -> void:
	# 奖励魂石
	if _meta_progress:
		_meta_progress.soul_stones += ach["reward_souls"]
		_meta_progress.save()
	# 弹窗通知
	_queue_popup(ach)
	_save_achievements()

# ── 弹窗通知（右下角）──────────────────────────────────
func _queue_popup(ach: Dictionary) -> void:
	_popup_queue.append(ach)
	if not _popup_active:
		_show_next_popup()

func _show_next_popup() -> void:
	if _popup_queue.is_empty():
		_popup_active = false
		return
	_popup_active = true
	var ach = _popup_queue.pop_front()
	_create_popup_ui(ach)

func _create_popup_ui(ach: Dictionary) -> void:
	# 找最顶层 CanvasLayer 显示
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	get_tree().root.add_child(canvas)

	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(300, 72)
	# 右下角定位
	panel.anchor_left   = 1.0
	panel.anchor_right  = 1.0
	panel.anchor_top    = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left   = -320
	panel.offset_right  = -10
	panel.offset_top    = -90
	panel.offset_bottom = -10
	canvas.add_child(panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.10, 0.06, 0.95)
	style.border_color = Color(0.8, 0.7, 0.2)
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2; style.border_width_bottom = 2
	style.corner_radius_top_left = 6; style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6; style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
	# 成就弹窗背景纹理
	if ResourceLoader.exists("res://assets/ui/achievement_popup_bg.png"):
		var bg = TextureRect.new()
		bg.texture = load("res://assets/ui/achievement_popup_bg.png")
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.modulate = Color(1, 1, 1, 0.35)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	vbox.offset_left = 8
	vbox.offset_right = -8
	vbox.offset_top = 6
	vbox.offset_bottom = -6
	panel.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = "🏅 成就解锁！"
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	vbox.add_child(title_lbl)

	var name_lbl = Label.new()
	name_lbl.text = "%s %s" % [ach["icon_emoji"], ach["name"]]
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	vbox.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = "%s  +%d💎" % [ach["desc"], ach["reward_souls"]]
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(desc_lbl)

	# 滑入动画
	panel.offset_left = 10
	panel.offset_right = 330
	var tween_in = canvas.create_tween()
	tween_in.tween_property(panel, "offset_left", -320, 0.3).set_ease(Tween.EASE_OUT)
	tween_in.tween_property(panel, "offset_right", -10, 0.3).set_ease(Tween.EASE_OUT)
	tween_in.set_parallel(true)

	# 3秒后滑出并清除
	await get_tree().create_timer(3.0, true).timeout
	if is_instance_valid(panel):
		var tween_out = canvas.create_tween()
		tween_out.tween_property(panel, "offset_left", 10, 0.3)
		tween_out.tween_property(panel, "offset_right", 330, 0.3)
		tween_out.set_parallel(true)
		await tween_out.finished
	if is_instance_valid(canvas):
		canvas.queue_free()
	_show_next_popup()

# ── 存档 ────────────────────────────────────────────────
func _save_achievements() -> void:
	var data: Dictionary = {}
	for ach in achievements:
		data[ach["id"]] = ach["unlocked"]
	data["total_kills"] = total_kills
	var f = FileAccess.open("user://achievements.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func _load_achievements() -> void:
	if not FileAccess.file_exists("user://achievements.json"):
		return
	var f = FileAccess.open("user://achievements.json", FileAccess.READ)
	if not f:
		return
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if parsed == null:
		return
	for ach in achievements:
		if ach["id"] in parsed:
			ach["unlocked"] = parsed[ach["id"]]
	if "total_kills" in parsed:
		total_kills = int(parsed["total_kills"])
