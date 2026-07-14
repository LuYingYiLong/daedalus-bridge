@tool
extends AcceptDialog

signal backend_update_started
signal backend_update_finished(exit_code: int)

const DOWNLOAD_DIALOG_SCENE: PackedScene = preload("uid://dg0dps48fpc7h")
const MANAGER_CLI_SCRIPT: GDScript = preload("uid://b6g8wsqm5d4et")
const PACKAGE_NAME: String = "daedalus-backend"
const NPM_MANAGER_BRIDGE_SCRIPT: String = "const fs=require('fs');const path=require('path');const cp=require('child_process');const packageName='daedalus-backend';const binNames=['bin/godot-daedalus-manager.js','bin/daedalus-manager.js'];const parts=(process.env.PATH||'').split(path.delimiter);for(const part of parts){const normalized=part.replace(/\\\\/g,'/');if(!normalized.endsWith('/node_modules/.bin'))continue;const root=path.resolve(part,'..',packageName);for(const name of binNames){const candidate=path.join(root,name);if(fs.existsSync(candidate)){const result=cp.spawnSync(process.execPath,[candidate,...process.argv.slice(1)],{stdio:'inherit'});process.exit(result.status??1);}}}console.error('daedalus manager package bin not found');process.exit(127);"
const BACKEND_BIN_FILES: PackedStringArray = [
	"godot-daedalus-backend",
	"godot-daedalus-backend.cmd",
	"godot-daedalus-backend.ps1",
	"godot-daedalus-mcp",
	"godot-daedalus-mcp.cmd",
	"godot-daedalus-mcp.ps1",
	"godot-daedalus-terminal-mcp",
	"godot-daedalus-terminal-mcp.cmd",
	"godot-daedalus-terminal-mcp.ps1"
]

@onready var node_js_current_version_label: Label = %NodeJsCurrentVersionLabel
@onready var npm_current_version_label: Label = %NPMCurrentVersionLabel
@onready var current_backend_version_label: Label = %CurrentBackendVersionLabel
@onready var latest_backend_version_label: Label = %LatestBackendVersionLabel
@onready var current_frontend_version_label: Label = %CurrentFrontendVersionLabel
@onready var latest_frontend_version_label: Label = %LatestFrontendVersionLabel
@onready var pending_frontend_version_label: Label = %PendingFrontendVersionLabel
@onready var download_node_js_button: Button = $VBoxContainer/NodeJsContainer/HBoxContainer/DownloadNodeJsButton
@onready var download_npm_button: Button = $VBoxContainer/NPMContainer/HBoxContainer/DownloadNPMButton
@onready var repair_button: Button = %RepairButton
@onready var download_backend_button: Button = %DownloadBackendButton
@onready var install_from_file_button: Button = $VBoxContainer/BackendContainer/HBoxContainer/InstallFromFileButton
@onready var stage_frontend_update_button: Button = %StageFrontendUpdateButton
@onready var file_dialog: EditorFileDialog = %EditorFileDialog

var node_command_path: String
var npm_command_path: String
var installed_backend_version: String
var latest_backend_version: String
var installed_frontend_version: String
var latest_frontend_version: String
var pending_frontend_version: String
var refresh_thread: Thread
var refresh_generation: int
var refresh_running: bool
var manager_command_thread: Thread
var manager_command_running: bool
var manager_cli: RefCounted
var check_for_updates_enabled: bool = true
var backend_dev_dir: String
var frontend_update_ready_dialog: ConfirmationDialog


func _ready() -> void:
	manager_cli = MANAGER_CLI_SCRIPT.new()
	_setup_manager_cli(manager_cli)
	refresh_status()


func setup_frontend_config(frontend_config: Dictionary) -> void:
	check_for_updates_enabled = bool(frontend_config.get("checkForUpdatesEnabled", true))
	backend_dev_dir = str(frontend_config.get("backendDevDir", "")).strip_edges()
	_setup_manager_cli(manager_cli)


func _setup_manager_cli(next_manager_cli: RefCounted) -> void:
	if next_manager_cli == null:
		return

	next_manager_cli.call("setup", backend_dev_dir)


func refresh_status() -> void:
	refresh_generation += 1
	var current_generation: int = refresh_generation
	if refresh_running:
		return

	refresh_running = true
	_set_loading_state()
	refresh_thread = Thread.new()
	refresh_thread.start(Callable(self, "_run_refresh_status_thread").bind(current_generation))


