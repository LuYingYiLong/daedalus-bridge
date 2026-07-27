@tool
extends Button

signal pin_toggled(context_id: String, pinned: bool)
signal remove_requested(context_id: String)
signal activated(context_id: String)

const MAIN_HELPERS: GDScript = preload("res://addons/godot_daedalus/scripts/main_helpers.gd")
const PIN_ICON: Texture2D = preload("res://addons/godot_daedalus/assets/icons/pin.svg")
const UNPIN_ICON: Texture2D = preload("res://addons/godot_daedalus/assets/icons/pin.svg")
const NODE_ICON: Texture2D = preload("res://addons/godot_daedalus/assets/icons/node.svg")
const FILE_ICON: Texture2D = preload("res://addons/godot_daedalus/assets/icons/file.svg")
const SCRIPT_ICON: Texture2D = preload("res://addons/godot_daedalus/assets/icons/script.svg")
const SCRIPT_EXTENSIONS: PackedStringArray = ["gd", "cs", "shader", "gdshader", "glsl", "hlsl"]

@onready var context_icon: TextureRect = %Icon
@onready var title_label: Label = %Label

var context_id: String
var context_data: Dictionary
var pinned: bool
var interactive: bool = true
var thumbnail_texture: Texture2D
var thumbnail_source_key: String
var thumbnail_thread: Thread
var thumbnail_request_id: int


func setup(context: Dictionary) -> void:
	context_data = context.duplicate(true)
	context_id = str(context_data.get("id", ""))
	pinned = bool(context_data.get("pinned", false))

	title_label.text = str(context_data.get("title", "Context"))
	_apply_icon_state()
	tooltip_text = _create_tooltip_text()


func _process(_delta: float) -> void:
	_poll_thumbnail_thread()


func _exit_tree() -> void:
	if thumbnail_thread != null:
		thumbnail_thread.wait_to_finish()
		thumbnail_thread = null


func set_interactive(enabled: bool) -> void:
	interactive = enabled
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_ARROW
	_apply_icon_state()
	tooltip_text = _create_tooltip_text()


func _pressed() -> void:
	if not interactive:
		activated.emit(context_id)
		return

	pinned = not pinned
	context_data["pinned"] = pinned
	_apply_icon_state()
	tooltip_text = _create_tooltip_text()
	pin_toggled.emit(context_id, pinned)


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
		remove_requested.emit(context_id)
		accept_event()


func _get_context_icon() -> Texture2D:
	var context_kind: String = str(context_data.get("kind", ""))
	if context_kind == "script" or context_kind == "script_selection":
		return SCRIPT_ICON
	if context_kind == "file":
		return SCRIPT_ICON if _is_script_resource_path(str(context_data.get("resourcePath", ""))) else FILE_ICON
	if context_kind == "filesystem_selection":
		var filesystem_image_texture: Texture2D = _get_or_queue_image_thumbnail(
			_get_first_filesystem_selection_image_path(),
			""
		)
		if filesystem_image_texture != null:
			return filesystem_image_texture
		return SCRIPT_ICON if _is_filesystem_selection_only_scripts() else FILE_ICON
	if context_kind == "folder":
		return FILE_ICON
	if context_kind == "image":
		var image_data: Dictionary = _get_context_data()
		var image_texture: Texture2D = _get_or_queue_image_thumbnail(
			str(context_data.get("resourcePath", "")).strip_edges(),
			str(image_data.get("thumbnailDataUrl", image_data.get("dataUrl", ""))).strip_edges()
		)
		if image_texture != null:
			return image_texture
		return FILE_ICON

	return NODE_ICON


func _apply_icon_state() -> void:
	_set_context_texture(_get_context_icon())


func _set_context_texture(next_texture: Texture2D) -> void:
	context_icon.texture = next_texture
	if interactive:
		context_icon.show()
		icon = PIN_ICON if pinned else UNPIN_ICON
	else:
		context_icon.hide()
		icon = context_icon.texture


