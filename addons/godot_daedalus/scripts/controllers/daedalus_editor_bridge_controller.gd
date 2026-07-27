@tool
class_name DaedalusEditorBridgeController
extends Node

signal request_ready(method: String, params: Dictionary, request_prefix: String)
signal live_context_changed(context_id: String, context: Dictionary)

const MAIN_HELPERS: GDScript = preload("res://addons/godot_daedalus/scripts/main_helpers.gd")
const RPC_METHODS: GDScript = preload("res://addons/godot_daedalus/scripts/rpc_methods.gd")
const LIVE_EDITOR_SELECTION_CONTEXT_ID: String = "editor-selection-live"
const LIVE_SCRIPT_SELECTION_CONTEXT_ID: String = "script-selection-live"
const LIVE_FILESYSTEM_SELECTION_CONTEXT_ID: String = "filesystem-selection-live"
const SCRIPT_SELECTION_PREVIEW_LIMIT: int = 2000
const SCRIPT_LINE_PREVIEW_LIMIT: int = 500
const SCRIPT_EDITOR_TEXT_PREVIEW_LIMIT: int = 12000
const FILESYSTEM_CONTEXT_MAX_PATHS: int = 40
const EDITOR_CONTEXT_POLL_INTERVAL_MSEC: int = 500

var editor_plugin: EditorPlugin
var editor_interface: EditorInterface
var editor_selection: EditorSelection
var editor_undo_redo: EditorUndoRedoManager
var editor_script_editor: Object
var editor_context_update_queued: bool
var editor_context_next_poll_msec: int
var editor_instance_id: String


func get_editor_instance_id() -> String:
	if not editor_instance_id.is_empty():
		return editor_instance_id
	var project_path: String = ProjectSettings.globalize_path("res://").trim_suffix("/")
	var project_hash: int = hash(project_path)
	editor_instance_id = "godot-editor-%s-%d" % [str(project_hash).replace("-", "m"), Time.get_ticks_usec()]
	return editor_instance_id


func set_editor_instance_id(instance_id: String) -> void:
	var normalized_instance_id: String = instance_id.strip_edges()
	if not normalized_instance_id.is_empty():
		editor_instance_id = normalized_instance_id


func get_undo_redo() -> EditorUndoRedoManager:
	return editor_undo_redo


func get_interface() -> EditorInterface:
	return editor_interface


func get_selection() -> EditorSelection:
	return editor_selection


func setup(plugin: EditorPlugin) -> void:
	editor_plugin = plugin
	if editor_plugin == null:
		return

	editor_interface = editor_plugin.get_editor_interface()
	editor_selection = editor_interface.get_selection()
	editor_undo_redo = editor_plugin.get_undo_redo()
	editor_script_editor = editor_interface.get_script_editor()
	if editor_selection != null and not editor_selection.selection_changed.is_connected(_on_editor_selection_changed):
		editor_selection.selection_changed.connect(_on_editor_selection_changed)
	var script_changed_callable: Callable = Callable(self, "_on_editor_script_changed")
	if editor_script_editor != null and editor_script_editor.has_signal("editor_script_changed") and not editor_script_editor.is_connected("editor_script_changed", script_changed_callable):
		editor_script_editor.connect("editor_script_changed", script_changed_callable)
	queue_context_update()


func _on_editor_selection_changed() -> void:
	queue_context_update()


func _on_editor_script_changed(_script: Resource) -> void:
	queue_context_update()


func poll_live_context() -> void:
	if editor_interface == null:
		return

	var now_msec: int = Time.get_ticks_msec()
	if now_msec < editor_context_next_poll_msec:
		return

	editor_context_next_poll_msec = now_msec + EDITOR_CONTEXT_POLL_INTERVAL_MSEC
	queue_context_update()


func queue_context_update() -> void:
	if editor_context_update_queued:
		return

	editor_context_update_queued = true
	_send_editor_context_update.call_deferred()


