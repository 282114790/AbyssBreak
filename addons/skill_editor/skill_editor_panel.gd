# skill_editor_panel.gd
# 深渊突围技能编辑器 - 加载真实游戏数据，可预览真实技能效果
@tool
extends Control

var editor_interface = null

# ── 真实技能数据（与 Main.gd._register_demo_content 完全一致）────────────────
const SkillDataScript   = "res://scripts/skills/SkillData.gd"
const PassiveDataScript = "res://scripts/systems/PassiveData.gd"
const CharDataScript    = "res://scripts/player/CharacterData.gd"
const CharRegistry      = "res://scripts/player/CharacterRegistry.gd"

const RAW_SKILLS := [
	# [id, display_name, description, max_level, cooldown, lvup_cd, damage, lvup_dmg, scene_path, pierce, proj_count]
	["fireball",      "🔥 火焰术",    "向最近敌人发射追踪火球，范围爆炸",          5, 0.6,  -0.08, 25.0, 15.0, "res://scripts/skills/SkillFireball.gd",      1, 1],
	["orbital",       "🛡 魔法护盾",  "绕身旋转的魔法护盾，持续伤害近身敌人",      5, 0.0,   0.0,  12.0, 10.0, "res://scripts/skills/SkillOrbital.gd",       99, 3],
	["lightning",     "⚡ 雷击链",    "闪电在敌人间弹跳3次",                        5, 1.0,  -0.08, 25.0, 12.0, "res://scripts/skills/SkillLightning.gd",     3, 1],
	["iceblade",      "❄ 冰刃术",    "直线冰刃穿透所有敌人",                       5, 0.8,  -0.08, 30.0, 18.0, "res://scripts/skills/SkillIceBlade.gd",      99, 2],
	["frostzone",     "🌀 寒冰领域",  "范围内敌人减速50%并持续受伤",               5, 0.3,  -0.01, 10.0, 8.0,  "res://scripts/skills/SkillFrostZone.gd",     99, 1],
	["runeblast",     "💥 爆裂符文",  "在敌人脚下放置符文，1.5秒后爆炸",          5, 1.5,  -0.1,  50.0, 25.0, "res://scripts/skills/SkillRuneBlast.gd",     99, 1],
	["holywave",      "✨ 圣光波",    "向8方向发射扩散光波，覆盖全屏",              5, 5.0,  -0.2,  15.0, 8.0,  "res://scripts/skills/SkillHolyWave.gd",      99, 8],
	["poison_cloud",  "☠ 毒雾领域",  "周身毒雾持续中毒敌人，升级扩大范围",        5, 0.0,   0.0,  8.0,  5.0,  "res://scripts/skills/SkillPoisonCloud.gd",   99, 1],
	["void_rift",     "🌑 虚空裂缝",  "生成黑洞吸引并持续伤害周围敌人",            5, 6.0,  -0.3,  20.0, 10.0, "res://scripts/skills/SkillVoidRift.gd",      99, 1],
	["arcane_orb",    "💠 奥术弹幕",  "多颗弹幕公转后向外飞射，升级增加数量",      5, 2.5,  -0.2,  22.0, 12.0, "res://scripts/skills/SkillArcaneOrb.gd",     1, 3],
	["blood_nova",    "🩸 血月新星",  "消耗5%HP释放血色冲击波，HP越低伤害越高",   5, 3.5,  -0.2,  35.0, 18.0, "res://scripts/skills/SkillBloodNova.gd",     99, 1],
	["time_slow",     "⏳ 时间减速",  "减慢所有敌人80%速度，持续时间随等级增加",   5, 8.0,  -0.5,  0.0,  0.0,  "res://scripts/skills/SkillTimeSlow.gd",      99, 1],
	["thorn_aura",    "🌿 荆棘护甲",  "受击时反弹50%伤害，周身荆棘光环",          5, 0.0,   0.0,  0.0,  0.0,  "res://scripts/skills/SkillThornAura.gd",     99, 1],
	["meteor_shower", "☄ 陨石雨",    "从天而降多颗陨石砸向敌人密集区域",          5, 5.0,  -0.3,  40.0, 20.0, "res://scripts/skills/SkillMeteorShower.gd",  1, 1],
	["chain_lance",   "🏹 穿刺长枪",  "穿透长枪贯穿多个敌人，升级增加穿透数",     5, 1.2,  -0.1,  35.0, 18.0, "res://scripts/skills/SkillChainLance.gd",    5, 1],
]

