# CharacterData.gd
extends Resource
class_name CharacterData

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon_color: Color = Color.WHITE
@export var icon_emoji: String = "🧙"

@export var hp_mult: float = 1.0
@export var speed_mult: float = 1.0
@export var damage_mult: float = 1.0
@export var pickup_mult: float = 1.0
@export var regen_base: float = 0.0

@export var start_skill_ids: Array = []   # Array of String，不用类型约束
@export var trait_desc: String = ""
@export var walk_sheet_path: String = ""  # 行走动画精灵表路径（空=用程序化圆形）
@export var walk_frame_count: int = 8    # 动画帧数
@export var walk_frame_w: int = 128      # 单帧宽度px
@export var walk_frame_h: int = 128      # 单帧高度px
