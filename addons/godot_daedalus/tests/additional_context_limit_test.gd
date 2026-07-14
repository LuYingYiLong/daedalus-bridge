@tool
extends SceneTree

const ADDITIONAL_CONTEXT_CONTROLLER_SCRIPT: GDScript = preload("res://addons/godot_daedalus/scripts/controllers/daedalus_additional_context_controller.gd")
const LIVE_SCRIPT_SELECTION_CONTEXT_ID: String = "script-selection-live"
const LIVE_FILESYSTEM_SELECTION_CONTEXT_ID: String = "filesystem-selection-live"

var failures: PackedStringArray
var changed_count: int


func _init() -> void:
	_run_tests.call_deferred()


func _finish_tests() -> void:
	if failures.is_empty():
		quit(0)
		return

	for failure: String in failures:
		push_error(failure)
	quit(1)


func _run_tests() -> void:
	_test_render_reuses_context_nodes()
	await _test_deferred_render_coalesces_changes()

	var controller: Node = ADDITIONAL_CONTEXT_CONTROLLER_SCRIPT.new() as Node
	controller.connect("changed", Callable(self, "_on_controller_changed"))

	var first_context: Dictionary = _make_script_context(LIVE_SCRIPT_SELECTION_CONTEXT_ID, 1, 3)
	controller.call("upsert_live", LIVE_SCRIPT_SELECTION_CONTEXT_ID, first_context)
	_expect_equal(_context_count(controller), 1, "initial live context count")
	_expect_equal(_context_id_at(controller, 0), LIVE_SCRIPT_SELECTION_CONTEXT_ID, "initial live context id")
	_expect_equal(changed_count, 1, "initial live context emits changed")

	controller.call("upsert_live", LIVE_SCRIPT_SELECTION_CONTEXT_ID, first_context)
	_expect_equal(changed_count, 1, "same live context does not emit changed")

	controller.call("set_pinned", LIVE_SCRIPT_SELECTION_CONTEXT_ID, true)
	_expect_equal(_context_count(controller), 1, "pin detaches without duplicating")
	_expect_equal(_context_id_at(controller, 0) != LIVE_SCRIPT_SELECTION_CONTEXT_ID, true, "pinned live context detached")
	_expect_equal(_context_pinned_at(controller, 0), true, "detached context pinned")
	_expect_equal(changed_count, 2, "pin emits changed once")

	controller.call("upsert_live", LIVE_SCRIPT_SELECTION_CONTEXT_ID, first_context)
	_expect_equal(_context_count(controller), 1, "same live context suppressed after pin")
	_expect_equal(changed_count, 2, "suppressed live context does not emit changed")

	var second_context: Dictionary = _make_script_context(LIVE_SCRIPT_SELECTION_CONTEXT_ID, 8, 9)
	controller.call("upsert_live", LIVE_SCRIPT_SELECTION_CONTEXT_ID, second_context)
	_expect_equal(_context_count(controller), 2, "changed live context appended after pin")
	_expect_equal(_context_id_at(controller, 1), LIVE_SCRIPT_SELECTION_CONTEXT_ID, "new live context uses live slot")
	_expect_equal(_context_pinned_at(controller, 1), false, "new live context is unpinned")
	_expect_equal(changed_count, 3, "changed live context emits changed")

	controller.call("remove", LIVE_SCRIPT_SELECTION_CONTEXT_ID)
	_expect_equal(_context_count(controller), 1, "live context remove keeps pinned detached context")
	var removed_changed_count: int = changed_count
	controller.call("replace_items", [second_context])
	_expect_equal(_context_count(controller), 0, "dismissed live snapshot is not restored")
	_expect_equal(changed_count, removed_changed_count + 1, "dismissed live snapshot emits only for real snapshot change")

	controller.call("upsert_live", LIVE_SCRIPT_SELECTION_CONTEXT_ID, second_context)
	_expect_equal(_context_count(controller), 0, "same dismissed live upsert stays suppressed")
	_expect_equal(changed_count, removed_changed_count + 1, "suppressed dismissed live upsert does not emit changed")

	var editor_context: Dictionary = _make_editor_selection_context("Button", 1)
	controller.call("upsert_live", "editor-selection-live", editor_context)
	_expect_equal(_context_count(controller), 1, "editor live context can append after script dismissal")
	controller.call("remove", "editor-selection-live")
	var editor_removed_count: int = changed_count
	controller.call("replace_items", [_make_editor_selection_context("Button renamed", 2)])
	_expect_equal(_context_count(controller), 0, "dismissed editor live snapshot uses stable node path key")
	_expect_equal(changed_count, editor_removed_count, "volatile dismissed editor snapshot does not emit changed")
	controller.call("upsert_live", "editor-selection-live", _make_editor_selection_context("Button renamed", 2))
	_expect_equal(_context_count(controller), 0, "volatile dismissed editor live upsert stays suppressed")

	var full_contexts: Array[Dictionary] = []
	for index: int in range(10):
		full_contexts.append(_make_script_context("manual-%d" % index, index + 1, index + 1))
	controller.call("replace_items", full_contexts)
	var replace_changed_count: int = changed_count
	controller.call("replace_items", full_contexts)
	_expect_equal(changed_count, replace_changed_count, "same snapshot replace does not emit changed")
	controller.call("upsert_live", LIVE_SCRIPT_SELECTION_CONTEXT_ID, _make_script_context(LIVE_SCRIPT_SELECTION_CONTEXT_ID, 20, 20))
	_expect_equal(_context_count(controller), 10, "live append respects max context limit")

	controller.call("replace_items", [])
	var filesystem_context: Dictionary = _make_filesystem_context("res://addons/godot_daedalus/scenes/additional_context_item.tscn")
	controller.call("upsert_live", LIVE_FILESYSTEM_SELECTION_CONTEXT_ID, filesystem_context)
	_expect_equal(_context_count(controller), 1, "filesystem live context appended")
	var backend_snapshot: Array[Dictionary] = controller.call("get_backend_snapshot") as Array[Dictionary]
	_expect_equal(backend_snapshot.size(), 0, "backend snapshot excludes filesystem live context")
	var frozen_contexts: Array[Dictionary] = controller.call("freeze_contexts_for_message", [filesystem_context], true) as Array[Dictionary]
	_expect_equal(frozen_contexts.size(), 1, "message freeze keeps filesystem context")
	_expect_equal(str(frozen_contexts[0].get("id", "")) != LIVE_FILESYSTEM_SELECTION_CONTEXT_ID, true, "message freeze detaches filesystem live id")
	var filesystem_added_count: int = changed_count
	controller.call("replace_items", [])
	_expect_equal(_context_count(controller), 1, "empty backend snapshot preserves active filesystem live context")
	_expect_equal(changed_count, filesystem_added_count, "preserved active filesystem live snapshot does not emit changed")
	controller.call("upsert_live", LIVE_FILESYSTEM_SELECTION_CONTEXT_ID, {})
	_expect_equal(_context_count(controller), 1, "first empty filesystem selection is treated as transient")
	_expect_equal(changed_count, filesystem_added_count, "transient empty filesystem selection does not emit changed")
	controller.call("upsert_live", LIVE_FILESYSTEM_SELECTION_CONTEXT_ID, {})
	_expect_equal(_context_count(controller), 0, "repeated empty filesystem selection removes active live context")
	controller.call("replace_items", [filesystem_context])
	_expect_equal(_context_count(controller), 0, "backend live snapshot does not restore cleared filesystem selection")

	var image_contexts: Array[Dictionary] = [_make_attachment_image_context()]
	var request_clone: Array[Dictionary] = controller.call("clone_contexts", image_contexts) as Array[Dictionary]
	var ui_clone: Array[Dictionary] = controller.call("clone_contexts", image_contexts, true) as Array[Dictionary]
	_expect_equal(_image_data_has_key(request_clone, "dataUrl"), false, "request clone strips image dataUrl")
	_expect_equal(_image_data_has_key(request_clone, "thumbnailDataUrl"), false, "request clone strips image thumbnail")
	_expect_equal(_image_data_has_key(ui_clone, "dataUrl"), false, "ui clone strips full image dataUrl")
	_expect_equal(_image_data_has_key(ui_clone, "thumbnailDataUrl"), true, "ui clone keeps image thumbnail")

	controller.free()
	_finish_tests()


