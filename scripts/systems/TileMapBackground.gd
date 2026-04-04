extends Node2D

# ============================================================
#  深渊突围 — 分层背景系统 v3
#  优化：NEAREST filter / 火把 PointLight2D / 粒子配色修正
#  map_theme: "dungeon"(默认) | "ice" | "lava"
# ============================================================

# 地图主题（由 Main.gd 在初始化前设置）
var map_theme: String = "dungeon"

const TILE_PX    := 64
const SCALE_F    := 1.0
const DISPLAY    := TILE_PX * SCALE_F   # 64px
const WORLD_HALF := 8000.0   # 足够大，玩家基本跑不到边界

const ROOM_TILES := 16
const ROOM_SIZE  := DISPLAY * ROOM_TILES

# Layer 1 —— floor_layer1.png（20tile横排，每tile16px）
# tile排列：[0,1]=普通石砖, [2-4]=苔藓石砖, [5-9]=符文(row0), [10-14]=符文(row1-2), [15-19]=符文(row3)
const FLOOR_TILE_COUNT : int = 20
const FLOOR_TILE_PX    : int = 64
const FLOOR_WEIGHTS : Array[int] = [
	1, 1, 1, 1, 1,
	1, 1, 1, 1, 1,
	1, 1, 1, 1, 1,
	1, 1, 1, 1, 1
]

# Layer 2
const DETAIL_TILE_COUNT := 6
const DETAIL_TILE_PX    := 32

# Layer 4 —— floor_deco_props.png（8 tile × 16px，横排）
const DECO_TILE_COUNT := 8
const DECO_TILE_PX    := 16

# Layer 5 —— torch_anim.png（4帧 × 16×32px）
const TORCH_FRAMES   := 4
const TORCH_TILE_W   := 16
const TORCH_TILE_H   := 32
const TORCH_INTERVAL := 8  # 每隔几格放一个火把

# ── 调试开关（-1=全开，2~5=Layer1底色+只叠该层）──────
const DEBUG_LAYER : int = -1

# ── 噪声 ──────────────────────────────────────────────
var _noise_floor  := FastNoiseLite.new()
var _noise_detail := FastNoiseLite.new()
var _noise_deco   := FastNoiseLite.new()
var _noise_torch  := FastNoiseLite.new()

# ── 纹理 ──────────────────────────────────────────────
var _tex_floor1 : Texture2D   # Layer1 专用
var _tex_detail : Texture2D
var _tex_deco   : Texture2D
var _tex_torch  : Texture2D

# ── 对象池 ────────────────────────────────────────────
var _floor_pool  : Array[Sprite2D] = []
var _detail_pool : Array[Sprite2D] = []
var _deco_pool   : Array[Sprite2D] = []
var _torch_pool  : Array[AnimatedSprite2D] = []

var _floor_active  : Dictionary = {}
var _detail_active : Dictionary = {}
var _deco_active   : Dictionary = {}
var _torch_active  : Dictionary = {}

var _camera : Camera2D
var _parallax_particles: CPUParticles2D = null  # 漂浮环境粒子

# ── SpriteFrames 缓存 ─────────────────────────────────
var _torch_frames : SpriteFrames = null

# ── 初始化 ────────────────────────────────────────────
func _ready() -> void:
	_setup_noise()
	_load_textures()
	_build_torch_frames()
	_find_camera()
	_draw_world_border()
	_setup_ambient_particles()
	if DEBUG_LAYER == -1 or DEBUG_LAYER == 3:
		_draw_room_grid()