const CHAR_INFO := {
	"mage":    {"name": "🧙 法师",  "damage_mult": 1.2, "speed_mult": 1.0,  "hp_mult": 1.0,  "regen": 0.0, "color": Color(0.6,0.3,1.0), "start": "fireball",  "sheet": "res://assets/sprites/player/mage_walk_sheet.png",   "fw": 200, "fh": 192, "fc": 8},
	"warrior": {"name": "⚔ 战士",  "damage_mult": 1.0, "speed_mult": 0.85, "hp_mult": 1.8,  "regen": 3.0, "color": Color(0.9,0.4,0.1), "start": "iceblade",  "sheet": "res://assets/sprites/warrior_walk_sheet.png",        "fw": 128, "fh": 128, "fc": 8},
	"hunter":  {"name": "🏹 猎手",  "damage_mult": 1.0, "speed_mult": 1.35, "hp_mult": 0.75, "regen": 0.0, "color": Color(0.2,0.8,0.4), "start": "lightning", "sheet": "res://assets/sprites/hunter_walk_sheet.png",         "fw": 128, "fh": 128, "fc": 8},
}

const CONFIG_PATH := "D:/AbyssBreak/skill_config.json"

# ── 运行时状态 ─────────────────────────────────────────────────────────────────
var _skill_data_map: Dictionary = {}   # id -> SkillData 实例（真实值）
var _config: Dictionary = {}           # 编辑器覆盖值
var _cur_skill_id: String = "fireball"
var _cur_char_id:  String = "mage"
var _preview_viewport: SubViewport = null
var _preview_container: SubViewportContainer = null
var _preview_player: Node = null
var _preview_skill: Node = null
var _preview_timer: float = 0.0
var _preview_active: bool = false

# UI
var _skill_list: ItemList
var _char_btns: Dictionary = {}
var _param_fields: Dictionary = {}
var _chart_panel: Panel
var _matrix_grid: GridContainer
var _status_label: Label
var _preview_lv_spin: SpinBox
var _info_label: Label

# ── 初始化 ────────────────────────────────────────────────────────────────────
func _load_config() -> void:
	_config = {}
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var f = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not f:
		return
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_config = parsed

func _ready() -> void:
	_load_config()
	_build_real_skill_data()
	_build_ui()
	_select_skill(0)

func _build_real_skill_data() -> void:
	var SD = load(SkillDataScript)
	for row in RAW_SKILLS:
		var sd = SD.new()
		sd.id                = row[0]
		sd.display_name      = row[1]
		sd.description       = row[2]
		sd.max_level         = row[3]
		sd.cooldown          = row[4]
		sd.level_up_cooldown = row[5]
		sd.damage            = row[6]
		sd.level_up_damage   = row[7]
		sd.scene_path        = row[8]
		sd.pierce_count      = row[9]
		sd.projectile_count  = row[10]
		# 应用编辑器覆盖
		_apply_overrides_to(sd)
		_skill_data_map[sd.id] = sd

func _apply_overrides_to(sd) -> void:
	var ov = _config.get(sd.id, {})
	if ov.has("damage"):            sd.damage            = float(ov["damage"])
	if ov.has("level_up_damage"):   sd.level_up_damage   = float(ov["level_up_damage"])
	if ov.has("cooldown"):          sd.cooldown          = float(ov["cooldown"])
	if ov.has("level_up_cooldown"): sd.level_up_cooldown = float(ov["level_up_cooldown"])
	if ov.has("speed"):             sd.speed             = float(ov["speed"])
	if ov.has("range_radius"):      sd.range_radius      = float(ov["range_radius"])
	if ov.has("pierce_count"):      sd.pierce_count      = int(ov["pierce_count"])
	if ov.has("projectile_count"):  sd.projectile_count  = int(ov["projectile_count"])
	if ov.has("max_level"):         sd.max_level         = int(ov["max_level"])

