extends RefCounted

const TEST_ADAPTER_GROUP: StringName = &"daedalus_test_adapter"
const ACTIONS_META: StringName = &"daedalus_test_actions"
const LABEL_META: StringName = &"daedalus_test_label"
const STATE_META: StringName = &"daedalus_test_state"
const ALLOWED_ACTIONS: PackedStringArray = [
	"button_press",
	"key_press",
]


func is_adapter(node: Control) -> bool:
	return is_instance_valid(node) and node.is_in_group(TEST_ADAPTER_GROUP)


func get_supported_actions(node: Control) -> PackedStringArray:
	var result: PackedStringArray
	if not is_adapter(node):
		return result
	var declared_value: Variant = node.get_meta(ACTIONS_META, PackedStringArray())
	if typeof(declared_value) != TYPE_ARRAY and typeof(declared_value) != TYPE_PACKED_STRING_ARRAY:
		return result
	for value in declared_value:
		var action_name: String = str(value)
		if ALLOWED_ACTIONS.has(action_name) and not result.has(action_name):
			result.append(action_name)
	return result


func can_press(node: Control) -> bool:
	return get_supported_actions(node).has("button_press")


func read_label(node: Control) -> String:
	return str(node.get_meta(LABEL_META, "")).left(4096) if is_adapter(node) else ""


func read_state(node: Control) -> Variant:
	if not is_adapter(node):
		return null
	var value: Variant = node.get_meta(STATE_META, null)
	return value if value == null or value is String or value is bool or value is int or value is float else null
