extends Node2D
# 飘字节点，程序化创建，自动播放动画后销毁
var label: Label

func setup(dmg: float, is_crit: bool = false) -> void:
	var actual_crit = is_crit or dmg > 30.0
	label = Label.new()
	label.text = ("✦ " if actual_crit else "") + str(int(dmg))
	var fsize = 36 if actual_crit else 22
	label.add_theme_font_size_override("font_size", fsize)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1) if actual_crit else Color(1.0, 1.0, 1.0))
	add_child(label)
	var fly_dist = 90.0 if actual_crit else 60.0
	var duration = 0.9
	scale = Vector2(1.5, 1.5) if actual_crit else Vector2(1.2, 1.2)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - fly_dist, duration)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
	tween.tween_property(label, "modulate:a", 0.0, duration).set_delay(duration * 0.4)
	tween.tween_callback(queue_free).set_delay(duration)
	if actual_crit:
		position.x += randf_range(-20, 20)
