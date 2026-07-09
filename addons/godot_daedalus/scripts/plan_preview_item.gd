@tool
extends PanelContainer

signal details_requested(plan_id: String, fallback_markdown: String)

@onready var title_label: Label = $VBoxContainer/HBoxContainer/Label
@onready var markdown_label: MarkdownLabel = %MarkdownLabel

var current_plan_id: String
var current_markdown: String


func setup(plan_data: Dictionary) -> void:
	current_plan_id = str(plan_data.get("planId", "")).strip_edges()
	var title_text: String = str(plan_data.get("title", "Plan")).strip_edges()
	var markdown_text: String = str(plan_data.get("previewMarkdown", plan_data.get("markdown", ""))).strip_edges()
	if title_text.is_empty():
		title_text = "Plan"
	current_markdown = markdown_text
	title_label.text = title_text
	markdown_label.clear()
	if markdown_text.is_empty():
		markdown_label.text = "Plan is ready."
	else:
		markdown_label.append_text(markdown_text)
		markdown_label.finish_stream()


func _on_copy_button_pressed() -> void:
	DisplayServer.clipboard_set(current_markdown)


func _on_dateils_button_pressed() -> void:
	details_requested.emit(current_plan_id, current_markdown)
