@tool
class_name DaedalusAdditionalContextController
extends Node

signal changed
signal status_requested(level: String, title: String, message: String)

const MAIN_HELPERS: GDScript = preload("uid://7sc7qjaju14c")
const ADDITIONAL_CONTEXT_ITEM_SCENE: PackedScene = preload("uid://rfwvgjocqqva")
const MAX_ITEMS: int = 10
const LIVE_EDITOR_SELECTION_CONTEXT_ID: String = "editor-selection-live"
const LIVE_SCRIPT_SELECTION_CONTEXT_ID: String = "script-selection-live"
const LIVE_FILESYSTEM_SELECTION_CONTEXT_ID: String = "filesystem-selection-live"
const VIEWER_RESERVED_HEIGHT: float = 32.0
const LIVE_CONTEXT_EMPTY_REMOVE_THRESHOLD: int = 2

var _viewer: ScrollContainer
var _container: HBoxContainer
var _items: Array[Dictionary]
var _next_id: int
var _active_live_contexts: Dictionary[String, Dictionary]
var _live_empty_counts: Dictionary[String, int]
var _dismissed_live_signatures: Dictionary[String, String]
var _dismissed_live_keys: Dictionary[String, String]
var _deferred_render_enabled: bool
var _render_queued: bool
var _changed_pending: bool


func setup(viewer: ScrollContainer, container: HBoxContainer) -> void:
	_viewer = viewer
	_container = container
	_viewer.custom_minimum_size.y = maxf(_viewer.custom_minimum_size.y, VIEWER_RESERVED_HEIGHT)
	render()


func set_deferred_render_enabled(enabled: bool) -> void:
	_deferred_render_enabled = enabled
	if not _deferred_render_enabled and _render_queued:
		_flush_render()


func get_items() -> Array[Dictionary]:
	return clone_contexts(_items, true)


func replace_items(contexts: Array) -> void:
	var next_items: Array[Dictionary] = _clone_contexts_for_snapshot_replace(contexts)
	if _context_arrays_equal(_items, next_items):
		return

	_items = next_items
	_commit_context_change()


func add_or_replace(context: Dictionary) -> bool:
	if context.is_empty():
		return false

	var context_key: String = make_context_key(context)
	for index: int in range(_items.size()):
		var existing_context: Dictionary = _items[index]
		if make_context_key(existing_context) == context_key:
			var replacement: Dictionary = context.duplicate(true)
			replacement["id"] = str(existing_context.get("id", replacement.get("id", "")))
			replacement["pinned"] = bool(existing_context.get("pinned", false))
			if _contexts_equal(existing_context, replacement):
				return true

			_items[index] = replacement
			_commit_context_change()
			return true

	if not can_append(true):
		return false
	var appended_context: Dictionary = context.duplicate(true)
	if str(appended_context.get("id", "")).is_empty():
		appended_context["id"] = make_context_id(
			str(appended_context.get("kind", "context")),
			str(appended_context.get("resourcePath", "")),
			str(appended_context.get("nodePath", ""))
		)
	_items.append(appended_context)
	_commit_context_change()
	return true


func upsert_live(context_id: String, context: Dictionary) -> void:
	var existing_index: int = find_index(context_id)
	if existing_index >= 0 and bool(_items[existing_index].get("pinned", false)):
		return

	if context.is_empty():
		if not _should_remove_empty_live_context(context_id, existing_index):
			return

		if existing_index >= 0:
			_items.remove_at(existing_index)
			_commit_context_change()
		return

	_live_empty_counts.erase(context_id)
	var live_context: Dictionary = context.duplicate(true)
	live_context["id"] = context_id
	live_context["pinned"] = false
	_active_live_contexts[context_id] = live_context.duplicate(true)
	var next_signature: String = make_live_signature(context_id, live_context)
	var next_live_key: String = make_live_dismiss_key(context_id, live_context)
	if str(_dismissed_live_keys.get(context_id, "")) == next_live_key:
		return
	if str(_dismissed_live_signatures.get(context_id, "")) == next_signature:
		return
	if existing_index >= 0:
		if make_live_signature(context_id, _items[existing_index]) == next_signature:
			return
		_items[existing_index] = live_context
	elif can_append(false):
		_items.append(live_context)
	else:
		return

	_commit_context_change()