func _send_editor_context_update() -> void:
	editor_context_update_queued = false
	if editor_interface == null:
		return

	var edited_root: Node = get_edited_scene_root()
	var selected_nodes: Array[Dictionary] = []
	if editor_selection != null and edited_root != null:
		var raw_selected_nodes: Array[Node] = editor_selection.get_selected_nodes()
		for selected_node: Node in raw_selected_nodes:
			if selected_node == null:
				continue
			selected_nodes.append(serialize_editor_node_summary(selected_node, edited_root))

	var script_context: Dictionary = collect_script_selection_context()
	var filesystem_selection_context: Dictionary = collect_filesystem_selection_context()
	_sync_live_editor_selection_context(edited_root, selected_nodes)
	_sync_live_script_selection_context(script_context)
	_sync_live_filesystem_selection_context(filesystem_selection_context)
	var params: Dictionary[String, Variant] = {
		"hasEditor": true,
		"workspaceId": ProjectSettings.globalize_path("res://"),
		"editorInstanceId": get_editor_instance_id(),
		"activeScenePath": get_scene_resource_path(edited_root) if edited_root != null else "",
		"selectedNodeCount": selected_nodes.size(),
		"selectedNodes": selected_nodes,
		"capabilities": {
			"sceneViewCapture": true
		},
		"scriptContext": script_context if not script_context.is_empty() else null,
		"filesystemSelection": filesystem_selection_context if not filesystem_selection_context.is_empty() else null,
		"updatedAt": MAIN_HELPERS.get_utc_timestamp()
	}
	if edited_root != null:
		params["editedSceneRoot"] = serialize_editor_node_summary(edited_root, edited_root)

	request_ready.emit(RPC_METHODS.EDITOR_CONTEXT_UPDATE, params, "editor-context")


func _sync_live_editor_selection_context(edited_root: Node, selected_nodes: Array[Dictionary]) -> void:
	if edited_root == null or selected_nodes.is_empty():
		live_context_changed.emit(LIVE_EDITOR_SELECTION_CONTEXT_ID, {})
		return

	var scene_path: String = get_scene_resource_path(edited_root)
	var title_text: String = "Selected Node (%d)" % selected_nodes.size()
	var selected_names: PackedStringArray
	for selected_node_info: Dictionary in selected_nodes:
		selected_names.append(str(selected_node_info.get("name", "")))

	var context: Dictionary = {
		"id": LIVE_EDITOR_SELECTION_CONTEXT_ID,
		"kind": "editor_selection",
		"title": title_text,
		"subtitle": scene_path,
		"pinned": false,
		"source": "editor",
		"resourcePath": scene_path,
		"summary": "Currently selected node in the editor: %s" % ", ".join(selected_names),
		"data": {
			"selectedNodes": selected_nodes
		}
	}
	live_context_changed.emit(LIVE_EDITOR_SELECTION_CONTEXT_ID, context)


func _sync_live_script_selection_context(context: Dictionary) -> void:
	live_context_changed.emit(LIVE_SCRIPT_SELECTION_CONTEXT_ID, context)


func _sync_live_filesystem_selection_context(context: Dictionary) -> void:
	live_context_changed.emit(LIVE_FILESYSTEM_SELECTION_CONTEXT_ID, context)


func collect_script_selection_context() -> Dictionary:
	if editor_script_editor == null:
		return {}
	if not editor_script_editor.has_method("get_current_editor"):
		return {}

	var current_editor_value: Variant = editor_script_editor.call("get_current_editor")
	if not (current_editor_value is Object):
		return {}
	var current_editor_object: Object = current_editor_value as Object
	if current_editor_object == null or not current_editor_object.has_method("get_base_editor"):
		return {}

	var base_editor_value: Variant = current_editor_object.call("get_base_editor")
	if not (base_editor_value is TextEdit):
		return {}
	var base_text_edit: TextEdit = base_editor_value as TextEdit
	var line_count: int = base_text_edit.get_line_count()
	if line_count <= 0:
		return {}

	var editor_text: String = base_text_edit.text
	var resource_path: String = _get_current_script_resource_path(current_editor_object)
	var caret_line_zero: int = clampi(base_text_edit.get_caret_line(0), 0, maxi(line_count - 1, 0))
	var caret_column_zero: int = maxi(base_text_edit.get_caret_column(0), 0)
	var has_script_selection: bool = base_text_edit.has_selection(0)
	var line_start: int = caret_line_zero + 1
	var column_start: int = caret_column_zero + 1
	var line_end: int = line_start
	var column_end: int = column_start
	var data: Dictionary = {
		"caretLine": line_start,
		"caretColumn": column_start,
		"hasSelection": has_script_selection,
		"editorTextPreview": _clip_context_text(editor_text, SCRIPT_EDITOR_TEXT_PREVIEW_LIMIT),
		"editorTextTruncated": editor_text.length() > SCRIPT_EDITOR_TEXT_PREVIEW_LIMIT,
		"editorTextLineCount": line_count,
		"resourcePathAvailable": not resource_path.is_empty()
	}

	if has_script_selection:
		line_start = base_text_edit.get_selection_from_line(0) + 1
		column_start = base_text_edit.get_selection_from_column(0) + 1
		line_end = base_text_edit.get_selection_to_line(0) + 1
		column_end = base_text_edit.get_selection_to_column(0) + 1
		var selected_text: String = base_text_edit.get_selected_text(0)
		data["selectedTextPreview"] = _clip_context_text(selected_text, SCRIPT_SELECTION_PREVIEW_LIMIT)
		data["selectedTextTruncated"] = selected_text.length() > SCRIPT_SELECTION_PREVIEW_LIMIT
	else:
		var current_line_text: String = base_text_edit.get_line(caret_line_zero)
		data["lineTextPreview"] = _clip_context_text(current_line_text, SCRIPT_LINE_PREVIEW_LIMIT)
		data["lineTextTruncated"] = current_line_text.length() > SCRIPT_LINE_PREVIEW_LIMIT

	data["lineStart"] = line_start
	data["columnStart"] = column_start
	data["lineEnd"] = line_end
	data["columnEnd"] = column_end

	var script_name: String = resource_path.get_file()
	if script_name.is_empty():
		script_name = "未保存脚本"
	var range_text: String = _format_script_selection_range(line_start, line_end)
	var selection_label: String = "选区" if has_script_selection else "光标行"
	var context: Dictionary = {
		"id": LIVE_SCRIPT_SELECTION_CONTEXT_ID,
		"kind": "script_selection",
		"title": "%s:%s" % [script_name, range_text],
		"subtitle": "%s · %d:%d-%d:%d" % [selection_label, line_start, column_start, line_end, column_end],
		"pinned": false,
		"source": "editor",
		"summary": "Godot 脚本编辑器当前%s，行列使用 1-based：%d:%d-%d:%d。" % [selection_label, line_start, column_start, line_end, column_end],
		"data": data
	}
	if not resource_path.is_empty():
		context["resourcePath"] = resource_path
		context["scriptPath"] = resource_path
	return context


