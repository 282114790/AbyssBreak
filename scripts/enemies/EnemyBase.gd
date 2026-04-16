# EnemyBase.gd
# 所有敌人的基类 — 数据驱动视觉系统 + 动画状态机 + shader 受击反馈
extends CharacterBody2D
class_name EnemyBase

# ── 视觉资源数据库（按 display_name 查找） ──────────────────
const VISUAL_DB := {
	"小恶魔":   {"sheet": "res://assets/sprites/enemies/demon_walk_sheet.png",            "frames": 6,  "fw": 155, "fh": 174, "fps": 8.0,  "dp": 55,  "static": "res://assets/sprites/enemies/enemy_demon.png"},
	"骷髅战士": {"sheet": "res://assets/sprites/enemies/skeleton_walk_sheet.png",          "frames": 10, "fw": 181, "fh": 268, "fps": 10.0, "dp": 65,  "static": "res://assets/sprites/enemies/enemy_skeleton.png"},
	"石头怪":   {"sheet": "res://assets/sprites/enemies/stone_golem_walk_sheet.png",       "frames": 8,  "fw": 222, "fh": 253, "fps": 6.0,  "dp": 80,  "static": "res://assets/sprites/enemies/enemy_golem.png"},
	"暗影弓手": {"sheet": "res://assets/sprites/enemies/archer_walk_sheet.png",            "frames": 7,  "fw": 126, "fh": 170, "fps": 8.0,  "dp": 60,  "static": "res://assets/sprites/enemies/enemy_archer.png"},
	"火焰精灵": {"sheet": "res://assets/sprites/enemies/fire_sprite_walk_sheet.png",       "frames": 7,  "fw": 157, "fh": 143, "fps": 8.0,  "dp": 55,  "static": "res://assets/sprites/enemies/enemy_fire_sprite.png"},
	"深渊魔王": {"sheet": "res://assets/sprites/enemies/boss_walk_sheet.png",              "frames": 6,  "fw": 170, "fh": 172, "fps": 8.0,  "dp": 140, "static": "res://assets/sprites/enemies/enemy_boss_abyss.png"},
	"裂变虫":   {"sheet": "res://assets/sprites/enemies/splitter_walk_sheet.png",          "frames": 6,  "fw": 172, "fh": 168, "fps": 8.0,  "dp": 58},
	"幽影刺客": {"sheet": "res://assets/sprites/enemies/shadow_assassin_walk_sheet.png",   "frames": 6,  "fw": 168, "fh": 168, "fps": 8.0,  "dp": 58},
	"铁盾卫兵": {"sheet": "res://assets/sprites/enemies/shield_guard_walk_sheet.png",      "frames": 6,  "fw": 163, "fh": 173, "fps": 8.0,  "dp": 75},
	"亡灵法师": {"sheet": "res://assets/sprites/enemies/necromancer_walk_sheet.png",       "frames": 6,  "fw": 170, "fh": 168, "fps": 8.0,  "dp": 65},
	"巡逻傀儡": {"sheet": "res://assets/sprites/enemies/patrol_puppet_walk_sheet.png",     "frames": 6,  "fw": 153, "fh": 175, "fps": 8.0,  "dp": 70},
	"深渊骑士": {"sheet": "res://assets/sprites/enemies/abyss_knight_walk_sheet.png",      "frames": 6,  "fw": 169, "fh": 168, "fps": 8.0,  "dp": 140},
	"虚空主宰": {"sheet": "res://assets/sprites/enemies/void_sovereign_walk_sheet.png",    "frames": 6,  "fw": 171, "fh": 173, "fps": 8.0,  "dp": 140},
	"分裂体":   {"sheet": "res://assets/sprites/enemies/split_child_walk_sheet.png",       "frames": 8,  "fw": 128, "fh": 95,  "fps": 8.0,  "dp": 48},
	"仆从":     {"sheet": "res://assets/sprites/enemies/minion_walk_sheet.png",            "frames": 6,  "fw": 146, "fh": 156, "fps": 8.0,  "dp": 48},
	"深渊仆从": {"sheet": "res://assets/sprites/enemies/abyss_minion_walk_sheet.png",      "frames": 6,  "fw": 142, "fh": 176, "fps": 8.0,  "dp": 50},
}

