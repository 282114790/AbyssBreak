# RandomEventSystem.gd
# 随机事件系统 — 不暂停游戏的侧边选择卡片，每隔一段时间触发风险/回报二选一
extends Node

const MAJOR_INTERVAL_SEC := 90.0
const MINOR_INTERVAL_SEC := 30.0
const CARD_DISPLAY_SEC := 8.0

var _major_timer := 0.0
var _minor_timer := 0.0
var _minor_index := 0
var _panel: CanvasLayer = null
var _auto_close_timer: float = 0.0
var _used_indices: Array = []

const EVENTS := [
	{
		"title": "深渊裂缝",
		"desc": "一道裂缝出现在脚下。",
		"optA": {"text": "跳入裂缝 → 获得随机遗物", "risk": false, "action": "relic"},
		"optB": {"text": "引爆裂缝 → 范围伤害，损失15%血量", "risk": true, "action": "aoe_damage"},
	},
	{
		"title": "血之契约",
		"desc": "一个声音低语……以血换力。",
		"optA": {"text": "接受 → HP-30%，伤害+25%持续30秒", "risk": true, "action": "blood_pact"},
		"optB": {"text": "拒绝 → 无事发生", "risk": false, "action": "nothing"},
	},
	{
		"title": "魔法涌流",
		"desc": "空气中充满了不稳定的魔力。",
		"optA": {"text": "吸收 → 随机技能CD永久-0.5s", "risk": false, "action": "cd_reduce"},
		"optB": {"text": "引爆 → 清屏伤害，首技能CD变10s", "risk": true, "action": "overload"},
	},
	{
		"title": "迷途灵魂",
		"desc": "一个迷失的灵魂向你靠近。",
		"optA": {"text": "引导它 → 获得波次×20经验", "risk": false, "action": "exp_bonus"},
		"optB": {"text": "吸收它 → 最大HP+20%，1分钟禁疗", "risk": true, "action": "soul_absorb"},
	},
	{
		"title": "贪婪宝箱",
		"desc": "一个发光的宝箱突然出现，周围有精英守卫。",
		"optA": {"text": "打开宝箱 → 获得遗物+50金币，召唤3精英", "risk": true, "action": "treasure_trap"},
		"optB": {"text": "谨慎离开 → 回复20%血量", "risk": false, "action": "safe_heal"},
	},
	{
		"title": "诅咒祭坛",
		"desc": "一座古老的祭坛散发着不祥的气息。",
		"optA": {"text": "献祭 → 移速-15%，全技能伤害+40%持续60秒", "risk": true, "action": "altar_sacrifice"},
		"optB": {"text": "净化 → 移除一个诅咒（若有）", "risk": false, "action": "altar_purify"},
	},
	{
		"title": "时间裂隙",
		"desc": "时间的流动变得不稳定。",
		"optA": {"text": "加速时间 → 敌人加速30秒，经验×2", "risk": true, "action": "time_accel"},
		"optB": {"text": "减速时间 → 全屏减速8秒", "risk": false, "action": "time_slow"},
	},
	{
		"title": "深渊商人",
		"desc": "一个神秘商人从虚空中走出。",
		"optA": {"text": "交易 → 花费100金换史诗遗物", "risk": false, "action": "merchant_deal"},
		"optB": {"text": "抢劫 → 免费获得遗物，但损失25%HP", "risk": true, "action": "merchant_rob"},
	},
	{
		"title": "变异浪潮",
		"desc": "大地震颤，敌人开始异变。",
		"optA": {"text": "拥抱混沌 → 30秒内敌人更快但经验×3", "risk": true, "action": "mutate_fast"},
		"optB": {"text": "抵御异变 → 30秒内敌人更慢但更肉", "risk": false, "action": "mutate_tank"},
	},
	{
		"title": "暗影分身",
		"desc": "你的影子似乎有了自己的意志。",
		"optA": {"text": "融合 → 攻速+50%持续45秒", "risk": false, "action": "shadow_merge"},
		"optB": {"text": "对抗 → 暴击率+30%持续30秒，但受伤×1.5", "risk": true, "action": "shadow_fight"},
	},
	{
		"title": "生命之泉",
		"desc": "一股温暖的能量从地下涌出。",
		"optA": {"text": "饮用 → 回满血量，获得10秒回血光环", "risk": false, "action": "fountain_drink"},
		"optB": {"text": "献血 → HP-50%，永久伤害+15%", "risk": true, "action": "fountain_sacrifice"},
	},
	{
		"title": "赌徒骰子",
		"desc": "一颗闪烁的骰子在空中旋转。",
		"optA": {"text": "掷骰子 → 50%几率获得3个遗物，50%失去30%HP", "risk": true, "action": "gamble_dice"},
		"optB": {"text": "稳妥 → 必定获得1个遗物", "risk": false, "action": "gamble_safe"},
	},
]

