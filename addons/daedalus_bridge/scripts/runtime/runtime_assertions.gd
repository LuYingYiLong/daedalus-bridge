extends RefCounted

const MAX_WAIT_MSEC: int = 30_000
const ALLOWED_PROPERTIES: PackedStringArray = [
	"exists",
	"visible",
	"visibleInTree",
	"enabled",
	"text",
	"buttonPressed",
	"selected",
	"currentTab",
	"testState",
]


func assert_node(node: Control, assertion: Dictionary) -> Dictionary:
	var property_name: String = str(assertion.get("property", ""))
	if not ALLOWED_PROPERTIES.has(property_name):
		return { "ok": false, "error": "runtime_assertion_property_not_allowed" }
	var actual: Variant = _read_property(node, property_name)
	var expected: Variant = assertion.get("equals")
	return {
		"ok": actual == expected,
		"status": "completed" if actual == expected else "failed",
		"property": property_name,
		"expected": expected,
		"actual": actual,
	}


func wait_for_node(node: Control, assertion: Dictionary, timeout_msec: int, is_cancelled: Callable = Callable()) -> Dictionary:
	var bounded_timeout: int = clampi(timeout_msec, 1, MAX_WAIT_MSEC)
	var started_at: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_at < bounded_timeout:
		if is_cancelled.is_valid() and bool(is_cancelled.call()):
			return { "ok": false, "status": "failed", "error": "runtime_tool_cancelled" }
		if not is_instance_valid(node) or not node.is_inside_tree():
			if str(assertion.get("property", "")) == "exists" and assertion.get("equals") == false:
				return { "ok": true, "status": "completed", "elapsedMsec": Time.get_ticks_msec() - started_at }
			return { "ok": false, "status": "failed", "error": "runtime_node_expired" }
		var result: Dictionary = assert_node(node, assertion)
		if bool(result.get("ok", false)):
			result["elapsedMsec"] = Time.get_ticks_msec() - started_at
			return result
		await node.get_tree().process_frame
	return {
		"ok": false,
		"status": "failed",
		"error": "runtime_wait_timeout",
		"elapsedMsec": Time.get_ticks_msec() - started_at,
	}


func _read_property(node: Control, property_name: String) -> Variant:
	if property_name == "exists":
		return is_instance_valid(node) and node.is_inside_tree()
	if property_name == "visible":
		return node.visible
	if property_name == "visibleInTree":
		return node.is_visible_in_tree()
	if property_name == "enabled":
		return not (node as BaseButton).disabled if node is BaseButton else true
	if property_name == "text":
		if node is BaseButton:
			return (node as BaseButton).text
		if node is LineEdit:
			return (node as LineEdit).text
		if node is TextEdit:
			return (node as TextEdit).text
		if node is Label:
			return (node as Label).text
	if property_name == "buttonPressed" and node is BaseButton:
		return (node as BaseButton).button_pressed
	if property_name == "selected" and node is OptionButton:
		return (node as OptionButton).selected
	if property_name == "currentTab":
		if node is TabBar:
			return (node as TabBar).current_tab
		if node is TabContainer:
			return (node as TabContainer).current_tab
	if property_name == "testState" and node.is_in_group(&"daedalus_test_adapter"):
		var value: Variant = node.get_meta(&"daedalus_test_state", null)
		return value if value == null or value is String or value is bool or value is int or value is float else null
	return null
