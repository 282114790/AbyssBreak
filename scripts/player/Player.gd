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
var exp_to_next: int = 100
var total_score: int = 0

# 技能系统
var skills: Array = []           # 已装备的技能实例
var max_skill_slots: int = 4     # 基础4槽，Meta可扩展到5
var passive_ids: Array = []      # 已拥有的被动id列表
var skill_echoes: Array = []     # 被替换技能的残响 [{id, damage_bonus, element}]

# 角色独特机制
var _mechanic_id: String = ""
var _elemental_chain_count: int = 0    # 法师：同元素连续施法层数
var _elemental_chain_element: int = -1 # 法师：当前连锁元素
var _elemental_chain_timer: float = 0.0
var _revenge_strike_active: bool = false # 战士：受创反击激活
var _revenge_strike_timer: float = 0.0
var _velocity_damage_bonus: float = 0.0 # 猎人：速度转伤害

# 遗物系统
var relic_ids: Array = []        # 已拥有的遗物id列表
var crit_chance: float = 0.05    # 暴击率（默认5%）
var crit_mult: float = 1.5       # 暴击倍率（默认1.5倍）
var barrier_dr: float = 0.0      # 元素壁垒减伤率（0.0~1.0）

# 诅咒系统
var curse_ids: Array = []        # 已接受的诅咒id列表
var heal_disabled: bool = false  # 诅咒：无法回血

# 局内货币（商人用）
var gold: int = 0

# 终结技系统（R: 深渊脉冲, T: 虚空崩裂，独立充能）
var ult_charge_r: float = 0.0
var ult_charge_t: float = 0.0
const ULT_MAX_R: float = 100.0
const ULT_MAX_T: float = 130.0
var ult_ready_r: bool = false
var ult_ready_t: bool = false
var _ult_cd_r: float = 0.0
var _ult_cd_t: float = 0.0
var _ult_invincible: bool = false

# 完美闪避
var _perfect_dodge_window: bool = false
var _perfect_dodge_bonus: bool = false
var _perfect_dodge_timer: float = 0.0

# 消耗道具系统
var consumables: Array = []  # [{id, name, count}]
const MAX_CONSUMABLE_SLOTS := 3

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

# 涅槃之力 (regen2)：受伤后3秒无敌
var _regen2_invincible: bool = false
var _regen2_timer: float = 0.0
var _has_regen2: bool = false

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
		_mechanic_id = char_data.unique_mechanic if char_data.get("unique_mechanic") else ""

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
		crit_chance += meta.get_crit_chance_bonus()
		crit_mult   *= meta.get_crit_mult_bonus()
		_has_regen2 = meta.has_regen2_invincible()

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
	frames.set_animation_speed("walk", 12.0)  # 8→12fps，更流畅
	for i in range(frame_count):
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		atlas.margin = Rect2(2, 2, -4, -4)  # 内缩2px，防止相邻帧渗透进描边shader
		frames.add_frame("walk", atlas)

	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 6.0)
	# idle 用前3帧做轻微呼吸摆动（0→1→2→1 循环）
	for idx in [0, 1, 2, 1]:
		var idle_atlas = AtlasTexture.new()
		idle_atlas.atlas = tex
		idle_atlas.region = Rect2(min(idx, frame_count - 1) * frame_w, 0, frame_w, frame_h)
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
	# 启动待机呼吸浮动
	_start_idle_breath()

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

	_setup_player_light()

func _on_anim_finished() -> void:
	if visual and visual.animation == "cast":
		# cast 结束时做一个小弹出感（scale 1.0 → 1.12 → 1.0）
		var base_scale = visual.scale
		var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(visual, "scale", base_scale * 1.12, 0.06)
		tween.tween_property(visual, "scale", base_scale, 0.08)
		visual.play("idle")

# 待机呼吸浮动：循环 Tween，上下 3px + 轻微缩放
var _breath_tween: Tween = null
var _breath_base_y: float = 0.0

func _start_idle_breath() -> void:
	_breath_base_y = visual.position.y
	_run_breath_cycle()

func _run_breath_cycle() -> void:
	if not is_instance_valid(visual):
		return
	_breath_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_breath_tween.tween_property(visual, "position:y", _breath_base_y - 3.0, 0.6)
	_breath_tween.tween_property(visual, "position:y", _breath_base_y, 0.6)
	_breath_tween.tween_callback(_run_breath_cycle)