func _process(delta: float) -> void:
	if EventBus.game_logic_paused:
		return
	if is_instance_valid(_panel):
		_auto_close_timer -= delta
		if _auto_close_timer <= 0.0:
			_close()
		return

	_major_timer += delta
	_minor_timer += delta

	# 小事件（30秒周期）：直接触发，无需选择
	if _minor_timer >= MINOR_INTERVAL_SEC:
		_minor_timer = 0.0
		_trigger_minor_event()

	# 大事件（90秒周期）：二选一卡片
	if _major_timer >= MAJOR_INTERVAL_SEC:
		_major_timer = 0.0
		_trigger_event()

func _trigger_event() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return
	var idx = _pick_event_index()
	var ev = EVENTS[idx]
	_show_event(ev, player)

func _pick_event_index() -> int:
	if _used_indices.size() >= EVENTS.size():
		_used_indices.clear()
	var available: Array = []
	for i in range(EVENTS.size()):
		if not _used_indices.has(i):
			available.append(i)
	var picked = available[randi() % available.size()]
	_used_indices.append(picked)
	return picked

func _show_event(ev: Dictionary, player: Node) -> void:
	_auto_close_timer = CARD_DISPLAY_SEC
	_panel = CanvasLayer.new()
	_panel.layer = 12
	get_tree().current_scene.add_child(_panel)

	var card = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.14, 0.92)
	sb.corner_radius_top_left = 8
	sb.corner_radius_bottom_left = 8
	sb.border_width_left = 3
	sb.border_color = Color(1.0, 0.75, 0.2, 0.9)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", sb)

	card.anchor_right = 1.0
	card.anchor_top = 0.3
	card.offset_left = -340
	card.offset_right = 0
	card.offset_top = 0
	card.offset_bottom = 0
	card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	card.size_flags_horizontal = Control.SIZE_SHRINK_END
	card.custom_minimum_size = Vector2(320, 0)
	_panel.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var title = Label.new()
	title.text = ev["title"]
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = ev["desc"]
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)

	for opt_key in ["optA", "optB"]:
		var opt = ev[opt_key]
		var btn = Button.new()
		btn.text = opt["text"]
		btn.custom_minimum_size = Vector2(280, 36)
		var btn_sb = StyleBoxFlat.new()
		btn_sb.bg_color = Color(0.85, 0.25, 0.2, 0.7) if opt["risk"] else Color(0.2, 0.65, 0.35, 0.7)
		btn_sb.corner_radius_top_left = 4
		btn_sb.corner_radius_top_right = 4
		btn_sb.corner_radius_bottom_left = 4
		btn_sb.corner_radius_bottom_right = 4
		btn_sb.content_margin_left = 8
		btn_sb.content_margin_right = 8
		btn_sb.content_margin_top = 4
		btn_sb.content_margin_bottom = 4
		btn.add_theme_stylebox_override("normal", btn_sb)
		var hover_sb = btn_sb.duplicate()
		hover_sb.bg_color = hover_sb.bg_color.lightened(0.2)
		btn.add_theme_stylebox_override("hover", hover_sb)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(func(): _choose(opt["action"], player))
		vbox.add_child(btn)

	var timer_lbl = Label.new()
	timer_lbl.name = "TimerLabel"
	timer_lbl.text = str(int(CARD_DISPLAY_SEC)) + "s"
	timer_lbl.add_theme_font_size_override("font_size", 11)
	timer_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(timer_lbl)

	# slide-in animation
	card.modulate.a = 0.0
	card.position.x += 340
	var tw = card.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(card, "position:x", card.position.x - 340, 0.35)
	tw.parallel().tween_property(card, "modulate:a", 1.0, 0.25)

	# update countdown label
	_start_countdown_update(timer_lbl)

func _start_countdown_update(lbl: Label) -> void:
	if not is_instance_valid(lbl) or not is_instance_valid(_panel):
		return
	lbl.text = str(max(0, int(_auto_close_timer))) + "s"
	get_tree().create_timer(1.0).timeout.connect(func():
		_start_countdown_update(lbl)
	)

