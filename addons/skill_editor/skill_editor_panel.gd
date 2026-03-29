# skill_editor_panel.gd
# 深渊突围技能编辑器主面板
@tool
extends Control

var editor_interface = null

# ── 数据 ──────────────────────────────────────────────────────────────────────
const SKILL_SCRIPTS := {
	"fireball":      "res://scripts/skills/SkillFireball.gd",
	"orbital":       "res://scripts/skills/SkillOrbital.gd",
	"lightning":     "res://scripts/skills/SkillLightning.gd",
	"iceblade":      "res://scripts/skills/SkillIceBlade.gd",
	"frostzone":     "res://scripts/skills/SkillFrostZone.gd",
	"runeblast":     "res://scripts/skills/SkillRuneBlast.gd",
	"holywave":      "res://scripts/skills/SkillHolyWave.gd",
	"poison_cloud":  "res://scripts/skills/SkillPoisonCloud.gd",
	"void_rift":     "res://scripts/skills/SkillVoidRift.gd",
	"arcane_orb":    "res://scripts/skills/SkillArcaneOrb.gd",
	"blood_nova":    "res://scripts/skills/SkillBloodNova.gd",
	"time_slow":     "res://scripts/skills/SkillTimeSlow.gd",
	"thorn_aura":    "res://scripts/skills/SkillThornAura.gd",
	"meteor_shower": "res://scripts/skills/SkillMeteorShower.gd",
	"chain_lance":   "res://scripts/skills/SkillChainLance.gd",
}

const SKILL_DISPLAY := {
	"fireball": "🔥 火焰术", "orbital": "🛡 轨道护盾", "lightning": "⚡ 雷链",
	"iceblade": "❄ 冰刃", "frostzone": "🌨 冻结领域", "runeblast": "💥 符文爆破",
	"holywave": "✨ 圣光波", "poison_cloud": "☠ 毒雾", "void_rift": "🌀 虚空裂缝",
	"arcane_orb": "🔮 奥术弹幕", "blood_nova": "🩸 血月新星", "time_slow": "⏳ 时间减速",
	"thorn_aura": "🌿 荆棘护甲", "meteor_shower": "☄ 陨石雨", "chain_lance": "🗡 穿刺长枪",
}

const CHAR_DATA := {
	"mage":    {"name": "🧙 法师", "damage_mult": 1.2, "speed_mult": 1.0, "hp_mult": 1.0, "color": Color(0.6,0.3,1.0)},
	"warrior": {"name": "⚔ 战士", "damage_mult": 1.0, "speed_mult": 0.85, "hp_mult": 1.8, "color": Color(0.9,0.4,0.1)},
	"hunter":  {"name": "🏹 猎手", "damage_mult": 1.0, "speed_mult": 1.35, "hp_mult": 0.75, "color": Color(0.2,0.8,0.4)},
}

const CONFIG_PATH := "D:/AbyssBreak/skill_config.json"

# 当前选中
var _cur_skill_id: String = "fireball"
var _cur_char_id: String = "mage"

# UI refs
var _skill_list: ItemList
var _char_btns: Dictionary = {}
var _param_fields: Dictionary = {}
var _chart_panel: Panel
var _matrix_grid: GridContainer
var _status_label: Label
var _preview_btn: Button

# 当前编辑数据（所有技能的参数覆盖，从JSON加载）
var _config: Dictionary = {}

# ── 初始化 ────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_load_config()
	_build_ui()
	_refresh_all()

