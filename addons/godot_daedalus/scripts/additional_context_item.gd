@tool
extends Button

signal pin_toggled(context_id: String, pinned: bool)
signal remove_requested(context_id: String)
signal activated(context_id: String)

const MAIN_HELPERS: GDScript = preload("res://addons/godot_daedalus/scripts/main_helpers.gd")
const PIN_ICON: Texture2D = preload("uid://djumrslufw1q8")
const UNPIN_ICON: Texture2D = preload("uid://xd7ejyjkvr20")
const NODE_ICON: Texture2D = preload("uid://cg37rrr8iihlh")
const FILE_ICON: Texture2D = preload("uid://bolghxe3kbp2r")
const SCRIPT_ICON: Texture2D = preload("uid://dqw3f23j6ipt8")
const SCRIPT_EXTENSIONS: PackedStringArray = ["gd", "cs", "shader", "gdshader", "glsl", "hlsl"]

@onready var context_icon: TextureRect = %Icon
@onready var title_label: Label = %Label

var context_id: String
var context_data: Dictionary
var pinned: bool
var interactive: bool = true


func setup(context: Dictionary) -> void:
	context_data = context.duplicate(true)
	context_id = str(context_data.get("id", ""))
	pinned = bool(context_data.get("pinned", false))

	title_label.text = str(context_data.get("title", "Context"))
	_apply_icon_state()
	tooltip_text = _create_tooltip_text()


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
		var filesystem_image_texture: Texture2D = _get_filesystem_selection_image_thumbnail_texture()
		if filesystem_image_texture != null:
			return filesystem_image_texture
		return SCRIPT_ICON if _is_filesystem_selection_only_scripts() else FILE_ICON
	if context_kind == "folder":
		return FILE_ICON
	if context_kind == "image":
		var image_texture: Texture2D = _get_image_thumbnail_texture(
			str(context_data.get("resourcePath", "")).strip_edges(),
			str(_get_context_data().get("dataUrl", "")).strip_edges()
		)
		if image_texture != null:
			return image_texture
		return FILE_ICON

	return NODE_ICON


func _apply_icon_state() -> void:
	context_icon.texture = _get_context_icon()
	if interactive:
		context_icon.show()
		icon = PIN_ICON if pinned else UNPIN_ICON
	else:
		context_icon.hide()
		icon = context_icon.texture


func _get_filesystem_selection_image_thumbnail_texture() -> Texture2D:
	var image_path: String = _get_first_filesystem_selection_image_path()
	if image_path.is_empty():
		return null

	return _get_image_thumbnail_texture(image_path, "")


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


func _get_image_thumbnail_texture(resource_path: String, data_url: String) -> Texture2D:
	if not resource_path.is_empty():
		var loaded_texture: Texture2D = load(resource_path) as Texture2D
		if loaded_texture != null:
			return loaded_texture

		var image_resource: Image = Image.new()
		if image_resource.load(resource_path) == OK:
			return ImageTexture.create_from_image(image_resource)

	return _get_image_thumbnail_texture_from_data_url(data_url)


func _get_image_thumbnail_texture_from_data_url(data_url: String) -> Texture2D:
	var comma_index: int = data_url.find(",")
	if comma_index < 0:
		return null

	var raw_bytes: PackedByteArray = Marshalls.base64_to_raw(data_url.substr(comma_index + 1))
	if raw_bytes.is_empty():
		return null

	var image_resource: Image = Image.new()
	var mime_type: String = data_url.substr(5, comma_index - 5).split(";")[0] if data_url.begins_with("data:") else ""
	var error: Error = ERR_UNAVAILABLE
	match mime_type:
		"image/png":
			error = image_resource.load_png_from_buffer(raw_bytes)
		"image/jpeg":
			error = image_resource.load_jpg_from_buffer(raw_bytes)
		"image/webp":
			error = image_resource.load_webp_from_buffer(raw_bytes)
		_:
			error = ERR_UNAVAILABLE

	if error != OK:
		return null

	return ImageTexture.create_from_image(image_resource)


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
