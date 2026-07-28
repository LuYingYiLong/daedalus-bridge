@tool
extends CenterContainer

signal reconnect_requested
signal backend_check_requested
signal settings_requested

const SHINE_SHADER: Shader = preload("res://addons/godot_daedalus/scripts/shaders/shine.gdshader")

@onready var icon: TextureRect = %Icon
@onready var status_label: Label = %StatusLabel
@onready var error_container: VBoxContainer = %ErrorContainer
@onready var error_label: Label = %ErrorLabel
@onready var error_details_label: RichTextLabel = %ErrorDetailsLabel

var latest_error_details: String


func _ready() -> void:
	_resolve_node_refs()
	if error_container != null:
		error_container.hide()


func show_status(title: String) -> void:
	_resolve_node_refs()
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SHINE_SHADER
	if icon != null:
		icon.material = material
	if status_label != null:
		status_label.text = title
		status_label.show()
	if error_container != null:
		error_container.hide()


func show_connecting() -> void:
	show_status("Checking backend")


func show_error(title: String, details: String) -> void:
	_resolve_node_refs()
	if icon != null:
		icon.material = null
	latest_error_details = "%s\n\n%s" % [title, details]
	if status_label != null:
		status_label.text = title
		status_label.show()
	if error_label != null:
		error_label.text = title
	if error_details_label != null:
		error_details_label.text = details
	if error_container != null:
		error_container.show()


func _resolve_node_refs() -> void:
	if icon == null:
		icon = get_node_or_null("%Icon") as TextureRect
	if status_label == null:
		status_label = get_node_or_null("%StatusLabel") as Label
	if error_container == null:
		error_container = get_node_or_null("%ErrorContainer") as VBoxContainer
	if error_label == null:
		error_label = get_node_or_null("%ErrorLabel") as Label
	if error_details_label == null:
		error_details_label = get_node_or_null("%ErrorDetailsLabel") as RichTextLabel


func _on_reconnect_button_pressed() -> void:
	reconnect_requested.emit()


func _on_backend_manager_button_pressed() -> void:
	backend_check_requested.emit()


func _on_settings_button_pressed() -> void:
	settings_requested.emit()


func _on_copy_details_button_pressed() -> void:
	DisplayServer.clipboard_set(latest_error_details)
