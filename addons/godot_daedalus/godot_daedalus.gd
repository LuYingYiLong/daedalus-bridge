@tool
extends EditorPlugin

const DOCK_ICON: Texture2D = preload("res://addons/godot_daedalus/assets/icons/icon.svg")
const MAIN_SCENE: PackedScene = preload("res://addons/godot_daedalus/scenes/main.tscn")

var dock: Node
var uses_editor_dock: bool = false


func _enter_tree() -> void:
	var dock_content: Node = MAIN_SCENE.instantiate()
	var dock_content_script: Script = dock_content.get_script()
	if dock_content_script == null or not dock_content_script.can_instantiate():
		push_error("Daedalus main dock script failed to load. Please reinstall the plugin package or check script load errors above.")
	elif dock_content.has_method("setup_editor_bridge"):
		dock_content.call("setup_editor_bridge", self)
	uses_editor_dock = ClassDB.class_exists("EditorDock") and has_method("add_dock")
	if uses_editor_dock:
		dock = ClassDB.instantiate("EditorDock") as Node
		dock.set("title", "Daedalus")
		dock.set("dock_icon", DOCK_ICON)
		dock.set("default_slot", DOCK_SLOT_RIGHT_UL)
		dock.add_child(dock_content)
		call("add_dock", dock)
	else:
		dock = dock_content
		add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock as Control)


func _exit_tree() -> void:
	if dock == null:
		return
	if uses_editor_dock:
		call("remove_dock", dock)
	else:
		remove_control_from_docks(dock as Control)
	dock.queue_free()
	dock = null
	uses_editor_dock = false
