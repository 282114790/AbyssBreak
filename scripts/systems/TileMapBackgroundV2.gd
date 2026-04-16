extends Node2D

# ============================================================
#  深渊突围 — 背景系统 V3
#  L0: 底图平铺       z=-10
#  L1: deco props      z=-6
# ============================================================

var map_theme: String = "dungeon"

const TILE_SRC_PX := 1024
const TILE_DISPLAY := 384
const GRID_STEP   := TILE_DISPLAY
const WORLD_HALF  := 8000.0

# ── L0: 底图纹理映射 ──
const FLOOR_TEXTURES := {
	"dark_stone":    "res://assets/tilesets/floor_style1_dark_stone.png",
	"herringbone":   "res://assets/tilesets/floor_style2_herringbone.png",
	"abyss_rock":    "res://assets/tilesets/floor_style3_abyss_rock.png",
	"marble_ruins":  "res://assets/tilesets/floor_style4_marble_ruins.png",
	"wet_slab":      "res://assets/tilesets/floor_style5_wet_slab.png",
}

# ── L1: Deco Props 配置 ──
const DECO_DIR := "res://assets/tilesets/deco_props_dungeon/"
const DECO_PROPS := {
	"barrel":        { "count": 2 },
	"blood_pool":    { "count": 2 },
	"book_pile":     { "count": 2 },
	"broken_pillar": { "count": 3 },
	"candle":        { "count": 2 },
	"chain":         { "count": 2 },
	"chest":         { "count": 3 },
	"cobweb":        { "count": 3 },
	"crystal":       { "count": 3 },
	"magic_circle":  { "count": 2 },
	"mushroom":      { "count": 3 },
	"rubble":        { "count": 2 },
	"skull_pile":    { "count": 3 },
}

const DECO_ZONES : Array = [
	{ "threshold": 0.25, "density": 0.85, "props": ["broken_pillar", "rubble", "chain", "skull_pile"] },
	{ "threshold": 0.45, "density": 0.78, "props": ["chest", "barrel", "book_pile", "candle"] },
	{ "threshold": 0.60, "density": 0.74, "props": ["magic_circle", "candle", "blood_pool", "crystal"] },
	{ "threshold": 0.80, "density": 0.80, "props": ["mushroom", "crystal", "cobweb"] },
	{ "threshold": 1.01, "density": 0.30, "props": [] },
]

const DECO_SCALE_MIN     := 0.44
const DECO_SCALE_MAX     := 0.90
const DECO_OFFSET_RATIO  := 0.70
const DECO_SPAWN_PROTECT := 3.0

# ── 噪声 ──
var _noise_deco_density := FastNoiseLite.new()
var _noise_deco_zone    := FastNoiseLite.new()

# ── 纹理缓存 ──
var _tex_floor : Texture2D
var _deco_textures : Dictionary = {}

# ── 对象池 ──
var _floor_pool  : Array[Sprite2D] = []
var _floor_active : Dictionary = {}
var _deco_pool  : Array[Sprite2D] = []
var _deco_active : Dictionary = {}

var _camera : Camera2D
var _parallax_particles: CPUParticles2D = null
var _debug_first_update := true

func _ready() -> void:
	_setup_noise()
	_load_textures()
	_find_camera()
	_setup_ambient_particles()

func _setup_noise() -> void:
	_noise_deco_density.seed = 1001
	_noise_deco_density.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise_deco_density.frequency = 0.04

	_noise_deco_zone.seed = 1337
	_noise_deco_zone.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise_deco_zone.frequency = 0.003

func _load_textures() -> void:
	# L0: floor
	var tex_path : String = FLOOR_TEXTURES.get(map_theme, "")
	if tex_path != "" and ResourceLoader.exists(tex_path):
		_tex_floor = load(tex_path)
	else:
		for key in FLOOR_TEXTURES:
			if ResourceLoader.exists(FLOOR_TEXTURES[key]):
				_tex_floor = load(FLOOR_TEXTURES[key])
				break

	# L1: deco props
	var deco_miss := 0
	for prop_name in DECO_PROPS:
		var cfg = DECO_PROPS[prop_name]
		for i in range(int(cfg.count)):
			var fname := "deco_props_dungeon_%s_%02d.png" % [prop_name, i]
			var path := DECO_DIR + fname
			if ResourceLoader.exists(path):
				_deco_textures["%s_%02d" % [prop_name, i]] = load(path)
			else:
				deco_miss += 1
	print("[BG] theme=%s, floor=%s, deco=%d loaded, %d missed" % [map_theme, str(_tex_floor != null), _deco_textures.size(), deco_miss])

