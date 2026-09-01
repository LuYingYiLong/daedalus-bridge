extends RefCounted

const MAX_TEXT_LENGTH: int = 4096

const KEY_ALLOWLIST: Dictionary = {
	"enter": KEY_ENTER,
	"tab": KEY_TAB,
	"escape": KEY_ESCAPE,
	"backspace": KEY_BACKSPACE,
	"delete": KEY_DELETE,
	"arrow_up": KEY_UP,
	"arrow_down": KEY_DOWN,
	"arrow_left": KEY_LEFT,
	"arrow_right": KEY_RIGHT,
	"home": KEY_HOME,
	"end": KEY_END,
	"page_up": KEY_PAGEUP,
	"page_down": KEY_PAGEDOWN,
}

var test_adapter: RefCounted


func setup(adapter: RefCounted) -> void:
	test_adapter = adapter


func execute(node: Control, action: Dictionary, is_cancelled: Callable = Callable()) -> Dictionary:
	if _was_cancelled(is_cancelled):
		return _failure("runtime_tool_cancelled", "not_dispatched")
	if not _is_actionable(node):
		return _failure("runtime_node_not_actionable", "not_dispatched")
	var action_type: String = str(action.get("type", ""))
	if action_type == "button_press" or action_type == "toggle":
		return await _press_control(node, is_cancelled)
	if action_type == "set_text":
		return await _set_text(node, str(action.get("text", "")), is_cancelled)
	if action_type == "select":
		return await _select(node, int(action.get("index", -1)), is_cancelled)
	if action_type == "key_press":
		return await _press_key(node, str(action.get("key", "")), bool(action.get("shift", false)), bool(action.get("ctrl", false)), is_cancelled)
	return _failure("runtime_action_unsupported", "not_dispatched")


func _press_control(node: Control, is_cancelled: Callable) -> Dictionary:
	var button: BaseButton = node as BaseButton
	var adapter_press: bool = test_adapter != null and test_adapter.can_press(node)
	if button == null and not adapter_press:
		return _failure("runtime_button_unavailable", "not_dispatched")
	if button != null and button.disabled:
		return _failure("runtime_button_unavailable", "not_dispatched")
	var rect: Rect2 = node.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return _failure("runtime_control_rect_invalid", "not_dispatched")
	var viewport: Viewport = node.get_viewport()
	if viewport == null:
		return _failure("runtime_viewport_unavailable", "not_dispatched")
	if _was_cancelled(is_cancelled):
		return _failure("runtime_tool_cancelled", "not_dispatched")
	var tree: SceneTree = node.get_tree()
	var center: Vector2 = rect.get_center()
	var pressed_state: Array = [false]
	var on_pressed: Callable = func() -> void:
		pressed_state[0] = true
	if button != null:
		button.pressed.connect(on_pressed, CONNECT_ONE_SHOT)
	var pressed_event: InputEventMouseButton = InputEventMouseButton.new()
	pressed_event.button_index = MOUSE_BUTTON_LEFT
	pressed_event.button_mask = MOUSE_BUTTON_MASK_LEFT
	pressed_event.pressed = true
	pressed_event.position = center
	pressed_event.global_position = center
	viewport.push_input(pressed_event, true)
	await tree.process_frame
	var released_event: InputEventMouseButton = InputEventMouseButton.new()
	released_event.button_index = MOUSE_BUTTON_LEFT
	released_event.button_mask = 0
	released_event.pressed = false
	released_event.position = center
	released_event.global_position = center
	if is_instance_valid(viewport):
		viewport.push_input(released_event, true)
	await tree.process_frame
	if button != null and is_instance_valid(button) and button.pressed.is_connected(on_pressed):
		button.pressed.disconnect(on_pressed)
	if _was_cancelled(is_cancelled) or not is_instance_valid(node):
		return _failure("runtime_tool_cancelled", "unknown")
	return { "ok": true, "status": "completed" if bool(pressed_state[0]) else "dispatched", "channel": "godot_input" }


func _set_text(node: Control, text: String, is_cancelled: Callable) -> Dictionary:
	if text.length() > MAX_TEXT_LENGTH:
		return _failure("runtime_text_too_long", "not_dispatched")
	if node is LineEdit and not (node as LineEdit).editable:
		return _failure("runtime_text_read_only", "not_dispatched")
	if node is TextEdit and not (node as TextEdit).editable:
		return _failure("runtime_text_read_only", "not_dispatched")
	if not (node is LineEdit or node is TextEdit):
		return _failure("runtime_text_target_invalid", "not_dispatched")
	node.grab_focus()
	await node.get_tree().process_frame
	var clear_result: Dictionary = await _send_key(node, KEY_A, false, true, is_cancelled)
	if not bool(clear_result.get("ok", false)):
		return clear_result
	var backspace_result: Dictionary = await _send_key(node, KEY_BACKSPACE, false, false, is_cancelled)
	if not bool(backspace_result.get("ok", false)):
		return backspace_result
	for character in text:
		if _was_cancelled(is_cancelled):
			return _failure("runtime_tool_cancelled", "unknown")
		var event: InputEventKey = InputEventKey.new()
		event.pressed = true
		event.unicode = character.unicode_at(0)
		node.get_viewport().push_input(event, true)
		event = event.duplicate() as InputEventKey
		event.pressed = false
		node.get_viewport().push_input(event, true)
	await node.get_tree().process_frame
	var current_text: String = (node as LineEdit).text if node is LineEdit else (node as TextEdit).text
	return { "ok": true, "status": "completed" if current_text == text else "dispatched", "channel": "godot_input" }