func _get_or_queue_image_thumbnail(resource_path: String, data_url: String) -> Texture2D:
	var normalized_resource_path: String = resource_path.strip_edges()
	var normalized_data_url: String = data_url.strip_edges()
	if normalized_resource_path.is_empty() and normalized_data_url.is_empty():
		return null
	var next_source_key: String = "%s\n%d:%d" % [
		normalized_resource_path,
		normalized_data_url.length(),
		hash(normalized_data_url)
	]
	if thumbnail_texture != null and thumbnail_source_key == next_source_key:
		return thumbnail_texture
	_queue_thumbnail_load(next_source_key, normalized_resource_path, normalized_data_url)
	return null


func _queue_thumbnail_load(source_key: String, resource_path: String, data_url: String) -> void:
	if thumbnail_thread != null:
		if thumbnail_source_key == source_key:
			return
		thumbnail_thread.wait_to_finish()
		thumbnail_thread = null

	thumbnail_source_key = source_key
	thumbnail_request_id += 1
	var request_id: int = thumbnail_request_id
	thumbnail_thread = Thread.new()
	var error: Error = thumbnail_thread.start(Callable(self, "_load_image_thumbnail_thread").bind(request_id, resource_path, data_url))
	if error != OK:
		thumbnail_thread = null
		return
	set_process(true)


func _poll_thumbnail_thread() -> void:
	if thumbnail_thread == null:
		set_process(false)
		return
	if thumbnail_thread.is_alive():
		return

	var result_value: Variant = thumbnail_thread.wait_to_finish()
	thumbnail_thread = null
	set_process(false)
	if typeof(result_value) != TYPE_DICTIONARY:
		return

	var result: Dictionary = result_value as Dictionary
	if int(result.get("requestId", 0)) != thumbnail_request_id:
		return
	var image_value: Variant = result.get("image", null)
	if not (image_value is Image):
		return
	var image_resource: Image = image_value as Image
	if image_resource.is_empty():
		return

	thumbnail_texture = ImageTexture.create_from_image(image_resource)
	_set_context_texture(thumbnail_texture)


func _load_image_thumbnail_thread(request_id: int, resource_path: String, data_url: String) -> Dictionary:
	var image_resource: Image = Image.new()
	var error: Error = ERR_UNAVAILABLE
	if not resource_path.is_empty():
		error = image_resource.load(resource_path)
	elif not data_url.is_empty():
		error = _load_image_from_data_url(image_resource, data_url)

	if error != OK:
		return { "requestId": request_id }

	return {
		"requestId": request_id,
		"image": image_resource
	}


func _get_first_filesystem_selection_image_path() -> String:
	var data: Dictionary = _get_context_data()
	var selected_paths_value: Variant = data.get("selectedPaths", [])
	if typeof(selected_paths_value) != TYPE_ARRAY:
		return ""

	var selected_paths: Array = selected_paths_value as Array
	for selected_path_value: Variant in selected_paths:
		if typeof(selected_path_value) != TYPE_DICTIONARY:
			continue

		var selected_path: Dictionary = selected_path_value as Dictionary
		if str(selected_path.get("kind", "")) != "file":
			continue

		var resource_path: String = str(selected_path.get("resourcePath", "")).strip_edges()
		if MAIN_HELPERS.is_supported_image_resource_path(resource_path):
			return resource_path

	return ""


func _load_image_from_data_url(image_resource: Image, data_url: String) -> Error:
	var comma_index: int = data_url.find(",")
	if comma_index < 0:
		return ERR_INVALID_DATA

	var raw_bytes: PackedByteArray = Marshalls.base64_to_raw(data_url.substr(comma_index + 1))
	if raw_bytes.is_empty():
		return ERR_INVALID_DATA

	var mime_type: String = data_url.substr(5, comma_index - 5).split(";")[0] if data_url.begins_with("data:") else ""
	match mime_type:
		"image/png":
			return image_resource.load_png_from_buffer(raw_bytes)
		"image/jpeg":
			return image_resource.load_jpg_from_buffer(raw_bytes)
		"image/webp":
			return image_resource.load_webp_from_buffer(raw_bytes)
		_:
			return ERR_UNAVAILABLE

	return ERR_UNAVAILABLE


