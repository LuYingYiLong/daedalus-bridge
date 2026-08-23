@tool
extends VBoxContainer

signal reconnect_requested
signal studio_open_requested
signal diagnostics_copy_requested

const ICON_PATH: String = "res://addons/daedalus_bridge/assets/icon.svg"

@onready var icon: TextureRect = %Icon
@onready var error_value: Label = %ErrorValue

var _context_revision: int
var _bridge_version: String = "unknown"
var _godot_version: String = "unknown"
var _backend_version: String = "unknown"


func _ready() -> void:
	var icon_image: Image = Image.new()
	var load_result: Error = icon_image.load(ICON_PATH)
	if load_result != OK:
		push_warning("Daedalus Bridge icon could not be decoded (error %d)." % load_result)
		return
	icon.texture = ImageTexture.create_from_image(icon_image)


func set_error(value: String) -> void:
	error_value.text = value if not value.is_empty() else "None"
	error_value.visible = not value.is_empty()


func get_error_text() -> String:
	return error_value.text


func update_context(context: Dictionary) -> void:
	# Context updates are intentionally reduced to diagnostics metadata.  Do
	# not retain or render the full script/file payload in the dock; doing so
	# would create another large allocation on the editor's main thread.
	_context_revision = int(context.get("contextRevision", _context_revision))


func set_versions(bridge_version: String, godot_version: String, backend_version: String) -> void:
	_bridge_version = bridge_version
	_godot_version = godot_version
	_backend_version = backend_version


func get_status_text() -> String:
	return "Bridge %s · Godot %s · Backend %s · Context %d" % [
		_bridge_version,
		_godot_version,
		_backend_version,
		_context_revision,
	]


func _on_reconnect_button_pressed() -> void:
	reconnect_requested.emit()


func _on_open_studio_button_pressed() -> void:
	studio_open_requested.emit()


func _on_copy_diagnostics_button_pressed() -> void:
	diagnostics_copy_requested.emit()
