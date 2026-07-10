@tool
extends SceneTree

const MAIN_SCRIPT: GDScript = preload("uid://c20c3llfub24q")
const FILE_EDIT_CONTROLLER_SCRIPT: GDScript = preload("res://addons/godot_daedalus/scripts/controllers/daedalus_file_edit_controller.gd")

var failures: PackedStringArray
var captured_inline_diff_summary: Dictionary


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
	var file_edit_controller: Node = FILE_EDIT_CONTROLLER_SCRIPT.new() as Node
	file_edit_controller.connect("inline_diff_ready", _on_inline_diff_ready)
	_test_display_path(file_edit_controller)
	_test_inline_diff_flushes_active_batches(file_edit_controller)
	_test_failed_message_body_parts(main_node)
	_test_orphan_error_event_creates_assistant_entry(main_node)
	_test_overwrite_restore(file_edit_controller)
	_test_create_delete_restore(file_edit_controller)
	file_edit_controller.free()
	main_node.free()


func _test_display_path(file_edit_controller: Node) -> void:
	var display_path: String = str(file_edit_controller.call("format_display_path", {
		"path": "scripts/player.gd",
		"absolutePath": "D:/Project/scripts/player.gd",
		"workspaceRoot": "D:/Project"
	}))
	_expect_equal(display_path, "scripts/player.gd", "workspace relative display path")

	var external_path: String = str(file_edit_controller.call("format_display_path", {
		"path": "",
		"absolutePath": "D:/Outside/file.gd",
		"workspaceRoot": "D:/Project"
	}))
	_expect_equal(external_path, "D:/Outside/file.gd", "external absolute display path")


func _test_inline_diff_flushes_active_batches(file_edit_controller: Node) -> void:
	captured_inline_diff_summary.clear()
	file_edit_controller.call("set_active_session_id", "session-inline-diff")
	var batch: Dictionary = {
		"batchId": "batch-inline-diff",
		"editedFiles": [{
			"path": "scripts/player.gd",
			"absolutePath": "D:/Project/scripts/player.gd",
			"workspaceRoot": "D:/Project",
			"additions": 3,
			"deletions": 2,
			"existsAfter": true,
			"afterSha256": "after-hash",
			"undoable": true
		}]
	}
	file_edit_controller.call("collect_active_batch", { "fileEditBatch": batch })
	file_edit_controller.call("complete_stream", "assistant-inline-diff")
	if captured_inline_diff_summary.is_empty():
		failures.append("inline diff flush did not append body part")
		return

	var inline_part: Dictionary = captured_inline_diff_summary
	_expect_equal(str(inline_part.get("type", "")), "inline_diff", "inline diff body part type")
	_expect_equal(str(inline_part.get("sessionId", "")), "session-inline-diff", "inline diff session id")
	_expect_equal(int(inline_part.get("editedFileCount", 0)), 1, "inline diff edited file count")
	_expect_equal(int(inline_part.get("additions", 0)), 3, "inline diff additions")
	_expect_equal(int(inline_part.get("deletions", 0)), 2, "inline diff deletions")

	var batch_ids: Array = inline_part.get("batchIds", []) as Array
	if batch_ids.is_empty():
		failures.append("inline diff batch ids missing")
	else:
		_expect_equal(str(batch_ids[0]), "batch-inline-diff", "inline diff batch id")

	var edited_files: Array = inline_part.get("editedFiles", []) as Array
	if edited_files.is_empty():
		failures.append("inline diff edited files missing")
		return

	var edited_file: Dictionary = edited_files[0] as Dictionary
	_expect_equal(str(edited_file.get("displayPath", "")), "scripts/player.gd", "inline diff display path")