func _test_deferred_render_coalesces_changes() -> void:
	var controller: Node = ADDITIONAL_CONTEXT_CONTROLLER_SCRIPT.new() as Node
	var viewer: ScrollContainer = ScrollContainer.new()
	var container: HBoxContainer = HBoxContainer.new()
	viewer.add_child(container)
	root.add_child(viewer)
	controller.call("setup", viewer, container)
	controller.call("set_deferred_render_enabled", true)

	var local_changed_count: int = 0
	controller.connect("changed", func() -> void: local_changed_count += 1)
	controller.call("upsert_live", LIVE_SCRIPT_SELECTION_CONTEXT_ID, _make_script_context(LIVE_SCRIPT_SELECTION_CONTEXT_ID, 1, 1))
	controller.call("upsert_live", LIVE_FILESYSTEM_SELECTION_CONTEXT_ID, _make_filesystem_context("res://addons/godot_daedalus/scenes/main.tscn"))
	_expect_equal(container.get_child_count(), 0, "deferred render waits until frame end")
	await process_frame
	_expect_equal(container.get_child_count(), 2, "deferred render applies queued contexts")
	_expect_equal(local_changed_count, 1, "deferred render emits one changed signal")

	root.remove_child(viewer)
	controller.free()
	viewer.queue_free()


