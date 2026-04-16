@tool
# SkillOrbital.gd
# 元素壁垒 — 环形魔法壁垒围绕玩家旋转，多层同心环，击退敌人并叠加减伤buff
extends SkillBase
class_name SkillOrbital

const FRAME_COUNT := 4
const FRAME_SIZE := 128
const SHEET_PATH := "res://assets/sprites/effects/skills/barrier_ring_sheet.png"

# 每层环的配置: [半径, 旋转方向(1=顺时针,-1=逆时针), 速度系数, 缩放]
const RING_CONFIGS := [
	[90.0,   1.0, 1.0,  0.7],
	[140.0, -1.0, 0.75, 0.9],
	[185.0,  1.0, 0.55, 1.1],
]

var _rings: Array = []           # [{node, radius, dir, speed_mult, scale_val, angle}]
var _hit_cooldowns: Dictionary = {}
var _sheet_tex: Texture2D = null
var _frame_textures: Array = []

# 减伤 buff 管理
var _dr_stacks: int = 0
var _dr_timers: Array = []       # 每层 buff 的剩余时间
const DR_PER_STACK := 0.15
const DR_MAX_STACKS := 3
const DR_DURATION := 2.0

# 击退力（随等级增长）
const BASE_KNOCKBACK := 150.0
const KNOCKBACK_PER_LEVEL := 26.0

# 环厚度：判定敌人是否在环形区域内的容差
const RING_HALF_WIDTH := 28.0

func _ready() -> void:
	_ensure_textures()
	call_deferred("_rebuild_rings")

func _ensure_textures() -> void:
	if _sheet_tex != null:
		return
	_sheet_tex = load(SHEET_PATH)
	if _sheet_tex == null:
		return
	_frame_textures.clear()
	for i in range(FRAME_COUNT):
		var atlas = AtlasTexture.new()
		atlas.atlas = _sheet_tex
		atlas.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
		atlas.filter_clip = true
		_frame_textures.append(atlas)

func _get_ring_count() -> int:
	if level >= 5:
		return 3
	elif level >= 3:
		return 2
	return 1

func _get_base_speed() -> float:
	return 2.5 + (level - 1) * 0.25

func _rebuild_rings() -> void:
	for r in _rings:
		if is_instance_valid(r["node"]):
			r["node"].queue_free()
	_rings.clear()

	var count = _get_ring_count()
	for i in range(count):
		var cfg = RING_CONFIGS[i]
		var radius: float = cfg[0] + (level - 1) * 5.0
		var dir: float = cfg[1]
		var speed_mult: float = cfg[2]
		var scale_val: float = cfg[3] + (level - 1) * 0.03

		var ring_node = Node2D.new()
		ring_node.name = "Ring_%d" % i

		var anim = AnimatedSprite2D.new()
		anim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if _frame_textures.size() == FRAME_COUNT:
			var sf = SpriteFrames.new()
			sf.add_animation("pulse")
			sf.set_animation_loop("pulse", true)
			sf.set_animation_speed("pulse", 8.0)
			for f in _frame_textures:
				sf.add_frame("pulse", f)
			anim.sprite_frames = sf
			anim.play("pulse")
		anim.scale = Vector2(scale_val, scale_val)
		# 外层环略微透明，形成层次
		var alpha = 1.0 - i * 0.15
		anim.modulate = Color(1.0, 1.0, 1.0, alpha)
		ring_node.add_child(anim)

		# 轻微粒子拖尾
		var trail = GPUParticles2D.new()
		trail.emitting = true
		trail.amount = 6
		trail.lifetime = 0.35
		trail.local_coords = false
		var pm = ParticleProcessMaterial.new()
		pm.direction = Vector3.ZERO
		pm.spread = 180.0
		pm.initial_velocity_min = 0.0
		pm.initial_velocity_max = 8.0
		pm.gravity = Vector3.ZERO
		pm.scale_min = 1.5
		pm.scale_max = 3.5
		var g = Gradient.new()
		g.set_color(0, Color(0.4, 0.6, 1.0, 0.5))
		g.set_color(1, Color(0.2, 0.3, 0.8, 0.0))
		var gt = GradientTexture1D.new()
		gt.gradient = g
		pm.color_ramp = gt
		trail.process_material = pm
		ring_node.add_child(trail)

		add_child(ring_node)
		_rings.append({
			"node": ring_node,
			"anim": anim,
			"radius": radius,
			"dir": dir,
			"speed_mult": speed_mult,
			"scale_val": scale_val,
			"angle": TAU / count * i,
		})

func activate() -> void:
	pass

func _process(delta: float) -> void:
	if EventBus.game_logic_paused:
		return
	if not is_instance_valid(owner_player):
		return

	var base_speed = _get_base_speed()
	var player_pos = owner_player.global_position

	for r in _rings:
		if not is_instance_valid(r["node"]):
			continue
		r["angle"] += base_speed * r["dir"] * r["speed_mult"] * delta
		# 环的中心放在玩家位置，视觉节点绕圈放置只是为了让旋转看起来自然
		# 实际上整个环跟随玩家，通过旋转角度实现视觉效果
		r["node"].global_position = player_pos
		r["node"].rotation = r["angle"]

	# 减伤 buff 衰减
	_update_dr_timers(delta)

