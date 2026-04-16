# TutorialSystem.gd
# 新手引导（#29）— 第一局强制引导流程
# 步骤：移动 → 升级选技能 → 施放主动技能 → 击败精英
extends Node

enum Step { MOVE, SKILL_UP, CAST_ACTIVE, KILL_ELITE, DONE }
var step: Step = Step.MOVE
var _overlay: CanvasLayer = null
var _hint_lbl: Label = null

var _move_steps := 0
var _move_required := 30

func _ready() -> void:
	var meta = get_tree().root.find_child("MetaProgress", true, false)
	if meta and meta.total_runs > 0:
		queue_free()
		return
	_setup_hint_ui()
	EventBus.player_leveled_up.connect(_on_level_up)
	EventBus.enemy_died.connect(_on_enemy_died)

func _setup_hint_ui() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 20
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(_overlay)

	# 底部提示横幅
	_hint_lbl = Label.new()
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_lbl.add_theme_font_size_override("font_size", 18)
	_hint_lbl.add_theme_color_override("font_color", Color(1, 1, 0.7))
	_hint_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_lbl.offset_top = -70; _hint_lbl.offset_bottom = -10
	_hint_lbl.offset_left = 20; _hint_lbl.offset_right = -20

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bg.offset_top = -75; bg.offset_bottom = -5
	bg.offset_left = 5; bg.offset_right = -5
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(bg)
	_overlay.add_child(_hint_lbl)
	_update_hint()

func _process(_delta: float) -> void:
	if step == Step.DONE: return
	if step == Step.MOVE:
		var player = get_tree().get_first_node_in_group("player")
		if is_instance_valid(player) and player.velocity.length() > 10.0:
			_move_steps += 1
			if _move_steps >= _move_required:
				_advance(Step.SKILL_UP)
	if step == Step.CAST_ACTIVE:
		# 检测Q/E是否被按下
		if Input.is_action_just_pressed("skill_q") or Input.is_action_just_pressed("skill_e"):
			_advance(Step.KILL_ELITE)

func _on_level_up() -> void:
	if step == Step.SKILL_UP:
		_advance(Step.CAST_ACTIVE)

func _on_enemy_died(_pos, _exp) -> void:
	if step == Step.KILL_ELITE:
		# 检测是否有精英被击杀（简化：直接推进）
		_advance(Step.DONE)

func _advance(next: Step) -> void:
	step = next
	_update_hint()
	if step == Step.DONE:
		get_tree().create_timer(2.5).timeout.connect(func():
			if is_instance_valid(_overlay): _overlay.queue_free()
			queue_free()
		)

func _update_hint() -> void:
	if not is_instance_valid(_hint_lbl): return
	match step:
		Step.MOVE:
			_hint_lbl.text = "🎮 新手引导（1/4）：用 WASD 移动角色"
		Step.SKILL_UP:
			_hint_lbl.text = "⬆ 新手引导（2/4）：等待升级 → 从弹出选项中选一个技能"
		Step.CAST_ACTIVE:
			_hint_lbl.text = "⚡ 新手引导（3/4）：按 Q 或 E 释放主动技能！"
		Step.KILL_ELITE:
			_hint_lbl.text = "💀 新手引导（4/4）：击败一个精英敌人（橙色描边）！"
		Step.DONE:
			_hint_lbl.text = "✅ 引导完成！享受冒险吧！"
