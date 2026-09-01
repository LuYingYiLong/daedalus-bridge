extends Node

const BRIDGE_VERSION: String = "2.0.0"
const BRIDGE_PROTOCOL_VERSION: int = 4
const HEARTBEAT_INTERVAL_MSEC: int = 2000
const RECONNECT_INTERVAL_MSEC: int = 1000
const MAX_SCREENSHOT_BYTES: int = 5 * 1024 * 1024
const MAX_SCREENSHOT_EDGE: int = 2560

const BACKEND_RUNTIME_PATH: String = "res://addons/daedalus_bridge/scripts/backend_runtime.gd"
const BRIDGE_CONNECTION_PATH: String = "res://addons/daedalus_bridge/scripts/bridge_connection.gd"
const NODE_SNAPSHOT_PATH: String = "res://addons/daedalus_bridge/scripts/runtime/runtime_node_snapshot.gd"
const RUNTIME_INPUT_PATH: String = "res://addons/daedalus_bridge/scripts/runtime/runtime_input.gd"
const RUNTIME_ASSERTIONS_PATH: String = "res://addons/daedalus_bridge/scripts/runtime/runtime_assertions.gd"
const RUNTIME_TEST_ADAPTER_PATH: String = "res://addons/daedalus_bridge/scripts/runtime/runtime_test_adapter.gd"

var backend_runtime: RefCounted
var connection: Node
var snapshot: RefCounted
var runtime_input: RefCounted
var runtime_assertions: RefCounted
var test_adapter: RefCounted

var runtime_instance_id: String
var test_session_id: String
var test_session_token: String
var backend_url: String
var backend_dev_dir: String
var connection_url: String
var auth_protocol: String
var handshake_request_id: String
var handshake_accepted: bool
var enabled: bool
var tree_revision: int
var next_heartbeat_msec: int
var next_reconnect_msec: int
var completed_actions: Dictionary
var cancelled_calls: Dictionary
var backend_started: bool
var current_scene_instance_id: int
var current_tree_paused: bool


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var options: Dictionary = _read_options()
	test_session_id = str(options.get("testSessionId", ""))
	test_session_token = str(options.get("testSessionToken", ""))
	if test_session_id.is_empty() or test_session_token.is_empty():
		set_process(false)
		return
	backend_url = str(options.get("backendUrl", "ws://127.0.0.1:38181"))
	backend_dev_dir = str(options.get("backendDevDir", ""))
	runtime_instance_id = "godot-runtime-%d-%d" % [int(Time.get_unix_time_from_system()), randi()]
	if not _create_services():
		push_error("Daedalus Runtime Test Agent could not initialize.")
		set_process(false)
		return
	enabled = true
	current_scene_instance_id = get_tree().current_scene.get_instance_id() if get_tree().current_scene != null else 0
	current_tree_paused = get_tree().paused
	get_tree().tree_changed.connect(_on_tree_changed)
	_start_connection()


func _exit_tree() -> void:
	shutdown()


func _process(_delta: float) -> void:
	if not enabled or connection == null:
		return
	connection.poll()
	var scene_instance_id: int = get_tree().current_scene.get_instance_id() if get_tree().current_scene != null else 0
	if scene_instance_id != current_scene_instance_id:
		current_scene_instance_id = scene_instance_id
		_on_tree_changed()
	if get_tree().paused != current_tree_paused:
		current_tree_paused = get_tree().paused
		_on_tree_changed()
	var now_msec: int = Time.get_ticks_msec()
	if handshake_accepted and now_msec >= next_heartbeat_msec:
		_send_heartbeat()
	if connection.is_closed() and next_reconnect_msec > 0 and now_msec >= next_reconnect_msec:
		_start_connection()


func shutdown() -> void:
	enabled = false
	handshake_accepted = false
	completed_actions.clear()
	cancelled_calls.clear()
	if snapshot != null:
		snapshot.clear()
	if connection != null:
		connection.shutdown()
	if backend_runtime != null:
		backend_runtime.stop_started_backend()
	set_process(false)