func _run_refresh_status_thread(current_generation: int) -> void:
	var node_result: Dictionary = _find_command(["node", "node.exe"], PackedStringArray(["--version"]))
	var node_version: String = str(node_result.get("version", ""))

	var npm_result: Dictionary = _find_command(["npm", "npm.cmd"], PackedStringArray(["--version"]))
	var next_npm_command_path: String = str(npm_result.get("path", ""))
	var npm_version: String = str(npm_result.get("version", ""))

	var manager_result: Dictionary = { "ok": false }
	if check_for_updates_enabled:
		var manager_args: PackedStringArray = PackedStringArray(["status", "--project", ProjectSettings.globalize_path("res://")])
		var status_manager_cli: RefCounted = MANAGER_CLI_SCRIPT.new()
		_setup_manager_cli(status_manager_cli)
		manager_result = status_manager_cli.call("run_json", manager_args) as Dictionary
	var backend_status: Dictionary = {}
	var frontend_status: Dictionary = {}
	if bool(manager_result.get("ok", false)):
		var status_value: Variant = manager_result.get("status", {})
		if typeof(status_value) == TYPE_DICTIONARY:
			var status_dictionary: Dictionary = status_value as Dictionary
			var backend_value: Variant = status_dictionary.get("backend", {})
			if typeof(backend_value) == TYPE_DICTIONARY:
				backend_status = backend_value as Dictionary
			var frontend_value: Variant = status_dictionary.get("frontend", {})
			if typeof(frontend_value) == TYPE_DICTIONARY:
				frontend_status = frontend_value as Dictionary

	var next_latest_backend_version: String = _read_optional_status_string(backend_status, "latestVersion")
	var next_installed_backend_version: String = _read_optional_status_string(backend_status, "installedVersion")
	var next_installed_frontend_version: String = _read_optional_status_string(frontend_status, "installedVersion")
	var next_latest_frontend_version: String = _read_optional_status_string(frontend_status, "latestVersion")
	var next_pending_frontend_version: String = _read_optional_status_string(frontend_status, "pendingVersion")
	if not bool(manager_result.get("ok", false)):
		next_installed_backend_version = _read_installed_backend_version()
		if check_for_updates_enabled:
			next_latest_backend_version = _read_latest_backend_version(next_npm_command_path)
		next_installed_frontend_version = _read_installed_frontend_version()
	call_deferred(
		"_finish_refresh_status",
		current_generation,
		str(node_result.get("path", "")),
		node_version,
		next_npm_command_path,
		npm_version,
		next_installed_backend_version,
		next_latest_backend_version,
		next_installed_frontend_version,
		next_latest_frontend_version,
		next_pending_frontend_version
	)