func _choose(action: String, player: Node) -> void:
	match action:
		"relic":
			var main = get_tree().current_scene
			if main.has_method("_drop_relic_at"):
				main._drop_relic_at(player.global_position + Vector2(60, 0))
		"aoe_damage":
			player.current_hp = max(player.current_hp - player.max_hp * 0.15, 1)
			EventBus.emit_signal("player_hp_changed", player.current_hp, player.max_hp)
			for e in get_tree().get_nodes_in_group("enemies"):
				if player.global_position.distance_to(e.global_position) < 300:
					e.take_damage(player.max_hp * 0.5, false)
		"blood_pact":
			player.current_hp = max(player.current_hp - player.max_hp * 0.3, 1)
			EventBus.emit_signal("player_hp_changed", player.current_hp, player.max_hp)
			player.damage_multiplier *= 1.25
			get_tree().create_timer(30.0).timeout.connect(func():
				if is_instance_valid(player): player.damage_multiplier /= 1.25
			)
		"cd_reduce":
			if not player.skills.is_empty():
				var sk = player.skills[randi() % player.skills.size()]
				sk.data.cooldown = max(sk.data.cooldown - 0.5, 0.2)
		"overload":
			for e in get_tree().get_nodes_in_group("enemies"):
				e.take_damage(999.0, false)
			if not player.skills.is_empty():
				player.skills[0].cooldown_timer = 10.0
		"exp_bonus":
			var wave = get_tree().current_scene.wave_manager.current_wave if get_tree().current_scene.get("wave_manager") else 1
			player.gain_exp(wave * 20)
			EventBus.emit_signal("pickup_float_text", player.global_position + Vector2(0, -30),
				"+%d 经验" % (wave * 20), Color(0.3, 0.9, 1.0))
		"soul_absorb":
			player.max_hp = int(player.max_hp * 1.2)
			player.current_hp = min(player.current_hp + int(player.max_hp * 0.1), player.max_hp)
			EventBus.emit_signal("player_hp_changed", player.current_hp, player.max_hp)
			player.heal_disabled = true
			get_tree().create_timer(60.0).timeout.connect(func():
				if is_instance_valid(player): player.heal_disabled = false
			)
		"treasure_trap":
			var main = get_tree().current_scene
			if main.has_method("_drop_relic_at"):
				main._drop_relic_at(player.global_position + Vector2(60, 0))
			player.gold += 50
			var wm = main.get("wave_manager")
			if wm:
				for i in range(3):
					wm.call_deferred("_spawn_elite")
		"safe_heal":
			player.heal(player.max_hp * 0.2)
		"altar_sacrifice":
			player.move_speed *= 0.85
			player.damage_multiplier *= 1.4
			get_tree().create_timer(60.0).timeout.connect(func():
				if is_instance_valid(player):
					player.move_speed /= 0.85
					player.damage_multiplier /= 1.4
			)
		"altar_purify":
			if not player.curse_ids.is_empty():
				player.curse_ids.pop_back()
		"time_accel":
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and e.data:
					e.data.move_speed *= 1.5
			player.exp_multiplier *= 2.0
			get_tree().create_timer(30.0).timeout.connect(func():
				if is_instance_valid(player): player.exp_multiplier /= 2.0
				for e in get_tree().get_nodes_in_group("enemies"):
					if is_instance_valid(e) and e.data:
						e.data.move_speed /= 1.5
			)
		"time_slow":
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and e.data:
					e.data.move_speed *= 0.4
			get_tree().create_timer(8.0).timeout.connect(func():
				for e in get_tree().get_nodes_in_group("enemies"):
					if is_instance_valid(e) and e.data:
						e.data.move_speed /= 0.4
			)
		"merchant_deal":
			if player.gold >= 100:
				player.gold -= 100
				var main = get_tree().current_scene
				if main.has_method("_drop_relic_at"):
					main._drop_relic_at(player.global_position + Vector2(60, 0))
		"merchant_rob":
			player.current_hp = max(player.current_hp - player.max_hp * 0.25, 1)
			EventBus.emit_signal("player_hp_changed", player.current_hp, player.max_hp)
			var main = get_tree().current_scene
			if main.has_method("_drop_relic_at"):
				main._drop_relic_at(player.global_position + Vector2(60, 0))
		"mutate_fast":
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and e.data:
					e.data.move_speed *= 1.8
			player.exp_multiplier *= 3.0
			get_tree().create_timer(30.0).timeout.connect(func():
				if is_instance_valid(player): player.exp_multiplier /= 3.0
				for e in get_tree().get_nodes_in_group("enemies"):
					if is_instance_valid(e) and e.data:
						e.data.move_speed /= 1.8
			)
		"mutate_tank":
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and e.data:
					e.data.move_speed *= 0.5
					e.data.max_hp *= 2.0
			get_tree().create_timer(30.0).timeout.connect(func():
				for e in get_tree().get_nodes_in_group("enemies"):
					if is_instance_valid(e) and e.data:
						e.data.move_speed /= 0.5
						e.data.max_hp /= 2.0
			)
		"shadow_merge":
			player.attack_speed_multiplier *= 1.5
			get_tree().create_timer(45.0).timeout.connect(func():
				if is_instance_valid(player): player.attack_speed_multiplier /= 1.5
			)
		"shadow_fight":
			player.crit_chance += 0.30
			player.set_meta("shadow_fight_dmg_taken_mult", 1.5)
			get_tree().create_timer(30.0).timeout.connect(func():
				if is_instance_valid(player):
					player.crit_chance -= 0.30
					player.remove_meta("shadow_fight_dmg_taken_mult")
			)
		"fountain_drink":
			player.current_hp = player.max_hp
			EventBus.emit_signal("player_hp_changed", player.current_hp, player.max_hp)
			var orig_regen = player.regen_per_second
			player.regen_per_second += player.max_hp * 0.05
			get_tree().create_timer(10.0).timeout.connect(func():
				if is_instance_valid(player):
					player.regen_per_second = orig_regen
			)
		"fountain_sacrifice":
			player.current_hp = max(player.current_hp - player.max_hp * 0.5, 1)
			EventBus.emit_signal("player_hp_changed", player.current_hp, player.max_hp)
			player.damage_multiplier *= 1.15
		"gamble_dice":
			if randf() < 0.5:
				var main = get_tree().current_scene
				if main.has_method("_drop_relic_at"):
					for i in range(3):
						var offset = Vector2(randf_range(-80, 80), randf_range(-80, 80))
						main._drop_relic_at(player.global_position + offset)
			else:
				player.current_hp = max(player.current_hp - player.max_hp * 0.3, 1)
				EventBus.emit_signal("player_hp_changed", player.current_hp, player.max_hp)
		"gamble_safe":
			var main = get_tree().current_scene
			if main.has_method("_drop_relic_at"):
				main._drop_relic_at(player.global_position + Vector2(60, 0))
		"nothing":
			pass
	_close()