func _find_camera() -> void:
	var parent = get_parent()
	if parent and parent.get("camera") != null:
		_camera = parent.camera
	if not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_2d()

func _setup_ambient_particles() -> void:
	var p = CPUParticles2D.new()
	p.amount = 30
	p.lifetime = 7.0
	p.explosiveness = 0.0
	p.randomness = 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(800, 450)
	p.direction = Vector2(0.05, -1.0)
	p.spread = 20.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 12.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(0.4, 0.45, 0.35, 0.0))
	gradient.add_point(0.25, Color(0.4, 0.45, 0.35, 0.10))
	gradient.add_point(0.75, Color(0.5, 0.5, 0.4, 0.08))
	gradient.add_point(1.0, Color(0.5, 0.5, 0.4, 0.0))
	p.color_ramp = gradient
	p.z_index = -5
	add_child(p)
	_parallax_particles = p

func _process(_delta: float) -> void:
	if not is_instance_valid(_camera):
		var parent = get_parent()
		if parent and parent.get("camera") != null:
			_camera = parent.camera
		if not is_instance_valid(_camera):
			_camera = get_viewport().get_camera_2d()
		if not is_instance_valid(_camera):
			return
	if is_instance_valid(_parallax_particles):
		_parallax_particles.global_position = _camera.global_position
	_update_tiles()

func _update_tiles() -> void:
	var cam_pos := _camera.global_position
	var vp_size := get_viewport_rect().size
	var margin  := float(GRID_STEP) * 1.5

	var x_min := cam_pos.x - vp_size.x * 0.5 - margin
	var x_max := cam_pos.x + vp_size.x * 0.5 + margin
	var y_min := cam_pos.y - vp_size.y * 0.5 - margin
	var y_max := cam_pos.y + vp_size.y * 0.5 + margin

	var col_min := int(floor(x_min / GRID_STEP))
	var col_max := int(ceil(x_max / GRID_STEP))
	var row_min := int(floor(y_min / GRID_STEP))
	var row_max := int(ceil(y_max / GRID_STEP))

	var world_tiles := int(WORLD_HALF / GRID_STEP)
	col_min = clampi(col_min, -world_tiles, world_tiles - 1)
	col_max = clampi(col_max, -world_tiles, world_tiles - 1)
	row_min = clampi(row_min, -world_tiles, world_tiles - 1)
	row_max = clampi(row_max, -world_tiles, world_tiles - 1)

	var needed : Dictionary = {}
	for r in range(row_min, row_max + 1):
		for c in range(col_min, col_max + 1):
			needed[Vector2i(c, r)] = true

	# 回收不可见的
	for key in _floor_active.keys():
		if not needed.has(key):
			_return_sprite(_floor_active[key], _floor_pool)
			_floor_active.erase(key)
	for key in _deco_active.keys():
		if not needed.has(key):
			_return_sprite(_deco_active[key], _deco_pool)
			_deco_active.erase(key)

	# 生成可见的
	var _dbg_deco := 0
	for key in needed.keys():
		var c : int = key.x
		var r : int = key.y
		var wx := float(c) * GRID_STEP + GRID_STEP * 0.5
		var wy := float(r) * GRID_STEP + GRID_STEP * 0.5

		if not _floor_active.has(key):
			var sp := _get_sprite(_floor_pool)
			_place_floor_tile(sp, c, r, wx, wy)
			_floor_active[key] = sp

		if not _deco_active.has(key) and _deco_textures.size() > 0:
			var deco_sp := _place_deco(c, r, wx, wy)
			if deco_sp != null:
				_deco_active[key] = deco_sp
				_dbg_deco += 1

	if _debug_first_update:
		_debug_first_update = false
		print("[BG] First frame — tiles: %d, deco_placed: %d" % [needed.size(), _dbg_deco])