func _test_render_reuses_context_nodes() -> void:
	var controller: Node = ADDITIONAL_CONTEXT_CONTROLLER_SCRIPT.new() as Node
	var viewer: ScrollContainer = ScrollContainer.new()
	var container: HBoxContainer = HBoxContainer.new()
	viewer.add_child(container)
	root.add_child(viewer)
	controller.call("setup", viewer, container)
	_expect_equal(viewer.visible, true, "context viewer stays visible as stable layout slot")

	controller.call("replace_items", [_make_script_context(LIVE_SCRIPT_SELECTION_CONTEXT_ID, 1, 1)])
	_expect_equal(container.get_child_count(), 1, "render creates one context node")
	var first_item: Node = container.get_child(0)
	var first_instance_id: int = first_item.get_instance_id()

	controller.call("replace_items", [_make_script_context(LIVE_SCRIPT_SELECTION_CONTEXT_ID, 2, 2)])
	_expect_equal(container.get_child_count(), 1, "render keeps one context node")
	_expect_equal(container.get_child(0).get_instance_id(), first_instance_id, "render reuses context node for same id")

	controller.call("replace_items", [])
	_expect_equal(container.get_child_count(), 0, "render removes stale context node")
	_expect_equal(viewer.visible, true, "empty context viewer still reserves layout slot")
	_expect_equal(viewer.custom_minimum_size.y >= 32.0, true, "context viewer keeps reserved height")
	root.remove_child(viewer)
	controller.free()
	viewer.queue_free()


func _on_controller_changed() -> void:
	changed_count += 1


func _make_script_context(context_id: String, line_start: int, line_end: int) -> Dictionary:
	return {
		"id": context_id,
		"kind": "script_selection",
		"title": "player.gd:%d-%d" % [line_start, line_end],
		"subtitle": "选区 · %d:1-%d:1" % [line_start, line_end],
		"pinned": false,
		"source": "editor",
		"resourcePath": "res://scripts/player.gd",
		"scriptPath": "res://scripts/player.gd",
		"summary": "测试脚本选区",
		"data": {
			"lineStart": line_start,
			"columnStart": 1,
			"lineEnd": line_end,
			"columnEnd": 1,
			"hasSelection": true
		}
	}


func _make_attachment_image_context() -> Dictionary:
	return {
		"id": "image-context",
		"kind": "image",
		"title": "Clipboard image",
		"subtitle": "image/png · 1 KiB · 8x8",
		"pinned": false,
		"source": "clipboard",
		"resourcePath": "",
		"data": {
			"attachmentId": "attachment-test",
			"mimeType": "image/png",
			"dataUrl": "data:image/png;base64,full",
			"thumbnailDataUrl": "data:image/png;base64,thumb"
		}
	}


func _make_editor_selection_context(title_text: String, child_count: int) -> Dictionary:
	return {
		"id": "editor-selection-live",
		"kind": "editor_selection",
		"title": title_text,
		"subtitle": "res://main.tscn",
		"pinned": false,
		"source": "editor",
		"resourcePath": "res://main.tscn",
		"summary": "Selected node: %s" % title_text,
		"data": {
			"selectedNodes": [
				{
					"name": title_text,
					"path": "CanvasLayer/Button",
					"type": "Button",
					"childCount": child_count
				}
			]
		}
	}


func _make_filesystem_context(resource_path: String) -> Dictionary:
	return {
		"id": LIVE_FILESYSTEM_SELECTION_CONTEXT_ID,
		"kind": "filesystem_selection",
		"title": resource_path.get_file(),
		"subtitle": resource_path,
		"pinned": false,
		"source": "editor",
		"resourcePath": resource_path,
		"summary": "FileSystem Dock 当前选中：%s" % resource_path.get_file(),
		"data": {
			"selectedPaths": [{
				"resourcePath": resource_path,
				"kind": "file",
				"name": resource_path.get_file(),
				"extension": resource_path.get_extension()
			}],
			"truncated": false
		}
	}


func _image_data_has_key(contexts: Array[Dictionary], key: String) -> bool:
	if contexts.is_empty():
		return false
	var context: Dictionary = contexts[0]
	var data_value: Variant = context.get("data", {})
	if typeof(data_value) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = data_value as Dictionary
	return data.has(key)


func _get_contexts(controller: Node) -> Array[Dictionary]:
	return controller.call("get_items") as Array[Dictionary]


func _context_count(controller: Node) -> int:
	return _get_contexts(controller).size()


func _context_id_at(controller: Node, index: int) -> String:
	var contexts: Array[Dictionary] = _get_contexts(controller)
	var context: Dictionary = contexts[index]
	return str(context.get("id", ""))


func _context_pinned_at(controller: Node, index: int) -> bool:
	var contexts: Array[Dictionary] = _get_contexts(controller)
	var context: Dictionary = contexts[index]
	return bool(context.get("pinned", false))


func _expect_equal(actual_value: Variant, expected_value: Variant, label_text: String) -> void:
	if actual_value == expected_value:
		return

	failures.append("%s: expected %s, got %s" % [label_text, str(expected_value), str(actual_value)])
