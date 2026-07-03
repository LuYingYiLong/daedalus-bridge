@tool
extends AcceptDialog

signal backend_update_started
signal backend_update_finished(exit_code: int)

const DOWNLOAD_DIALOG_SCENE: PackedScene = preload("uid://dg0dps48fpc7h")
const PACKAGE_NAME: String = "godot-daedalus_backend"
const BACKEND_BIN_FILES: Array[String] = [
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
@onready var download_node_js_button: Button = $VBoxContainer/NodeJsContainer/HBoxContainer/DownloadNodeJsButton
@onready var download_npm_button: Button = $VBoxContainer/NPMContainer/HBoxContainer/DownloadNPMButton
@onready var repair_button: Button = %RepairButton
@onready var download_backend_button: Button = %DownloadBackendButton
@onready var install_from_file_button: Button = $VBoxContainer/BackendContainer/HBoxContainer/InstallFromFileButton
@onready var file_dialog: EditorFileDialog = %EditorFileDialog

var node_command_path: String
var npm_command_path: String
var installed_backend_version: String
var latest_backend_version: String
var refresh_thread: Thread
var refresh_generation: int
var refresh_running: bool


func _ready() -> void:
	refresh_status()


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

	var next_latest_backend_version: String = _read_latest_backend_version(next_npm_command_path)
	var next_installed_backend_version: String = _read_installed_backend_version()
	call_deferred(
		"_finish_refresh_status",
		current_generation,
		str(node_result.get("path", "")),
		node_version,
		next_npm_command_path,
		npm_version,
		next_installed_backend_version,
		next_latest_backend_version
	)


func _finish_refresh_status(
	current_generation: int,
	next_node_command_path: String,
	node_version: String,
	next_npm_command_path: String,
	npm_version: String,
	next_installed_backend_version: String,
	next_latest_backend_version: String
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

	node_js_current_version_label.text = "Current version: %s" % _format_missing_version(node_version)
	npm_current_version_label.text = "Current version: %s" % _format_missing_version(npm_version)
	current_backend_version_label.text = "Current version: %s" % _format_missing_version(installed_backend_version)
	if latest_backend_version.is_empty():
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


func _set_loading_state() -> void:
	node_js_current_version_label.text = "Current version: checking..."
	npm_current_version_label.text = "Current version: checking..."
	current_backend_version_label.text = "Current version: checking..."
	latest_backend_version_label.text = "Latest version: checking..."
	download_backend_button.disabled = true
	repair_button.disabled = true
	install_from_file_button.disabled = true


func _find_command(candidates: Array[String], version_args: PackedStringArray) -> Dictionary:
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


func _read_installed_backend_version() -> String:
	var package_json_path: String = _get_backend_package_json_path()
	if not FileAccess.file_exists(package_json_path):
		return ""

	var content: String = FileAccess.get_file_as_string(package_json_path)
	var parsed_json: Variant = JSON.parse_string(content)
	if typeof(parsed_json) != TYPE_DICTIONARY:
		return ""

	var package_data: Dictionary = parsed_json as Dictionary
	return str(package_data.get("version", "")).strip_edges()


func _read_latest_backend_version(command_path: String) -> String:
	if command_path.is_empty():
		return ""

	var output_lines: Array = []
	var exit_code: int = _execute_command(command_path, PackedStringArray(["view", PACKAGE_NAME, "version"]), output_lines)
	if exit_code != 0:
		return ""

	return _first_output_line(output_lines)


func _get_backend_install_dir() -> String:
	var appdata_path: String = OS.get_environment("APPDATA").strip_edges()
	if appdata_path.is_empty():
		appdata_path = OS.get_user_data_dir()

	return appdata_path.path_join(".godot_daedalus").path_join("backend")


func _get_backend_package_json_path() -> String:
	return _get_backend_install_dir().path_join("node_modules").path_join(PACKAGE_NAME).path_join("package.json")


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
	if npm_command_path.is_empty():
		_show_command_message("npm was not found. Install Node.js first, then reopen this dialog.")
		return

	if not _ensure_backend_install_dir():
		return

	backend_update_started.emit()
	var stop_error: String = _stop_backend_processes_for_update()
	if not stop_error.is_empty():
		backend_update_finished.emit(1)
		_show_command_message(stop_error)
		return

	var download_dialog: AcceptDialog = DOWNLOAD_DIALOG_SCENE.instantiate()
	add_child(download_dialog)
	download_dialog.connect("command_finished", Callable(self, "_on_download_dialog_command_finished"))
	download_dialog.popup_centered()
	download_dialog.call("start_command", title_text, npm_command_path, _build_npm_install_args(package_spec))


func _start_repair_command(title_text: String, package_spec: String) -> void:
	if npm_command_path.is_empty():
		_show_command_message("npm was not found. Install Node.js first, then reopen this dialog.")
		return

	if not _ensure_backend_install_dir():
		return

	backend_update_started.emit()
	var stop_error: String = _stop_backend_processes_for_update()
	if not stop_error.is_empty():
		backend_update_finished.emit(1)
		_show_command_message(stop_error)
		return

	var repair_error: String = _prepare_backend_repair()
	if not repair_error.is_empty():
		backend_update_finished.emit(1)
		_show_command_message(repair_error)
		return

	var download_dialog: AcceptDialog = DOWNLOAD_DIALOG_SCENE.instantiate()
	add_child(download_dialog)
	download_dialog.connect("command_finished", Callable(self, "_on_download_dialog_command_finished"))
	download_dialog.popup_centered()
	download_dialog.call("start_command", title_text, npm_command_path, _build_npm_repair_args(package_spec))


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
	var text_lines: Array[String] = []
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
	message_dialog.popup_centered()


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
	OS.shell_open("https://www.npmjs.com/package/godot-daedalus_backend")


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


func _exit_tree() -> void:
	refresh_generation += 1
	if refresh_thread != null:
		refresh_thread.wait_to_finish()
		refresh_thread = null
