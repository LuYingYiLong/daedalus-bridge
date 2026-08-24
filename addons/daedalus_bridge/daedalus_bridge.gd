@tool
extends EditorPlugin

const BRIDGE_RUNTIME_PATH: String = "res://addons/daedalus_bridge/scripts/bridge_runtime.gd"

var bridge_runtime: Node
var bridge_dock: EditorDock


func _enter_tree() -> void:
	var bridge_runtime_script: GDScript = load(BRIDGE_RUNTIME_PATH) as GDScript
	if bridge_runtime_script == null:
		push_error("Daedalus Bridge runtime could not be loaded.")
		return
	bridge_runtime = bridge_runtime_script.new() as Node
	if bridge_runtime == null:
		push_error("Daedalus Bridge runtime has an invalid Node base type.")
		return
	add_child(bridge_runtime)
	bridge_runtime.setup(self)
	bridge_dock = bridge_runtime.get_status_dock()
	if bridge_dock == null:
		push_error("Daedalus Bridge status Dock is unavailable.")
		return
	add_dock(bridge_dock)
	bridge_runtime.start()


func _exit_tree() -> void:
	if bridge_runtime != null:
		bridge_runtime.shutdown()
	if bridge_dock != null and is_instance_valid(bridge_dock):
		remove_dock(bridge_dock)
		bridge_dock.queue_free()
		bridge_dock = null
	if bridge_runtime != null:
		bridge_runtime.queue_free()
		bridge_runtime = null