func _finish_refresh_status(
	current_generation: int,
	next_node_command_path: String,
	node_version: String,
	next_npm_command_path: String,
	npm_version: String,
	next_installed_backend_version: String,
	next_latest_backend_version: String,
	next_installed_frontend_version: String,
	next_latest_frontend_version: String,
	next_pending_frontend_version: String
) -> void:
	if refresh_thread != null:
		refresh_thread.wait_to_finish()
		refresh_thread = null
	refresh_running = false
	if current_generation != refresh_generation:
		refresh_status()
		return

	node_command_path = next_node_command_path
	npm_command_path = next_npm_command_path
	installed_backend_version = next_installed_backend_version
	latest_backend_version = next_latest_backend_version
	installed_frontend_version = next_installed_frontend_version
	latest_frontend_version = next_latest_frontend_version
	pending_frontend_version = next_pending_frontend_version

	node_js_current_version_label.text = "Current version: %s" % _format_missing_version(node_version)
	npm_current_version_label.text = "Current version: %s" % _format_missing_version(npm_version)
	current_backend_version_label.text = "Current version: %s" % _format_missing_version(installed_backend_version)
	if not check_for_updates_enabled:
		latest_backend_version_label.text = "Latest version: update checks disabled"
	elif latest_backend_version.is_empty():
		latest_backend_version_label.text = "Latest version: unavailable"
	else:
		latest_backend_version_label.text = "Latest version: %s" % latest_backend_version

	download_backend_button.disabled = npm_command_path.is_empty()
	repair_button.disabled = npm_command_path.is_empty()
	install_from_file_button.disabled = npm_command_path.is_empty()
	if installed_backend_version.is_empty():
		download_backend_button.text = "Install"
		download_backend_button.show()
		repair_button.hide()
	elif not latest_backend_version.is_empty() and installed_backend_version == latest_backend_version:
		download_backend_button.hide()
		repair_button.show()
	else:
		download_backend_button.text = "Update"
		download_backend_button.show()
		repair_button.hide()

	current_frontend_version_label.text = "Current version: %s" % _format_missing_version(installed_frontend_version)
	if not check_for_updates_enabled:
		latest_frontend_version_label.text = "Latest version: update checks disabled"
	elif latest_frontend_version.is_empty():
		latest_frontend_version_label.text = "Latest version: unavailable"
	else:
		latest_frontend_version_label.text = "Latest version: %s" % latest_frontend_version
	if _is_empty_status_text(pending_frontend_version):
		pending_frontend_version_label.text = "Pending version: none"
	else:
		pending_frontend_version_label.text = "Pending version: %s" % pending_frontend_version

	var has_actionable_pending_frontend_update: bool = _is_pending_frontend_update_actionable()
	if not has_actionable_pending_frontend_update and not _is_empty_status_text(pending_frontend_version):
		pending_frontend_version_label.text = "Pending version: already installed"

	if has_actionable_pending_frontend_update:
		stage_frontend_update_button.text = "Install pending update"
		stage_frontend_update_button.disabled = false
	elif not check_for_updates_enabled:
		stage_frontend_update_button.text = "Disabled"
		stage_frontend_update_button.disabled = true
	elif latest_frontend_version.is_empty():
		stage_frontend_update_button.text = "Stage update"
		stage_frontend_update_button.disabled = true
	elif not latest_frontend_version.is_empty() and installed_frontend_version == latest_frontend_version:
		stage_frontend_update_button.text = "Up to date"
		stage_frontend_update_button.disabled = true
	else:
		stage_frontend_update_button.text = "Stage update"
		stage_frontend_update_button.disabled = false


func _set_loading_state() -> void:
	node_js_current_version_label.text = "Current version: checking..."
	npm_current_version_label.text = "Current version: checking..."
	current_backend_version_label.text = "Current version: checking..."
	latest_backend_version_label.text = "Latest version: checking..."
	current_frontend_version_label.text = "Current version: checking..."
	latest_frontend_version_label.text = "Latest version: checking..."
	pending_frontend_version_label.text = "Pending version: checking..."
	download_backend_button.disabled = true
	repair_button.disabled = true
	install_from_file_button.disabled = true
	stage_frontend_update_button.disabled = true


func _find_command(candidates: PackedStringArray, version_args: PackedStringArray) -> Dictionary:
	for command_path: String in candidates:
		var output_lines: Array = []
		var exit_code: int = _execute_command(command_path, version_args, output_lines)
		if exit_code == 0:
			return {
				"path": command_path,
				"version": _first_output_line(output_lines)
			}

	return {
		"path": "",
		"version": ""
	}


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

	var needs_quote: bool = value.contains(" ") or value.contains("\t") or value.contains("&") or value.contains("(") or value.contains(")") or value.contains("^")
	if not needs_quote:
		return value

	return "\"%s\"" % value.replace("\"", "\\\"")


func _first_output_line(output_lines: Array) -> String:
	for line_value: Variant in output_lines:
		var line_text: String = str(line_value).strip_edges()
		if not line_text.is_empty():
			return line_text

	return ""


func _format_missing_version(version_text: String) -> String:
	if version_text.is_empty():
		return "Not found"

	return version_text


func _read_optional_status_string(status: Dictionary, key_name: String) -> String:
	var value: Variant = status.get(key_name, "")
	if value == null:
		return ""

	var text: String = str(value).strip_edges()
	var normalized_text: String = text.to_lower()
	if normalized_text == "null" or normalized_text == "<null>" or normalized_text == "nil" or normalized_text == "none":
		return ""

	return text


func _is_pending_frontend_update_actionable() -> bool:
	if pending_frontend_version.is_empty():
		return false
	if _is_empty_status_text(pending_frontend_version):
		return false
	if installed_frontend_version.is_empty():
		return true

	return _is_version_newer(pending_frontend_version, installed_frontend_version)


func _is_empty_status_text(text: String) -> bool:
	var normalized_text: String = text.strip_edges().to_lower()
	return normalized_text.is_empty() or normalized_text == "null" or normalized_text == "<null>" or normalized_text == "nil" or normalized_text == "none"


