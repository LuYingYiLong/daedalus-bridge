@tool
extends SceneTree

const INLINE_DIFF_VIEWER_SCENE: PackedScene = preload("uid://s13mo8fn3boc")

var failures: PackedStringArray
var undo_requested_count: int


func _init() -> void:
	_run_tests()
	if failures.is_empty():
		quit(0)
		return

	for failure: String in failures:
		push_error(failure)
	quit(1)


func _run_tests() -> void:
	var viewer: PanelContainer = INLINE_DIFF_VIEWER_SCENE.instantiate() as PanelContainer
	root.add_child(viewer)
	viewer.connect("undo_requested", Callable(self, "_on_undo_requested"))
	viewer.call("setup", {
		"type": "inline_diff",
		"undoable": true,
		"editedFiles": [
			{
				"displayPath": "scripts/player.gd",
				"additions": 3,
				"deletions": 2
			},
			{
				"displayPath": "scenes/main.tscn",
				"additions": 1,
				"deletions": 0
			}
		]
	})

	var edited_files_label: Label = viewer.get_node("%EditedFilesLabel") as Label
	var undo_button: Button = viewer.get_node("VBoxContainer/HBoxContainer/UndoButton") as Button
	var review_button: Button = viewer.get_node("VBoxContainer/HBoxContainer/ReviewButton") as Button
	var item_container: VBoxContainer = viewer.get_node("%ItemContainer") as VBoxContainer
	_expect_equal(edited_files_label.text, "Edited 2 files", "edited file count label")
	_expect_equal(undo_button.disabled, false, "undo button enabled")
	_expect_equal(review_button.visible, false, "review button hidden")
	_expect_equal(item_container.get_child_count(), 2, "diff item count")

	var first_item: Node = item_container.get_child(0)
	_expect_equal((first_item.get_node("%PathLabel") as Label).text, "scripts/player.gd", "first item path")
	_expect_equal((first_item.get_node("%InlineDiffLabel") as Label).text, "+3 -2", "first item diff")

	undo_button.emit_signal("pressed")
	_expect_equal(undo_requested_count, 1, "undo signal emitted")
	viewer.queue_free()


func _on_undo_requested(_summary: Dictionary) -> void:
	undo_requested_count += 1


func _expect_equal(actual_value: Variant, expected_value: Variant, label_text: String) -> void:
	if actual_value == expected_value:
		return

	failures.append("%s: expected %s, got %s" % [label_text, str(expected_value), str(actual_value)])
