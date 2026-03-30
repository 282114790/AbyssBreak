# EnemyBase.gd
# 所有敌人的基类
extends CharacterBody2D
class_name EnemyBase

var data: EnemyData
var hp: float = 30.0
var player: Node2D = null
var attack_timer: float = 0.0
var is_dead: bool = false

# 减速状态（寒冰领域等技能使用）
var is_slowed: bool = false
var base_move_speed: float = 0.0  # 记录原始速度，用于恢复

# 视觉节点（程序生成，无需美术）
var visual: AnimatedSprite2D
var hp_bar: ColorRect
var hp_bar_bg: ColorRect

func _ready() -> void:
	add_to_group("enemies")
	_find_player()
	# 注意：_setup_visual() 移到 setup() 里调用

func setup(enemy_data: EnemyData) -> void:
	data = enemy_data
	hp = data.max_hp
	base_move_speed = data.move_speed  # 记录原始速度
	_setup_visual()  # 有了data再建视觉

func _setup_visual() -> void:
	# 碰撞层：layer 2=enemies, mask 1=player
	collision_layer = 2
	collision_mask = 1

	# spritesheet 配置表：name -> {path, frames, frame_w, frame_h, fps}
	var sheet_map = {
		"小恶魔": {
			"path": "res://assets/sprites/enemies/demon_walk_sheet.png",
			"frames": 6, "frame_w": 170, "frame_h": 168, "fps": 8.0
		},
		"骷髅战士": {
			"path": "res://assets/sprites/enemies/skeleton_walk_sheet.png",
			"frames": 10, "frame_w": 204, "frame_h": 279, "fps": 10.0
		},
		"石头怪": {
			"path": "res://assets/sprites/enemies/stone_golem_walk_sheet.png",
			"frames": 8, "frame_w": 256, "frame_h": 279, "fps": 6.0
		},
		"暗影弓手": {
			"path": "res://assets/sprites/enemies/archer_walk_sheet.png",
			"frames": 6, "frame_w": 170, "frame_h": 168, "fps": 8.0
		},
		"火焰精灵": {
			"path": "res://assets/sprites/enemies/fire_sprite_walk_sheet.png",
			"frames": 6, "frame_w": 170, "frame_h": 559, "fps": 8.0
		},
		"深渊魔王": {
			"path": "res://assets/sprites/enemies/boss_walk_sheet.png",
			"frames": 8, "frame_w": 256, "frame_h": 279, "fps": 6.0
		},
	}

	# 静态图兜底表（单帧精灵，用 Sprite2D 直接显示）
	var static_map = {
		"小恶魔":   "res://assets/sprites/enemies/enemy_demon.png",
		"石头怪":   "res://assets/sprites/enemies/enemy_golem.png",
		"暗影弓手": "res://assets/sprites/enemies/enemy_archer.png",
		"火焰精灵": "res://assets/sprites/enemies/enemy_fire_sprite.png",
		"骷髅战士": "res://assets/sprites/enemies/enemy_skeleton.png",
		"深渊魔王": "res://assets/sprites/enemies/enemy_boss_abyss.png",
	}


	var anim_sprite = AnimatedSprite2D.new()
	anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	var name_key = data.display_name if data else ""

	if sheet_map.has(name_key):
		# 用动画 spritesheet — 改用 Sprite2D + hframes 方式，避免 AtlasTexture 兼容问题
		var cfg = sheet_map[name_key]
		var tex = load(cfg["path"])
		if tex == null:
			push_error("EnemyBase: 找不到贴图 " + cfg["path"])
		else:
			# 用 AnimationPlayer + Sprite2D 组合，或直接用 AnimatedSprite2D 但用 create_from_image
			# 最简单稳定方案：AnimatedSprite2D，逐帧用 sub region
			var sf = SpriteFrames.new()
			sf.add_animation("walk")
			sf.set_animation_loop("walk", true)
			sf.set_animation_speed("walk", cfg["fps"])
			for i in range(cfg["frames"]):
				var atlas = AtlasTexture.new()
				atlas.atlas = tex
				atlas.region = Rect2(i * cfg["frame_w"], 0, cfg["frame_w"], cfg["frame_h"])
				atlas.filter_clip = true
				sf.add_frame("walk", atlas)
			sf.add_animation("idle")
			sf.set_animation_loop("idle", true)
			sf.set_animation_speed("idle", 1.0)
			var idle_atlas = AtlasTexture.new()
			idle_atlas.atlas = tex
			idle_atlas.region = Rect2(0, 0, cfg["frame_w"], cfg["frame_h"])
			idle_atlas.filter_clip = true
			sf.add_frame("idle", idle_atlas)
			anim_sprite.sprite_frames = sf
			var display_size = 128.0 if (data and data.display_name == "深渊魔王") else (192.0 if (data and data.display_name == "火焰精灵") else 64.0)
			anim_sprite.scale = Vector2(display_size / cfg["frame_h"], display_size / cfg["frame_h"])
			anim_sprite.play("walk")
	elif static_map.has(name_key):
		# 兜底：静态图包成单帧动画
		var tex = load(static_map[name_key])
		var sf = SpriteFrames.new()
		sf.add_animation("idle")
		sf.set_animation_loop("idle", true)
		sf.set_animation_speed("idle", 1.0)
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(0, 0, tex.get_width(), tex.get_height())
		sf.add_frame("idle", atlas)
		anim_sprite.sprite_frames = sf
		# 根据 data.size 设定显示尺寸（单位：游戏像素），图片本身128px
		var display_px = (data.size if data else 16.0) * 2.5
		var tex_size = float(max(tex.get_width(), tex.get_height()))
		anim_sprite.scale = Vector2(display_px / tex_size, display_px / tex_size)
		anim_sprite.play("idle")

	add_child(anim_sprite)
	visual = anim_sprite

	# 血条背景
	hp_bar_bg = ColorRect.new()
	hp_bar_bg.size = Vector2(30, 4)
	hp_bar_bg.position = Vector2(-15, -30)
	hp_bar_bg.color = Color(0.2, 0.0, 0.0)
	add_child(hp_bar_bg)

	# 血条
	hp_bar = ColorRect.new()
	hp_bar.size = Vector2(30, 4)
	hp_bar.position = Vector2(-15, -30)
	hp_bar.color = Color(0.0, 0.9, 0.2)
	add_child(hp_bar)

	# 碰撞体（根据实际 size 动态设置）
	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	var sz = data.size if data else 16.0
	rect.size = Vector2(sz, sz)
	col.shape = rect
	add_child(col)

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if is_dead or not is_instance_valid(player):
		return
	if EventBus.game_logic_paused:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	attack_timer -= delta
	_move(delta)
	_try_attack()
	move_and_slide()