func _setup_ambient_particles() -> void:
	# #10 漂浮魔法粒子 — 地牢氛围：魔法紫 + 橙焰双色混合
	var p = CPUParticles2D.new()
	p.amount = 40
	p.lifetime = 6.0
	p.explosiveness = 0.0
	p.randomness = 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(800, 450)
	p.direction = Vector2(0.1, -1.0)
	p.spread = 25.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 20.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 3.0
	# 渐变：生成时偏紫，消逝时偏橙（配合火把氛围）
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(0.65, 0.25, 0.9, 0.0))   # 紫色淡入
	gradient.add_point(0.2, Color(0.65, 0.25, 0.9, 0.22))  # 紫色峰值
	gradient.add_point(0.7, Color(0.9, 0.55, 0.2, 0.18))   # 过渡到橙
	gradient.add_point(1.0, Color(0.9, 0.55, 0.2, 0.0))    # 橙色淡出
	p.color_ramp = gradient
	p.z_index = -5
	add_child(p)
	_parallax_particles = p

func _setup_noise() -> void:
	_noise_floor.seed  = 42;   _noise_floor.noise_type  = FastNoiseLite.TYPE_SIMPLEX; _noise_floor.frequency  = 0.08
	_noise_detail.seed = 137;  _noise_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX; _noise_detail.frequency = 0.12
	_noise_deco.seed   = 271;  _noise_deco.noise_type   = FastNoiseLite.TYPE_SIMPLEX; _noise_deco.frequency   = 0.05
	_noise_torch.seed  = 512;  _noise_torch.noise_type  = FastNoiseLite.TYPE_SIMPLEX; _noise_torch.frequency  = 0.04

func _load_textures() -> void:
	# 根据地图主题切换地板贴图
	match map_theme:
		"ice":
			_tex_floor1 = load("res://assets/tilesets/floor_ice.png")
		"lava":
			_tex_floor1 = load("res://assets/tilesets/floor_lava.png")
		_:  # dungeon (default)
			_tex_floor1 = load("res://assets/tilesets/floor_layer1.png")
	_tex_detail = load("res://assets/tilesets/floor_detail_overlay.png")
	_tex_deco   = load("res://assets/tilesets/floor_deco_props.png")
	_tex_torch  = load("res://assets/tilesets/torch_anim.png")

func _build_torch_frames() -> void:
	_torch_frames = SpriteFrames.new()
	_torch_frames.add_animation("burn")
	_torch_frames.set_animation_loop("burn", true)
	_torch_frames.set_animation_speed("burn", 8.0)
	for i in range(TORCH_FRAMES):
		var atlas := AtlasTexture.new()
		atlas.atlas = _tex_torch
		atlas.region = Rect2(i * TORCH_TILE_W, 0, TORCH_TILE_W, TORCH_TILE_H)
		_torch_frames.add_frame("burn", atlas)

func _find_camera() -> void:
	# 不用 await，直接尝试从父节点拿
	var parent = get_parent()
	if parent and parent.get("camera") != null:
		_camera = parent.camera
	if not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_2d()

# ── 每帧更新 ──────────────────────────────────────────
func _process(_delta: float) -> void:
	if not is_instance_valid(_camera):
		var parent = get_parent()
		if parent and parent.get("camera") != null:
			_camera = parent.camera
		if not is_instance_valid(_camera):
			_camera = get_viewport().get_camera_2d()
		if not is_instance_valid(_camera):
			return
	# 粒子跟摄像机，营造漂浮感
	if is_instance_valid(_parallax_particles):
		_parallax_particles.global_position = _camera.global_position
	_update_tiles()

