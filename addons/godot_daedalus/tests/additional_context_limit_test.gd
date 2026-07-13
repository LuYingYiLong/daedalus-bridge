@tool
extends SceneTree

const ADDITIONAL_CONTEXT_CONTROLLER_SCRIPT: GDScript = preload("res://addons/godot_daedalus/scripts/controllers/daedalus_additional_context_controller.gd")
const LIVE_SCRIPT_SELECTION_CONTEXT_ID: String = "script-selection-live"

var failures: PackedStringArray


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
	var controller: Node = ADDITIONAL_CONTEXT_CONTROLLER_SCRIPT.new() as Node

	var first_context: Dictionary = _make_script_context(LIVE_SCRIPT_SELECTION_CONTEXT_ID, 1, 3)
	controller.call("upsert_live", LIVE_SCRIPT_SELECTION_CONTEXT_ID, first_context)
	_expect_equal(_context_count(controller), 1, "initial live context count")
	_expect_equal(_context_id_at(controller, 0), LIVE_SCRIPT_SELECTION_CONTEXT_ID, "initial live context id")

	controller.call("set_pinned", LIVE_SCRIPT_SELECTION_CONTEXT_ID, true)
	_expect_equal(_context_count(controller), 1, "pin detaches without duplicating")
	_expect_equal(_context_id_at(controller, 0) != LIVE_SCRIPT_SELECTION_CONTEXT_ID, true, "pinned live context detached")
	_expect_equal(_context_pinned_at(controller, 0), true, "detached context pinned")

	controller.call("upsert_live", LIVE_SCRIPT_SELECTION_CONTEXT_ID, first_context)
	_expect_equal(_context_count(controller), 1, "same live context suppressed after pin")

	var second_context: Dictionary = _make_script_context(LIVE_SCRIPT_SELECTION_CONTEXT_ID, 8, 9)
	controller.call("upsert_live", LIVE_SCRIPT_SELECTION_CONTEXT_ID, second_context)
	_expect_equal(_context_count(controller), 2, "changed live context appended after pin")
	_expect_equal(_context_id_at(controller, 1), LIVE_SCRIPT_SELECTION_CONTEXT_ID, "new live context uses live slot")
	_expect_equal(_context_pinned_at(controller, 1), false, "new live context is unpinned")

	var full_contexts: Array[Dictionary] = []
	for index: int in range(10):
		full_contexts.append(_make_script_context("manual-%d" % index, index + 1, index + 1))
	controller.call("replace_items", full_contexts)
	controller.call("upsert_live", LIVE_SCRIPT_SELECTION_CONTEXT_ID, _make_script_context(LIVE_SCRIPT_SELECTION_CONTEXT_ID, 20, 20))
	_expect_equal(_context_count(controller), 10, "live append respects max context limit")

	var image_contexts: Array[Dictionary] = [_make_attachment_image_context()]
	var request_clone: Array[Dictionary] = controller.call("clone_contexts", image_contexts) as Array[Dictionary]
	var ui_clone: Array[Dictionary] = controller.call("clone_contexts", image_contexts, true) as Array[Dictionary]
	_expect_equal(_image_data_has_key(request_clone, "dataUrl"), false, "request clone strips image dataUrl")
	_expect_equal(_image_data_has_key(request_clone, "thumbnailDataUrl"), false, "request clone strips image thumbnail")
	_expect_equal(_image_data_has_key(ui_clone, "dataUrl"), false, "ui clone strips full image dataUrl")
	_expect_equal(_image_data_has_key(ui_clone, "thumbnailDataUrl"), true, "ui clone keeps image thumbnail")

	controller.free()
	_finish_tests()


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