# ── UI 构建 ───────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	custom_minimum_size = Vector2(0, 420)
	var root = HSplitContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.split_offset = 200
	add_child(root)

	# ── 左栏：职业 + 技能列表 ──
	var left = VBoxContainer.new()
	left.custom_minimum_size = Vector2(200, 0)
	root.add_child(left)

	var char_label = Label.new(); char_label.text = "职业"
	char_label.add_theme_color_override("font_color", Color(0.8,0.8,0.5))
	left.add_child(char_label)

	var char_row = HBoxContainer.new()
	left.add_child(char_row)
	for cid in ["mage","warrior","hunter"]:
		var btn = Button.new()
		btn.text = CHAR_DATA[cid]["name"]
		btn.toggle_mode = true
		btn.pressed.connect(_on_char_selected.bind(cid))
		btn.custom_minimum_size = Vector2(58, 28)
		btn.add_theme_font_size_override("font_size", 11)
		char_row.add_child(btn)
		_char_btns[cid] = btn
	_char_btns["mage"].button_pressed = true

	var sep = HSeparator.new(); left.add_child(sep)

	var skill_label = Label.new(); skill_label.text = "技能列表"
	skill_label.add_theme_color_override("font_color", Color(0.8,0.8,0.5))
	left.add_child(skill_label)

	_skill_list = ItemList.new()
	_skill_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_skill_list.item_selected.connect(_on_skill_selected)
	left.add_child(_skill_list)

	for sid in SKILL_DISPLAY:
		_skill_list.add_item(SKILL_DISPLAY[sid])
		var idx = _skill_list.get_item_count() - 1
		_skill_list.set_item_metadata(idx, sid)

	# ── 中栏：参数编辑 + 底部按钮 ──
	var mid_split = VSplitContainer.new()
	mid_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_split.split_offset = 280
	root.add_child(mid_split)

	var mid_top = VSplitContainer.new()
	mid_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_top.split_offset = 300
	mid_split.add_child(mid_top)

	# 参数面板
	var param_scroll = ScrollContainer.new()
	param_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	param_scroll.custom_minimum_size = Vector2(300, 0)
	mid_top.add_child(param_scroll)

	var param_vbox = VBoxContainer.new()
	param_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	param_scroll.add_child(param_vbox)

	var param_title = Label.new(); param_title.text = "参数编辑"
	param_title.add_theme_font_size_override("font_size", 14)
	param_title.add_theme_color_override("font_color", Color(1.0,0.85,0.3))
	param_vbox.add_child(param_title)

	# 参数字段定义：[key, 显示名, 最小值, 最大值, 步进, 是否小数]
	var fields := [
		["damage",          "基础伤害",     0.0,  500.0, 0.5,  true],
		["level_up_damage", "每级伤害",     0.0,  200.0, 0.5,  true],
		["cooldown",        "冷却时间(s)",  0.1,  30.0,  0.1,  true],
		["level_up_cooldown","每级冷却",   -2.0,  0.0,   0.05, true],
		["speed",           "飞行速度",     0.0,  2000.0,10.0, false],
		["range_radius",    "范围半径",     0.0,  2000.0,10.0, false],
		["pierce_count",    "穿透次数",     1.0,  20.0,  1.0,  false],
		["projectile_count","投射数量",     1.0,  20.0,  1.0,  false],
		["max_level",       "最大等级",     1.0,  20.0,  1.0,  false],
	]

	for fd in fields:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		param_vbox.add_child(row)

		var lbl = Label.new()
		lbl.text = fd[1]
		lbl.custom_minimum_size = Vector2(110, 0)
		lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(lbl)

		var spin = SpinBox.new()
		spin.min_value = fd[2]; spin.max_value = fd[3]; spin.step = fd[4]
		spin.allow_lesser = false; spin.allow_greater = false
		if fd[5]: spin.rounded = false
		spin.custom_minimum_size = Vector2(120, 0)
		spin.value_changed.connect(_on_param_changed.bind(fd[0]))
		row.add_child(spin)
		_param_fields[fd[0]] = spin

		# 重置按钮
		var rst = Button.new(); rst.text = "↺"
		rst.custom_minimum_size = Vector2(28, 0)
		rst.tooltip_text = "恢复默认值"
		rst.pressed.connect(_on_reset_field.bind(fd[0]))
		row.add_child(rst)

	# 操作按钮行
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	mid_split.add_child(btn_row)

	var save_btn = Button.new(); save_btn.text = "💾 保存参数"
	save_btn.pressed.connect(_save_config)
	btn_row.add_child(save_btn)

	var reset_btn = Button.new(); reset_btn.text = "↺ 重置全部"
	reset_btn.pressed.connect(_reset_all)
	btn_row.add_child(reset_btn)

	var balance_btn = Button.new(); balance_btn.text = "⚖ 平衡报告"
	balance_btn.pressed.connect(_show_balance_report)
	btn_row.add_child(balance_btn)

	_preview_btn = Button.new(); _preview_btn.text = "▶ 场景预览"
	_preview_btn.pressed.connect(_preview_in_scene)
	btn_row.add_child(_preview_btn)

	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", Color(0.4,1.0,0.4))
	_status_label.add_theme_font_size_override("font_size", 11)
	btn_row.add_child(_status_label)

	# ── 右栏：曲线图 + 职业矩阵 ──
	var right = VBoxContainer.new()
	right.custom_minimum_size = Vector2(360, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right)

	var chart_label = Label.new(); chart_label.text = "成长曲线"
	chart_label.add_theme_color_override("font_color", Color(0.8,0.8,0.5))
	right.add_child(chart_label)

	_chart_panel = Panel.new()
	_chart_panel.custom_minimum_size = Vector2(0, 200)
	_chart_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart_panel.draw.connect(_draw_chart)
	right.add_child(_chart_panel)

	var matrix_label = Label.new(); matrix_label.text = "职业伤害矩阵（各等级最终伤害）"
	matrix_label.add_theme_color_override("font_color", Color(0.8,0.8,0.5))
	right.add_child(matrix_label)

	_matrix_grid = GridContainer.new()
	_matrix_grid.columns = 5  # 等级列 + 3职业
	right.add_child(_matrix_grid)