func _is_version_newer(candidate_version: String, current_version: String) -> bool:
	var candidate_parts: PackedInt32Array = _parse_semver(candidate_version)
	var current_parts: PackedInt32Array = _parse_semver(current_version)
	if candidate_parts.size() != 3 or current_parts.size() != 3:
		return candidate_version != current_version

	for index: int in range(3):
		if candidate_parts[index] > current_parts[index]:
			return true
		if candidate_parts[index] < current_parts[index]:
			return false

	return false


func _parse_semver(version_text: String) -> PackedInt32Array:
	var normalized_version: String = version_text.strip_edges().trim_prefix("v")
	var raw_parts: PackedStringArray = normalized_version.split(".")
	if raw_parts.size() != 3:
		return PackedInt32Array()

	var parsed_parts: PackedInt32Array
	for raw_part: String in raw_parts:
		if not raw_part.is_valid_int():
			return PackedInt32Array()
		parsed_parts.append(int(raw_part))

	return parsed_parts


func _read_installed_backend_version() -> String:
	var package_json_path: String = _get_current_backend_package_json_path()
	if package_json_path.is_empty():
		package_json_path = _get_legacy_backend_package_json_path()

	return _read_package_version(package_json_path)


func _read_installed_frontend_version() -> String:
	return _read_plugin_cfg_value(ProjectSettings.globalize_path("res://addons/godot_daedalus/plugin.cfg"), "version")


func _read_package_version(package_json_path: String) -> String:
	if package_json_path.is_empty() or not FileAccess.file_exists(package_json_path):
		return ""

	var content: String = FileAccess.get_file_as_string(package_json_path)
	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(content)
	if parse_error != OK:
		return ""

	var parsed_data: Variant = parser.data
	if typeof(parsed_data) != TYPE_DICTIONARY:
		return ""

	var package_data: Dictionary = parsed_data as Dictionary
	return str(package_data.get("version", "")).strip_edges()


func _read_plugin_cfg_value(file_path: String, key_name: String) -> String:
	if not FileAccess.file_exists(file_path):
		return ""

	var content: String = FileAccess.get_file_as_string(file_path)
	for raw_line: String in content.split("\n", false):
		var line_text: String = raw_line.strip_edges()
		if not line_text.begins_with("%s=" % key_name):
			continue

		var value_text: String = line_text.substr(key_name.length() + 1).strip_edges()
		return value_text.trim_prefix("\"").trim_suffix("\"")

	return ""


func _read_latest_backend_version(command_path: String) -> String:
	if command_path.is_empty():
		return ""

	var output_lines: Array = []
	var exit_code: int = _execute_command(command_path, PackedStringArray(["view", PACKAGE_NAME, "version"]), output_lines)
	if exit_code != 0:
		return ""

	return _first_output_line(output_lines)


func _get_backend_install_dir() -> String:
	var backend_install_dir: String = _get_daedalus_app_dir().path_join("backend")
	if DirAccess.dir_exists_absolute(backend_install_dir):
		return backend_install_dir

	var legacy_backend_install_dir: String = _get_legacy_daedalus_app_dir().path_join("backend")
	if DirAccess.dir_exists_absolute(legacy_backend_install_dir):
		return legacy_backend_install_dir

	return backend_install_dir


func _get_daedalus_app_dir() -> String:
	var user_profile_path: String = OS.get_environment("USERPROFILE").strip_edges()
	if not user_profile_path.is_empty():
		return user_profile_path.path_join(".daedalus")

	return OS.get_user_data_dir().path_join(".daedalus")


func _get_legacy_daedalus_app_dir() -> String:
	var appdata_path: String = OS.get_environment("APPDATA").strip_edges()
	if appdata_path.is_empty():
		return OS.get_user_data_dir().path_join(".godot_daedalus")

	return appdata_path.path_join(".godot_daedalus")


func _get_legacy_backend_package_json_path() -> String:
	return _get_backend_install_dir().path_join("node_modules").path_join(PACKAGE_NAME).path_join("package.json")


