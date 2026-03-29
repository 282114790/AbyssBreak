extends Node
# 挂在 Camera2D 上，或作为独立节点控制摄像机偏移
var camera: Camera2D
var shake_amount: float = 0.0
var shake_decay: float = 8.0

func start(amount: float) -> void:
	shake_amount = amount

func _process(delta: float) -> void:
	if shake_amount > 0:
		shake_amount = max(0, shake_amount - shake_decay * delta)
		if camera:
			camera.offset = Vector2(
				randf_range(-shake_amount, shake_amount),
				randf_range(-shake_amount, shake_amount)
			)
	elif camera:
		camera.offset = Vector2.ZERO
