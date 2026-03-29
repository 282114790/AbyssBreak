# DifficultyData.gd
# 难度配置数据（不使用class_name，避免自引用编译问题）
extends Resource

var id: String = ""
var display_name: String = ""
var description: String = ""
var enemy_hp_mult: float = 1.0
var enemy_dmg_mult: float = 1.0
var enemy_speed_mult: float = 1.0
var enemy_count_mult: float = 1.0
var exp_mult: float = 1.0
var soul_stone_mult: float = 1.0
var locked: bool = false
var unlock_condition: String = ""
