extends RefCounted

const MAX_DEPTH: int = 20
const MAX_NODES: int = 1000
const MAX_TEXT_LENGTH: int = 4096

var observation_id: String
var runtime_instance_id: String
var tree_revision: int
var nodes_by_id: Dictionary
var node_count: int
var truncated: bool
var test_adapter: RefCounted


func setup(adapter: RefCounted) -> void:
	test_adapter = adapter


func observe(root: Node, next_runtime_instance_id: String, next_tree_revision: int) -> Dictionary:
	clear()
	runtime_instance_id = next_runtime_instance_id
	tree_revision = next_tree_revision
	observation_id = "%s:%d:%d" % [runtime_instance_id, Time.get_ticks_usec(), randi()]
	if root == null or not is_instance_valid(root):
		return {
			"ok": false,
			"error": "runtime_scene_unavailable",
		}
	var controls: Array = []
	_collect_controls(root, root, 0, controls)
	_attach_child_ids(controls)
	return {
		"ok": true,
		"runtimeInstanceId": runtime_instance_id,
		"observationId": observation_id,
		"treeRevision": tree_revision,
		"scenePath": root.scene_file_path,
		"rootName": str(root.name),
		"nodes": controls,
		"nodeCount": node_count,
		"truncated": truncated,
		"capturedAtMsec": Time.get_ticks_msec(),
	}


func clear() -> void:
	observation_id = ""
	runtime_instance_id = ""
	tree_revision = -1
	nodes_by_id.clear()
	node_count = 0
	truncated = false


func resolve_node(requested_observation_id: String, node_id: String, current_tree_revision: int) -> Dictionary:
	if requested_observation_id != observation_id or observation_id.is_empty():
		return { "ok": false, "error": "runtime_observation_stale" }
	if current_tree_revision != tree_revision:
		return { "ok": false, "error": "runtime_tree_changed" }
	var reference: WeakRef = nodes_by_id.get(node_id) as WeakRef
	if reference == null:
		return { "ok": false, "error": "runtime_node_unknown" }
	var value: Variant = reference.get_ref()
	if not value is Control:
		return { "ok": false, "error": "runtime_node_expired" }
	var node: Control = value as Control
	if not is_instance_valid(node) or not node.is_inside_tree():
		return { "ok": false, "error": "runtime_node_expired" }
	return { "ok": true, "node": node }


func serialize_node(node: Control, root: Node) -> Dictionary:
	var node_id: String = _create_node_id(node)
	var rect: Rect2 = node.get_global_rect()
	return {
		"nodeId": node_id,
		"type": node.get_class(),
		"name": str(node.name).left(240),
		"nodePath": str(root.get_path_to(node)).left(1024),
		"visible": node.visible,
		"visibleInTree": node.is_visible_in_tree(),
		"enabled": _is_enabled(node),
		"globalRect": {
			"x": rect.position.x,
			"y": rect.position.y,
			"width": rect.size.x,
			"height": rect.size.y,
		},
		"text": _read_text(node),
		"supportedActions": _get_supported_actions(node),
		"properties": _read_properties(node),
		"children": [],
	}


func _collect_controls(node: Node, root: Node, depth: int, output: Array) -> void:
	if node_count >= MAX_NODES:
		truncated = true
		return
	if depth > MAX_DEPTH:
		truncated = true
		return
	if node is Control:
		output.append(serialize_node(node as Control, root))
		node_count += 1
	for child_value in node.get_children():
		if node_count >= MAX_NODES:
			truncated = true
			return
		var child: Node = child_value as Node
		if child != null:
			_collect_controls(child, root, depth + 1, output)


func _create_node_id(node: Control) -> String:
	var node_id: String = "node-%d-%d" % [node.get_instance_id(), node_count + 1]
	nodes_by_id[node_id] = weakref(node)
	return node_id


func _attach_child_ids(nodes: Array) -> void:
	var nodes_by_path: Dictionary = {}
	for value in nodes:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = value as Dictionary
		nodes_by_path[str(item.get("nodePath", ""))] = item
	for value in nodes:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = value as Dictionary
		var segments: PackedStringArray = str(item.get("nodePath", "")).split("/")
		while segments.size() > 1:
			segments.remove_at(segments.size() - 1)
			var parent_path: String = "/".join(segments)
			if not nodes_by_path.has(parent_path):
				continue
			var parent: Dictionary = nodes_by_path[parent_path] as Dictionary
			var children: Array = parent.get("children", []) as Array
			children.append(str(item.get("nodeId", "")))
			parent["children"] = children
			break


func _get_supported_actions(node: Control) -> PackedStringArray:
	var actions: PackedStringArray
	if node is BaseButton and not (node as BaseButton).disabled:
		actions.append("button_press")
		if (node as BaseButton).toggle_mode:
			actions.append("toggle")
	if node is LineEdit and (node as LineEdit).editable:
		actions.append("set_text")
	if node is TextEdit and (node as TextEdit).editable:
		actions.append("set_text")
	if node is OptionButton and not (node as OptionButton).disabled:
		actions.append("select")
	if node is TabBar or node is TabContainer:
		actions.append("select")
	if node.focus_mode != Control.FOCUS_NONE:
		actions.append("key_press")
	if test_adapter != null:
		for action_name in test_adapter.get_supported_actions(node):
			if not actions.has(action_name):
				actions.append(action_name)
	return actions


func _is_enabled(node: Control) -> bool:
	if node is BaseButton:
		return not (node as BaseButton).disabled
	if node is LineEdit:
		return (node as LineEdit).editable
	if node is TextEdit:
		return (node as TextEdit).editable
	return true


func _read_text(node: Control) -> String:
	if node is BaseButton:
		return (node as BaseButton).text.left(MAX_TEXT_LENGTH)
	if node is LineEdit:
		return (node as LineEdit).text.left(MAX_TEXT_LENGTH)
	if node is TextEdit:
		return (node as TextEdit).text.left(MAX_TEXT_LENGTH)
	if node is Label:
		return (node as Label).text.left(MAX_TEXT_LENGTH)
	if test_adapter != null:
		return str(test_adapter.read_label(node)).left(MAX_TEXT_LENGTH)
	return ""


func _read_properties(node: Control) -> Dictionary:
	var properties: Dictionary = {}
	if node is BaseButton:
		properties["buttonPressed"] = (node as BaseButton).button_pressed
		properties["disabled"] = (node as BaseButton).disabled
	if node is LineEdit:
		properties["editable"] = (node as LineEdit).editable
	if node is TextEdit:
		properties["editable"] = (node as TextEdit).editable
	if node is OptionButton:
		properties["selected"] = (node as OptionButton).selected
	if node is TabBar:
		properties["currentTab"] = (node as TabBar).current_tab
	if node is TabContainer:
		properties["currentTab"] = (node as TabContainer).current_tab
	if test_adapter != null and test_adapter.is_adapter(node):
		properties["testAdapter"] = true
		properties["testState"] = test_adapter.read_state(node)
	return properties