# 供 SkillBase 调用：播放施法动画
func play_cast_anim() -> void:
	if visual and not is_dodging:
		visual.play("cast")

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if _regen2_invincible:
		_regen2_timer -= delta
		if _regen2_timer <= 0:
			_regen2_invincible = false
	if _ult_cd_r > 0: _ult_cd_r -= delta
	if _ult_cd_t > 0: _ult_cd_t -= delta
	if _perfect_dodge_bonus:
		_perfect_dodge_timer -= delta
		if _perfect_dodge_timer <= 0:
			_perfect_dodge_bonus = false
	_handle_dodge(delta)
	_handle_movement(delta)
	_handle_regen(delta)
	_handle_pickup(delta)
	_handle_ultimate_input()
	_handle_consumable_input()
	_update_mechanic(delta)
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

	# 翻滚时暂停呼吸偏移，复位 Y
	if _breath_tween: _breath_tween.kill()
	if visual: visual.position.y = _breath_base_y

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
	# 翻滚结束，重启呼吸
	_run_breath_cycle()

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
	if is_dodging:
		return
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
	var coins = get_tree().get_nodes_in_group("gold_coins")
	for coin in coins:
		if is_instance_valid(coin) and global_position.distance_to(coin.global_position) <= pickup_radius:
			coin.attract()

func take_damage(dmg: float) -> void:
	if is_dead:
		return
	if dodge_invincible:
		_on_perfect_dodge()
		return
	if _regen2_invincible or _ult_invincible:
		return
	if barrier_dr > 0.0:
		dmg *= (1.0 - clampf(barrier_dr, 0.0, 0.9))
	current_hp -= dmg
	current_hp = max(current_hp, 0.0)
	EventBus.emit_signal("player_damaged", current_hp, max_hp)
	on_damaged_mechanic()
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
		# 受击时打断呼吸偏移，复位后重启
		if _breath_tween: _breath_tween.kill()
		visual.position.y = _breath_base_y
		tween.tween_callback(_run_breath_cycle)
	# 涅槃之力：受伤后触发 3 秒无敌
	if _has_regen2 and current_hp > 0:
		_regen2_invincible = true
		_regen2_timer = 3.0
	if current_hp <= 0:
		die()

func heal(amount: float) -> void:
	if heal_disabled:
		return
	current_hp = min(current_hp + amount, max_hp)
	EventBus.emit_signal("player_damaged", current_hp, max_hp)

func gain_exp(amount: int) -> void:
	if is_showing_upgrade:
		return
	var route_exp = 1.0
	var diff_exp = 1.0
	var main = get_tree().root.find_child("Main", true, false)
	if main and main.has_meta("route_exp_bonus"):
		route_exp = main.get_meta("route_exp_bonus")
	if main and main.has_meta("difficulty_exp_mult"):
		diff_exp = main.get_meta("difficulty_exp_mult")
	var gained = int(amount * exp_multiplier * route_exp * diff_exp)
	current_exp += gained
	total_score += gained
	charge_ultimate(float(gained) * 1.5)  # DEBUG: 10x 充能速度，调试完改回 0.15
	EventBus.emit_signal("player_exp_changed", current_exp, exp_to_next)
	while current_exp >= exp_to_next and not is_showing_upgrade:
		current_exp -= exp_to_next
		_level_up()

func _level_up() -> void:
	level += 1
	exp_to_next = int(100 * pow(1.5, level - 1))
	EventBus.emit_signal("player_leveled_up", level)
	is_showing_upgrade = true
	# call_deferred：等当前物理帧完全结束后再暂停+显示面板，避免同帧内paused无效
	call_deferred("_do_show_upgrade")

func _do_show_upgrade() -> void:
	EventBus.game_logic_paused = true
	var meta = get_tree().root.find_child("MetaProgress", true, false)
	var max_choices := 5
	if meta and meta.get_upgrade_choices_count() == 4:
		max_choices = 6
	var choices = UpgradeSystem.generate_choices(self, max_choices)
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