# ── 动画状态 ──────────────────────────────────────────────
enum AnimState { IDLE, WALK, ATTACK, HURT, DEATH }
var _anim_state: AnimState = AnimState.IDLE
var _anim_state_timer: float = 0.0
var _base_scale: Vector2 = Vector2.ONE

var data: EnemyData
var hp: float = 30.0
var player: Node2D = null
var attack_timer: float = 0.0
var is_dead: bool = false

# 减速状态（寒冰领域等技能使用）
var is_slowed: bool = false
var base_move_speed: float = 0.0

# 视觉节点
var visual: AnimatedSprite2D
var hp_bar: ColorRect
var hp_bar_bg: ColorRect

func _ready() -> void:
	add_to_group("enemies")
	_find_player()

func setup(enemy_data: EnemyData) -> void:
	data = enemy_data
	hp = data.max_hp
	base_move_speed = data.move_speed
	_setup_visual()

# ── 视觉系统（数据驱动） ──────────────────────────────────
func _setup_visual() -> void:
	collision_layer = 2
	collision_mask = 1

	# 从 VISUAL_DB 填充未设置的视觉字段
	if data and data.walk_sheet_path == "":
		var vdb: Dictionary = VISUAL_DB.get(data.display_name, {})
		if vdb.size() > 0:
			data.walk_sheet_path = vdb.get("sheet", "")
			data.walk_frames = vdb.get("frames", 6)
			data.walk_frame_w = vdb.get("fw", 170)
			data.walk_frame_h = vdb.get("fh", 168)
			data.walk_fps = vdb.get("fps", 8.0)
			data.static_sprite_path = vdb.get("static", "")
			if vdb.has("dp") and data.display_scale <= 0:
				data.display_scale = vdb["dp"]

	var anim_sprite = AnimatedSprite2D.new()
	anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	var has_visual := false
	if data and data.walk_sheet_path != "":
		has_visual = _build_spritesheet_anim(anim_sprite)
	if not has_visual and data and data.static_sprite_path != "":
		has_visual = _build_static_anim(anim_sprite)
	if not has_visual:
		_build_procedural_anim(anim_sprite)

	add_child(anim_sprite)
	visual = anim_sprite

	# 默认 hit_flash shader（普通怪用，精英/Boss 会被 _apply_enemy_style 替换）
	var hit_shader = load("res://assets/shaders/hit_flash.gdshader")
	if hit_shader:
		var mat = ShaderMaterial.new()
		mat.shader = hit_shader
		mat.set_shader_parameter("flash_intensity", 0.0)
		mat.set_shader_parameter("flash_color", Color.WHITE)
		visual.material = mat

	# 血条
	var is_boss = data and data.exp_reward >= 50
	hp_bar_bg = ColorRect.new()
	hp_bar_bg.size = Vector2(30, 4)
	hp_bar_bg.position = Vector2(-15, -30)
	hp_bar_bg.color = Color(0.2, 0.0, 0.0)
	hp_bar_bg.visible = not is_boss
	add_child(hp_bar_bg)
	hp_bar = ColorRect.new()
	hp_bar.size = Vector2(30, 4)
	hp_bar.position = Vector2(-15, -30)
	hp_bar.color = Color(0.0, 0.9, 0.2)
	hp_bar.visible = not is_boss
	add_child(hp_bar)

	# 碰撞体
	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	var sz = data.size if data else 16.0
	rect.size = Vector2(sz, sz)
	col.shape = rect
	add_child(col)

	_apply_enemy_style()
	_base_scale = scale

	# Boss 自动挂载三阶段控制器
	if is_boss:
		var bc = Node.new()
		bc.set_script(load("res://scripts/enemies/BossController.gd"))
		bc.name = "BossController"
		add_child(bc)

