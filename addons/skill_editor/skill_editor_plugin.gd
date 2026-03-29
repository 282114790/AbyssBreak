# skill_editor_plugin.gd
@tool
extends EditorPlugin

var _panel: Control = null

func _enter_tree() -> void:
	_panel = preload("res://addons/skill_editor/skill_editor_panel.gd").new()
	_panel.editor_interface = get_editor_interface()
	add_control_to_bottom_panel(_panel, "⚔ 技能编辑器")

func _exit_tree() -> void:
	if _panel:
		remove_control_from_bottom_panel(_panel)
		_panel.queue_free()
		_panel = null