func _update_tiles() -> void:
	var cam_pos := _camera.global_position
	var vp_size := get_viewport_rect().size
	var margin  := DISPLAY * 3

	var x_min := cam_pos.x - vp_size.x * 0.5 - margin
	var x_max := cam_pos.x + vp_size.x * 0.5 + margin
	var y_min := cam_pos.y - vp_size.y * 0.5 - margin
	var y_max := cam_pos.y + vp_size.y * 0.5 + margin

	var col_min := int(floor(x_min / DISPLAY))
	var col_max := int(ceil(x_max  / DISPLAY))
	var row_min := int(floor(y_min / DISPLAY))
	var row_max := int(ceil(y_max  / DISPLAY))
	
	# 调试：每秒打印一次（正式版删除）
	#if Engine.get_process_frames() % 60 == 0:
	#	print("[BG] cam=", cam_pos, " floor_active=", _floor_active.size())

	var world_tiles := int(WORLD_HALF / DISPLAY)
	col_min = clampi(col_min, -world_tiles, world_tiles - 1)
	col_max = clampi(col_max, -world_tiles, world_tiles - 1)
	row_min = clampi(row_min, -world_tiles, world_tiles - 1)
	row_max = clampi(row_max, -world_tiles, world_tiles - 1)

	var needed : Dictionary = {}
	for r in range(row_min, row_max + 1):
		for c in range(col_min, col_max + 1):
			needed[Vector2i(c, r)] = true

	# 回收
	for key in _floor_active.keys():
		if not needed.has(key): _return_floor(_floor_active[key]); _floor_active.erase(key)
	for key in _detail_active.keys():
		if not needed.has(key): _return_detail(_detail_active[key]); _detail_active.erase(key)
	for key in _deco_active.keys():
		if not needed.has(key): _return_deco(_deco_active[key]); _deco_active.erase(key)
	for key in _torch_active.keys():
		if not needed.has(key): _return_torch(_torch_active[key]); _torch_active.erase(key)

	# 生成
	for key in needed.keys():
		var c : int = key.x
		var r : int = key.y
		var wx := c * DISPLAY + DISPLAY * 0.5
		var wy := r * DISPLAY + DISPLAY * 0.5

		# Layer 1（始终显示作为底色）
		if not _floor_active.has(key):
			var sp := _get_floor_sprite()
			_place_floor_tile(sp, c, r, wx, wy)
			_floor_active[key] = sp

		# Layer 2（约30%格子）
		if (DEBUG_LAYER == -1 or DEBUG_LAYER == 2) and not _detail_active.has(key):
			var n := _noise_detail.get_noise_2d(float(c), float(r))
			if n > 0.15:
				var sp := _get_detail_sprite()
				_place_detail_tile(sp, c, r, wx, wy)
				_detail_active[key] = sp

		# Layer 4（约8%，避开房间中心）
		if (DEBUG_LAYER == -1 or DEBUG_LAYER == 4) and not _deco_active.has(key):
			var nd := _noise_deco.get_noise_2d(float(c) * 1.7, float(r) * 1.7)
			var lc := posmod(c, ROOM_TILES)
			var lr := posmod(r, ROOM_TILES)
			var near_center := (lc > 4 and lc < 12 and lr > 4 and lr < 12)
			if nd > 0.55 and not near_center:
				var sp := _get_deco_sprite()
				_place_deco_tile(sp, c, r, wx, wy)
				_deco_active[key] = sp

		# Layer 5：火把（每 TORCH_INTERVAL 格的角落附近，噪声筛选）
		if (DEBUG_LAYER == -1 or DEBUG_LAYER == 5) and not _torch_active.has(key):
			var lc2 := posmod(c, TORCH_INTERVAL)
			var lr2 := posmod(r, TORCH_INTERVAL)
			if lc2 == 1 and lr2 == 1:
				var nt := _noise_torch.get_noise_2d(float(c), float(r))
				if nt > 0.1:
					var sp := _get_torch_sprite()
					_place_torch(sp, wx, wy)
					_torch_active[key] = sp

