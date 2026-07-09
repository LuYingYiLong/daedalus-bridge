@tool
extends SceneTree

const ADD_MCP_SERVER_DIALOG_SCENE: PackedScene = preload("res://addons/godot_daedalus/scenes/settings_menu/add_mcp_server_dialog.tscn")

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
	var dialog: ConfirmationDialog = ADD_MCP_SERVER_DIALOG_SCENE.instantiate() as ConfirmationDialog
	get_root().add_child(dialog)

	var name_line_edit: LineEdit = dialog.get_node("VBoxContainer/GridContainer/NameLineEdit") as LineEdit
	var type_option_button: OptionButton = dialog.get_node("VBoxContainer/GridContainer/TypeOptionButton") as OptionButton
	var plan_access_check_button: CheckButton = dialog.get_node("VBoxContainer/GridContainer/PlanAccessCheckButton") as CheckButton
	var common_line_edit: LineEdit = dialog.get_node("VBoxContainer/StdioContainer/CommonLineEdit") as LineEdit
	var url_line_edit: LineEdit = dialog.get_node("VBoxContainer/HttpContainer/URLLineEdit") as LineEdit

	name_line_edit.text = "context7"
	common_line_edit.text = "npx"
	plan_access_check_button.button_pressed = true
	var validation_result: Dictionary = dialog.call("_validate_form") as Dictionary
	_expect_equal(bool(validation_result.get("ok", false)), true, "stdio payload valid")
	var stdio_config: Dictionary = dialog.call("_create_config") as Dictionary
	_expect_equal(str(stdio_config.get("planAccess", "")), "read", "stdio plan access payload")

	plan_access_check_button.button_pressed = false
	var disabled_config: Dictionary = dialog.call("_create_config") as Dictionary
	_expect_equal(str(disabled_config.get("planAccess", "")), "disabled", "disabled plan access payload")

	type_option_button.select(1)
	dialog.call("_on_type_option_button_item_selected", 1)
	url_line_edit.text = "https://example.com/mcp"
	plan_access_check_button.button_pressed = true
	validation_result = dialog.call("_validate_form") as Dictionary
	_expect_equal(bool(validation_result.get("ok", false)), true, "http payload valid")
	var http_config: Dictionary = dialog.call("_create_config") as Dictionary
	_expect_equal(str(http_config.get("transport", "")), "http", "http payload transport")
	_expect_equal(str(http_config.get("planAccess", "")), "read", "http plan access payload")

	dialog.queue_free()


func _expect_equal(actual_value: Variant, expected_value: Variant, label_text: String) -> void:
	if actual_value == expected_value:
		return

	failures.append("%s: expected %s, got %s" % [label_text, str(expected_value), str(actual_value)])
