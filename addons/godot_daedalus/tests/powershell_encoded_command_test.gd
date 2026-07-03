@tool
extends SceneTree


func _init() -> void:
	if OS.get_name() != "Windows":
		quit(0)
		return

	var command_text: String = "Write-Output 'daedalus-ok'"
	var output_lines: Array = []
	var exit_code: int = OS.execute(
		_get_powershell_path(),
		PackedStringArray([
			"-NoProfile",
			"-ExecutionPolicy",
			"Bypass",
			"-EncodedCommand",
			Marshalls.raw_to_base64(command_text.to_utf16_buffer())
		]),
		output_lines,
		true
	)
	if exit_code != 0:
		push_error("PowerShell encoded command failed: %s" % "\n".join(_stringify_output_lines(output_lines)))
		quit(1)
		return

	if not _stringify_output_lines(output_lines).has("daedalus-ok"):
		push_error("PowerShell encoded command returned unexpected output: %s" % "\n".join(_stringify_output_lines(output_lines)))
		quit(1)
		return

	quit(0)


func _get_powershell_path() -> String:
	var system_root: String = OS.get_environment("SystemRoot").strip_edges()
	if not system_root.is_empty():
		var powershell_path: String = system_root.path_join("System32").path_join("WindowsPowerShell").path_join("v1.0").path_join("powershell.exe")
		if FileAccess.file_exists(powershell_path):
			return powershell_path

	return "powershell.exe"


func _stringify_output_lines(output_lines: Array) -> Array[String]:
	var text_lines: Array[String] = []
	for line_value: Variant in output_lines:
		text_lines.append(str(line_value).strip_edges())

	return text_lines
