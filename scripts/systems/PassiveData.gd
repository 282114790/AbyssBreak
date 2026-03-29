# PassiveData.gd
# 被动技能数据资源
extends Resource
class_name PassiveData

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var max_level: int = 5

# 各项加成（百分比或绝对值）
@export var hp_bonus: float = 0.0          # 血量加成（绝对值）
@export var move_speed_bonus: float = 0.0  # 移速加成（百分比）
@export var damage_bonus: float = 0.0      # 伤害加成（百分比）
@export var attack_speed_bonus: float = 0.0 # 攻速加成（百分比）
@export var pickup_radius_bonus: float = 0.0 # 吸收范围加成
@export var exp_bonus: float = 0.0         # 经验加成（百分比）
@export var regen_bonus: float = 0.0       # 每秒回血量