# ── UI 构建 ───────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	custom_minimum_size = Vector2(0, 480)
	var root_h = HSplitContainer.new()
	root_h.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_h.split_offset = 190
	add_child(root_h)

	# ══ 左栏：职业 + 技能列表 ══════════════════════════════════════════════════
	var left = VBoxContainer.new()
	left.custom_minimum_size = Vector2(190, 0)
	root_h.add_child(left)

	var clbl = Label.new(); clbl.text = "职业"
	clbl.add_theme_color_override("font_color", Color(0.8,0.8,0.5))
	left.add_child(clbl)

	var char_row = HBoxContainer.new()
	left.add_child(char_row)
	for cid in ["mage","warrior","hunter"]:
		var btn = Button.new()
		btn.text = CHAR_INFO[cid]["name"]
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(56, 26)
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(_on_char_selected.bind(cid))
		char_row.add_child(btn)
		_char_btns[cid] = btn
	_char_btns["mage"].button_pressed = true

	# 角色属性信息
	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 10)
	_info_label.add_theme_color_override("font_color", Color(0.7,0.7,0.9))
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_info_label)

	var sep = HSeparator.new(); left.add_child(sep)

	var slbl = Label.new(); slbl.text = "技能列表"
	slbl.add_theme_color_override("font_color", Color(0.8,0.8,0.5))
	left.add_child(slbl)

	_skill_list = ItemList.new()
	_skill_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_skill_list.item_selected.connect(_on_skill_list_selected)
	left.add_child(_skill_list)

	for i in range(RAW_SKILLS.size()):
		var row = RAW_SKILLS[i]
		_skill_list.add_item(row[1])
		_skill_list.set_item_metadata(i, row[0])
		# Tooltip：技能描述 + 关键参数
		var cd    = row[4]
		var dmg   = row[6]
		var lvup_dmg = row[7]
		var max_lv   = row[3]
		var pierce   = row[9]
		var proj     = row[10]
		var tip = "%s\n\n%s\n\n⚔ 基础伤害：%.0f（每级+%.0f）\n⏱ 冷却时间：%.1fs\n🎯 穿透：%s  弹数：%d\n⬆ 最大等级：%d" % [
			row[1], row[2],
			dmg, lvup_dmg,
			cd,
			"∞" if pierce >= 99 else str(pierce),
			proj, max_lv
		]
		_skill_list.set_item_tooltip(i, tip)

	# ══ 中+右 VSplit ══════════════════════════════════════════════════════════
	var right_v = VSplitContainer.new()
	right_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_v.split_offset = 300
	root_h.add_child(right_v)

	# ── 上半：参数编辑 + 曲线 + 矩阵（横向3列）
	var top_h = HSplitContainer.new()
	top_h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_h.split_offset = 280
	right_v.add_child(top_h)

	# ── 参数面板 ──
	var param_scroll = ScrollContainer.new()
	param_scroll.custom_minimum_size = Vector2(270, 0)
	param_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_h.add_child(param_scroll)

	var pv = VBoxContainer.new()
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	param_scroll.add_child(pv)

	var ptitle = Label.new(); ptitle.text = "⚙ 技能参数（真实数据）"
	ptitle.add_theme_font_size_override("font_size", 13)
	ptitle.add_theme_color_override("font_color", Color(1.0,0.85,0.3))
	pv.add_child(ptitle)

	# 字段：[key, 显示名, min, max, step, float?]
	var fields := [
		["damage",           "基础伤害",       0.0, 500.0, 0.5,  true ],
		["level_up_damage",  "每级伤害成长",   0.0, 200.0, 0.5,  true ],
		["cooldown",         "冷却时间(s)",    0.0,  30.0, 0.05, true ],
		["level_up_cooldown","每级冷却削减",  -3.0,   0.0, 0.05, true ],
		["speed",            "投射物速度",     0.0,2000.0, 10.0, false],
		["range_radius",     "范围半径(px)",   0.0,2000.0, 10.0, false],
		["pierce_count",     "穿透次数",       1.0,  20.0,  1.0, false],
		["projectile_count", "投射数量",       1.0,  20.0,  1.0, false],
		["max_level",        "最大等级",       1.0,  20.0,  1.0, false],
	]

	for fd in fields:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		pv.add_child(row)
		var lbl = Label.new(); lbl.text = fd[1]
		lbl.custom_minimum_size = Vector2(115,0)
		lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(lbl)
		var spin = SpinBox.new()
		spin.min_value = fd[2]; spin.max_value = fd[3]; spin.step = fd[4]
		if fd[5]: spin.rounded = false
		spin.custom_minimum_size = Vector2(100,0)
		spin.value_changed.connect(_on_param_changed.bind(fd[0]))
		row.add_child(spin)
		_param_fields[fd[0]] = spin
		var rst = Button.new(); rst.text = "↺"
		rst.custom_minimum_size = Vector2(24,0)
		rst.tooltip_text = "恢复游戏默认值"
		rst.pressed.connect(_on_reset_field.bind(fd[0]))
		row.add_child(rst)

	# ── 曲线 + 矩阵 ──
	var right_right = VBoxContainer.new()
	right_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_h.add_child(right_right)

	var chart_lbl = Label.new(); chart_lbl.text = "DPS成长曲线（三职业）"
	chart_lbl.add_theme_color_override("font_color", Color(0.8,0.8,0.5))
	right_right.add_child(chart_lbl)

	_chart_panel = Panel.new()
	_chart_panel.custom_minimum_size = Vector2(0, 180)
	_chart_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart_panel.draw.connect(_draw_chart)
	right_right.add_child(_chart_panel)

	var mat_lbl = Label.new(); mat_lbl.text = "职业×等级 最终伤害矩阵"
	mat_lbl.add_theme_color_override("font_color", Color(0.8,0.8,0.5))
	right_right.add_child(mat_lbl)

	_matrix_grid = GridContainer.new()
	_matrix_grid.columns = 6  # 等级 + 法/战/猎 + DPS + 冷却
	right_right.add_child(_matrix_grid)

	# ══ 下半：预览面板 ════════════════════════════════════════════════════════
	var preview_vbox = VBoxContainer.new()
	preview_vbox.custom_minimum_size = Vector2(0, 160)
	right_v.add_child(preview_vbox)

	# 预览控制栏
	var ctrl_row = HBoxContainer.new()
	ctrl_row.add_theme_constant_override("separation", 8)
	preview_vbox.add_child(ctrl_row)

	var preview_title = Label.new(); preview_title.text = "▶ 技能预览（真实渲染）"
	preview_title.add_theme_color_override("font_color", Color(1.0,0.85,0.3))
	preview_title.add_theme_font_size_override("font_size", 13)
	ctrl_row.add_child(preview_title)

	var lv_lbl = Label.new(); lv_lbl.text = "预览等级:"
	ctrl_row.add_child(lv_lbl)
	_preview_lv_spin = SpinBox.new()
	_preview_lv_spin.min_value = 1; _preview_lv_spin.max_value = 10; _preview_lv_spin.value = 1
	_preview_lv_spin.custom_minimum_size = Vector2(60,0)
	ctrl_row.add_child(_preview_lv_spin)

	var start_btn = Button.new(); start_btn.text = "▶ 启动预览"
	start_btn.pressed.connect(_start_preview)
	ctrl_row.add_child(start_btn)

	var stop_btn = Button.new(); stop_btn.text = "⏹ 停止"
	stop_btn.pressed.connect(_stop_preview)
	ctrl_row.add_child(stop_btn)

	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", Color(0.4,1.0,0.4))
	_status_label.add_theme_font_size_override("font_size", 11)
	ctrl_row.add_child(_status_label)

	var action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	preview_vbox.add_child(action_row)

	var save_btn = Button.new(); save_btn.text = "💾 保存参数"
	save_btn.pressed.connect(_save_config)
	action_row.add_child(save_btn)

	var reset_btn = Button.new(); reset_btn.text = "↺ 重置此技能"
	reset_btn.pressed.connect(_reset_cur_skill)
	action_row.add_child(reset_btn)

	var balance_btn = Button.new(); balance_btn.text = "⚖ 平衡报告"
	balance_btn.pressed.connect(_show_balance_report)
	action_row.add_child(balance_btn)

	# SubViewport 预览窗口
	_preview_container = SubViewportContainer.new()
	_preview_container.custom_minimum_size = Vector2(0, 220)
	_preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_container.stretch = true
	preview_vbox.add_child(_preview_container)

	_preview_viewport = SubViewport.new()
	_preview_viewport.size = Vector2i(400, 300)
	_preview_viewport.transparent_bg = true
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# 编辑器内让子节点正常执行 _ready/_process
	_preview_viewport.process_mode = Node.PROCESS_MODE_ALWAYS
	_preview_container.add_child(_preview_viewport)

	# SubViewport 里放一个简单背景
	var bg_rect = ColorRect.new()
	bg_rect.color = Color(0.05, 0.05, 0.12, 1.0)
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_viewport.add_child(bg_rect)

