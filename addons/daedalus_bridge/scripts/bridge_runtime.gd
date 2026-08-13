@tool
extends Node

const BRIDGE_VERSION: String = "2.0.0"
const BRIDGE_PROTOCOL_VERSION: int = 4
const HEARTBEAT_INTERVAL_MSEC: int = 5000
const RECONNECT_DELAYS_MSEC: Array = [500, 1000, 2000, 5000, 10000]
const BACKEND_RUNTIME_PATH: String = "res://addons/daedalus_bridge/scripts/backend_runtime.gd"
const BRIDGE_CONNECTION_PATH: String = "res://addons/daedalus_bridge/scripts/bridge_connection.gd"
const EDITOR_CONTEXT_PATH: String = "res://addons/daedalus_bridge/scripts/editor_context.gd"
const STATUS_DOCK_SCENE_PATH: String = "res://addons/daedalus_bridge/scenes/bridge_status_dock.tscn"

var editor_plugin: EditorPlugin
var backend_runtime: RefCounted
var connection: Node
var editor_context: Node
var status_dock: Control
var handshake_request_id: String
var handshake_accepted: bool
var pending_context: Dictionary
var last_context_fingerprint: String
var context_revision: int
var next_heartbeat_msec: int
var next_reconnect_msec: int
var reconnect_attempt: int
var connection_url: String
var auth_protocol: String
var backend_version: String
var terminal_call_ids: Dictionary = {}


func setup(plugin: EditorPlugin) -> void:
	editor_plugin = plugin
	set_process(false)
	_register_editor_settings()
	if not _build_status_dock():
		return
	var backend_runtime_script: GDScript = load(BACKEND_RUNTIME_PATH) as GDScript
	var bridge_connection_script: GDScript = load(BRIDGE_CONNECTION_PATH) as GDScript
	var editor_context_script: GDScript = load(EDITOR_CONTEXT_PATH) as GDScript
	if backend_runtime_script == null or bridge_connection_script == null or editor_context_script == null:
		_set_error("One or more Bridge runtime scripts could not be loaded.")
		return
	backend_runtime = backend_runtime_script.new()
	connection = bridge_connection_script.new()
	editor_context = editor_context_script.new()
	add_child(connection)
	add_child(editor_context)
	connection.connect(&"connected", Callable(self, "_on_connected"))
	connection.connect(&"disconnected", Callable(self, "_on_disconnected"))
	connection.connect(&"message_received", Callable(self, "_on_message_received"))
	connection.connect(&"protocol_error", Callable(self, "_on_protocol_error"))
	editor_context.connect(&"request_ready", Callable(self, "_on_editor_request_ready"))
	editor_context.setup(editor_plugin)


func start() -> void:
	if status_dock == null or backend_runtime == null or connection == null or editor_context == null:
		push_error("Daedalus Bridge runtime is not ready to start.")
		return
	set_process(true)
	_start_connection()


func get_status_dock() -> Control:
	return status_dock


func shutdown() -> void:
	set_process(false)
	if connection != null:
		connection.shutdown()
	if backend_runtime != null:
		backend_runtime.stop_started_backend()
	handshake_accepted = false


func _process(_delta: float) -> void:
	if connection == null:
		return
	connection.poll()
	editor_context.poll_live_context()
	var now_msec: int = Time.get_ticks_msec()
	if connection.is_open() and handshake_accepted and now_msec >= next_heartbeat_msec:
		_send_heartbeat()
	if connection.is_closed() and next_reconnect_msec > 0 and now_msec >= next_reconnect_msec:
		_start_connection()


func _start_connection() -> void:
	next_reconnect_msec = 0
	handshake_accepted = false
	var settings: EditorSettings = editor_plugin.get_editor_interface().get_editor_settings()
	var backend_url: String = str(settings.get_setting("daedalus/editor_bridge/backend_url")).strip_edges()
	var backend_dev_dir: String = str(settings.get_setting("daedalus/editor_bridge/backend_dev_directory")).strip_edges()
	backend_runtime.setup(backend_url, backend_dev_dir)
	var launch_result: Dictionary = backend_runtime.start_backend()
	if not bool(launch_result.get("ok", false)):
		_set_error(str(launch_result.get("message", "Unable to start the shared backend runtime.")))
		_schedule_reconnect()
		return
	connection_url = str(launch_result.get("url", backend_url))
	auth_protocol = str(launch_result.get("authProtocol", ""))
	backend_version = str(launch_result.get("backendVersion", "unknown"))
	var connect_error: Error = connection.connect_to_backend(connection_url, 8 * 1024 * 1024, auth_protocol)
	if connect_error != OK:
		_set_error("Connection failed: %s" % error_string(connect_error))
		_schedule_reconnect()