func _create_services() -> bool:
	var backend_runtime_script: GDScript = load(BACKEND_RUNTIME_PATH) as GDScript
	var connection_script: GDScript = load(BRIDGE_CONNECTION_PATH) as GDScript
	var snapshot_script: GDScript = load(NODE_SNAPSHOT_PATH) as GDScript
	var input_script: GDScript = load(RUNTIME_INPUT_PATH) as GDScript
	var assertions_script: GDScript = load(RUNTIME_ASSERTIONS_PATH) as GDScript
	var adapter_script: GDScript = load(RUNTIME_TEST_ADAPTER_PATH) as GDScript
	if backend_runtime_script == null or connection_script == null or snapshot_script == null \
			or input_script == null or assertions_script == null or adapter_script == null:
		return false
	backend_runtime = backend_runtime_script.new()
	connection = connection_script.new() as Node
	snapshot = snapshot_script.new()
	runtime_input = input_script.new()
	runtime_assertions = assertions_script.new()
	test_adapter = adapter_script.new()
	if backend_runtime == null or connection == null or snapshot == null or runtime_input == null or runtime_assertions == null or test_adapter == null:
		return false
	snapshot.setup(test_adapter)
	runtime_input.setup(test_adapter)
	add_child(connection)
	connection.connected.connect(_on_connected)
	connection.disconnected.connect(_on_disconnected)
	connection.message_received.connect(_on_message_received)
	connection.protocol_error.connect(_on_protocol_error)
	return true


func _start_connection() -> void:
	next_reconnect_msec = 0
	handshake_accepted = false
	if not backend_started:
		backend_runtime.setup(backend_url, backend_dev_dir)
		var launch_result: Dictionary = backend_runtime.start_backend()
		if not bool(launch_result.get("ok", false)):
			_schedule_reconnect()
			return
		connection_url = str(launch_result.get("url", backend_url))
		auth_protocol = str(launch_result.get("authProtocol", ""))
		backend_started = true
	var connect_error: Error = connection.connect_to_backend(connection_url, 8 * 1024 * 1024, auth_protocol)
	if connect_error != OK:
		_schedule_reconnect()


func _on_connected() -> void:
	handshake_request_id = connection.send_request("client.hello", {
		"protocolVersion": 3,
		"clientType": "godot_runtime_test_bridge",
		"clientName": "Daedalus Runtime Test",
		"bridgeVersion": BRIDGE_VERSION,
		"bridgeProtocolVersion": BRIDGE_PROTOCOL_VERSION,
		"godotVersion": str(Engine.get_version_info().get("string", "")),
		"workspaceRoot": ProjectSettings.globalize_path("res://").trim_suffix("/"),
		"runtimeInstanceId": runtime_instance_id,
		"testSessionId": test_session_id,
		"testSessionToken": test_session_token,
		"capabilities": {
			"godotRuntimeTest": true,
			"godotRuntimeInput": true,
			"godotRuntimeAssertions": true,
		},
	}, "runtime-hello")


func _on_disconnected(_close_code: int, _close_reason: String) -> void:
	handshake_accepted = false
	completed_actions.clear()
	cancelled_calls.clear()
	snapshot.clear()
	_schedule_reconnect()


func _on_protocol_error(message: String) -> void:
	push_error("Daedalus Runtime Test protocol error: %s" % message)


func _on_message_received(message: Dictionary) -> void:
	if str(message.get("type", "")) == "response" and str(message.get("id", "")) == handshake_request_id:
		if not bool(message.get("ok", false)):
			push_error("Daedalus Runtime Test authorization was rejected.")
			shutdown()
			return
		handshake_accepted = true
		_send_heartbeat()
		return
	if not handshake_accepted or str(message.get("type", "")) != "event":
		return
	var data_value: Variant = message.get("data", {})
	if typeof(data_value) != TYPE_DICTIONARY:
		return
	var event_name: String = str(message.get("event", ""))
	if event_name == "godot.runtime.tool.cancelled":
		_handle_tool_cancelled(data_value as Dictionary)
	elif event_name == "godot.runtime.tool.requested":
		_handle_tool_requested.call_deferred(data_value as Dictionary)