# ── 预览系统 ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if not _preview_active: return
	_preview_timer += delta
	# 每 2 秒重新触发一次技能 activate（让效果持续可见）
	if _preview_timer >= 2.0:
		_preview_timer = 0.0
		_trigger_skill_once()

func _start_preview() -> void:
	_stop_preview()
	_set_status("⏳ 启动预览...")

	var sd = _skill_data_map.get(_cur_skill_id)
	if sd == null:
		_set_status("❌ 技能数据未找到"); return

	var script_path = sd.scene_path
	if not ResourceLoader.exists(script_path):
		_set_status("❌ 找不到脚本: " + script_path); return

	# 清理旧预览
	for c in _preview_viewport.get_children():
		if c is not ColorRect: c.queue_free()

	# 背景网格（模拟游戏地板）
	var grid = _make_preview_grid()
	_preview_viewport.add_child(grid)

	# 创建一个简易 Player 代理（挂 preview_player.gd 提供 hp 等属性）
	_preview_player = Node2D.new()
	_preview_player.set_script(load("res://addons/skill_editor/preview_player.gd"))
	_preview_player.name = "PreviewPlayer"
	_preview_player.position = Vector2(200, 150)
	_preview_player.add_to_group("player")

	# 给 Player 代理注入职业倍率
	_preview_player.damage_multiplier = CHAR_INFO[_cur_char_id]["damage_mult"]

	# 角色精灵
	var char_info = CHAR_INFO[_cur_char_id]
	var anim = _make_char_sprite(char_info)
	_preview_player.add_child(anim)

	# 角色名标签
	var name_lbl = Label.new()
	name_lbl.text = char_info["name"]
	name_lbl.position = Vector2(-32, -54)
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", char_info["color"])
	_preview_player.add_child(name_lbl)

	_preview_viewport.add_child(_preview_player)

	# 创建敌人假人（供技能寻找目标）
	_make_dummy_enemies()

	# 实例化真实技能脚本
	var lv = int(_preview_lv_spin.value)
	_preview_skill = _instantiate_skill(sd, lv)
	if _preview_skill == null:
		_set_status("❌ 技能实例化失败"); return

	_preview_player.add_child(_preview_skill)

	# 等一帧让 _ready() 执行，再注入属性（否则 set() 在脚本初始化前无效）
	await get_tree().process_frame
	_preview_skill.set("data", sd)
	_preview_skill.set("level", lv)
	_preview_skill.set("owner_player", _preview_player)
	_preview_skill.set("spawn_root", _preview_viewport)

	_preview_active = true
	_preview_timer = 0.0
	_set_status("✅ %s Lv%d 预览中（%s）" % [sd.display_name, lv, CHAR_INFO[_cur_char_id]["name"]])

	# 立即触发一次
	_trigger_skill_once()