# ── 数据操作 ──────────────────────────────────────────────────────────────────
func _load_config() -> void:
	if FileAccess.file_exists(CONFIG_PATH):
		var f = FileAccess.open(CONFIG_PATH, FileAccess.READ)
		var txt = f.get_as_text(); f.close()
		var parsed = JSON.parse_string(txt)
		if parsed is Dictionary:
			_config = parsed
			_set_status("✅ 已加载 skill_config.json")
			return
	_config = {}

func _get_param(skill_id: String, key: String) -> float:
	# 优先从 _config 读，否则从脚本默认值读
	if _config.has(skill_id) and _config[skill_id].has(key):
		return float(_config[skill_id][key])
	return _get_default_param(skill_id, key)

func _get_default_param(skill_id: String, key: String) -> float:
	# 从游戏里实际 SkillData 默认值表读
	var defaults := {
		"fireball":      {"damage":15,"level_up_damage":8,"cooldown":1.5,"level_up_cooldown":-0.05,"speed":400,"range_radius":0,"pierce_count":1,"projectile_count":1,"max_level":8},
		"orbital":       {"damage":8, "level_up_damage":4,"cooldown":0.5,"level_up_cooldown":-0.02,"speed":0,"range_radius":80,"pierce_count":99,"projectile_count":3,"max_level":8},
		"lightning":     {"damage":20,"level_up_damage":10,"cooldown":2.0,"level_up_cooldown":-0.08,"speed":0,"range_radius":300,"pierce_count":3,"projectile_count":1,"max_level":8},
		"iceblade":      {"damage":12,"level_up_damage":6,"cooldown":1.2,"level_up_cooldown":-0.05,"speed":350,"range_radius":0,"pierce_count":2,"projectile_count":2,"max_level":8},
		"frostzone":     {"damage":5, "level_up_damage":3,"cooldown":0.3,"level_up_cooldown":-0.01,"speed":0,"range_radius":200,"pierce_count":99,"projectile_count":1,"max_level":8},
		"runeblast":     {"damage":35,"level_up_damage":15,"cooldown":4.0,"level_up_cooldown":-0.15,"speed":0,"range_radius":180,"pierce_count":99,"projectile_count":1,"max_level":8},
		"holywave":      {"damage":15,"level_up_damage":8,"cooldown":5.0,"level_up_cooldown":-0.2,"speed":0,"range_radius":300,"pierce_count":99,"projectile_count":1,"max_level":8},
		"poison_cloud":  {"damage":3, "level_up_damage":2,"cooldown":0.5,"level_up_cooldown":-0.02,"speed":0,"range_radius":150,"pierce_count":99,"projectile_count":1,"max_level":8},
		"void_rift":     {"damage":25,"level_up_damage":12,"cooldown":3.0,"level_up_cooldown":-0.1,"speed":0,"range_radius":120,"pierce_count":99,"projectile_count":1,"max_level":8},
		"arcane_orb":    {"damage":18,"level_up_damage":9,"cooldown":1.8,"level_up_cooldown":-0.07,"speed":300,"range_radius":0,"pierce_count":1,"projectile_count":3,"max_level":8},
		"blood_nova":    {"damage":40,"level_up_damage":20,"cooldown":6.0,"level_up_cooldown":-0.25,"speed":0,"range_radius":250,"pierce_count":99,"projectile_count":1,"max_level":8},
		"time_slow":     {"damage":0, "level_up_damage":0,"cooldown":8.0,"level_up_cooldown":-0.3,"speed":0,"range_radius":400,"pierce_count":99,"projectile_count":1,"max_level":5},
		"thorn_aura":    {"damage":6, "level_up_damage":3,"cooldown":0.4,"level_up_cooldown":-0.01,"speed":0,"range_radius":100,"pierce_count":99,"projectile_count":1,"max_level":8},
		"meteor_shower": {"damage":30,"level_up_damage":15,"cooldown":0.8,"level_up_cooldown":-0.03,"speed":600,"range_radius":0,"pierce_count":1,"projectile_count":1,"max_level":8},
		"chain_lance":   {"damage":22,"level_up_damage":11,"cooldown":2.5,"level_up_cooldown":-0.1,"speed":500,"range_radius":0,"pierce_count":5,"projectile_count":1,"max_level":8},
	}
	if defaults.has(skill_id) and defaults[skill_id].has(key):
		return float(defaults[skill_id][key])
	return 0.0

