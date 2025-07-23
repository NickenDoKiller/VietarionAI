# plugin.gd
@tool
extends EditorPlugin

var main_panel
var panel_container
var editor_interface

func _enter_tree():
	var custom_scene = preload("res://addons/AI_Chat_Support/AI Chat UI.tscn")
	editor_interface = get_editor_interface()
	panel_container = custom_scene.instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, panel_container)
	print("Gemini Chat plugin enabled!")

func _exit_tree():
	if panel_container:
		remove_control_from_docks(panel_container)
		panel_container.queue_free()
	print("AI Chat plugin disabled!")
