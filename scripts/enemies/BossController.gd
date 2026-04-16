# BossController.gd
# Boss 三阶段控制 + 主动技能（AOE、召唤、冲刺）
extends Node

enum Phase { NORMAL, BERSERK, DYING }
var phase: Phase = Phase.NORMAL

var _boss: Node = null
var _boss_max_hp: float = 1.0
var _skill_timer: float = 0.0
var _skill_interval: float = 4.0

func _ready() -> void:
	_boss = get_parent()
	await get_tree().process_frame
	if is_instance_valid(_boss):
		_boss_max_hp = max(_boss.hp, 1.0)

func _process(delta: float) -> void:
	if not is_instance_valid(_boss) or _boss.is_dead: return
	if EventBus.game_logic_paused: return
	var hp_ratio = float(_boss.hp) / _boss_max_hp
	match phase:
		Phase.NORMAL:
			if hp_ratio <= 0.66:
				_enter_berserk()
		Phase.BERSERK:
			if hp_ratio <= 0.33:
				_enter_dying()
	_skill_timer -= delta
	if _skill_timer <= 0:
		_skill_timer = _skill_interval
		_use_skill()

func _use_skill() -> void:
	var roll = randi() % 3
	match roll:
		0: _skill_ground_aoe()
		1: _skill_summon_minions()
		2: _skill_dash_attack()

func _skill_ground_aoe() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player): return
	var target_pos = player.global_position
	# Warning indicator
	var warning = ColorRect.new()
	var radius = 100.0 + 20.0 * (2 - int(phase))
	warning.size = Vector2(radius * 2, radius * 2)
	warning.position = target_pos - Vector2(radius, radius)
	warning.color = Color(1.0, 0.2, 0.1, 0.25)
	warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning.z_index = -5
	get_tree().current_scene.add_child(warning)
	# Blink then deal damage
	var tw = warning.create_tween()
	tw.tween_property(warning, "color:a", 0.5, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(warning, "color:a", 0.15, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		var p = get_tree().get_first_node_in_group("player")
		if is_instance_valid(p):
			var d = target_pos.distance_to(p.global_position)
			if d < radius:
				var dmg = _boss.data.damage * 1.5 if _boss.data else 30.0
				p.take_damage(dmg)
		warning.queue_free()
	)

func _skill_summon_minions() -> void:
	var wm = get_tree().root.find_child("WaveManager", true, false)
	if not wm: return
	var count = 2 if phase == Phase.NORMAL else (3 if phase == Phase.BERSERK else 5)
	for i in count:
		var enemy = CharacterBody2D.new()
		enemy.set_script(load("res://scripts/enemies/EnemyBase.gd"))
		enemy.add_to_group("enemies")
		get_tree().current_scene.add_child(enemy)
		var ed = EnemyData.new()
		ed.display_name = "深渊仆从"
		ed.max_hp = 15.0
		ed.damage = 5.0
		ed.move_speed = 80.0
		ed.size = 10.0
		ed.color = _boss.data.color.lerp(Color.WHITE, 0.4) if _boss.data else Color(0.6, 0.3, 0.8)
		ed.exp_reward = 2
		ed.attack_cooldown = 1.5
		enemy.setup(ed)
		var angle = TAU * i / count
		enemy.global_position = _boss.global_position + Vector2(cos(angle), sin(angle)) * 60.0
	_show_phase_banner("Boss 召唤了仆从！", Color(0.8, 0.4, 1.0))

func _skill_dash_attack() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player) or not is_instance_valid(_boss): return
	var dir = _boss.global_position.direction_to(player.global_position)
	var dash_speed = _boss.base_move_speed * 4.0
	_boss.velocity = dir * dash_speed
	_boss.move_and_slide()
	# Flash visual
	if _boss.visual:
		_boss.visual.modulate = Color(2.0, 1.5, 0.5)
		var tw = _boss.create_tween()
		tw.tween_property(_boss.visual, "modulate", Color(1, 1, 1), 0.3)

func _enter_berserk() -> void:
	phase = Phase.BERSERK
	_skill_interval = 3.0
	_boss.base_move_speed *= 1.4
	if _boss.data:
		_boss.data.attack_cooldown *= 0.7
	if _boss.visual:
		_boss.visual.modulate = Color(1.0, 0.3, 0.3)
	_do_shake(8.0)
	_show_phase_banner("⚡ Boss 进入狂暴状态！", Color(1.0, 0.4, 0.1))

func _enter_dying() -> void:
	phase = Phase.DYING
	_skill_interval = 2.0
	_boss.base_move_speed *= 1.6
	if _boss.data:
		_boss.data.attack_cooldown *= 0.5
	if _boss.visual:
		_boss.visual.modulate = Color(0.6, 0.1, 1.0)
		var tween = _boss.create_tween().set_loops()
		tween.tween_property(_boss.visual, "position", Vector2(3, 0), 0.04)
		tween.tween_property(_boss.visual, "position", Vector2(-3, 0), 0.04)
		tween.tween_property(_boss.visual, "position", Vector2.ZERO, 0.04)
	_do_shake(12.0)
	_show_phase_banner("💀 Boss 濒死狂怒！", Color(0.8, 0.1, 1.0))

func _do_shake(amount: float) -> void:
	var ss = get_tree().root.find_child("ScreenShake", true, false)
	if ss and ss.has_method("start"):
		ss.start(amount)

func _show_phase_banner(text: String, color: Color) -> void:
	var hud = get_tree().root.find_child("HUDLayer", true, false)
	if not hud: hud = get_tree().get_first_node_in_group("hud_layer")
	if not hud: return
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.anchor_left = 0.5; lbl.anchor_right = 0.5
	lbl.anchor_top = 0.35; lbl.anchor_bottom = 0.35
	lbl.offset_left = -350; lbl.offset_right = 350
	lbl.offset_top = -25; lbl.offset_bottom = 25
	hud.add_child(lbl)
	var tween = lbl.create_tween()
	tween.tween_interval(1.8)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tween.tween_callback(lbl.queue_free)
