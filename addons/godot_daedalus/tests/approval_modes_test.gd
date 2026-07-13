@tool
extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://addons/godot_daedalus/scenes/main.tscn")

var failures: PackedStringArray


func _init() -> void:
	_run_tests.call_deferred()


func _finish_tests() -> void:
	if failures.is_empty():
		quit(0)
		return

	for failure: String in failures:
		push_error(failure)
	quit(1)


func _run_tests() -> void:
	var main_instance: VBoxContainer = MAIN_SCENE.instantiate() as VBoxContainer
	var approval_mode_button: OptionButton = main_instance.get_node("MainViewer/FooterContainer/ApprovalModeButton") as OptionButton
	var controller: Node = main_instance.get_node("Controllers/ProviderNavigationController")
	controller.call("setup", approval_mode_button, null, null, null)

	_expect_equal(approval_mode_button.get_item_count(), 2, "approval mode item count")
	_expect_equal(approval_mode_button.get_item_text(0), "Manual", "manual approval item")
	_expect_equal(approval_mode_button.get_item_text(1), "Auto Safe", "auto-safe approval item")
	_expect_equal(bool(controller.call("select_approval_mode", "manual")), true, "manual selectable")
	_expect_equal(bool(controller.call("select_approval_mode", "auto-safe")), true, "auto-safe selectable")
	_expect_equal(bool(controller.call("select_approval_mode", "read-only")), false, "read-only removed")

	main_instance.free()
	_finish_tests()


func _expect_equal(actual_value: Variant, expected_value: Variant, label_text: String) -> void:
	if actual_value == expected_value:
		return

	failures.append("%s: expected %s, got %s" % [label_text, str(expected_value), str(actual_value)])
