# World.gd
# 世界初始化 - 程序生成地图背景和初始内容
extends Node2D

# 场景预加载（无需美术资源，全程序生成）
const PLAYER_SCRIPT = preload("res://scripts/player/Player.gd")
const WAVE_MANAGER_SCRIPT = preload("res://scripts/systems/WaveManager.gd")
const GAME_MANAGER_SCRIPT = preload("res://scripts/systems/GameManager.gd")
const HUD_SCRIPT = preload("res://scripts/ui/HUD.gd")

var player: Player
var wave_manager: WaveManager
var hud: Node

func _ready() -> void:
	_setup_background()
	_setup_player()
	_setup_wave_manager()
	_setup_hud()
	_start_game()

func _setup_background() -> void:
	# TileMap 地砖背景
	var bg = Node2D.new()
	bg.set_script(load("res://scripts/systems/TileMapBackground.gd"))
	bg.name = "TileMapBackground"
	# 根据难度切换地图主题
	var main = get_tree().root.find_child("Main", true, false)
	if main:
		var diff = main.get("current_difficulty")
		if diff is Resource:
			match diff.id:
				"hard":  bg.set("map_theme", "ice")
				"abyss": bg.set("map_theme", "lava")
				_:       bg.set("map_theme", "dungeon")
	add_child(bg)

func _setup_player() -> void:
	player = CharacterBody2D.new()
	player.set_script(PLAYER_SCRIPT)
	player.position = Vector2(640, 360)
	add_child(player)

func _setup_wave_manager() -> void:
	wave_manager = Node.new()
	wave_manager.set_script(WAVE_MANAGER_SCRIPT)
	wave_manager.name = "WaveManager"
	add_child(wave_manager)

func _setup_hud() -> void:
	hud = CanvasLayer.new()
	hud.set_script(HUD_SCRIPT)
	# 手动创建 HUD 子节点
	_build_hud_nodes(hud)
	hud.game_manager = null  # 稍后注入
	add_child(hud)

func _build_hud_nodes(canvas: CanvasLayer) -> void:
	var hp_bar = ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.position = Vector2(10, 10)
	hp_bar.size = Vector2(200, 20)
	hp_bar.max_value = 100
	hp_bar.value = 100
	canvas.add_child(hp_bar)

	var hp_label = Label.new()
	hp_label.name = "HPLabel"
	hp_label.position = Vector2(215, 10)
	hp_label.size = Vector2(100, 20)
	hp_label.text = "100 / 100"
	canvas.add_child(hp_label)

	var exp_bar = ProgressBar.new()
	exp_bar.name = "ExpBar"
	exp_bar.position = Vector2(10, 35)
	exp_bar.size = Vector2(300, 14)
	exp_bar.max_value = 10
	exp_bar.value = 0
	canvas.add_child(exp_bar)

	var level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.position = Vector2(315, 10)
	level_label.size = Vector2(60, 20)
	level_label.text = "Lv.1"
	canvas.add_child(level_label)

	var timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.position = Vector2(580, 10)
	timer_label.size = Vector2(120, 20)
	timer_label.text = "00:00"
	canvas.add_child(timer_label)

	var wave_label = Label.new()
	wave_label.name = "WaveLabel"
	wave_label.position = Vector2(10, 55)
	wave_label.size = Vector2(140, 20)
	wave_label.text = "第 1 波"
	canvas.add_child(wave_label)

	var level_up_panel = Panel.new()
	level_up_panel.name = "LevelUpPanel"
	level_up_panel.visible = false
	level_up_panel.position = Vector2(190, 210)
	level_up_panel.size = Vector2(900, 300)
	canvas.add_child(level_up_panel)

	var panel_title = Label.new()
	panel_title.text = "⬆  选择升级"
	panel_title.position = Vector2(0, 10)
	panel_title.size = Vector2(900, 40)
	panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_title.add_theme_font_size_override("font_size", 28)
	level_up_panel.add_child(panel_title)

	var choices = HBoxContainer.new()
	choices.name = "Choices"
	choices.position = Vector2(50, 60)
	choices.size = Vector2(800, 200)
	level_up_panel.add_child(choices)

func _start_game() -> void:
	wave_manager.start(player)
	if hud.has_method("_ready"):
		hud.game_manager = get_node_or_null("WaveManager")

func _process(_delta: float) -> void:
	# 摄像机跟随玩家
	if is_instance_valid(player):
		get_viewport().get_camera_2d()