func _get_current_script_resource_path(current_editor_object: Object) -> String:
	var script_resource: Resource
	if editor_script_editor != null and editor_script_editor.has_method("get_current_script"):
		var script_value: Variant = editor_script_editor.call("get_current_script")
		if script_value is Resource:
			script_resource = script_value as Resource

	if script_resource == null and current_editor_object.has_method("get_edited_resource"):
		var edited_resource_value: Variant = current_editor_object.call("get_edited_resource")
		if edited_resource_value is Resource:
			script_resource = edited_resource_value as Resource

	if script_resource == null:
		return ""

	return script_resource.resource_path


func collect_filesystem_selection_context() -> Dictionary:
	if editor_interface == null:
		return {}

	var selected_paths: PackedStringArray = editor_interface.get_selected_paths()
	if selected_paths.is_empty():
		return {}

	var selected_path_items: Array[Dictionary]
	var selected_names: PackedStringArray
	var truncated: bool = false
	for index: int in range(selected_paths.size()):
		if selected_path_items.size() >= FILESYSTEM_CONTEXT_MAX_PATHS:
			truncated = true
			break

		var selected_path: String = selected_paths[index].strip_edges()
		if selected_path.is_empty():
			continue

		var normalized_path: String = selected_path.trim_suffix("/")
		var selected_kind: String = "folder" if DirAccess.dir_exists_absolute(selected_path) else "file"
		var selected_name: String = normalized_path.get_file()
		if selected_name.is_empty():
			selected_name = selected_path
		var selected_item: Dictionary = {
			"resourcePath": selected_path,
			"kind": selected_kind,
			"name": selected_name
		}
		if selected_kind == "file":
			selected_item["extension"] = selected_path.get_extension()
		selected_path_items.append(selected_item)
		selected_names.append(selected_name)

	if selected_path_items.is_empty():
		return {}

	var first_item: Dictionary = selected_path_items[0]
	var first_path: String = str(first_item.get("resourcePath", ""))
	var title_text: String = "文件系统选中项 (%d)" % selected_path_items.size()
	if selected_path_items.size() == 1:
		title_text = str(first_item.get("name", title_text))

	var subtitle_text: String = first_path
	if selected_path_items.size() > 1:
		subtitle_text = "%s 等 %d 项" % [first_path, selected_path_items.size()]

	return {
		"id": LIVE_FILESYSTEM_SELECTION_CONTEXT_ID,
		"kind": "filesystem_selection",
		"title": title_text,
		"subtitle": subtitle_text,
		"pinned": false,
		"source": "editor",
		"resourcePath": first_path,
		"summary": "FileSystem Dock 当前选中：%s%s" % [", ".join(selected_names.slice(0, 6)), " ..." if truncated or selected_names.size() > 6 else ""],
		"data": {
			"selectedPaths": selected_path_items,
			"truncated": truncated
		}
	}


func _format_script_selection_range(line_start: int, line_end: int) -> String:
	if line_start == line_end:
		return "%d" % line_start
	return "%d-%d" % [line_start, line_end]


func _clip_context_text(source_text: String, max_chars: int) -> String:
	if source_text.length() <= max_chars:
		return source_text
	return source_text.substr(0, max_chars)