func _is_filesystem_selection_only_scripts() -> bool:
	var data: Dictionary = _get_context_data()
	var selected_paths_value: Variant = data.get("selectedPaths", [])
	if typeof(selected_paths_value) != TYPE_ARRAY:
		return false

	var selected_paths: Array = selected_paths_value as Array
	var has_file: bool
	for selected_path_value: Variant in selected_paths:
		if typeof(selected_path_value) != TYPE_DICTIONARY:
			continue
		var selected_path: Dictionary = selected_path_value as Dictionary
		if str(selected_path.get("kind", "")) != "file":
			return false
		has_file = true
		if not _is_script_resource_path(str(selected_path.get("resourcePath", ""))):
			return false

	return has_file


func _is_script_resource_path(resource_path: String) -> bool:
	var extension: String = resource_path.get_extension().to_lower()
	return SCRIPT_EXTENSIONS.has(extension)


func _create_tooltip_text() -> String:
	var lines: PackedStringArray
	lines.append(str(context_data.get("title", "Context")))

	var subtitle: String = str(context_data.get("subtitle", "")).strip_edges()
	if not subtitle.is_empty():
		lines.append(subtitle)

	var resource_path: String = str(context_data.get("resourcePath", "")).strip_edges()
	if not resource_path.is_empty():
		lines.append(resource_path)

	var node_path: String = str(context_data.get("nodePath", "")).strip_edges()
	if not node_path.is_empty():
		lines.append(node_path)

	var context_kind: String = str(context_data.get("kind", ""))
	if context_kind == "script_selection":
		_append_script_selection_tooltip_lines(lines)
	elif context_kind == "filesystem_selection":
		_append_filesystem_selection_tooltip_lines(lines)
	elif context_kind == "image":
		_append_image_tooltip_lines(lines)

	if interactive:
		lines.append("Click to pin/unpin. Right-click to remove.")

	return "\n".join(lines)


func _append_script_selection_tooltip_lines(lines: PackedStringArray) -> void:
	var data: Dictionary = _get_context_data()
	var line_start: int = int(data.get("lineStart", 0))
	var column_start: int = int(data.get("columnStart", 0))
	var line_end: int = int(data.get("lineEnd", 0))
	var column_end: int = int(data.get("columnEnd", 0))
	if line_start > 0 and column_start > 0 and line_end > 0 and column_end > 0:
		lines.append("Range: %d:%d-%d:%d" % [line_start, column_start, line_end, column_end])

	var has_selection: bool = bool(data.get("hasSelection", false))
	if has_selection:
		lines.append("Selection preview included")
	else:
		lines.append("Current line preview included")


func _append_filesystem_selection_tooltip_lines(lines: PackedStringArray) -> void:
	var data: Dictionary = _get_context_data()
	var selected_paths_value: Variant = data.get("selectedPaths", [])
	if typeof(selected_paths_value) != TYPE_ARRAY:
		return

	var selected_paths: Array = selected_paths_value as Array
	for index: int in range(mini(selected_paths.size(), 5)):
		var selected_path_value: Variant = selected_paths[index]
		if typeof(selected_path_value) != TYPE_DICTIONARY:
			continue
		var selected_path: Dictionary = selected_path_value as Dictionary
		lines.append("%s: %s" % [str(selected_path.get("kind", "file")), str(selected_path.get("resourcePath", ""))])
	if selected_paths.size() > 5:
		lines.append("... %d more" % (selected_paths.size() - 5))


func _append_image_tooltip_lines(lines: PackedStringArray) -> void:
	var data: Dictionary = _get_context_data()
	var mime_type: String = str(data.get("mimeType", "")).strip_edges()
	if not mime_type.is_empty():
		lines.append("MIME: %s" % mime_type)

	var byte_size: int = int(data.get("byteSize", 0))
	if byte_size > 0:
		lines.append("Size: %s" % MAIN_HELPERS.format_byte_size(byte_size))

	var width: int = int(data.get("width", 0))
	var height: int = int(data.get("height", 0))
	if width > 0 and height > 0:
		lines.append("Dimensions: %dx%d" % [width, height])


func _get_context_data() -> Dictionary:
	var data_value: Variant = context_data.get("data", {})
	if typeof(data_value) != TYPE_DICTIONARY:
		return {}
	return data_value as Dictionary
