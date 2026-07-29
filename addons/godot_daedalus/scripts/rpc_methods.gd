@tool
extends RefCounted

const PING: String = "ping"
const BACKEND_HEALTH: String = "backend.health"
const COMMAND_LIST: String = "command.list"
const CLIENT_HELLO: String = "client.hello"
const CLIENT_INFO: String = "client.info"
const PROVIDER_CONFIGURE: String = "provider.configure"
const PROVIDER_CONFIG_GET: String = "provider.config.get"
const PROVIDER_CURRENT_GET: String = "provider.current.get"
const PROVIDER_MODEL_SELECTION_GET: String = "provider.modelSelection.get"
const PROVIDER_CONFIG_SET: String = "provider.config.set"
const PROVIDER_CONFIG_CLEAR: String = "provider.config.clear"
const PROVIDER_MODELS_LIST: String = "provider.models.list"
const AI_CHAT: String = "ai.chat"
const AI_NEXT_STEP_HINTS: String = "ai.next_step_hints"
const AI_CANCEL: String = "ai.cancel"
const AGENT_RUN_RETRY: String = "agent.run.retry"
const PROMPT_LIST: String = "prompt.list"
const USER_PROMPT_GET: String = "userPrompt.get"
const USER_PROMPT_SET: String = "userPrompt.set"
const GENERAL_SETTINGS_GET: String = "generalSettings.get"
const GENERAL_SETTINGS_UPDATE: String = "generalSettings.update"
const WEB_SEARCH_SETTINGS_GET: String = "webSearchSettings.get"
const WEB_SEARCH_SETTINGS_UPDATE: String = "webSearchSettings.update"
const SKILL_LIST: String = "skill.list"
const SKILL_GET: String = "skill.get"
const SKILL_SET_ENABLED: String = "skill.set_enabled"
const SKILL_UPDATE: String = "skill.update"
const SKILL_REMOVE: String = "skill.remove"
const SKILL_INSTALL: String = "skill.install"
const SKILL_RELOAD: String = "skill.reload"
const SESSION_RESET: String = "session.reset"
const SESSION_INFO: String = "session.info"
const SESSION_CREATE: String = "session.create"
const SESSION_OPEN: String = "session.open"
const SESSION_SUBSCRIBE: String = "session.subscribe"
const SESSION_UNSUBSCRIBE: String = "session.unsubscribe"
const SESSION_EDITOR_BIND: String = "session.editor.bind"
const SESSION_TIMELINE: String = "session.timeline"
const SESSION_INTEGRITY_CHECK: String = "session.integrity.check"
const SESSION_LIST: String = "session.list"
const SESSION_BROWSER_SNAPSHOT: String = "session.browser.snapshot"
const SESSION_ARCHIVE: String = "session.archive"
const SESSION_ARCHIVED_LIST: String = "session.archived.list"
const SESSION_ARCHIVED_RESTORE: String = "session.archived.restore"
const SESSION_ARCHIVED_DELETE: String = "session.archived.delete"
const SESSION_SAVE: String = "session.save"
const SESSION_MODEL_SET: String = "session.model.set"
const SESSION_DELETE: String = "session.delete"
const SESSION_RENAME: String = "session.rename"
const SESSION_COMPRESS: String = "session.compress"
const SESSION_SUMMARY: String = "session.summary"
const SESSION_OVERVIEW_GET: String = "session.overview.get"
const SESSION_CONTEXT_ESTIMATE: String = "session.context.estimate"
const SESSION_WORKFLOW_TODO_DISMISS: String = "session.workflow.todo.dismiss"
const SESSION_WORKBENCH_GET: String = "session.workbench.get"
const SESSION_WORKBENCH_PATCH: String = "session.workbench.patch"
const SESSION_GUIDE_ADD: String = "session.guide.add"
const SESSION_GUIDE_UPDATE: String = "session.guide.update"
const SESSION_GUIDE_DELETE: String = "session.guide.delete"
const MESSAGE_QUEUE_LIST: String = "message.queue.list"
const MESSAGE_QUEUE_ADD: String = "message.queue.add"
const MESSAGE_QUEUE_UPDATE: String = "message.queue.update"
const MESSAGE_QUEUE_REMOVE: String = "message.queue.remove"
const MESSAGE_QUEUE_STATUS: String = "message.queue.status"
const MCP_LIST_TOOLS: String = "mcp.listTools"
const MCP_CALL_TOOL: String = "mcp.callTool"
const MCP_LIST_RESOURCES: String = "mcp.listResources"
const MCP_READ_RESOURCE: String = "mcp.readResource"
const MCP_CONFIG_LIST: String = "mcp.config.list"
const MCP_CONFIG_ADD: String = "mcp.config.add"
const MCP_CONFIG_UPDATE: String = "mcp.config.update"
const MCP_CONFIG_REMOVE: String = "mcp.config.remove"
const MCP_CONFIG_SET_ENABLED: String = "mcp.config.setEnabled"
const TOOL_CATALOG_LIST: String = "tool.catalog.list"
const TOOL_EXECUTE: String = "tool.execute"
const FILE_CHANGE_CREATE: String = "fileChange.create"
const FILE_CHANGE_OVERWRITE: String = "fileChange.overwrite"
const FILE_CHANGE_DELETE: String = "fileChange.delete"
const FILE_EDIT_BATCH_GET: String = "fileEdit.batch.get"
const ATTACHMENT_IMAGE_SAVE: String = "attachment.image.save"
const ATTACHMENT_IMAGE_GENERATED_GET: String = "attachment.image.generated.get"
const PLAN_GET: String = "plan.get"
const PLAN_CLARIFY: String = "plan.clarify"
const PLAN_REVISE: String = "plan.revise"
const PLAN_APPROVE: String = "plan.approve"
const APPROVAL_LIST: String = "approval.list"
const APPROVAL_MODE_SET: String = "approval.mode.set"
const APPROVAL_APPROVE: String = "approval.approve"
const APPROVAL_REJECT: String = "approval.reject"
const ENVIRONMENT_CONFIGURE: String = "environment.configure"
const EDITOR_CONTEXT_UPDATE: String = "editor.context.update"
const EDITOR_INSTANCES_LIST: String = "editor.instances.list"
const EDITOR_TOOL_RESULT: String = "editor.tool.result"
const WORKSPACE_LIST: String = "workspace.list"
const WORKSPACE_SELECT: String = "workspace.select"
const WORKSPACE_DELETE: String = "workspace.delete"
const WORKSPACE_INFO: String = "workspace.info"


