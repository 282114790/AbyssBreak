# MapRegistry.gd
# 地图注册表 — 管理所有可用地图风格
extends Node

class MapData:
	var id: String
	var display_name: String
	var description: String
	var icon_emoji: String
	var bg_script_path: String
	var bg_theme: String
	var canvas_modulate_color: Color
	var world_half_size: float
	var preview_color: Color

var all_maps: Array = []
var selected_id: String = "dark_stone"

func _ready() -> void:
	_register_maps()

func _register_maps() -> void:
	_add_map("dark_stone", "暗色石砖", "苔藓覆盖的不规则暗色石砖地牢",
		"🪨", "dark_stone", Color(0.75, 0.72, 0.68), Color(0.15, 0.18, 0.12))

	_add_map("herringbone", "人字纹砖", "古老的人字纹铺砖地面，磨损而沧桑",
		"🧱", "herringbone", Color(0.78, 0.73, 0.68), Color(0.18, 0.15, 0.12))

	_add_map("abyss_rock", "深渊裂隙", "黑曜石般的碎裂岩面，裂缝中透出幽蓝光芒",
		"🌑", "abyss_rock", Color(0.65, 0.62, 0.72), Color(0.08, 0.06, 0.15))

	_add_map("marble_ruins", "大理石废墟", "破碎的大理石地砖，远古神殿的遗迹",
		"🏛", "marble_ruins", Color(0.85, 0.82, 0.78), Color(0.22, 0.20, 0.18))

	_add_map("wet_slab", "湿润石板", "潮湿的石板地面，水渍与苔藓交织的沼泽地牢",
		"💧", "wet_slab", Color(0.68, 0.72, 0.70), Color(0.10, 0.15, 0.14))

func _add_map(id: String, name: String, desc: String, emoji: String,
		theme: String, modulate: Color, preview: Color) -> void:
	var m = MapData.new()
	m.id = id
	m.display_name = name
	m.description = desc
	m.icon_emoji = emoji
	m.bg_script_path = "res://scripts/systems/TileMapBackgroundV2.gd"
	m.bg_theme = theme
	m.canvas_modulate_color = modulate
	m.world_half_size = 3000.0
	m.preview_color = preview
	all_maps.append(m)

func get_map(map_id: String) -> MapData:
	for m in all_maps:
		if m.id == map_id:
			return m
	return all_maps[0]
