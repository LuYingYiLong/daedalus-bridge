@tool
extends RefCounted

const PACKAGE_NAME: String = "daedalus-backend"
const MANAGER_BIN_NAME: String = "godot-daedalus-manager"

var backend_dev_dir: String


func setup(next_backend_dev_dir: String) -> void:
	backend_dev_dir = next_backend_dev_dir.strip_edges()


func run_json(manager_args: PackedStringArray) -> Dictionary:
	var output_lines: Array = []
	var command_result: Dictionary = _run_manager_command(manager_args, output_lines)
	var exit_code: int = int(command_result.get("exit_code", 1))
	var output_text: String = "\n".join(_stringify_output_lines(output_lines)).strip_edges()
	var parsed_output: Dictionary = _parse_json_output(output_text)
	if parsed_output.is_empty():
		return {
			"ok": false,
			"code": "manager_parse_failed",
			"message": "Daedalus manager did not return valid JSON.",
			"details": output_text,
			"exitCode": exit_code,
			"command": str(command_result.get("summary", ""))
		}

	if not parsed_output.has("exitCode"):
		parsed_output["exitCode"] = exit_code
	if not parsed_output.has("command"):
		parsed_output["command"] = str(command_result.get("summary", ""))
	return parsed_output


func _run_manager_command(manager_args: PackedStringArray, output_lines: Array) -> Dictionary:
	var last_summary: String = "godot-daedalus-manager"
	var invocations: Array[Dictionary] = _build_manager_invocations(manager_args)
	for invocation_index: int in range(invocations.size()):
		var invocation: Dictionary = invocations[invocation_index]
		output_lines.clear()
		var command_path: String = str(invocation.get("command_path", ""))
		var command_args: PackedStringArray = invocation.get("command_args", PackedStringArray()) as PackedStringArray
		last_summary = str(invocation.get("summary", ""))
		var exit_code: int = _execute_command(command_path, command_args, output_lines)
		if exit_code == 0:
			return {
				"exit_code": exit_code,
				"summary": last_summary
			}

		var output_text: String = "\n".join(_stringify_output_lines(output_lines))
		if output_text.contains("\"ok\""):
			var parsed_output: Dictionary = _parse_json_output(output_text)
			if _should_try_next_manager_invocation(parsed_output, invocation_index, invocations.size()):
				continue
			return {
				"exit_code": exit_code,
				"summary": last_summary
			}

	return {
		"exit_code": 1,
		"summary": last_summary
	}


func _build_manager_invocations(manager_args: PackedStringArray) -> Array[Dictionary]:
	var invocations: Array[Dictionary] = []
	var json_args: PackedStringArray = PackedStringArray(["--json"])
	json_args.append_array(manager_args)
	var dev_invocation: Dictionary = _build_dev_manager_invocation(json_args)
	if not dev_invocation.is_empty():
		invocations.append(dev_invocation)

	var npm_invocation: Dictionary = _build_npm_latest_manager_invocation(json_args)
	var prefer_latest_manager: bool = _should_prefer_latest_manager(manager_args)
	var allow_npm_latest_manager: bool = _should_allow_npm_latest_manager(manager_args)
	if prefer_latest_manager and allow_npm_latest_manager:
		invocations.append(npm_invocation)

	var current_manager_path: String = _get_current_manager_bin_path()
	if not current_manager_path.is_empty():
		invocations.append({
			"command_path": current_manager_path,
			"command_args": json_args,
			"summary": "%s %s" % [current_manager_path, " ".join(json_args)]
		})

	var legacy_manager_path: String = _get_legacy_manager_bin_path()
	if not legacy_manager_path.is_empty():
		invocations.append({
			"command_path": legacy_manager_path,
			"command_args": json_args,
			"summary": "%s %s" % [legacy_manager_path, " ".join(json_args)]
		})

	if not prefer_latest_manager and allow_npm_latest_manager:
		invocations.append(npm_invocation)

	invocations.append({
		"command_path": MANAGER_BIN_NAME,
		"command_args": json_args,
		"summary": "%s %s" % [MANAGER_BIN_NAME, " ".join(json_args)]
	})

	return invocations


func _build_dev_manager_invocation(json_args: PackedStringArray) -> Dictionary:
	if backend_dev_dir.is_empty():
		return {}

	var package_json_path: String = backend_dev_dir.path_join("package.json")
	if not FileAccess.file_exists(package_json_path):
		return {}

	var npm_args: PackedStringArray = PackedStringArray(["exec", "--prefix", backend_dev_dir, "--", MANAGER_BIN_NAME])
	npm_args.append_array(json_args)
	return {
		"command_path": "npm",
		"command_args": npm_args,
		"summary": "npm %s" % " ".join(npm_args)
	}


func _build_npm_latest_manager_invocation(json_args: PackedStringArray) -> Dictionary:
	var npm_args: PackedStringArray = PackedStringArray(["exec", "--yes", "--package", "%s@latest" % PACKAGE_NAME, "--", MANAGER_BIN_NAME])
	npm_args.append_array(json_args)
	return {
		"command_path": "npm",
		"command_args": npm_args,
		"summary": "npm %s" % " ".join(npm_args)
	}