func replace_skill(old_skill_idx: int, new_skill_instance: SkillBase) -> void:
	if old_skill_idx < 0 or old_skill_idx >= skills.size():
		return
	var old_skill = skills[old_skill_idx]
	skill_echoes.append({
		"id": old_skill.data.id,
		"display_name": old_skill.data.display_name,
		"damage_bonus": old_skill.data.damage * 0.5 * old_skill.level / old_skill.data.max_level,
		"element": old_skill.data.element,
	})
	var old_id = old_skill.data.id
	old_skill.queue_free()
	skills.remove_at(old_skill_idx)
	skills.append(new_skill_instance)
	new_skill_instance.owner_player = self
	add_child(new_skill_instance)
	EventBus.emit_signal("skill_replaced", old_id, new_skill_instance.data.id)

func get_echo_damage_bonus() -> float:
	var bonus := 0.0
	for echo in skill_echoes:
		bonus += echo.get("damage_bonus", 0.0)
	return bonus

func is_skill_slots_full() -> bool:
	return skills.size() >= max_skill_slots

func _check_evolutions() -> void:
	for skill in skills:
		if skill.can_evolve(passive_ids) and skill.level >= skill.data.max_level:
			EventBus.emit_signal("skill_evolved", skill.data.id, skill.data.evolved_skill_id)

# ── 角色独特机制 ────────────────────────────────────────
func notify_skill_cast(skill_element: int) -> void:
	if _mechanic_id == "elemental_chain":
		if skill_element == _elemental_chain_element and skill_element >= 0:
			_elemental_chain_count = mini(_elemental_chain_count + 1, 4)
		else:
			_elemental_chain_count = 1
			_elemental_chain_element = skill_element
		_elemental_chain_timer = 3.0

func get_mechanic_damage_mult() -> float:
	match _mechanic_id:
		"elemental_chain":
			return 1.0 + _elemental_chain_count * 0.15
		"revenge_strike":
			if _revenge_strike_active:
				_revenge_strike_active = false
				return 2.0
			return 1.0
		"velocity_damage":
			return 1.0 + _velocity_damage_bonus
	return 1.0

func _update_mechanic(delta: float) -> void:
	match _mechanic_id:
		"elemental_chain":
			if _elemental_chain_timer > 0:
				_elemental_chain_timer -= delta
				if _elemental_chain_timer <= 0:
					_elemental_chain_count = 0
					_elemental_chain_element = -1
		"revenge_strike":
			if _revenge_strike_timer > 0:
				_revenge_strike_timer -= delta
				if _revenge_strike_timer <= 0:
					_revenge_strike_active = false
		"velocity_damage":
			var speed_ratio = velocity.length() / max(base_move_speed, 1.0)
			_velocity_damage_bonus = clampf(speed_ratio * 0.3, 0.0, 0.4)

func on_damaged_mechanic() -> void:
	if _mechanic_id == "revenge_strike":
		_revenge_strike_active = true
		_revenge_strike_timer = 8.0

func die() -> void:
	is_dead = true
	EventBus.emit_signal("player_died")

# ── 玩家动态光源 ──────────────────────────────────────
var _player_light: PointLight2D = null
var _player_light_base_energy: float = 0.85

func _setup_player_light() -> void:
	_player_light = PointLight2D.new()
	_player_light.name = "PlayerLight"
	_player_light.texture = _make_radial_gradient(128)
	_player_light.color = Color(0.95, 0.9, 0.82, 1.0)
	_player_light.energy = _player_light_base_energy
	_player_light.texture_scale = 6.0
	_player_light.shadow_enabled = false
	_player_light.z_index = -5
	add_child(_player_light)
	_start_light_flicker()

func _start_light_flicker() -> void:
	if not is_instance_valid(_player_light):
		return
	var tw = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	var target := _player_light_base_energy + randf_range(-0.08, 0.08)
	tw.tween_property(_player_light, "energy", target, randf_range(0.4, 0.8))
	tw.tween_callback(_start_light_flicker)

static func _make_radial_gradient(sz: int) -> ImageTexture:
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var center := Vector2(sz * 0.5, sz * 0.5)
	for y in range(sz):
		for x in range(sz):
			var dist := Vector2(x, y).distance_to(center) / (sz * 0.5)
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			alpha = alpha * alpha * alpha
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)