func _test_failed_message_body_parts(main_node: VBoxContainer) -> void:
	var file_edit_batch: Dictionary = {
		"batchId": "batch-failed",
		"editedFiles": [{
			"path": "scripts/player.gd",
			"absolutePath": "D:/Project/scripts/player.gd",
			"workspaceRoot": "D:/Project",
			"additions": 4,
			"deletions": 1,
			"existsAfter": true,
			"afterSha256": "after-failed",
			"undoable": true
		}]
	}
	var records: Array = [
		{
			"id": "event-delta",
			"requestId": "request-failed",
			"event": "ai.delta",
			"createdAt": "2026-07-08T00:00:00.000Z",
			"data": { "type": "ai.delta", "text": "准备修改脚本。" }
		},
		{
			"id": "event-tool",
			"requestId": "request-failed",
			"event": "agent.tool.result",
			"createdAt": "2026-07-08T00:00:01.000Z",
			"data": {
				"type": "agent.tool.result",
				"toolCallId": "tool-1",
				"toolName": "mcp_godot_overwrite_text_file",
				"fileEditBatch": file_edit_batch
			}
		},
		{
			"id": "event-error",
			"requestId": "request-failed",
			"event": "agent.run.error",
			"createdAt": "2026-07-08T00:00:02.000Z",
			"data": {
				"type": "agent.run.error",
				"code": "agent_run_error",
				"message": "总结阶段不能调用工具"
			}
		}
	]
	var failed_message: Dictionary = {
		"role": "assistant",
		"status": "failed",
		"error": {
			"code": "fallback_error",
			"message": "不应重复显示"
		}
	}
	var body_parts: Array = main_node.call(
		"_build_assistant_body_parts",
		records,
		"",
		"request-failed",
		failed_message
	) as Array
	_expect_equal(body_parts.size(), 4, "failed body part count")
	_expect_equal(str((body_parts[0] as Dictionary).get("type", "")), "markdown", "failed markdown part")
	_expect_equal(str((body_parts[1] as Dictionary).get("type", "")), "tool", "failed tool part")
	_expect_equal(str((body_parts[2] as Dictionary).get("type", "")), "status", "failed status part")
	_expect_equal(str((body_parts[2] as Dictionary).get("details", "")), "总结阶段不能调用工具", "failed status details")
	_expect_equal(str((body_parts[3] as Dictionary).get("type", "")), "inline_diff", "failed inline diff last")


func _test_orphan_error_event_creates_assistant_entry(main_node: VBoxContainer) -> void:
	var before_count: int = (main_node.get("timeline_entries") as Array).size()
	var records: Array = [{
		"id": "event-orphan-error",
		"requestId": "request-orphan-failed",
		"event": "agent.run.error",
		"createdAt": "2026-07-08T00:01:00.000Z",
		"data": {
			"type": "agent.run.error",
			"code": "agent_run_error",
			"message": "旧会话错误"
		}
	}]
	main_node.call("_append_orphan_event_records", records)

	var timeline_entries: Array = main_node.get("timeline_entries") as Array
	_expect_equal(timeline_entries.size(), before_count + 1, "orphan error assistant entry count")
	var entry: Dictionary = timeline_entries[timeline_entries.size() - 1] as Dictionary
	_expect_equal(str(entry.get("type", "")), "assistant", "orphan error entry type")
	var body_parts: Array = entry.get("body_parts", []) as Array
	if body_parts.is_empty():
		failures.append("orphan error body parts missing")
		return

	var status_part: Dictionary = body_parts[body_parts.size() - 1] as Dictionary
	_expect_equal(str(status_part.get("type", "")), "status", "orphan error status type")
	_expect_equal(str(status_part.get("details", "")), "旧会话错误", "orphan error details")


func _test_overwrite_restore(file_edit_controller: Node) -> void:
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
	_expect_equal(bool(file_edit_controller.call("is_group_current", edits, true)), true, "after hash matches")
	file_edit_controller.call("apply_snapshots", edits, false)
	_expect_equal(_read_text(file_path), "old\n", "overwrite undo restores before")
	_expect_equal(bool(file_edit_controller.call("is_group_current", edits, false)), true, "before hash matches")
	file_edit_controller.call("apply_snapshots", edits, true)
	_expect_equal(_read_text(file_path), "new\n", "overwrite redo restores after")
	DirAccess.remove_absolute(file_path)


func _test_create_delete_restore(file_edit_controller: Node) -> void:
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
	file_edit_controller.call("apply_snapshots", edits, true)
	_expect_equal(_read_text(file_path), "created\n", "create apply writes file")
	file_edit_controller.call("apply_snapshots", edits, false)
	_expect_equal(FileAccess.file_exists(file_path), false, "create undo deletes file")


func _on_inline_diff_ready(_entry_id: String, summary: Dictionary) -> void:
	captured_inline_diff_summary = summary.duplicate(true)


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
