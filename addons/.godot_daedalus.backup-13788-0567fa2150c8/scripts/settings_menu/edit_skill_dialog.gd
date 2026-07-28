@tool
extends ConfirmationDialog

signal save_requested(skill_ref: String, content: String)

@onready var skill_description_label: Label = %SkillDescriptionLabel
@onready var text_edit: TextEdit = %TextEdit

var skill_ref: String


func _ready() -> void:
	if not confirmed.is_connected(_on_confirmed):
		confirmed.connect(_on_confirmed)


func setup(next_skill_ref: String, skill_name: String, content: String) -> void:
	skill_ref = next_skill_ref
	title = "Edit skill"
	skill_description_label.text = "%s\n%s" % [skill_name, next_skill_ref]
	text_edit.text = content
	text_edit.grab_focus.call_deferred()


func show_error(message_text: String) -> void:
	skill_description_label.text = "%s\nError: %s" % [skill_ref, message_text]


func _on_confirmed() -> void:
	var content: String = text_edit.text
	if content.strip_edges().is_empty():
		show_error("SKILL.md cannot be empty.")
		popup_centered()
		return
	save_requested.emit(skill_ref, content)
