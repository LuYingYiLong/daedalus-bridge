@tool
extends SceneTree

const RPC_METHODS: GDScript = preload("res://addons/godot_daedalus/scripts/rpc_methods.gd")

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
	_expect_equal(RPC_METHODS.AI_CHAT, "ai.chat", "ai chat method")
	_expect_equal(RPC_METHODS.BACKEND_HEALTH, "backend.health", "backend health method")
	_expect_equal(RPC_METHODS.COMMAND_LIST, "command.list", "command list method")
	_expect_equal(RPC_METHODS.SKILL_LIST, "skill.list", "skill list method")
	_expect_equal(RPC_METHODS.SKILL_GET, "skill.get", "skill get method")
	_expect_equal(RPC_METHODS.SKILL_SET_ENABLED, "skill.set_enabled", "skill enabled method")
	_expect_equal(RPC_METHODS.SKILL_UPDATE, "skill.update", "skill update method")
	_expect_equal(RPC_METHODS.SKILL_REMOVE, "skill.remove", "skill remove method")
	_expect_equal(RPC_METHODS.SKILL_RELOAD, "skill.reload", "skill reload method")
	_expect_equal(RPC_METHODS.CLIENT_HELLO, "client.hello", "client hello method")
	_expect_equal(RPC_METHODS.PROVIDER_CURRENT_GET, "provider.current.get", "provider current method")
	_expect_equal(RPC_METHODS.PROVIDER_MODEL_SELECTION_GET, "provider.modelSelection.get", "provider model selection method")
	_expect_equal(RPC_METHODS.USER_PROMPT_GET, "userPrompt.get", "user prompt get method")
	_expect_equal(RPC_METHODS.USER_PROMPT_SET, "userPrompt.set", "user prompt set method")
	_expect_equal(RPC_METHODS.SESSION_OPEN, "session.open", "session open method")
	_expect_equal(RPC_METHODS.SESSION_EDITOR_BIND, "session.editor.bind", "session editor bind method")
	_expect_equal(RPC_METHODS.APPROVAL_APPROVE, "approval.approve", "approval approve method")
	_expect_equal(RPC_METHODS.MCP_CONFIG_ADD, "mcp.config.add", "mcp config add method")
	_expect_equal(RPC_METHODS.MCP_CONFIG_UPDATE, "mcp.config.update", "mcp config update method")
	_expect_equal(RPC_METHODS.TOOL_CATALOG_LIST, "tool.catalog.list", "tool catalog list method")
	_expect_equal(RPC_METHODS.TOOL_EXECUTE, "tool.execute", "tool execute method")
	_expect_equal(RPC_METHODS.ATTACHMENT_IMAGE_SAVE, "attachment.image.save", "attachment image save method")
	_expect_equal(RPC_METHODS.PLAN_GET, "plan.get", "plan get method")
	_expect_equal(RPC_METHODS.PLAN_CLARIFY, "plan.clarify", "plan clarify method")
	_expect_equal(RPC_METHODS.PLAN_REVISE, "plan.revise", "plan revise method")
	_expect_equal(RPC_METHODS.PLAN_APPROVE, "plan.approve", "plan approve method")
	_expect_equal(RPC_METHODS.SESSION_WORKBENCH_GET, "session.workbench.get", "session workbench get method")
	_expect_equal(RPC_METHODS.SESSION_WORKBENCH_PATCH, "session.workbench.patch", "session workbench patch method")
	_expect_equal(RPC_METHODS.MESSAGE_QUEUE_ADD, "message.queue.add", "message queue add method")
	_expect_equal(RPC_METHODS.MESSAGE_QUEUE_STATUS, "message.queue.status", "message queue status method")

	var methods: PackedStringArray = RPC_METHODS.all()
	var seen: Dictionary[String, bool]
	for method_name: String in methods:
		if seen.has(method_name):
			failures.append("duplicate RPC method: %s" % method_name)
		seen[method_name] = true

	_expect_equal(methods.size(), 83, "rpc method count")
	_expect_equal(seen.has(RPC_METHODS.COMMAND_LIST), true, "command list listed")
	_expect_equal(seen.has(RPC_METHODS.CLIENT_INFO), true, "client info listed")
	_expect_equal(seen.has(RPC_METHODS.EDITOR_INSTANCES_LIST), true, "editor instances list listed")
	_expect_equal(seen.has(RPC_METHODS.EDITOR_TOOL_RESULT), true, "editor tool result listed")
	_expect_equal(seen.has(RPC_METHODS.WORKSPACE_INFO), true, "workspace info listed")
	_expect_equal(seen.has(RPC_METHODS.ATTACHMENT_IMAGE_SAVE), true, "attachment image save listed")
	_expect_equal(seen.has(RPC_METHODS.PLAN_APPROVE), true, "plan approve listed")
	_expect_equal(seen.has(RPC_METHODS.SESSION_WORKBENCH_GET), true, "session workbench get listed")
	_expect_equal(seen.has(RPC_METHODS.SESSION_WORKBENCH_PATCH), true, "session workbench patch listed")
	_expect_equal(seen.has(RPC_METHODS.MESSAGE_QUEUE_LIST), true, "message queue list listed")
	_expect_equal(seen.has(RPC_METHODS.MESSAGE_QUEUE_REMOVE), true, "message queue remove listed")
	_expect_equal(seen.has(RPC_METHODS.TOOL_CATALOG_LIST), true, "tool catalog list listed")
	_expect_equal(seen.has(RPC_METHODS.TOOL_EXECUTE), true, "tool execute listed")
	_finish_tests()


func _expect_equal(actual_value: Variant, expected_value: Variant, label_text: String) -> void:
	if actual_value == expected_value:
		return

	failures.append("%s: expected %s, got %s" % [label_text, str(expected_value), str(actual_value)])
