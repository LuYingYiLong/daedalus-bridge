@tool
extends RefCounted

const MESSAGE_QUEUE_STATUS_PENDING: String = "pending"
const MESSAGE_QUEUE_STATUS_SENDING: String = "sending"
const MESSAGE_QUEUE_STATUS_APPROVAL: String = "approval"
const MESSAGE_QUEUE_STATUS_FAILED: String = "failed"
const MESSAGE_QUEUE_STATUS_CANCELLED: String = "cancelled"
const MESSAGE_QUEUE_STATUS_REJECTED: String = "rejected"
const GUIDE_STATUS_DRAFT: String = "draft"
const GUIDE_STATUS_SUBMITTING: String = "submitting"
const GUIDE_STATUS_PENDING: String = "pending"
const GUIDE_STATUS_DELETING: String = "deleting"
const GUIDE_STATUS_APPLIED: String = "applied"
const GUIDE_STATUS_FAILED: String = "failed"
const MAX_IMAGE_ATTACHMENTS: int = 3
const MAX_IMAGE_BYTES: int = 1024 * 1024
const MAX_TOTAL_IMAGE_BYTES: int = 2621440


static func format_queue_status(status: String) -> String:
	if status == MESSAGE_QUEUE_STATUS_PENDING:
		return "Queued"
	if status == MESSAGE_QUEUE_STATUS_SENDING:
		return "Sending"
	if status == MESSAGE_QUEUE_STATUS_APPROVAL:
		return "Approval"
	if status == MESSAGE_QUEUE_STATUS_CANCELLED:
		return "Stopped"
	if status == MESSAGE_QUEUE_STATUS_REJECTED:
		return "Rejected"
	if status == MESSAGE_QUEUE_STATUS_FAILED:
		return "Failed"

	return status.capitalize()


static func can_edit_queue_message(status: String) -> bool:
	return status == MESSAGE_QUEUE_STATUS_PENDING or status == MESSAGE_QUEUE_STATUS_FAILED or status == MESSAGE_QUEUE_STATUS_CANCELLED or status == MESSAGE_QUEUE_STATUS_REJECTED


static func can_delete_queue_message(status: String) -> bool:
	return status == MESSAGE_QUEUE_STATUS_PENDING or status == MESSAGE_QUEUE_STATUS_FAILED or status == MESSAGE_QUEUE_STATUS_CANCELLED or status == MESSAGE_QUEUE_STATUS_REJECTED


static func format_guide_status(status: String) -> String:
	if status == GUIDE_STATUS_DRAFT:
		return "Guide"
	if status == GUIDE_STATUS_SUBMITTING:
		return "Sending"
	if status == GUIDE_STATUS_PENDING:
		return "Pending"
	if status == GUIDE_STATUS_DELETING:
		return "Deleting"
	if status == GUIDE_STATUS_APPLIED:
		return "Applied"
	if status == GUIDE_STATUS_FAILED:
		return "Failed"

	return status.capitalize()


static func can_submit_manual_guide(status: String) -> bool:
	return status == GUIDE_STATUS_DRAFT or status == GUIDE_STATUS_FAILED


static func can_edit_manual_guide(status: String) -> bool:
	return status == GUIDE_STATUS_DRAFT or status == GUIDE_STATUS_PENDING or status == GUIDE_STATUS_FAILED or status == GUIDE_STATUS_APPLIED


static func can_delete_manual_guide(status: String) -> bool:
	return status != GUIDE_STATUS_SUBMITTING and status != GUIDE_STATUS_DELETING


static func format_message_preview(message_text: String) -> String:
	var preview_text: String = message_text.replace("\n", " ").strip_edges()
	if preview_text.length() > 96:
		return preview_text.substr(0, 96) + "..."

	return preview_text


static func string_or_empty(value: Variant) -> String:
	if value == null:
		return ""

	return str(value)


static func make_session_title(message_text: String) -> String:
	var one_line: String = message_text.replace("\n", " ").strip_edges()
	if one_line.length() > 24:
		return one_line.substr(0, 24)

	if one_line.is_empty():
		return "新会话"

	return one_line


static func get_image_mime_type(resource_path: String) -> String:
	var extension: String = resource_path.get_extension().to_lower()
	match extension:
		"png":
			return "image/png"
		"jpg", "jpeg":
			return "image/jpeg"
		"webp":
			return "image/webp"
		"gif":
			return "image/gif"

	return ""


static func is_supported_image_resource_path(resource_path: String) -> bool:
	return not get_image_mime_type(resource_path).is_empty()


static func context_array_has_images(contexts: Array) -> bool:
	for context_value: Variant in contexts:
		if typeof(context_value) != TYPE_DICTIONARY:
			continue

		var context_dictionary: Dictionary = context_value as Dictionary
		var context_kind: String = str(context_dictionary.get("kind", ""))
		if context_kind == "image":
			return true
		if context_kind == "filesystem_selection" and filesystem_selection_has_image_paths(context_dictionary):
			return true

	return false