func _select(node: Control, index: int, is_cancelled: Callable) -> Dictionary:
	if index < 0:
		return _failure("runtime_selection_invalid", "not_dispatched")
	if node is OptionButton:
		var option_button: OptionButton = node as OptionButton
		if option_button.disabled or index >= option_button.item_count:
			return _failure("runtime_selection_out_of_range", "not_dispatched")
		option_button.grab_focus()
		var home_result: Dictionary = await _send_key(option_button, KEY_HOME, false, false, is_cancelled)
		if not bool(home_result.get("ok", false)):
			return home_result
		for _step in range(index):
			var down_result: Dictionary = await _send_key(option_button, KEY_DOWN, false, false, is_cancelled)
			if not bool(down_result.get("ok", false)):
				return down_result
		var enter_result: Dictionary = await _send_key(option_button, KEY_ENTER, false, false, is_cancelled)
		if not bool(enter_result.get("ok", false)):
			return enter_result
		return { "ok": true, "status": "completed" if option_button.selected == index else "dispatched", "channel": "godot_input" }
	var tab_bar: TabBar = null
	if node is TabBar:
		tab_bar = node as TabBar
	elif node is TabContainer:
		tab_bar = (node as TabContainer).get_tab_bar()
	if tab_bar == null or index >= tab_bar.tab_count:
		return _failure("runtime_selection_target_invalid", "not_dispatched")
	tab_bar.grab_focus()
	var tab_home_result: Dictionary = await _send_key(tab_bar, KEY_HOME, false, false, is_cancelled)
	if not bool(tab_home_result.get("ok", false)):
		return tab_home_result
	for _step in range(index):
		var right_result: Dictionary = await _send_key(tab_bar, KEY_RIGHT, false, false, is_cancelled)
		if not bool(right_result.get("ok", false)):
			return right_result
	return { "ok": true, "status": "completed" if tab_bar.current_tab == index else "dispatched", "channel": "godot_input" }


func _press_key(node: Control, key_name: String, shift: bool, ctrl: bool, is_cancelled: Callable) -> Dictionary:
	var normalized_key: String = key_name.strip_edges().to_lower()
	var keycode: Key = KEY_NONE
	if normalized_key.begins_with("ctrl+"):
		ctrl = true
		var suffix: String = normalized_key.trim_prefix("ctrl+")
		if suffix in ["a", "f", "s", "z", "y"]:
			keycode = OS.find_keycode_from_string(suffix)
	elif normalized_key == "shift+tab":
		shift = true
		keycode = KEY_TAB
	elif KEY_ALLOWLIST.has(normalized_key):
		keycode = int(KEY_ALLOWLIST[normalized_key])
	if keycode == KEY_NONE:
		return _failure("runtime_key_not_allowed", "not_dispatched")
	node.grab_focus()
	return await _send_key(node, keycode, shift, ctrl, is_cancelled)


func _send_key(node: Control, keycode: Key, shift: bool, ctrl: bool, is_cancelled: Callable = Callable()) -> Dictionary:
	if _was_cancelled(is_cancelled):
		return _failure("runtime_tool_cancelled", "not_dispatched")
	var viewport: Viewport = node.get_viewport()
	if viewport == null:
		return _failure("runtime_viewport_unavailable", "not_dispatched")
	var pressed_event: InputEventKey = InputEventKey.new()
	pressed_event.keycode = keycode
	pressed_event.physical_keycode = keycode
	pressed_event.shift_pressed = shift
	pressed_event.ctrl_pressed = ctrl
	pressed_event.pressed = true
	viewport.push_input(pressed_event, true)
	var released_event: InputEventKey = pressed_event.duplicate() as InputEventKey
	released_event.pressed = false
	viewport.push_input(released_event, true)
	await node.get_tree().process_frame
	return { "ok": true, "status": "dispatched", "channel": "godot_input" }


func _is_actionable(node: Control) -> bool:
	if not is_instance_valid(node) or not node.is_inside_tree() or not node.is_visible_in_tree() or node.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return false
	var rect: Rect2 = node.get_global_rect()
	var center: Vector2 = rect.get_center()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0 or not node.get_viewport_rect().has_point(center):
		return false
	var ancestor: Control = node
	while ancestor != null:
		if not ancestor.is_visible_in_tree():
			return false
		if ancestor.clip_contents and not ancestor.get_global_rect().has_point(center):
			return false
		ancestor = ancestor.get_parent_control()
	return true


func _failure(error: String, status: String) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"status": status,
		"channel": "godot_input",
	}


func _was_cancelled(is_cancelled: Callable) -> bool:
	return is_cancelled.is_valid() and bool(is_cancelled.call())
