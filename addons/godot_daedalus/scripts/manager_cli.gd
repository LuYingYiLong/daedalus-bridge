@tool
extends RefCounted

const PACKAGE_NAME: String = "godot-daedalus_backend"
const MANAGER_BIN_NAME: String = "godot-daedalus-manager"


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
	for invocation: Dictionary in _build_manager_invocations(manager_args):
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

	invocations.append({
		"command_path": MANAGER_BIN_NAME,
		"command_args": json_args,
		"summary": "%s %s" % [MANAGER_BIN_NAME, " ".join(json_args)]
	})

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

	var npm_args: PackedStringArray = PackedStringArray(["exec", "--yes", "--package", "%s@latest" % PACKAGE_NAME, "--", MANAGER_BIN_NAME])
	npm_args.append_array(json_args)
	invocations.append({
		"command_path": "npm",
		"command_args": npm_args,
		"summary": "npm %s" % " ".join(npm_args)
	})

	return invocations


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


func _stringify_output_lines(output_lines: Array) -> Array[String]:
	var text_lines: Array[String] = []
	for line_value: Variant in output_lines:
		text_lines.append(str(line_value).strip_edges())

	return text_lines
