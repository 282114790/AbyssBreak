# CharacterRegistry.gd
extends Node

const CharacterDataScript = preload("res://scripts/player/CharacterData.gd")

var all_characters: Array = []
var selected_id: String = "mage"

func _ready() -> void:
	_register_all()

func _register_all() -> void:
	var mage = CharacterDataScript.new()
	mage.id            = "mage"
	mage.display_name  = "法师"
	mage.description   = "精通元素魔法的古老法师，擅长远程群攻。"
	mage.icon_color    = Color(0.6, 0.3, 1.0)
	mage.icon_emoji    = "🧙"
	mage.hp_mult       = 1.0
	mage.speed_mult    = 1.0
	mage.damage_mult   = 1.2
	mage.pickup_mult   = 1.0
	mage.regen_base    = 0.0
	mage.start_skill_ids = ["fireball"]
	mage.trait_desc    = "连续释放同元素技能，伤害逐次递增（最高+60%）"
	mage.element_affinity = [SkillData.Element.FIRE, SkillData.Element.HOLY]
	mage.unique_mechanic = "elemental_chain"
	mage.mechanic_desc = "连续同元素施法：每次+15%伤害，最高4层"
	all_characters.append(mage)

	var warrior = CharacterDataScript.new()
	warrior.id            = "warrior"
	warrior.display_name  = "战士"
	warrior.description   = "铁甲战士，以肉身为盾，近身肉搏无人能敌。"
	warrior.icon_color    = Color(0.9, 0.4, 0.1)
	warrior.icon_emoji    = "⚔"
	warrior.hp_mult       = 1.8
	warrior.speed_mult    = 0.85
	warrior.damage_mult   = 1.0
	warrior.pickup_mult   = 0.8
	warrior.regen_base    = 3.0
	warrior.start_skill_ids = ["iceblade"]
	warrior.trait_desc    = "受击后下一次技能伤害翻倍（受创反击）"
	warrior.element_affinity = [SkillData.Element.ICE, SkillData.Element.DARK]
	warrior.unique_mechanic = "revenge_strike"
	warrior.mechanic_desc = "受击后8秒内下一次技能伤害×2"
	warrior.walk_sheet_path  = "res://assets/sprites/warrior_walk_sheet.png"
	warrior.walk_frame_count = 8
	warrior.walk_frame_w     = 128
	warrior.walk_frame_h     = 128
	all_characters.append(warrior)

	var hunter = CharacterDataScript.new()
	hunter.id            = "hunter"
	hunter.display_name  = "猎手"
	hunter.description   = "来自深渊边境的精英猎手，速度与精准是她的武器。"
	hunter.icon_color    = Color(0.2, 0.8, 0.4)
	hunter.icon_emoji    = "🏹"
	hunter.hp_mult       = 0.75
	hunter.speed_mult    = 1.35
	hunter.damage_mult   = 1.0
	hunter.pickup_mult   = 1.3
	hunter.regen_base    = 0.0
	hunter.start_skill_ids = ["lightning"]
	hunter.trait_desc    = "移动速度转化为伤害加成（动即是攻）"
	hunter.element_affinity = [SkillData.Element.LIGHTNING, SkillData.Element.POISON]
	hunter.unique_mechanic = "velocity_damage"
	hunter.mechanic_desc = "移速越快伤害越高，最高+40%"
	hunter.walk_sheet_path  = "res://assets/sprites/hunter_walk_sheet.png"
	hunter.walk_frame_count = 8
	hunter.walk_frame_w     = 128
	hunter.walk_frame_h     = 128
	all_characters.append(hunter)

func get_character(id: String):
	for c in all_characters:
		if c.id == id: return c
	return null

func is_unlocked(id: String, meta: Node) -> bool:
	if id == "mage":
		return true
	if not meta:
		return false
	if id == "warrior":
		return meta.total_runs >= 3
	if id == "hunter":
		return meta.best_score > 0 and meta.total_runs >= 5
	return true