func _handle_tool_cancelled(data: Dictionary) -> void:
	if str(data.get("testSessionId", "")) != test_session_id \
			or str(data.get("runtimeInstanceId", "")) != runtime_instance_id:
		return
	var call_id: String = str(data.get("callId", ""))
	if not call_id.is_empty():
		cancelled_calls[call_id] = true


func _handle_tool_requested(data: Dictionary) -> void:
	var call_id: String = str(data.get("callId", ""))
	var tool_name: String = str(data.get("toolName", ""))
	var requested_test_session_id: String = str(data.get("testSessionId", ""))
	var args_value: Variant = data.get("args", {})
	var args: Dictionary = args_value as Dictionary if typeof(args_value) == TYPE_DICTIONARY else {}
	if call_id.is_empty() or requested_test_session_id != test_session_id:
		return
	if _is_call_cancelled(call_id):
		cancelled_calls.erase(call_id)
		return
	var result: Dictionary
	if tool_name == "observe":
		result = _observe()
	elif tool_name == "action":
		result = await _execute_action(args, call_id)
	elif tool_name == "assert":
		result = _assert(args, call_id)
	elif tool_name == "wait":
		result = await _wait(args, call_id)
	elif tool_name == "screenshot":
		result = await _capture_screenshot(args, call_id)
	else:
		result = { "ok": false, "error": "runtime_tool_unknown" }
	if not _is_call_cancelled(call_id):
		_send_tool_result(call_id, result)
	cancelled_calls.erase(call_id)


func _observe() -> Dictionary:
	var root: Node = get_tree().current_scene
	return snapshot.observe(root, runtime_instance_id, tree_revision)


func _execute_action(args: Dictionary, call_id: String) -> Dictionary:
	if get_tree().paused:
		return { "ok": false, "error": "runtime_tree_paused", "status": "not_dispatched" }
	var action_id: String = str(args.get("actionId", ""))
	if action_id.is_empty():
		return { "ok": false, "error": "runtime_action_id_required", "status": "not_dispatched" }
	if completed_actions.has(action_id):
		return (completed_actions[action_id] as Dictionary).duplicate(true)
	var resolved: Dictionary = snapshot.resolve_node(
		str(args.get("observationId", "")),
		str(args.get("nodeId", "")),
		tree_revision
	)
	if not bool(resolved.get("ok", false)):
		return resolved
	var action_value: Variant = args.get("action", {})
	var action: Dictionary = action_value as Dictionary if typeof(action_value) == TYPE_DICTIONARY else {}
	var result: Dictionary = await runtime_input.execute(
		resolved.get("node") as Control,
		action,
		_is_call_cancelled.bind(call_id)
	)
	result["actionId"] = action_id
	result["runtimeInstanceId"] = runtime_instance_id
	completed_actions[action_id] = result.duplicate(true)
	return result


func _assert(args: Dictionary, call_id: String) -> Dictionary:
	if _is_call_cancelled(call_id):
		return { "ok": false, "error": "runtime_tool_cancelled", "status": "not_dispatched" }
	var resolved: Dictionary = snapshot.resolve_node(
		str(args.get("observationId", "")),
		str(args.get("nodeId", "")),
		tree_revision
	)
	if not bool(resolved.get("ok", false)):
		return resolved
	var assertion_value: Variant = args.get("assertion", {})
	var assertion: Dictionary = assertion_value as Dictionary if typeof(assertion_value) == TYPE_DICTIONARY else {}
	return runtime_assertions.assert_node(resolved.get("node") as Control, assertion)


func _wait(args: Dictionary, call_id: String) -> Dictionary:
	var resolved: Dictionary = snapshot.resolve_node(
		str(args.get("observationId", "")),
		str(args.get("nodeId", "")),
		tree_revision
	)
	if not bool(resolved.get("ok", false)):
		return resolved
	var assertion_value: Variant = args.get("assertion", {})
	var assertion: Dictionary = assertion_value as Dictionary if typeof(assertion_value) == TYPE_DICTIONARY else {}
	return await runtime_assertions.wait_for_node(
		resolved.get("node") as Control,
		assertion,
		int(args.get("timeoutMsec", 5000)),
		_is_call_cancelled.bind(call_id)
	)


