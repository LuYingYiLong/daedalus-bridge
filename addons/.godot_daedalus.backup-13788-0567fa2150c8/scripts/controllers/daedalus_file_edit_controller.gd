@tool
class_name DaedalusFileEditController
extends Node

signal request_ready(params: Dictionary, group_id: String)
signal inline_diff_ready(entry_id: String, summary: Dictionary)

var editor_bridge_controller: DaedalusEditorBridgeController
var active_file_edit_batches: Array[Dictionary]
var pending_file_edit_batch_requests: Dictionary[String, String]
var pending_file_edit_batch_groups: Dictionary[String, Dictionary]
var inline_diff_action_titles_by_key: Dictionary[String, String]
var active_session_id: String


func setup(editor_bridge: DaedalusEditorBridgeController) -> void:
	editor_bridge_controller = editor_bridge


func set_active_session_id(session_id: String) -> void:
	active_session_id = session_id


func clear_active_batches() -> void:
	active_file_edit_batches.clear()


func register_batch_request(group_id: String, request_id: String) -> void:
	if group_id.is_empty() or request_id.is_empty():
		return
	pending_file_edit_batch_requests[request_id] = group_id
	var group: Dictionary = pending_file_edit_batch_groups.get(group_id, {}) as Dictionary
	if group.is_empty():
		return
	group["remaining"] = int(group.get("remaining", 0)) + 1
	pending_file_edit_batch_groups[group_id] = group


func append_batch_from_event(file_edit_batches: Array[Dictionary], event_data: Dictionary) -> void:
	var batch_value: Variant = event_data.get("fileEditBatch", {})
	if typeof(batch_value) != TYPE_DICTIONARY:
		return

	var batch: Dictionary = (batch_value as Dictionary).duplicate(true)
	if str(batch.get("batchId", "")).is_empty():
		return

	file_edit_batches.append(batch)


func collect_active_batch(event_data: Dictionary) -> void:
	append_batch_from_event(active_file_edit_batches, event_data)


func create_inline_diff_summary(file_edit_batches: Array[Dictionary]) -> Dictionary:
	if file_edit_batches.is_empty():
		return {}

	var batch_ids: Array[String] = []
	var edited_files_by_key: Dictionary = {}
	var edited_file_keys: PackedStringArray
	var is_undoable: bool = true
	for batch: Dictionary in file_edit_batches:
		var batch_id: String = str(batch.get("batchId", ""))
		if batch_id.is_empty() or batch_ids.has(batch_id):
			continue
		batch_ids.append(batch_id)

		var files_value: Variant = batch.get("editedFiles", [])
		if typeof(files_value) != TYPE_ARRAY:
			continue

		for file_value: Variant in files_value as Array:
			if typeof(file_value) != TYPE_DICTIONARY:
				continue

			var file_summary: Dictionary = (file_value as Dictionary).duplicate(true)
			var file_key: String = _get_file_edit_key(file_summary)
			if file_key.is_empty():
				continue

			var file_additions: int = int(file_summary.get("additions", 0))
			var file_deletions: int = int(file_summary.get("deletions", 0))
			if not edited_files_by_key.has(file_key):
				file_summary["displayPath"] = format_display_path(file_summary)
				file_summary["additions"] = 0
				file_summary["deletions"] = 0
				edited_files_by_key[file_key] = file_summary
				edited_file_keys.append(file_key)

			var merged_file: Dictionary = edited_files_by_key[file_key] as Dictionary
			merged_file["additions"] = int(merged_file.get("additions", 0)) + file_additions
			merged_file["deletions"] = int(merged_file.get("deletions", 0)) + file_deletions
			merged_file["existsAfter"] = bool(file_summary.get("existsAfter", merged_file.get("existsAfter", false)))
			merged_file["afterSha256"] = str(file_summary.get("afterSha256", merged_file.get("afterSha256", "")))
			merged_file["undoable"] = bool(merged_file.get("undoable", true)) and bool(file_summary.get("undoable", true))
			edited_files_by_key[file_key] = merged_file

	var edited_files: Array[Dictionary] = []
	var total_additions: int = 0
	var total_deletions: int = 0
	for file_key: String in edited_file_keys:
		var edited_file: Dictionary = edited_files_by_key[file_key] as Dictionary
		total_additions += int(edited_file.get("additions", 0))
		total_deletions += int(edited_file.get("deletions", 0))
		if not bool(edited_file.get("undoable", true)):
			is_undoable = false
		edited_files.append(edited_file)

	if batch_ids.is_empty() or edited_files.is_empty():
		return {}

	return {
		"type": "inline_diff",
		"sessionId": active_session_id,
		"batchIds": batch_ids,
		"editedFileCount": edited_files.size(),
		"additions": total_additions,
		"deletions": total_deletions,
		"undoable": is_undoable,
		"editedFiles": edited_files
	}