# ── 终结技系统 ──────────────────────────────────────
func charge_ultimate(amount: float) -> void:
	if not ult_ready_r:
		ult_charge_r = min(ult_charge_r + amount, ULT_MAX_R)
		if ult_charge_r >= ULT_MAX_R:
			ult_ready_r = true
			EventBus.emit_signal("pickup_float_text", global_position + Vector2(0, -40),
				"[R] 深渊脉冲 就绪！", Color(1.0, 0.85, 0.2))
	if not ult_ready_t:
		ult_charge_t = min(ult_charge_t + amount * 0.75, ULT_MAX_T)
		if ult_charge_t >= ULT_MAX_T:
			ult_ready_t = true
			EventBus.emit_signal("pickup_float_text", global_position + Vector2(0, -50),
				"[T] 虚空崩裂 就绪！", Color(0.7, 0.4, 1.0))

func _handle_ultimate_input() -> void:
	if is_dead: return
	if Input.is_key_pressed(KEY_R) and ult_ready_r and _ult_cd_r <= 0:
		_activate_abyss_pulse()
	elif Input.is_key_pressed(KEY_T) and ult_ready_t and _ult_cd_t <= 0:
		_activate_void_collapse()

# ── R：深渊脉冲 — 三波冲击波 + 灼烧领域 ──────────────
func _activate_abyss_pulse() -> void:
	ult_ready_r = false
	ult_charge_r = 0.0
	_ult_cd_r = 2.0
	_ult_invincible = true

	var base_dmg = (200.0 + max_hp * 0.15) * damage_multiplier
	var origin = global_position

	if visual:
		visual.modulate = Color(3.0, 3.0, 2.0)
		var tw = create_tween()
		tw.tween_property(visual, "modulate", Color(1, 1, 1), 0.5)

	var wave_colors = [
		Color(1.0, 1.0, 0.85, 0.9),
		Color(1.0, 0.6, 0.15, 0.85),
		Color(0.8, 0.15, 0.1, 0.8),
	]
	var p_starts = [
		Color(1.0, 1.0, 0.7, 1.0),
		Color(1.0, 0.7, 0.2, 1.0),
		Color(1.0, 0.3, 0.1, 1.0),
	]
	var p_ends = [
		Color(1.0, 0.9, 0.3, 0.0),
		Color(1.0, 0.3, 0.0, 0.0),
		Color(0.5, 0.0, 0.0, 0.0),
	]
	var wave_radii = [250.0, 400.0, 550.0]
	var wave_dmg = [0.6, 0.8, 1.2]
	var wave_kb = [180.0, 250.0, 350.0]

	for i in range(3):
		if i > 0:
			await get_tree().create_timer(0.2).timeout
		if is_dead: _ult_invincible = false; return
		_spawn_pulse_ring(origin, wave_colors[i], wave_radii[i], p_starts[i], p_ends[i])
		_pulse_damage_kb(origin, wave_radii[i], base_dmg * wave_dmg[i], wave_kb[i])
		_ult_shake(3.0 + i * 2.0)
		var sm = get_tree().get_first_node_in_group("sound_manager")
		if sm: sm.play_explosion()

	await get_tree().create_timer(0.3).timeout
	if not is_dead:
		_spawn_burn_zone(global_position, 160.0, base_dmg * 0.15, 3.0)
	await get_tree().create_timer(0.3).timeout
	_ult_invincible = false

func _spawn_pulse_ring(origin: Vector2, color: Color, max_r: float, ps: Color, pe: Color) -> void:
	var ring = Node2D.new()
	ring.global_position = origin
	ring.z_index = 12
	get_tree().current_scene.add_child(ring)

	var line = Line2D.new()
	line.width = 6.0
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	for i in range(65):
		var a = (TAU / 64.0) * i
		line.add_point(Vector2(cos(a) * 10, sin(a) * 10))
	ring.add_child(line)

	var echo = Line2D.new()
	echo.width = 3.0
	echo.default_color = Color(color.r, color.g, color.b, color.a * 0.4)
	echo.joint_mode = Line2D.LINE_JOINT_ROUND
	for i in range(65):
		var a = (TAU / 64.0) * i
		echo.add_point(Vector2(cos(a) * 10, sin(a) * 10))
	ring.add_child(echo)

	var burst = GPUParticles2D.new()
	burst.emitting = false
	burst.amount = 48
	burst.lifetime = 0.45
	burst.explosiveness = 0.8
	burst.one_shot = true
	burst.local_coords = false
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 100.0
	pm.initial_velocity_max = 250.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 3.0
	pm.scale_max = 9.0
	var g = Gradient.new()
	g.set_color(0, ps)
	g.set_color(1, pe)
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	burst.process_material = pm
	ring.add_child(burst)
	burst.emitting = true

	var max_scale = max_r / 10.0
	var tween = ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(max_scale, max_scale), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.45)
	tween.tween_callback(ring.queue_free).set_delay(0.55)