func _capture_screenshot(args: Dictionary, call_id: String) -> Dictionary:
	if _is_call_cancelled(call_id):
		return { "ok": false, "error": "runtime_tool_cancelled" }
	if str(args.get("observationId", "")) != snapshot.observation_id:
		return { "ok": false, "error": "runtime_observation_stale" }
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return { "ok": false, "error": "runtime_viewport_unavailable" }
	await RenderingServer.frame_post_draw
	if _is_call_cancelled(call_id):
		return { "ok": false, "error": "runtime_tool_cancelled" }
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return { "ok": false, "error": "runtime_screenshot_unavailable" }
	var longest_edge: int = maxi(image.get_width(), image.get_height())
	if longest_edge > MAX_SCREENSHOT_EDGE:
		var scale: float = float(MAX_SCREENSHOT_EDGE) / float(longest_edge)
		image.resize(maxi(1, int(image.get_width() * scale)), maxi(1, int(image.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
	var png: PackedByteArray = image.save_png_to_buffer()
	while png.size() > MAX_SCREENSHOT_BYTES and image.get_width() > 320 and image.get_height() > 180:
		image.resize(maxi(1, int(image.get_width() * 0.85)), maxi(1, int(image.get_height() * 0.85)), Image.INTERPOLATE_LANCZOS)
		png = image.save_png_to_buffer()
	if png.size() > MAX_SCREENSHOT_BYTES:
		return { "ok": false, "error": "runtime_screenshot_too_large" }
	return {
		"ok": true,
		"observationId": snapshot.observation_id,
		"mimeType": "image/png",
		"width": image.get_width(),
		"height": image.get_height(),
		"byteLength": png.size(),
		"data": Marshalls.raw_to_base64(png),
		"capturedAtMsec": Time.get_ticks_msec(),
	}


func _send_tool_result(call_id: String, result: Dictionary) -> void:
	if not handshake_accepted:
		return
	var ok: bool = bool(result.get("ok", false))
	var params: Dictionary = {
		"callId": call_id,
		"runtimeInstanceId": runtime_instance_id,
		"testSessionId": test_session_id,
		"ok": ok,
	}
	if ok:
		params["result"] = result
	else:
		params["error"] = {
			"code": str(result.get("error", "runtime_tool_failed")),
			"message": str(result.get("message", result.get("error", "Runtime tool failed."))),
			"retryable": str(result.get("error", "")).contains("timeout"),
		}
	connection.send_request("godot.runtime.tool.result", params, "runtime-result")


func _is_call_cancelled(call_id: String) -> bool:
	return bool(cancelled_calls.get(call_id, false)) or not enabled or not handshake_accepted


func _send_heartbeat() -> void:
	if not handshake_accepted:
		return
	next_heartbeat_msec = Time.get_ticks_msec() + HEARTBEAT_INTERVAL_MSEC
	connection.send_request("godot.runtime.heartbeat", {
		"runtimeInstanceId": runtime_instance_id,
		"testSessionId": test_session_id,
		"treeRevision": tree_revision,
		"scenePath": get_tree().current_scene.scene_file_path if get_tree().current_scene != null else "",
	}, "runtime-heartbeat")


func _on_tree_changed() -> void:
	tree_revision += 1
	snapshot.clear()
	completed_actions.clear()


func _schedule_reconnect() -> void:
	if enabled:
		next_reconnect_msec = Time.get_ticks_msec() + RECONNECT_INTERVAL_MSEC


func _read_options() -> Dictionary:
	var options: Dictionary = {}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--daedalus-runtime-test="):
			options["testSessionId"] = argument.trim_prefix("--daedalus-runtime-test=")
		elif argument.begins_with("--daedalus-runtime-token="):
			options["testSessionToken"] = argument.trim_prefix("--daedalus-runtime-token=")
		elif argument.begins_with("--daedalus-backend-url="):
			options["backendUrl"] = argument.trim_prefix("--daedalus-backend-url=")
		elif argument.begins_with("--daedalus-backend-dev-dir="):
			options["backendDevDir"] = argument.trim_prefix("--daedalus-backend-dev-dir=")
	return options