func format_display_path(file_summary: Dictionary) -> String:
	var path_text: String = str(file_summary.get("path", "")).replace("\\", "/")
	var absolute_path: String = str(file_summary.get("absolutePath", "")).replace("\\", "/")
	var workspace_root: String = str(file_summary.get("workspaceRoot", "")).replace("\\", "/").trim_suffix("/")
	if not absolute_path.is_empty() and not workspace_root.is_empty():
		var root_prefix: String = "%s/" % workspace_root
		if absolute_path.to_lower().begins_with(root_prefix.to_lower()):
			return absolute_path.substr(root_prefix.length())

	if not path_text.is_empty():
		return path_text

	return absolute_path


func complete_stream(entry_id: String) -> void:
	var summary: Dictionary = create_inline_diff_summary(active_file_edit_batches)
	active_file_edit_batches.clear()
	if summary.is_empty():
		return

	inline_diff_ready.emit(entry_id, summary)
	_request_file_edit_batches(summary, "register", entry_id)


func _request_file_edit_batches(summary: Dictionary, mode: String, entry_id: String) -> void:
	var session_id: String = str(summary.get("sessionId", active_session_id))
	if session_id.is_empty():
		session_id = active_session_id
	if session_id.is_empty():
		return

	var batch_ids_value: Variant = summary.get("batchIds", [])
	if typeof(batch_ids_value) != TYPE_ARRAY:
		return

	var group_id: String = "file-edit-group-%d-%d" % [Time.get_ticks_msec(), pending_file_edit_batch_groups.size()]
	var group: Dictionary = {
		"mode": mode,
		"entry_id": entry_id,
		"summary": summary.duplicate(true),
		"remaining": 0,
		"failed": false,
		"batches": []
	}
	pending_file_edit_batch_groups[group_id] = group

	for batch_id_value: Variant in batch_ids_value as Array:
		var batch_id: String = str(batch_id_value).strip_edges()
		if batch_id.is_empty():
			continue

		var request_params: Dictionary[String, Variant] = {
			"sessionId": session_id,
			"batchId": batch_id
		}
		request_ready.emit(request_params, group_id)

	group = pending_file_edit_batch_groups.get(group_id, {}) as Dictionary
	if int(group.get("remaining", 0)) == 0:
		pending_file_edit_batch_groups.erase(group_id)


func handle_batch_response(response_id: String, ok: bool, result_dictionary: Dictionary) -> bool:
	var group_id: String = str(pending_file_edit_batch_requests.get(response_id, ""))
	if group_id.is_empty():
		return false

	pending_file_edit_batch_requests.erase(response_id)
	var group: Dictionary = pending_file_edit_batch_groups.get(group_id, {}) as Dictionary
	if group.is_empty():
		return true

	var batches: Array = group.get("batches", []) as Array
	if ok:
		var batch_value: Variant = result_dictionary.get("fileEditBatch", {})
		if typeof(batch_value) == TYPE_DICTIONARY:
			batches.append((batch_value as Dictionary).duplicate(true))
		else:
			group["failed"] = true
	else:
		group["failed"] = true

	group["batches"] = batches
	group["remaining"] = maxi(0, int(group.get("remaining", 1)) - 1)
	if int(group.get("remaining", 0)) > 0:
		pending_file_edit_batch_groups[group_id] = group
		return true

	pending_file_edit_batch_groups.erase(group_id)
	_complete_file_edit_batch_group(group)
	return true


func _complete_file_edit_batch_group(group: Dictionary) -> void:
	if bool(group.get("failed", false)):
		return

	var batches: Array = group.get("batches", []) as Array
	var summary: Dictionary = group.get("summary", {}) as Dictionary
	var mode: String = str(group.get("mode", ""))
	if mode == "register":
		_register_file_edit_undo_action(summary, batches)
	elif mode == "undo":
		_undo_inline_diff_summary(summary, batches)


