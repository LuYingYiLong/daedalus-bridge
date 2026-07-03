@tool
extends CenterContainer

signal reconnect_requested
signal backend_check_requested

const SHINE_SHADER: Shader = preload("uid://it7onvcel3up")

@onready var icon: TextureRect = %Icon
@onready var error_container: VBoxContainer = %ErrorContainer
@onready var error_label: Label = %ErrorLabel
@onready var error_details_label: Label = %ErrorDetailsLabel


func _ready() -> void:
	error_container.hide()


func show_connecting() -> void:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SHINE_SHADER
	icon.material = material
	error_container.hide()


func show_error(title: String, details: String) -> void:
	icon.material = null
	error_label.text = title
	error_details_label.text = details
	error_container.show()


func _on_reconnect_button_pressed() -> void:
	reconnect_requested.emit()


func _on_backend_manager_button_pressed() -> void:
	backend_check_requested.emit()
