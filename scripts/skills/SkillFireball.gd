# SkillFireball.gd
# 火焰术 - 多弹散射，发射数量随等级增加
extends SkillBase
class_name SkillFireball

func activate() -> void:
	if not owner_player or not is_instance_valid(owner_player):
		return
	var target = get_nearest_enemy()
	if not target:
		return
	var shoot_count = level
	var base_dir = owner_player.global_position.direction_to(target.global_position)
	var base_angle = base_dir.angle()
	var spread = deg_to_rad(15.0)
	for i in range(shoot_count):
		var offset = 0.0
		if shoot_count > 1:
			offset = spread * (i - (shoot_count - 1) / 2.0)
		var dir = Vector2(cos(base_angle + offset), sin(base_angle + offset))
		_spawn_projectile_dir(dir)
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm:
		sm.play_shoot()

# 用 ArrayMesh 画填充圆
static func _make_circle_mesh(radius: float, color: Color) -> ArrayMesh:
	var segments = 32
	var vertices = PackedVector2Array()
	var colors = PackedColorArray()
	# 用三角扇形填充
	for i in range(segments):
		var a0 = (TAU / segments) * i
		var a1 = (TAU / segments) * (i + 1)
		vertices.append(Vector2.ZERO)
		vertices.append(Vector2(cos(a0), sin(a0)) * radius)
		vertices.append(Vector2(cos(a1), sin(a1)) * radius)
		colors.append(color)
		colors.append(color)
		colors.append(color)
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _spawn_projectile_dir(dir: Vector2) -> void:
	var proj = Area2D.new()
	proj.set_script(load("res://scripts/skills/Projectile.gd"))
	proj.add_to_group("player_projectiles")

	# 碰撞体
	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 10.0
	col.shape = circle
	proj.add_child(col)

	# ── 外层光晕（大圆，半透明橙）─────────────────────
	var glow_mesh = MeshInstance2D.new()
	glow_mesh.mesh = _make_circle_mesh(18.0, Color(1.0, 0.35, 0.0, 0.30))
	glow_mesh.use_parent_material = false
	proj.add_child(glow_mesh)

	# ── 内核（小圆，亮黄白）───────────────────────────
	var core_mesh = MeshInstance2D.new()
	core_mesh.mesh = _make_circle_mesh(9.0, Color(1.0, 0.95, 0.4, 1.0))
	proj.add_child(core_mesh)

	# ── 火焰尾迹粒子 ──────────────────────────────────
	var trail = GPUParticles2D.new()
	trail.emitting = true
	trail.amount = 24
	trail.lifetime = 0.4
	trail.explosiveness = 0.0
	trail.randomness = 0.2
	trail.local_coords = false

	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(-1, 0, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 20.0
	pm.initial_velocity_max = 60.0
	pm.gravity = Vector3(0, 0, 0)
	pm.scale_min = 3.0
	pm.scale_max = 8.0
	var grad = Gradient.new()
	grad.set_color(0, Color(1.0, 0.8, 0.1, 0.9))
	grad.set_color(1, Color(0.8, 0.1, 0.0, 0.0))
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = grad
	pm.color_ramp = grad_tex
	trail.process_material = pm
	proj.add_child(trail)
	proj.move_child(trail, 0)

	get_tree().current_scene.add_child(proj)
	proj.global_position = owner_player.global_position

	var angle_deg = rad_to_deg(dir.angle()) + 180.0
	trail.rotation_degrees = angle_deg

	proj.setup_dir(get_current_damage(), dir, data.speed if data else 350.0, data.pierce_count if data else 1)