func _register_file_edit_undo_action(summary: Dictionary, batches: Array) -> void:
	var editor_undo_redo: EditorUndoRedoManager = editor_bridge_controller.get_undo_redo()
	if editor_undo_redo == null:
		return
	if not bool(summary.get("undoable", true)):
		return

	var action_key: String = _get_inline_diff_action_key(summary)
	if action_key.is_empty() or inline_diff_action_titles_by_key.has(action_key):
		return

	var edits: Array[Dictionary] = _aggregate_file_edit_snapshots(batches)
	if edits.is_empty() or not is_group_current(edits, true):
		return

	var action_title: String = _create_file_edit_action_title("Daedalus AI edit", edits.size())
	editor_undo_redo.create_action(action_title, 0, self, true, false)
	editor_undo_redo.add_do_method(self, "apply_snapshots", edits, true)
	editor_undo_redo.add_undo_method(self, "apply_snapshots", edits, false)
	editor_undo_redo.commit_action(false)
	inline_diff_action_titles_by_key[action_key] = action_title


func _undo_inline_diff_summary(summary: Dictionary, batches: Array) -> void:
	if not bool(summary.get("undoable", true)):
		return

	var edits: Array[Dictionary] = _aggregate_file_edit_snapshots(batches)
	if edits.is_empty() or not is_group_current(edits, true):
		return

	var action_key: String = _get_inline_diff_action_key(summary)
	var action_title: String = str(inline_diff_action_titles_by_key.get(action_key, ""))
	if not action_title.is_empty() and _try_undo_registered_file_edit_action(action_title):
		return

	var editor_undo_redo: EditorUndoRedoManager = editor_bridge_controller.get_undo_redo()
	if editor_undo_redo == null:
		apply_snapshots(edits, false)
		return

	var restore_title: String = _create_file_edit_action_title("Undo Daedalus AI edit", edits.size())
	editor_undo_redo.create_action(restore_title, 0, self, true, false)
	editor_undo_redo.add_do_method(self, "apply_snapshots", edits, false)
	editor_undo_redo.add_undo_method(self, "apply_snapshots", edits, true)
	editor_undo_redo.commit_action()


func _try_undo_registered_file_edit_action(action_title: String) -> bool:
	var editor_undo_redo: EditorUndoRedoManager = editor_bridge_controller.get_undo_redo()
	if editor_undo_redo == null:
		return false

	var history_id: int = editor_undo_redo.get_object_history_id(self)
	var undo_redo: UndoRedo = editor_undo_redo.get_history_undo_redo(history_id)
	if undo_redo == null:
		return false

	var current_action: int = undo_redo.get_current_action()
	if current_action < 0 or undo_redo.get_action_name(current_action) != action_title:
		return false

	return undo_redo.undo()


func _aggregate_file_edit_snapshots(batches: Array) -> Array[Dictionary]:
	var edits_by_key: Dictionary = {}
	var edit_keys: PackedStringArray
	for batch_value: Variant in batches:
		if typeof(batch_value) != TYPE_DICTIONARY:
			continue

		var batch: Dictionary = batch_value as Dictionary
		var edits_value: Variant = batch.get("edits", [])
		if typeof(edits_value) != TYPE_ARRAY:
			continue

		for edit_value: Variant in edits_value as Array:
			if typeof(edit_value) != TYPE_DICTIONARY:
				continue

			var edit: Dictionary = (edit_value as Dictionary).duplicate(true)
			if not bool(edit.get("undoable", false)):
				continue

			var edit_key: String = _get_file_edit_key(edit)
			if edit_key.is_empty():
				continue

			if not edits_by_key.has(edit_key):
				edits_by_key[edit_key] = edit
				edit_keys.append(edit_key)
				continue

			var existing_edit: Dictionary = edits_by_key[edit_key] as Dictionary
			existing_edit["existsAfter"] = bool(edit.get("existsAfter", false))
			existing_edit["afterText"] = str(edit.get("afterText", ""))
			existing_edit["afterSha256"] = str(edit.get("afterSha256", ""))
			existing_edit["additions"] = int(existing_edit.get("additions", 0)) + int(edit.get("additions", 0))
			existing_edit["deletions"] = int(existing_edit.get("deletions", 0)) + int(edit.get("deletions", 0))
			edits_by_key[edit_key] = existing_edit

	var edits: Array[Dictionary] = []
	for edit_key: String in edit_keys:
		edits.append((edits_by_key[edit_key] as Dictionary).duplicate(true))

	return edits