# ── Spritesheet 动画构建 ──────────────────────────────────
func _build_spritesheet_anim(sprite: AnimatedSprite2D) -> bool:
	var tex = load(data.walk_sheet_path)
	if tex == null:
		push_error("EnemyBase: 找不到贴图 " + data.walk_sheet_path)
		return false
	var sf = SpriteFrames.new()

	sf.add_animation("walk")
	sf.set_animation_loop("walk", true)
	sf.set_animation_speed("walk", data.walk_fps)
	for i in range(data.walk_frames):
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * data.walk_frame_w, 0, data.walk_frame_w, data.walk_frame_h)
		atlas.filter_clip = true
		sf.add_frame("walk", atlas)

	sf.add_animation("idle")
	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", 1.0)
	var idle_atlas = AtlasTexture.new()
	idle_atlas.atlas = tex
	idle_atlas.region = Rect2(0, 0, data.walk_frame_w, data.walk_frame_h)
	idle_atlas.filter_clip = true
	sf.add_frame("idle", idle_atlas)

	sf.add_animation("attack")
	sf.set_animation_loop("attack", false)
	sf.set_animation_speed("attack", data.walk_fps * 2.0)
	for i in range(mini(3, data.walk_frames)):
		var a = AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * data.walk_frame_w, 0, data.walk_frame_w, data.walk_frame_h)
		a.filter_clip = true
		sf.add_frame("attack", a)

	sprite.sprite_frames = sf
	var display_px: float
	if data.display_scale > 0:
		display_px = data.display_scale
	elif data.exp_reward >= 50:
		display_px = 128.0
	else:
		display_px = data.size * 3.0
	sprite.scale = Vector2(display_px / data.walk_frame_h, display_px / data.walk_frame_h)
	sprite.play("walk")
	return true

# ── 静态图单帧构建 ──────────────────────────────────────
func _build_static_anim(sprite: AnimatedSprite2D) -> bool:
	var tex = load(data.static_sprite_path)
	if tex == null: return false
	var sf = SpriteFrames.new()
	for anim_name in ["idle", "walk", "attack"]:
		sf.add_animation(anim_name)
		sf.set_animation_loop(anim_name, true)
		sf.set_animation_speed(anim_name, 1.0)
		sf.add_frame(anim_name, tex)
	sprite.sprite_frames = sf
	var display_px = data.size * 3.0
	var tex_size = float(max(tex.get_width(), tex.get_height()))
	sprite.scale = Vector2(display_px / tex_size, display_px / tex_size)
	sprite.play("idle")
	return true

# ── 程序化图形兜底（按 MoveType 绘制特征形状） ──────────
func _build_procedural_anim(sprite: AnimatedSprite2D) -> void:
	var mt = data.move_type if data else EnemyData.MoveType.CHASE
	var col = data.color if data else Color(0.8, 0.2, 0.2)
	var tex = _generate_shape_texture(mt, col)
	var sf = SpriteFrames.new()
	for anim_name in ["idle", "walk", "attack"]:
		sf.add_animation(anim_name)
		sf.set_animation_loop(anim_name, true)
		sf.set_animation_speed(anim_name, 1.0)
		sf.add_frame(anim_name, tex)
	sprite.sprite_frames = sf
	var display_px = (data.size if data else 16.0) * 3.0
	sprite.scale = Vector2(display_px / 64.0, display_px / 64.0)
	sprite.play("idle")

static var _procedural_cache: Dictionary = {}