func _move(delta: float) -> void:
	var dir = global_position.direction_to(player.global_position)
	velocity = dir * base_move_speed  # 用实例变量，支持减速叠加
	# 左右翻转 + 确保播放 walk
	if visual and visual.sprite_frames and visual.sprite_frames.has_animation("walk"):
		if visual.animation != "walk":
			visual.play("walk")
		if dir.x != 0:
			visual.flip_h = dir.x < 0

func _try_attack() -> void:
	if attack_timer > 0:
		return
	var dist = global_position.distance_to(player.global_position)
	if dist < data.size + 16:
		attack_timer = data.attack_cooldown
		player.take_damage(data.damage)

func take_damage(dmg: float, is_crit: bool = false) -> void:
	if is_dead:
		return
	hp -= dmg
	_update_hp_bar()
	# 受击闪白（Sprite2D用modulate）
	visual.modulate = Color(2.0, 2.0, 2.0)
	var tween = create_tween()
	tween.tween_property(visual, "modulate", Color(1, 1, 1, 1), 0.1)
	# 受击 scale 弹跳
	var hit_tween = create_tween()
	hit_tween.set_parallel(true)
	hit_tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.05)
	hit_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_delay(0.05)
	# 音效
	var snd = get_tree().get_first_node_in_group("sound_manager")
	if snd:
		snd.play_hit()
	# 伤害飘字
	var dn = Node2D.new()
	dn.set_script(load("res://scripts/systems/DamageNumber.gd"))
	get_tree().current_scene.add_child(dn)
	dn.global_position = global_position + Vector2(randf_range(-15, 15), -20)
	dn.setup(dmg, is_crit)
	if hp <= 0:
		die()

func _update_hp_bar() -> void:
	var ratio = max(hp / data.max_hp, 0.0)
	hp_bar.size.x = 30 * ratio

func die() -> void:
	is_dead = true
	# 音效
	var snd = get_tree().get_first_node_in_group("sound_manager")
	if snd:
		snd.play_enemy_die()
	# 死亡粒子特效
	var fx = Node2D.new()
	fx.set_script(load("res://scripts/systems/DeathEffect.gd"))
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position
	fx.setup(data.color if data else Color(0.8, 0.2, 0.2))
	# 掉落经验
	EventBus.emit_signal("enemy_died", global_position, data.exp_reward if data else 5)
	queue_free()
