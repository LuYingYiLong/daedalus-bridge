@tool
extends RefCounted

const PACKAGE_NAME: String = "godot-daedalus_backend"
const BACKEND_BIN_NAME: String = "godot-daedalus-backend"
const MANAGER_CLI_SCRIPT: GDScript = preload("uid://b6g8wsqm5d4et")
const DEFAULT_PUBLISHED_BACKEND_PORT: int = 38180
const DEFAULT_DEVELOPMENT_BACKEND_PORT: int = 38181
const MAX_LOG_LINES: int = 80
const MAX_LOG_READ_BYTES: int = 65536
const TCP_PROBE_ATTEMPTS: int = 50
const TCP_PROBE_DELAY_MSEC: int = 20
const STARTUP_LOCK_STALE_SECONDS: int = 15

var backend_url: String
var backend_dev_dir: String
var launch_mode: String
var command_summary: String
var launched_pid: int = -1
var log_file_path: String
var recent_log_lines: PackedStringArray
var last_error: String
var manager_cli: RefCounted
var startup_lock_dir: String


func setup(next_backend_url: String, next_backend_dev_dir: String) -> void:
	backend_url = next_backend_url.strip_edges()
	backend_dev_dir = next_backend_dev_dir.strip_edges()
	launch_mode = ""
	command_summary = ""
	launched_pid = -1
	log_file_path = ""
	recent_log_lines.clear()
	last_error = ""
	startup_lock_dir = ""
	manager_cli = MANAGER_CLI_SCRIPT.new()


func is_local_backend_url() -> bool:
	var normalized_url: String = backend_url.strip_edges().to_lower()
	if normalized_url.is_empty():
		return true

	return normalized_url == "ws://localhost" \
		or normalized_url.begins_with("ws://localhost:") \
		or normalized_url.begins_with("ws://localhost/") \
		or normalized_url == "ws://127.0.0.1" \
		or normalized_url.begins_with("ws://127.0.0.1:") \
		or normalized_url.begins_with("ws://127.0.0.1/") \
		or normalized_url == "ws://[::1]" \
		or normalized_url.begins_with("ws://[::1]:") \
		or normalized_url.begins_with("ws://[::1]/")


func probe_local_backend_port() -> Dictionary:
	if not is_local_backend_url():
		return {
			"checked": false,
			"occupied": false,
			"host": "",
			"port": 0
		}

	var port_number: int = _parse_backend_url_port()
	if port_number <= 0:
		return {
			"checked": false,
			"occupied": false,
			"host": "127.0.0.1",
			"port": port_number
		}

	var probe_hosts: PackedStringArray = _get_backend_probe_hosts()
	for host_name: String in probe_hosts:
		if _is_tcp_port_occupied(host_name, port_number):
			return {
				"checked": true,
				"occupied": true,
				"host": host_name,
				"port": port_number
			}

	return {
		"checked": true,
		"occupied": false,
		"host": ", ".join(probe_hosts),
		"port": port_number
	}


func _is_tcp_port_occupied(host_name: String, port_number: int) -> bool:
	var tcp_peer: StreamPeerTCP = StreamPeerTCP.new()
	var connect_error: Error = tcp_peer.connect_to_host(host_name, port_number)
	if connect_error != OK:
		return false

	for _attempt_index: int in range(TCP_PROBE_ATTEMPTS):
		tcp_peer.poll()
		var tcp_status: StreamPeerTCP.Status = tcp_peer.get_status()
		if tcp_status == StreamPeerTCP.STATUS_CONNECTED:
			tcp_peer.disconnect_from_host()
			return true
		if tcp_status == StreamPeerTCP.STATUS_ERROR:
			return false

		OS.delay_msec(TCP_PROBE_DELAY_MSEC)

	tcp_peer.disconnect_from_host()
	return false


