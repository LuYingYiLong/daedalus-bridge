@tool
extends RefCounted

const DEFAULT_BACKEND_PORT: int = 38180
const PLUGIN_PROTOCOL_VERSION: int = 2

var backend_url: String
var backend_dev_dir: String
var launch_mode: String
var command_summary: String
var last_error: String
var recent_log_lines: PackedStringArray


func setup(next_backend_url: String, next_backend_dev_dir: String) -> void:
	backend_url = next_backend_url.strip_edges()
	backend_dev_dir = next_backend_dev_dir.strip_edges()
	launch_mode = ""
	command_summary = ""
	last_error = ""
	recent_log_lines.clear()


func is_local_backend_url() -> bool:
	var normalized_url: String = backend_url.strip_edges().to_lower()
	return normalized_url.is_empty() \
		or normalized_url.begins_with("ws://127.0.0.1") \
		or normalized_url.begins_with("ws://localhost")


func probe_local_backend_port() -> Dictionary:
	return {
		"checked": false,
		"occupied": false,
		"host": "127.0.0.1",
		"port": DEFAULT_BACKEND_PORT
	}


func start_backend() -> Dictionary:
	last_error = ""
	recent_log_lines.clear()
	if not backend_dev_dir.is_empty():
		launch_mode = "development-external"
		command_summary = "Use the configured development backend"
		return {
			"ok": true,
			"mode": launch_mode,
			"url": backend_url,
			"authProtocol": "",
			"details": build_diagnostic_details()
		}

	if OS.get_name() != "Windows":
		last_error = "The shared Daedalus runtime is currently available on Windows only."
		return _failure_result()

	var managed_backend: Dictionary = _read_managed_backend()
	var executable_path: String = str(managed_backend.get("executablePath", "")).strip_edges()
	if executable_path.is_empty():
		last_error = "Daedalus Studio has not deployed a managed backend. Open Daedalus Studio once, then reconnect."
		return _failure_result()
	launch_mode = "shared-runtime"
	command_summary = "%s runtime acquire --client godot --project <project> --json" % executable_path
	if not _supports_shared_runtime(managed_backend):
		return _failure_result()

	var project_path: String = ProjectSettings.globalize_path("res://").trim_suffix("/")
	var command_args: PackedStringArray = PackedStringArray([
		"runtime",
		"acquire",
		"--client",
		"godot",
		"--project",
		project_path,
		"--json"
	])
	var output_lines: Array = []
	var exit_code: int = OS.execute(executable_path, command_args, output_lines, true)
	recent_log_lines = _stringify_output_lines(output_lines)
	var output_text: String = "\n".join(recent_log_lines).strip_edges()
	var result: Dictionary = _parse_json_dictionary(output_text)
	if exit_code != 0 or not bool(result.get("ok", false)):
		last_error = str(result.get("error", output_text)).strip_edges()
		if last_error.is_empty():
			last_error = "Shared backend runtime acquisition failed with exit code %d." % exit_code
		return _failure_result()

	var connection_value: Variant = result.get("connection", {})
	if typeof(connection_value) != TYPE_DICTIONARY:
		last_error = "The shared runtime did not return connection metadata."
		return _failure_result()
	var connection: Dictionary = connection_value as Dictionary
	var host: String = str(connection.get("host", "127.0.0.1")).strip_edges()
	var port: int = int(connection.get("port", DEFAULT_BACKEND_PORT))
	var auth_protocol: String = str(result.get("authProtocol", "")).strip_edges()
	if host != "127.0.0.1" or port <= 0 or auth_protocol.is_empty():
		last_error = "The shared runtime returned an invalid local connection."
		return _failure_result()

	return {
		"ok": true,
		"mode": launch_mode,
		"url": "ws://%s:%d" % [host, port],
		"authProtocol": auth_protocol,
		"leaseId": str(result.get("leaseId", "")),
		"backendVersion": str(connection.get("version", "")),
		"details": build_diagnostic_details()
	}