static func all() -> PackedStringArray:
	return [
		PING,
		BACKEND_HEALTH,
		COMMAND_LIST,
		CLIENT_HELLO,
		CLIENT_INFO,
		PROVIDER_CONFIGURE,
		PROVIDER_CONFIG_GET,
		PROVIDER_CURRENT_GET,
		PROVIDER_MODEL_SELECTION_GET,
		PROVIDER_CONFIG_SET,
		PROVIDER_CONFIG_CLEAR,
		PROVIDER_MODELS_LIST,
		AI_CHAT,
		AI_NEXT_STEP_HINTS,
		AI_CANCEL,
		AGENT_RUN_RETRY,
		PROMPT_LIST,
		USER_PROMPT_GET,
		USER_PROMPT_SET,
		GENERAL_SETTINGS_GET,
		GENERAL_SETTINGS_UPDATE,
		WEB_SEARCH_SETTINGS_GET,
		WEB_SEARCH_SETTINGS_UPDATE,
		SKILL_LIST,
		SKILL_GET,
		SKILL_SET_ENABLED,
		SKILL_UPDATE,
		SKILL_REMOVE,
		SKILL_INSTALL,
		SKILL_RELOAD,
		SESSION_RESET,
		SESSION_INFO,
		SESSION_CREATE,
		SESSION_OPEN,
		SESSION_SUBSCRIBE,
		SESSION_UNSUBSCRIBE,
		SESSION_EDITOR_BIND,
		SESSION_TIMELINE,
		SESSION_INTEGRITY_CHECK,
		SESSION_LIST,
		SESSION_BROWSER_SNAPSHOT,
		SESSION_ARCHIVE,
		SESSION_ARCHIVED_LIST,
		SESSION_ARCHIVED_RESTORE,
		SESSION_ARCHIVED_DELETE,
		SESSION_SAVE,
		SESSION_MODEL_SET,
		SESSION_DELETE,
		SESSION_RENAME,
		SESSION_COMPRESS,
		SESSION_SUMMARY,
		SESSION_OVERVIEW_GET,
		SESSION_CONTEXT_ESTIMATE,
		SESSION_WORKFLOW_TODO_DISMISS,
		SESSION_WORKBENCH_GET,
		SESSION_WORKBENCH_PATCH,
		SESSION_GUIDE_ADD,
		SESSION_GUIDE_UPDATE,
		SESSION_GUIDE_DELETE,
		MESSAGE_QUEUE_LIST,
		MESSAGE_QUEUE_ADD,
		MESSAGE_QUEUE_UPDATE,
		MESSAGE_QUEUE_REMOVE,
		MESSAGE_QUEUE_STATUS,
		MCP_LIST_TOOLS,
		MCP_CALL_TOOL,
		MCP_LIST_RESOURCES,
		MCP_READ_RESOURCE,
		MCP_CONFIG_LIST,
		MCP_CONFIG_ADD,
		MCP_CONFIG_UPDATE,
		MCP_CONFIG_REMOVE,
		MCP_CONFIG_SET_ENABLED,
		TOOL_CATALOG_LIST,
		TOOL_EXECUTE,
		FILE_CHANGE_CREATE,
		FILE_CHANGE_OVERWRITE,
		FILE_CHANGE_DELETE,
		FILE_EDIT_BATCH_GET,
		ATTACHMENT_IMAGE_SAVE,
		ATTACHMENT_IMAGE_GENERATED_GET,
		PLAN_GET,
		PLAN_CLARIFY,
		PLAN_REVISE,
		PLAN_APPROVE,
		APPROVAL_LIST,
		APPROVAL_MODE_SET,
		APPROVAL_APPROVE,
		APPROVAL_REJECT,
		ENVIRONMENT_CONFIGURE,
		EDITOR_CONTEXT_UPDATE,
		EDITOR_INSTANCES_LIST,
		EDITOR_TOOL_RESULT,
		WORKSPACE_LIST,
		WORKSPACE_SELECT,
		WORKSPACE_DELETE,
		WORKSPACE_INFO
	]
