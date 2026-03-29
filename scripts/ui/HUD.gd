# HUD.gd
# 游戏内UI - 所有节点引用由 Main.gd 程序化创建后注入
extends CanvasLayer

var game_manager: Node = null

# 节点引用（由外部注入，不用 @onready）
var hp_bar: ProgressBar
var hp_label: Label
var exp_bar: ProgressBar
var level_label: Label
var timer_label: Label
var wave_label: Label
var level_up_panel: Control
var choice_buttons: HBoxContainer

# 美化新增引用
var difficulty_badge: Label = null

func _ready() -> void:
	EventBus.player_damaged.connect(_on_hp_changed)
	EventBus.player_exp_changed.connect(_on_exp_changed)
	EventBus.player_leveled_up.connect(_on_level_up)
	EventBus.wave_changed.connect(_on_wave_changed)
	EventBus.show_level_up_panel.connect(_show_upgrade_panel)
	EventBus.game_over.connect(_on_game_over)
	if EventBus.has_signal("player_won"):
		EventBus.player_won.connect(_on_victory)

func _process(_delta: float) -> void:
	if game_manager and timer_label:
		var t = int(game_manager.game_time)
		timer_label.text = "%02d:%02d" % [t / 60, t % 60]

	# 更新波次标签（处理无尽模式）
	if wave_label and game_manager:
		var wm = game_manager.get("wave_manager")
		if wm:
			var total_waves = wm.wave_configs.size()
			if wm.is_endless:
				wave_label.text = "Wave %d / ∞" % wm.current_wave
			else:
				wave_label.text = "Wave %d / %d" % [wm.current_wave, total_waves]

	# 更新难度徽章颜色（仅首次设置后不需每帧，但轻量级）
	_update_difficulty_badge()

func _update_difficulty_badge() -> void:
	if not difficulty_badge or not game_manager:
		return
	var diff = game_manager.get("current_difficulty")
	if diff == null:
		return
	# DifficultyData 是 Resource，.id 是普通属性
	var diff_id: String = str(diff.get("id")) if diff.get("id") != null else ""
	match diff_id:
		"normal":
			difficulty_badge.text = "🟢 普通"
			difficulty_badge.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		"hard":
			difficulty_badge.text = "🟠 困难"
			difficulty_badge.add_theme_color_override("font_color", Color(1.0, 0.6, 0.1))
		"abyss":
			difficulty_badge.text = "🔴 深渊"
			difficulty_badge.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		_:
			if diff_id != "" and diff_id != "null":
				difficulty_badge.text = "⚙ " + diff_id
				difficulty_badge.add_theme_color_override("font_color", Color.WHITE)

func _on_hp_changed(current: float, maximum: float) -> void:
	if hp_bar:
		hp_bar.max_value = maximum
		hp_bar.value = current
	if hp_label:
		hp_label.text = "%d / %d" % [int(current), int(maximum)]

func _on_exp_changed(current: int, required: int) -> void:
	if exp_bar:
		exp_bar.max_value = required
		exp_bar.value = current

func _on_level_up(new_level: int) -> void:
	if level_label:
		level_label.text = "Lv." + str(new_level)

func _on_wave_changed(wave: int) -> void:
	# 波次标签将在 _process 每帧更新以处理无尽模式
	if wave_label and game_manager:
		var wm = game_manager.get("wave_manager")
		if wm:
			var total_waves = wm.wave_configs.size()
			if wm.is_endless:
				wave_label.text = "Wave %d / ∞" % wave
			else:
				wave_label.text = "Wave %d / %d" % [wave, total_waves]
		else:
			wave_label.text = "Wave %d" % wave

var _pending_choices: Array = []

func _show_upgrade_panel(choices: Array) -> void:
	if not level_up_panel or not choice_buttons:
		return
	_pending_choices = choices
	level_up_panel.visible = true
	get_tree().paused = true   # 双保险：HUD 这里也暂停，不依赖 Main.gd 的信号顺序
	# 升级音效
	var snd = get_tree().get_first_node_in_group("sound_manager")
	if snd:
		snd.play_level_up()
	# 清除旧按钮（立即清除，不await，暂停时await会卡死）
	for child in choice_buttons.get_children():
		child.free()
	# 生成新选项按钮
	for i in range(choices.size()):
		var choice = choices[i]
		var btn = Button.new()
		btn.text = "[%d] %s\n%s" % [i+1, choice["display_name"], choice.get("description", "")]
		btn.custom_minimum_size = Vector2(240, 120)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_on_choice_selected.bind(choice))
		# 样式：深色背景 + 蓝色边框
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.08, 0.08, 0.25)
		btn_style.border_width_left = 1; btn_style.border_width_right = 1
		btn_style.border_width_top = 1; btn_style.border_width_bottom = 1
		btn_style.border_color = Color(0.4, 0.6, 1.0)
		btn_style.corner_radius_top_left = 4; btn_style.corner_radius_top_right = 4
		btn_style.corner_radius_bottom_left = 4; btn_style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", btn_style)
		var hover_style = btn_style.duplicate()
		hover_style.bg_color = Color(0.15, 0.15, 0.4)
		hover_style.border_color = Color(0.6, 0.8, 1.0)
		btn.add_theme_stylebox_override("hover", hover_style)
		choice_buttons.add_child(btn)