func _on_connected() -> void:
	reconnect_attempt = 0
	handshake_request_id = connection.send_request("client.hello", {
		"protocolVersion": 3,
		"clientType": "godot_editor_bridge",
		"clientName": "Daedalus Bridge",
		"bridgeVersion": BRIDGE_VERSION,
		"bridgeProtocolVersion": BRIDGE_PROTOCOL_VERSION,
		"godotVersion": str(Engine.get_version_info().get("string", "")),
		"workspaceRoot": ProjectSettings.globalize_path("res://").trim_suffix("/"),
		"editorInstanceId": editor_context.get_editor_instance_id(),
		"capabilities": editor_context.get_capabilities(),
	}, "bridge-hello")


func _on_disconnected(_close_code: int, close_reason: String) -> void:
	handshake_accepted = false
	_set_error(close_reason if not close_reason.is_empty() else "Backend connection closed.")
	_schedule_reconnect()


func _on_protocol_error(message: String) -> void:
	_set_error(message)


func _on_message_received(message: Dictionary) -> void:
	if str(message.get("type", "")) == "response" and str(message.get("id", "")) == handshake_request_id:
		if not bool(message.get("ok", false)):
			var error_value_variant: Variant = message.get("error", {})
			var handshake_error: Dictionary = error_value_variant as Dictionary if typeof(error_value_variant) == TYPE_DICTIONARY else {}
			_set_error(str(handshake_error.get("message", "Bridge Protocol handshake failed.")))
			connection.shutdown()
			return
		handshake_accepted = true
		last_context_fingerprint = ""
		_set_error("")
		_flush_context()
		_send_heartbeat()
		return
	if str(message.get("type", "")) != "event" or str(message.get("event", "")) != "editor.tool.requested":
		return
	if not handshake_accepted:
		return
	var data_value: Variant = message.get("data", {})
	var data: Dictionary = data_value as Dictionary if typeof(data_value) == TYPE_DICTIONARY else {}
	var call_id: String = str(data.get("callId", ""))
	if call_id.is_empty() or terminal_call_ids.has(call_id):
		return
	terminal_call_ids[call_id] = true
	editor_context.handle_tool_requested(data)


func _on_editor_request_ready(method: String, params: Dictionary, request_prefix: String) -> void:
	if method == "editor.context.update":
		pending_context = params.duplicate(true)
		_flush_context()
		return
	if method == "editor.tool.result":
		if not handshake_accepted:
			return
		connection.send_request(method, params, request_prefix)


func _flush_context() -> void:
	if not handshake_accepted or pending_context.is_empty():
		return
	var fingerprint_value: Dictionary = pending_context.duplicate(true)
	fingerprint_value.erase("updatedAt")
	var fingerprint: String = str(hash(JSON.stringify(fingerprint_value)))
	if fingerprint == last_context_fingerprint:
		return
	context_revision += 1
	pending_context["contextRevision"] = context_revision
	pending_context["contextFingerprint"] = fingerprint
	last_context_fingerprint = fingerprint
	connection.send_request("editor.context.update", pending_context, "editor-context")
	_update_context_labels(pending_context)


func _send_heartbeat() -> void:
	if not handshake_accepted:
		return
	next_heartbeat_msec = Time.get_ticks_msec() + HEARTBEAT_INTERVAL_MSEC
	connection.send_request("editor.heartbeat", {
		"editorInstanceId": editor_context.get_editor_instance_id(),
		"workspaceRoot": ProjectSettings.globalize_path("res://").trim_suffix("/"),
		"contextRevision": context_revision,
	}, "editor-heartbeat")


