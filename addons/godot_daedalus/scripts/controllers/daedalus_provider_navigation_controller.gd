@tool
class_name DaedalusProviderNavigationController
extends Node

const APPROVAL_MODE_IDS: PackedStringArray = ["manual", "auto-safe"]
const CHAT_MODE_IDS: PackedStringArray = ["agent", "ask", "plan"]

var _approval_mode_button: OptionButton
var _mode_button: MenuButton
var _provider_button: OptionButton
var _model_button: OptionButton
var _model_capabilities: Array[Dictionary]


func setup(approval_mode_button: OptionButton, mode_button: MenuButton, provider_button: OptionButton, model_button: OptionButton) -> void:
	_approval_mode_button = approval_mode_button
	_mode_button = mode_button
	_provider_button = provider_button
	_model_button = model_button


func select_approval_mode(approval_mode: String) -> bool:
	if _approval_mode_button == null:
		return false
	for index: int in range(APPROVAL_MODE_IDS.size()):
		if APPROVAL_MODE_IDS[index] == approval_mode:
			_approval_mode_button.select(index)
			return true
	return false


func get_approval_mode() -> String:
	if _approval_mode_button == null:
		return APPROVAL_MODE_IDS[0]
	var selected_index: int = _approval_mode_button.selected
	if selected_index < 0 or selected_index >= APPROVAL_MODE_IDS.size():
		return APPROVAL_MODE_IDS[0]
	return APPROVAL_MODE_IDS[selected_index]


func is_known_chat_mode(chat_mode: String) -> bool:
	return CHAT_MODE_IDS.has(chat_mode)


func is_known_provider(provider_id: String) -> bool:
	if _provider_button == null:
		return provider_id == "deepseek"
	for index: int in range(_provider_button.item_count):
		if str(_provider_button.get_item_metadata(index)) == provider_id:
			return true
	return false


func set_model_capabilities(capabilities: Array[Dictionary]) -> void:
	_model_capabilities.clear()
	for model_capabilities: Dictionary in capabilities:
		_model_capabilities.append(model_capabilities.duplicate(true))


func selected_model_supports_image() -> bool:
	if _model_button == null:
		return false
	var selected_index: int = _model_button.selected
	if selected_index < 0 or selected_index >= _model_capabilities.size():
		return false
	return bool(_model_capabilities[selected_index].get("imageInput", false))
