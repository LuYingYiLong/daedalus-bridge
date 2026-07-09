@tool
extends SceneTree

const EDIT_MCP_SERVER_DIALOG_SCENE: PackedScene = preload("res://addons/godot_daedalus/scenes/settings_menu/edit_mcp_server_dialog.tscn")

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
	var dialog: ConfirmationDialog = _create_dialog({
		"id": "custom-demo",
		"name": "demo-tools",
		"description": "Demo server",
		"transport": "stdio",
		"enabled": true,
		"planAccess": "read",
		"command": "npx",
		"args": ["-y", "demo-mcp"],
		"envNames": ["TOKEN"]
	})

	var name_line_edit: LineEdit = dialog.get_node("VBoxContainer/GridContainer/NameLineEdit") as LineEdit
	var description_text_edit: TextEdit = dialog.get_node("VBoxContainer/GridContainer/DescriptionTextEdit") as TextEdit
	var plan_access_check_button: CheckButton = dialog.get_node("VBoxContainer/GridContainer/PlanAccessCheckButton") as CheckButton
	var args_text_edit: TextEdit = dialog.get_node("VBoxContainer/StdioContainer/ArgsTextEdit") as TextEdit
	var env_text_edit: TextEdit = dialog.get_node("VBoxContainer/StdioContainer/EnvTextEdit") as TextEdit
	var type_option_button: OptionButton = dialog.get_node("VBoxContainer/GridContainer/TypeOptionButton") as OptionButton
	var stdio_container: GridContainer = dialog.get_node("VBoxContainer/StdioContainer") as GridContainer
	var http_container: GridContainer = dialog.get_node("VBoxContainer/HttpContainer") as GridContainer
	var url_line_edit: LineEdit = dialog.get_node("VBoxContainer/HttpContainer/URLLineEdit") as LineEdit
	var http_header_text_edit: TextEdit = dialog.get_node("VBoxContainer/HttpContainer/HttpHeaderTextEdit") as TextEdit

	_expect_equal(name_line_edit.text, "demo-tools", "name prefilled")
	_expect_equal(name_line_edit.editable, false, "name is read only")
	_expect_equal(description_text_edit.text, "Demo server", "description prefilled")
	_expect_equal(plan_access_check_button.button_pressed, true, "plan access prefilled")
	_expect_equal(args_text_edit.text, "-y\ndemo-mcp", "args prefilled")
	_expect_equal(env_text_edit.text, "TOKEN=", "env secret placeholder")
	var validation_result: Dictionary = dialog.call("_validate_form") as Dictionary
	_expect_equal(bool(validation_result.get("ok", false)), true, "old empty env value keeps secret")

	var stdio_config: Dictionary = dialog.call("_create_config") as Dictionary
	var stdio_env: Dictionary = stdio_config.get("env", {}) as Dictionary
	_expect_equal(str(stdio_config.get("transport", "")), "stdio", "stdio payload transport")
	_expect_equal(str(stdio_config.get("planAccess", "")), "read", "stdio payload plan access")
	_expect_equal(str(stdio_env.get("TOKEN", "missing")), "", "empty env payload preserves old secret")

	env_text_edit.text = "TOKEN=\nNEW_TOKEN="
	validation_result = dialog.call("_validate_form") as Dictionary
	_expect_equal(bool(validation_result.get("ok", false)), false, "new empty env value rejected")
	env_text_edit.text = "TOKEN=\nNEW_TOKEN=new-value"
	validation_result = dialog.call("_validate_form") as Dictionary
	_expect_equal(bool(validation_result.get("ok", false)), true, "new env value accepted")

	type_option_button.select(1)
	dialog.call("_on_type_option_button_item_selected", 1)
	url_line_edit.text = "https://example.com/mcp"
	http_header_text_edit.text = "Authorization: Bearer token"
	_expect_equal(stdio_container.visible, false, "stdio hidden for http")
	_expect_equal(http_container.visible, true, "http visible")
	validation_result = dialog.call("_validate_form") as Dictionary
	_expect_equal(bool(validation_result.get("ok", false)), true, "http values valid")
	var http_config: Dictionary = dialog.call("_create_config") as Dictionary
	var http_headers: Dictionary = http_config.get("headers", {}) as Dictionary
	_expect_equal(str(http_config.get("transport", "")), "http", "http payload transport")
	_expect_equal(str(http_config.get("planAccess", "")), "read", "http payload plan access")
	_expect_equal(str(http_headers.get("Authorization", "")), "Bearer token", "http header payload")

	plan_access_check_button.button_pressed = false
	var disabled_plan_config: Dictionary = dialog.call("_create_config") as Dictionary
	_expect_equal(str(disabled_plan_config.get("planAccess", "")), "disabled", "disabled plan access payload")

	dialog.queue_free()


func _create_dialog(metadata: Dictionary) -> ConfirmationDialog:
	var dialog: ConfirmationDialog = EDIT_MCP_SERVER_DIALOG_SCENE.instantiate() as ConfirmationDialog
	get_root().add_child(dialog)
	dialog.call("setup_server", metadata)
	return dialog


func _expect_equal(actual_value: Variant, expected_value: Variant, label_text: String) -> void:
	if actual_value == expected_value:
		return

	failures.append("%s: expected %s, got %s" % [label_text, str(expected_value), str(actual_value)])