func set_pinned(context_id: String, pinned: bool) -> void:
	var context_index: int = find_index(context_id)
	if context_index < 0:
		return

	var context: Dictionary = _items[context_index]
	if not (pinned and is_live_id(context_id)) and bool(context.get("pinned", false)) == pinned:
		return

	if pinned and is_live_id(context_id):
		_dismissed_live_signatures[context_id] = make_live_signature(context_id, context)
		_dismissed_live_keys[context_id] = make_live_dismiss_key(context_id, context)
		var detached_context: Dictionary = context.duplicate(true)
		detached_context["id"] = make_context_id(
			str(detached_context.get("kind", "context")),
			str(detached_context.get("resourcePath", "")),
			make_context_key(detached_context)
		)
		detached_context["pinned"] = true
		_items[context_index] = detached_context
	else:
		context["pinned"] = pinned
		_items[context_index] = context

	_commit_context_change()


func remove(context_id: String) -> void:
	var context_index: int = find_index(context_id)
	if context_index < 0:
		return

	var context: Dictionary = _items[context_index]
	if is_live_id(context_id):
		_dismissed_live_signatures[context_id] = make_live_signature(context_id, context)
		_dismissed_live_keys[context_id] = make_live_dismiss_key(context_id, context)
	_items.remove_at(context_index)
	_commit_context_change()


func clear_unpinned() -> void:
	var retained_contexts: Array[Dictionary]
	var changed_contexts: bool = false
	for context: Dictionary in _items:
		if bool(context.get("pinned", false)):
			retained_contexts.append(context)
		else:
			changed_contexts = true
			var context_id: String = str(context.get("id", ""))
			if is_live_id(context_id):
				_dismissed_live_signatures[context_id] = make_live_signature(context_id, context)
				_dismissed_live_keys[context_id] = make_live_dismiss_key(context_id, context)
	if not changed_contexts:
		return

	_items = retained_contexts
	_commit_context_change()


func get_request_snapshot() -> Array[Dictionary]:
	return clone_contexts(_items, false)


func get_timeline_snapshot() -> Array[Dictionary]:
	return clone_contexts(_items, true)


func get_backend_snapshot() -> Array[Dictionary]:
	var backend_contexts: Array[Dictionary]
	for context: Dictionary in _items:
		if is_live_id(str(context.get("id", ""))):
			continue
		backend_contexts.append(context)
	return clone_contexts(backend_contexts, true)


func freeze_contexts_for_message(source_contexts: Array, include_thumbnail_data: bool = true) -> Array[Dictionary]:
	var frozen_contexts: Array[Dictionary]
	for context: Dictionary in clone_contexts(source_contexts, include_thumbnail_data):
		var context_id: String = str(context.get("id", ""))
		if is_live_id(context_id):
			context["id"] = make_context_id(
				str(context.get("kind", "context")),
				str(context.get("resourcePath", "")),
				make_context_key(context)
			)
		frozen_contexts.append(context)
	return frozen_contexts


func create_image_context(resource_path: String, existing_contexts: Array, context_source: String, is_pinned: bool) -> Dictionary:
	if not MAIN_HELPERS.is_supported_image_resource_path(resource_path):
		status_requested.emit("warning", "图片格式不支持", "第一版仅支持 PNG、JPEG、WebP 和 GIF 图片。")
		return {}

	var image_file: FileAccess = FileAccess.open(resource_path, FileAccess.READ)
	if image_file == null:
		status_requested.emit("warning", "图片读取失败", "无法读取图片：%s" % resource_path)
		return {}

	var byte_size: int = image_file.get_length()
	var limit_message: String = MAIN_HELPERS.validate_image_context_limits(existing_contexts, resource_path, byte_size)
	if not limit_message.is_empty():
		image_file.close()
		status_requested.emit("warning", "图片无法添加", limit_message)
		return {}

	var image_bytes: PackedByteArray = image_file.get_buffer(byte_size)
	image_file.close()
	if image_bytes.size() != byte_size:
		status_requested.emit("warning", "图片读取失败", "图片读取不完整：%s" % resource_path)
		return {}

	var image_width: int
	var image_height: int
	var image_texture: Texture2D = load(resource_path) as Texture2D
	var image_resource: Image = image_texture.get_image() if image_texture != null else null
	if image_resource != null:
		image_width = image_resource.get_width()
		image_height = image_resource.get_height()

	var mime_type: String = MAIN_HELPERS.get_image_mime_type(resource_path)
	var image_data: Dictionary = {
		"mimeType": mime_type,
		"dataUrl": "data:%s;base64,%s" % [mime_type, Marshalls.raw_to_base64(image_bytes)],
		"byteSize": byte_size
	}
	if image_width > 0:
		image_data["width"] = image_width
	if image_height > 0:
		image_data["height"] = image_height

	var dimension_text: String = "%dx%d" % [image_width, image_height] if image_width > 0 and image_height > 0 else "未知尺寸"
	return {
		"id": make_context_id("image", resource_path, ""),
		"kind": "image",
		"title": resource_path.get_file(),
		"subtitle": "%s · %s · %s" % [mime_type, MAIN_HELPERS.format_byte_size(byte_size), dimension_text],
		"pinned": is_pinned,
		"source": context_source,
		"resourcePath": resource_path,
		"summary": "用户为本轮消息附加了一张图片；图片二进制会作为多模态输入发送给支持 image 的模型。",
		"data": image_data
	}


