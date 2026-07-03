@tool
extends Control

const ROW_HEIGHT: int = 28
const MAX_ROWS: int = 7
const LABEL_WIDTH: float = 128.0
const H_PADDING: float = 10.0
const V_PADDING: float = 5.0

var commands: Array[Dictionary] = []
var selected_index: int
var popup_rect: Rect2
var popup_visible: bool


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	hide()


func show_commands(next_commands: Array[Dictionary], next_selected_index: int, text_edit_rect: Rect2, container_rect: Rect2) -> void:
	commands = next_commands.duplicate(true)
	selected_index = clampi(next_selected_index, 0, maxi(commands.size() - 1, 0))
	global_position = container_rect.position
	size = container_rect.size
	custom_minimum_size = container_rect.size
	var row_count: int = mini(commands.size(), MAX_ROWS)
	var popup_width: float = text_edit_rect.size.x
	var popup_height: float = maxi(float(ROW_HEIGHT), float(row_count * ROW_HEIGHT) + V_PADDING * 2.0)
	var local_text_position: Vector2 = text_edit_rect.position - container_rect.position
	var popup_position: Vector2 = Vector2(local_text_position.x, local_text_position.y - popup_height - 4.0)
	if popup_position.y < 0.0:
		popup_position.y = local_text_position.y + text_edit_rect.size.y + 4.0

	popup_rect = Rect2(popup_position, Vector2(popup_width, popup_height))
	popup_visible = true
	show()
	queue_redraw()


func hide_commands() -> void:
	popup_visible = false
	commands.clear()
	hide()
	queue_redraw()


func _draw() -> void:
	if not popup_visible or commands.is_empty():
		return

	var panel_style: StyleBoxFlat = _get_completion_stylebox() as StyleBoxFlat
	if panel_style != null:
		draw_style_box(panel_style, popup_rect)
	else:
		draw_rect(popup_rect, get_theme_color(&"dark_color_2", &"Editor"))

	var font: Font = get_theme_font(&"font", &"CodeEdit")
	if font == null:
		font = get_theme_default_font()
	var font_size: int = get_theme_font_size(&"font_size", &"CodeEdit")
	if font_size <= 0:
		font_size = get_theme_default_font_size()

	var normal_color: Color = get_theme_color(&"font_color", &"CodeEdit")
	var muted_color: Color = get_theme_color(&"font_placeholder_color", &"LineEdit")
	var selected_color: Color = get_theme_color(&"completion_selected_color", &"CodeEdit")
	if selected_color.a <= 0.01:
		selected_color = get_theme_color(&"selection_color", &"TextEdit")

	var row_count: int = mini(commands.size(), MAX_ROWS)
	for index: int in range(row_count):
		var row_rect: Rect2 = Rect2(
			popup_rect.position + Vector2(0.0, V_PADDING + float(index * ROW_HEIGHT)),
			Vector2(popup_rect.size.x, float(ROW_HEIGHT))
		)
		if index == selected_index:
			draw_rect(row_rect, selected_color)

		var command: Dictionary = commands[index]
		var label_text: String = str(command.get("label", ""))
		var description_text: String = str(command.get("description", ""))
		var text_y: float = row_rect.position.y + floor((float(ROW_HEIGHT) + float(font_size)) * 0.5) - 2.0
		draw_string(font, Vector2(row_rect.position.x + H_PADDING, text_y), label_text, HORIZONTAL_ALIGNMENT_LEFT, LABEL_WIDTH - H_PADDING, font_size, normal_color)
		draw_string(font, Vector2(row_rect.position.x + LABEL_WIDTH, text_y), description_text, HORIZONTAL_ALIGNMENT_LEFT, row_rect.size.x - LABEL_WIDTH - H_PADDING, font_size, muted_color)


func _get_completion_stylebox() -> StyleBox:
	if has_theme_stylebox(&"completion", &"CodeEdit"):
		return get_theme_stylebox(&"completion", &"CodeEdit")
	if has_theme_stylebox(&"panel", &"PopupPanel"):
		return get_theme_stylebox(&"panel", &"PopupPanel")

	return null