func get_edited_scene_root() -> Node:
	if editor_interface == null:
		return null

	return editor_interface.get_edited_scene_root()


func get_scene_resource_path(scene_root: Node) -> String:
	if scene_root == null:
		return ""
	return scene_root.scene_file_path


func get_relative_node_path(scene_root: Node, target_node: Node) -> String:
	if scene_root == null or target_node == null:
		return ""
	if scene_root == target_node:
		return "."
	return str(scene_root.get_path_to(target_node))


func _find_editor_node(scene_path: String, node_path: String) -> Node:
	var edited_root: Node = get_edited_scene_root()
	if edited_root == null:
		return null

	var requested_scene_path: String = scene_path.strip_edges()
	if not requested_scene_path.is_empty() and requested_scene_path != get_scene_resource_path(edited_root):
		return null

	var requested_node_path: String = node_path.strip_edges()
	if requested_node_path.is_empty() or requested_node_path == ".":
		return edited_root
	if not edited_root.has_node(NodePath(requested_node_path)):
		return null

	return edited_root.get_node(NodePath(requested_node_path))


func serialize_editor_node_summary(target_node: Node, scene_root: Node) -> Dictionary:
	var script_path: String = get_node_script_path(target_node)
	var summary: Dictionary = {
		"name": target_node.name,
		"path": get_relative_node_path(scene_root, target_node),
		"type": target_node.get_class(),
		"ownerPath": get_relative_node_path(scene_root, target_node.owner) if target_node.owner != null else "",
		"childCount": target_node.get_child_count(),
		"properties": _get_node_key_properties(target_node)
	}
	if not script_path.is_empty():
		summary["scriptPath"] = script_path
	return summary


func _serialize_editor_node_deep(target_node: Node, scene_root: Node, depth: int = 0) -> Dictionary:
	var summary: Dictionary = serialize_editor_node_summary(target_node, scene_root)
	if depth >= 2:
		return summary

	var children: Array[Dictionary] = []
	for child_node: Node in target_node.get_children():
		children.append(_serialize_editor_node_deep(child_node, scene_root, depth + 1))
	summary["children"] = children
	return summary


func get_node_script_path(target_node: Node) -> String:
	var script_value: Variant = target_node.get_script()
	if script_value is Script:
		var script_resource: Script = script_value as Script
		return script_resource.resource_path
	return ""


func _get_node_key_properties(target_node: Node) -> Dictionary:
	var properties: Dictionary = {}
	for property_name: String in ["text", "tooltip_text", "visible", "disabled", "placeholder_text", "position", "size", "custom_minimum_size"]:
		if _node_has_property(target_node, property_name):
			var property_value: Variant = target_node.get(property_name)
			properties[property_name] = _compact_variant_for_json(property_value)
	return properties


func _node_has_property(target_node: Node, property_name: String) -> bool:
	for property_info: Dictionary in target_node.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			return true
	return false


func _compact_variant_for_json(value: Variant) -> Variant:
	if value is Vector2:
		var vector_value: Vector2 = value as Vector2
		return { "x": vector_value.x, "y": vector_value.y }
	if value is Vector2i:
		var vector_i_value: Vector2i = value as Vector2i
		return { "x": vector_i_value.x, "y": vector_i_value.y }
	if value is Color:
		var color_value: Color = value as Color
		return color_value.to_html(true)
	if value is Resource:
		var resource_value: Resource = value as Resource
		return resource_value.resource_path
	if typeof(value) == TYPE_ARRAY:
		var source_array: Array = value as Array
		var compact_array: Array = []
		for item: Variant in source_array:
			compact_array.append(_compact_variant_for_json(item))
		return compact_array
	if typeof(value) == TYPE_DICTIONARY:
		var source_dictionary: Dictionary = value as Dictionary
		var compact_dictionary: Dictionary = {}
		for key_value: Variant in source_dictionary.keys():
			compact_dictionary[str(key_value)] = _compact_variant_for_json(source_dictionary[key_value])
		return compact_dictionary
	return value


func summarize_editor_node(target_node: Node) -> String:
	var node_path: String = ""
	var edited_root: Node = get_edited_scene_root()
	if edited_root != null:
		node_path = get_relative_node_path(edited_root, target_node)
	return "%s `%s` (%d children)" % [target_node.get_class(), node_path, target_node.get_child_count()]