func start_backend() -> Dictionary:
	last_error = ""
	recent_log_lines.clear()
	log_file_path = _prepare_launch_log_file()
	launched_pid = -1
	if not _try_acquire_startup_lock():
		return {
			"ok": true,
			"mode": launch_mode,
			"alreadyRunning": true,
			"message": last_error,
			"details": build_diagnostic_details()
		}

	var port_probe: Dictionary = probe_local_backend_port()
	if bool(port_probe.get("checked", false)) and bool(port_probe.get("occupied", false)):
		launch_mode = "waiting-existing"
		command_summary = "waiting for backend on occupied port"
		last_error = "Backend port %d is already in use on %s. Daedalus will wait briefly in case another project is starting the backend." % [
			int(port_probe.get("port", 0)),
			str(port_probe.get("host", "localhost"))
		]
		_release_startup_lock()
		return {
			"ok": true,
			"mode": launch_mode,
			"alreadyRunning": true,
			"message": last_error,
			"details": build_diagnostic_details()
		}

	if backend_dev_dir.is_empty():
		return _start_published_backend_with_manager()

	var command_text: String = _build_launch_command_text()
	if command_text.is_empty():
		_release_startup_lock()
		return {
			"ok": false,
			"mode": launch_mode,
			"message": last_error,
			"details": build_diagnostic_details()
		}

	var shell_path: String = _get_shell_path()
	var shell_args: PackedStringArray = _get_shell_args(_append_log_redirection(command_text))
	launched_pid = OS.create_process(shell_path, shell_args, false)
	if launched_pid <= 0:
		last_error = "Could not create backend child process."
		_release_startup_lock()
		return {
			"ok": false,
			"mode": launch_mode,
			"message": last_error,
			"details": build_diagnostic_details()
		}

	return {
		"ok": true,
		"mode": launch_mode,
		"pid": launched_pid,
		"details": build_diagnostic_details()
	}


func stop_started_backend() -> Dictionary:
	if backend_dev_dir.is_empty() and manager_cli != null and launch_mode != "published-legacy":
		var stop_result: Dictionary = manager_cli.call("run_json", PackedStringArray(["backend", "stop"])) as Dictionary
		launched_pid = -1
		return stop_result

	if launched_pid <= 0:
		return {
			"ok": true,
			"message": "No plugin-started backend process is recorded."
		}

	var output_lines: Array = []
	var exit_code: int
	if OS.get_name() == "Windows":
		exit_code = OS.execute(
			"taskkill",
			PackedStringArray(["/PID", str(launched_pid), "/T", "/F"]),
			output_lines,
			true
		)
	else:
		exit_code = OS.execute(
			"kill",
			PackedStringArray(["-TERM", str(launched_pid)]),
			output_lines,
			true
		)

	var previous_pid: int = launched_pid
	launched_pid = -1
	return {
		"ok": exit_code == 0,
		"pid": previous_pid,
		"exitCode": exit_code,
		"message": "\n".join(_stringify_output_lines(output_lines))
	}


func _start_published_backend_with_manager() -> Dictionary:
	launch_mode = "published"
	var launch_port: int = _parse_backend_url_port()
	command_summary = "godot-daedalus-manager backend start --port %d" % launch_port
	var manager_result: Dictionary = manager_cli.call("run_json", PackedStringArray(["backend", "start", "--port", str(launch_port)])) as Dictionary
	if not bool(manager_result.get("ok", false)):
		last_error = str(manager_result.get("message", "Daedalus manager could not start the backend."))
		var manager_details: String = str(manager_result.get("details", ""))
		if not manager_details.is_empty():
			last_error += "\n%s" % manager_details
		_release_startup_lock()
		return {
			"ok": false,
			"mode": launch_mode,
			"message": last_error,
			"details": build_diagnostic_details()
		}

	var backend_value: Variant = manager_result.get("backend", {})
	if typeof(backend_value) == TYPE_DICTIONARY:
		var backend_dictionary: Dictionary = backend_value as Dictionary
		launched_pid = int(backend_dictionary.get("pid", -1))
		log_file_path = str(backend_dictionary.get("logPath", log_file_path))

	return {
		"ok": true,
		"mode": launch_mode,
		"pid": launched_pid,
		"details": build_diagnostic_details()
	}


