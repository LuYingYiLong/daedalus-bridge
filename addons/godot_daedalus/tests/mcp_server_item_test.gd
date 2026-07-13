@tool
extends SceneTree

const MCP_SERVER_ITEM_SCENE: PackedScene = preload("res://addons/godot_daedalus/scenes/settings_menu/mcp_server_item.tscn")

var failures: PackedStringArray
var edit_server_id: String


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
	var item: HBoxContainer = MCP_SERVER_ITEM_SCENE.instantiate() as HBoxContainer
	get_root().add_child(item)
	item.connect("edit_requested", Callable(self, "_on_edit_requested"))
	item.call("setup", {
		"id": "custom-demo",
		"name": "Demo MCP",
		"transport": "stdio",
		"enabled": true,
		"status": "connected",
		"toolCount": 2,
		"planAccess": "read"
	})

	var name_label: Label = item.get_node("NameLabel") as Label
	var plan_access_label: Label = item.get_node("PlanAccessLabel") as Label
	var edit_button: Button = item.get_node("EditButton") as Button
	var remove_button: Button = item.get_node("RemoveButton") as Button
	var check_button: CheckButton = item.get_node("CheckButton") as CheckButton

	_expect_equal(name_label.text, "Demo MCP", "name rendered")
	_expect_equal(plan_access_label.visible, true, "plan access label visible")
	_expect_equal(edit_button.disabled, false, "edit enabled")
	_expect_equal(remove_button.disabled, false, "remove enabled")
	_expect_equal(check_button.disabled, false, "check enabled")
	item.call("_on_edit_button_pressed")
	_expect_equal(edit_server_id, "custom-demo", "edit signal server id")

	item.call("setup", {
		"id": "custom-demo",
		"name": "Demo MCP",
		"transport": "stdio",
		"enabled": true,
		"status": "connecting",
		"pending": true,
		"planAccess": "disabled"
	})
	_expect_equal(plan_access_label.visible, false, "plan access label hidden")
	_expect_equal(edit_button.disabled, true, "pending edit disabled")
	_expect_equal(remove_button.disabled, true, "pending remove disabled")
	_expect_equal(check_button.disabled, true, "pending check disabled")

	item.queue_free()
	_finish_tests()


func _on_edit_requested(server_id: String) -> void:
	edit_server_id = server_id


func _expect_equal(actual_value: Variant, expected_value: Variant, label_text: String) -> void:
	if actual_value == expected_value:
		return

	failures.append("%s: expected %s, got %s" % [label_text, str(expected_value), str(actual_value)])
