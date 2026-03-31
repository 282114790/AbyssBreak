# Player.gd
# 玩家控制脚本
extends CharacterBody2D
class_name Player

# 基础属性
@export var base_max_hp: float = 1000.0
@export var base_move_speed: float = 240.0
@export var base_pickup_radius: float = 120.0

# 当前属性（被动加成后）
var max_hp: float = 1000.0
var current_hp: float = 1000.0
var move_speed: float = 220.0
var pickup_radius: float = 120.0
var damage_multiplier: float = 1.0
var attack_speed_multiplier: float = 1.0
var exp_multiplier: float = 1.0
var regen_per_second: float = 0.0

# 等级/经验
var level: int = 1
var current_exp: int = 0
var exp_to_next: int = 50
var total_score: int = 0

# 技能系统
var skills: Array = []           # 已装备的技能实例
var max_skill_slots: int = 6
var passive_ids: Array = []      # 已拥有的被动id列表

# 遗物系统
var relic_ids: Array = []        # 已拥有的遗物id列表
var crit_chance: float = 0.05    # 暴击率（默认5%）
var crit_mult: float = 1.5       # 暴击倍率（默认1.5倍）

# 诅咒系统
var curse_ids: Array = []        # 已接受的诅咒id列表
var heal_disabled: bool = false  # 诅咒：无法回血

# 内部
var regen_timer: float = 0.0
var is_showing_upgrade: bool = false  # 升级面板开关锁
var pickup_timer: float = 0.0
var is_dead: bool = false
var visual: AnimatedSprite2D

# 翻滚/闪避
var is_dodging: bool = false         # 当前正在翻滚
var dodge_invincible: bool = false   # 无敌帧
var dodge_timer: float = 0.0         # 翻滚剩余时长
var dodge_cooldown_timer: float = 0.0 # 翻滚冷却
const DODGE_DURATION: float = 0.32   # 翻滚持续时间（秒）
const DODGE_SPEED: float = 520.0     # 翻滚速度
var DODGE_COOLDOWN: float = 0.7    # 翻滚冷却（秒）
const DODGE_INVINCIBLE_DURATION: float = 0.25  # 无敌帧时长
var _dodge_dir: Vector2 = Vector2.RIGHT
var _afterimage_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	max_hp = base_max_hp
	current_hp = max_hp
	move_speed = base_move_speed
	pickup_radius = base_pickup_radius
	_apply_meta_bonuses()
	_setup_visual()
	EventBus.emit_signal("player_exp_changed", current_exp, exp_to_next)
	EventBus.emit_signal("player_damaged", current_hp, max_hp)

func _apply_meta_bonuses() -> void:
	await get_tree().process_frame

	# ① 应用角色基础属性倍率
	var char_data = get_meta("char_data", null)
	if char_data:
		max_hp           = base_max_hp       * char_data.hp_mult
		move_speed       = base_move_speed   * char_data.speed_mult
		pickup_radius    = base_pickup_radius * char_data.pickup_mult
		regen_per_second += char_data.regen_base
		damage_multiplier *= char_data.damage_mult

	# ② 应用 Meta 永久解锁加成
	var meta = get_tree().root.find_child("MetaProgress", true, false)
	if meta:
		max_hp           = max_hp        * meta.get_hp_bonus()
		move_speed       = move_speed    * meta.get_speed_bonus()
		pickup_radius    = pickup_radius * meta.get_pickup_bonus()
		regen_per_second += meta.get_regen_bonus()
		damage_multiplier  *= meta.get_damage_bonus()
		attack_speed_multiplier *= meta.get_attack_speed_bonus()
		exp_multiplier   *= meta.get_exp_bonus()
		max_skill_slots  += meta.get_extra_skill_slots()

	current_hp = max_hp

