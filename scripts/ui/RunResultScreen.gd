# RunResultScreen.gd
# 游戏结算界面 - 死亡/通关后展示数据 + 魂石奖励
extends CanvasLayer

signal continue_pressed   # 返回主界面/重新开始

var _meta: Node = null

func _ready() -> void:
	layer = 10
	visible = false

func show_result(wave: int, score: int, survive_sec: float, kills: int, won: bool) -> void:
	_meta = get_tree().root.find_child("MetaProgress", true, false)
	if _meta == null:
		push_error("MetaProgress not found")
		return
	var earned = _meta.on_run_ended(wave, score, survive_sec, kills)
	visible = true
	# 收集 player 的 Build 数据（#20）
	var player = get_tree().get_first_node_in_group("player")
	var build_skills: Array = []
	var build_relics: Array = []
	var build_curses: Array = []
	if is_instance_valid(player):
		for s in player.skills:
			if s.data: build_skills.append({"name": s.data.display_name, "level": s.level})
		for rid in player.relic_ids if "relic_ids" in player else []:
			var rd = RelicRegistry.get_relic(rid)
			build_relics.append(rd.display_name if rd else rid)
		build_curses = player.curse_ids if "curse_ids" in player else []
	_build_ui(wave, score, survive_sec, kills, won, earned, build_skills, build_relics, build_curses)

func _build_ui(wave: int, score: int, survive_sec: float, kills: int, won: bool, earned: int, build_skills: Array = [], build_relics: Array = [], build_curses: Array = []) -> void:
	# 清理旧节点
	for c in get_children():
		c.queue_free()

	# 半透明黑色遮罩
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.82)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# 主面板
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(480, 520)
	panel.position = Vector2(-240, -260)
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	# 标题
	var title_lbl = Label.new()
	title_lbl.text = "✨ 深渊突破！" if won else "💀 深渊吞噬了你"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3) if won else Color(0.9, 0.3, 0.3))
	vbox.add_child(title_lbl)

	# 分割线
	vbox.add_child(_make_separator())

	# 数据行
	var mins := int(survive_sec) / 60
	var secs := int(survive_sec) % 60
	_add_stat_row(vbox, "🌊 到达波次",  "第 %d 波" % wave)
	_add_stat_row(vbox, "⏱ 存活时长",  "%02d:%02d" % [mins, secs])
	_add_stat_row(vbox, "💀 击杀数",    "%d" % kills)
	_add_stat_row(vbox, "⭐ 得分",      "%d" % score)

	vbox.add_child(_make_separator())

	# 魂石奖励
	var soul_row = _add_stat_row(vbox, "💎 获得魂石", "+ %d" % earned, Color(0.5, 0.8, 1.0))
	var total_lbl = Label.new()
	total_lbl.text = "当前魂石总量：%d" % _meta.soul_stones
	total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	vbox.add_child(total_lbl)

	vbox.add_child(_make_separator())

	# 历史最佳
	_add_stat_row(vbox, "🏆 历史最高波次", "第 %d 波" % _meta.best_wave, Color(0.9, 0.75, 0.2))
	_add_stat_row(vbox, "🏅 历史最高分",   "%d" % _meta.best_score,     Color(0.9, 0.75, 0.2))

	# #20 本局 Build 展示
	if not build_skills.is_empty() or not build_relics.is_empty():
		vbox.add_child(_make_separator())
		var build_lbl = Label.new()
		build_lbl.text = "📋 本局 Build"
		build_lbl.add_theme_font_size_override("font_size", 13)
		build_lbl.add_theme_color_override("font_color", Color(0.7, 0.95, 1.0))
		vbox.add_child(build_lbl)
		for sk in build_skills:
			var r = Label.new()
			r.text = "  ⚔ %s  Lv%d" % [sk["name"], sk["level"]]
			r.add_theme_font_size_override("font_size", 11)
			vbox.add_child(r)
		for rn in build_relics:
			var r = Label.new()
			r.text = "  💎 %s" % rn
			r.add_theme_font_size_override("font_size", 11)
			r.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
			vbox.add_child(r)
		for cn in build_curses:
			var r = Label.new()
			r.text = "  ☠ %s" % cn
			r.add_theme_font_size_override("font_size", 11)
			r.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
			vbox.add_child(r)

	vbox.add_child(_make_separator())

	# 按钮区
	var btn_box = HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_box)

	var btn_upgrade = Button.new()
	btn_upgrade.text = "💎 解锁强化"
	btn_upgrade.custom_minimum_size = Vector2(160, 44)
	btn_upgrade.pressed.connect(_on_upgrade_pressed)
	btn_box.add_child(btn_upgrade)

	var btn_restart = Button.new()
	btn_restart.text = "🔄 再来一局"
	btn_restart.custom_minimum_size = Vector2(160, 44)
	btn_restart.pressed.connect(_on_restart_pressed)
	btn_box.add_child(btn_restart)

func _add_stat_row(parent: Control, label: String, value: String, val_color: Color = Color.WHITE) -> HBoxContainer:
	var row = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val = Label.new()
	val.text = value
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_color_override("font_color", val_color)
	row.add_child(lbl)
	row.add_child(val)
	parent.add_child(row)
	return row

func _make_separator() -> HSeparator:
	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color(1, 1, 1, 0.15))
	return sep

func _on_upgrade_pressed() -> void:
	# 打开局外解锁界面
	var upgrade_screen = get_tree().root.find_child("UnlockScreen", true, false)
	if upgrade_screen:
		upgrade_screen.show_screen()

func _on_restart_pressed() -> void:
	visible = false
	emit_signal("continue_pressed")
	get_tree().reload_current_scene()