func _stop_preview() -> void:
	_preview_active = false
	if is_instance_valid(_preview_player):
		_preview_player.queue_free()
		_preview_player = null
	_preview_skill = null
	# 清空 viewport（保留背景）
	for c in _preview_viewport.get_children():
		if c is not ColorRect: c.queue_free()
	if _preview_active == false and _status_label:
		if _status_label.text.begins_with("✅"):
			_set_status("⏹ 预览已停止")

func _instantiate_skill(sd, lv: int) -> Node:
	var script = load(sd.scene_path)
	if script == null: return null
	var node = Node2D.new()
	node.set_script(script)
	node.name = "PreviewSkill_" + sd.id
	# 预写一次（add_child 前），_ready 后会被覆盖写一次
	node.set("data", sd)
	node.set("level", lv)
	node.set("owner_player", _preview_player)
	node.set("spawn_root", _preview_viewport)
	return node

func _trigger_skill_once() -> void:
	if not is_instance_valid(_preview_skill): return
	if not is_instance_valid(_preview_player): return
	# 调试：确认注入情况
	var d = _preview_skill.get("data")
	var op = _preview_skill.get("owner_player")
	var sr = _preview_skill.get("spawn_root")
	print("[SkillEditor] trigger: data=", d, " owner_player=", op, " spawn_root=", sr)
	print("[SkillEditor] skill pos=", _preview_skill.global_position, " player pos=", _preview_player.global_position)
	print("[SkillEditor] enemies in viewport=", _preview_viewport.get_children().filter(func(n): return n.is_in_group("enemies")).size())
	# 调用真实 activate()
	if _preview_skill.has_method("activate"):
		_preview_skill.call("activate")

func _make_char_sprite(char_info: Dictionary) -> AnimatedSprite2D:
	var anim = AnimatedSprite2D.new()
	anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sheet_path = char_info["sheet"]
	var fw = char_info["fw"]
	var fh = char_info["fh"]
	var fc = char_info["fc"]
	if not ResourceLoader.exists(sheet_path):
		# 找不到精灵表，用彩色方块代替
		var fallback = ColorRect.new()
		fallback.color = char_info["color"]
		fallback.size = Vector2(32, 32)
		fallback.position = Vector2(-16, -16)
		var dummy = Node2D.new()
		dummy.add_child(fallback)
		return anim  # 返回空 AnimatedSprite2D
	var tex = load(sheet_path)
	var frames = SpriteFrames.new()
	frames.add_animation("walk")
	frames.set_animation_loop("walk", true)
	frames.set_animation_speed("walk", 8.0)
	for i in range(fc):
		var at = AtlasTexture.new()
		at.atlas = tex; at.region = Rect2(i * fw, 0, fw, fh)
		frames.add_frame("walk", at)
	anim.sprite_frames = frames
	anim.animation = "walk"
	anim.play()
	# 缩放到合适预览大小
	var scale_f = 48.0 / fh
	anim.scale = Vector2(scale_f, scale_f)
	return anim