func _setup_visual() -> void:
	collision_layer = 1
	collision_mask = 2

	var anim_sprite = AnimatedSprite2D.new()
	anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# 读取角色数据中的精灵表配置
	var char_data = get_meta("char_data", null)
	var sheet_path = "res://assets/sprites/player/mage_walk_sheet.png"
	var frame_w = 200
	var frame_h = 192
	var frame_count = 8
	var disp_scale = 0.42

	if char_data and char_data.walk_sheet_path != "":
		sheet_path    = char_data.walk_sheet_path
		frame_w       = char_data.walk_frame_w
		frame_h       = char_data.walk_frame_h
		frame_count   = char_data.walk_frame_count
		disp_scale    = 0.50  # 128px 帧用稍大缩放

	anim_sprite.scale = Vector2(disp_scale, disp_scale)

	var tex = load(sheet_path)
	var frames = SpriteFrames.new()

	frames.add_animation("walk")
	frames.set_animation_loop("walk", true)
	frames.set_animation_speed("walk", 8.0)
	for i in range(frame_count):
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		atlas.margin = Rect2(2, 2, -4, -4)  # 内缩2px，防止相邻帧渗透进描边shader
		frames.add_frame("walk", atlas)

	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 5.0)
	var idle_atlas = AtlasTexture.new()
	idle_atlas.atlas = tex
	idle_atlas.region = Rect2(0, 0, frame_w, frame_h)
	idle_atlas.margin = Rect2(2, 2, -4, -4)
	frames.add_frame("idle", idle_atlas)

	anim_sprite.sprite_frames = frames
	add_child(anim_sprite)
	visual = anim_sprite
	visual.play("idle")

	# 施法动画（快速抬手：用walk前3帧高速播放）
	frames.add_animation("cast")
	frames.set_animation_loop("cast", false)
	frames.set_animation_speed("cast", 18.0)
	for i in range(min(3, frame_count)):
		var catlas = AtlasTexture.new()
		catlas.atlas = tex
		catlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		catlas.margin = Rect2(2, 2, -4, -4)
		frames.add_frame("cast", catlas)
	visual.animation_finished.connect(_on_anim_finished)

	# 描边轮廓 shader
	var shader_mat = ShaderMaterial.new()
	var outline_shader = load("res://assets/shaders/character_outline.gdshader")
	if outline_shader:
		shader_mat.shader = outline_shader
		shader_mat.set_shader_parameter("outline_color", Color(1.0, 0.85, 0.1, 1.0))  # 金黄色
		shader_mat.set_shader_parameter("outline_width", 2.5)  # 稍粗一点更明显
		shader_mat.set_shader_parameter("shadow_color", Color(0.0, 0.0, 0.0, 0.45))
		shader_mat.set_shader_parameter("shadow_offset", Vector2(2.0, 3.0))
		visual.material = shader_mat

	var col = CollisionShape2D.new()
	var cap = CapsuleShape2D.new()
	cap.radius = 12.0
	cap.height = 20.0
	col.shape = cap
	add_child(col)

func _on_anim_finished() -> void:
	if visual and visual.animation == "cast":
		visual.play("idle")

# 供 SkillBase 调用：播放施法动画
func play_cast_anim() -> void:
	if visual and not is_dodging:
		visual.play("cast")

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_handle_dodge(delta)
	_handle_movement(delta)
	_handle_regen(delta)
	_handle_pickup(delta)
	move_and_slide()

func _handle_dodge(delta: float) -> void:
	# 冷却计时
	if dodge_cooldown_timer > 0.0:
		dodge_cooldown_timer -= delta

	# 翻滚进行中
	if is_dodging:
		dodge_timer -= delta
		_afterimage_timer -= delta
		# 生成残影
		if _afterimage_timer <= 0.0:
			_afterimage_timer = 0.05
			_spawn_afterimage()
		if dodge_timer <= 0.0:
			_end_dodge()
		else:
			velocity = _dodge_dir * DODGE_SPEED
		return

	# 检测翻滚输入（Space）
	if Input.is_action_just_pressed("ui_accept") and dodge_cooldown_timer <= 0.0:
		_start_dodge()

