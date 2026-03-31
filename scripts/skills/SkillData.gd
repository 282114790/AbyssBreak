# SkillData.gd
# 技能数据资源 - 数据驱动设计，新增技能只需新建一个Resource文件
extends Resource
class_name SkillData

enum SkillType {
	PROJECTILE,   # 投射物（火球、冰刃...）
	ORBITAL,      # 绕身旋转（护盾...）
	AREA,         # 范围（雷暴领域...）
	SUMMON,       # 召唤（宠物、图腾...）
	MELEE,        # 近战（冲刺斩...）
}

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var skill_type: SkillType = SkillType.PROJECTILE
@export var scene_path: String = ""         # 技能场景路径

# 基础属性
@export var damage: float = 10.0
@export var cooldown: float = 1.0
@export var speed: float = 200.0
@export var range_radius: float = 0.0
@export var pierce_count: int = 1          # 穿透次数
@export var projectile_count: int = 1      # 同时发射数量

# 进化配置
@export var evolve_passive_id: String = "" # 需要配合哪个被动才能进化
@export var evolved_skill_id: String = ""  # 进化后变成哪个技能

# 升级配置（每级提升）
@export var level_up_damage: float = 5.0
@export var level_up_cooldown: float = -0.05
@export var max_level: int = 5

# 主动技能配置
@export var is_active: bool = false         # true=主动技能（需按键触发），false=自动触发
@export var active_slot: int = 0            # 0=Q槽 1=E槽（is_active=true时有效）
