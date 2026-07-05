@tool
extends SceneTree

const ADDITIONAL_CONTEXT_ITEM_SCENE: PackedScene = preload("uid://rfwvgjocqqva")

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
	var context_item: Button = ADDITIONAL_CONTEXT_ITEM_SCENE.instantiate() as Button
	root.add_child(context_item)
	context_item.call("setup", {
		"id": "test-image",
		"kind": "image",
		"title": "scene_tree.png",
		"resourcePath": "res://addons/godot_daedalus/tests/images/scene_tree.png",
		"data": {
			"mimeType": "image/png",
			"byteSize": 34421,
			"width": 474,
			"height": 397
		}
	})

	var icon_node: TextureRect = context_item.get_node("%Icon") as TextureRect
	_expect_equal(icon_node.texture != null, true, "interactive icon has texture")
	_expect_equal(icon_node.texture.resource_path != "res://addons/godot_daedalus/assets/icons/file.svg", true, "interactive icon uses thumbnail")

	context_item.call("set_interactive", false)
	_expect_equal(icon_node.visible, false, "history icon node hidden")
	_expect_equal(context_item.icon != null, true, "history root icon has texture")
	_expect_equal(context_item.icon.resource_path != "res://addons/godot_daedalus/assets/icons/file.svg", true, "history root icon uses thumbnail")

	context_item.queue_free()

	var filesystem_context_item: Button = ADDITIONAL_CONTEXT_ITEM_SCENE.instantiate() as Button
	root.add_child(filesystem_context_item)
	filesystem_context_item.call("setup", {
		"id": "test-filesystem-image",
		"kind": "filesystem_selection",
		"title": "scene_tree.png",
		"resourcePath": "res://addons/godot_daedalus/tests/images/scene_tree.png",
		"data": {
			"selectedPaths": [{
				"kind": "file",
				"resourcePath": "res://addons/godot_daedalus/tests/images/scene_tree.png"
			}]
		}
	})

	var filesystem_icon_node: TextureRect = filesystem_context_item.get_node("%Icon") as TextureRect
	_expect_equal(filesystem_icon_node.texture != null, true, "filesystem image icon has texture")
	_expect_equal(filesystem_icon_node.texture.resource_path != "res://addons/godot_daedalus/assets/icons/file.svg", true, "filesystem image icon uses thumbnail")

	filesystem_context_item.queue_free()


func _expect_equal(actual_value: Variant, expected_value: Variant, label_text: String) -> void:
	if actual_value == expected_value:
		return

	failures.append("%s: expected %s, got %s" % [label_text, str(expected_value), str(actual_value)])