func _make_dummy_enemies() -> void:
	var dummy_script = load("res://addons/skill_editor/preview_dummy_enemy.gd")
	var positions = [Vector2(340,80), Vector2(380,150), Vector2(310,200), Vector2(60,100), Vector2(100,180)]
	for i in range(positions.size()):
		var enemy = Node2D.new()
		enemy.set_script(dummy_script)
		enemy.name = "DummyEnemy%d" % i
		enemy.position = positions[i]
		enemy.add_to_group("enemies")
		_preview_viewport.add_child(enemy)

func _make_preview_grid() -> Node2D:
	var grid = Node2D.new()
	grid.name = "PreviewGrid"
	var cell = 32
	for x in range(0, 420, cell):
		for y in range(0, 320, cell):
			var r = ColorRect.new()
			r.position = Vector2(x, y)
			r.size = Vector2(cell - 1, cell - 1)
			r.color = Color(0.08, 0.08, 0.16) if (x + y) % (cell * 2) == 0 else Color(0.06, 0.06, 0.12)
			grid.add_child(r)
	return grid

# ── 数据计算 ──────────────────────────────────────────────────────────────────
func _get_sd(skill_id: String):
	return _skill_data_map.get(skill_id)

func _get_param(skill_id: String, key: String) -> float:
	var ov = _config.get(skill_id, {})
	if ov.has(key): return float(ov[key])
	# 从 RAW_SKILLS 读原始默认值
	for row in RAW_SKILLS:
		if row[0] != skill_id: continue
		match key:
			"damage":            return float(row[6])
			"level_up_damage":   return float(row[7])
			"cooldown":          return float(row[4])
			"level_up_cooldown": return float(row[5])
			"pierce_count":      return float(row[9])
			"projectile_count":  return float(row[10])
			"max_level":         return float(row[3])
			"speed":             return 300.0
			"range_radius":      return 0.0
	return 0.0

func _calc_damage(skill_id: String, lv: int, char_id: String) -> float:
	var base  = _get_param(skill_id, "damage")
	var perlv = _get_param(skill_id, "level_up_damage")
	var mult  = float(CHAR_INFO[char_id]["damage_mult"])
	return (base + perlv * (lv - 1)) * mult

func _calc_cd(skill_id: String, lv: int) -> float:
	var cd    = _get_param(skill_id, "cooldown")
	var perlv = _get_param(skill_id, "level_up_cooldown")
	return max(cd + perlv * (lv - 1), 0.05)

func _calc_dps(skill_id: String, lv: int, char_id: String) -> float:
	var dmg  = _calc_damage(skill_id, lv, char_id)
	var cd   = _calc_cd(skill_id, lv)
	var proj = _get_param(skill_id, "projectile_count")
	if cd <= 0.0: return dmg * proj * 10.0  # 持续型技能
	return dmg * proj / cd

# ── UI 刷新 ───────────────────────────────────────────────────────────────────
func _refresh_all() -> void:
	_refresh_info_label()
	_refresh_params()
	_refresh_matrix()
	if _chart_panel: _chart_panel.queue_redraw()
	# 如果预览在跑，重启
	if _preview_active: _start_preview()

func _refresh_info_label() -> void:
	if not _info_label: return
	var ci = CHAR_INFO[_cur_char_id]
	var sd = _get_sd(_cur_skill_id)
	var start_mark = "⭐ 初始技能" if ci["start"] == _cur_skill_id else ""
	_info_label.text = "HP×%.2f  速度×%.2f\n伤害×%.2f  回血%.1f/s\n%s" % [
		ci["hp_mult"], ci["speed_mult"], ci["damage_mult"], ci["regen"], start_mark
	]

func _refresh_params() -> void:
	for key in _param_fields:
		var val = _get_param(_cur_skill_id, key)
		_param_fields[key].set_value_no_signal(val)