static func filesystem_selection_has_image_paths(context: Dictionary) -> bool:
	var data_value: Variant = context.get("data", {})
	if typeof(data_value) != TYPE_DICTIONARY:
		return false

	var data_dictionary: Dictionary = data_value as Dictionary
	var selected_paths_value: Variant = data_dictionary.get("selectedPaths", [])
	if typeof(selected_paths_value) != TYPE_ARRAY:
		return false

	var selected_paths: Array = selected_paths_value as Array
	for selected_path_value: Variant in selected_paths:
		if typeof(selected_path_value) != TYPE_DICTIONARY:
			continue

		var selected_path: Dictionary = selected_path_value as Dictionary
		if str(selected_path.get("kind", "")) != "file":
			continue
		if is_supported_image_resource_path(str(selected_path.get("resourcePath", ""))):
			return true

	return false


static func model_capabilities_support_image(capabilities: Dictionary) -> bool:
	return bool(capabilities.get("imageInput", false))


static func format_byte_size(byte_size: int) -> String:
	if byte_size >= 1024 * 1024:
		return "%.2f MiB" % (float(byte_size) / float(1024 * 1024))
	if byte_size >= 1024:
		return "%.1f KiB" % (float(byte_size) / 1024.0)

	return "%d B" % byte_size


static func validate_image_context_limits(contexts: Array, resource_path: String, next_byte_size: int) -> String:
	if next_byte_size <= 0:
		return "图片文件为空或无法读取。"
	if next_byte_size > MAX_IMAGE_BYTES:
		return "单张图片不能超过 %s。" % format_byte_size(MAX_IMAGE_BYTES)

	var normalized_path: String = resource_path.strip_edges()
	var image_count: int = 0
	var total_bytes: int = 0
	for context_value: Variant in contexts:
		if typeof(context_value) != TYPE_DICTIONARY:
			continue

		var context_dictionary: Dictionary = context_value as Dictionary
		if str(context_dictionary.get("kind", "")) != "image":
			continue
		if str(context_dictionary.get("resourcePath", "")).strip_edges() == normalized_path:
			continue

		image_count += 1
		var data_value: Variant = context_dictionary.get("data", {})
		if typeof(data_value) != TYPE_DICTIONARY:
			continue

		var data_dictionary: Dictionary = data_value as Dictionary
		total_bytes += int(data_dictionary.get("byteSize", 0))

	if image_count >= MAX_IMAGE_ATTACHMENTS:
		return "每条消息最多附加 %d 张图片。" % MAX_IMAGE_ATTACHMENTS
	if total_bytes + next_byte_size > MAX_TOTAL_IMAGE_BYTES:
		return "图片总大小不能超过 %s。" % format_byte_size(MAX_TOTAL_IMAGE_BYTES)

	return ""


static func get_utc_timestamp() -> String:
	return "%sZ" % Time.get_datetime_string_from_system(true, false)


static func format_approval_args_preview(args_value: Variant, preview_limit: int) -> String:
	var args_text: String = JSON.stringify(args_value, "\t")
	if args_text.length() <= preview_limit:
		return args_text

	return "%s\n\n... 已截断显示，完整参数保存在后端审批队列中，批准时仍会执行完整内容。" % args_text.substr(0, preview_limit)