func _get_current_backend_package_json_path() -> String:
	var current_json_path: String = _get_backend_install_dir().path_join("current.json")
	if not FileAccess.file_exists(current_json_path):
		return ""

	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(FileAccess.get_file_as_string(current_json_path))
	if parse_error != OK:
		return ""

	var parsed_data: Variant = parser.data
	if typeof(parsed_data) != TYPE_DICTIONARY:
		return ""

	var current_data: Dictionary = parsed_data as Dictionary
	var current_path: String = str(current_data.get("path", "")).strip_edges()
	if current_path.is_empty():
		return ""

	var package_json_path: String = current_path.path_join("node_modules").path_join(PACKAGE_NAME).path_join("package.json")
	if FileAccess.file_exists(package_json_path):
		return package_json_path

	return current_path.path_join("package.json")


func _ensure_backend_install_dir() -> bool:
	var backend_install_dir: String = _get_backend_install_dir()
	var make_dir_error: Error = DirAccess.make_dir_recursive_absolute(backend_install_dir)
	if make_dir_error != OK:
		_show_command_message("Cannot create backend install directory: %s" % backend_install_dir)
		return false

	return true


func _build_npm_install_args(package_spec: String) -> PackedStringArray:
	return PackedStringArray([
		"install",
		"--prefix",
		_get_backend_install_dir(),
		"--prefer-online",
		package_spec
	])


func _build_npm_repair_args(package_spec: String) -> PackedStringArray:
	return PackedStringArray([
		"install",
		"--prefix",
		_get_backend_install_dir(),
		"--force",
		"--prefer-online",
		package_spec
	])


func _start_install_command(title_text: String, package_spec: String) -> void:
	backend_update_started.emit()
	var manager_args: PackedStringArray = PackedStringArray(["backend", "install"])
	if package_spec != "%s@latest" % PACKAGE_NAME:
		manager_args.append_array(PackedStringArray(["--version", package_spec.trim_prefix("%s@" % PACKAGE_NAME)]))
	_start_manager_command(title_text, manager_args)


func _start_repair_command(title_text: String, package_spec: String) -> void:
	backend_update_started.emit()
	var manager_args: PackedStringArray = PackedStringArray(["backend", "update"])
	if package_spec != "%s@latest" % PACKAGE_NAME:
		manager_args.append_array(PackedStringArray(["--version", package_spec.trim_prefix("%s@" % PACKAGE_NAME)]))
	_start_manager_command(title_text, manager_args)


func _start_manager_command(title_text: String, manager_args: PackedStringArray) -> void:
	if manager_command_running:
		return

	manager_command_running = true
	_set_loading_state()
	manager_command_thread = Thread.new()
	manager_command_thread.start(Callable(self, "_run_manager_command_thread").bind(title_text, manager_args))


func _run_manager_command_thread(title_text: String, manager_args: PackedStringArray) -> void:
	var command_manager_cli: RefCounted = MANAGER_CLI_SCRIPT.new()
	_setup_manager_cli(command_manager_cli)
	var result: Dictionary = command_manager_cli.call("run_json", manager_args) as Dictionary
	call_deferred("_finish_manager_command", title_text, result)


func _finish_manager_command(title_text: String, result: Dictionary) -> void:
	if manager_command_thread != null:
		manager_command_thread.wait_to_finish()
		manager_command_thread = null
	manager_command_running = false

	var ok: bool = bool(result.get("ok", false))
	backend_update_finished.emit(0 if ok else 1)
	if ok:
		if title_text == "Stage Daedalus plugin update":
			var frontend_value: Variant = result.get("frontend", {})
			var staged_version: String = latest_frontend_version
			if typeof(frontend_value) == TYPE_DICTIONARY:
				var frontend_dictionary: Dictionary = frontend_value as Dictionary
				staged_version = str(frontend_dictionary.get("version", staged_version)).strip_edges()
			_show_frontend_update_ready_dialog(staged_version)
		else:
			_show_command_message("%s completed successfully." % title_text)
	else:
		_show_command_message("%s failed.\n\n%s\n\n%s" % [
			title_text,
			str(result.get("message", "Unknown manager error.")),
			str(result.get("details", ""))
		])
	refresh_status()