func _schedule_reconnect() -> void:
	var delay_index: int = mini(reconnect_attempt, RECONNECT_DELAYS_MSEC.size() - 1)
	next_reconnect_msec = Time.get_ticks_msec() + int(RECONNECT_DELAYS_MSEC[delay_index])
	reconnect_attempt += 1


func _register_editor_settings() -> void:
	var settings: EditorSettings = editor_plugin.get_editor_interface().get_editor_settings()
	_register_setting(settings, "daedalus/editor_bridge/backend_url", "ws://127.0.0.1:38180")
	_register_setting(settings, "daedalus/editor_bridge/backend_dev_directory", "")


func _register_setting(settings: EditorSettings, setting_name: String, default_value: String) -> void:
	if not settings.has_setting(setting_name):
		settings.set_setting(setting_name, default_value)
	settings.add_property_info({
		"name": setting_name,
		"type": TYPE_STRING,
	})


func _build_status_dock() -> bool:
	var dock_scene: PackedScene = load(STATUS_DOCK_SCENE_PATH) as PackedScene
	if dock_scene == null:
		push_error("Daedalus Bridge status Dock scene could not be loaded.")
		return false
	status_dock = dock_scene.instantiate() as Control
	if status_dock == null:
		push_error("Daedalus Bridge status Dock scene has an invalid root node.")
		return false
	status_dock.connect(&"reconnect_requested", Callable(self, "_on_reconnect_requested"))
	status_dock.connect(&"studio_open_requested", Callable(self, "_on_studio_open_requested"))
	status_dock.connect(&"diagnostics_copy_requested", Callable(self, "_on_diagnostics_copy_requested"))
	return true


func _update_context_labels(context: Dictionary) -> void:
	if status_dock == null:
		return
	status_dock.call("update_context", context)
	status_dock.call("set_versions", BRIDGE_VERSION, str(Engine.get_version_info().get("string", "")), backend_version)


func _set_error(value: String) -> void:
	if status_dock != null:
		status_dock.call("set_error", value)


func _on_reconnect_requested() -> void:
	if connection != null:
		connection.shutdown()
	reconnect_attempt = 0
	_start_connection()


func _on_studio_open_requested() -> void:
	var studio_record_path: String = _get_daedalus_dir().path_join("studio").path_join("current.json")
	if not FileAccess.file_exists(studio_record_path):
		_set_error("Daedalus Studio executable record was not found.")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(studio_record_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		_set_error("Daedalus Studio executable record is invalid.")
		return
	var executable_path: String = str((parsed as Dictionary).get("executablePath", "")).strip_edges()
	if executable_path.is_empty() or not FileAccess.file_exists(executable_path):
		_set_error("The recorded Daedalus Studio executable does not exist.")
		return
	var arguments: PackedStringArray
	var argument_values: Variant = (parsed as Dictionary).get("arguments", [])
	if typeof(argument_values) == TYPE_ARRAY:
		for argument_value in argument_values as Array:
			arguments.append(str(argument_value))
	var process_id: int = OS.create_process(executable_path, arguments)
	if process_id <= 0:
		_set_error("Daedalus Studio could not be opened.")


func _on_diagnostics_copy_requested() -> void:
	var status_text: String = str(status_dock.call("get_status_text")) if status_dock != null else "Unavailable"
	var error_text: String = str(status_dock.call("get_error_text")) if status_dock != null else "Unavailable"
	DisplayServer.clipboard_set("\n".join(PackedStringArray([
		"Daedalus Bridge %s" % BRIDGE_VERSION,
		"Bridge Protocol: %d" % BRIDGE_PROTOCOL_VERSION,
		"Godot: %s" % str(Engine.get_version_info().get("string", "")),
		"Backend: %s" % backend_version,
		"Workspace: %s" % ProjectSettings.globalize_path("res://").trim_suffix("/"),
		"Status: %s" % status_text,
		"Context revision: %d" % context_revision,
		"Last error: %s" % error_text,
	])))


func _get_daedalus_dir() -> String:
	var user_profile: String = OS.get_environment("USERPROFILE").strip_edges()
	if not user_profile.is_empty():
		return user_profile.path_join(".daedalus")
	return OS.get_user_data_dir().path_join(".daedalus")
