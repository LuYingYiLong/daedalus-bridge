@tool
class_name DaedalusBackendConnectionController
extends Node

signal connected
signal disconnected(close_code: int, close_reason: String)
signal message_received(message: Dictionary)
signal protocol_error(message: String)

const MAX_MESSAGES_PER_FRAME: int = 24
const MAX_MESSAGE_PROCESS_MSEC: int = 6

var _socket: WebSocketPeer = WebSocketPeer.new()
var _request_id: int
var _was_open: bool


func connect_to_backend(url: String, buffer_size: int, auth_protocol: String = "") -> Error:
	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()
	_socket = WebSocketPeer.new()
	_socket.inbound_buffer_size = buffer_size
	_socket.outbound_buffer_size = buffer_size
	_socket.supported_protocols = PackedStringArray([auth_protocol]) if not auth_protocol.is_empty() else PackedStringArray()
	_was_open = false
	return _socket.connect_to_url(url)


func poll() -> void:
	_socket.poll()
	var socket_state: WebSocketPeer.State = _socket.get_ready_state()
	if socket_state == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			connected.emit()
		_receive_messages()
	elif socket_state == WebSocketPeer.STATE_CLOSED and _was_open:
		_was_open = false
		disconnected.emit(_socket.get_close_code(), _socket.get_close_reason())


func send_request(method: String, params: Dictionary, id_prefix: String) -> String:
	if not is_open():
		return ""
	_request_id += 1
	var request_key: String = "%s-%d" % [id_prefix, _request_id]
	var payload: Dictionary = {
		"protocolVersion": 3,
		"type": "request",
		"id": request_key,
		"method": method,
		"params": params
	}
	var send_error: Error = _socket.send_text(JSON.stringify(payload))
	if send_error != OK:
		protocol_error.emit("Failed to send request: %s" % error_string(send_error))
		return ""
	return request_key


func send_json(payload: Dictionary) -> Error:
	if not is_open():
		return ERR_UNAVAILABLE
	var envelope: Dictionary = payload.duplicate(true)
	envelope["protocolVersion"] = 3
	return _socket.send_text(JSON.stringify(envelope))


func is_open() -> bool:
	return _socket.get_ready_state() == WebSocketPeer.STATE_OPEN


func is_closed() -> bool:
	return _socket.get_ready_state() == WebSocketPeer.STATE_CLOSED


func get_close_code() -> int:
	return _socket.get_close_code()


func get_close_reason() -> String:
	return _socket.get_close_reason()


func shutdown() -> void:
	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()
	_was_open = false


func _receive_messages() -> void:
	var processed_count: int
	var started_at_msec: int = Time.get_ticks_msec()
	while _socket.get_available_packet_count() > 0:
		if processed_count >= MAX_MESSAGES_PER_FRAME:
			break
		if Time.get_ticks_msec() - started_at_msec >= MAX_MESSAGE_PROCESS_MSEC:
			break
		var packet: PackedByteArray = _socket.get_packet()
		processed_count += 1
		if not _socket.was_string_packet():
			protocol_error.emit("Backend sent a non-text WebSocket packet.")
			continue
		var parsed_value: Variant = JSON.parse_string(packet.get_string_from_utf8())
		if typeof(parsed_value) != TYPE_DICTIONARY:
			protocol_error.emit("Backend sent invalid JSON-RPC data.")
			continue
		var message: Dictionary = parsed_value as Dictionary
		if str(message.get("type", "")) == "event" and not _is_v3_event_envelope(message):
			protocol_error.emit("Backend sent an invalid v3 event envelope. Update Daedalus Studio, the backend, and this plugin together.")
			continue
		message_received.emit(message)


func _is_v3_event_envelope(message: Dictionary) -> bool:
	var sequence_type: int = typeof(message.get("sequence"))
	return int(message.get("protocolVersion", 0)) == 3 \
		and not str(message.get("eventId", "")).is_empty() \
		and not str(message.get("event", "")).is_empty() \
		and message.has("sessionId") \
		and not str(message.get("requestId", "")).is_empty() \
		and not str(message.get("runId", "")).is_empty() \
		and (sequence_type == TYPE_FLOAT or sequence_type == TYPE_INT) \
		and not str(message.get("createdAt", "")).is_empty()
