@tool
extends VBoxContainer

signal reconnect_requested
signal studio_open_requested
signal diagnostics_copy_requested

@onready var error_value: Label = %ErrorValue


func set_error(value: String) -> void:
	error_value.text = value if not value.is_empty() else "None"
	error_value.visible = not value.is_empty()


func get_error_text() -> String:
	return error_value.text


func _on_reconnect_button_pressed() -> void:
	reconnect_requested.emit()


func _on_open_studio_button_pressed() -> void:
	studio_open_requested.emit()


func _on_copy_diagnostics_button_pressed() -> void:
	diagnostics_copy_requested.emit()