static func _generate_shape_texture(move_type: int, color: Color, sz: int = 64) -> ImageTexture:
	var key = "%d_%s" % [move_type, color.to_html()]
	if _procedural_cache.has(key):
		return _procedural_cache[key]

	var img = Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var cx: float = sz * 0.5
	var cy: float = sz * 0.5
	var r: float = sz * 0.4

	match move_type:
		EnemyData.MoveType.TANK:
			for y in range(sz):
				for x in range(sz):
					var dx = absf(x - cx)
					var dy = absf(y - cy)
					var corner = maxf(dx - r + 8, 0) + maxf(dy - r + 8, 0)
					if dx < r and dy < r and corner < 8:
						img.set_pixel(x, y, color)

		EnemyData.MoveType.RANGED, EnemyData.MoveType.PATROL:
			for y in range(sz):
				for x in range(sz):
					if absf(x - cx) + absf(y - cy) < r:
						img.set_pixel(x, y, color)

		EnemyData.MoveType.TELEPORTER:
			for y in range(sz):
				for x in range(sz):
					var ny = (float(y) - (cy - r)) / (r * 2.0)
					if ny >= 0.0 and ny <= 1.0 and absf(x - cx) < ny * r:
						img.set_pixel(x, y, Color(color.r, color.g, color.b, 0.7))

		EnemyData.MoveType.SPLITTER:
			var c1x = cx - r * 0.3
			var c2x = cx + r * 0.3
			var sr = r * 0.6
			for y in range(sz):
				for x in range(sz):
					var d1 = sqrt((x - c1x) * (x - c1x) + (y - cy) * (y - cy))
					var d2 = sqrt((x - c2x) * (x - c2x) + (y - cy) * (y - cy))
					if d1 < sr or d2 < sr:
						img.set_pixel(x, y, color)

		EnemyData.MoveType.SHIELDER:
			for y in range(sz):
				for x in range(sz):
					var dx = absf(x - cx)
					var dy = absf(y - cy)
					if dx < r * 0.8 and dy < r:
						img.set_pixel(x, y, color)
			var shield_col = Color(0.5, 0.7, 1.0)
			for y in range(int(cy - r), int(cy + r)):
				for x in range(int(cx + r * 0.8), mini(int(cx + r * 0.8 + 5), sz)):
					if y >= 0 and y < sz:
						img.set_pixel(x, y, shield_col)

		EnemyData.MoveType.SUMMONER:
			for y in range(sz):
				for x in range(sz):
					var dist = sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy))
					if dist < r * 0.55:
						img.set_pixel(x, y, color)
					elif dist > r * 0.75 and dist < r * 0.95:
						img.set_pixel(x, y, Color(color.r, color.g, color.b, 0.5))

		EnemyData.MoveType.EXPLODE:
			for y in range(sz):
				for x in range(sz):
					var dx = x - cx
					var dy = y - cy
					var dist = sqrt(dx * dx + dy * dy)
					var angle = atan2(dy, dx)
					var spike = r * (0.6 + 0.4 * absf(sin(angle * 4.0)))
					if dist < spike:
						img.set_pixel(x, y, color)

		_:
			for y in range(sz):
				for x in range(sz):
					if sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)) < r:
						img.set_pixel(x, y, color)

	var tex = ImageTexture.create_from_image(img)
	_procedural_cache[key] = tex
	return tex

# ── 动画状态切换 ──────────────────────────────────────────
func _set_anim_state(new_state: AnimState, duration: float = 0.0) -> void:
	if _anim_state == AnimState.DEATH: return
	_anim_state = new_state
	_anim_state_timer = duration
	if not visual or not visual.sprite_frames: return
	match new_state:
		AnimState.IDLE:
			if visual.sprite_frames.has_animation("idle"):
				visual.play("idle")
		AnimState.WALK:
			if visual.sprite_frames.has_animation("walk"):
				if visual.animation != "walk":
					visual.play("walk")
		AnimState.ATTACK:
			if visual.sprite_frames.has_animation("attack"):
				visual.play("attack")

# ── 精英 / Boss 视觉区分 ─────────────────────────────────
func _apply_enemy_style() -> void:
	if not data or not visual: return
	var is_elite = data.is_elite
	var is_boss = data.exp_reward >= 50

	if is_elite:
		scale = Vector2(1.3, 1.3)
		if hp_bar: hp_bar.color = Color(1.0, 0.55, 0.1)
		var star = Label.new()
		star.text = "★"
		star.add_theme_font_size_override("font_size", 14)
		star.add_theme_color_override("font_color", Color(1.0, 0.75, 0.1))
		star.position = Vector2(-6, -44)
		add_child(star)
		var tw = create_tween().set_loops()
		tw.tween_property(star, "modulate:a", 0.4, 0.6)
		tw.tween_property(star, "modulate:a", 1.0, 0.6)

	elif is_boss:
		var fog = GPUParticles2D.new()
		fog.amount = 6
		fog.lifetime = 1.5
		fog.local_coords = false
		fog.z_index = -1
		var pm = ParticleProcessMaterial.new()
		pm.direction = Vector3(0, -1, 0)
		pm.spread = 40.0
		pm.initial_velocity_min = 5.0
		pm.initial_velocity_max = 15.0
		pm.gravity = Vector3(0, -10, 0)
		pm.scale_min = 8.0
		pm.scale_max = 16.0
		var g = Gradient.new()
		g.set_color(0, Color(0.4, 0.1, 0.6, 0.35))
		g.set_color(1, Color(0.2, 0.05, 0.3, 0.0))
		var gt = GradientTexture1D.new()
		gt.gradient = g
		pm.color_ramp = gt
		fog.process_material = pm
		fog.position = Vector2(0, data.size * 0.5)
		add_child(fog)

	else:
		if data.color != Color.WHITE:
			visual.modulate = data.color.lerp(Color.WHITE, 0.55)

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")

