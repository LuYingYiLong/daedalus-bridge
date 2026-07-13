@tool
extends SceneTree

const EDITOR_BRIDGE_CONTROLLER_SCRIPT: GDScript = preload("res://addons/godot_daedalus/scripts/controllers/daedalus_editor_bridge_controller.gd")

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
	var controller: Node = EDITOR_BRIDGE_CONTROLLER_SCRIPT.new() as Node
	var scene_image: Image = Image.create(64, 32, false, Image.FORMAT_RGBA8)
	scene_image.fill(Color(0.2, 0.4, 0.8, 1.0))
	var payload_value: Variant = controller.call("_encode_scene_view_capture", scene_image)
	if typeof(payload_value) != TYPE_DICTIONARY:
		failures.append("capture payload must be a dictionary")
		controller.free()
		_finish_tests()
		return

	var payload: Dictionary = payload_value as Dictionary
	_expect_equal(str(payload.get("mimeType", "")), "image/png", "capture MIME type")
	_expect_equal(int(payload.get("width", 0)), 64, "capture width")
	_expect_equal(int(payload.get("height", 0)), 32, "capture height")
	_expect_equal(str(payload.get("dataUrl", "")).begins_with("data:image/png;base64,"), true, "capture data URL")
	_expect_equal(int(payload.get("byteSize", 0)) > 0, true, "capture byte size")
	controller.free()
	_finish_tests()


func _expect_equal(actual_value: Variant, expected_value: Variant, label_text: String) -> void:
	if actual_value == expected_value:
		return

	failures.append("%s: expected %s, got %s" % [label_text, str(expected_value), str(actual_value)])