func handle_tool_requested(data: Dictionary) -> void:
	var call_id: String = str(data.get("callId", ""))
	var tool_name: String = str(data.get("toolName", ""))
	var args_value: Variant = data.get("args", {})
	var args: Dictionary = args_value as Dictionary if typeof(args_value) == TYPE_DICTIONARY else {}
	var ok: bool = true
	var result: Variant = {}
	var error_message: String = ""

	if call_id.is_empty():
		return

	if tool_name == "capture_scene_view":
		_complete_editor_capture_scene_view.call_deferred(call_id, args)
		return

	if tool_name == "inspect_node":
		result = _execute_editor_inspect_node(args)
	elif tool_name == "apply_scene_patch":
		result = _execute_editor_apply_scene_patch(args)
	elif tool_name == "refresh_filesystem":
		result = _execute_editor_refresh_filesystem(args)
	else:
		ok = false
		error_message = "Unknown editor tool: %s" % tool_name

	if typeof(result) == TYPE_DICTIONARY and bool((result as Dictionary).get("ok", true)) == false:
		ok = false
		error_message = str((result as Dictionary).get("error", "Editor tool failed"))

	_emit_editor_tool_result(call_id, ok, result, error_message)


func _complete_editor_capture_scene_view(call_id: String, args: Dictionary) -> void:
	var result: Dictionary = await _execute_editor_capture_scene_view(args)
	var ok: bool = bool(result.get("ok", true))
	var error_message: String = str(result.get("error", "Editor tool failed")) if not ok else ""
	_emit_editor_tool_result(call_id, ok, result, error_message)


func _emit_editor_tool_result(call_id: String, ok: bool, result: Variant, error_message: String) -> void:
	request_ready.emit(
		RPC_METHODS.EDITOR_TOOL_RESULT,
		{
			"callId": call_id,
			"ok": ok,
			"result": result if ok else null,
			"error": error_message if not ok else ""
		},
		"editor-tool-result"
	)


func _execute_editor_inspect_node(args: Dictionary) -> Dictionary:
	var scene_path: String = str(args.get("scenePath", ""))
	var node_path: String = str(args.get("nodePath", "."))
	var target_node: Node = _find_editor_node(scene_path, node_path)
	var edited_root: Node = get_edited_scene_root()
	if target_node == null or edited_root == null:
		return { "ok": false, "error": "editor_node_not_found" }

	return {
		"ok": true,
		"node": _serialize_editor_node_deep(target_node, edited_root)
	}


func _execute_editor_capture_scene_view(args: Dictionary) -> Dictionary:
	if editor_interface == null:
		return { "ok": false, "error": "editor_interface_unavailable" }

	var requested_view: String = str(args.get("view", "auto")).to_lower().strip_edges()
	if requested_view.is_empty():
		requested_view = "auto"
	if requested_view != "auto" and requested_view != "2d" and requested_view != "3d":
		return { "ok": false, "error": "scene_view_invalid_view" }

	var selected_view: String = requested_view
	if selected_view == "auto":
		var edited_root: Node = get_edited_scene_root()
		if edited_root == null:
			return { "ok": false, "error": "scene_view_unavailable" }
		selected_view = "2d" if edited_root is Node2D or edited_root is Control else "3d"

	editor_interface.set_main_screen_editor("2D" if selected_view == "2d" else "3D")
	await RenderingServer.frame_post_draw

	var candidates: Array[Dictionary] = []
	var viewport_2d: SubViewport = editor_interface.get_editor_viewport_2d()
	if viewport_2d != null and _is_scene_viewport_capturable(viewport_2d) and selected_view == "2d":
		candidates.append({ "view": "2d", "viewportIndex": 0, "viewport": viewport_2d })

	if selected_view == "3d":
		for viewport_index: int in range(4):
			var viewport_3d: SubViewport = editor_interface.get_editor_viewport_3d(viewport_index)
			if viewport_3d != null and _is_scene_viewport_capturable(viewport_3d):
				candidates.append({ "view": "3d", "viewportIndex": viewport_index, "viewport": viewport_3d })

	if candidates.is_empty():
		return { "ok": false, "error": "scene_view_unavailable" }
	if candidates.size() != 1:
		return { "ok": false, "error": "scene_view_ambiguous" }

	var candidate: Dictionary = candidates[0]
	var viewport_value: Variant = candidate.get("viewport", null)
	if not (viewport_value is SubViewport):
		return { "ok": false, "error": "scene_view_unavailable" }
	var viewport: SubViewport = viewport_value as SubViewport
	var viewport_texture: Texture2D = viewport.get_texture()
	if viewport_texture == null:
		return { "ok": false, "error": "scene_view_texture_unavailable" }
	var scene_image: Image = viewport_texture.get_image()
	if scene_image == null or scene_image.is_empty():
		return { "ok": false, "error": "scene_view_image_unavailable" }

	var payload: Dictionary = _encode_scene_view_capture(scene_image)
	if payload.is_empty():
		return { "ok": false, "error": "scene_view_image_too_large" }
	payload["ok"] = true
	payload["view"] = str(candidate.get("view", "unknown"))
	payload["viewportIndex"] = int(candidate.get("viewportIndex", 0))
	var edited_root: Node = get_edited_scene_root()
	payload["activeScenePath"] = get_scene_resource_path(edited_root) if edited_root != null else ""
	return payload


