# DropSystem.gd
# 掉落系统 — 从 Main.gd 提取，处理敌人死亡后的经验/金币/治疗掉落
extends Node

func _ready() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)

func _on_enemy_died(pos: Vector2, exp_val: int) -> void:
	EventBus.total_kills += 1
	var is_elite := exp_val >= 15
	var is_boss := exp_val >= 100

	var roll := randf()
	if is_boss or is_elite:
		_drop_exp_gem(pos, exp_val)
		_drop_gold_coin(pos, exp_val)
		if is_boss:
			for i in range(2):
				_drop_gold_coin(pos + Vector2(randf_range(-20, 20), randf_range(-20, 20)), exp_val)
	elif roll < 0.75:
		_drop_exp_gem(pos, exp_val)
	elif roll < 0.95:
		_drop_gold_coin(pos, exp_val)
	else:
		_drop_heal_bubble(pos)

func _drop_exp_gem(pos: Vector2, exp_val: int) -> void:
	var gem = Area2D.new()
	gem.set_script(load("res://scripts/systems/ExperienceGem.gd"))
	get_tree().current_scene.add_child(gem)
	gem.global_position = pos
	gem.setup(exp_val)

func _drop_gold_coin(pos: Vector2, exp_val: int) -> void:
	var coin = Area2D.new()
	coin.set_script(load("res://scripts/systems/GoldCoin.gd"))
	get_tree().current_scene.add_child(coin)
	coin.global_position = pos + Vector2(randf_range(-8, 8), randf_range(-8, 8))
	var gold_val := 1 + randi() % 3
	if exp_val >= 100:
		gold_val = 15 + randi() % 10
	elif exp_val >= 15:
		gold_val = 5 + randi() % 5
	coin.setup(gold_val)

func _drop_heal_bubble(pos: Vector2) -> void:
	var heal = Area2D.new()
	heal.set_script(load("res://scripts/systems/HealBubble.gd"))
	get_tree().current_scene.add_child(heal)
	heal.global_position = pos
	heal.setup(15.0 + randf() * 10.0)