func _input(event: InputEvent) -> void:
	if not level_up_panel or not level_up_panel.visible:
		return
	# 数字键 1/2/3 快捷选择
	for i in range(1, 4):
		if event is InputEventKey and event.pressed and event.keycode == (KEY_0 + i):
			if i - 1 < _pending_choices.size():
				_on_choice_selected(_pending_choices[i - 1])
				get_viewport().set_input_as_handled()

func _on_choice_selected(choice: Dictionary) -> void:
	if level_up_panel:
		level_up_panel.visible = false
	EventBus.game_logic_paused = false
	get_tree().paused = false
	EventBus.emit_signal("upgrade_chosen", choice)

func _on_game_over(survived_time: float, score: int) -> void:
	_show_end_screen(false, survived_time, score)

func _on_victory(survived_time: float, score: int) -> void:
	_show_end_screen(true, survived_time, score)

func _show_end_screen(is_victory: bool, survived_time: float, score: int) -> void:
	# 全屏遮罩
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# 标题
	var title = Label.new()
	title.text = "🏆 Victory!" if is_victory else "💀 Game Over"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1) if is_victory else Color(1.0, 0.3, 0.3))
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position.y = -80
	overlay.add_child(title)

	# 统计
	var t = int(survived_time)
	var stats = Label.new()
	stats.text = "存活时间：%02d:%02d    得分：%d" % [t / 60, t % 60, score]
	stats.add_theme_font_size_override("font_size", 28)
	stats.add_theme_color_override("font_color", Color.WHITE)
	stats.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.add_child(stats)

	# 重启提示
	var hint = Label.new()
	hint.text = "按 R 重新开始"
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.position.y = 80
	overlay.add_child(hint)


func _on_hp_changed(current: float, maximum: float) -> void:
	if hp_bar:
		hp_bar.max_value = maximum
		hp_bar.value = current
	if hp_label:
		hp_label.text = "%d / %d" % [int(current), int(maximum)]

func _on_exp_changed(current: int, required: int) -> void:
	if exp_bar:
		exp_bar.max_value = required
		exp_bar.value = current

func _on_level_up(new_level: int) -> void:
	if level_label:
		level_label.text = "Lv." + str(new_level)

func _on_wave_changed(wave: int) -> void:
	if wave_label:
		wave_label.text = "第 %d 波" % wave

var _pending_choices: Array = []

func _show_upgrade_panel(choices: Array) -> void:
	if not level_up_panel or not choice_buttons:
		return
	_pending_choices = choices
	level_up_panel.visible = true
	get_tree().paused = true   # 双保险：HUD 这里也暂停，不依赖 Main.gd 的信号顺序
	# 升级音效
	var snd = get_tree().get_first_node_in_group("sound_manager")
	if snd:
		snd.play_level_up()
	# 清除旧按钮（立即清除，不await，暂停时await会卡死）
	for child in choice_buttons.get_children():
		child.free()
	# 生成新选项按钮
	for i in range(choices.size()):
		var choice = choices[i]
		var btn = Button.new()
		btn.text = "[%d] %s\n%s" % [i+1, choice["display_name"], choice.get("description", "")]
		btn.custom_minimum_size = Vector2(240, 120)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_on_choice_selected.bind(choice))
		# 样式：深色背景 + 蓝色边框
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.08, 0.08, 0.25)
		btn_style.border_width_left = 1; btn_style.border_width_right = 1
		btn_style.border_width_top = 1; btn_style.border_width_bottom = 1
		btn_style.border_color = Color(0.4, 0.6, 1.0)
		btn_style.corner_radius_top_left = 4; btn_style.corner_radius_top_right = 4
		btn_style.corner_radius_bottom_left = 4; btn_style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", btn_style)
		var hover_style = btn_style.duplicate()
		hover_style.bg_color = Color(0.15, 0.15, 0.4)
		hover_style.border_color = Color(0.6, 0.8, 1.0)
		btn.add_theme_stylebox_override("hover", hover_style)
		choice_buttons.add_child(btn)

func _input(event: InputEvent) -> void:
	if not level_up_panel or not level_up_panel.visible:
		return
	# 数字键 1/2/3 快捷选择
	for i in range(1, 4):
		if event is InputEventKey and event.pressed and event.keycode == (KEY_0 + i):
			if i - 1 < _pending_choices.size():
				_on_choice_selected(_pending_choices[i - 1])
				get_viewport().set_input_as_handled()

func _on_choice_selected(choice: Dictionary) -> void:
	if level_up_panel:
		level_up_panel.visible = false
	EventBus.game_logic_paused = false
	get_tree().paused = false
	EventBus.emit_signal("upgrade_chosen", choice)

func _on_game_over(survived_time: float, score: int) -> void:
	_show_end_screen(false, survived_time, score)

func _on_victory(survived_time: float, score: int) -> void:
	_show_end_screen(true, survived_time, score)

func _show_end_screen(is_victory: bool, survived_time: float, score: int) -> void:
	# 全屏遮罩
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# 标题
	var title = Label.new()
	title.text = "🏆 Victory!" if is_victory else "💀 Game Over"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1) if is_victory else Color(1.0, 0.3, 0.3))
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position.y = -80
	overlay.add_child(title)

	# 统计
	var t = int(survived_time)
	var stats = Label.new()
	stats.text = "存活时间：%02d:%02d    得分：%d" % [t / 60, t % 60, score]
	stats.add_theme_font_size_override("font_size", 28)
	stats.add_theme_color_override("font_color", Color.WHITE)
	stats.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.add_child(stats)

	# 重启提示
	var hint = Label.new()
	hint.text = "按 R 重新开始"
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.position.y = 80
	overlay.add_child(hint)
