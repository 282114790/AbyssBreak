# RandomEventSystem.gd
# 随机事件系统（#26）— 每隔一段时间触发文字事件（收益/风险二选一）
extends Node

const INTERVAL_SEC := 90.0  # 每90秒触发一次

var _timer := 0.0
var _panel: CanvasLayer = null

const EVENTS := [
	{
		"title": "🌑 深渊裂缝",
		"desc": "一道裂缝出现在脚下，选择你的应对方式。",
		"optA": {"text": "✨ 跳入裂缝（获得随机遗物）", "risk": false, "action": "relic"},
		"optB": {"text": "⚡ 引爆裂缝（造成AOE伤害，但损失15%血量）", "risk": true,  "action": "aoe_damage"}
	},
	{
		"title": "🩸 血之契约",
		"desc": "一个声音低语……以血换力。",
		"optA": {"text": "✅ 接受（HP-30%，伤害+25%，持续30秒）", "risk": true,  "action": "blood_pact"},
		"optB": {"text": "❌ 拒绝（无事发生）", "risk": false, "action": "nothing"}
	},
	{
		"title": "🔮 魔法涌流",
		"desc": "空气中充满了不稳定的魔力。",
		"optA": {"text": "🌀 吸收魔力（随机一个技能CD永久减少0.5s）", "risk": false, "action": "cd_reduce"},
		"optB": {"text": "💥 引爆魔力（清屏伤害，但1格CD变为10秒）", "risk": true,  "action": "overload"}
	},
	{
		"title": "👻 迷途灵魂",
		"desc": "一个迷失的灵魂向你靠近。",
		"optA": {"text": "🌟 引导它（获得经验值等同当前波次×20）", "risk": false, "action": "exp_bonus"},
		"optB": {"text": "💀 吸收它（最大血量+20%，但下一分钟不能回血）", "risk": true,  "action": "soul_absorb"}
	},
]

func _process(delta: float) -> void:
	if EventBus.game_logic_paused: return
	if is_instance_valid(_panel): return
	_timer += delta
	if _timer >= INTERVAL_SEC:
		_timer = 0.0
		_trigger_event()

func _trigger_event() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player): return
	var ev = EVENTS[randi() % EVENTS.size()]
	EventBus.game_logic_paused = true
	_show_event(ev, player)

func _show_event(ev: Dictionary, player: Node) -> void:
	_panel = CanvasLayer.new()
	_panel.layer = 13
	get_tree().current_scene.add_child(_panel)

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(overlay)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(440, 260)
	vbox.position = Vector2(-220, -130)
	vbox.add_theme_constant_override("separation", 14)
	_panel.add_child(vbox)

	var title = Label.new()
	title.text = ev["title"]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = ev["desc"]
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	for opt_key in ["optA", "optB"]:
		var opt = ev[opt_key]
		var btn = Button.new()
		btn.text = opt["text"]
		btn.custom_minimum_size = Vector2(380, 44)
		btn.pressed.connect(func(): _choose(opt["action"], player))
		vbox.add_child(btn)

func _choose(action: String, player: Node) -> void:
	match action:
		"relic":
			var main = get_tree().current_scene
			if main.has_method("_drop_relic_at"):
				main._drop_relic_at(player.global_position + Vector2(60, 0))
		"aoe_damage":
			player.hp = max(player.hp - player.max_hp * 0.15, 1)
			EventBus.emit_signal("player_hp_changed", player.hp, player.max_hp)
			for e in get_tree().get_nodes_in_group("enemies"):
				if player.global_position.distance_to(e.global_position) < 300:
					e.take_damage(player.max_hp * 0.5, false)
		"blood_pact":
			player.hp = max(player.hp - player.max_hp * 0.3, 1)
			player.damage_multiplier *= 1.25
			get_tree().create_timer(30.0).timeout.connect(func(): player.damage_multiplier /= 1.25)
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
			EventBus.emit_signal("enemy_died", player.global_position, wave * 20)
		"soul_absorb":
			player.max_hp = int(player.max_hp * 1.2)
			player.hp = min(player.hp + int(player.max_hp * 0.1), player.max_hp)
		"nothing":
			pass
	_close()

func _close() -> void:
	if is_instance_valid(_panel): _panel.queue_free()
	_panel = null
	EventBus.game_logic_paused = false