func stop_started_backend() -> Dictionary:
	return {
		"ok": true,
		"message": "The shared backend remains available for other authenticated clients."
	}


func poll_logs() -> void:
	pass


func build_diagnostic_details() -> String:
	var lines: PackedStringArray = [
		"Mode: %s" % (launch_mode if not launch_mode.is_empty() else "not started"),
		"Command: %s" % (command_summary if not command_summary.is_empty() else "none")
	]
	if not last_error.is_empty():
		lines.append("Error: %s" % last_error)
	if not recent_log_lines.is_empty():
		lines.append("Output:")
		lines.append_array(recent_log_lines)
	return "\n".join(lines)


func _read_managed_backend() -> Dictionary:
	var current_path: String = _get_daedalus_app_dir().path_join("backend").path_join("current.json")
	if not FileAccess.file_exists(current_path):
		return {}
	var current: Dictionary = _parse_json_dictionary(FileAccess.get_file_as_string(current_path))
	var executable_path: String = str(current.get("executablePath", "")).strip_edges()
	if executable_path.is_empty() or not FileAccess.file_exists(executable_path):
		return {}
	return current


func _supports_shared_runtime(managed_backend: Dictionary) -> bool:
	var manifest_path: String = str(managed_backend.get("manifestPath", "")).strip_edges()
	var backend_version: String = str(managed_backend.get("version", "unknown")).strip_edges()
	if manifest_path.is_empty() or not FileAccess.file_exists(manifest_path):
		last_error = "Managed backend %s has no verified shared-runtime manifest. Open the current Daedalus Studio once so it can repair the backend, or configure Backend dev directory for development mode." % backend_version
		return false
	var manifest: Dictionary = _parse_json_dictionary(FileAccess.get_file_as_string(manifest_path))
	var minimum_protocol: int = int(manifest.get("minPluginProtocolVersion", 0))
	var maximum_protocol: int = int(manifest.get("maxPluginProtocolVersion", 0))
	if minimum_protocol <= 0 or maximum_protocol < minimum_protocol:
		last_error = "Managed backend %s predates shared runtime support. Open Daedalus Studio 1.0.3 or later once to install backend 1.1.4 or later. For a source backend, set Backend dev directory and run it at ws://localhost:38181." % backend_version
		return false
	if PLUGIN_PROTOCOL_VERSION < minimum_protocol or PLUGIN_PROTOCOL_VERSION > maximum_protocol:
		last_error = "Managed backend %s supports plugin protocol %d-%d, but this plugin requires protocol %d. Update Daedalus Studio and the Godot Daedalus plugin together." % [backend_version, minimum_protocol, maximum_protocol, PLUGIN_PROTOCOL_VERSION]
		return false
	return true


func _get_daedalus_app_dir() -> String:
	var user_profile: String = OS.get_environment("USERPROFILE").strip_edges()
	if not user_profile.is_empty():
		return user_profile.path_join(".daedalus")
	return OS.get_user_data_dir().path_join(".daedalus")


func _failure_result() -> Dictionary:
	return {
		"ok": false,
		"mode": launch_mode,
		"message": last_error,
		"details": build_diagnostic_details()
	}


func _parse_json_dictionary(text: String) -> Dictionary:
	var normalized: String = text.strip_edges()
	var start_index: int = normalized.find("{")
	var end_index: int = normalized.rfind("}")
	if start_index < 0 or end_index < start_index:
		return {}
	var parser: JSON = JSON.new()
	if parser.parse(normalized.substr(start_index, end_index - start_index + 1)) != OK:
		return {}
	if typeof(parser.data) != TYPE_DICTIONARY:
		return {}
	return parser.data as Dictionary


func _stringify_output_lines(output_lines: Array) -> PackedStringArray:
	var result: PackedStringArray
	for line_value: Variant in output_lines:
		var line: String = str(line_value).strip_edges()
		if not line.is_empty():
			result.append(line)
	return result