func _is_scene_viewport_capturable(viewport: SubViewport) -> bool:
	if viewport.size.x <= 0 or viewport.size.y <= 0:
		return false
	var viewport_container: CanvasItem = _get_viewport_container(viewport)
	if viewport_container != null and not viewport_container.is_visible_in_tree():
		return false
	var viewport_texture: Texture2D = viewport.get_texture()
	return viewport_texture != null and viewport_texture.get_width() > 0 and viewport_texture.get_height() > 0


func _get_viewport_container(viewport: SubViewport) -> CanvasItem:
	var ancestor: Node = viewport.get_parent()
	while ancestor != null:
		if ancestor is CanvasItem:
			return ancestor as CanvasItem
		ancestor = ancestor.get_parent()
	return null


func _encode_scene_view_capture(scene_image: Image) -> Dictionary:
	var image_copy: Image = scene_image.duplicate() as Image
	if image_copy == null or image_copy.is_empty():
		return {}

	var largest_side: int = maxi(image_copy.get_width(), image_copy.get_height())
	if largest_side > 1280:
		var scale: float = 1280.0 / float(largest_side)
		var initial_size: Vector2i = Vector2i(
			maxi(1, roundi(float(image_copy.get_width()) * scale)),
			maxi(1, roundi(float(image_copy.get_height()) * scale))
		)
		image_copy.resize(initial_size.x, initial_size.y, Image.INTERPOLATE_LANCZOS)

	var png_bytes: PackedByteArray = image_copy.save_png_to_buffer()
	while png_bytes.size() > 1024 * 1024:
		var current_largest_side: int = maxi(image_copy.get_width(), image_copy.get_height())
		if current_largest_side <= 512:
			return {}
		var target_largest_side: int = maxi(512, floori(float(current_largest_side) * 0.75))
		var resize_scale: float = float(target_largest_side) / float(current_largest_side)
		var target_size: Vector2i = Vector2i(
			maxi(1, roundi(float(image_copy.get_width()) * resize_scale)),
			maxi(1, roundi(float(image_copy.get_height()) * resize_scale))
		)
		image_copy.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
		png_bytes = image_copy.save_png_to_buffer()

	if png_bytes.is_empty():
		return {}
	return {
		"mimeType": "image/png",
		"dataUrl": "data:image/png;base64,%s" % Marshalls.raw_to_base64(png_bytes),
		"byteSize": png_bytes.size(),
		"width": image_copy.get_width(),
		"height": image_copy.get_height()
	}


func _execute_editor_refresh_filesystem(args: Dictionary) -> Dictionary:
	if editor_interface == null:
		return { "ok": false, "error": "editor_interface_unavailable" }

	var resource_filesystem: EditorFileSystem = editor_interface.get_resource_filesystem()
	if resource_filesystem == null:
		return { "ok": false, "error": "editor_filesystem_unavailable" }

	var changed_paths_value: Variant = args.get("changedPaths", [])
	var changed_paths: PackedStringArray
	if typeof(changed_paths_value) == TYPE_ARRAY:
		for path_value: Variant in changed_paths_value as Array:
			var changed_path: String = str(path_value).strip_edges()
			if not changed_path.is_empty():
				changed_paths.append(changed_path)

	var should_scan_sources: bool = bool(args.get("scanSources", true))
	if should_scan_sources and resource_filesystem.has_method("scan_sources"):
		resource_filesystem.call("scan_sources")
	resource_filesystem.scan()
	queue_context_update()

	return {
		"ok": true,
		"changedPaths": changed_paths,
		"scanSources": should_scan_sources
	}


