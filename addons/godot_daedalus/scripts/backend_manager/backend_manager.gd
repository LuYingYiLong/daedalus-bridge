@tool
extends AcceptDialog

const DOWNLOAD_DIALOG_SCENE: PackedScene = preload("uid://dg0dps48fpc7h")
const PACKAGE_NAME: String = "godot-daedalus_backend"
const RECOMMENDED_BACKEND_VERSION: String = "1.0.1"

@onready var node_js_current_version_label: Label = %NodeJsCurrentVersionLabel
@onready var npm_current_version_label: Label = %NPMCurrentVersionLabel
@onready var current_backend_version_label: Label = %CurrentBackendVersionLabel
@onready var latest_backend_version_label: Label = %LatestBackendVersionLabel
@onready var download_node_js_button: Button = $VBoxContainer/NodeJsContainer/HBoxContainer/DownloadNodeJsButton
@onready var download_npm_button: Button = $VBoxContainer/NPMContainer/HBoxContainer/DownloadNPMButton
@onready var download_backend_button: Button = %DownloadBackendButton
@onready var install_from_file_button: Button = $VBoxContainer/BackendContainer/HBoxContainer/InstallFromFileButton
@onready var file_dialog: EditorFileDialog = %EditorFileDialog

var node_command_path: String
var npm_command_path: String
var installed_backend_version: String


func _ready() -> void:
	refresh_status()


func refresh_status() -> void:
	var node_result: Dictionary = _find_command(["node", "node.exe"], PackedStringArray(["--version"]))
	node_command_path = str(node_result.get("path", ""))
	var node_version: String = str(node_result.get("version", ""))
	node_js_current_version_label.text = "Current version: %s" % _format_missing_version(node_version)

	var npm_result: Dictionary = _find_command(["npm", "npm.cmd"], PackedStringArray(["--version"]))
	npm_command_path = str(npm_result.get("path", ""))
	var npm_version: String = str(npm_result.get("version", ""))
	npm_current_version_label.text = "Current version: %s" % _format_missing_version(npm_version)

	installed_backend_version = _read_installed_backend_version()
	current_backend_version_label.text = "Current version: %s" % _format_missing_version(installed_backend_version)
	latest_backend_version_label.text = "Recommended version: %s" % RECOMMENDED_BACKEND_VERSION

	download_backend_button.disabled = npm_command_path.is_empty()
	install_from_file_button.disabled = npm_command_path.is_empty()
	if installed_backend_version.is_empty():
		download_backend_button.text = "Install"
	elif installed_backend_version == RECOMMENDED_BACKEND_VERSION:
		download_backend_button.text = "Repair"
	else:
		download_backend_button.text = "Update"


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
		package_spec
	])


func _start_install_command(title_text: String, package_spec: String) -> void:
	if npm_command_path.is_empty():
		_show_command_message("npm was not found. Install Node.js first, then reopen this dialog.")
		return

	if not _ensure_backend_install_dir():
		return

	var download_dialog: AcceptDialog = DOWNLOAD_DIALOG_SCENE.instantiate()
	add_child(download_dialog)
	download_dialog.connect("command_finished", Callable(self, "_on_download_dialog_command_finished"))
	download_dialog.popup_centered()
	download_dialog.call("start_command", title_text, npm_command_path, _build_npm_install_args(package_spec))


func _show_command_message(message_text: String) -> void:
	var message_dialog: AcceptDialog = AcceptDialog.new()
	message_dialog.dialog_text = message_text
	add_child(message_dialog)
	message_dialog.popup_centered()


func _on_download_dialog_command_finished(_exit_code: int) -> void:
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
	var package_spec: String = "%s@%s" % [PACKAGE_NAME, RECOMMENDED_BACKEND_VERSION]
	_start_install_command("Install Daedalus backend", package_spec)


func _on_install_from_file_button_pressed() -> void:
	if npm_command_path.is_empty():
		_show_command_message("npm was not found. Install Node.js first, then reopen this dialog.")
		return

	file_dialog.popup_centered_ratio()


func _on_backend_package_file_selected(file_path: String) -> void:
	if file_path.strip_edges().is_empty():
		return

	_start_install_command("Install Daedalus backend from file", ProjectSettings.globalize_path(file_path))
