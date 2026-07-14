@tool
extends SceneTree

const USER_MESSAGE_ITEM_SCENE: PackedScene = preload("res://addons/godot_daedalus/scenes/user_message_item.tscn")

var failures: PackedStringArray
var received_request_id: String
var received_message_text: String
var received_contexts: Array[Dictionary]


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
	_test_resend_preserves_additional_contexts()
	_finish_tests()


func _test_resend_preserves_additional_contexts() -> void:
	var item: Control = USER_MESSAGE_ITEM_SCENE.instantiate() as Control
	root.add_child(item)
	await process_frame

	var source_contexts: Array[Dictionary] = [_make_script_context()]
	item.connect("resend_requested", Callable(self, "_on_resend_requested"))
	item.call("setup", "旧消息", "request-1", "2026-07-14T01:02:03.000Z", source_contexts)
	source_contexts[0]["title"] = "被外部修改"

	item.call("_on_edit_button_pressed")
	var text_edit: TextEdit = item.get_node("%TextEdit") as TextEdit
	text_edit.text = "新消息"
	item.call("_on_send_button_pressed")

	_expect_equal(received_request_id, "request-1", "resend request id")
	_expect_equal(received_message_text, "新消息", "resend message text")
	_expect_equal(received_contexts.size(), 1, "resend context count")
	if not received_contexts.is_empty():
		_expect_equal(str(received_contexts[0].get("title", "")), "player.gd:1-3", "resend keeps setup context snapshot")
		received_contexts[0]["title"] = "信号接收方修改"

	item.call("_on_edit_button_pressed")
	text_edit.text = "再次发送"
	item.call("_on_send_button_pressed")
	if not received_contexts.is_empty():
		_expect_equal(str(received_contexts[0].get("title", "")), "player.gd:1-3", "resend emits cloned context snapshot")

	root.remove_child(item)
	item.queue_free()


func _on_resend_requested(request_id: String, message_text: String, additional_contexts: Array) -> void:
	received_request_id = request_id
	received_message_text = message_text
	received_contexts.clear()
	for context_value: Variant in additional_contexts:
		if typeof(context_value) == TYPE_DICTIONARY:
			received_contexts.append((context_value as Dictionary).duplicate(true))


func _make_script_context() -> Dictionary:
	return {
		"id": "manual-script",
		"kind": "script_selection",
		"title": "player.gd:1-3",
		"subtitle": "选区 · 1:1-3:1",
		"pinned": false,
		"source": "manual",
		"resourcePath": "res://scripts/player.gd",
		"scriptPath": "res://scripts/player.gd",
		"summary": "测试脚本上下文",
		"data": {
			"lineStart": 1,
			"columnStart": 1,
			"lineEnd": 3,
			"columnEnd": 1,
			"hasSelection": true
		}
	}


func _expect_equal(actual_value: Variant, expected_value: Variant, label_text: String) -> void:
	if actual_value == expected_value:
		return

	failures.append("%s: expected %s, got %s" % [label_text, str(expected_value), str(actual_value)])