func _start_legacy_published_backend(manager_message: String, manager_details: String) -> Dictionary:
	launch_mode = "published-legacy"
	var launch_port: int = _parse_backend_url_port()
	var backend_install_dir: String = _get_backend_install_dir()
	if OS.get_name() == "Windows":
		command_summary = "set DAEDALUS_BACKEND_MODE=runtime&& set PORT=%d&& npm exec --prefix %s -- %s" % [
			launch_port,
			_quote_command_part(backend_install_dir),
			BACKEND_BIN_NAME
		]
	else:
		command_summary = "DAEDALUS_BACKEND_MODE=runtime PORT=%d npm exec --prefix %s -- %s" % [
			launch_port,
			_quote_command_part(backend_install_dir),
			BACKEND_BIN_NAME
		]

	var shell_path: String = _get_shell_path()
	var shell_args: PackedStringArray = _get_shell_args(_append_log_redirection(command_summary))
	launched_pid = OS.create_process(shell_path, shell_args, false)
	if launched_pid <= 0:
		last_error = "Daedalus manager is unavailable, and the legacy backend command could not be started.\n%s" % manager_message
		if not manager_details.is_empty():
			last_error += "\n%s" % manager_details
		_release_startup_lock()
		return {
			"ok": false,
			"mode": launch_mode,
			"message": last_error,
			"details": build_diagnostic_details()
		}

	last_error = ""
	return {
		"ok": true,
		"mode": launch_mode,
		"pid": launched_pid,
		"details": build_diagnostic_details()
	}


func poll_logs() -> void:
	_read_launch_log_file()


func get_recent_log_text() -> String:
	return "\n".join(recent_log_lines)


func build_diagnostic_details() -> String:
	poll_logs()
	var lines: PackedStringArray
	lines.append("Backend URL: %s" % backend_url)
	if not launch_mode.is_empty():
		lines.append("Launch mode: %s" % launch_mode)
	if not command_summary.is_empty():
		lines.append("Command: %s" % command_summary)
	if launched_pid > 0:
		lines.append("PID: %d" % launched_pid)
	if not log_file_path.is_empty():
		lines.append("Log file: %s" % log_file_path)
	if not last_error.is_empty():
		lines.append("Error: %s" % last_error)

	var log_text: String = get_recent_log_text()
	if not log_text.is_empty():
		lines.append("")
		lines.append("Recent backend log:")
		lines.append(log_text)

	return "\n".join(lines)


func _parse_backend_url_port() -> int:
	var normalized_url: String = backend_url.strip_edges().to_lower()
	if normalized_url.is_empty():
		return DEFAULT_DEVELOPMENT_BACKEND_PORT if not backend_dev_dir.is_empty() else DEFAULT_PUBLISHED_BACKEND_PORT

	var scheme_separator_index: int = normalized_url.find("://")
	var remainder: String = normalized_url
	if scheme_separator_index >= 0:
		remainder = normalized_url.substr(scheme_separator_index + 3)

	var slash_index: int = remainder.find("/")
	if slash_index >= 0:
		remainder = remainder.substr(0, slash_index)

	var port_text: String
	if remainder.begins_with("["):
		var bracket_index: int = remainder.find("]")
		if bracket_index >= 0 and remainder.length() > bracket_index + 2 and remainder.substr(bracket_index + 1, 1) == ":":
			port_text = remainder.substr(bracket_index + 2)
	else:
		var colon_index: int = remainder.rfind(":")
		if colon_index >= 0:
			port_text = remainder.substr(colon_index + 1)

	if port_text.is_valid_int():
		return port_text.to_int()

	if normalized_url.begins_with("wss://"):
		return 443

	return 80


