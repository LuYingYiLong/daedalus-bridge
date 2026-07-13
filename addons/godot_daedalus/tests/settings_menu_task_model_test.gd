@tool
extends SceneTree

const SETTINGS_MENU_SCENE: PackedScene = preload("res://addons/godot_daedalus/scenes/settings_menu/settings_menu.tscn")

var failures: PackedStringArray
var saved_provider_id: String
var saved_api_key: String
var saved_base_url: String
var saved_model_routing: Dictionary


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
	var dialog: AcceptDialog = SETTINGS_MENU_SCENE.instantiate() as AcceptDialog
	root.add_child(dialog)
	dialog.connect("provider_config_save_requested", Callable(self, "_on_provider_config_save_requested"))
	dialog.call("setup_provider_config", _create_provider_status(), {})

	var image_option_button: OptionButton = dialog.get_node("%ImageRecognitionModelOptionButton") as OptionButton
	var planner_option_button: OptionButton = dialog.get_node("%WorkflowPlannerModelOptionButton") as OptionButton
	var title_option_button: OptionButton = dialog.get_node("%SessionTitleModelOptionButton") as OptionButton
	var base_url_line_edit: LineEdit = dialog.get_node("%ProviderBaseURLLineEdit") as LineEdit
	var provider_option_button: OptionButton = dialog.get_node("%ProviderOptionButton") as OptionButton

	_expect_equal(image_option_button.get_item_text(0), "Use current model", "image default option")
	_expect_equal(planner_option_button.get_item_text(0), "Use current model", "planner default option")
	_expect_equal(title_option_button.get_item_text(0), "Use current model", "title default option")
	_expect_equal(_has_option_metadata(image_option_button, "moonshot", "kimi-k2.6"), true, "image option has moonshot model")
	_expect_equal(_has_option_metadata(image_option_button, "zhipu", "glm-5v-turbo"), true, "image option has zhipu visual model")
	_expect_equal(base_url_line_edit.placeholder_text, "https://api.deepseek.com", "base url default placeholder")
	_expect_equal(base_url_line_edit.text, "https://proxy.example/v1", "base url custom value")
	_select_provider_option(provider_option_button, "moonshot")
	dialog.call("_on_provider_option_button_item_selected", provider_option_button.selected)
	_expect_equal(base_url_line_edit.placeholder_text, "https://api.moonshot.cn/v1", "moonshot base url default placeholder")
	_expect_equal(base_url_line_edit.text, "", "null base url renders empty")
	_select_provider_option(provider_option_button, "zhipu")
	dialog.call("_on_provider_option_button_item_selected", provider_option_button.selected)
	_expect_equal(base_url_line_edit.placeholder_text, "https://open.bigmodel.cn/api/paas/v4", "zhipu base url default placeholder")
	_select_provider_option(provider_option_button, "deepseek")
	dialog.call("_on_provider_option_button_item_selected", provider_option_button.selected)

	_select_option_metadata(image_option_button, "moonshot", "kimi-k2.6")
	dialog.call("_on_confirmed")
	_expect_equal(saved_provider_id, "deepseek", "saved provider")
	_expect_equal(saved_base_url, "https://proxy.example/v1", "saved base url")
	var image_routing: Dictionary = saved_model_routing.get("imageRecognition", {}) as Dictionary
	_expect_equal(str(image_routing.get("provider", "")), "moonshot", "image routing provider")
	_expect_equal(str(image_routing.get("model", "")), "kimi-k2.6", "image routing model")
	_expect_equal(saved_model_routing.get("workflowPlanner", "not-null") == null, true, "planner routing current")
	dialog.queue_free()
	_finish_tests()


func _create_provider_status() -> Dictionary:
	return {
		"activeProvider": "deepseek",
		"provider": "deepseek",
		"configured": true,
		"model": "deepseek-v4-flash",
		"modelRouting": {
			"imageRecognition": null,
			"workflowPlanner": null,
			"sessionTitle": null
		},
		"providers": [
			{
				"provider": "deepseek",
				"displayName": "DeepSeek",
				"configured": true,
				"model": "deepseek-v4-flash",
				"baseUrl": "https://proxy.example/v1",
				"defaultBaseUrl": "https://api.deepseek.com",
				"modelsCache": [],
				"fallbackModels": [
					{ "id": "deepseek-v4-flash", "displayName": "DeepSeek V4 Flash" },
					{ "id": "deepseek-v4-pro", "displayName": "DeepSeek V4 Pro" }
				]
			},
			{
				"provider": "moonshot",
				"displayName": "Moonshot",
				"configured": true,
				"model": "kimi-k2.7-code",
				"baseUrl": null,
				"defaultBaseUrl": "https://api.moonshot.cn/v1",
				"modelsCache": [
					{ "id": "kimi-k2.6", "displayName": "Kimi K2.6" }
				],
				"fallbackModels": []
			},
			{
				"provider": "openai",
				"displayName": "OpenAI",
				"configured": false,
				"model": null,
				"baseUrl": null,
				"defaultBaseUrl": "https://api.openai.com/v1",
				"modelsCache": [
					{ "id": "gpt-5.5", "displayName": "GPT-5.5" }
				],
				"fallbackModels": []
			},
			{
				"provider": "zhipu",
				"displayName": "Zhipu AI",
				"configured": true,
				"model": "glm-5.2",
				"baseUrl": null,
				"defaultBaseUrl": "https://open.bigmodel.cn/api/paas/v4",
				"modelsCache": [],
				"fallbackModels": [
					{ "id": "glm-5.2", "displayName": "GLM-5.2" },
					{ "id": "glm-5v-turbo", "displayName": "GLM-5V Turbo", "capabilities": { "imageInput": true } }
				]
			}
		]
	}


func _has_option_metadata(option_button: OptionButton, provider_id: String, model_id: String) -> bool:
	for index: int in range(option_button.get_item_count()):
		var metadata_value: Variant = option_button.get_item_metadata(index)
		if typeof(metadata_value) != TYPE_DICTIONARY:
			continue

		var metadata: Dictionary = metadata_value as Dictionary
		if str(metadata.get("provider", "")) == provider_id and str(metadata.get("model", "")) == model_id:
			return true

	return false


func _select_option_metadata(option_button: OptionButton, provider_id: String, model_id: String) -> void:
	for index: int in range(option_button.get_item_count()):
		var metadata_value: Variant = option_button.get_item_metadata(index)
		if typeof(metadata_value) != TYPE_DICTIONARY:
			continue

		var metadata: Dictionary = metadata_value as Dictionary
		if str(metadata.get("provider", "")) == provider_id and str(metadata.get("model", "")) == model_id:
			option_button.select(index)
			return


func _select_provider_option(option_button: OptionButton, provider_id: String) -> void:
	for index: int in range(option_button.get_item_count()):
		if str(option_button.get_item_metadata(index)) == provider_id:
			option_button.select(index)
			return


func _on_provider_config_save_requested(provider_id: String, api_key: String, base_url: String, model_routing: Dictionary) -> void:
	saved_provider_id = provider_id
	saved_api_key = api_key
	saved_base_url = base_url
	saved_model_routing = model_routing.duplicate(true)


func _expect_equal(actual_value: Variant, expected_value: Variant, label_text: String) -> void:
	if actual_value == expected_value:
		return

	failures.append("%s: expected %s, got %s" % [label_text, str(expected_value), str(actual_value)])
