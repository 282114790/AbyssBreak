# MerchantSystem.gd
# 商人系统（#25）— 每5波出现，用局内金币购买遗物/回血/技能升级
extends Node

signal merchant_closed

const APPEAR_EVERY_WAVES := 5
var _last_wave := 0
var _panel: CanvasLayer = null

func _ready() -> void:
	EventBus.wave_changed.connect(_on_wave_changed)

func _on_wave_changed(wave: int) -> void:
	if wave <= 1: return
	if wave - _last_wave >= APPEAR_EVERY_WAVES and wave % APPEAR_EVERY_WAVES == 0:
		_last_wave = wave
		get_tree().create_timer(2.0).timeout.connect(_show_merchant)

func _show_merchant() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player): return

	EventBus.game_logic_paused = true

	_panel = CanvasLayer.new()
	_panel.layer = 12
	get_tree().current_scene.add_child(_panel)

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(overlay)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(460, 380)
	vbox.position = Vector2(-230, -190)
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	var title = Label.new()
	title.text = "🧙 神秘商人出现了！"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)

	var gold_lbl = Label.new()
	gold_lbl.name = "GoldLabel"
	gold_lbl.text = "🪙 金币：%d" % player.gold
	gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(gold_lbl)

	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color(1,1,1,0.2))
	vbox.add_child(sep)

	var items = [
		{"name": "💊 满血回复",        "cost": 30, "action": "heal_full"},
		{"name": "⬆ 随机技能升级",     "cost": 50, "action": "skill_up"},
		{"name": "💎 随机遗物",         "cost": 80, "action": "relic"},
		{"name": "🛡 护盾+20%最大血量", "cost": 60, "action": "shield"},
		{"name": "💣 炸弹×2",          "cost": 40, "action": "buy_bomb"},
		{"name": "🧊 冻结卷轴×1",      "cost": 55, "action": "buy_freeze"},
		{"name": "🌀 传送卷轴×2",      "cost": 35, "action": "buy_teleport"},
		{"name": "💚 大回复药水×1",     "cost": 45, "action": "buy_mega_heal"},
	]
	for item in items:
		var row = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = item["name"]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var cost_lbl = Label.new()
		cost_lbl.text = "🪙%d" % item["cost"]
		cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		row.add_child(cost_lbl)
		var btn = Button.new()
		btn.text = "购买"
		btn.custom_minimum_size = Vector2(72, 32)
		var c = item["cost"]; var a = item["action"]
		btn.pressed.connect(func(): _buy(player, a, c, gold_lbl))
		if player.gold < item["cost"]:
			btn.disabled = true
		row.add_child(btn)
		vbox.add_child(row)

	var close_btn = Button.new()
	close_btn.text = "离开"
	close_btn.custom_minimum_size = Vector2(160, 40)
	close_btn.pressed.connect(_close_merchant)
	vbox.add_child(close_btn)

func _buy(player: Node, action: String, cost: int, gold_lbl: Label) -> void:
	if player.gold < cost: return
	player.gold -= cost
	gold_lbl.text = "🪙 金币：%d" % player.gold
	match action:
		"heal_full":
			player.current_hp = player.max_hp
			EventBus.emit_signal("player_damaged", player.current_hp, player.max_hp)
		"skill_up":
			if not player.skills.is_empty():
				var sk = player.skills[randi() % player.skills.size()]
				sk.level_up()
		"relic":
			var owned = player.get("relic_ids") if player.get("relic_ids") != null else []
			var choices = RelicRegistry.get_random_choices(1, owned)
			if not choices.is_empty():
				choices[0].apply_to_player(player)
				if "relic_ids" in player:
					player.relic_ids.append(choices[0].id)
				EventBus.emit_signal("relic_collected", choices[0].id)
		"shield":
			player.max_hp = int(player.max_hp * 1.2)
			player.current_hp = min(player.current_hp + int(player.max_hp * 0.2), player.max_hp)
			EventBus.emit_signal("player_damaged", player.current_hp, player.max_hp)
		"buy_bomb":
			if player.has_method("add_consumable"):
				player.add_consumable("bomb", "炸弹")
				player.add_consumable("bomb", "炸弹")
		"buy_freeze":
			if player.has_method("add_consumable"):
				player.add_consumable("freeze", "冻结")
		"buy_teleport":
			if player.has_method("add_consumable"):
				player.add_consumable("teleport", "传送")
				player.add_consumable("teleport", "传送")
		"buy_mega_heal":
			if player.has_method("add_consumable"):
				player.add_consumable("mega_heal", "大回复")

func _close_merchant() -> void:
	if is_instance_valid(_panel): _panel.queue_free()
	_panel = null
	EventBus.game_logic_paused = false
	emit_signal("merchant_closed")