func _parse_backend_url_host() -> String:
	var normalized_url: String = backend_url.strip_edges().to_lower()
	if normalized_url.is_empty():
		return "localhost"

	var scheme_separator_index: int = normalized_url.find("://")
	var remainder: String = normalized_url
	if scheme_separator_index >= 0:
		remainder = normalized_url.substr(scheme_separator_index + 3)

	var slash_index: int = remainder.find("/")
	if slash_index >= 0:
		remainder = remainder.substr(0, slash_index)

	if remainder.begins_with("["):
		var bracket_index: int = remainder.find("]")
		if bracket_index > 0:
			return remainder.substr(1, bracket_index - 1)

	var colon_index: int = remainder.rfind(":")
	if colon_index >= 0:
		return remainder.substr(0, colon_index)

	if remainder.is_empty():
		return "localhost"

	return remainder


func _get_backend_probe_hosts() -> PackedStringArray:
	var hosts: PackedStringArray
	var parsed_host: String = _parse_backend_url_host()
	_append_unique_probe_host(hosts, parsed_host)
	var normalized_host: String = parsed_host.to_lower()
	if normalized_host == "localhost" or normalized_host == "127.0.0.1" or normalized_host == "::1":
		_append_unique_probe_host(hosts, "127.0.0.1")
		_append_unique_probe_host(hosts, "::1")

	return hosts


func _append_unique_probe_host(hosts: PackedStringArray, host_name: String) -> void:
	var normalized_host: String = host_name.strip_edges()
	if normalized_host.is_empty():
		return
	if not hosts.has(normalized_host):
		hosts.append(normalized_host)


func _build_launch_command_text() -> String:
	var launch_port: int = _parse_backend_url_port()
	var global_dev_dir: String = ProjectSettings.globalize_path(backend_dev_dir)
	if not DirAccess.dir_exists_absolute(global_dev_dir):
		last_error = "Backend development directory does not exist: %s" % global_dev_dir
		launch_mode = "development"
		command_summary = "npm run dev"
		return ""

	launch_mode = "development"
	if OS.get_name() == "Windows":
		command_summary = "cd /d %s && set DAEDALUS_BACKEND_MODE=development&& set PORT=%d&& npm run dev" % [_quote_command_part(global_dev_dir), launch_port]
		return command_summary

	command_summary = "cd %s && DAEDALUS_BACKEND_MODE=development PORT=%d npm run dev" % [_quote_command_part(global_dev_dir), launch_port]
	return command_summary


func _get_backend_install_dir() -> String:
	var appdata_path: String = OS.get_environment("APPDATA").strip_edges()
	if appdata_path.is_empty():
		appdata_path = OS.get_user_data_dir()

	return appdata_path.path_join(".godot_daedalus").path_join("backend")


func _get_shell_path() -> String:
	if OS.get_name() == "Windows":
		var shell_path: String = OS.get_environment("COMSPEC").strip_edges()
		if shell_path.is_empty():
			return "cmd.exe"

		return shell_path

	return "/bin/sh"


func _get_shell_args(command_text: String) -> PackedStringArray:
	if OS.get_name() == "Windows":
		return PackedStringArray(["/d", "/s", "/c", command_text])

	return PackedStringArray(["-lc", command_text])


func _prepare_launch_log_file() -> String:
	var user_data_dir: String = _get_daedalus_log_dir()

	var make_dir_error: Error = DirAccess.make_dir_recursive_absolute(user_data_dir)
	if make_dir_error != OK:
		return ""

	var next_log_file_path: String = user_data_dir.path_join("daedalus_backend_launch_%d.log" % Time.get_ticks_msec())
	var log_file: FileAccess = FileAccess.open(next_log_file_path, FileAccess.WRITE)
	if log_file == null:
		return ""

	log_file.store_line("Daedalus backend launch log")
	log_file.store_line("Started at: %s" % Time.get_datetime_string_from_system())
	log_file.close()
	return next_log_file_path


func _get_daedalus_log_dir() -> String:
	var appdata_path: String = OS.get_environment("APPDATA").strip_edges()
	if appdata_path.is_empty():
		return OS.get_user_data_dir()

	return appdata_path.path_join(".godot_daedalus").path_join("logs")


func _get_backend_runtime_dir() -> String:
	var appdata_path: String = OS.get_environment("APPDATA").strip_edges()
	if appdata_path.is_empty():
		return OS.get_user_data_dir().path_join("backend").path_join("runtime")

	return appdata_path.path_join(".godot_daedalus").path_join("backend").path_join("runtime")