func _start_dodge() -> void:
	# 翻滚方向 = 当前移动方向，无输入则背向（保留上一个移动方向）
	var dir = Vector2.ZERO
	if Input.is_action_pressed("move_up"):    dir.y -= 1
	if Input.is_action_pressed("move_down"):  dir.y += 1
	if Input.is_action_pressed("move_left"):  dir.x -= 1
	if Input.is_action_pressed("move_right"): dir.x += 1
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN  # 默认向下翻滚
	_dodge_dir = dir.normalized()

	is_dodging = true
	dodge_invincible = true
	dodge_timer = DODGE_DURATION
	_afterimage_timer = 0.0
	dodge_cooldown_timer = DODGE_COOLDOWN

	# 视觉：半透明表示无敌
	if visual:
		visual.modulate = Color(1.0, 1.0, 1.0, 0.45)

	# 无敌帧在翻滚前期结束（比翻滚动作早一点）
	get_tree().create_timer(DODGE_INVINCIBLE_DURATION).timeout.connect(func():
		dodge_invincible = false
	)

func _end_dodge() -> void:
	is_dodging = false
	dodge_invincible = false
	if visual:
		visual.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _spawn_afterimage() -> void:
	if visual == null:
		return
	# 用 Sprite2D 复制当前帧作为残影
	var ghost = Sprite2D.new()
	var sf = visual.sprite_frames
	var anim = visual.animation
	var frame_idx = visual.frame
	if sf and sf.has_animation(anim) and frame_idx < sf.get_frame_count(anim):
		ghost.texture = sf.get_frame_texture(anim, frame_idx)
	ghost.scale = visual.scale
	ghost.flip_h = visual.flip_h
	ghost.position = global_position
	ghost.modulate = Color(0.4, 0.7, 1.0, 0.55)  # 蓝白残影
	ghost.z_index = -1
	get_tree().current_scene.add_child(ghost)
	# 0.15s 淡出后清理
	var tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.15)
	tween.tween_callback(ghost.queue_free)

var _move_velocity: Vector2 = Vector2.ZERO  # 带惯性的速度
var _footstep_timer: float = 0.0            # 脚步粒子计时

func _handle_movement(delta: float) -> void:
	var dir = Vector2.ZERO
	if Input.is_action_pressed("move_up"):    dir.y -= 1
	if Input.is_action_pressed("move_down"):  dir.y += 1
	if Input.is_action_pressed("move_left"):  dir.x -= 1
	if Input.is_action_pressed("move_right"): dir.x += 1
	if dir != Vector2.ZERO:
		dir = dir.normalized()
		if visual and visual.animation != "walk" and visual.animation != "cast":
			visual.play("walk")
		if dir.x != 0:
			visual.flip_h = dir.x < 0
		# 惯性加速（0.12s 达到目标速度）
		_move_velocity = _move_velocity.lerp(dir * move_speed, 1.0 - exp(-delta * 18.0))
		# 脚步粒子
		_footstep_timer -= delta
		if _footstep_timer <= 0.0:
			_footstep_timer = 0.18
			_spawn_footstep()
	else:
		if visual and visual.animation != "idle" and visual.animation != "cast":
			visual.play("idle")
		# 惯性减速
		_move_velocity = _move_velocity.lerp(Vector2.ZERO, 1.0 - exp(-delta * 22.0))
	velocity = _move_velocity

func _spawn_footstep() -> void:
	var fp = CPUParticles2D.new()
	fp.emitting = false
	fp.one_shot = true
	fp.amount = 4
	fp.lifetime = 0.25
	fp.explosiveness = 0.9
	fp.spread = 35.0
	fp.direction = Vector2(0, 1)
	fp.initial_velocity_min = 15.0
	fp.initial_velocity_max = 30.0
	fp.scale_amount_min = 2.0
	fp.scale_amount_max = 4.0
	fp.color = Color(0.5, 0.4, 0.3, 0.5)
	fp.z_index = -1
	get_tree().current_scene.add_child(fp)
	fp.global_position = global_position + Vector2(0, 10)
	fp.emitting = true
	get_tree().create_timer(0.5).timeout.connect(func():
		if is_instance_valid(fp): fp.queue_free()
	)

func _handle_regen(delta: float) -> void:
	if regen_per_second <= 0:
		return
	regen_timer += delta
	if regen_timer >= 1.0:
		regen_timer = 0.0
		heal(regen_per_second)