func _get_file_edit_key(edit: Dictionary) -> String:
	var absolute_path: String = str(edit.get("absolutePath", "")).replace("\\", "/")
	if not absolute_path.is_empty():
		return absolute_path.to_lower()

	return str(edit.get("path", "")).replace("\\", "/").to_lower()


func _get_inline_diff_action_key(summary: Dictionary) -> String:
	var batch_ids_value: Variant = summary.get("batchIds", [])
	if typeof(batch_ids_value) != TYPE_ARRAY:
		return ""

	var batch_ids: PackedStringArray
	for batch_id_value: Variant in batch_ids_value as Array:
		var batch_id: String = str(batch_id_value).strip_edges()
		if not batch_id.is_empty():
			batch_ids.append(batch_id)

	return "|".join(batch_ids)


func _create_file_edit_action_title(prefix: String, file_count: int) -> String:
	return "%s: %d file%s" % [prefix, file_count, "" if file_count == 1 else "s"]


func is_group_current(edits: Array[Dictionary], use_after_state: bool) -> bool:
	for edit: Dictionary in edits:
		if not bool(edit.get("undoable", false)):
			return false

		var absolute_path: String = str(edit.get("absolutePath", "")).strip_edges()
		if absolute_path.is_empty():
			return false

		var should_exist_key: String = "existsAfter" if use_after_state else "existedBefore"
		var expected_hash_key: String = "afterSha256" if use_after_state else "beforeSha256"
		var should_exist: bool = bool(edit.get(should_exist_key, false))
		if not should_exist:
			if FileAccess.file_exists(absolute_path):
				return false
			continue

		if not FileAccess.file_exists(absolute_path):
			return false

		var read_result: Dictionary = _read_text_file_absolute(absolute_path)
		if not bool(read_result.get("ok", false)):
			return false

		var expected_hash: String = str(edit.get(expected_hash_key, ""))
		if expected_hash.is_empty() or str(read_result.get("text", "")).sha256_text() != expected_hash:
			return false

	return true


func apply_snapshots(edits: Array, use_after_state: bool) -> void:
	for edit_value: Variant in edits:
		if typeof(edit_value) != TYPE_DICTIONARY:
			continue

		_apply_file_edit_snapshot(edit_value as Dictionary, use_after_state)

	_refresh_editor_filesystem_after_file_edits()


func _apply_file_edit_snapshot(edit: Dictionary, use_after_state: bool) -> void:
	var absolute_path: String = str(edit.get("absolutePath", "")).strip_edges()
	if absolute_path.is_empty():
		return

	var should_exist_key: String = "existsAfter" if use_after_state else "existedBefore"
	var text_key: String = "afterText" if use_after_state else "beforeText"
	var should_exist: bool = bool(edit.get(should_exist_key, false))
	if should_exist:
		_write_text_file_absolute(absolute_path, str(edit.get(text_key, "")))
	elif FileAccess.file_exists(absolute_path):
		_delete_file_absolute(absolute_path)


func _read_text_file_absolute(absolute_path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"error": error_string(FileAccess.get_open_error())
		}

	return {
		"ok": true,
		"text": file.get_as_text()
	}


func _write_text_file_absolute(absolute_path: String, content: String) -> bool:
	var directory_path: String = absolute_path.get_base_dir()
	if not directory_path.is_empty():
		var directory_error: Error = DirAccess.make_dir_recursive_absolute(directory_path)
		if directory_error != OK:
			return false

	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(content)
	return true


func _delete_file_absolute(absolute_path: String) -> bool:
	var remove_error: Error = DirAccess.remove_absolute(absolute_path)
	return remove_error == OK or not FileAccess.file_exists(absolute_path)


func _refresh_editor_filesystem_after_file_edits() -> void:
	if editor_bridge_controller == null:
		return
	var editor_interface: EditorInterface = editor_bridge_controller.get_interface()
	if editor_interface == null:
		return

	var resource_filesystem: EditorFileSystem = editor_interface.get_resource_filesystem()
	if resource_filesystem == null:
		return

	if resource_filesystem.has_method("scan_sources"):
		resource_filesystem.call("scan_sources")
	resource_filesystem.scan()
	editor_bridge_controller.queue_context_update()


func undo_inline_diff(summary: Dictionary) -> void:
	_request_file_edit_batches(summary, "undo", "")
