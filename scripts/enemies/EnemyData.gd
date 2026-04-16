# EnemyData.gd
# 敌人数据资源 - 数据驱动，新增敌人只需新建Resource
extends Resource
class_name EnemyData

enum MoveType {
	CHASE,       # 直冲玩家
	EXPLODE,     # 靠近后自爆 AOE
	RANGED,      # 远程射击，保持距离
	TANK,        # 护甲型：减伤，速度慢
	ELITE,       # 精英（特殊行为）
	SPLITTER,    # 死后分裂成小怪
	TELEPORTER,  # 短距离闪现接近
	SHIELDER,    # 正面免伤，必须绕后
	SUMMONER,    # 召唤小怪
	PATROL,      # 沿路径巡逻，高伤害可预判
}

@export var id: String = ""
@export var display_name: String = ""
@export var max_hp: float = 30.0
@export var move_speed: float = 60.0
@export var damage: float = 10.0
@export var exp_reward: int = 5
@export var move_type: MoveType = MoveType.CHASE
@export var color: Color = Color(0.8, 0.2, 0.2)
@export var size: float = 16.0
@export var attack_range: float = 0.0
@export var attack_cooldown: float = 2.0
@export var armor: float = 0.0
@export var is_elite: bool = false

# ── 视觉字段（数据驱动） ──
@export var walk_sheet_path: String = ""
@export var walk_frames: int = 6
@export var walk_frame_w: int = 170
@export var walk_frame_h: int = 168
@export var walk_fps: float = 8.0
@export var static_sprite_path: String = ""
@export var display_scale: float = -1.0
