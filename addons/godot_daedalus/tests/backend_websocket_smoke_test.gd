@tool
extends SceneTree

const DEFAULT_BACKEND_URL: String = "ws://localhost:38180"
const CONNECT_TIMEOUT_MSEC: int = 5000
const POLL_DELAY_MSEC: int = 50

var socket: WebSocketPeer = WebSocketPeer.new()


func _init() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var backend_url: String = OS.get_environment("DAEDALUS_TEST_BACKEND_URL").strip_edges()
	if backend_url.is_empty():
		backend_url = DEFAULT_BACKEND_URL

	var connect_error: Error = socket.connect_to_url(backend_url)
	if connect_error != OK:
		push_error("Failed to start WebSocket connection: %s" % error_string(connect_error))
		quit(1)
		return

	var request_sent: bool
	var deadline_msec: int = Time.get_ticks_msec() + CONNECT_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline_msec:
		socket.poll()
		var socket_state: WebSocketPeer.State = socket.get_ready_state()
		if socket_state == WebSocketPeer.STATE_OPEN and not request_sent:
			var request_payload: Dictionary = {
				"id": "backend-health-smoke",
				"method": "backend.health",
				"params": {}
			}
			socket.send_text(JSON.stringify(request_payload))
			request_sent = true

		while socket.get_available_packet_count() > 0:
			var response_text: String = socket.get_packet().get_string_from_utf8()
			var parsed_response: Variant = JSON.parse_string(response_text)
			if typeof(parsed_response) != TYPE_DICTIONARY:
				push_error("Backend returned non-object response: %s" % response_text)
				quit(1)
				return

			var response_dictionary: Dictionary = parsed_response as Dictionary
			if str(response_dictionary.get("id", "")) != "backend-health-smoke":
				continue

			var result_value: Variant = response_dictionary.get("result", {})
			if not bool(response_dictionary.get("ok", false)) or typeof(result_value) != TYPE_DICTIONARY:
				push_error("Backend health failed: %s" % response_text)
				quit(1)
				return

			var result_dictionary: Dictionary = result_value as Dictionary
			if str(result_dictionary.get("name", "")) != "godot-daedalus-backend":
				push_error("Unexpected backend health name: %s" % response_text)
				quit(1)
				return

			quit(0)
			return

		if socket_state == WebSocketPeer.STATE_CLOSED:
			push_error("WebSocket closed before backend.health completed.")
			quit(1)
			return

		OS.delay_msec(POLL_DELAY_MSEC)

	push_error("Timed out waiting for backend.health.")
	quit(1)