func add_image_path(resource_path: String, context_source: String = "manual", is_pinned: bool = false) -> bool:
	var context: Dictionary = create_image_context(resource_path, _items, context_source, is_pinned)
	return add_or_replace(context)


func expand_filesystem_image_selections(source_contexts: Array[Dictionary]) -> Array[Dictionary]:
	var expanded_contexts: Array[Dictionary]
	var known_image_paths: Dictionary
	for context_dictionary: Dictionary in source_contexts:
		if str(context_dictionary.get("kind", "")) == "image":
			var image_path: String = str(context_dictionary.get("resourcePath", "")).strip_edges()
			if not image_path.is_empty():
				known_image_paths[image_path] = true

	for context_dictionary: Dictionary in source_contexts:
		if str(context_dictionary.get("kind", "")) != "filesystem_selection":
			expanded_contexts.append(context_dictionary)
			continue
		var image_contexts: Array[Dictionary] = _create_images_from_filesystem_selection(
			context_dictionary,
			expanded_contexts,
			known_image_paths
		)
		for image_context: Dictionary in image_contexts:
			expanded_contexts.append(image_context)
		if image_contexts.is_empty() or _filesystem_selection_has_non_image_paths(context_dictionary):
			expanded_contexts.append(context_dictionary)
	return expanded_contexts


func _create_images_from_filesystem_selection(context: Dictionary, existing_contexts: Array[Dictionary], known_image_paths: Dictionary) -> Array[Dictionary]:
	var image_contexts: Array[Dictionary]
	var data: Dictionary = get_context_data(context)
	var selected_paths_value: Variant = data.get("selectedPaths", [])
	if typeof(selected_paths_value) != TYPE_ARRAY:
		return image_contexts
	var working_contexts: Array[Dictionary] = clone_contexts(existing_contexts)
	for selected_path_value: Variant in selected_paths_value as Array:
		if typeof(selected_path_value) != TYPE_DICTIONARY:
			continue
		var selected_path: Dictionary = selected_path_value as Dictionary
		if str(selected_path.get("kind", "")) != "file":
			continue
		var resource_path: String = str(selected_path.get("resourcePath", "")).strip_edges()
		if resource_path.is_empty() or not MAIN_HELPERS.is_supported_image_resource_path(resource_path):
			continue
		if bool(known_image_paths.get(resource_path, false)):
			continue
		var image_context: Dictionary = create_image_context(resource_path, working_contexts, "editor", false)
		if image_context.is_empty():
			continue
		image_contexts.append(image_context)
		working_contexts.append(image_context)
		known_image_paths[resource_path] = true
	return image_contexts


func _filesystem_selection_has_non_image_paths(context: Dictionary) -> bool:
	var data: Dictionary = get_context_data(context)
	var selected_paths_value: Variant = data.get("selectedPaths", [])
	if typeof(selected_paths_value) != TYPE_ARRAY:
		return true
	for selected_path_value: Variant in selected_paths_value as Array:
		if typeof(selected_path_value) != TYPE_DICTIONARY:
			continue
		var selected_path: Dictionary = selected_path_value as Dictionary
		if str(selected_path.get("kind", "")) != "file":
			return true
		var resource_path: String = str(selected_path.get("resourcePath", "")).strip_edges()
		if resource_path.is_empty() or not MAIN_HELPERS.is_supported_image_resource_path(resource_path):
			return true
	return false


func clone_contexts(source_contexts: Array, include_thumbnail_data: bool = false) -> Array[Dictionary]:
	var cloned_contexts: Array[Dictionary]
	for context_value: Variant in source_contexts:
		if typeof(context_value) != TYPE_DICTIONARY:
			continue
		var context_dictionary: Dictionary = context_value as Dictionary
		var cloned_context: Dictionary = context_dictionary.duplicate(true)
		if str(cloned_context.get("kind", "")) == "image":
			var data_value: Variant = cloned_context.get("data", {})
			if typeof(data_value) == TYPE_DICTIONARY:
				var image_data: Dictionary = data_value as Dictionary
				if not str(image_data.get("attachmentId", "")).is_empty():
					image_data.erase("dataUrl")
					if not include_thumbnail_data:
						image_data.erase("thumbnailDataUrl")
					cloned_context["data"] = image_data
		cloned_contexts.append(cloned_context)
	return cloned_contexts


