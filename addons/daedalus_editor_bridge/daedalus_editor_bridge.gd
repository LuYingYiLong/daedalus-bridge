@tool
extends EditorPlugin

const BRIDGE_RUNTIME_PATH: String = "res://addons/daedalus_editor_bridge/scripts/bridge_runtime.gd"

var bridge_runtime: Node
var bridge_dock: Control


func _enter_tree() -> void:
	var bridge_runtime_script: GDScript = load(BRIDGE_RUNTIME_PATH) as GDScript
	if bridge_runtime_script == null:
		push_error("Daedalus Editor Bridge runtime could not be loaded.")
		return
	bridge_runtime = bridge_runtime_script.new()
	add_child(bridge_runtime)
	bridge_runtime.setup(self)
	bridge_dock = bridge_runtime.get_status_dock()
	if bridge_dock == null:
		push_error("Daedalus Editor Bridge status Dock is unavailable.")
		return
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, bridge_dock)


func _exit_tree() -> void:
	if bridge_runtime != null:
		bridge_runtime.shutdown()
	if bridge_dock != null:
		remove_control_from_docks(bridge_dock)
		bridge_dock.queue_free()
		bridge_dock = null
	if bridge_runtime != null:
		bridge_runtime.queue_free()
		bridge_runtime = null