func _calc_damage_at_level(skill_id: String, lv: int, char_id: String) -> float:
	var base = _get_param(skill_id, "damage")
	var per_lv = _get_param(skill_id, "level_up_damage")
	var dmult = float(CHAR_DATA[char_id]["damage_mult"])
	return (base + per_lv * (lv - 1)) * dmult

func _calc_dps(skill_id: String, lv: int, char_id: String) -> float:
	var dmg = _calc_damage_at_level(skill_id, lv, char_id)
	var cd = _get_param(skill_id, "cooldown") + _get_param(skill_id, "level_up_cooldown") * (lv - 1)
	cd = max(cd, 0.1)
	var proj = _get_param(skill_id, "projectile_count")
	return dmg * proj / cd

# ── UI 刷新 ───────────────────────────────────────────────────────────────────
func _refresh_all() -> void:
	_refresh_params()
	_refresh_matrix()
	if _chart_panel: _chart_panel.queue_redraw()

func _refresh_params() -> void:
	for key in _param_fields:
		var spin: SpinBox = _param_fields[key]
		spin.set_value_no_signal(_get_param(_cur_skill_id, key))

func _refresh_matrix() -> void:
	if not _matrix_grid: return
	for c in _matrix_grid.get_children(): c.free()

	var max_lv = int(_get_param(_cur_skill_id, "max_level"))
	var show_lvs = [1, 2, 3, 5, max_lv] if max_lv >= 5 else range(1, max_lv+1)
	show_lvs = Array(show_lvs)
	show_lvs = show_lvs.filter(func(x): return x <= max_lv)

	# 表头
	_matrix_add_cell("等级", Color(0.8,0.8,0.5), true)
	for cid in ["mage","warrior","hunter"]:
		_matrix_add_cell(CHAR_DATA[cid]["name"], CHAR_DATA[cid]["color"], true)
	_matrix_add_cell("DPS(法)", Color(0.8,0.8,0.5), true)

	# 数据行
	for lv in show_lvs:
		_matrix_add_cell("Lv%d" % lv, Color.WHITE, false)
		var avg_dps = 0.0
		for cid in ["mage","warrior","hunter"]:
			var dmg = _calc_damage_at_level(_cur_skill_id, lv, cid)
			_matrix_add_cell("%.1f" % dmg, CHAR_DATA[cid]["color"].lightened(0.2), false)
			if cid == "mage": avg_dps = _calc_dps(_cur_skill_id, lv, "mage")
		# DPS列
		var dps_color = Color(0.4,1.0,0.4) if avg_dps < 100 else (Color(1.0,0.8,0.2) if avg_dps < 200 else Color(1.0,0.3,0.3))
		_matrix_add_cell("%.1f" % avg_dps, dps_color, false)

