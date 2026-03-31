# BossController.gd
# Boss三阶段控制（#23）— 附加到 Boss 敌人节点上
# 阶段：HP>66% 普通 → HP>33% 狂暴 → HP<33% 濒死狂怒
extends Node

enum Phase { NORMAL, BERSERK, DYING }
var phase: Phase = Phase.NORMAL

var _boss: Node = null
var _boss_max_hp: float = 1.0  # EnemyBase 无 max_hp，启动时记录初始值

func _ready() -> void:
	_boss = get_parent()
	await get_tree().process_frame
	if is_instance_valid(_boss):
		_boss_max_hp = max(_boss.hp, 1.0)

func _process(_delta: float) -> void:
	if not is_instance_valid(_boss) or _boss.is_dead: return
	var hp_ratio = float(_boss.hp) / _boss_max_hp
	match phase:
		Phase.NORMAL:
			if hp_ratio <= 0.66:
				_enter_berserk()
		Phase.BERSERK:
			if hp_ratio <= 0.33:
				_enter_dying()

func _enter_berserk() -> void:
	phase = Phase.BERSERK
	_boss.base_move_speed *= 1.4
	if _boss.data:
		_boss.data.attack_cooldown *= 0.7  # 攻击间隔 -30%
	if _boss.visual:
		_boss.visual.modulate = Color(1.0, 0.3, 0.3)
	_do_shake(8.0)
	_show_phase_banner("⚡ Boss 进入狂暴状态！", Color(1.0, 0.4, 0.1))

func _enter_dying() -> void:
	phase = Phase.DYING
	_boss.base_move_speed *= 1.6
	if _boss.data:
		_boss.data.attack_cooldown *= 0.5  # 攻击间隔 -50%
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
