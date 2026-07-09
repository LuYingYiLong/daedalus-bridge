@tool
extends PanelContainer

signal plan_approved(plan_id: String)
signal plan_revision_requested(plan_id: String, feedback: String)

@onready var approve_button: Button = %RecommendReplyButton
@onready var text_edit: TextEdit = %TextEdit
@onready var send_button: Button = %SendButton

var current_plan_id: String


func _ready() -> void:
	visible = false
	if not approve_button.pressed.is_connected(_on_approve_button_pressed):
		approve_button.pressed.connect(_on_approve_button_pressed)
	if not text_edit.text_changed.is_connected(_on_text_edit_text_changed):
		text_edit.text_changed.connect(_on_text_edit_text_changed)
	if not send_button.pressed.is_connected(_on_send_button_pressed):
		send_button.pressed.connect(_on_send_button_pressed)
	_update_send_state()


func setup(plan_id: String, title: String = "") -> void:
	current_plan_id = plan_id
	text_edit.clear()
	var normalized_title: String = title.strip_edges()
	approve_button.text = "Yes, execute this plan"
	approve_button.tooltip_text = normalized_title
	approve_button.disabled = current_plan_id.is_empty()
	_update_send_state()
	show()


func _on_approve_button_pressed() -> void:
	if current_plan_id.is_empty():
		return

	hide()
	plan_approved.emit(current_plan_id)


func _on_send_button_pressed() -> void:
	var feedback: String = text_edit.text.strip_edges()
	if current_plan_id.is_empty() or feedback.is_empty():
		return

	hide()
	text_edit.clear()
	plan_revision_requested.emit(current_plan_id, feedback)


func _on_text_edit_text_changed() -> void:
	_update_send_state()


func _update_send_state() -> void:
	send_button.disabled = text_edit.text.strip_edges().is_empty()