func _stop_backend_processes_for_update() -> String:
	if OS.get_name() != "Windows":
		return ""

	var backend_install_dir: String = _normalize_absolute_path(_get_backend_install_dir()).replace("/", "\\")
	if backend_install_dir.is_empty():
		return "Cannot resolve Daedalus backend install directory."

	var powershell_command: String = "\n".join([
		"$ErrorActionPreference = 'Stop'",
		"$root = '%s'" % _escape_powershell_single_quoted(backend_install_dir),
		"$rootAlt = $root.Replace([char]92, [char]47)",
		"$processes = Get-CimInstance Win32_Process | Where-Object {",
		"  $commandLine = $_.CommandLine",
		"  $commandLine -and ($commandLine.Contains($root) -or $commandLine.Contains($rootAlt))",
		"}",
		"foreach ($process in $processes) {",
		"  if ($process.ProcessId -ne $PID) {",
		"    Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue",
		"    Write-Output (\"Stopped PID {0}: {1}\" -f $process.ProcessId, $process.Name)",
		"  }",
		"}"
	])

	var output_lines: Array = []
	var exit_code: int = OS.execute(
		_get_powershell_path(),
		PackedStringArray(["-NoProfile", "-ExecutionPolicy", "Bypass", "-EncodedCommand", Marshalls.raw_to_base64(powershell_command.to_utf16_buffer())]),
		output_lines,
		true
	)
	if exit_code == 0:
		return ""

	return "Could not stop stale Daedalus backend processes before updating.\n\n%s" % "\n".join(_stringify_output_lines(output_lines))


func _get_powershell_path() -> String:
	var system_root: String = OS.get_environment("SystemRoot").strip_edges()
	if not system_root.is_empty():
		var powershell_path: String = system_root.path_join("System32").path_join("WindowsPowerShell").path_join("v1.0").path_join("powershell.exe")
		if FileAccess.file_exists(powershell_path):
			return powershell_path

	return "powershell.exe"


func _escape_powershell_single_quoted(value: String) -> String:
	return value.replace("'", "''")


func _stringify_output_lines(output_lines: Array) -> Array[String]:
	var text_lines: PackedStringArray
	for line_value: Variant in output_lines:
		text_lines.append(str(line_value).strip_edges())

	return text_lines


func _prepare_backend_repair() -> String:
	var backend_install_dir: String = _get_backend_install_dir()
	var package_dir: String = backend_install_dir.path_join("node_modules").path_join(PACKAGE_NAME)
	if not _is_inside_backend_install_dir(package_dir):
		return "Refusing to repair unexpected backend package path: %s" % package_dir

	if DirAccess.dir_exists_absolute(package_dir):
		if not _remove_directory_tree_absolute(package_dir):
			return "Could not remove stale backend package directory: %s\n\nThe backend is probably still running and Windows is locking node_modules. Close Godot or stop node.exe for Daedalus, then try Repair again." % package_dir

	var bin_dir: String = backend_install_dir.path_join("node_modules").path_join(".bin")
	if _is_inside_backend_install_dir(bin_dir) and DirAccess.dir_exists_absolute(bin_dir):
		for bin_file_name: String in BACKEND_BIN_FILES:
			var bin_file_path: String = bin_dir.path_join(bin_file_name)
			if FileAccess.file_exists(bin_file_path):
				var remove_bin_error: Error = DirAccess.remove_absolute(bin_file_path)
				if remove_bin_error != OK:
					return "Could not remove stale backend command shim: %s" % bin_file_path

	for lock_file_name: String in ["package-lock.json", "npm-shrinkwrap.json"]:
		var lock_file_path: String = backend_install_dir.path_join(lock_file_name)
		if _is_inside_backend_install_dir(lock_file_path) and FileAccess.file_exists(lock_file_path):
			var remove_lock_error: Error = DirAccess.remove_absolute(lock_file_path)
			if remove_lock_error != OK:
				return "Could not remove stale npm lock file: %s" % lock_file_path

	var node_modules_lock_path: String = backend_install_dir.path_join("node_modules").path_join(".package-lock.json")
	if _is_inside_backend_install_dir(node_modules_lock_path) and FileAccess.file_exists(node_modules_lock_path):
		var remove_node_modules_lock_error: Error = DirAccess.remove_absolute(node_modules_lock_path)
		if remove_node_modules_lock_error != OK:
			return "Could not remove stale npm metadata: %s" % node_modules_lock_path

	return ""


func _is_inside_backend_install_dir(path_text: String) -> bool:
	var install_dir: String = _normalize_absolute_path(_get_backend_install_dir())
	var target_path: String = _normalize_absolute_path(path_text)
	return target_path == install_dir or target_path.begins_with("%s/" % install_dir)


func _normalize_absolute_path(path_text: String) -> String:
	return ProjectSettings.globalize_path(path_text).replace("\\", "/").simplify_path()