func _try_acquire_startup_lock() -> bool:
	var runtime_dir: String = _get_backend_runtime_dir()
	var make_dir_error: Error = DirAccess.make_dir_recursive_absolute(runtime_dir)
	if make_dir_error != OK:
		launch_mode = "waiting-existing"
		command_summary = "startup lock unavailable"
		last_error = "Could not prepare backend runtime directory: %s" % runtime_dir
		return false

	startup_lock_dir = runtime_dir.path_join("frontend-start.lock")
	var owner_path: String = startup_lock_dir.path_join("owner.txt")
	if DirAccess.dir_exists_absolute(startup_lock_dir):
		var modified_time: int = int(FileAccess.get_modified_time(owner_path))
		if modified_time <= 0 or Time.get_unix_time_from_system() - modified_time > STARTUP_LOCK_STALE_SECONDS:
			_remove_startup_lock(startup_lock_dir)
		else:
			launch_mode = "waiting-existing"
			command_summary = "another Daedalus plugin is starting backend"
			last_error = "Another Godot project is already starting Daedalus backend. Waiting for it to become reachable."
			return false

	var lock_error: Error = DirAccess.make_dir_absolute(startup_lock_dir)
	if lock_error != OK:
		launch_mode = "waiting-existing"
		command_summary = "another Daedalus plugin is starting backend"
		last_error = "Another Godot project is already starting Daedalus backend. Waiting for it to become reachable."
		return false

	var owner_file: FileAccess = FileAccess.open(owner_path, FileAccess.WRITE)
	if owner_file != null:
		owner_file.store_line("%d" % OS.get_process_id())
		owner_file.store_line(Time.get_datetime_string_from_system())
		owner_file.close()

	return true


func _release_startup_lock() -> void:
	if startup_lock_dir.is_empty():
		return

	_remove_startup_lock(startup_lock_dir)
	startup_lock_dir = ""


func _remove_startup_lock(lock_dir: String) -> void:
	var owner_path: String = lock_dir.path_join("owner.txt")
	if FileAccess.file_exists(owner_path):
		DirAccess.remove_absolute(owner_path)
	if DirAccess.dir_exists_absolute(lock_dir):
		DirAccess.remove_absolute(lock_dir)


func _append_log_redirection(command_text: String) -> String:
	if log_file_path.is_empty():
		return command_text

	var quoted_log_path: String = _quote_command_part(log_file_path)
	if OS.get_name() == "Windows":
		return "%s >> %s 2>&1" % [command_text, quoted_log_path]

	return "%s >> %s 2>&1" % [command_text, quoted_log_path]


func _quote_command_part(value: String) -> String:
	if value.is_empty():
		return "\"\""

	var escaped_value: String = value.replace("\"", "\\\"")
	return "\"%s\"" % escaped_value


func _stringify_output_lines(output_lines: Array) -> PackedStringArray:
	var text_lines: PackedStringArray
	for line_value: Variant in output_lines:
		text_lines.append(str(line_value).strip_edges())

	return text_lines


func _read_launch_log_file() -> void:
	if log_file_path.is_empty():
		return
	if not FileAccess.file_exists(log_file_path):
		return

	var log_file: FileAccess = FileAccess.open(log_file_path, FileAccess.READ)
	if log_file == null:
		return

	var file_length: int = log_file.get_length()
	if file_length > MAX_LOG_READ_BYTES:
		log_file.seek(file_length - MAX_LOG_READ_BYTES)

	var output_text: String = log_file.get_as_text()
	log_file.close()
	if output_text.is_empty():
		return

	recent_log_lines.clear()
	for line_text: String in output_text.replace("\r\n", "\n").replace("\r", "\n").split("\n", false):
		var trimmed_line: String = line_text.strip_edges()
		if trimmed_line.is_empty():
			continue

		recent_log_lines.append(trimmed_line)

	while recent_log_lines.size() > MAX_LOG_LINES:
		recent_log_lines.remove_at(0)