# ── L0: 地板 ─────────────────────────────────────
func _place_floor_tile(sp: Sprite2D, _c: int, _r: int, wx: float, wy: float) -> void:
	sp.texture = _tex_floor
	sp.region_enabled = false
	var s := float(TILE_DISPLAY) / float(TILE_SRC_PX)
	sp.scale = Vector2(s, s)
	sp.position = Vector2(wx, wy)
	sp.z_index = -10
	sp.rotation = 0.0
	sp.flip_h = false
	var brightness := lerpf(0.92, 1.0, _cell_rand(_c, _r, 999))
	sp.modulate = Color(brightness, brightness, brightness, 1.0)

# ── L1: Deco Props ──────────────────────────────────
func _place_deco(c: int, r: int, wx: float, wy: float) -> Sprite2D:
	if absf(float(c)) < DECO_SPAWN_PROTECT and absf(float(r)) < DECO_SPAWN_PROTECT:
		return null

	var fc := float(c)
	var fr := float(r)

	var zone_n := (_noise_deco_zone.get_noise_2d(fc * GRID_STEP, fr * GRID_STEP) + 1.0) * 0.5
	var zone_cfg : Dictionary = DECO_ZONES[DECO_ZONES.size() - 1]
	for z in DECO_ZONES:
		if zone_n < float(z.threshold):
			zone_cfg = z
			break

	var density_n := (_noise_deco_density.get_noise_2d(fc, fr) + 1.0) * 0.5
	if density_n >= float(zone_cfg.density):
		return null

	var prop_list : Array = zone_cfg.props
	if prop_list.is_empty():
		var all_names : Array = DECO_PROPS.keys()
		var pick := int(_cell_rand(c, r, 500) * all_names.size()) % all_names.size()
		prop_list = [all_names[pick]]

	var chosen_name : String = prop_list[int(_cell_rand(c, r, 501) * prop_list.size()) % prop_list.size()]
	var cfg : Dictionary = DECO_PROPS.get(chosen_name, {})
	if cfg.is_empty():
		return null

	var variant := int(_cell_rand(c, r, 502) * int(cfg.count)) % int(cfg.count)
	var key := "%s_%02d" % [chosen_name, variant]
	if not _deco_textures.has(key):
		return null

	var sp := _get_sprite(_deco_pool)
	sp.texture = _deco_textures[key]
	sp.region_enabled = false

	var scale_t := _cell_rand(c, r, 510)
	var scale_factor := lerpf(DECO_SCALE_MIN, DECO_SCALE_MAX, scale_t)
	var s := float(GRID_STEP) / 256.0 * scale_factor
	sp.scale = Vector2(s, s)

	var margin_px := float(GRID_STEP) * (1.0 - scale_factor) * 0.5
	var max_off := margin_px * DECO_OFFSET_RATIO
	var off_x := lerpf(-max_off, max_off, _cell_rand(c, r, 511))
	var off_y := lerpf(-max_off, max_off, _cell_rand(c, r, 512))
	sp.position = Vector2(wx + off_x, wy + off_y)
	sp.rotation = 0.0
	sp.flip_h = false
	sp.modulate = Color(1.0, 1.0, 1.0, 1.0)
	sp.z_index = -6
	sp.material = null

	return sp

# ── 通用对象池 ──
func _get_sprite(pool: Array[Sprite2D]) -> Sprite2D:
	if pool.size() > 0:
		var sp : Sprite2D = pool.pop_back()
		sp.visible = true
		sp.rotation = 0.0
		sp.flip_h = false
		sp.material = null
		return sp
	var sp := Sprite2D.new()
	sp.centered = true
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sp)
	return sp

func _return_sprite(sp: Sprite2D, pool: Array[Sprite2D]) -> void:
	sp.visible = false
	sp.material = null
	pool.append(sp)

# ── 确定性哈希伪随机 ──
static func _cell_rand(c: int, r: int, salt: int) -> float:
	var h := ((c * 48271 + r * 12347 + salt * 65537) ^ 0x5DEECE66) & 0x7FFFFFFF
	h = (h * 16807 + 1013904223) & 0x7FFFFFFF
	return float(h & 0xFFFF) / 65535.0
