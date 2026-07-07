@tool
extends SceneTree

const MAIN_SCRIPT: GDScript = preload("uid://c20c3llfub24q")

var failures: PackedStringArray


func _init() -> void:
	_run_tests()
	if failures.is_empty():
		quit(0)
		return

	for failure: String in failures:
		push_error(failure)
	quit(1)


func _run_tests() -> void:
	var main_node: VBoxContainer = MAIN_SCRIPT.new() as VBoxContainer
	_test_display_path(main_node)
	_test_overwrite_restore(main_node)
	_test_create_delete_restore(main_node)
	main_node.free()


func _test_display_path(main_node: VBoxContainer) -> void:
	var display_path: String = str(main_node.call("_format_file_edit_display_path", {
		"path": "scripts/player.gd",
		"absolutePath": "D:/Project/scripts/player.gd",
		"workspaceRoot": "D:/Project"
	}))
	_expect_equal(display_path, "scripts/player.gd", "workspace relative display path")

	var external_path: String = str(main_node.call("_format_file_edit_display_path", {
		"path": "",
		"absolutePath": "D:/Outside/file.gd",
		"workspaceRoot": "D:/Project"
	}))
	_expect_equal(external_path, "D:/Outside/file.gd", "external absolute display path")


func _test_overwrite_restore(main_node: VBoxContainer) -> void:
	var file_path: String = ProjectSettings.globalize_path("user://daedalus_inline_diff_overwrite_test.gd")
	_write_text(file_path, "new\n")
	var edit: Dictionary = {
		"path": "scripts/player.gd",
		"absolutePath": file_path,
		"workspaceRoot": ProjectSettings.globalize_path("res://"),
		"existedBefore": true,
		"existsAfter": true,
		"beforeText": "old\n",
		"afterText": "new\n",
		"beforeSha256": "old\n".sha256_text(),
		"afterSha256": "new\n".sha256_text(),
		"undoable": true
	}
	var edits: Array[Dictionary] = [edit]
	_expect_equal(bool(main_node.call("_is_file_edit_group_current", edits, true)), true, "after hash matches")
	main_node.call("_apply_file_edit_snapshots", edits, false)
	_expect_equal(_read_text(file_path), "old\n", "overwrite undo restores before")
	_expect_equal(bool(main_node.call("_is_file_edit_group_current", edits, false)), true, "before hash matches")
	main_node.call("_apply_file_edit_snapshots", edits, true)
	_expect_equal(_read_text(file_path), "new\n", "overwrite redo restores after")
	DirAccess.remove_absolute(file_path)


func _test_create_delete_restore(main_node: VBoxContainer) -> void:
	var file_path: String = ProjectSettings.globalize_path("user://daedalus_inline_diff_create_test.gd")
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)

	var edit: Dictionary = {
		"path": "scripts/new_file.gd",
		"absolutePath": file_path,
		"workspaceRoot": ProjectSettings.globalize_path("res://"),
		"existedBefore": false,
		"existsAfter": true,
		"afterText": "created\n",
		"afterSha256": "created\n".sha256_text(),
		"undoable": true
	}
	var edits: Array[Dictionary] = [edit]
	main_node.call("_apply_file_edit_snapshots", edits, true)
	_expect_equal(_read_text(file_path), "created\n", "create apply writes file")
	main_node.call("_apply_file_edit_snapshots", edits, false)
	_expect_equal(FileAccess.file_exists(file_path), false, "create undo deletes file")


func _write_text(file_path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		failures.append("failed to open file for write: %s" % file_path)
		return
	file.store_string(text)


func _read_text(file_path: String) -> String:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		failures.append("failed to open file for read: %s" % file_path)
		return ""
	return file.get_as_text()


func _expect_equal(actual_value: Variant, expected_value: Variant, label_text: String) -> void:
	if actual_value == expected_value:
		return

	failures.append("%s: expected %s, got %s" % [label_text, str(expected_value), str(actual_value)])
