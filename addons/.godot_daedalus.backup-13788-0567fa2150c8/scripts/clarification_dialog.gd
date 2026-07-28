@tool
extends PanelContainer

signal clarification_submitted(plan_id: String, reply: String)

@onready var question_label: Label = %QuestionLabel
@onready var recommend_reply_button: Button = %RecommendReplyButton
@onready var reply2_button: Button = %Reply2Button
@onready var reply3_button: Button = %Reply3Button
@onready var text_edit: TextEdit = %TextEdit
@onready var send_button: Button = %SendButton

var current_plan_id: String
var reply_texts: PackedStringArray


func _ready() -> void:
	visible = false
	if not recommend_reply_button.pressed.is_connected(_on_reply_button_pressed.bind(0)):
		recommend_reply_button.pressed.connect(_on_reply_button_pressed.bind(0))
	if not reply2_button.pressed.is_connected(_on_reply_button_pressed.bind(1)):
		reply2_button.pressed.connect(_on_reply_button_pressed.bind(1))
	if not reply3_button.pressed.is_connected(_on_reply_button_pressed.bind(2)):
		reply3_button.pressed.connect(_on_reply_button_pressed.bind(2))
	if not text_edit.text_changed.is_connected(_on_text_edit_text_changed):
		text_edit.text_changed.connect(_on_text_edit_text_changed)
	if not send_button.pressed.is_connected(_on_send_button_pressed):
		send_button.pressed.connect(_on_send_button_pressed)
	_update_send_state()


func setup(question: String, replies: Array, plan_id: String) -> void:
	current_plan_id = plan_id
	question_label.text = question.strip_edges()
	reply_texts.clear()
	text_edit.clear()

	var buttons: Array[Button] = [
		recommend_reply_button,
		reply2_button,
		reply3_button
	]
	for index: int in range(buttons.size()):
		var button: Button = buttons[index]
		reply_texts.append("")
		if index >= replies.size() or typeof(replies[index]) != TYPE_DICTIONARY:
			button.hide()
			button.disabled = true
			continue

		var reply: Dictionary = replies[index] as Dictionary
		var label_text: String = str(reply.get("label", "")).strip_edges()
		var reply_text: String = str(reply.get("text", "")).strip_edges()
		var description_text: String = str(reply.get("description", "")).strip_edges()
		if label_text.is_empty():
			label_text = reply_text
		if index == 0:
			label_text = "%s (Recommended)" % label_text
		reply_texts[index] = reply_text
		button.text = label_text
		button.tooltip_text = description_text if not description_text.is_empty() else reply_text
		button.disabled = reply_text.is_empty()
		button.show()

	_update_send_state()
	show()


func _on_reply_button_pressed(index: int) -> void:
	if index < 0 or index >= reply_texts.size():
		return

	_submit_reply(reply_texts[index])


func _on_send_button_pressed() -> void:
	_submit_reply(text_edit.text.strip_edges())


func _on_text_edit_text_changed() -> void:
	_update_send_state()


func _submit_reply(reply: String) -> void:
	var normalized_reply: String = reply.strip_edges()
	if current_plan_id.is_empty() or normalized_reply.is_empty():
		return

	hide()
	text_edit.clear()
	clarification_submitted.emit(current_plan_id, normalized_reply)


func _update_send_state() -> void:
	send_button.disabled = text_edit.text.strip_edges().is_empty()
