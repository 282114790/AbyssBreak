# EventBus.gd
# 全局事件总线 - 解耦各系统间通信
extends Node

# 全局游戏暂停标志
var game_logic_paused: bool = false
var total_kills: int = 0   # 本局击杀计数

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# 敌人相关
signal enemy_died(position: Vector2, exp_reward: int)

# 玩家相关
signal player_damaged(current_hp: float, max_hp: float)
signal player_died
signal player_leveled_up(new_level: int)
signal player_exp_changed(current_exp: int, required_exp: int)

# 技能相关
signal skill_picked(skill_id: String)
signal skill_leveled_up(skill_id: String, new_level: int)
signal skill_evolved(old_id: String, new_id: String)

# 游戏流程
signal game_started
signal game_paused
signal game_resumed
signal game_over(survived_time: float, score: int)
signal player_won(survived_time: float, score: int)
signal wave_changed(wave_number: int)
signal boss_spawned
signal boss_died

# UI
signal show_level_up_panel(choices: Array)
signal upgrade_chosen(choice: Dictionary)
