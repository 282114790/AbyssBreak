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

# 内部
var regen_timer: float = 0.0
var is_showing_upgrade: bool = false  # 升级面板开关锁
var pickup_timer: float = 0.0
var is_dead: bool = false
var visual: AnimatedSprite2D

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

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_handle_movement(delta)
	_handle_regen(delta)
	_handle_pickup(delta)
	move_and_slide()

func _handle_movement(delta: float) -> void:
	var dir = Vector2.ZERO
	if Input.is_action_pressed("move_up"):    dir.y -= 1
	if Input.is_action_pressed("move_down"):  dir.y += 1
	if Input.is_action_pressed("move_left"):  dir.x -= 1
	if Input.is_action_pressed("move_right"): dir.x += 1
	if dir != Vector2.ZERO:
		dir = dir.normalized()
		if visual and visual.animation != "walk":
			visual.play("walk")
		# 左右翻转
		if dir.x != 0:
			visual.flip_h = dir.x < 0
	else:
		if visual and visual.animation != "idle":
			visual.play("idle")
	velocity = dir * move_speed

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