func _execute_editor_apply_scene_patch(args: Dictionary) -> Dictionary:
	if editor_undo_redo == null:
		return { "ok": false, "error": "editor_undo_redo_unavailable" }

	var edited_root: Node = get_edited_scene_root()
	if edited_root == null:
		return { "ok": false, "error": "editor_scene_unavailable" }

	var scene_path: String = str(args.get("scenePath", ""))
	if not scene_path.strip_edges().is_empty() and scene_path != get_scene_resource_path(edited_root):
		return { "ok": false, "error": "editor_scene_mismatch" }

	var operations_value: Variant = args.get("operations", [])
	if typeof(operations_value) != TYPE_ARRAY:
		return { "ok": false, "error": "invalid_operations" }

	var operations: Array = operations_value as Array
	if operations.is_empty():
		return { "ok": false, "error": "empty_operations" }

	var action_title: String = str(args.get("title", "Scene patch")).strip_edges()
	if action_title.is_empty():
		action_title = "Scene patch"
	if not action_title.begins_with("Daedalus:"):
		action_title = "Daedalus: %s" % action_title

	var created_nodes: Array[Node] = []
	for operation_value: Variant in operations:
		if typeof(operation_value) != TYPE_DICTIONARY:
			return { "ok": false, "error": "invalid_operation" }

		var operation: Dictionary = operation_value as Dictionary
		var operation_error: String = _validate_editor_patch_operation(operation)
		if not operation_error.is_empty():
			return { "ok": false, "error": operation_error }

	editor_undo_redo.create_action(action_title)
	for operation_value: Variant in operations:
		var operation: Dictionary = operation_value as Dictionary
		var operation_error: String = _add_editor_patch_operation(operation, edited_root, created_nodes)
		if not operation_error.is_empty():
			return { "ok": false, "error": operation_error }

	editor_undo_redo.commit_action()

	var should_save: bool = bool(args.get("saveAfter", true))
	var save_error: Error = OK
	if should_save:
		save_error = _save_current_editor_scene()

	return {
		"ok": save_error == OK,
		"operations": operations.size(),
		"createdNodes": created_nodes.size(),
		"saved": should_save and save_error == OK,
		"error": "" if save_error == OK else "editor_save_failed:%d" % int(save_error)
	}


func _add_editor_patch_operation(operation: Dictionary, edited_root: Node, created_nodes: Array[Node]) -> String:
	var operation_type: String = str(operation.get("type", ""))
	if operation_type == "set_property":
		return _add_editor_set_property_operation(operation, edited_root)
	if operation_type == "add_node":
		return _add_editor_add_node_operation(operation, edited_root, created_nodes)
	if operation_type == "rename_node":
		return _add_editor_rename_node_operation(operation, edited_root)
	if operation_type == "attach_script":
		return _add_editor_attach_script_operation(operation, edited_root)
	if operation_type == "connect_signal":
		return _add_editor_connect_signal_operation(operation, edited_root)
	return "unsupported_operation:%s" % operation_type


func _validate_editor_patch_operation(operation: Dictionary) -> String:
	var operation_type: String = str(operation.get("type", ""))
	if operation_type == "set_property":
		var target_node: Node = _find_editor_node("", str(operation.get("nodePath", ".")))
		var property_name: String = str(operation.get("property", ""))
		if target_node == null:
			return "node_not_found"
		if property_name.is_empty() or not _node_has_property(target_node, property_name):
			return "property_not_found:%s" % property_name
		return ""
	if operation_type == "add_node":
		var parent_node: Node = _find_editor_node("", str(operation.get("parentPath", ".")))
		var node_type: String = str(operation.get("nodeType", "Node"))
		if parent_node == null:
			return "parent_not_found"
		if not ClassDB.class_exists(node_type):
			return "class_not_found:%s" % node_type
		var created_node_value: Variant = ClassDB.instantiate(node_type)
		if not (created_node_value is Node):
			return "class_is_not_node:%s" % node_type
		var validation_node: Node = created_node_value as Node
		validation_node.free()
		return ""
	if operation_type == "rename_node":
		var rename_node: Node = _find_editor_node("", str(operation.get("nodePath", ".")))
		var node_name: String = str(operation.get("name", "")).strip_edges()
		if rename_node == null:
			return "node_not_found"
		if node_name.is_empty():
			return "empty_node_name"
		return ""
	if operation_type == "attach_script":
		var script_node: Node = _find_editor_node("", str(operation.get("nodePath", ".")))
		var script_path: String = str(operation.get("scriptPath", "")).strip_edges()
		if script_node == null:
			return "node_not_found"
		if script_path.is_empty():
			return "empty_script_path"
		var script_resource: Resource = load(script_path)
		if not (script_resource is Script):
			return "script_not_found:%s" % script_path
		return ""
	if operation_type == "connect_signal":
		var source_node: Node = _find_editor_node("", str(operation.get("fromNode", ".")))
		var target_node: Node = _find_editor_node("", str(operation.get("toNode", ".")))
		var signal_name: String = str(operation.get("signal", "")).strip_edges()
		var method_name: String = str(operation.get("method", "")).strip_edges()
		if source_node == null or target_node == null:
			return "signal_node_not_found"
		if signal_name.is_empty() or method_name.is_empty():
			return "invalid_signal_or_method"
		return ""
	return "unsupported_operation:%s" % operation_type


func _add_editor_set_property_operation(operation: Dictionary, edited_root: Node) -> String:
	var target_node: Node = _find_editor_node("", str(operation.get("nodePath", ".")))
	var property_name: String = str(operation.get("property", ""))
	if target_node == null:
		return "node_not_found"
	if property_name.is_empty() or not _node_has_property(target_node, property_name):
		return "property_not_found:%s" % property_name

	var old_value: Variant = target_node.get(property_name)
	var new_value: Variant = _coerce_property_value(operation.get("value", null), old_value)
	editor_undo_redo.add_do_property(target_node, property_name, new_value)
	editor_undo_redo.add_undo_property(target_node, property_name, old_value)
	return ""