# ── Layer 1 ───────────────────────────────────────────
func _place_floor_tile(sp: Sprite2D, c: int, r: int, wx: float, wy: float) -> void:
	var n := (_noise_floor.get_noise_2d(float(c), float(r)) + 1.0) * 0.5
	var total_w := 0
	for ww in FLOOR_WEIGHTS: total_w += ww
	var threshold := n * total_w
	var acc := 0
	var chosen := 0
	for i in range(FLOOR_WEIGHTS.size()):
		acc += FLOOR_WEIGHTS[i]
		if threshold <= acc: chosen = i; break

	sp.texture = _tex_floor1
	sp.region_enabled = true
	# 根据贴图类型选择切片方式
	if map_theme == "dungeon":
		# floor_layer1: 横排8tile，每tile 16px
		sp.region_rect = Rect2(chosen * FLOOR_TILE_PX, 0, FLOOR_TILE_PX, FLOOR_TILE_PX)
		sp.scale = Vector2(SCALE_F, SCALE_F)
	else:
		# ice/lava: 4列×2行，每tile 256×128px，共8tile
		var col = chosen % 4
		var row = chosen / 4
		sp.region_rect = Rect2(col * 256, row * 128, 256, 128)
		sp.scale = Vector2(DISPLAY / 256.0, DISPLAY / 128.0)  # 拉伸到64×64显示
	sp.position = Vector2(wx, wy)
	sp.z_index = -10
	sp.modulate = Color(1.0, 1.0, 1.0, 1.0)

# ── Layer 2 ───────────────────────────────────────────
func _place_detail_tile(sp: Sprite2D, c: int, r: int, wx: float, wy: float) -> void:
	var n := (_noise_detail.get_noise_2d(float(c) * 3.1, float(r) * 3.1) + 1.0) * 0.5
	var idx := int(n * DETAIL_TILE_COUNT) % DETAIL_TILE_COUNT
	sp.texture = _tex_detail
	sp.region_enabled = true
	sp.region_rect = Rect2(idx * DETAIL_TILE_PX, 0, DETAIL_TILE_PX, DETAIL_TILE_PX)
	sp.scale = Vector2(DISPLAY / DETAIL_TILE_PX, DISPLAY / DETAIL_TILE_PX)
	sp.position = Vector2(wx, wy)
	sp.z_index = -9
	sp.material = _make_multiply_material()
	sp.modulate = Color(1, 1, 1, lerpf(0.25, 0.45, n))

# ── Layer 4 ───────────────────────────────────────────
func _place_deco_tile(sp: Sprite2D, c: int, r: int, wx: float, wy: float) -> void:
	var n := (_noise_deco.get_noise_2d(float(c) * 5.3, float(r) * 5.3) + 1.0) * 0.5
	var idx := int(n * DECO_TILE_COUNT) % DECO_TILE_COUNT
	sp.texture = _tex_deco
	sp.region_enabled = true
	sp.region_rect = Rect2(idx * DECO_TILE_PX, 0, DECO_TILE_PX, DECO_TILE_PX)
	sp.scale = Vector2(SCALE_F, SCALE_F)
	sp.position = Vector2(wx, wy)
	sp.z_index = -7
	sp.modulate = Color(0.4, 0.35, 0.32, 0.75)

# ── Layer 5 ───────────────────────────────────────────
func _place_torch(sp: AnimatedSprite2D, wx: float, wy: float) -> void:
	sp.sprite_frames = _torch_frames
	sp.animation = "burn"
	sp.scale = Vector2(SCALE_F, SCALE_F)
	sp.position = Vector2(wx, wy)
	sp.z_index = -6
	sp.modulate = Color(1.0, 0.85, 0.6, 0.9)
	sp.play()
	# PointLight2D —— 若还没有则创建并挂到火把上
	if sp.get_node_or_null("TorchLight") == null:
		var light := PointLight2D.new()
		light.name = "TorchLight"
		light.texture = _get_light_texture()
		light.color = Color(1.0, 0.72, 0.3, 1.0)   # 暖橙黄
		light.energy = 1.2
		light.texture_scale = 3.0   # 半径约 ~280px，光圈更大更明显
		light.shadow_enabled = false
		light.z_index = -6
		sp.add_child(light)