static func localize_tool_name_for_display(raw_tool_name: String) -> String:
	match raw_tool_name:
		"mcp_godot_read_text_file", "read_text_file":
			return "读取文件"
		"mcp_godot_search_text", "search_text":
			return "搜索文本"
		"mcp_godot_create_text_file", "mcp_godot_propose_create_text_file", "create_text_file":
			return "创建文件"
		"mcp_godot_overwrite_text_file", "mcp_godot_propose_overwrite_text_file", "overwrite_text_file":
			return "覆盖文件"
		"mcp_godot_replace_text_in_file", "mcp_godot_propose_replace_text_in_file", "replace_text_in_file":
			return "替换文件内容"
		"mcp_godot_delete_file", "delete_file":
			return "删除文件"
		"mcp_godot_inspect_scene_tree", "inspect_scene_tree":
			return "查看场景树"
		"mcp_godot_create_scene", "mcp_godot_propose_create_scene", "create_scene":
			return "创建场景"
		"mcp_godot_add_node_to_scene", "mcp_godot_propose_add_node_to_scene", "add_node_to_scene":
			return "添加场景节点"
		"mcp_godot_attach_script_to_node", "mcp_godot_propose_attach_script_to_node", "attach_script_to_node":
			return "挂载脚本"
		"mcp_godot_connect_signal_in_scene", "mcp_godot_propose_connect_signal_in_scene", "connect_signal_in_scene":
			return "连接信号"
		"mcp_godot_apply_scene_patch", "mcp_godot_propose_apply_scene_patch", "apply_scene_patch":
			return "批量编辑场景"
		"mcp_godot_lsp_get_status", "lsp_get_status":
			return "检查 LSP 状态"
		"mcp_godot_lsp_get_file_diagnostics", "lsp_get_file_diagnostics":
			return "读取脚本诊断"
		"mcp_godot_lsp_get_document_symbols", "lsp_get_document_symbols":
			return "查看脚本符号"
		"mcp_godot_lsp_hover", "lsp_hover":
			return "查看 Hover 信息"
		"mcp_godot_lsp_goto_definition", "lsp_goto_definition":
			return "查找定义"
		"mcp_godot_dap_get_status", "dap_get_status":
			return "检查 DAP 状态"
		"mcp_godot_dap_get_last_error", "dap_get_last_error":
			return "读取运行错误"
		"mcp_godot_dap_get_stack_trace", "dap_get_stack_trace":
			return "读取调用栈"
		"mcp_godot_dap_get_variables", "dap_get_variables":
			return "读取变量"
		"mcp_terminal_run_safe_preset", "run_safe_preset":
			return "运行验证命令"
		"mcp_terminal_run_write_preset", "run_write_preset":
			return "运行写入命令"
		"mcp_terminal_run_godot_scene_script", "run_godot_scene_script":
			return "执行场景脚本"

	if raw_tool_name.begins_with("mcp_custom_"):
		return "自定义 MCP 工具"

	if raw_tool_name.begins_with("mcp_"):
		return "内部工具"

	return raw_tool_name


static func format_context_usage_percent(ratio: float) -> String:
	var percent: float = ratio * 100.0
	if percent > 0.0 and percent < 0.01:
		return "<0.01%"
	if percent < 1.0:
		return "%.2f%%" % percent
	if percent < 10.0:
		return "%.1f%%" % percent

	return "%d%%" % int(round(percent))


static func format_compact_token_count(token_count: int) -> String:
	var absolute_count: int = absi(token_count)
	if absolute_count >= 1000000:
		return "%.1fM" % (float(token_count) / 1000000.0)
	if absolute_count >= 1000:
		return "%.1fk" % (float(token_count) / 1000.0)

	return str(token_count)


static func format_relative_time(timestamp: String) -> String:
	if timestamp.is_empty():
		return ""

	return timestamp.replace("T", " ").replace("Z", "")


static func workflow_status_prefix(status: String) -> String:
	if status == "done":
		return "[x]"
	if status == "running":
		return "[~]"
	if status == "failed":
		return "[!]"
	if status == "paused":
		return "[pause]"

	return "[ ]"


static func workflow_status_color(status: String) -> Color:
	if status == "running":
		return Color(0.7, 0.86, 1.0, 1.0)
	if status == "done":
		return Color(0.72, 1.0, 0.76, 1.0)
	if status == "failed":
		return Color(1.0, 0.55, 0.55, 1.0)
	if status == "paused":
		return Color(1.0, 0.88, 0.48, 1.0)

	return Color(0.86, 0.86, 0.86, 1.0)


static func extract_todo_items(text: String) -> Array[Dictionary]:
	var todos: Array[Dictionary] = []
	var lines: PackedStringArray = text.split("\n")
	var has_task_marker: bool = false
	var current_task_block: Array[Dictionary] = []

	for raw_line: String in lines:
		var line: String = raw_line.strip_edges()
		if line.begins_with("- [ ] ") or line.begins_with("* [ ] "):
			has_task_marker = true
			current_task_block.append({ "text": line.substr(6).strip_edges(), "checked": false })
		elif line.begins_with("- [x] ") or line.begins_with("- [X] ") or line.begins_with("* [x] ") or line.begins_with("* [X] "):
			has_task_marker = true
			current_task_block.append({ "text": line.substr(6).strip_edges(), "checked": true })
		elif not line.is_empty() and not current_task_block.is_empty():
			todos = current_task_block.duplicate()
			current_task_block.clear()

	if has_task_marker:
		if not current_task_block.is_empty():
			todos = current_task_block.duplicate()
		return todos

	var in_todo_block: bool = false
	for raw_line: String in lines:
		var line: String = raw_line.strip_edges()
		var lower_line: String = line.to_lower()
		if lower_line == "todo" or lower_line == "todo:" or lower_line.contains("待办"):
			in_todo_block = true
			continue

		if not in_todo_block:
			continue

		if line.is_empty():
			if not todos.is_empty():
				break
			continue

		var dot_index: int = line.find(". ")
		if dot_index > 0 and line.substr(0, dot_index).is_valid_int():
			todos.append({ "text": line.substr(dot_index + 2).strip_edges(), "checked": false })
		elif line.begins_with("- ") or line.begins_with("* "):
			todos.append({ "text": line.substr(2).strip_edges(), "checked": false })
		elif not todos.is_empty():
			break

	return todos