func _refresh_matrix() -> void:
	if not _matrix_grid: return
	for c in _matrix_grid.get_children(): c.free()

	var max_lv = int(_get_param(_cur_skill_id, "max_level"))
	var show_lvs: Array = []
	if max_lv <= 5:
		for i in range(1, max_lv+1): show_lvs.append(i)
	else:
		show_lvs = [1, 2, 3, 5, max_lv]

	# 表头
	_mcell("等级", Color(0.9,0.9,0.5), true)
	for cid in ["mage","warrior","hunter"]:
		_mcell(CHAR_INFO[cid]["name"], CHAR_INFO[cid]["color"], true)
	_mcell("DPS(法)", Color(0.8,0.8,0.5), true)
	_mcell("CD(s)",   Color(0.8,0.8,0.5), true)

	for lv in show_lvs:
		_mcell("Lv%d" % lv, Color.WHITE, false)
		for cid in ["mage","warrior","hunter"]:
			var dmg = _calc_damage(_cur_skill_id, lv, cid)
			_mcell("%.1f" % dmg, CHAR_INFO[cid]["color"].lightened(0.15), false)
		var dps = _calc_dps(_cur_skill_id, lv, "mage")
		var dps_col = Color(0.4,1.0,0.4) if dps < 80 else (Color(1.0,0.8,0.2) if dps < 200 else Color(1.0,0.3,0.3))
		_mcell("%.1f" % dps, dps_col, false)
		var cd = _calc_cd(_cur_skill_id, lv)
		_mcell("%.2f" % cd, Color(0.6,0.8,1.0), false)

func _mcell(txt: String, col: Color, bold: bool) -> void:
	var lbl = Label.new(); lbl.text = txt
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_size_override("font_size", 10 if not bold else 11)
	lbl.custom_minimum_size = Vector2(64, 18)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_matrix_grid.add_child(lbl)

# ── 曲线图 ────────────────────────────────────────────────────────────────────
func _draw_chart() -> void:
	if not _chart_panel: return
	var W = _chart_panel.size.x; var H = _chart_panel.size.y
	if W < 20 or H < 20: return
	_chart_panel.draw_rect(Rect2(0,0,W,H), Color(0.04,0.04,0.1))

	var PL=44; var PR=8; var PT=10; var PB=28
	var cw = W-PL-PR; var ch = H-PT-PB

	var max_lv = int(_get_param(_cur_skill_id, "max_level"))
	if max_lv < 1: max_lv = 5

	var all_vals: Array = []
	var char_pts: Dictionary = {}
	for cid in ["mage","warrior","hunter"]:
		var pts: Array = []
		for lv in range(1, max_lv+1):
			var v = _calc_dps(_cur_skill_id, lv, cid)
			pts.append(v); all_vals.append(v)
		char_pts[cid] = pts

	var mv = all_vals.max() if all_vals.size() > 0 else 1.0
	if mv <= 0: mv = 1.0

	# 网格
	for i in range(5):
		var gy = PT + ch*i/4
		_chart_panel.draw_line(Vector2(PL,gy), Vector2(PL+cw,gy), Color(0.18,0.18,0.28), 1)
		_chart_panel.draw_string(ThemeDB.fallback_font, Vector2(1,gy+4), "%.0f" % (mv*(4-i)/4), HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color(0.45,0.45,0.5))

	for lv in range(1, max_lv+1):
		var gx = PL + cw*(lv-1)/max(max_lv-1,1)
		_chart_panel.draw_string(ThemeDB.fallback_font, Vector2(gx-4,H-3), str(lv), HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color(0.45,0.45,0.5))

	var ccols := {"mage":Color(0.65,0.4,1.0),"warrior":Color(1.0,0.55,0.2),"hunter":Color(0.25,0.9,0.45)}
	var cnames := {"mage":"法师","warrior":"战士","hunter":"猎手"}
	for cid in ["mage","warrior","hunter"]:
		var pts = char_pts[cid]; var col = ccols[cid]; var prev = Vector2.ZERO
		for i in range(pts.size()):
			var x = PL + cw*i/max(max_lv-1,1)
			var y = PT + ch*(1.0-pts[i]/mv)
			var p = Vector2(x,y)
			if i>0: _chart_panel.draw_line(prev,p,col,2)
			_chart_panel.draw_circle(p,3,col)
			prev=p

	# 图例
	var lx = PL+4
	for cid in ["mage","warrior","hunter"]:
		_chart_panel.draw_rect(Rect2(lx,PT+2,10,7),ccols[cid])
		_chart_panel.draw_string(ThemeDB.fallback_font, Vector2(lx+12,PT+9), cnames[cid], HORIZONTAL_ALIGNMENT_LEFT,-1,9,ccols[cid])
		lx += 46

	var sn = RAW_SKILLS.filter(func(r): return r[0]==_cur_skill_id)
	var title = sn[0][1] if sn.size()>0 else _cur_skill_id
	_chart_panel.draw_string(ThemeDB.fallback_font, Vector2(W/2-30,PT+12), title+" DPS", HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(1.0,0.88,0.5))