# ── 物理处理 ──────────────────────────────────────────────
var _lod_frame: int = 0

func _physics_process(delta: float) -> void:
	if is_dead or not is_instance_valid(player):
		return
	if EventBus.game_logic_paused:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	_lod_frame += 1
	var on_screen = _is_on_screen()
	if not on_screen and _lod_frame % 3 != 0:
		move_and_slide()
		return
	if _anim_state_timer > 0:
		_anim_state_timer -= delta
		if _anim_state_timer <= 0 and _anim_state in [AnimState.ATTACK, AnimState.HURT]:
			_set_anim_state(AnimState.WALK)
	attack_timer -= delta
	_move(delta)
	_try_attack()
	move_and_slide()

func _is_on_screen() -> bool:
	var vp = get_viewport()
	if not vp: return true
	var vp_rect = vp.get_visible_rect()
	var cam = get_viewport().get_camera_2d()
	if not cam: return true
	var screen_pos = global_position - cam.global_position + vp_rect.size * 0.5
	return vp_rect.grow(120).has_point(screen_pos)

# ── 移动 ──────────────────────────────────────────────────
var _explode_triggered: bool = false
var _ranged_preferred_dist: float = 250.0
var _teleport_timer: float = 0.0
var _summon_timer: float = 0.0
var _patrol_angle: float = 0.0
var _shield_facing: Vector2 = Vector2.RIGHT

func _move(delta: float) -> void:
	var dir = global_position.direction_to(player.global_position)
	var dist = global_position.distance_to(player.global_position)

	match data.move_type:
		EnemyData.MoveType.RANGED:
			if dist < _ranged_preferred_dist * 0.7:
				velocity = -dir * base_move_speed
			elif dist > _ranged_preferred_dist * 1.3:
				velocity = dir * base_move_speed
			else:
				var strafe = Vector2(-dir.y, dir.x)
				velocity = strafe * base_move_speed * 0.6
		EnemyData.MoveType.EXPLODE:
			if dist > data.size + 40:
				velocity = dir * base_move_speed * 1.4
			else:
				velocity = dir * base_move_speed * 0.5
		EnemyData.MoveType.TELEPORTER:
			_teleport_timer -= delta
			if _teleport_timer <= 0:
				_teleport_timer = randf_range(2.5, 4.0)
				var tp_dir = dir * min(dist - 30, 150.0)
				global_position += tp_dir
				if visual:
					visual.modulate.a = 0.3
					var tw = create_tween()
					tw.tween_property(visual, "modulate:a", 1.0, 0.2)
			velocity = dir * base_move_speed * 0.4
		EnemyData.MoveType.SHIELDER:
			_shield_facing = dir
			velocity = dir * base_move_speed
		EnemyData.MoveType.SUMMONER:
			if dist < 250:
				velocity = -dir * base_move_speed * 0.6
			else:
				velocity = dir * base_move_speed * 0.3
			_summon_timer -= delta
			if _summon_timer <= 0:
				_summon_timer = 6.0
				_do_summon()
		EnemyData.MoveType.PATROL:
			_patrol_angle += delta * 0.8
			var patrol_dir = Vector2(cos(_patrol_angle), sin(_patrol_angle))
			velocity = patrol_dir * base_move_speed
		EnemyData.MoveType.SPLITTER:
			velocity = dir * base_move_speed
		_:
			velocity = dir * base_move_speed

	if visual and dir.x != 0:
		visual.flip_h = dir.x < 0
	if _anim_state != AnimState.ATTACK and _anim_state != AnimState.HURT and _anim_state != AnimState.DEATH:
		if velocity.length_squared() > 1.0:
			if _anim_state != AnimState.WALK:
				_set_anim_state(AnimState.WALK)
		else:
			if _anim_state != AnimState.IDLE:
				_set_anim_state(AnimState.IDLE)

