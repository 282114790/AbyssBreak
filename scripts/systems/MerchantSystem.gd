# MerchantSystem.gd
# 商人系统（#25）— 每5波出现，用魂石购买遗物/回血/技能升级
extends Node

signal merchant_closed

const APPEAR_EVERY_WAVES := 5  # 每N波出现一次
var _last_wave := 0
var _panel: CanvasLayer = null

func _ready() -> void:
	EventBus.wave_changed.connect(_on_wave_changed)

func _on_wave_changed(wave: int) -> void:
	if wave <= 1: return
	if wave - _last_wave >= APPEAR_EVERY_WAVES and wave % APPEAR_EVERY_WAVES == 0:
		_last_wave = wave
		# 延迟2秒弹出，让波次开始特效播完
		get_tree().create_timer(2.0).timeout.connect(_show_merchant)

func _show_merchant() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var meta = get_tree().root.find_child("MetaProgress", true, false)
	if not is_instance_valid(player) or not meta: return

	# 暂停游戏逻辑（不暂停场景树，让UI仍可交互）
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

	var soul_lbl = Label.new()
	soul_lbl.text = "💎 当前魂石：%d" % meta.soul_stones
	soul_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	soul_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	vbox.add_child(soul_lbl)

	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color(1,1,1,0.2))
	vbox.add_child(sep)

	# 商品列表
	var items = [
		{"name": "💊 满血回复",       "cost": 8,  "action": "heal_full"},
		{"name": "⬆ 随机技能升级",    "cost": 12, "action": "skill_up"},
		{"name": "💎 随机遗物",        "cost": 20, "action": "relic"},
		{"name": "🛡 护盾+20%最大血量", "cost": 15, "action": "shield"},
	]
	for item in items:
		var row = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = item["name"]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var cost_lbl = Label.new()
		cost_lbl.text = "💎%d" % item["cost"]
		cost_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
		row.add_child(cost_lbl)
		var btn = Button.new()
		btn.text = "购买"
		btn.custom_minimum_size = Vector2(72, 32)
		var c = item["cost"]; var a = item["action"]
		btn.pressed.connect(func(): _buy(player, meta, a, c, soul_lbl))
		if meta.soul_stones < item["cost"]:
			btn.disabled = true
		row.add_child(btn)
		vbox.add_child(row)

	var close_btn = Button.new()
	close_btn.text = "离开"
	close_btn.custom_minimum_size = Vector2(160, 40)
	close_btn.pressed.connect(_close_merchant)
	vbox.add_child(close_btn)

func _buy(player: Node, meta: Node, action: String, cost: int, soul_lbl: Label) -> void:
	if meta.soul_stones < cost: return
	meta.soul_stones -= cost
	soul_lbl.text = "💎 当前魂石：%d" % meta.soul_stones
	match action:
		"heal_full":
			player.current_hp = player.max_hp
			EventBus.emit_signal("player_hp_changed", player.current_hp, player.max_hp)
		"skill_up":
			if not player.skills.is_empty():
				var sk = player.skills[randi() % player.skills.size()]
				sk.level_up()
		"relic":
			var owned = player.get("relic_ids") if player.get("relic_ids") != null else []
			var choices = RelicRegistry.get_random_choices(1, owned)
			if not choices.is_empty():
				choices[0].apply_to_player(player)
		"shield":
			player.max_hp = int(player.max_hp * 1.2)
			player.current_hp = min(player.current_hp + int(player.max_hp * 0.2), player.max_hp)
			EventBus.emit_signal("player_hp_changed", player.current_hp, player.max_hp)

func _close_merchant() -> void:
	if is_instance_valid(_panel): _panel.queue_free()
	_panel = null
	EventBus.game_logic_paused = false
	emit_signal("merchant_closed")
