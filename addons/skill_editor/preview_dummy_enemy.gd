# preview_dummy_enemy.gd
# 技能编辑器预览用的假人敌人，响应技能伤害调用
@tool
extends Node2D

var current_hp: float = 100.0
var max_hp: float = 100.0
var _dmg_flash: float = 0.0

func take_damage(dmg: float) -> void:
	current_hp -= dmg
	_dmg_flash = 0.15
	if current_hp <= 0:
		current_hp = max_hp  # 预览模式自动复活

func _process(delta: float) -> void:
	_dmg_flash = max(_dmg_flash - delta, 0.0)
	queue_redraw()

func _draw() -> void:
	var col = Color(1.0, 0.3, 0.3, 0.9) if _dmg_flash > 0 else Color(0.75, 0.1, 0.1, 0.85)
	draw_rect(Rect2(-14, -14, 28, 28), col)
	# HP条
	var hp_ratio = current_hp / max(max_hp, 1.0)
	draw_rect(Rect2(-14, -18, 28, 3), Color(0.2, 0.2, 0.2, 0.8))
	draw_rect(Rect2(-14, -18, 28 * hp_ratio, 3), Color(0.2, 0.9, 0.2, 0.9))
	draw_string(ThemeDB.fallback_font, Vector2(-5, 4), "敌", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