func _matrix_add_cell(txt: String, col: Color, bold: bool) -> void:
	var lbl = Label.new()
	lbl.text = txt
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_size_override("font_size", 11 if not bold else 12)
	lbl.custom_minimum_size = Vector2(72, 20)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_matrix_grid.add_child(lbl)

# ── 曲线图绘制 ────────────────────────────────────────────────────────────────
func _draw_chart() -> void:
	if not _chart_panel: return
	var W = _chart_panel.size.x
	var H = _chart_panel.size.y
	if W < 10 or H < 10: return

	# 背景
	_chart_panel.draw_rect(Rect2(0,0,W,H), Color(0.05,0.05,0.12))

	var pad_l = 45; var pad_r = 10; var pad_t = 10; var pad_b = 30
	var cw = W - pad_l - pad_r
	var ch = H - pad_t - pad_b

	var max_lv = int(_get_param(_cur_skill_id, "max_level"))
	if max_lv < 1: max_lv = 8

	# 计算各职业各等级DPS
	var all_vals: Array = []
	var char_points: Dictionary = {}
	for cid in ["mage","warrior","hunter"]:
		var pts: Array = []
		for lv in range(1, max_lv+1):
			var dps = _calc_dps(_cur_skill_id, lv, cid)
			pts.append(dps)
			all_vals.append(dps)
		char_points[cid] = pts

	var max_val = all_vals.max() if all_vals.size() > 0 else 1.0
	if max_val <= 0: max_val = 1.0

	# 网格线
	for i in range(5):
		var gy = pad_t + ch * i / 4
		_chart_panel.draw_line(Vector2(pad_l, gy), Vector2(pad_l+cw, gy), Color(0.2,0.2,0.3), 1)
		var val_lbl = "%.0f" % (max_val * (4-i) / 4)
		_chart_panel.draw_string(ThemeDB.fallback_font, Vector2(2, gy+4), val_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5,0.5,0.5))

	# X轴等级标注
	for lv in range(1, max_lv+1):
		var gx = pad_l + cw * (lv-1) / max(max_lv-1, 1)
		_chart_panel.draw_string(ThemeDB.fallback_font, Vector2(gx-4, H-4), str(lv), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5,0.5,0.5))

	# 三条曲线
	var char_colors := {"mage": Color(0.6,0.4,1.0), "warrior": Color(1.0,0.5,0.2), "hunter": Color(0.3,0.9,0.4)}
	var char_names := {"mage": "法师", "warrior": "战士", "hunter": "猎手"}

	for cid in ["mage","warrior","hunter"]:
		var pts = char_points[cid]
		var col = char_colors[cid]
		var prev = Vector2.ZERO
		for i in range(pts.size()):
			var x = pad_l + cw * i / max(max_lv-1, 1)
			var y = pad_t + ch * (1.0 - pts[i]/max_val)
			var p = Vector2(x, y)
			if i > 0:
				_chart_panel.draw_line(prev, p, col, 2)
			_chart_panel.draw_circle(p, 3, col)
			prev = p

	# 图例
	var lx = pad_l + 4
	for cid in ["mage","warrior","hunter"]:
		_chart_panel.draw_rect(Rect2(lx, pad_t+2, 12, 8), char_colors[cid])
		_chart_panel.draw_string(ThemeDB.fallback_font, Vector2(lx+14, pad_t+10), char_names[cid], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, char_colors[cid])
		lx += 52

	# 技能名标题
	var sname = SKILL_DISPLAY.get(_cur_skill_id, _cur_skill_id)
	_chart_panel.draw_string(ThemeDB.fallback_font, Vector2(W/2-40, pad_t+14), sname + " DPS曲线", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0,0.9,0.5))

