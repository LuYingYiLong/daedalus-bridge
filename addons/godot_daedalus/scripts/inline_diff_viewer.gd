@tool
extends PanelContainer

signal undo_requested(summary: Dictionary)
signal review_requested(summary: Dictionary)

const INLINE_DIFF_ITEM_SCENE: PackedScene = preload("res://addons/godot_daedalus/scenes/inline_diff_item.tscn")

@onready var edited_files_label: Label = %EditedFilesLabel
@onready var foldable_container: FoldableContainer = %FoldableContainer
@onready var item_container: VBoxContainer = %ItemContainer
@onready var undo_button: Button = $VBoxContainer/HBoxContainer/UndoButton
@onready var review_button: Button = $VBoxContainer/HBoxContainer/ReviewButton

var current_summary: Dictionary


func _ready() -> void:
	review_button.visible = false


func _on_undo_button_pressed() -> void:
	if current_summary.is_empty() or undo_button.disabled:
		return

	undo_requested.emit(current_summary.duplicate(true))


func _on_review_button_pressed() -> void:
	if current_summary.is_empty():
		return

	review_requested.emit(current_summary.duplicate(true))


func setup(summary: Dictionary) -> void:
	current_summary = summary.duplicate(true)
	for child: Node in item_container.get_children():
		child.queue_free()

	var files: Array[Dictionary] = _get_edited_files(current_summary)
	var file_count: int = files.size()
	edited_files_label.text = "Edited %d file%s" % [file_count, "" if file_count == 1 else "s"]
	undo_button.disabled = file_count == 0 or not bool(current_summary.get("undoable", true))

	for file_summary: Dictionary in files:
		var item: Node = INLINE_DIFF_ITEM_SCENE.instantiate()
		item_container.add_child(item)
		item.call(
			"setup",
			str(file_summary.get("displayPath", file_summary.get("path", ""))),
			int(file_summary.get("additions", 0)),
			int(file_summary.get("deletions", 0))
		)


func set_undo_available(is_available: bool, tooltip_text: String = "") -> void:
	undo_button.disabled = not is_available
	undo_button.tooltip_text = tooltip_text


func mark_undone() -> void:
	undo_button.disabled = true
	undo_button.text = "Undone"


func _get_edited_files(summary: Dictionary) -> Array[Dictionary]:
	var files: Array[Dictionary] = []
	var files_value: Variant = summary.get("editedFiles", [])
	if typeof(files_value) != TYPE_ARRAY:
		return files

	for file_value: Variant in files_value as Array:
		if typeof(file_value) != TYPE_DICTIONARY:
			continue

		files.append((file_value as Dictionary).duplicate(true))

	return files