# ── Layer 3：房间网格（静态）─────────────────────────
func _draw_room_grid() -> void:
	var world_tiles := int(WORLD_HALF / DISPLAY)
	var start       := -world_tiles * DISPLAY
	var grid_color  := Color(0.18, 0.14, 0.12, 0.55)

	var x := start
	while x <= -start:
		var l := Line2D.new()
		l.add_point(Vector2(x, start)); l.add_point(Vector2(x, -start))
		l.width = 1.5; l.default_color = grid_color; l.z_index = -8
		add_child(l)
		x += ROOM_SIZE

	var y := start
	while y <= -start:
		var l := Line2D.new()
		l.add_point(Vector2(start, y)); l.add_point(Vector2(-start, y))
		l.width = 1.5; l.default_color = grid_color; l.z_index = -8
		add_child(l)
		y += ROOM_SIZE

# ── 世界边界 ──────────────────────────────────────────
func _draw_world_border() -> void:
	var half := 7800.0
	var corners := [Vector2(-half,-half), Vector2(half,-half), Vector2(half,half), Vector2(-half,half), Vector2(-half,-half)]
	var l := Line2D.new()
	for p in corners: l.add_point(p)
	l.width = 4.0; l.default_color = Color(0.9, 0.2, 0.2, 0.8); l.z_index = -9
	add_child(l)

# ── Multiply Material 缓存 ───────────────────────────
var _multiply_mat : CanvasItemMaterial = null
func _make_multiply_material() -> CanvasItemMaterial:
	if _multiply_mat == null:
		_multiply_mat = CanvasItemMaterial.new()
		_multiply_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	return _multiply_mat

# ── PointLight2D 径向渐变纹理缓存 ────────────────────
var _light_tex : ImageTexture = null
func _get_light_texture() -> ImageTexture:
	if _light_tex != null:
		return _light_tex
	# 程序化生成 64×64 径向白→透渐变（PointLight2D 标准格式）
	const SZ := 64
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var center := Vector2(SZ * 0.5, SZ * 0.5)
	for y in range(SZ):
		for x in range(SZ):
			var dist := Vector2(x, y).distance_to(center) / (SZ * 0.5)
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			alpha = alpha * alpha  # 二次衰减，更自然
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	_light_tex = ImageTexture.create_from_image(img)
	return _light_tex

# ── 对象池：地板 ──────────────────────────────────────
func _get_floor_sprite() -> Sprite2D:
	if _floor_pool.size() > 0:
		var sp : Sprite2D = _floor_pool.pop_back()
		sp.visible = true; return sp
	var sp := Sprite2D.new()
	sp.centered = true
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)
	return sp

func _return_floor(sp: Sprite2D) -> void:
	sp.visible = false; _floor_pool.append(sp)

# ── 对象池：细节 ──────────────────────────────────────
func _get_detail_sprite() -> Sprite2D:
	if _detail_pool.size() > 0:
		var sp : Sprite2D = _detail_pool.pop_back()
		sp.visible = true; return sp
	var sp := Sprite2D.new()
	sp.centered = true
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)
	return sp

func _return_detail(sp: Sprite2D) -> void:
	sp.visible = false; _detail_pool.append(sp)

# ── 对象池：装饰 ──────────────────────────────────────
func _get_deco_sprite() -> Sprite2D:
	if _deco_pool.size() > 0:
		var sp : Sprite2D = _deco_pool.pop_back()
		sp.visible = true; return sp
	var sp := Sprite2D.new()
	sp.centered = true
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)
	return sp

func _return_deco(sp: Sprite2D) -> void:
	sp.visible = false; _deco_pool.append(sp)

# ── 对象池：火把 ──────────────────────────────────────
func _get_torch_sprite() -> AnimatedSprite2D:
	if _torch_pool.size() > 0:
		var sp : AnimatedSprite2D = _torch_pool.pop_back()
		sp.visible = true; sp.play(); return sp
	var sp := AnimatedSprite2D.new()
	sp.centered = true
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)
	return sp

func _return_torch(sp: AnimatedSprite2D) -> void:
	sp.stop(); sp.visible = false; _torch_pool.append(sp)
