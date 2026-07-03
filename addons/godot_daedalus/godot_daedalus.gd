@tool
extends EditorPlugin

const DOCK_ICON: Texture2D = preload("uid://cyodif1e2iey7")
const MAIN_SCENE: PackedScene = preload("uid://qf05xb4jnata")

var dock: EditorDock


func _enter_tree() -> void:
	dock = EditorDock.new()
	dock.title = "Daedalus"
	dock.dock_icon = DOCK_ICON
	dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_UL
	var dock_content: Node = MAIN_SCENE.instantiate()
	var dock_content_script: Script = dock_content.get_script()
	if dock_content_script == null or not dock_content_script.can_instantiate():
		push_error("Daedalus main dock script failed to load. Please reinstall the plugin package or check script load errors above.")
	elif dock_content.has_method("setup_editor_bridge"):
		dock_content.call("setup_editor_bridge", self)
	dock.add_child(dock_content)
	add_dock(dock)


func _exit_tree() -> void:
	remove_dock(dock)
	dock.queue_free()
	dock = null