func _physics_process(delta: float) -> void:
	if EventBus.game_logic_paused:
		return
	if not is_instance_valid(owner_player):
		return

	# hit cooldown 衰减
	for k in _hit_cooldowns.keys():
		_hit_cooldowns[k] -= delta
		if _hit_cooldowns[k] <= 0:
			_hit_cooldowns.erase(k)

	var player_pos = owner_player.global_position
	var enemies = _get_enemies()
	var knockback_force = BASE_KNOCKBACK + (level - 1) * KNOCKBACK_PER_LEVEL

	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var uid = enemy.get_instance_id()
		if _hit_cooldowns.get(uid, 0.0) > 0.0:
			continue

		var dist = player_pos.distance_to(enemy.global_position)

		# 检查敌人是否在任一环的区域内
		var hit_ring_idx := -1
		for i in range(_rings.size()):
			var r = _rings[i]
			var ring_r: float = r["radius"]
			if abs(dist - ring_r) < RING_HALF_WIDTH:
				hit_ring_idx = i
				break

		if hit_ring_idx < 0:
			continue

		# 命中
		_hit_cooldowns[uid] = 0.5
		deal_damage(enemy)

		# 击退
		var kb_dir = (enemy.global_position - player_pos).normalized()
		if kb_dir == Vector2.ZERO:
			kb_dir = Vector2.RIGHT.rotated(randf() * TAU)
		enemy.velocity += kb_dir * knockback_force

		# 叠加减伤 buff
		_add_dr_stack()

		# 环闪白
		_flash_ring(hit_ring_idx)

		# 冲击波环
		_spawn_impact_wave(enemy.global_position, _rings[hit_ring_idx]["radius"] * 0.3)

func _add_dr_stack() -> void:
	if _dr_stacks < DR_MAX_STACKS:
		_dr_stacks += 1
		_dr_timers.append(DR_DURATION)
	else:
		# 刷新最旧的一层
		if _dr_timers.size() > 0:
			_dr_timers[0] = DR_DURATION
	_apply_dr()

func _update_dr_timers(delta: float) -> void:
	var changed := false
	var i = _dr_timers.size() - 1
	while i >= 0:
		_dr_timers[i] -= delta
		if _dr_timers[i] <= 0:
			_dr_timers.remove_at(i)
			_dr_stacks = max(_dr_stacks - 1, 0)
			changed = true
		i -= 1
	if changed:
		_apply_dr()

func _apply_dr() -> void:
	if is_instance_valid(owner_player):
		owner_player.barrier_dr = _dr_stacks * DR_PER_STACK

func _flash_ring(idx: int) -> void:
	if idx < 0 or idx >= _rings.size():
		return
	var r = _rings[idx]
	var anim_node: AnimatedSprite2D = r["anim"]
	if not is_instance_valid(anim_node):
		return
	anim_node.modulate = Color(2.5, 2.5, 2.5, 1.0)
	var tw = create_tween()
	var alpha = 1.0 - idx * 0.15
	tw.tween_property(anim_node, "modulate", Color(1.0, 1.0, 1.0, alpha), 0.2)

func _spawn_impact_wave(pos: Vector2, radius: float) -> void:
	var wave = Line2D.new()
	wave.width = 2.0
	wave.default_color = Color(0.5, 0.7, 1.0, 0.7)
	for i in range(25):
		var a = (TAU / 24.0) * i
		wave.add_point(Vector2(cos(a) * 5, sin(a) * 5))
	wave.z_index = 7
	_get_spawn_root().add_child(wave)
	wave.global_position = pos
	var tw = wave.create_tween()
	tw.set_parallel(true)
	tw.tween_property(wave, "scale", Vector2(radius / 5.0, radius / 5.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(wave, "modulate:a", 0.0, 0.22)
	tw.tween_callback(wave.queue_free).set_delay(0.22)

	var spark = GPUParticles2D.new()
	spark.emitting = false
	spark.amount = 8
	spark.lifetime = 0.25
	spark.explosiveness = 0.95
	spark.one_shot = true
	spark.local_coords = false
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 30.0
	pm.initial_velocity_max = 80.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 1.5
	pm.scale_max = 3.5
	var g = Gradient.new()
	g.set_color(0, Color(0.6, 0.8, 1.0, 0.9))
	g.set_color(1, Color(0.3, 0.5, 1.0, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	spark.process_material = pm
	_get_spawn_root().add_child(spark)
	spark.global_position = pos
	spark.emitting = true
	get_tree().create_timer(0.4).timeout.connect(spark.queue_free)

func on_level_up() -> void:
	_rebuild_rings()

func _exit_tree() -> void:
	if is_instance_valid(owner_player):
		owner_player.barrier_dr = 0.0
