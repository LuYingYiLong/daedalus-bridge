@tool
extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://addons/godot_daedalus/scenes/main.tscn")
const LIVE_SCRIPT_SELECTION_CONTEXT_ID: String = "script-selection-live"

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
	var main_instance: VBoxContainer = MAIN_SCENE.instantiate() as VBoxContainer

	var first_context: Dictionary = _make_script_context(LIVE_SCRIPT_SELECTION_CONTEXT_ID, 1, 3)
	main_instance.call("_upsert_live_additional_context", LIVE_SCRIPT_SELECTION_CONTEXT_ID, first_context)
	_expect_equal(_context_count(main_instance), 1, "initial live context count")
	_expect_equal(_context_id_at(main_instance, 0), LIVE_SCRIPT_SELECTION_CONTEXT_ID, "initial live context id")

	main_instance.call("_on_additional_context_pin_toggled", LIVE_SCRIPT_SELECTION_CONTEXT_ID, true)
	_expect_equal(_context_count(main_instance), 1, "pin detaches without duplicating")
	_expect_equal(_context_id_at(main_instance, 0) != LIVE_SCRIPT_SELECTION_CONTEXT_ID, true, "pinned live context detached")
	_expect_equal(_context_pinned_at(main_instance, 0), true, "detached context pinned")

	main_instance.call("_upsert_live_additional_context", LIVE_SCRIPT_SELECTION_CONTEXT_ID, first_context)
	_expect_equal(_context_count(main_instance), 1, "same live context suppressed after pin")

	var second_context: Dictionary = _make_script_context(LIVE_SCRIPT_SELECTION_CONTEXT_ID, 8, 9)
	main_instance.call("_upsert_live_additional_context", LIVE_SCRIPT_SELECTION_CONTEXT_ID, second_context)
	_expect_equal(_context_count(main_instance), 2, "changed live context appended after pin")
	_expect_equal(_context_id_at(main_instance, 1), LIVE_SCRIPT_SELECTION_CONTEXT_ID, "new live context uses live slot")
	_expect_equal(_context_pinned_at(main_instance, 1), false, "new live context is unpinned")

	var full_contexts: Array[Dictionary] = []
	for index: int in range(10):
		full_contexts.append(_make_script_context("manual-%d" % index, index + 1, index + 1))
	main_instance.set("additional_context_items", full_contexts)
	main_instance.call("_upsert_live_additional_context", LIVE_SCRIPT_SELECTION_CONTEXT_ID, _make_script_context(LIVE_SCRIPT_SELECTION_CONTEXT_ID, 20, 20))
	_expect_equal(_context_count(main_instance), 10, "live append respects max context limit")

	main_instance.free()


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


func _get_contexts(main_instance: VBoxContainer) -> Array:
	return main_instance.get("additional_context_items") as Array


func _context_count(main_instance: VBoxContainer) -> int:
	return _get_contexts(main_instance).size()


func _context_id_at(main_instance: VBoxContainer, index: int) -> String:
	var contexts: Array = _get_contexts(main_instance)
	var context: Dictionary = contexts[index] as Dictionary
	return str(context.get("id", ""))


func _context_pinned_at(main_instance: VBoxContainer, index: int) -> bool:
	var contexts: Array = _get_contexts(main_instance)
	var context: Dictionary = contexts[index] as Dictionary
	return bool(context.get("pinned", false))


func _expect_equal(actual_value: Variant, expected_value: Variant, label_text: String) -> void:
	if actual_value == expected_value:
		return

	failures.append("%s: expected %s, got %s" % [label_text, str(expected_value), str(actual_value)])