func _clone_contexts_for_snapshot_replace(source_contexts: Array) -> Array[Dictionary]:
	var cloned_contexts: Array[Dictionary]
	for context: Dictionary in clone_contexts(source_contexts, true):
		var context_id: String = str(context.get("id", ""))
		if is_live_id(context_id):
			continue
		cloned_contexts.append(context)
	_append_active_live_contexts(cloned_contexts)
	return cloned_contexts


func _append_active_live_contexts(contexts: Array[Dictionary]) -> void:
	for context_id: String in _get_live_context_ids():
		if _context_array_has_id(contexts, context_id):
			continue
		if not _active_live_contexts.has(context_id):
			continue

		var context: Dictionary = _active_live_contexts[context_id].duplicate(true)
		var live_signature: String = make_live_signature(context_id, context)
		var live_key: String = make_live_dismiss_key(context_id, context)
		if str(_dismissed_live_keys.get(context_id, "")) == live_key:
			continue
		if str(_dismissed_live_signatures.get(context_id, "")) == live_signature:
			continue
		if contexts.size() >= MAX_ITEMS:
			continue

		contexts.append(context)


func _context_array_has_id(contexts: Array[Dictionary], context_id: String) -> bool:
	for context: Dictionary in contexts:
		if str(context.get("id", "")) == context_id:
			return true
	return false


func _get_live_context_ids() -> PackedStringArray:
	return PackedStringArray([
		LIVE_EDITOR_SELECTION_CONTEXT_ID,
		LIVE_SCRIPT_SELECTION_CONTEXT_ID,
		LIVE_FILESYSTEM_SELECTION_CONTEXT_ID
	])


func _should_remove_empty_live_context(context_id: String, existing_index: int) -> bool:
	if existing_index < 0 and not _active_live_contexts.has(context_id):
		_live_empty_counts.erase(context_id)
		_dismissed_live_signatures.erase(context_id)
		_dismissed_live_keys.erase(context_id)
		return false

	var empty_count: int = int(_live_empty_counts.get(context_id, 0)) + 1
	_live_empty_counts[context_id] = empty_count
	if empty_count < LIVE_CONTEXT_EMPTY_REMOVE_THRESHOLD:
		return false

	_live_empty_counts.erase(context_id)
	_active_live_contexts.erase(context_id)
	_dismissed_live_signatures.erase(context_id)
	_dismissed_live_keys.erase(context_id)
	return true


func can_append(show_warning: bool) -> bool:
	if _items.size() < MAX_ITEMS:
		return true
	if show_warning:
		status_requested.emit(
			"warning",
			"上下文数量已达上限",
			"最多只能添加 %d 个 Additional Context，请先移除一个。" % MAX_ITEMS
		)
	return false


func _commit_context_change() -> void:
	if not _deferred_render_enabled:
		render()
		changed.emit()
		return

	_changed_pending = true
	if _render_queued:
		return

	_render_queued = true
	_flush_render.call_deferred()


func _flush_render() -> void:
	if not _render_queued and not _changed_pending:
		return

	_render_queued = false
	render()
	if _changed_pending:
		_changed_pending = false
		changed.emit()


func render() -> void:
	if _viewer == null or _container == null:
		return

	_container.visible = true
	if _items.is_empty():
		for child: Node in _container.get_children():
			child.queue_free()
		return

	var existing_items_by_id: Dictionary[String, Node]
	for child: Node in _container.get_children():
		var child_context_id: String = str(child.get("context_id"))
		if child_context_id.is_empty() or existing_items_by_id.has(child_context_id):
			child.queue_free()
			continue
		existing_items_by_id[child_context_id] = child

	var retained_ids: Dictionary[String, bool]
	for index: int in range(_items.size()):
		var context: Dictionary = _items[index]
		var context_id: String = str(context.get("id", ""))
		if context_id.is_empty():
			continue

		var item: Node = existing_items_by_id.get(context_id, null) as Node
		if item == null:
			item = ADDITIONAL_CONTEXT_ITEM_SCENE.instantiate()
			_container.add_child(item)
			item.connect("pin_toggled", set_pinned)
			item.connect("remove_requested", remove)
		item.call("setup", context)
		if item.get_index() != index:
			_container.move_child(item, index)
		retained_ids[context_id] = true

	for context_id: String in existing_items_by_id.keys():
		if retained_ids.has(context_id):
			continue
		var stale_item: Node = existing_items_by_id[context_id]
		stale_item.queue_free()


