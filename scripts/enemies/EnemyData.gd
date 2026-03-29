# EnemyData.gd
# 敌人数据资源 - 数据驱动，新增敌人只需新建Resource
extends Resource
class_name EnemyData

enum MoveType {
	CHASE,       # 直冲玩家
	EXPLODE,     # 靠近爆炸
	RANGED,      # 远程射击
	ELITE,       # 精英（特殊行为）
}

@export var id: String = ""
@export var display_name: String = ""
@export var max_hp: float = 30.0
@export var move_speed: float = 60.0
@export var damage: float = 10.0           # 接触伤害
@export var exp_reward: int = 5
@export var move_type: MoveType = MoveType.CHASE
@export var color: Color = Color(0.8, 0.2, 0.2)
@export var size: float = 16.0
@export var attack_range: float = 0.0      # 远程攻击范围（0=近战）
@export var attack_cooldown: float = 2.0
