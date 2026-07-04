@tool
extends SceneTree

const RPC_METHODS: GDScript = preload("res://addons/godot_daedalus/scripts/rpc_methods.gd")

var failures: Array[String] = []


func _init() -> void:
	_run_tests()
	if failures.is_empty():
		quit(0)
		return

	for failure: String in failures:
		push_error(failure)
	quit(1)


func _run_tests() -> void:
	_expect_equal(RPC_METHODS.AI_CHAT, "ai.chat", "ai chat method")
	_expect_equal(RPC_METHODS.BACKEND_HEALTH, "backend.health", "backend health method")
	_expect_equal(RPC_METHODS.COMMAND_LIST, "command.list", "command list method")
	_expect_equal(RPC_METHODS.SESSION_OPEN, "session.open", "session open method")
	_expect_equal(RPC_METHODS.APPROVAL_APPROVE, "approval.approve", "approval approve method")
	_expect_equal(RPC_METHODS.MCP_CONFIG_ADD, "mcp.config.add", "mcp config add method")

	var methods: Array[String] = RPC_METHODS.all()
	var seen: Dictionary[String, bool] = {}
	for method_name: String in methods:
		if seen.has(method_name):
			failures.append("duplicate RPC method: %s" % method_name)
		seen[method_name] = true

	_expect_equal(methods.size(), 53, "rpc method count")
	_expect_equal(seen.has(RPC_METHODS.COMMAND_LIST), true, "command list listed")
	_expect_equal(seen.has(RPC_METHODS.EDITOR_TOOL_RESULT), true, "editor tool result listed")
	_expect_equal(seen.has(RPC_METHODS.WORKSPACE_INFO), true, "workspace info listed")


func _expect_equal(actual_value: Variant, expected_value: Variant, label_text: String) -> void:
	if actual_value == expected_value:
		return

	failures.append("%s: expected %s, got %s" % [label_text, str(expected_value), str(actual_value)])