func _remove_directory_tree_absolute(directory_path: String) -> bool:
	if not _is_inside_backend_install_dir(directory_path):
		return false

	var directory_access: DirAccess = DirAccess.open(directory_path)
	if directory_access == null:
		return not DirAccess.dir_exists_absolute(directory_path)

	directory_access.list_dir_begin()
	var entry_name: String = directory_access.get_next()
	while not entry_name.is_empty():
		if entry_name == "." or entry_name == "..":
			entry_name = directory_access.get_next()
			continue

		var entry_path: String = directory_path.path_join(entry_name)
		if directory_access.current_is_dir():
			if not _remove_directory_tree_absolute(entry_path):
				directory_access.list_dir_end()
				return false
		else:
			var remove_file_error: Error = DirAccess.remove_absolute(entry_path)
			if remove_file_error != OK:
				directory_access.list_dir_end()
				return false

		entry_name = directory_access.get_next()

	directory_access.list_dir_end()
	var remove_directory_error: Error = DirAccess.remove_absolute(directory_path)
	return remove_directory_error == OK or not DirAccess.dir_exists_absolute(directory_path)


func _show_command_message(message_text: String) -> void:
	var message_dialog: AcceptDialog = AcceptDialog.new()
	message_dialog.dialog_text = message_text
	add_child(message_dialog)
	message_dialog.popup_centered_ratio()


func _show_frontend_update_ready_dialog(version_text: String) -> void:
	if frontend_update_ready_dialog != null:
		frontend_update_ready_dialog.queue_free()
		frontend_update_ready_dialog = null

	frontend_update_ready_dialog = ConfirmationDialog.new()
	frontend_update_ready_dialog.title = "Daedalus plugin update is ready"
	frontend_update_ready_dialog.dialog_text = "Daedalus plugin update %s has been downloaded.\n\nTo install it safely, start the installer, close every Godot editor window that has this project open, then press any key in the installer window.\n\nAfter the installer finishes, reopen your Godot project." % _format_missing_version(version_text)
	frontend_update_ready_dialog.ok_button_text = "Start Installer"
	frontend_update_ready_dialog.cancel_button_text = "Later"
	frontend_update_ready_dialog.confirmed.connect(Callable(self, "_on_frontend_update_ready_confirmed"))
	add_child(frontend_update_ready_dialog)
	frontend_update_ready_dialog.popup_centered_ratio()


func _on_frontend_update_ready_confirmed() -> void:
	_start_external_frontend_installer()


func _start_external_frontend_installer() -> void:
	if OS.get_name() != "Windows":
		_show_command_message("External Daedalus plugin installer is currently only available on Windows.")
		return

	var installer_path: String = ProjectSettings.globalize_path("user://daedalus_frontend_update_installer_%s.cmd" % str(Time.get_ticks_msec()))
	var installer_file: FileAccess = FileAccess.open(installer_path, FileAccess.WRITE)
	if installer_file == null:
		_show_command_message("Could not create Daedalus plugin installer script:\n%s" % installer_path)
		return

	installer_file.store_string(_build_frontend_installer_script())
	installer_file.close()

	var start_command: String = "start \"Daedalus Plugin Installer\" %s" % _quote_windows_command_part(installer_path)
	var process_id: int = OS.create_process(_get_windows_shell_path(), PackedStringArray(["/d", "/s", "/c", start_command]), false)
	if process_id <= 0:
		_show_command_message("Could not start Daedalus plugin installer script:\n%s" % installer_path)
		return

	_show_command_message("Daedalus plugin installer has started in a new terminal window.\n\nClose every Godot editor window that has this project open, then press any key in the installer window. Reopen your project after the installer completes.")