func _pulse_damage_kb(origin: Vector2, radius: float, dmg: float, kb: float) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.is_dead: continue
		var dist = origin.distance_to(e.global_position)
		if dist >= radius: continue
		var falloff = 1.0 - dist / (radius * 1.2)
		e.take_damage(max(dmg * falloff, 10.0), true)
		var kb_dir = (e.global_position - origin).normalized()
		if kb_dir == Vector2.ZERO: kb_dir = Vector2.RIGHT.rotated(randf() * TAU)
		var target_pos = e.global_position + kb_dir * kb * falloff * 0.4
		var kb_tw = e.create_tween()
		kb_tw.tween_property(e, "global_position", target_pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if e.get("base_move_speed") != null:
			var orig_spd = e.base_move_speed
			e.base_move_speed *= 0.3
			get_tree().create_timer(1.0).timeout.connect(func():
				if is_instance_valid(e): e.base_move_speed = orig_spd
			)

func _spawn_burn_zone(pos: Vector2, radius: float, dps: float, duration: float) -> void:
	var zone = Node2D.new()
	zone.global_position = pos
	zone.z_index = -1
	get_tree().current_scene.add_child(zone)

	var line = Line2D.new()
	line.width = 2.5
	line.default_color = Color(1.0, 0.3, 0.1, 0.5)
	for i in range(33):
		var a = (TAU / 32.0) * i
		line.add_point(Vector2(cos(a) * radius, sin(a) * radius))
	zone.add_child(line)

	var fire = GPUParticles2D.new()
	fire.emitting = true
	fire.amount = 20
	fire.lifetime = 0.8
	fire.local_coords = true
	var pm = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radius * 0.7
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 30.0
	pm.initial_velocity_min = 15.0
	pm.initial_velocity_max = 40.0
	pm.gravity = Vector3(0, -20, 0)
	pm.scale_min = 3.0
	pm.scale_max = 8.0
	var g = Gradient.new()
	g.set_color(0, Color(1.0, 0.5, 0.1, 0.5))
	g.set_color(1, Color(0.8, 0.1, 0.0, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	fire.process_material = pm
	zone.add_child(fire)

	var elapsed := 0.0
	var tick := 0.0
	while elapsed < duration:
		await get_tree().process_frame
		var d = get_process_delta_time()
		elapsed += d
		tick += d
		if not is_instance_valid(zone): return
		zone.modulate.a = (0.4 + sin(elapsed * 4.0) * 0.1) * (1.0 - elapsed / duration)
		if tick >= 0.5:
			tick = 0.0
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and e.global_position.distance_to(pos) <= radius:
					e.take_damage(dps, false)
	if is_instance_valid(zone):
		zone.queue_free()

# ── T：虚空崩裂 — 敌群处生成黑洞 → 吸引 → 坍缩爆炸 ──────────────
const VOID_PULL_RADIUS := 350.0
const VOID_EXPLODE_RADIUS := 400.0

func _activate_void_collapse() -> void:
	ult_ready_t = false
	ult_charge_t = 0.0
	_ult_cd_t = 2.0
	_ult_invincible = true

	var base_dmg = (200.0 + max_hp * 0.15) * damage_multiplier
	var rift_pos = _find_void_target()
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm: sm.play_explosion()

	if visual:
		visual.modulate = Color(1.5, 0.8, 2.5)
		var tw = create_tween()
		tw.tween_property(visual, "modulate", Color(1, 1, 1), 1.5)

	# 生成前先画一条玩家→漩涡的连接线
	var link_line = Line2D.new()
	link_line.width = 2.0
	link_line.default_color = Color(0.5, 0.2, 0.9, 0.6)
	link_line.add_point(global_position)
	link_line.add_point(rift_pos)
	link_line.z_index = 9
	get_tree().current_scene.add_child(link_line)
	var link_tw = link_line.create_tween()
	link_tw.tween_property(link_line, "modulate:a", 0.0, 0.6)
	link_tw.tween_callback(link_line.queue_free)

	var vortex = Node2D.new()
	vortex.global_position = rift_pos
	vortex.z_index = 10
	get_tree().current_scene.add_child(vortex)

	var core = Sprite2D.new()
	core.texture = _make_radial_gradient(64)
	core.scale = Vector2(0.5, 0.5)
	core.modulate = Color(0.2, 0.0, 0.4, 0.9)
	vortex.add_child(core)

	var outer = Sprite2D.new()
	outer.texture = _make_radial_gradient(64)
	outer.scale = Vector2(1.2, 1.2)
	outer.modulate = Color(0.5, 0.2, 0.8, 0.35)
	vortex.add_child(outer)

	var suction_fx = GPUParticles2D.new()
	suction_fx.emitting = true
	suction_fx.amount = 36
	suction_fx.lifetime = 0.7
	suction_fx.local_coords = true
	var spm = ParticleProcessMaterial.new()
	spm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	spm.emission_ring_radius = 120.0
	spm.emission_ring_inner_radius = 100.0
	spm.emission_ring_height = 0.0
	spm.emission_ring_axis = Vector3(0, 0, 1)
	spm.direction = Vector3.ZERO
	spm.spread = 180.0
	spm.initial_velocity_min = -60.0
	spm.initial_velocity_max = -30.0
	spm.gravity = Vector3.ZERO
	spm.scale_min = 2.0
	spm.scale_max = 6.0
	var sg = Gradient.new()
	sg.set_color(0, Color(0.7, 0.3, 1.0, 0.8))
	sg.set_color(1, Color(0.2, 0.0, 0.5, 0.0))
	var sgt = GradientTexture1D.new()
	sgt.gradient = sg
	spm.color_ramp = sgt
	suction_fx.process_material = spm
	vortex.add_child(suction_fx)

	var edge = Line2D.new()
	edge.width = 2.0
	edge.default_color = Color(0.6, 0.3, 1.0, 0.5)
	for i in range(65):
		var a = (TAU / 64.0) * i
		edge.add_point(Vector2(cos(a) * 90, sin(a) * 90))
	vortex.add_child(edge)

	# 生成动画：从小到大弹出
	vortex.scale = Vector2(0.1, 0.1)
	var spawn_tw = vortex.create_tween()
	spawn_tw.tween_property(vortex, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 1.5秒吸引阶段
	var elapsed := 0.0
	while elapsed < 1.5:
		await get_tree().process_frame
		var d = get_process_delta_time()
		elapsed += d
		if not is_instance_valid(vortex): break

		core.rotation += d * (3.0 + elapsed * 5.0)
		outer.rotation -= d * (2.0 + elapsed * 4.0)
		edge.rotation += d * (1.0 + elapsed * 2.0)
		var growth = 0.5 + elapsed * 0.5
		core.scale = Vector2(growth, growth)

		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or e.is_dead: continue
			var dist = e.global_position.distance_to(rift_pos)
			if dist > VOID_PULL_RADIUS: continue
			var dir = (rift_pos - e.global_position).normalized()
			var pull = 300.0 * (1.0 - dist / (VOID_PULL_RADIUS + 50.0))
			e.global_position += dir * pull * d

	# 坍缩爆炸
	if is_instance_valid(vortex):
		vortex.queue_free()

	_spawn_implosion(rift_pos, base_dmg * 2.5)

	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.is_dead: continue
		var dist = rift_pos.distance_to(e.global_position)
		if dist < VOID_EXPLODE_RADIUS:
			var falloff = 1.0 - dist / (VOID_EXPLODE_RADIUS + 100.0)
			e.take_damage(max(base_dmg * 2.5 * falloff, 10.0), true)
			var kb_dir = (e.global_position - rift_pos).normalized()
			if kb_dir == Vector2.ZERO: kb_dir = Vector2.RIGHT.rotated(randf() * TAU)
			var kb_target = e.global_position + kb_dir * 100.0 * falloff
			var kb_tw = e.create_tween()
			kb_tw.tween_property(e, "global_position", kb_target, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_ult_shake(10.0)
	if sm: sm.play_explosion()
	await get_tree().create_timer(0.5).timeout
	_ult_invincible = false

func _find_void_target() -> Vector2:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearby: Array = []
	for e in enemies:
		if is_instance_valid(e) and not e.is_dead:
			if global_position.distance_to(e.global_position) < 450:
				nearby.append(e)
	if nearby.is_empty():
		var dir = _move_velocity.normalized() if _move_velocity.length() > 1 else Vector2.RIGHT
		return global_position + dir * 180.0
	var best_pos = nearby[0].global_position
	var best_count = 0
	for e in nearby:
		var count = 0
		for other in nearby:
			if e.global_position.distance_to(other.global_position) < 200:
				count += 1
		if count > best_count:
			best_count = count
			best_pos = e.global_position
	var offset_dir = (best_pos - global_position).normalized()
	if global_position.distance_to(best_pos) < 80:
		best_pos = global_position + offset_dir * 120.0
	return best_pos

func _spawn_implosion(pos: Vector2, dmg: float) -> void:
	# 白色闪光
	var flash = Sprite2D.new()
	flash.texture = _make_radial_gradient(64)
	flash.global_position = pos
	flash.scale = Vector2(0.5, 0.5)
	flash.modulate = Color(1.0, 1.0, 1.0, 1.0)
	flash.z_index = 15
	get_tree().current_scene.add_child(flash)
	var ftw = flash.create_tween()
	ftw.tween_property(flash, "scale", Vector2(12, 12), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ftw.tween_property(flash, "modulate:a", 0.0, 0.3)
	ftw.tween_callback(flash.queue_free)

	# 紫色冲击环
	var ring = Node2D.new()
	ring.global_position = pos
	ring.z_index = 14
	get_tree().current_scene.add_child(ring)
	var line = Line2D.new()
	line.width = 8.0
	line.default_color = Color(0.7, 0.3, 1.0, 0.9)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	for i in range(65):
		var a = (TAU / 64.0) * i
		line.add_point(Vector2(cos(a) * 10, sin(a) * 10))
	ring.add_child(line)
	var rtw = ring.create_tween()
	rtw.set_parallel(true)
	rtw.tween_property(ring, "scale", Vector2(50, 50), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rtw.tween_property(ring, "modulate:a", 0.0, 0.5)
	rtw.tween_callback(ring.queue_free).set_delay(0.6)

	# 粒子爆发
	var burst = GPUParticles2D.new()
	burst.emitting = false
	burst.amount = 64
	burst.lifetime = 0.6
	burst.explosiveness = 0.95
	burst.one_shot = true
	burst.local_coords = false
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 150.0
	pm.initial_velocity_max = 400.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 4.0
	pm.scale_max = 10.0
	var g = Gradient.new()
	g.set_color(0, Color(0.8, 0.5, 1.0, 1.0))
	g.set_color(1, Color(0.3, 0.0, 0.6, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	burst.process_material = pm
	get_tree().current_scene.add_child(burst)
	burst.global_position = pos
	burst.emitting = true
	get_tree().create_timer(0.8).timeout.connect(burst.queue_free)

	# 暗紫碎片环
	var debris = GPUParticles2D.new()
	debris.emitting = false
	debris.amount = 32
	debris.lifetime = 1.0
	debris.explosiveness = 0.9
	debris.one_shot = true
	debris.local_coords = false
	var dpm = ParticleProcessMaterial.new()
	dpm.direction = Vector3(0, -1, 0)
	dpm.spread = 180.0
	dpm.initial_velocity_min = 50.0
	dpm.initial_velocity_max = 120.0
	dpm.gravity = Vector3(0, 80, 0)
	dpm.scale_min = 2.0
	dpm.scale_max = 6.0
	var dg = Gradient.new()
	dg.set_color(0, Color(0.4, 0.1, 0.6, 0.8))
	dg.set_color(1, Color(0.1, 0.0, 0.2, 0.0))
	var dgt = GradientTexture1D.new()
	dgt.gradient = dg
	dpm.color_ramp = dgt
	debris.process_material = dpm
	get_tree().current_scene.add_child(debris)
	debris.global_position = pos
	debris.emitting = true
	get_tree().create_timer(1.2).timeout.connect(debris.queue_free)

func _ult_shake(intensity: float) -> void:
	var cam = get_viewport().get_camera_2d()
	if not cam: return
	var orig = cam.offset
	var tween = cam.create_tween()
	var count = int(intensity)
	for i in range(count):
		var off = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(cam, "offset", orig + off, 0.03)
	tween.tween_property(cam, "offset", orig, 0.04)

# ── 完美闪避反击 ──────────────────────────────────────
func _on_perfect_dodge() -> void:
	_perfect_dodge_bonus = true
	_perfect_dodge_timer = 3.0
	crit_chance += 0.50
	# stun nearby enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and global_position.distance_to(e.global_position) < 150:
			if e.data:
				var orig_spd = e.base_move_speed
				e.base_move_speed = 0
				get_tree().create_timer(1.0).timeout.connect(func():
					if is_instance_valid(e): e.base_move_speed = orig_spd
				)
	# visual feedback
	EventBus.emit_signal("pickup_float_text", global_position + Vector2(0, -30),
		"完美闪避！", Color(0.3, 0.9, 1.0))
	if visual:
		visual.modulate = Color(0.3, 1.5, 2.0)
		var tw = create_tween()
		tw.tween_property(visual, "modulate", Color(1, 1, 1), 0.3)
	# restore crit after timer
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(self) and _perfect_dodge_bonus:
			crit_chance -= 0.50
			_perfect_dodge_bonus = false
	)

# ── 消耗道具系统 ──────────────────────────────────────
var _consumable_debounce: Array = [false, false, false]

func add_consumable(item_id: String, item_name: String) -> bool:
	for c in consumables:
		if c["id"] == item_id:
			c["count"] += 1
			return true
	if consumables.size() < MAX_CONSUMABLE_SLOTS:
		consumables.append({"id": item_id, "name": item_name, "count": 1})
		return true
	return false

func _handle_consumable_input() -> void:
	if is_dead: return
	for i in range(min(consumables.size(), 3)):
		var key = KEY_1 + i
		var pressed = Input.is_key_pressed(key) and not Input.is_action_pressed("move_up")
		if pressed and not _consumable_debounce[i]:
			_consumable_debounce[i] = true
			_use_consumable(i)
			break
		elif not pressed:
			_consumable_debounce[i] = false

func _use_consumable(slot: int) -> void:
	if slot >= consumables.size(): return
	var item = consumables[slot]
	if item["count"] <= 0: return
	item["count"] -= 1
	match item["id"]:
		"bomb":
			var enemies = get_tree().get_nodes_in_group("enemies")
			for e in enemies:
				if is_instance_valid(e) and global_position.distance_to(e.global_position) < 350:
					e.take_damage(200.0 * damage_multiplier, false)
			EventBus.emit_signal("pickup_float_text", global_position + Vector2(0, -30),
				"炸弹！", Color(1.0, 0.5, 0.1))
		"teleport":
			var dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			global_position += dir * 400
			EventBus.emit_signal("pickup_float_text", global_position + Vector2(0, -30),
				"传送！", Color(0.5, 0.3, 1.0))
		"freeze":
			var enemies = get_tree().get_nodes_in_group("enemies")
			for e in enemies:
				if is_instance_valid(e) and e.data:
					var orig_spd = e.base_move_speed
					e.base_move_speed = 0
					get_tree().create_timer(5.0).timeout.connect(func():
						if is_instance_valid(e): e.base_move_speed = orig_spd
					)
			EventBus.emit_signal("pickup_float_text", global_position + Vector2(0, -30),
				"全屏冻结！", Color(0.3, 0.8, 1.0))
		"mega_heal":
			heal(max_hp * 0.5)
			EventBus.emit_signal("pickup_float_text", global_position + Vector2(0, -30),
				"大回复！", Color(0.3, 1.0, 0.3))
	if item["count"] <= 0:
		consumables.remove_at(slot)
