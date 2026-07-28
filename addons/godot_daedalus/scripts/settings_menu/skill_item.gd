@tool
extends PanelContainer

signal edit_requested(skill_ref: String)
signal remove_requested(skill_ref: String, skill_name: String)
signal enabled_changed(skill_ref: String, enabled: bool)

@onready var name_label: Label = %NameLabel
@onready var description_label: Label = %DescriptionLabel
@onready var source_label: Label = %SourceLabel
@onready var status_label: Label = %StatusLabel
@onready var remove_button: Button = %RemoveButton
@onready var edit_button: Button = %EditButton
@onready var enabled_check_button: CheckButton = %EnabledCheckButton

var skill_ref: String
var skill_name: String
var updating_state: bool


func _ready() -> void:
	if not edit_button.pressed.is_connected(_on_edit_button_pressed):
		edit_button.pressed.connect(_on_edit_button_pressed)
	if not remove_button.pressed.is_connected(_on_remove_button_pressed):
		remove_button.pressed.connect(_on_remove_button_pressed)
	if not enabled_check_button.toggled.is_connected(_on_enabled_toggled):
		enabled_check_button.toggled.connect(_on_enabled_toggled)


func setup(metadata: Dictionary) -> void:
	skill_ref = str(metadata.get("ref", ""))
	skill_name = str(metadata.get("name", skill_ref))
	var description_text: String = str(metadata.get("description", "")).strip_edges()
	var source_text: String = str(metadata.get("source", ""))
	var valid: bool = bool(metadata.get("valid", false))
	var error_text: String = str(metadata.get("error", "")).strip_edges()

	name_label.text = skill_name
	description_label.text = description_text if not description_text.is_empty() else "No description"
	description_label.tooltip_text = error_text if not error_text.is_empty() else description_text
	source_label.text = source_text.capitalize()
	status_label.text = "Ready" if valid else "Invalid"
	status_label.tooltip_text = error_text
	edit_button.visible = bool(metadata.get("editable", false))
	edit_button.disabled = not valid
	edit_button.tooltip_text = "Edit SKILL.md"
	remove_button.visible = bool(metadata.get("removable", false))
	remove_button.disabled = false
	remove_button.tooltip_text = "Remove personal skill"
	updating_state = true
	enabled_check_button.button_pressed = bool(metadata.get("enabled", false))
	enabled_check_button.disabled = not valid
	enabled_check_button.tooltip_text = "Enable this skill for the current workspace"
	updating_state = false


func _on_edit_button_pressed() -> void:
	edit_requested.emit(skill_ref)


func _on_remove_button_pressed() -> void:
	remove_requested.emit(skill_ref, skill_name)


func _on_enabled_toggled(enabled: bool) -> void:
	if not updating_state:
		enabled_changed.emit(skill_ref, enabled)
