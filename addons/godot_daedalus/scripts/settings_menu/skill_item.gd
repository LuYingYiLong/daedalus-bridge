@tool
extends MarginContainer

signal edit_requested(skill_ref: String)
signal remove_requested(skill_ref: String, skill_name: String)
signal enabled_changed(skill_ref: String, enabled: bool)

@onready var skill_button: Button = %Button
@onready var remove_button: Button = %RemoveButton
@onready var edit_button: Button = %EditButton
@onready var disable_check_button: CheckButton = %DisableCheckButton

var skill_ref: String
var skill_name: String
var updating_state: bool


func _ready() -> void:
	if not edit_button.pressed.is_connected(_on_edit_button_pressed):
		edit_button.pressed.connect(_on_edit_button_pressed)
	if not remove_button.pressed.is_connected(_on_remove_button_pressed):
		remove_button.pressed.connect(_on_remove_button_pressed)
	if not disable_check_button.toggled.is_connected(_on_enabled_toggled):
		disable_check_button.toggled.connect(_on_enabled_toggled)


func setup(metadata: Dictionary) -> void:
	skill_ref = str(metadata.get("ref", ""))
	skill_name = str(metadata.get("name", skill_ref))
	var description_text: String = str(metadata.get("description", "")).strip_edges()
	var source_text: String = str(metadata.get("source", ""))
	var valid: bool = bool(metadata.get("valid", false))
	var error_text: String = str(metadata.get("error", "")).strip_edges()
	var status_text: String = "%s [%s]" % [skill_name, source_text]
	if not valid:
		status_text += " - Invalid"
	skill_button.text = status_text
	skill_button.tooltip_text = error_text if not error_text.is_empty() else description_text
	edit_button.visible = bool(metadata.get("editable", false))
	edit_button.disabled = false
	edit_button.tooltip_text = "Edit SKILL.md"
	remove_button.visible = bool(metadata.get("removable", false))
	remove_button.disabled = false
	remove_button.tooltip_text = "Remove personal skill"
	updating_state = true
	disable_check_button.button_pressed = bool(metadata.get("enabled", false))
	disable_check_button.disabled = not valid
	disable_check_button.tooltip_text = "Enable skill discovery for this workspace"
	updating_state = false


func _on_edit_button_pressed() -> void:
	edit_requested.emit(skill_ref)


func _on_remove_button_pressed() -> void:
	remove_requested.emit(skill_ref, skill_name)


func _on_enabled_toggled(enabled: bool) -> void:
	if updating_state:
		return
	enabled_changed.emit(skill_ref, enabled)