# ── 事件回调 ──────────────────────────────────────────────────────────────────
func _on_char_selected(cid: String) -> void:
	_cur_char_id = cid
	for id in _char_btns:
		_char_btns[id].button_pressed = (id == cid)
	_refresh_all()

func _on_skill_selected(idx: int) -> void:
	_cur_skill_id = _skill_list.get_item_metadata(idx)
	_refresh_all()

func _on_param_changed(val: float, key: String) -> void:
	if not _config.has(_cur_skill_id):
		_config[_cur_skill_id] = {}
	_config[_cur_skill_id][key] = val
	_refresh_matrix()
	if _chart_panel: _chart_panel.queue_redraw()
	_set_status("● 未保存")

func _on_reset_field(key: String) -> void:
	if _config.has(_cur_skill_id):
		_config[_cur_skill_id].erase(key)
	_refresh_params()
	_refresh_matrix()
	if _chart_panel: _chart_panel.queue_redraw()
	_set_status("↺ 已重置 " + key)

# ── 保存 ──────────────────────────────────────────────────────────────────────
func _save_config() -> void:
	var f = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if not f:
		_set_status("❌ 无法写入 skill_config.json")
		return
	f.store_string(JSON.stringify(_config, "\t"))
	f.close()
	_set_status("✅ 已保存到 skill_config.json")

func _reset_all() -> void:
	_config.erase(_cur_skill_id)
	_refresh_all()
	_set_status("↺ 已重置 " + SKILL_DISPLAY.get(_cur_skill_id, _cur_skill_id))

# ── 平衡报告 ──────────────────────────────────────────────────────────────────
func _show_balance_report() -> void:
	var report := "=== 平衡报告（Lv5 法师 DPS）===\n\n"
	var dps_list: Array = []
	for sid in SKILL_DISPLAY:
		var max_lv = int(_get_param(sid, "max_level"))
		var lv = min(5, max_lv)
		var dps = _calc_dps(sid, lv, "mage")
		dps_list.append({"id": sid, "dps": dps, "name": SKILL_DISPLAY[sid]})

	dps_list.sort_custom(func(a,b): return a["dps"] > b["dps"])
	var avg = 0.0
	for d in dps_list: avg += d["dps"]
	avg /= dps_list.size()

	for d in dps_list:
		var bar = ""
		var ratio = d["dps"] / max(avg, 1.0)
		var warn = ""
		if ratio > 2.0: warn = " ⚠ 过强"
		elif ratio < 0.4: warn = " ⚠ 过弱"
		bar = "█".repeat(int(clamp(ratio * 10, 1, 30)))
		report += "%s %s %.1f%s\n" % [d["name"].substr(0,8).rpad(8), bar.substr(0,20).rpad(20), d["dps"], warn]

	report += "\n平均DPS: %.1f" % avg

	# 弹窗显示
	var dialog = AcceptDialog.new()
	dialog.title = "⚖ 技能平衡报告"
	dialog.dialog_text = report
	dialog.min_size = Vector2(520, 480)
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)