func make_context_id(context_kind: String, resource_path: String, node_path: String) -> String:
	_next_id += 1
	var key_text: String = "%s:%s:%s:%d" % [context_kind, resource_path, node_path, _next_id]
	return "ctx-%d-%d" % [Time.get_ticks_msec(), abs(hash(key_text))]


func make_context_key(context: Dictionary) -> String:
	var context_kind: String = str(context.get("kind", ""))
	if context_kind == "image":
		var image_data: Dictionary = get_context_data(context)
		var attachment_id: String = str(image_data.get("attachmentId", "")).strip_edges()
		if not attachment_id.is_empty():
			return "%s\n%s" % [context_kind, attachment_id]
	if context_kind == "script_selection":
		return "%s\n%s\n%s" % [
			context_kind,
			str(context.get("resourcePath", "")),
			make_script_selection_key(context)
		]
	if context_kind == "filesystem_selection":
		return "%s\n%s" % [context_kind, make_filesystem_selection_key(context)]
	return "%s\n%s\n%s" % [
		context_kind,
		str(context.get("resourcePath", "")),
		str(context.get("nodePath", ""))
	]


func make_script_selection_key(context: Dictionary) -> String:
	var data: Dictionary = get_context_data(context)
	return "%d:%d-%d:%d" % [
		int(data.get("lineStart", 0)),
		int(data.get("columnStart", 0)),
		int(data.get("lineEnd", 0)),
		int(data.get("columnEnd", 0))
	]


func make_filesystem_selection_key(context: Dictionary) -> String:
	var data: Dictionary = get_context_data(context)
	var selected_paths_value: Variant = data.get("selectedPaths", [])
	if typeof(selected_paths_value) != TYPE_ARRAY:
		return str(context.get("resourcePath", ""))
	var path_parts: PackedStringArray
	for selected_path_value: Variant in selected_paths_value as Array:
		if typeof(selected_path_value) == TYPE_DICTIONARY:
			path_parts.append(str((selected_path_value as Dictionary).get("resourcePath", "")))
	return "\n".join(path_parts)


func make_live_dismiss_key(context_id: String, context: Dictionary) -> String:
	var context_kind: String = str(context.get("kind", ""))
	if context_kind == "editor_selection":
		return "%s\n%s\n%s" % [
			context_id,
			str(context.get("resourcePath", "")),
			_make_editor_selection_paths_key(context)
		]
	return "%s\n%s" % [context_id, make_context_key(context)]


func _make_editor_selection_paths_key(context: Dictionary) -> String:
	var data: Dictionary = get_context_data(context)
	var selected_nodes_value: Variant = data.get("selectedNodes", [])
	if typeof(selected_nodes_value) != TYPE_ARRAY:
		return ""

	var node_paths: PackedStringArray
	for selected_node_value: Variant in selected_nodes_value as Array:
		if typeof(selected_node_value) != TYPE_DICTIONARY:
			continue
		var selected_node: Dictionary = selected_node_value as Dictionary
		node_paths.append(str(selected_node.get("path", "")))
	return "\n".join(node_paths)


func get_context_data(context: Dictionary) -> Dictionary:
	var data_value: Variant = context.get("data", {})
	if typeof(data_value) != TYPE_DICTIONARY:
		return {}
	return data_value as Dictionary


func find_index(context_id: String) -> int:
	for index: int in range(_items.size()):
		if str(_items[index].get("id", "")) == context_id:
			return index
	return -1


func _context_arrays_equal(left_contexts: Array[Dictionary], right_contexts: Array[Dictionary]) -> bool:
	if left_contexts.size() != right_contexts.size():
		return false

	for index: int in range(left_contexts.size()):
		if not _contexts_equal(left_contexts[index], right_contexts[index]):
			return false

	return true


func _contexts_equal(left_context: Dictionary, right_context: Dictionary) -> bool:
	return left_context == right_context


func is_live_id(context_id: String) -> bool:
	return (
		context_id == LIVE_EDITOR_SELECTION_CONTEXT_ID
		or context_id == LIVE_SCRIPT_SELECTION_CONTEXT_ID
		or context_id == LIVE_FILESYSTEM_SELECTION_CONTEXT_ID
	)


func make_live_signature(context_id: String, context: Dictionary) -> String:
	var signature_context: Dictionary = context.duplicate(true)
	signature_context["id"] = context_id
	signature_context["pinned"] = false
	return JSON.stringify(signature_context)
