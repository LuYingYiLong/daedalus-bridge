@tool
extends SceneTree

const MAIN_HELPERS: GDScript = preload("res://addons/godot_daedalus/scripts/main_helpers.gd")

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
	_expect_equal(MAIN_HELPERS.format_queue_status("pending"), "Queued", "pending queue status")
	_expect_equal(MAIN_HELPERS.format_queue_status("cancelled"), "Stopped", "cancelled queue status")
	_expect_equal(MAIN_HELPERS.can_edit_queue_message("failed"), true, "failed queue editable")
	_expect_equal(MAIN_HELPERS.can_edit_queue_message("sending"), false, "sending queue not editable")
	_expect_equal(MAIN_HELPERS.format_guide_status("applied"), "Applied", "applied guide status")
	_expect_equal(MAIN_HELPERS.can_delete_manual_guide("deleting"), false, "deleting guide not deletable")
	_expect_equal(MAIN_HELPERS.make_session_title(""), "新会话", "empty session title")
	_expect_equal(MAIN_HELPERS.make_session_title("123456789012345678901234567890"), "123456789012345678901234", "long session title")
	_expect_equal(MAIN_HELPERS.format_context_usage_percent(0.000001), "<0.01%", "tiny context percent")
	_expect_equal(MAIN_HELPERS.format_compact_token_count(1530), "1.5k", "compact token count")
	_expect_equal(MAIN_HELPERS.get_image_mime_type("res://icon.PNG"), "image/png", "png mime")
	_expect_equal(MAIN_HELPERS.get_image_mime_type("res://photo.jpeg"), "image/jpeg", "jpeg mime")
	_expect_equal(MAIN_HELPERS.is_supported_image_resource_path("res://texture.bmp"), false, "bmp unsupported")
	_expect_equal(MAIN_HELPERS.format_byte_size(1536), "1.5 KiB", "image byte size")
	_expect_equal(MAIN_HELPERS.model_capabilities_support_image({ "imageInput": true }), true, "image capability")
	_expect_equal(MAIN_HELPERS.model_capabilities_support_image({}), false, "missing image capability")

	var image_contexts: Array[Dictionary] = [{
		"kind": "image",
		"resourcePath": "res://a.png",
		"data": { "byteSize": 1024 }
	}]
	_expect_equal(MAIN_HELPERS.context_array_has_images(image_contexts), true, "image context detected")
	var filesystem_image_contexts: Array[Dictionary] = [{
		"kind": "filesystem_selection",
		"data": {
			"selectedPaths": [{
				"kind": "file",
				"resourcePath": "res://selected.webp"
			}]
		}
	}]
	_expect_equal(MAIN_HELPERS.context_array_has_images(filesystem_image_contexts), true, "filesystem image selection detected")
	_expect_equal(MAIN_HELPERS.validate_image_context_limits(image_contexts, "res://b.png", 1024), "", "small image accepted")
	_expect_equal(
		MAIN_HELPERS.validate_image_context_limits([], "res://large.png", MAIN_HELPERS.MAX_IMAGE_BYTES + 1).is_empty(),
		false,
		"large image rejected"
	)

	var todos: Array[Dictionary] = MAIN_HELPERS.extract_todo_items("- [ ] 写测试\n- [x] 跑检查")
	_expect_equal(todos.size(), 2, "markdown todo count")
	_expect_equal(str(todos[0].get("text", "")), "写测试", "markdown todo text")
	_expect_equal(bool(todos[1].get("checked", false)), true, "markdown todo checked")

	var plain_todos: Array[Dictionary] = MAIN_HELPERS.extract_todo_items("待办\n1. 拆分主脚本\n2. 补下载规则")
	_expect_equal(plain_todos.size(), 2, "plain todo count")
	_expect_equal(str(plain_todos[1].get("text", "")), "补下载规则", "plain todo text")
	_finish_tests()


func _expect_equal(actual_value: Variant, expected_value: Variant, label_text: String) -> void:
	if actual_value == expected_value:
		return

	failures.append("%s: expected %s, got %s" % [label_text, str(expected_value), str(actual_value)])
