@tool
extends EditorPlugin

const BRIDGE_RUNTIME_PATH: String = "res://addons/daedalus_bridge/scripts/bridge_runtime.gd"
const RUNTIME_TEST_AGENT_PATH: String = "res://addons/daedalus_bridge/scripts/runtime/runtime_test_agent.gd"
const RUNTIME_TEST_AUTOLOAD_NAME: String = "DaedalusRuntimeTest"

var bridge_runtime: Node
var bridge_dock: EditorDock
var registered_runtime_test_autoload: bool


func _enter_tree() -> void:
	_register_runtime_test_autoload()
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
	_unregister_runtime_test_autoload()


func _register_runtime_test_autoload() -> void:
	var setting_name: String = "autoload/%s" % RUNTIME_TEST_AUTOLOAD_NAME
	if ProjectSettings.has_setting(setting_name):
		var configured_path: String = str(ProjectSettings.get_setting(setting_name, "")).trim_prefix("*")
		if configured_path == RUNTIME_TEST_AGENT_PATH:
			registered_runtime_test_autoload = true
		else:
			push_error("Daedalus Runtime Test Autoload name is already used by another script.")
		return
	if not ResourceLoader.exists(RUNTIME_TEST_AGENT_PATH):
		push_error("Daedalus Runtime Test Agent could not be found.")
		return
	add_autoload_singleton(RUNTIME_TEST_AUTOLOAD_NAME, RUNTIME_TEST_AGENT_PATH)
	registered_runtime_test_autoload = true


func _unregister_runtime_test_autoload() -> void:
	if not registered_runtime_test_autoload:
		return
	var setting_name: String = "autoload/%s" % RUNTIME_TEST_AUTOLOAD_NAME
	var configured_path: String = str(ProjectSettings.get_setting(setting_name, "")).trim_prefix("*")
	if configured_path == RUNTIME_TEST_AGENT_PATH:
		remove_autoload_singleton(RUNTIME_TEST_AUTOLOAD_NAME)
	registered_runtime_test_autoload = false
