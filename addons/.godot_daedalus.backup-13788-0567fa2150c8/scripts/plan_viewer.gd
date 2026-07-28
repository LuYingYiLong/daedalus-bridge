@tool
extends AcceptDialog

@onready var markdown_label: MarkdownLabel = %MarkdownLabel


func setup(title_text: String, markdown_text: String) -> void:
	var normalized_title: String = title_text.strip_edges()
	title = "Plan viewer" if normalized_title.is_empty() else normalized_title
	markdown_label.clear()
	markdown_label.append_text(markdown_text)
	markdown_label.finish_stream()