func _should_prefer_latest_manager(manager_args: PackedStringArray) -> bool:
	if manager_args.size() < 2:
		return false

	var command_group: String = str(manager_args[0])
	var command_name: String = str(manager_args[1])
	if command_group != "frontend":
		return false

	return command_name == "download" or command_name == "stage" or command_name == "check"


func _should_allow_npm_latest_manager(manager_args: PackedStringArray) -> bool:
	if manager_args.size() < 2:
		return true

	var command_group: String = str(manager_args[0])
	var command_name: String = str(manager_args[1])
	if command_group == "backend" and (command_name == "start" or command_name == "stop" or command_name == "health"):
		return false

	return true


func _should_try_next_manager_invocation(parsed_output: Dictionary, invocation_index: int, invocation_count: int) -> bool:
	if invocation_index >= invocation_count - 1:
		return false

	if bool(parsed_output.get("ok", false)):
		return false

	var message: String = str(parsed_output.get("message", "")).strip_edges().to_lower()
	var details: String = str(parsed_output.get("details", "")).strip_edges().to_lower()
	var code: String = str(parsed_output.get("code", "")).strip_edges().to_lower()
	if code == "manager_parse_failed":
		return true
	if code == "unknown_error" and message == "fetch failed":
		return true
	if message == "fetch failed" and details.is_empty():
		return true

	return false


func _get_current_manager_bin_path() -> String:
	var current_json_path: String = _get_backend_install_dir().path_join("current.json")
	if not FileAccess.file_exists(current_json_path):
		return ""

	var current_data: Dictionary = _try_parse_json_dictionary(FileAccess.get_file_as_string(current_json_path))
	if current_data.is_empty():
		return ""

	var current_path: String = str(current_data.get("path", "")).strip_edges()
	if current_path.is_empty():
		return ""

	return _get_bin_path_for_prefix(current_path)


func _get_legacy_manager_bin_path() -> String:
	return _get_bin_path_for_prefix(_get_backend_install_dir())


func _get_bin_path_for_prefix(prefix_path: String) -> String:
	var bin_dir: String = prefix_path.path_join("node_modules").path_join(".bin")
	var manager_path: String
	if OS.get_name() == "Windows":
		manager_path = bin_dir.path_join("%s.cmd" % MANAGER_BIN_NAME)
	else:
		manager_path = bin_dir.path_join(MANAGER_BIN_NAME)

	if FileAccess.file_exists(manager_path):
		return manager_path

	return ""


func _get_backend_install_dir() -> String:
	var appdata_path: String = OS.get_environment("APPDATA").strip_edges()
	if appdata_path.is_empty():
		appdata_path = OS.get_user_data_dir()

	return appdata_path.path_join(".godot_daedalus").path_join("backend")


func _execute_command(command_path: String, command_args: PackedStringArray, output_lines: Array) -> int:
	if OS.get_name() == "Windows":
		var command_text: String = _build_windows_command_text(command_path, command_args)
		return OS.execute(_get_windows_shell_path(), PackedStringArray(["/d", "/s", "/c", command_text]), output_lines, true)

	return OS.execute(command_path, command_args, output_lines, true)


func _get_windows_shell_path() -> String:
	var shell_path: String = OS.get_environment("COMSPEC").strip_edges()
	if shell_path.is_empty():
		return "cmd.exe"

	return shell_path


func _build_windows_command_text(command_path: String, command_args: PackedStringArray) -> String:
	var parts: PackedStringArray = PackedStringArray([_quote_windows_command_part(command_path)])
	for command_arg: String in command_args:
		parts.append(_quote_windows_command_part(command_arg))

	return " ".join(parts)


func _quote_windows_command_part(value: String) -> String:
	if value.is_empty():
		return "\"\""

	var needs_quote: bool = value.contains(" ") or value.contains("\t") or value.contains("&") or value.contains("(") or value.contains(")") or value.contains("^") or value.contains("\"")
	if not needs_quote:
		return value

	return "\"%s\"" % value.replace("\"", "\\\"")


func _parse_json_output(output_text: String) -> Dictionary:
	var parsed_output: Dictionary = _try_parse_json_dictionary(output_text)
	if not parsed_output.is_empty():
		return parsed_output

	var start_index: int = output_text.find("{")
	var end_index: int = output_text.rfind("}")
	if start_index < 0 or end_index < start_index:
		return {}

	var sliced_text: String = output_text.substr(start_index, end_index - start_index + 1)
	return _try_parse_json_dictionary(sliced_text)


func _try_parse_json_dictionary(json_text: String) -> Dictionary:
	if json_text.strip_edges().is_empty():
		return {}

	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(json_text)
	if parse_error != OK:
		return {}

	var parsed_data: Variant = parser.data
	if typeof(parsed_data) != TYPE_DICTIONARY:
		return {}

	return parsed_data as Dictionary

	return {}


func _stringify_output_lines(output_lines: Array) -> PackedStringArray:
	var text_lines: PackedStringArray
	for line_value: Variant in output_lines:
		text_lines.append(str(line_value).strip_edges())

	return text_lines
