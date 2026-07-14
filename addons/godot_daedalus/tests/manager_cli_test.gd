@tool
extends SceneTree

const MANAGER_CLI_SCRIPT: GDScript = preload("uid://b6g8wsqm5d4et")

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
	var manager_cli: RefCounted = MANAGER_CLI_SCRIPT.new()
	var invocation: Dictionary = manager_cli.call("_build_npm_latest_manager_invocation", PackedStringArray(["--json", "status"])) as Dictionary
	var command_args: PackedStringArray = invocation.get("command_args", PackedStringArray()) as PackedStringArray
	_expect_equal(str(invocation.get("command_path", "")), "npm", "npm latest manager command path")
	_expect_equal(command_args.has("node"), true, "npm latest manager uses node bridge")
	_expect_equal(command_args.has("-e"), true, "npm latest manager uses inline bridge script")
	_expect_equal(command_args.has("godot-daedalus-manager"), false, "npm latest manager avoids broken package shim")
	_expect_equal(command_args[command_args.size() - 2], "--json", "json arg is forwarded")
	_expect_equal(command_args[command_args.size() - 1], "status", "manager command is forwarded")
	_finish_tests()


func _expect_equal(actual_value: Variant, expected_value: Variant, label_text: String) -> void:
	if actual_value == expected_value:
		return

	failures.append("%s: expected %s, got %s" % [label_text, str(expected_value), str(actual_value)])