func _trigger_minor_event() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player): return
	var event_type = _minor_index % 4
	_minor_index += 1
	var main = get_tree().current_scene
	match event_type:
		0:
			_show_banner("⚠ 新的威胁出现了！", Color(1.0, 0.5, 0.1))
		1:
			if main.has_method("_drop_relic_at"):
				main._drop_relic_at(player.global_position + Vector2(randf_range(-100, 100), randf_range(-100, 100)))
				_show_banner("🎁 遗物出现了！", Color(1.0, 0.9, 0.1))
		2:
			var wm = main.get("wave_manager") if main else null
			if wm:
				var count = clamp(2 + (wm.wave_cycle if "wave_cycle" in wm else 0), 2, 4)
				for _i in range(count):
					wm.call_deferred("_spawn_elite")
				_show_banner("💀 精英军团来袭！", Color(1.0, 0.3, 0.3))
		3:
			for _i in range(3):
				var bubble = Area2D.new()
				var script = load("res://scripts/systems/HealBubble.gd") if ResourceLoader.exists("res://scripts/systems/HealBubble.gd") else null
				if not script: break
				bubble.set_script(script)
				main.add_child(bubble)
				bubble.global_position = player.global_position + Vector2(randf_range(-150, 150), randf_range(-150, 150))
				bubble.setup(player.max_hp * 0.1)
			_show_banner("💚 治疗气泡出现了！", Color(0.3, 1.0, 0.3))

func _show_banner(text: String, color: Color) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	var target = hud if hud else get_tree().current_scene
	if not target: return
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", color)
	lbl.anchor_left = 0.5; lbl.anchor_right = 0.5
	lbl.anchor_top = 0.2; lbl.anchor_bottom = 0.2
	lbl.offset_left = -150; lbl.offset_right = 150
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target.add_child(lbl)
	var tw = lbl.create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(lbl.queue_free)

func _close() -> void:
	if is_instance_valid(_panel):
		var card = null
		for child in _panel.get_children():
			if child is PanelContainer:
				card = child
				break
		if card:
			var tw = card.create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(card, "position:x", card.position.x + 360, 0.25)
			tw.parallel().tween_property(card, "modulate:a", 0.0, 0.2)
			tw.tween_callback(func():
				if is_instance_valid(_panel): _panel.queue_free()
				_panel = null
			)
		else:
			_panel.queue_free()
			_panel = null
	else:
		_panel = null