# ── 场景内预览 ────────────────────────────────────────────────────────────────
func _preview_in_scene() -> void:
	if not editor_interface:
		_set_status("❌ 无法获取编辑器接口")
		return

	# 获取当前编辑场景
	var edited_root = editor_interface.get_edited_scene_root()
	if not edited_root:
		_set_status("❌ 请先在编辑器中打开 main.tscn")
		return

	# 清理旧预览节点
	var old = edited_root.find_child("_SkillPreviewDummy", true, false)
	if old: old.queue_free()

	# 创建预览容器
	var preview_node = Node2D.new()
	preview_node.name = "_SkillPreviewDummy"
	edited_root.add_child(preview_node)
	preview_node.set_owner(edited_root)

	# 假人目标（红圈）
	var dummy = Node2D.new()
	dummy.name = "PreviewTarget"
	dummy.global_position = Vector2(300, 0)
	preview_node.add_child(dummy)
	dummy.set_owner(edited_root)

	# 画假人圆圈
	var dummy_sprite = MeshInstance2D.new()
	var arr_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	var verts = PackedVector2Array()
	var colors = PackedColorArray()
	var segs = 24
	for i in range(segs+1):
		var angle = TAU * i / segs
		var r = 28.0
		verts.append(Vector2(cos(angle)*r, sin(angle)*r))
		colors.append(Color(1,0.2,0.2,0.8))
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
	dummy_sprite.mesh = arr_mesh
	dummy.add_child(dummy_sprite)
	dummy_sprite.set_owner(edited_root)

	# 标注文字
	var lbl = Label.new()
	lbl.text = "◀ 假人目标"
	lbl.position = Vector2(32, -16)
	lbl.add_theme_color_override("font_color", Color(1,0.4,0.4))
	dummy.add_child(lbl)
	lbl.set_owner(edited_root)

	# 尝试加载技能场景
	var skill_script_path = SKILL_SCRIPTS.get(_cur_skill_id, "")
	if skill_script_path != "" and ResourceLoader.exists(skill_script_path):
		# 创建临时玩家节点（给技能提供 owner_player）
		var fake_player = Node2D.new()
		fake_player.name = "PreviewPlayer"
		fake_player.global_position = Vector2(0, 0)
		preview_node.add_child(fake_player)
		fake_player.set_owner(edited_root)

		# 玩家标注
		var plbl = Label.new()
		plbl.text = CHAR_DATA[_cur_char_id]["name"] + "\n" + SKILL_DISPLAY.get(_cur_skill_id,"")
		plbl.position = Vector2(-40, -48)
		plbl.add_theme_color_override("font_color", CHAR_DATA[_cur_char_id]["color"])
		fake_player.add_child(plbl)
		plbl.set_owner(edited_root)

		# 画玩家圆圈
		var p_sprite = MeshInstance2D.new()
		var pm = ArrayMesh.new()
		var pa = []; pa.resize(Mesh.ARRAY_MAX)
		var pv = PackedVector2Array(); var pc = PackedColorArray()
		var pcol = CHAR_DATA[_cur_char_id]["color"]
		for i in range(segs+1):
			var angle = TAU * i / segs
			pv.append(Vector2(cos(angle)*20, sin(angle)*20))
			pc.append(pcol)
		pa[Mesh.ARRAY_VERTEX] = pv; pa[Mesh.ARRAY_COLOR] = pc
		pm.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, pa)
		p_sprite.mesh = pm
		fake_player.add_child(p_sprite)
		p_sprite.set_owner(edited_root)

	_set_status("✅ 预览节点已添加到场景（查看2D视图）")
	# 选中预览节点让编辑器定位
	if editor_interface:
		editor_interface.get_selection().clear()
		editor_interface.get_selection().add_node(preview_node)

func _set_status(msg: String) -> void:
	if _status_label:
		_status_label.text = msg
