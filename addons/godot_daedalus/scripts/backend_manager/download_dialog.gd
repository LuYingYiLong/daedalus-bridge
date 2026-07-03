@tool
extends AcceptDialog

signal command_finished(exit_code: int)

@onready var log_label: RichTextLabel = %LogLabel

var command_thread: Thread
var command_running: bool


func _ready() -> void:
	ok_button_text = "Close"
	log_label.bbcode_enabled = false
	log_label.text = ""


func start_command(title_text: String, command_path: String, command_args: PackedStringArray) -> void:
	if command_running:
		return

	title = title_text
	command_running = true
	get_ok_button().disabled = true
	_append_log("$ %s %s" % [command_path, " ".join(command_args)])
	command_thread = Thread.new()
	command_thread.start(Callable(self, "_run_command_thread").bind(command_path, command_args))


func _run_command_thread(command_path: String, command_args: PackedStringArray) -> void:
	var output_lines: Array = []
	var exit_code: int = _execute_command(command_path, command_args, output_lines)
	call_deferred("_finish_command", exit_code, output_lines)


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


func _finish_command(exit_code: int, output_lines: Array) -> void:
	if command_thread != null:
		command_thread.wait_to_finish()
		command_thread = null

	for line_value: Variant in output_lines:
		_append_log(str(line_value).strip_edges())

	command_running = false
	get_ok_button().disabled = false
	_append_log("")
	if exit_code == 0:
		_append_log("Completed successfully.")
	else:
		_append_log("Failed with exit code: %d" % exit_code)
	command_finished.emit(exit_code)


func _append_log(line_text: String) -> void:
	if line_text.is_empty():
		log_label.append_text("\n")
		return

	log_label.append_text(line_text + "\n")