# ── 攻击 ──────────────────────────────────────────────────
func _try_attack() -> void:
	if attack_timer > 0:
		return
	var dist = global_position.distance_to(player.global_position)

	match data.move_type:
		EnemyData.MoveType.RANGED:
			if dist < data.attack_range + 50 and dist > 30:
				attack_timer = data.attack_cooldown
				_set_anim_state(AnimState.ATTACK, 0.3)
				_fire_projectile()
		EnemyData.MoveType.EXPLODE:
			if dist < data.size + 40 and not _explode_triggered:
				_explode_triggered = true
				_do_explode()
		_:
			if dist < data.size + 16:
				attack_timer = data.attack_cooldown
				_set_anim_state(AnimState.ATTACK, 0.3)
				player.take_damage(data.damage)

func _fire_projectile() -> void:
	var dir = global_position.direction_to(player.global_position)
	var bullet = Area2D.new()
	bullet.name = "EnemyBullet"
	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 6.0
	col.shape = circle
	bullet.add_child(col)
	var dot = ColorRect.new()
	dot.size = Vector2(8, 8)
	dot.position = Vector2(-4, -4)
	dot.color = data.color
	bullet.add_child(dot)
	bullet.collision_layer = 0
	bullet.collision_mask = 1
	bullet.set_meta("dir", dir)
	bullet.set_meta("spd", 220.0)
	bullet.set_meta("dmg", data.damage)
	bullet.set_meta("timer", 0.0)
	bullet.set_meta("lifetime", 3.0)
	bullet.set_script(_get_bullet_script())
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position

func _get_bullet_script() -> GDScript:
	if _bullet_script_cache == null:
		_bullet_script_cache = GDScript.new()
		_bullet_script_cache.source_code = """extends Area2D

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(get_meta("dmg", 0))
		queue_free()

func _physics_process(delta):
	var t = get_meta("timer", 0.0) + delta
	set_meta("timer", t)
	if t > get_meta("lifetime", 3.0):
		queue_free()
		return
	global_position += get_meta("dir", Vector2.RIGHT) * get_meta("spd", 220.0) * delta
"""
		_bullet_script_cache.reload()
	return _bullet_script_cache

static var _bullet_script_cache: GDScript = null

func _do_explode() -> void:
	var explode_radius := data.size * 4.0
	var p = get_tree().get_first_node_in_group("player")
	if is_instance_valid(p):
		var dist = global_position.distance_to(p.global_position)
		if dist < explode_radius:
			p.take_damage(data.damage * 2.0)
	var ring = ColorRect.new()
	var ring_size = explode_radius * 2
	ring.size = Vector2(ring_size, ring_size)
	ring.position = Vector2(-explode_radius, -explode_radius)
	ring.color = Color(1.0, 0.4, 0.1, 0.6)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ring)
	var tw = create_tween()
	tw.tween_property(ring, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): die())

# ── 受击（Shader 驱动分级反馈） ───────────────────────────
func take_damage(dmg: float, is_crit: bool = false) -> void:
	if is_dead: return
	var was_shielded := false
	if data and data.move_type == EnemyData.MoveType.SHIELDER:
		var p = get_tree().get_first_node_in_group("player")
		if is_instance_valid(p):
			var attack_dir = (global_position - p.global_position).normalized()
			if _shield_facing.dot(attack_dir) < -0.3:
				dmg *= 0.2
				was_shielded = true
				EventBus.emit_signal("pickup_float_text",
					global_position + Vector2(0, -25), "护盾！", Color(0.5, 0.5, 0.8))
	if data and data.armor > 0:
		dmg = max(dmg - data.armor, 1.0)
	hp -= dmg
	_update_hp_bar()

	# Shader flash（hit_flash 和 character_outline 均支持 flash_intensity）
	var flash_i: float
	var flash_c: Color
	var flash_dur: float
	if was_shielded:
		flash_i = 0.5; flash_c = Color(0.5, 0.7, 1.0); flash_dur = 0.1
	elif is_crit:
		flash_i = 1.0; flash_c = Color(1.0, 0.9, 0.2); flash_dur = 0.18
	else:
		flash_i = 0.8; flash_c = Color.WHITE; flash_dur = 0.12
	if visual and visual.material:
		visual.material.set_shader_parameter("flash_intensity", flash_i)
		visual.material.set_shader_parameter("flash_color", flash_c)
		var flash_tw = create_tween()
		flash_tw.tween_method(func(v: float):
			if is_instance_valid(visual) and visual.material:
				visual.material.set_shader_parameter("flash_intensity", v)
		, flash_i, 0.0, flash_dur)

	# Scale bounce
	var bounce = 1.3 if is_crit else 1.15
	var hit_tween = create_tween().set_parallel(true)
	hit_tween.tween_property(self, "scale", _base_scale * bounce, 0.05)
	hit_tween.tween_property(self, "scale", _base_scale, 0.1).set_delay(0.05)

	# Knockback
	var p2 = get_tree().get_first_node_in_group("player")
	if is_instance_valid(p2):
		var kb_dir = (global_position - p2.global_position).normalized()
		global_position += kb_dir * (5.0 if is_crit else 3.0)

	var snd = get_tree().get_first_node_in_group("sound_manager")
	if snd: snd.play_hit()

	_set_anim_state(AnimState.HURT, 0.15)

	if is_crit:
		EventBus.emit_signal("pickup_float_text",
			global_position + Vector2(randf_range(-10, 10), -20),
			"✦ 暴击 %d" % int(dmg),
			Color(1.0, 0.85, 0.1))
	if hp <= 0:
		die()