func _build_frontend_installer_script() -> String:
	var manager_command_parts: PackedStringArray = _build_external_manager_command_parts()
	manager_command_parts.append_array(PackedStringArray([
		"--json",
		"frontend",
		"apply-wait",
		"--project",
		ProjectSettings.globalize_path("res://")
	]))
	var manager_command: String = _join_windows_command_parts(manager_command_parts)
	var lines: PackedStringArray = PackedStringArray([
		"@echo off",
		"chcp 65001 >nul",
		"title Daedalus Plugin Installer",
		"echo Daedalus plugin installer is ready.",
		"echo.",
		"echo 1. Close every Godot editor window that has this project open.",
		"echo 2. Return to this installer window.",
		"echo 3. Press any key to replace the Daedalus plugin files.",
		"echo.",
		"echo The installer will keep retrying for a few minutes if Windows still holds file locks.",
		"echo.",
		"pause",
		"echo.",
		"call %s" % manager_command,
		"set EXITCODE=%ERRORLEVEL%",
		"echo.",
		"if \"%EXITCODE%\"==\"0\" (",
		"  echo Daedalus plugin update completed successfully.",
		"  echo Reopen your Godot project to load the new plugin version.",
		") else (",
		"  echo Daedalus plugin update failed with exit code %EXITCODE%.",
		"  echo Check the log path printed above, then try again from Backend Manager.",
		")",
		"echo.",
		"pause",
		"exit /b %EXITCODE%"
	])
	return "\r\n".join(lines) + "\r\n"


func _build_external_manager_command_parts() -> PackedStringArray:
	if not backend_dev_dir.is_empty() and FileAccess.file_exists(backend_dev_dir.path_join("package.json")):
		var dev_manager_path: String = backend_dev_dir.path_join("bin").path_join("daedalus-manager.js")
		if FileAccess.file_exists(dev_manager_path):
			return PackedStringArray(["node", dev_manager_path])
		return PackedStringArray(["npm", "exec", "--prefix", backend_dev_dir, "--", "godot-daedalus-manager"])

	return PackedStringArray(["npm", "exec", "--yes", "--package", "%s@latest" % PACKAGE_NAME, "--", "node", "-e", NPM_MANAGER_BRIDGE_SCRIPT, "--"])


func _join_windows_command_parts(parts: PackedStringArray) -> String:
	var quoted_parts: PackedStringArray
	for part: String in parts:
		quoted_parts.append(_quote_windows_command_part(part))

	return " ".join(quoted_parts)


func _on_download_dialog_command_finished(exit_code: int) -> void:
	backend_update_finished.emit(exit_code)
	refresh_status()


func _on_open_node_js_page_button_pressed() -> void:
	OS.shell_open("https://nodejs.org/")


func _on_download_node_js_button_pressed() -> void:
	OS.shell_open("https://nodejs.org/")


func _on_open_npm_page_button_pressed() -> void:
	OS.shell_open("https://docs.npmjs.com/downloading-and-installing-node-js-and-npm")


func _on_download_npm_button_pressed() -> void:
	OS.shell_open("https://docs.npmjs.com/downloading-and-installing-node-js-and-npm")


func _on_open_backend_page_button_pressed() -> void:
	OS.shell_open("https://www.npmjs.com/package/daedalus-backend")


func _on_open_frontend_page_button_pressed() -> void:
	OS.shell_open("https://github.com/LuYingYiLong/godot-daedalus/releases")


func _on_download_backend_button_pressed() -> void:
	var package_spec: String = "%s@latest" % PACKAGE_NAME
	if installed_backend_version.is_empty():
		_start_install_command("Install Daedalus backend", package_spec)
	else:
		_start_repair_command("Update Daedalus backend", package_spec)


func _on_install_from_file_button_pressed() -> void:
	if npm_command_path.is_empty():
		_show_command_message("npm was not found. Install Node.js first, then reopen this dialog.")
		return

	file_dialog.popup_centered_ratio()


func _on_backend_package_file_selected(file_path: String) -> void:
	if file_path.strip_edges().is_empty():
		return

	if installed_backend_version.is_empty():
		_start_install_command("Install Daedalus backend from file", ProjectSettings.globalize_path(file_path))
	else:
		_start_repair_command("Install Daedalus backend from file", ProjectSettings.globalize_path(file_path))


func _on_repair_button_pressed() -> void:
	var package_spec: String = "%s@latest" % PACKAGE_NAME
	_start_repair_command("Repair Daedalus backend", package_spec)


func _on_stage_frontend_update_button_pressed() -> void:
	if _is_pending_frontend_update_actionable():
		_show_frontend_update_ready_dialog(pending_frontend_version)
		return

	if latest_frontend_version.is_empty():
		_show_command_message("Latest frontend version is unavailable. Check your network connection, then refresh this dialog.")
		return

	_start_manager_command("Stage Daedalus plugin update", PackedStringArray(["frontend", "stage", "--version", latest_frontend_version]))


func _exit_tree() -> void:
	refresh_generation += 1
	if refresh_thread != null:
		refresh_thread.wait_to_finish()
		refresh_thread = null