func _handle_pickup(delta: float) -> void:
	pickup_timer += delta
	if pickup_timer < 0.1:
		return
	pickup_timer = 0.0
	var gems = get_tree().get_nodes_in_group("exp_gems")
	for gem in gems:
		if is_instance_valid(gem) and global_position.distance_to(gem.global_position) <= pickup_radius:
			gem.attract()

func take_damage(dmg: float) -> void:
	if is_dead:
		return
	# 无敌帧期间免伤
	if dodge_invincible:
		return
	current_hp -= dmg
	current_hp = max(current_hp, 0.0)
	EventBus.emit_signal("player_damaged", current_hp, max_hp)
	# 音效
	var snd = get_tree().get_first_node_in_group("sound_manager")
	if snd:
		snd.play_player_hurt()
	# 击退：找最近敌人方向
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest = null
	var nearest_dist = INF
	for e in enemies:
		if is_instance_valid(e):
			var d = global_position.distance_to(e.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = e
	if nearest != null:
		var knockback_dir = (global_position - nearest.global_position).normalized()
		velocity += knockback_dir * 120
	# 受击闪白
	if visual:
		visual.modulate = Color(2.0, 2.0, 2.0)
		var tween = create_tween()
		tween.tween_property(visual, "modulate", Color(1, 1, 1, 1), 0.15)
	if current_hp <= 0:
		die()

func heal(amount: float) -> void:
	if heal_disabled:
		return
	current_hp = min(current_hp + amount, max_hp)
	EventBus.emit_signal("player_damaged", current_hp, max_hp)

func gain_exp(amount: int) -> void:
	if is_showing_upgrade:
		return  # 升级面板打开时不累计经验，避免连锁触发
	var gained = int(amount * exp_multiplier)
	current_exp += gained
	total_score += gained
	EventBus.emit_signal("player_exp_changed", current_exp, exp_to_next)
	while current_exp >= exp_to_next and not is_showing_upgrade:
		current_exp -= exp_to_next
		_level_up()

func _level_up() -> void:
	level += 1
	exp_to_next = int(50 * pow(1.4, level - 1))
	EventBus.emit_signal("player_leveled_up", level)
	is_showing_upgrade = true
	# call_deferred：等当前物理帧完全结束后再暂停+显示面板，避免同帧内paused无效
	call_deferred("_do_show_upgrade")

func _do_show_upgrade() -> void:
	EventBus.game_logic_paused = true  # 冻结敌人移动和波次生成
	var choices = UpgradeSystem.generate_choices(self)
	EventBus.emit_signal("show_level_up_panel", choices)

func apply_passive(passive_data: PassiveData) -> void:
	passive_ids.append(passive_data.id)
	max_hp += passive_data.hp_bonus
	current_hp += passive_data.hp_bonus
	move_speed += base_move_speed * passive_data.move_speed_bonus
	damage_multiplier += passive_data.damage_bonus
	attack_speed_multiplier += passive_data.attack_speed_bonus
	pickup_radius += passive_data.pickup_radius_bonus
	exp_multiplier += passive_data.exp_bonus
	regen_per_second += passive_data.regen_bonus
	# 冷却加成：减少所有已装备技能的冷却
	if passive_data.cooldown_bonus != 0.0:
		for skill in skills:
			if skill.data:
				skill.data.cooldown = max(0.1, skill.data.cooldown * (1.0 + passive_data.cooldown_bonus))
	EventBus.emit_signal("player_damaged", current_hp, max_hp)
	_check_evolutions()

func add_skill(skill_instance: SkillBase) -> void:
	if skills.size() >= max_skill_slots:
		return
	skills.append(skill_instance)
	skill_instance.owner_player = self
	add_child(skill_instance)

func _check_evolutions() -> void:
	for skill in skills:
		if skill.can_evolve(passive_ids) and skill.level >= skill.data.max_level:
			EventBus.emit_signal("skill_evolved", skill.data.id, skill.data.evolved_skill_id)
			# TODO: 替换为进化后的技能

func die() -> void:
	is_dead = true
	EventBus.emit_signal("player_died")