func _update_hp_bar() -> void:
	if not hp_bar or not hp_bar.visible: return
	var ratio = max(hp / data.max_hp, 0.0)
	hp_bar.size.x = 30 * ratio

# ── 死亡（带缩小淡出动画） ────────────────────────────────
func die() -> void:
	if is_dead: return
	is_dead = true
	_anim_state = AnimState.DEATH

	var snd = get_tree().get_first_node_in_group("sound_manager")
	if snd: snd.play_enemy_die()

	var fx = Node2D.new()
	fx.set_script(load("res://scripts/systems/DeathEffect.gd"))
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position
	fx.setup(data.color if data else Color(0.8, 0.2, 0.2))

	if visual:
		var death_tw = create_tween().set_parallel(true)
		death_tw.tween_property(visual, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN)
		death_tw.tween_property(visual, "modulate:a", 0.0, 0.2)

	if data and data.move_type == EnemyData.MoveType.SPLITTER and not data.is_elite:
		_spawn_split_children()

	var is_elite_flag = data.is_elite if data else false
	var is_boss_flag = (data.exp_reward >= 50) if data else false
	if (is_elite_flag or is_boss_flag) and get_tree().current_scene.has_method("_drop_relic_at"):
		get_tree().current_scene._drop_relic_at(global_position)

	EventBus.emit_signal("enemy_died", global_position, data.exp_reward if data else 5)

	var free_tw = create_tween()
	free_tw.tween_interval(0.25)
	free_tw.tween_callback(queue_free)

func _spawn_split_children() -> void:
	var count = randi_range(2, 3)
	for i in range(count):
		var child = CharacterBody2D.new()
		child.set_script(load("res://scripts/enemies/EnemyBase.gd"))
		child.add_to_group("enemies")
		get_tree().current_scene.add_child(child)
		var ed = EnemyData.new()
		ed.display_name = "分裂体"
		ed.max_hp = data.max_hp * 0.3
		ed.damage = data.damage * 0.5
		ed.move_speed = data.move_speed * 1.3
		ed.size = data.size * 0.6
		ed.color = data.color.lightened(0.3)
		ed.exp_reward = max(data.exp_reward / 3, 1)
		ed.attack_cooldown = data.attack_cooldown
		ed.move_type = EnemyData.MoveType.CHASE
		child.setup(ed)
		var offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
		child.global_position = global_position + offset

func _do_summon() -> void:
	if not is_instance_valid(player): return
	var count = randi_range(2, 3)
	for i in range(count):
		var minion = CharacterBody2D.new()
		minion.set_script(load("res://scripts/enemies/EnemyBase.gd"))
		minion.add_to_group("enemies")
		get_tree().current_scene.add_child(minion)
		var ed = EnemyData.new()
		ed.display_name = "仆从"
		ed.max_hp = data.max_hp * 0.2
		ed.damage = data.damage * 0.4
		ed.move_speed = 80.0
		ed.size = 10.0
		ed.color = data.color.lightened(0.2)
		ed.exp_reward = 2
		ed.attack_cooldown = 1.5
		ed.move_type = EnemyData.MoveType.CHASE
		minion.setup(ed)
		var offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
		minion.global_position = global_position + offset