func _add_editor_add_node_operation(operation: Dictionary, edited_root: Node, created_nodes: Array[Node]) -> String:
	var parent_node: Node = _find_editor_node("", str(operation.get("parentPath", ".")))
	var node_type: String = str(operation.get("nodeType", "Node"))
	var node_name: String = str(operation.get("nodeName", node_type))
	if parent_node == null:
		return "parent_not_found"
	if not ClassDB.class_exists(node_type):
		return "class_not_found:%s" % node_type

	var created_node_value: Variant = ClassDB.instantiate(node_type)
	if not (created_node_value is Node):
		return "class_is_not_node:%s" % node_type

	var created_node: Node = created_node_value as Node
	created_node.name = node_name
	var properties_value: Variant = operation.get("properties", {})
	if typeof(properties_value) == TYPE_DICTIONARY:
		var properties: Dictionary = properties_value as Dictionary
		for property_key: Variant in properties.keys():
			var property_name: String = str(property_key)
			if _node_has_property(created_node, property_name):
				var old_value: Variant = created_node.get(property_name)
				created_node.set(property_name, _coerce_property_value(properties[property_key], old_value))

	editor_undo_redo.add_do_method(parent_node, "add_child", created_node)
	editor_undo_redo.add_do_property(created_node, "owner", edited_root)
	editor_undo_redo.add_undo_method(parent_node, "remove_child", created_node)
	editor_undo_redo.add_do_reference(created_node)
	created_nodes.append(created_node)
	return ""


func _add_editor_rename_node_operation(operation: Dictionary, _edited_root: Node) -> String:
	var target_node: Node = _find_editor_node("", str(operation.get("nodePath", ".")))
	var node_name: String = str(operation.get("name", "")).strip_edges()
	if target_node == null:
		return "node_not_found"
	if node_name.is_empty():
		return "empty_node_name"

	var old_name: String = target_node.name
	editor_undo_redo.add_do_property(target_node, "name", node_name)
	editor_undo_redo.add_undo_property(target_node, "name", old_name)
	return ""


func _add_editor_attach_script_operation(operation: Dictionary, _edited_root: Node) -> String:
	var target_node: Node = _find_editor_node("", str(operation.get("nodePath", ".")))
	var script_path: String = str(operation.get("scriptPath", "")).strip_edges()
	if target_node == null:
		return "node_not_found"
	if script_path.is_empty():
		return "empty_script_path"

	var script_resource: Resource = load(script_path)
	if not (script_resource is Script):
		return "script_not_found:%s" % script_path

	var old_script: Variant = target_node.get_script()
	editor_undo_redo.add_do_method(target_node, "set_script", script_resource)
	editor_undo_redo.add_undo_method(target_node, "set_script", old_script)
	return ""


func _add_editor_connect_signal_operation(operation: Dictionary, _edited_root: Node) -> String:
	var source_node: Node = _find_editor_node("", str(operation.get("fromNode", ".")))
	var target_node: Node = _find_editor_node("", str(operation.get("toNode", ".")))
	var signal_name: String = str(operation.get("signal", "")).strip_edges()
	var method_name: String = str(operation.get("method", "")).strip_edges()
	if source_node == null or target_node == null:
		return "signal_node_not_found"
	if signal_name.is_empty() or method_name.is_empty():
		return "invalid_signal_or_method"

	var callable: Callable = Callable(target_node, method_name)
	if source_node.is_connected(signal_name, callable):
		return ""

	editor_undo_redo.add_do_method(source_node, "connect", signal_name, callable)
	editor_undo_redo.add_undo_method(source_node, "disconnect", signal_name, callable)
	return ""


func _coerce_property_value(value: Variant, old_value: Variant) -> Variant:
	if old_value is Vector2 and typeof(value) == TYPE_DICTIONARY:
		var vector_dictionary: Dictionary = value as Dictionary
		return Vector2(float(vector_dictionary.get("x", 0.0)), float(vector_dictionary.get("y", 0.0)))
	if old_value is Vector2i and typeof(value) == TYPE_DICTIONARY:
		var vector_i_dictionary: Dictionary = value as Dictionary
		return Vector2i(int(vector_i_dictionary.get("x", 0)), int(vector_i_dictionary.get("y", 0)))
	if old_value is Color and typeof(value) == TYPE_STRING:
		return Color(str(value))
	return value


func _save_current_editor_scene() -> Error:
	if editor_interface == null:
		return FAILED

	return editor_interface.save_scene()
