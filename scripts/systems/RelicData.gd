# RelicData.gd
# 遗物数据定义
extends Resource
class_name RelicData

var id: String = ""
var display_name: String = ""
var description: String = ""
var icon_emoji: String = "📦"
var rarity: int = 1  # 1=普通 2=稀有 3=史诗

# 效果参数（由apply_to_player实现）
var hp_bonus: float = 0.0
var hp_mult: float = 1.0
var damage_bonus: float = 0.0
var damage_mult: float = 1.0
var speed_bonus: float = 0.0
var cooldown_mult: float = 1.0    # <1 = 加速冷却
var pickup_bonus: float = 0.0
var regen_bonus: float = 0.0
var exp_mult: float = 1.0
var crit_chance: float = 0.0      # 暴击率加成（0.0~1.0）
var crit_mult: float = 1.0        # 暴击倍率加成
var projectile_bonus: int = 0     # 额外投射物数量
var dodge_recharge: float = 0.0   # 翻滚冷却减少（秒）
var aoe_mult: float = 1.0         # 范围倍率

func apply_to_player(p: Node) -> void:
	if hp_bonus != 0.0:
		p.max_hp += hp_bonus
		p.current_hp += hp_bonus
	if hp_mult != 1.0:
		var added = p.max_hp * (hp_mult - 1.0)
		p.max_hp += added
		p.current_hp += added
	if damage_bonus != 0.0:
		p.damage_multiplier += damage_bonus
	if damage_mult != 1.0:
		p.damage_multiplier *= damage_mult
	if speed_bonus != 0.0:
		p.move_speed += speed_bonus
	if cooldown_mult != 1.0:
		for skill in p.skills:
			if skill.data:
				skill.data.cooldown = max(0.08, skill.data.cooldown * cooldown_mult)
	if pickup_bonus != 0.0:
		p.pickup_radius += pickup_bonus
	if regen_bonus != 0.0:
		p.regen_per_second += regen_bonus
	if exp_mult != 1.0:
		p.exp_multiplier *= exp_mult
	if crit_chance != 0.0:
		p.crit_chance = p.crit_chance + crit_chance
	if crit_mult != 1.0:
		p.crit_mult = p.crit_mult * crit_mult
	if dodge_recharge != 0.0:
		p.DODGE_COOLDOWN = max(0.2, p.DODGE_COOLDOWN - dodge_recharge)
	EventBus.emit_signal("player_damaged", p.current_hp, p.max_hp)