# ── 选择回调 ──────────────────────────────────────────────────────────────────
func _on_char_selected(cid: String) -> void:
	_cur_char_id = cid
	for id in _char_btns: _char_btns[id].button_pressed = (id == cid)
	_refresh_all()

func _on_skill_list_selected(idx: int) -> void:
	_cur_skill_id = _skill_list.get_item_metadata(idx)
	_refresh_all()

func _select_skill(idx: int) -> void:
	if _skill_list and idx < _skill_list.get_item_count():
		_skill_list.select(idx)
		_on_skill_list_selected(idx)

# ── 参数编辑 ──────────────────────────────────────────────────────────────────
func _on_param_changed(val: float, key: String) -> void:
	if not _config.has(_cur_skill_id): _config[_cur_skill_id] = {}
	_config[_cur_skill_id][key] = val
	# 同步到 SkillData 实例
	var sd = _skill_data_map.get(_cur_skill_id)
	if sd: _apply_overrides_to(sd)
	_refresh_matrix()
	if _chart_panel: _chart_panel.queue_redraw()
	_set_status("● 已修改 %s.%s = %.3f（未保存）" % [_cur_skill_id, key, val])

func _on_reset_field(key: String) -> void:
	if _config.has(_cur_skill_id): _config[_cur_skill_id].erase(key)
	var sd = _skill_data_map.get(_cur_skill_id)
	if sd: _apply_overrides_to(sd)
	_refresh_params()
	_refresh_matrix()
	if _chart_panel: _chart_panel.queue_redraw()
	_set_status("↺ 已恢复 %s 默认值" % key)

# ── 保存/重置 ─────────────────────────────────────────────────────────────────
func _save_config() -> void:
	var f = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if not f: _set_status("❌ 无法写入 skill_config.json"); return
	f.store_string(JSON.stringify(_config, "\t")); f.close()
	_set_status("✅ 已保存到 skill_config.json（游戏重启后生效）")

func _reset_cur_skill() -> void:
	_config.erase(_cur_skill_id)
	var sd = _skill_data_map.get(_cur_skill_id)
	if sd:
		# 从 RAW_SKILLS 重新初始化
		for row in RAW_SKILLS:
			if row[0] != _cur_skill_id: continue
			sd.damage=row[6]; sd.level_up_damage=row[7]
			sd.cooldown=row[4]; sd.level_up_cooldown=row[5]
			sd.pierce_count=row[9]; sd.projectile_count=row[10]; sd.max_level=row[3]
	_refresh_all()
	_set_status("↺ 已重置 %s 为游戏默认值" % _cur_skill_id)

# ── 平衡报告 ──────────────────────────────────────────────────────────────────
func _show_balance_report() -> void:
	var lines: Array = ["=== 平衡报告（Lv5，法师 DPS）===\n"]
	var rows: Array = []
	for row in RAW_SKILLS:
		var sid = row[0]
		var lv = min(5, int(_get_param(sid,"max_level")))
		var dps = _calc_dps(sid, lv, "mage")
		rows.append({"name": row[1], "dps": dps})
	rows.sort_custom(func(a,b): return a["dps"]>b["dps"])
	var avg = 0.0; for r in rows: avg += r["dps"]; avg /= rows.size()
	for r in rows:
		var ratio = r["dps"]/max(avg,1.0)
		var warn = "  ⚠ 过强" if ratio>2.0 else ("  ⚠ 过弱" if ratio<0.4 else "")
		var bar = "█".repeat(int(clamp(ratio*8,1,24)))
		lines.append("%-10s %s %.1f%s" % [r["name"].substr(0,9), bar.substr(0,18), r["dps"], warn])
	lines.append("\n平均DPS: %.1f" % avg)

	var dlg = AcceptDialog.new()
	dlg.title = "⚖ 平衡报告"
	dlg.dialog_text = "\n".join(lines)
	dlg.min_size = Vector2(520, 500)
	get_tree().root.add_child(dlg)
	dlg.popup_centered()
	dlg.confirmed.connect(dlg.queue_free)

func _set_status(msg: String) -> void:
	if _status_label: _status_label.text = msg
