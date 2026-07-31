@tool
extends VBoxContainer

const DEFAULT_BACKEND_URL: String = "ws://127.0.0.1:38180"
const DEVELOPMENT_BACKEND_URL: String = "ws://127.0.0.1:38181"
const MAIN_HELPERS: GDScript = preload("res://addons/godot_daedalus/scripts/main_helpers.gd")
const RPC_METHODS: GDScript = preload("res://addons/godot_daedalus/scripts/rpc_methods.gd")
const USER_MESSAGE_ITEM_SCENE: PackedScene = preload("res://addons/godot_daedalus/scenes/user_message_item.tscn")
const ASSISTANT_MARKDOWN_ITEM_SCENE: PackedScene = preload("res://addons/godot_daedalus/scenes/assistant_markdown_item.tscn")
const TOOL_CALL_ITEM_SCENE: PackedScene = preload("res://addons/godot_daedalus/scenes/tool_call_item/tool_call_item.tscn")
const STATUS_ITEM_SCENE: PackedScene = preload("res://addons/godot_daedalus/scenes/tool_call_item/status_item.tscn")
const SESSION_ITEM_SCENE: PackedScene = preload("res://addons/godot_daedalus/scenes/session_item.tscn")
const TODO_ITEM_SCENE: PackedScene = preload("res://addons/godot_daedalus/scenes/todo_item.tscn")
const ADDITIONAL_CONTEXT_ITEM_SCENE: PackedScene = preload("res://addons/godot_daedalus/scenes/additional_context_item.tscn")
const PLAN_VIEWER_SCENE: PackedScene = preload("res://addons/godot_daedalus/scenes/plan_viewer.tscn")
const PLAN_CLARIFICATION_ICON_UID: String = "res://addons/godot_daedalus/assets/icons/ask.svg"
const CONTEXT_POPUP_MENU_UID: String = "res://addons/godot_daedalus/scenes/context_popup_menu.tscn"
const CONTEXT_ICON_DIR: String = "res://addons/godot_daedalus/assets/icons"
const FRONTEND_CONFIG_PATH: String = "user://godot_daedalus_frontend.cfg"
const FRONTEND_CONFIG_SECTION: String = "frontend"

const CONFIG_BACKEND_URL_KEY: String = "backend_url"
const CONFIG_BACKEND_DEV_DIR_KEY: String = "backend_dev_dir"
const CONFIG_NEXT_STEP_HINTS_KEY: String = "next_step_hints_enabled"
const CONFIG_CHECK_FOR_UPDATES_KEY: String = "check_for_updates_enabled"

const CONNECTED_ICON: Texture2D = preload("res://addons/godot_daedalus/assets/icons/connected.svg")
const CONNECT_FAILED_ICON: Texture2D = preload("res://addons/godot_daedalus/assets/icons/connect_failed.svg")
const DISCONNECTED_ICON: Texture2D = preload("res://addons/godot_daedalus/assets/icons/disconnected.svg")
const STAUTS_WARNING: Texture2D = preload("res://addons/godot_daedalus/assets/icons/status_warning.svg")
const GUIDE_NOW_ICON: Texture2D = preload("res://addons/godot_daedalus/assets/icons/guide.svg")
const EDIT_ICON: Texture2D = preload("res://addons/godot_daedalus/assets/icons/edit.svg")
const DELETE_ICON: Texture2D = preload("res://addons/godot_daedalus/assets/icons/remove.svg")
const SETTINGS_MENU_UID: String = "res://addons/godot_daedalus/scenes/settings_menu/settings_menu.tscn"
const BACKEND_LAUNCHER_SCRIPT: GDScript = preload("res://addons/godot_daedalus/scripts/backend_launcher.gd")
const SLASH_COMMAND_OVERLAY_SCRIPT: GDScript = preload("res://addons/godot_daedalus/scripts/slash_command_overlay.gd")
const TEXT_COMPLETION_ACCEPT_ACTION: StringName = &"ui_text_completion_accept"
const MAX_CONNECT_ATTEMPTS: int = 20
const CONNECT_RETRY_SECONDS: float = 0.5
const BACKEND_START_TIMEOUT_MSEC: int = 10000
const BACKEND_HEALTH_TIMEOUT_MSEC: int = 2500
const PLUGIN_VERSION: String = "1.3.3"
const PLUGIN_PROTOCOL_VERSION: int = 3
const STUDIO_BINDING_VERSION: String = "1.0.7"
const WEBSOCKET_BUFFER_SIZE: int = 4194304
const MAX_MESSAGES_PER_FRAME: int = 24
const MAX_MESSAGE_PROCESS_MSEC: int = 6
const TIMELINE_BUFFER_ITEMS: int = 10
const TIMELINE_PAGE_LOAD_THRESHOLD: int = 96
const TIMELINE_NODE_POOL_LIMIT_PER_TYPE: int = 32
const TIMELINE_RENDER_BUDGET_PER_FRAME: int = 8
const TIMELINE_MAX_LOADED_BLOCKS: int = 240
const TIMELINE_ESTIMATED_USER_HEIGHT: float = 88.0
const TIMELINE_ESTIMATED_ASSISTANT_HEIGHT: float = 140.0
const TIMELINE_ESTIMATED_TOOL_HEIGHT: float = 72.0
const TIMELINE_ESTIMATED_THINKING_HEIGHT: float = 72.0
const TIMELINE_ESTIMATED_STATUS_HEIGHT: float = 74.0
const TIMELINE_MIN_ITEM_HEIGHT: float = 32.0
const TIMELINE_BOTTOM_FOLLOW_THRESHOLD: float = 32.0
const SESSION_OPEN_MESSAGE_LIMIT: int = 80
const APPROVAL_ARGS_PREVIEW_LIMIT: int = 4000
const DELTA_FLUSH_INTERVAL_MSEC: int = 45
const TIMELINE_MEASURE_INTERVAL_MSEC: int = 240
const WORKBENCH_PATCH_DEBOUNCE_SECONDS: float = 0.18
const MAX_QUEUED_MESSAGES: int = 12
const MESSAGE_QUEUE_STATUS_PENDING: StringName = &"pending"
const MESSAGE_QUEUE_STATUS_SENDING: StringName = &"sending"
const MESSAGE_QUEUE_STATUS_APPROVAL: StringName = &"approval"
const MESSAGE_QUEUE_STATUS_FAILED: StringName = &"failed"
const MESSAGE_QUEUE_STATUS_CANCELLED: StringName = &"cancelled"
const MESSAGE_QUEUE_STATUS_REJECTED: StringName = &"rejected"
const GUIDE_STATUS_DRAFT: StringName = &"draft"
const GUIDE_STATUS_SUBMITTING: StringName = &"submitting"
const GUIDE_STATUS_PENDING: StringName = &"pending"
const GUIDE_STATUS_DELETING: StringName = &"deleting"
const GUIDE_STATUS_APPLIED: StringName = &"applied"
const GUIDE_STATUS_FAILED: StringName = &"failed"
const MESSAGE_TREE_STATUS_COLUMN: int = 0
const MESSAGE_TREE_MESSAGE_COLUMN: int = 1
const MESSAGE_TREE_ACTIONS_COLUMN: int = 2
const MESSAGE_TREE_BUTTON_GUIDE_NOW: int = 1
const MESSAGE_TREE_BUTTON_EDIT: int = 2
const MESSAGE_TREE_BUTTON_DELETE: int = 3
const NEXT_STEP_HINT_ACTION_PREFIX: String = "next-step-hint:"
const ADD_CONTEXT_SELECTED_NODES_ID: int = 1
const ADD_CONTEXT_ACTIVE_SCENE_ID: int = 2
const ADD_CONTEXT_FILE_ID: int = 3
const ADD_CONTEXT_FOLDER_ID: int = 4
const ADD_CONTEXT_SCRIPT_SELECTION_ID: int = 5
const ADD_CONTEXT_FILESYSTEM_SELECTION_ID: int = 6
const ADD_CONTEXT_CLEAR_UNPINNED_ID: int = 7
const ADD_CONTEXT_IMAGE_ID: int = 8
const LIVE_EDITOR_SELECTION_CONTEXT_ID: String = "editor-selection-live"
const LIVE_SCRIPT_SELECTION_CONTEXT_ID: String = "script-selection-live"
const LIVE_FILESYSTEM_SELECTION_CONTEXT_ID: String = "filesystem-selection-live"
const SCRIPT_SELECTION_PREVIEW_LIMIT: int = 2000
const SCRIPT_LINE_PREVIEW_LIMIT: int = 500
const SCRIPT_EDITOR_TEXT_PREVIEW_LIMIT: int = 12000
const FILESYSTEM_CONTEXT_MAX_PATHS: int = 40
const ADDITIONAL_CONTEXT_MAX_ITEMS: int = 10
const EDITOR_CONTEXT_POLL_INTERVAL_MSEC: int = 500

const DEFAULT_PROVIDER_ID: String = "deepseek"

const APPROVAL_MODE_IDS: PackedStringArray = [
	"manual",
	"auto-safe"
]

const CHAT_MODE_AGENT: String = "agent"
const CHAT_MODE_ASK: String = "ask"
const CHAT_MODE_PLAN: String = "plan"
const CHAT_MODE_ID_AGENT: int = 0
const CHAT_MODE_ID_ASK: int = 1
const CHAT_MODE_ID_PLAN: int = 2
const CHAT_MODE_IDS: PackedStringArray = [
	CHAT_MODE_AGENT,
	CHAT_MODE_ASK,
	CHAT_MODE_PLAN
]
const CHAT_MODE_LABELS: PackedStringArray = [
	"Agent",
	"Ask",
	"Plan"
]

@onready var main_viewer: VBoxContainer = %MainViewer
@onready var back_button: Button = %BackButton
@onready var workspace_filter_button: OptionButton = %WorkspaceFilterButton
@onready var search_session_line_edit: LineEdit = %SearchSessionLineEdit
@onready var session_option_button: OptionButton = %SessionOptionButton
@onready var create_new_session_button: Button = %CreateNewSessionButton
@onready var context_length_button: Button = %ContextLengthButton
@onready var session_list_viewer: VBoxContainer = %SessionListViewer
@onready var session_list: VBoxContainer = %SessionList
@onready var background_context_viewer: VBoxContainer = %BackgroundContextViewer
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var background_context_container: VBoxContainer = %BackgroundContextContainer
@onready var approval_dialog: PanelContainer = %ApprovalDialog
@onready var clarification_dialog: PanelContainer = %ClarificationDialog
@onready var plan_approval_dialog: PanelContainer = %PlanApprovalDialog
@onready var send_button: Button = %SendButton
@onready var stop_button: Button = %StopButton
@onready var status_button: Button = %StatusButton
@onready var text_edit: TextEdit = %TextEdit
@onready var mode_button: MenuButton = %ModeButton
@onready var provider_option_button: OptionButton = %ProviderOptionButton
@onready var model_button: OptionButton = %ModelButton
@onready var effort_button: OptionButton = %EffortButton
@onready var approval_mode_button: OptionButton = %ApprovalModeButton
@onready var approval_title_label: Label = %ApprovalTitleLabel
@onready var approval_description_label: TextEdit = %ApprovalDescriptionLabel
@onready var boot_splash: CenterContainer = %BootSplash
@onready var backend_manager_button: LinkButton = %BackendManagerButton
@onready var todo_list: FoldableContainer = %TodoList
@onready var todo_container: VBoxContainer = %TodoContainer
@onready var message_queue_panel: PanelContainer = %MessageQueue
@onready var message_tree: Tree = %MessageTree
@onready var additional_context_viewer: ScrollContainer = %AdditionalContextViewer
@onready var additional_context_container: HBoxContainer = %AdditionalContextContainer
@onready var add_context_button: MenuButton = %AddContextButton
@onready var additional_context_controller: DaedalusAdditionalContextController = %AdditionalContextController
@onready var editor_bridge_controller: DaedalusEditorBridgeController = %EditorBridgeController
@onready var file_edit_controller: DaedalusFileEditController = %FileEditController
@onready var backend_connection_controller: DaedalusBackendConnectionController = %BackendConnectionController
@onready var provider_navigation_controller: DaedalusProviderNavigationController = %ProviderNavigationController

var connected_workspace_id: String
var socket_ready: bool
var workspace_ready: bool
var has_connected_once: bool
var connection_attempts: int
var connection_attempt_generation: int
var is_connecting: bool
var backend_recovery_mode: bool
var restore_session_after_reconnect_id: String
var connection_status_entry_id: String
var pending_recovery_status_after_session_open: bool
var active_stream_id: String
var chat_request_id: int
var active_session_id: String
var pending_chat_text: String
var pending_chat_additional_context: Array[Dictionary]
var pending_clipboard_image_payload: Dictionary
var pending_clipboard_image_save_request_id: String
var pending_approval_id: String
var sessions_by_id: Dictionary[String, Dictionary]
var session_ids_in_order: PackedStringArray
var renamed_session_metadata_by_id: Dictionary[String, Dictionary]
var archived_sessions_by_id: Dictionary[String, Dictionary]
var archived_session_ids_in_order: PackedStringArray
var custom_mcp_servers: Array[Dictionary]
var workspaces_by_id: Dictionary[String, Dictionary]
var selected_workspace_filter: String
var session_search_text: String
var tool_items_by_call_id: Dictionary[String, Node]
var active_assistant_item: Node
var active_thinking_item: Node
var active_assistant_text: String
var last_todo_signature: String
var provider_config_status: Dictionary
var web_search_settings_status: Dictionary
var timeline_entries: Array[Dictionary]
var timeline_heights: Array[float]
var timeline_prefix_heights: Array[float]
var timeline_entry_ids: Dictionary[String, bool]
var timeline_entry_indices_by_id: Dictionary[String, int]
var timeline_node_pools_by_type: Dictionary[String, Array]
var rendered_entry_nodes: Dictionary[String, Node]
var rendered_entry_indices: Dictionary[String, int]
var timeline_top_spacer: Control
var timeline_visible_container: VBoxContainer
var timeline_bottom_spacer: Control
var timeline_render_queued: bool
var timeline_measure_queued: bool
var timeline_follow_bottom: bool = true
var timeline_scroll_to_bottom_queued: bool
var timeline_deferred_scroll_queued: bool
var timeline_deferred_scroll_version: int
var timeline_heights_dirty: bool
var timeline_dirty_height_start_index: int = -1
var timeline_block_offset: int
var timeline_has_more_before: bool
var timeline_has_more_after: bool
var timeline_loading_before: bool
var timeline_loading_after: bool
var active_assistant_entry_id: String
var active_thinking_entry_id: String
var active_tool_entry_ids_by_call_id: Dictionary[String, String]
var active_stream_request_id: String
var active_stream_started_at_utc: String
var active_stream_status_code: String
var paused_stream_request_id: String
var paused_stream_started_at_utc: String
var paused_assistant_entry_id: String
var active_workflow_id: String
var pending_assistant_delta_text: String
var pending_assistant_delta_queued: bool
var pending_assistant_delta_flush_at_msec: int
var pending_thinking_delta_text: String
var pending_thinking_delta_queued: bool
var pending_thinking_delta_flush_at_msec: int
var timeline_measure_after_msec: int
var workflow_todo_nodes_by_id: Dictionary[String, Node]
var workflow_phase_nodes_by_id: Dictionary[String, Node]
var latest_context_info: Dictionary
var context_popup_menu: PopupPanel
var context_popup_open_after_info: bool
var active_settings_menu: Node
var backend_url: String = DEFAULT_BACKEND_URL
var backend_auth_protocol: String
var backend_dev_dir: String
var backend_launcher: RefCounted
var backend_launch_started: bool
var backend_launch_deadline_msec: int
var backend_health_request_id: String
var backend_health_pending: bool
var backend_health_deadline_msec: int
var pending_socket_open_was_recovering: bool
var pending_socket_open_session_id: String
var pending_workspace_ready_was_recovering: bool
var pending_workspace_ready_session_id: String
var connected_backend_version: String
var slash_command_overlay: Control
var slash_commands: Array[Dictionary]
var slash_command_items: Array
var slash_command_selected_index: int
var slash_command_completion_consumed: bool
var completion_trigger: String
var skill_summaries: Array[Dictionary]
var skill_catalog_revision: String
var custom_instructions: String
var next_step_hints_enabled: bool
var check_for_updates_enabled: bool = true
var active_chat_mode: String = CHAT_MODE_AGENT
var active_provider_id: String = DEFAULT_PROVIDER_ID
var provider_ids: PackedStringArray = [DEFAULT_PROVIDER_ID]
var provider_names: PackedStringArray = ["DeepSeek"]
var model_ids: PackedStringArray
var model_names: PackedStringArray
var model_capabilities: Array[Dictionary]
var pending_provider_config_api_key: String
var pending_provider_config_base_url: String
var pending_provider_config_provider: String = DEFAULT_PROVIDER_ID
var pending_provider_config_model_routing: Dictionary
var pending_provider_config_save_after_connect: bool
var queued_messages: Array[Dictionary]
var message_queue_next_id: int
var active_queue_message_id: int
var workbench_revision: int
var workbench_patch_sequence: int
var agent_run_revisions_by_id: Dictionary[String, int]
var agent_run_sequences_by_session_id: Dictionary[String, int]
var applying_workbench_snapshot: bool
var workbench_composer_patch_debounce_pending: bool
var workbench_composer_patch_include_text: bool
var workbench_composer_patch_include_context: bool
var workbench_context_patch_in_flight: bool
var workbench_context_patch_signature: String
var manual_guides: Array[Dictionary]
var manual_guide_next_id: int
var editing_guide_local_id: String
var next_step_hint_request_id: String
var next_step_hint_anchor_request_id: String
var next_step_hint_entry_ids: PackedStringArray
var next_step_hints_by_action_id: Dictionary[String, String]
var next_step_hints_signature: String
var pending_editor_bridge_plugin: EditorPlugin
var pending_plan_detail_requests: Dictionary[String, Dictionary]
var plan_assistant_entry_ids_by_plan_id: Dictionary[String, String]


func _load_slash_commands() -> void:
	slash_commands.clear()
	_hide_slash_command_popup()
	_send_request(RPC_METHODS.COMMAND_LIST, {}, "command-list")


func _load_skills() -> void:
	_send_request(RPC_METHODS.SKILL_LIST, {}, "skill-list")


func _get_fallback_models_for_provider(provider_id: String) -> Array[Dictionary]:
	var providers_value: Variant = provider_config_status.get("providers", [])
	if typeof(providers_value) == TYPE_ARRAY:
		for provider_value: Variant in providers_value as Array:
			if typeof(provider_value) != TYPE_DICTIONARY:
				continue
			var provider_status: Dictionary = provider_value as Dictionary
			if str(provider_status.get("provider", "")).strip_edges() != provider_id:
				continue
			var cached_models_value: Variant = provider_status.get("modelsCache", [])
			if typeof(cached_models_value) == TYPE_ARRAY and not (cached_models_value as Array).is_empty():
				return _copy_model_dictionaries(cached_models_value as Array)
			var fallback_models_value: Variant = provider_status.get("fallbackModels", [])
			if typeof(fallback_models_value) == TYPE_ARRAY and not (fallback_models_value as Array).is_empty():
				return _copy_model_dictionaries(fallback_models_value as Array)

	return [
		{ "id": "deepseek-v4-flash", "displayName": "DeepSeek V4 Flash", "capabilities": { "reasoning": true } },
		{ "id": "deepseek-v4-pro", "displayName": "DeepSeek V4 Pro", "capabilities": { "reasoning": true } }
	]


func _copy_model_dictionaries(models: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for model_value: Variant in models:
		if typeof(model_value) == TYPE_DICTIONARY:
			result.append((model_value as Dictionary).duplicate(true))
	return result


func _is_known_chat_mode(chat_mode: String) -> bool:
	return CHAT_MODE_IDS.has(chat_mode)


func _get_chat_mode_label(chat_mode: String) -> String:
	for index: int in range(CHAT_MODE_IDS.size()):
		if CHAT_MODE_IDS[index] == chat_mode:
			return CHAT_MODE_LABELS[index]

	return CHAT_MODE_LABELS[0]


func _get_chat_mode_id(chat_mode: String) -> int:
	if chat_mode == CHAT_MODE_ASK:
		return CHAT_MODE_ID_ASK
	if chat_mode == CHAT_MODE_PLAN:
		return CHAT_MODE_ID_PLAN

	return CHAT_MODE_ID_AGENT


func _get_chat_mode_from_menu_id(menu_id: int) -> String:
	if menu_id == CHAT_MODE_ID_ASK:
		return CHAT_MODE_ASK
	if menu_id == CHAT_MODE_ID_PLAN:
		return CHAT_MODE_PLAN

	return CHAT_MODE_AGENT


func _setup_mode_button() -> void:
	var popup_menu: PopupMenu = mode_button.get_popup()
	if not popup_menu.id_pressed.is_connected(_on_mode_button_id_pressed):
		popup_menu.id_pressed.connect(_on_mode_button_id_pressed)
	for index: int in range(popup_menu.get_item_count()):
		var menu_id: int = popup_menu.get_item_id(index)
		popup_menu.set_item_as_checkable(index, true)
		popup_menu.set_item_disabled(index, false)
	_update_mode_button()


func _setup_plan_dialogs() -> void:
	if clarification_dialog.has_signal("clarification_submitted") and not clarification_dialog.is_connected("clarification_submitted", Callable(self, "_on_plan_clarification_submitted")):
		clarification_dialog.connect("clarification_submitted", Callable(self, "_on_plan_clarification_submitted"))
	if plan_approval_dialog.has_signal("plan_approved") and not plan_approval_dialog.is_connected("plan_approved", Callable(self, "_on_plan_approved")):
		plan_approval_dialog.connect("plan_approved", Callable(self, "_on_plan_approved"))
	if plan_approval_dialog.has_signal("plan_revision_requested") and not plan_approval_dialog.is_connected("plan_revision_requested", Callable(self, "_on_plan_revision_requested")):
		plan_approval_dialog.connect("plan_revision_requested", Callable(self, "_on_plan_revision_requested"))
	if not clarification_dialog.visibility_changed.is_connected(_sync_plan_overlay_input_visibility):
		clarification_dialog.visibility_changed.connect(_sync_plan_overlay_input_visibility)
	if not plan_approval_dialog.visibility_changed.is_connected(_sync_plan_overlay_input_visibility):
		plan_approval_dialog.visibility_changed.connect(_sync_plan_overlay_input_visibility)
	clarification_dialog.hide()
	plan_approval_dialog.hide()
	_sync_plan_overlay_input_visibility()


func _select_chat_mode(chat_mode: String) -> bool:
	if not _is_known_chat_mode(chat_mode):
		return false

	active_chat_mode = chat_mode
	_update_mode_button()
	return true


func _get_selected_chat_mode() -> String:
	if _is_known_chat_mode(active_chat_mode):
		return active_chat_mode

	return CHAT_MODE_AGENT


func _update_mode_button() -> void:
	if mode_button == null:
		return

	var selected_chat_mode: String = _get_selected_chat_mode()
	mode_button.text = ""
	mode_button.tooltip_text = "Conversation mode: %s" % _get_chat_mode_label(selected_chat_mode)
	var popup_menu: PopupMenu = mode_button.get_popup()
	var selected_menu_id: int = _get_chat_mode_id(selected_chat_mode)
	for index: int in range(popup_menu.get_item_count()):
		var item_selected: bool = popup_menu.get_item_id(index) == selected_menu_id
		popup_menu.set_item_checked(index, item_selected)
		if item_selected:
			mode_button.icon = popup_menu.get_item_icon(index)


func _is_known_provider_id(provider_id: String) -> bool:
	return provider_ids.has(provider_id)


func _populate_provider_button() -> void:
	provider_option_button.clear()
	for index: int in range(provider_ids.size()):
		provider_option_button.add_item(provider_names[index], index)
		provider_option_button.set_item_metadata(index, provider_ids[index])

	if _select_provider_id(active_provider_id):
		return

	active_provider_id = DEFAULT_PROVIDER_ID
	provider_option_button.select(0)
	_update_provider_button_tooltip()


func _select_provider_id(provider_id: String) -> bool:
	for index: int in range(provider_option_button.get_item_count()):
		if str(provider_option_button.get_item_metadata(index)) == provider_id:
			provider_option_button.select(index)
			_update_provider_button_tooltip()
			return true

	return false


func _get_selected_provider_id() -> String:
	var selected_index: int = provider_option_button.selected
	if selected_index >= 0 and selected_index < provider_option_button.get_item_count():
		var metadata_value: Variant = provider_option_button.get_item_metadata(selected_index)
		if typeof(metadata_value) == TYPE_STRING:
			var provider_id: String = str(metadata_value).strip_edges()
			if _is_known_provider_id(provider_id):
				return provider_id

	return active_provider_id


func _update_provider_button_tooltip() -> void:
	provider_option_button.tooltip_text = "Provider: %s" % _get_provider_display_name(active_provider_id)


func _get_provider_config_model_id(provider_id: String) -> String:
	var providers_value: Variant = provider_config_status.get("providers", [])
	if typeof(providers_value) != TYPE_ARRAY:
		return ""

	var providers: Array = providers_value as Array
	for provider_item: Variant in providers:
		if typeof(provider_item) != TYPE_DICTIONARY:
			continue

		var provider_data: Dictionary = provider_item as Dictionary
		var status_provider_id: String = str(provider_data.get("provider", provider_data.get("id", ""))).strip_edges()
		if status_provider_id != provider_id:
			continue

		return str(provider_data.get("model", "")).strip_edges()

	return ""


func _select_or_add_model_id(model_id: String) -> bool:
	var normalized_model_id: String = model_id.strip_edges()
	if normalized_model_id.is_empty():
		return false
	if _select_model_id(normalized_model_id):
		return true

	model_ids.append(normalized_model_id)
	model_names.append(normalized_model_id)
	model_capabilities.append({})
	model_button.add_item(normalized_model_id, model_button.get_item_count())
	model_button.set_item_metadata(model_button.get_item_count() - 1, normalized_model_id)
	model_button.select(model_button.get_item_count() - 1)
	_update_model_button_tooltip()
	return true


func _switch_active_provider(provider_id: String, activate_backend: bool) -> void:
	if not _is_known_provider_id(provider_id):
		return

	active_provider_id = provider_id
	_select_provider_id(active_provider_id)
	_populate_model_button(_get_fallback_models_for_provider(active_provider_id))

	var configured_model_id: String = _get_provider_config_model_id(active_provider_id)
	_select_or_add_model_id(configured_model_id)

	_load_provider_models(active_provider_id)
	if activate_backend:
		_save_active_session_metadata()


func _populate_model_button(models: Array) -> void:
	var previous_model_id: String = _get_selected_model_id()
	model_ids.clear()
	model_names.clear()
	model_capabilities.clear()
	model_button.clear()

	for item: Variant in models:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var model_data: Dictionary = item as Dictionary
		var model_id: String = str(model_data.get("id", "")).strip_edges()
		if model_id.is_empty() or model_ids.has(model_id):
			continue

		var display_name: String = str(model_data.get("displayName", model_id)).strip_edges()
		if display_name.is_empty():
			display_name = model_id

		var capabilities_value: Variant = model_data.get("capabilities", {})
		var capabilities: Dictionary = {}
		if typeof(capabilities_value) == TYPE_DICTIONARY:
			capabilities = (capabilities_value as Dictionary).duplicate(true)

		model_ids.append(model_id)
		model_names.append(display_name)
		model_capabilities.append(capabilities)
		model_button.add_item(display_name, model_button.get_item_count())
		model_button.set_item_metadata(model_button.get_item_count() - 1, model_id)

	if model_ids.is_empty():
		var fallback_models: Array[Dictionary] = _get_fallback_models_for_provider(active_provider_id)
		for fallback_model: Dictionary in fallback_models:
			var fallback_id: String = str(fallback_model.get("id", "")).strip_edges()
			var fallback_name: String = str(fallback_model.get("displayName", fallback_id)).strip_edges()
			var fallback_capabilities: Dictionary = fallback_model.get("capabilities", {}) as Dictionary
			model_ids.append(fallback_id)
			model_names.append(fallback_name)
			model_capabilities.append(fallback_capabilities.duplicate(true))
			model_button.add_item(fallback_name, model_button.get_item_count())
			model_button.set_item_metadata(model_button.get_item_count() - 1, fallback_id)

	if not previous_model_id.is_empty() and _select_model_id(previous_model_id):
		_update_model_button_tooltip()
		_update_send_state()
		return

	model_button.select(0)
	_update_model_button_tooltip()
	_update_send_state()


func _select_model_id(model_id: String) -> bool:
	for index: int in range(model_ids.size()):
		if model_ids[index] == model_id:
			model_button.select(index)
			_update_model_button_tooltip()
			return true

	return false


func _select_approval_mode(approval_mode: String) -> bool:
	return provider_navigation_controller.select_approval_mode(approval_mode)


func _add_image_context(resource_path: String) -> void:
	if not additional_context_controller.add_image_path(resource_path):
		return
	if not _selected_model_supports_image_input():
		_show_image_model_warning()


func _handle_clipboard_image_paste() -> bool:
	var clipboard_image: Image = DisplayServer.clipboard_get_image()
	if clipboard_image == null or clipboard_image.is_empty():
		return false

	var payload: Dictionary = _create_clipboard_image_payload(clipboard_image)
	if payload.is_empty():
		return true

	if not _is_socket_open():
		_upsert_connection_status_entry("warning", "后端未连接", "无法保存剪贴板图片，请连接后端后重试。")
		return true

	if active_session_id.is_empty():
		pending_clipboard_image_payload = payload
		_create_session("New session " + Time.get_datetime_string_from_system(false, true))
		return true

	_save_clipboard_image_attachment(payload)
	return true


func _create_clipboard_image_payload(clipboard_image: Image) -> Dictionary:
	var png_bytes: PackedByteArray = clipboard_image.save_png_to_buffer()
	if png_bytes.is_empty():
		_upsert_connection_status_entry("warning", "剪贴板图片读取失败", "无法把剪贴板图片编码为 PNG。")
		return {}

	var byte_size: int = png_bytes.size()
	var unique_path: String = "clipboard://%d" % Time.get_ticks_usec()
	var limit_message: String = MAIN_HELPERS.validate_image_context_limits(additional_context_controller.get_items(), unique_path, byte_size)
	if not limit_message.is_empty():
		_upsert_connection_status_entry("warning", "图片无法添加", limit_message)
		return {}

	var title: String = "Clipboard image %s" % Time.get_datetime_string_from_system(false, true).replace("T", " ")
	return {
		"mimeType": "image/png",
		"dataUrl": "data:image/png;base64,%s" % Marshalls.raw_to_base64(png_bytes),
		"byteSize": byte_size,
		"width": clipboard_image.get_width(),
		"height": clipboard_image.get_height(),
		"title": title
	}


func _save_clipboard_image_attachment(payload: Dictionary) -> void:
	if not _is_socket_open():
		_upsert_connection_status_entry("warning", "后端未连接", "无法保存剪贴板图片，请连接后端后重试。")
		return
	if active_session_id.is_empty():
		pending_clipboard_image_payload = payload.duplicate(true)
		_create_session("New session " + Time.get_datetime_string_from_system(false, true))
		return

	var params: Dictionary[String, Variant] = {
		"sessionId": active_session_id,
		"mimeType": str(payload.get("mimeType", "image/png")),
		"dataUrl": str(payload.get("dataUrl", "")),
		"byteSize": int(payload.get("byteSize", 0)),
		"title": str(payload.get("title", "Clipboard image"))
	}
	var width: int = int(payload.get("width", 0))
	var height: int = int(payload.get("height", 0))
	if width > 0:
		params["width"] = width
	if height > 0:
		params["height"] = height

	pending_clipboard_image_save_request_id = _send_request(RPC_METHODS.ATTACHMENT_IMAGE_SAVE, params, "attachment-image-save")
	if pending_clipboard_image_save_request_id.is_empty():
		_upsert_connection_status_entry("warning", "剪贴板图片保存失败", "无法向后端发送图片保存请求。")


func _handle_attachment_image_save_response(response_id: String, ok: bool, result: Dictionary) -> bool:
	if response_id != pending_clipboard_image_save_request_id and not response_id.begins_with("attachment-image-save"):
		return false

	if response_id == pending_clipboard_image_save_request_id:
		pending_clipboard_image_save_request_id = ""

	if not ok:
		_upsert_connection_status_entry("warning", "剪贴板图片保存失败", "后端未能保存剪贴板图片。")
		return true

	var attachment_value: Variant = result.get("attachment", {})
	if typeof(attachment_value) != TYPE_DICTIONARY:
		_upsert_connection_status_entry("warning", "剪贴板图片保存失败", "后端返回的图片上下文无效。")
		return true

	var context: Dictionary = attachment_value as Dictionary
	additional_context_controller.add_or_replace(context)
	if not _can_send_image_contexts():
		_show_image_model_warning()
	return true


func _create_image_context(resource_path: String, existing_contexts: Array, context_source: String, is_pinned: bool) -> Dictionary:
	return additional_context_controller.create_image_context(resource_path, existing_contexts, context_source, is_pinned)


func _add_selected_nodes_context() -> void:
	var editor_selection: EditorSelection = editor_bridge_controller.get_selection()
	if editor_selection == null:
		_upsert_connection_status_entry("warning", "编辑器上下文不可用", "当前 Dock 没有获得 Godot EditorSelection。")
		return

	var edited_root: Node = editor_bridge_controller.get_edited_scene_root()
	if edited_root == null:
		_upsert_connection_status_entry("warning", "没有打开场景", "请先在编辑器中打开一个场景。")
		return

	var selected_nodes: Array[Node] = editor_selection.get_selected_nodes()
	if selected_nodes.is_empty():
		_upsert_connection_status_entry("warning", "没有选中节点", "请先在场景树中选择一个或多个节点。")
		return

	for selected_node: Node in selected_nodes:
		if selected_node == null:
			continue
		additional_context_controller.add_or_replace(_create_node_additional_context(selected_node, edited_root))


func _add_active_scene_context() -> void:
	var edited_root: Node = editor_bridge_controller.get_edited_scene_root()
	if edited_root == null:
		_upsert_connection_status_entry("warning", "没有打开场景", "请先在编辑器中打开一个场景。")
		return

	var scene_path: String = editor_bridge_controller.get_scene_resource_path(edited_root)
	var scene_title: String = scene_path.get_file() if not scene_path.is_empty() else edited_root.name
	var context: Dictionary = {
		"id": additional_context_controller.make_context_id("scene", scene_path, "."),
		"kind": "scene",
		"title": scene_title,
		"subtitle": "Active scene",
		"pinned": false,
		"source": "editor",
		"resourcePath": scene_path,
		"nodePath": ".",
		"nodeType": edited_root.get_class(),
		"summary": "Current open Godot editor scene.",
		"data": editor_bridge_controller.serialize_editor_node_summary(edited_root, edited_root)
	}
	additional_context_controller.add_or_replace(context)


func _add_current_script_selection_context() -> void:
	var context: Dictionary = editor_bridge_controller.collect_script_selection_context()
	if context.is_empty():
		_upsert_connection_status_entry("warning", "没有脚本选区", "请先在 Godot 脚本编辑器中打开脚本，或把光标放到目标行。")
		return

	context["id"] = additional_context_controller.make_context_id(
		"script_selection",
		str(context.get("resourcePath", "")),
		additional_context_controller.make_script_selection_key(context)
	)
	context["pinned"] = false
	additional_context_controller.add_or_replace(context)


func _add_filesystem_selection_context() -> void:
	var context: Dictionary = editor_bridge_controller.collect_filesystem_selection_context()
	if context.is_empty():
		_upsert_connection_status_entry("warning", "没有文件系统选择", "请先在 FileSystem Dock 中选择一个或多个文件/文件夹。")
		return

	context["id"] = additional_context_controller.make_context_id(
		"filesystem_selection",
		"",
		additional_context_controller.make_filesystem_selection_key(context)
	)
	context["pinned"] = false
	additional_context_controller.add_or_replace(context)


func _create_node_additional_context(target_node: Node, edited_root: Node) -> Dictionary:
	var scene_path: String = editor_bridge_controller.get_scene_resource_path(edited_root)
	var node_path: String = editor_bridge_controller.get_relative_node_path(edited_root, target_node)
	var script_path: String = editor_bridge_controller.get_node_script_path(target_node)
	var node_type: String = target_node.get_class()
	var context: Dictionary = {
		"id": additional_context_controller.make_context_id("node", scene_path, node_path),
		"kind": "node",
		"title": target_node.name,
		"subtitle": "%s in %s" % [node_type, scene_path.get_file() if not scene_path.is_empty() else edited_root.name],
		"pinned": false,
		"source": "editor",
		"resourcePath": scene_path,
		"nodePath": node_path,
		"nodeType": node_type,
		"summary": editor_bridge_controller.summarize_editor_node(target_node),
		"data": editor_bridge_controller.serialize_editor_node_summary(target_node, edited_root)
	}
	if not script_path.is_empty():
		context["scriptPath"] = script_path
	return context


func _get_additional_context_snapshot() -> Array[Dictionary]:
	var expanded_contexts: Array[Dictionary] = additional_context_controller.expand_filesystem_image_selections(
		additional_context_controller.get_timeline_snapshot()
	)
	return additional_context_controller.freeze_contexts_for_message(expanded_contexts, true)


func _context_array_has_images(contexts: Array) -> bool:
	return MAIN_HELPERS.context_array_has_images(contexts)


func _selected_model_supports_image_input() -> bool:
	var selected_index: int = model_button.selected
	if selected_index < 0 or selected_index >= model_capabilities.size():
		return false

	var capabilities: Dictionary = model_capabilities[selected_index]
	return MAIN_HELPERS.model_capabilities_support_image(capabilities)


func _has_configured_image_recognition_model() -> bool:
	var routing_value: Variant = provider_config_status.get("modelRouting", {})
	if typeof(routing_value) != TYPE_DICTIONARY:
		return false

	var routing: Dictionary = routing_value as Dictionary
	var image_model_value: Variant = routing.get("imageRecognition", null)
	if typeof(image_model_value) != TYPE_DICTIONARY:
		return false

	var image_model: Dictionary = image_model_value as Dictionary
	return not str(image_model.get("provider", "")).strip_edges().is_empty() and not str(image_model.get("model", "")).strip_edges().is_empty()


func _can_send_image_contexts() -> bool:
	return _selected_model_supports_image_input() or _has_configured_image_recognition_model()


func _show_image_model_warning() -> void:
	if _has_configured_image_recognition_model():
		_upsert_connection_status_entry(
			"message",
			"图片将先识别",
			"当前模型不支持图片，后端会先使用 Image recognition model 识别图片，再交给当前模型回答。"
		)
		return

	_upsert_connection_status_entry(
		"warning",
		"当前模型不支持图片输入",
		"请切换到带有 image capability 的模型，或在设置里配置 Image recognition model。"
	)


func _render_message_panel() -> void:
	if message_queue_panel == null or message_tree == null:
		return

	var should_show_panel: bool = background_context_viewer.visible and (not queued_messages.is_empty() or not manual_guides.is_empty())
	message_queue_panel.visible = should_show_panel
	if not should_show_panel:
		message_tree.clear()
		return

	message_tree.clear()
	var root_item: TreeItem = message_tree.create_item()

	for queued_message: Dictionary in queued_messages:
		var queue_item: TreeItem = message_tree.create_item(root_item)
		var metadata: Dictionary = {
			"kind": "queue",
			"id": int(queued_message.get("id", 0)),
			"status": str(queued_message.get("status", MESSAGE_QUEUE_STATUS_PENDING)),
			"message": str(queued_message.get("text", ""))
		}
		var queue_status: String = str(queued_message.get("status", MESSAGE_QUEUE_STATUS_PENDING))
		queue_item.set_text(MESSAGE_TREE_STATUS_COLUMN, MAIN_HELPERS.format_queue_status(queue_status))
		queue_item.set_text(MESSAGE_TREE_MESSAGE_COLUMN, MAIN_HELPERS.format_message_preview(str(queued_message.get("text", ""))))
		queue_item.set_tooltip_text(MESSAGE_TREE_MESSAGE_COLUMN, str(queued_message.get("text", "")))
		queue_item.set_metadata(MESSAGE_TREE_STATUS_COLUMN, metadata)
		queue_item.set_metadata(MESSAGE_TREE_MESSAGE_COLUMN, metadata)
		queue_item.set_metadata(MESSAGE_TREE_ACTIONS_COLUMN, metadata)
		queue_item.add_button(MESSAGE_TREE_ACTIONS_COLUMN, EDIT_ICON, MESSAGE_TREE_BUTTON_EDIT, not MAIN_HELPERS.can_edit_queue_message(queue_status), "Edit")
		queue_item.add_button(MESSAGE_TREE_ACTIONS_COLUMN, DELETE_ICON, MESSAGE_TREE_BUTTON_DELETE, not MAIN_HELPERS.can_delete_queue_message(queue_status), "Delete")

	for manual_guide: Dictionary in manual_guides:
		var guide_item: TreeItem = message_tree.create_item(root_item)
		var guide_status: String = str(manual_guide.get("status", GUIDE_STATUS_DRAFT))
		var guide_metadata: Dictionary = {
			"kind": "guide",
			"local_id": str(manual_guide.get("local_id", "")),
			"guide_id": str(manual_guide.get("guide_id", "")),
			"client_guide_id": str(manual_guide.get("client_guide_id", "")),
			"status": guide_status,
			"message": str(manual_guide.get("text", ""))
		}
		guide_item.set_text(MESSAGE_TREE_STATUS_COLUMN, MAIN_HELPERS.format_guide_status(guide_status))
		guide_item.set_text(MESSAGE_TREE_MESSAGE_COLUMN, MAIN_HELPERS.format_message_preview(str(manual_guide.get("text", ""))))
		guide_item.set_tooltip_text(MESSAGE_TREE_MESSAGE_COLUMN, str(manual_guide.get("text", "")))
		guide_item.set_metadata(MESSAGE_TREE_STATUS_COLUMN, guide_metadata)
		guide_item.set_metadata(MESSAGE_TREE_MESSAGE_COLUMN, guide_metadata)
		guide_item.set_metadata(MESSAGE_TREE_ACTIONS_COLUMN, guide_metadata)
		guide_item.add_button(MESSAGE_TREE_ACTIONS_COLUMN, GUIDE_NOW_ICON, MESSAGE_TREE_BUTTON_GUIDE_NOW, not MAIN_HELPERS.can_submit_manual_guide(guide_status), "Guide now")
		guide_item.add_button(MESSAGE_TREE_ACTIONS_COLUMN, EDIT_ICON, MESSAGE_TREE_BUTTON_EDIT, not MAIN_HELPERS.can_edit_manual_guide(guide_status), "Edit")
		guide_item.add_button(MESSAGE_TREE_ACTIONS_COLUMN, DELETE_ICON, MESSAGE_TREE_BUTTON_DELETE, not MAIN_HELPERS.can_delete_manual_guide(guide_status), "Delete")


func _on_message_tree_item_activated() -> void:
	var selected_item: TreeItem = message_tree.get_selected()
	if selected_item == null:
		return

	var metadata_value: Variant = selected_item.get_metadata(0)
	if typeof(metadata_value) != TYPE_DICTIONARY:
		return

	var metadata: Dictionary = metadata_value as Dictionary
	var item_kind: String = str(metadata.get("kind", ""))
	if item_kind == "guide":
		var guide_message_text: String = str(metadata.get("message", ""))
		if not guide_message_text.is_empty():
			text_edit.text = guide_message_text
			text_edit.grab_focus()
		return
	if item_kind != "queue":
		return

	var queue_status: String = str(metadata.get("status", ""))
	if queue_status == str(MESSAGE_QUEUE_STATUS_PENDING) and active_stream_id.is_empty():
		_process_message_queue()
		return

	var queued_message_text: String = str(metadata.get("message", ""))
	if not queued_message_text.is_empty():
		text_edit.text = queued_message_text
		text_edit.grab_focus()


func _on_message_tree_button_clicked(item: TreeItem, _column: int, button_id: int, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return

	var metadata_value: Variant = item.get_metadata(MESSAGE_TREE_STATUS_COLUMN)
	if typeof(metadata_value) != TYPE_DICTIONARY:
		return

	var metadata: Dictionary = metadata_value as Dictionary
	var item_kind: String = str(metadata.get("kind", ""))
	if item_kind == "queue":
		_handle_queue_tree_action(button_id, metadata)
	elif item_kind == "guide":
		_handle_guide_tree_action(button_id, metadata)


func _on_text_edit_text_changed() -> void:
	if text_edit.text.strip_edges().is_empty():
		slash_command_completion_consumed = false
	_update_slash_command_popup()
	_queue_workbench_composer_patch(true, false)
	_update_send_state()


func _update_slash_command_popup() -> void:
	if slash_command_completion_consumed:
		_hide_slash_command_popup()
		return

	var filter_text: String = _get_skill_completion_filter()
	if not filter_text.is_empty():
		completion_trigger = "@"
		slash_command_items = _filter_skills(filter_text)
	else:
		filter_text = _get_slash_command_filter()
		completion_trigger = "/" if not filter_text.is_empty() else ""
		slash_command_items = _filter_slash_commands(filter_text) if not filter_text.is_empty() else []
	if filter_text.is_empty():
		_hide_slash_command_popup()
		return
	if slash_command_items.is_empty():
		_hide_slash_command_popup()
		return

	slash_command_selected_index = clampi(slash_command_selected_index, 0, slash_command_items.size() - 1)
	_show_slash_command_overlay()


func _get_slash_command_filter() -> String:
	var caret_line: int = text_edit.get_caret_line()
	if caret_line < 0 or caret_line >= text_edit.get_line_count():
		return ""

	var line_text: String = text_edit.get_line(caret_line)
	var caret_column: int = clampi(text_edit.get_caret_column(), 0, line_text.length())
	var prefix_text: String = line_text.substr(0, caret_column)
	var slash_index: int = prefix_text.rfind("/")
	if slash_index < 0:
		return ""

	var before_slash: String = prefix_text.substr(0, slash_index).strip_edges()
	if not before_slash.is_empty():
		return ""

	var filter_text: String = prefix_text.substr(slash_index).strip_edges()
	if filter_text.contains(" "):
		return ""

	return filter_text


func _filter_slash_commands(filter_text: String) -> Array:
	var filtered_commands: Array[Dictionary] = []
	var normalized_filter: String = filter_text.to_lower()
	for command: Dictionary in slash_commands:
		var command_text: String = str(command.get("command", "")).to_lower()
		var usage_text: String = str(command.get("label", "")).to_lower()
		if normalized_filter == "/" or command_text.begins_with(normalized_filter) or usage_text.begins_with(normalized_filter):
			filtered_commands.append(command)

	return filtered_commands


func _get_skill_completion_filter() -> String:
	var caret_line: int = text_edit.get_caret_line()
	if caret_line < 0 or caret_line >= text_edit.get_line_count():
		return ""
	var line_text: String = text_edit.get_line(caret_line)
	var caret_column: int = clampi(text_edit.get_caret_column(), 0, line_text.length())
	var prefix_text: String = line_text.substr(0, caret_column)
	var at_index: int = prefix_text.rfind("@")
	if at_index < 0:
		return ""
	if at_index > 0:
		var preceding_codepoint: int = prefix_text.unicode_at(at_index - 1)
		if preceding_codepoint != 32 and preceding_codepoint != 9:
			return ""
	var token_text: String = prefix_text.substr(at_index + 1)
	if token_text.contains(" ") or token_text.contains("\t"):
		return ""
	return token_text if not token_text.is_empty() else "@"


func _filter_skills(filter_text: String) -> Array[Dictionary]:
	var filtered_skills: Array[Dictionary] = []
	var normalized_filter: String = "" if filter_text == "@" else filter_text.to_lower()
	for metadata: Dictionary in skill_summaries:
		if not bool(metadata.get("enabled", false)) or not bool(metadata.get("valid", false)):
			continue
		var skill_ref: String = str(metadata.get("ref", ""))
		var skill_name: String = str(metadata.get("name", ""))
		var description_text: String = str(metadata.get("description", ""))
		var searchable_text: String = "%s %s %s" % [skill_ref, skill_name, description_text]
		if not normalized_filter.is_empty() and searchable_text.to_lower().find(normalized_filter) < 0:
			continue
		filtered_skills.append({
			"command": "@" + skill_ref,
			"label": "@" + skill_ref,
			"insert": "@" + skill_ref + " ",
			"description": "%s - %s" % [skill_name, description_text]
		})
	return filtered_skills


func _extract_skill_refs(message_text: String) -> Array[String]:
	var refs: Array[String] = []
	var enabled_refs: Dictionary[String, bool] = {}
	for metadata: Dictionary in skill_summaries:
		if bool(metadata.get("enabled", false)) and bool(metadata.get("valid", false)):
			enabled_refs[str(metadata.get("ref", ""))] = true
	var expression: RegEx = RegEx.new()
	var compile_error: Error = expression.compile("(?:^|\\s)@(builtin|personal|project):([a-z0-9][a-z0-9-]{0,63})(?=\\s|$|[.,;:!?，。；：！？])")
	if compile_error != OK:
		return refs
	var matches: Array[RegExMatch] = expression.search_all(message_text)
	for match_result: RegExMatch in matches:
		var skill_ref: String = "%s:%s" % [match_result.get_string(1), match_result.get_string(2)]
		if enabled_refs.has(skill_ref) and not refs.has(skill_ref):
			refs.append(skill_ref)
		if refs.size() >= 4:
			break
	return refs


func _apply_skill_list_response(result_dictionary: Dictionary) -> void:
	skill_summaries.clear()
	var skills_value: Variant = result_dictionary.get("skills", [])
	if typeof(skills_value) == TYPE_ARRAY:
		for item: Variant in skills_value as Array:
			if typeof(item) == TYPE_DICTIONARY:
				skill_summaries.append((item as Dictionary).duplicate(true))
	skill_catalog_revision = str(result_dictionary.get("revision", ""))
	if active_settings_menu != null and is_instance_valid(active_settings_menu):
		active_settings_menu.call("setup_skills", skill_summaries, skill_catalog_revision, _is_socket_open())
	_update_slash_command_popup()


func _apply_slash_command_list_response(result_dictionary: Dictionary) -> void:
	slash_commands.clear()
	var commands_value: Variant = result_dictionary.get("commands", [])
	if typeof(commands_value) != TYPE_ARRAY:
		return

	var command_array: Array = commands_value as Array
	for command_value: Variant in command_array:
		if typeof(command_value) != TYPE_DICTIONARY:
			continue

		var command_dictionary: Dictionary = command_value as Dictionary
		var command_text: String = str(command_dictionary.get("command", "")).strip_edges()
		if command_text.is_empty() or not command_text.begins_with("/"):
			continue

		var usage_text: String = str(command_dictionary.get("usage", command_text)).strip_edges()
		var insert_text: String = str(command_dictionary.get("insertText", command_text))
		var description_text: String = str(command_dictionary.get("description", "")).strip_edges()
		slash_commands.append({
			"command": command_text,
			"label": usage_text,
			"insert": insert_text,
			"description": description_text
		})

	_update_slash_command_popup()


func _show_slash_command_overlay() -> void:
	if slash_command_overlay == null:
		return

	slash_command_overlay.call(
		"show_commands",
		slash_command_items,
		slash_command_selected_index,
		text_edit.get_global_rect(),
		get_global_rect()
	)


func _hide_slash_command_popup() -> void:
	if slash_command_overlay != null:
		slash_command_overlay.call("hide_commands")


func _clear_text_edit_after_submit() -> void:
	slash_command_completion_consumed = false
	_hide_slash_command_popup()
	text_edit.clear()


func _move_slash_command_selection(delta: int) -> void:
	if slash_command_items.is_empty():
		return

	slash_command_selected_index = posmod(slash_command_selected_index + delta, slash_command_items.size())
	_show_slash_command_overlay()


func _confirm_slash_command_completion() -> void:
	if slash_command_items.is_empty():
		return

	var selected_command: Dictionary = slash_command_items[clampi(slash_command_selected_index, 0, slash_command_items.size() - 1)]
	slash_command_completion_consumed = completion_trigger == "/"
	_replace_completion_token(str(selected_command.get("insert", "")))
	_hide_slash_command_popup()
	_update_send_state()


func _replace_completion_token(insert_text: String) -> void:
	var caret_line: int = text_edit.get_caret_line()
	var line_text: String = text_edit.get_line(caret_line)
	var caret_column: int = clampi(text_edit.get_caret_column(), 0, line_text.length())
	var prefix_text: String = line_text.substr(0, caret_column)
	var token_index: int = prefix_text.rfind(completion_trigger)
	if token_index < 0:
		return

	text_edit.select(caret_line, token_index, caret_line, caret_column)
	text_edit.delete_selection()
	text_edit.insert_text_at_caret(insert_text)
	text_edit.grab_focus()


func _on_timeline_scroll_value_changed(_value: float) -> void:
	var should_follow_bottom: bool = _is_timeline_near_bottom()
	if timeline_follow_bottom and not should_follow_bottom:
		timeline_deferred_scroll_version += 1
	timeline_follow_bottom = should_follow_bottom
	if scroll_container.scroll_vertical <= TIMELINE_PAGE_LOAD_THRESHOLD:
		_request_previous_timeline_page()
	elif should_follow_bottom:
		_request_next_timeline_page()
	_schedule_timeline_render(false)


func _setup_options() -> void:
	workspace_filter_button.clear()
	workspace_filter_button.add_item("All", 0)
	workspace_filter_button.set_item_metadata(0, "")

	_setup_mode_button()
	_populate_provider_button()
	_populate_model_button(_get_fallback_models_for_provider(active_provider_id))

	effort_button.clear()
	effort_button.add_item("Normal", 0)


func _setup_slash_command_popup() -> void:
	slash_command_overlay = SLASH_COMMAND_OVERLAY_SCRIPT.new() as Control
	slash_command_overlay.name = "SlashCommandOverlay"
	slash_command_overlay.top_level = true
	slash_command_overlay.z_index = 4096
	slash_command_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slash_command_overlay.focus_mode = Control.FOCUS_NONE
	add_child(slash_command_overlay)
	slash_command_overlay.hide()
	text_edit.gui_input.connect(_on_text_edit_gui_input)


func _load_frontend_config() -> void:
	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(FRONTEND_CONFIG_PATH)
	var should_save_config: bool = load_error != OK

	backend_dev_dir = str(config.get_value(FRONTEND_CONFIG_SECTION, CONFIG_BACKEND_DEV_DIR_KEY, "")).strip_edges()
	backend_url = _resolve_backend_url_for_mode(
		_normalize_backend_url(str(config.get_value(FRONTEND_CONFIG_SECTION, CONFIG_BACKEND_URL_KEY, DEFAULT_BACKEND_URL))),
		backend_dev_dir
	)
	active_provider_id = DEFAULT_PROVIDER_ID
	_select_provider_id(active_provider_id)
	_populate_model_button(_get_fallback_models_for_provider(active_provider_id))
	custom_instructions = ""
	next_step_hints_enabled = bool(config.get_value(FRONTEND_CONFIG_SECTION, CONFIG_NEXT_STEP_HINTS_KEY, false))
	check_for_updates_enabled = bool(config.get_value(FRONTEND_CONFIG_SECTION, CONFIG_CHECK_FOR_UPDATES_KEY, true))
	_select_chat_mode(CHAT_MODE_AGENT)
	_select_approval_mode(APPROVAL_MODE_IDS[0])

	if should_save_config:
		_save_frontend_config()


func _save_frontend_config() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(FRONTEND_CONFIG_SECTION, CONFIG_BACKEND_URL_KEY, backend_url)
	config.set_value(FRONTEND_CONFIG_SECTION, CONFIG_BACKEND_DEV_DIR_KEY, backend_dev_dir)
	config.set_value(FRONTEND_CONFIG_SECTION, CONFIG_NEXT_STEP_HINTS_KEY, next_step_hints_enabled)
	config.set_value(FRONTEND_CONFIG_SECTION, CONFIG_CHECK_FOR_UPDATES_KEY, check_for_updates_enabled)
	var save_error: Error = config.save(FRONTEND_CONFIG_PATH)
	if save_error != OK:
		push_warning("Failed to save Daedalus frontend config: %s" % error_string(save_error))


func _normalize_backend_url(url: String) -> String:
	var normalized_url: String = url.strip_edges()
	if normalized_url.is_empty():
		return DEFAULT_BACKEND_URL
	if normalized_url == "ws://localhost:38180":
		return DEFAULT_BACKEND_URL
	if normalized_url == "ws://localhost:38181":
		return DEVELOPMENT_BACKEND_URL

	return normalized_url


func _resolve_backend_url_for_mode(normalized_url: String, normalized_backend_dev_dir: String) -> String:
	if not normalized_backend_dev_dir.strip_edges().is_empty() and _is_default_backend_url(normalized_url):
		return DEVELOPMENT_BACKEND_URL
	if normalized_backend_dev_dir.strip_edges().is_empty() and normalized_url == DEVELOPMENT_BACKEND_URL:
		return DEFAULT_BACKEND_URL

	return normalized_url


func _is_default_backend_url(url: String) -> bool:
	return url == DEFAULT_BACKEND_URL or url == DEVELOPMENT_BACKEND_URL


func _clear_template_items() -> void:
	_setup_timeline_containers()
	if additional_context_container == null:
		return

	for child: Node in additional_context_container.get_children():
		child.queue_free()


func _setup_timeline_containers() -> void:
	if timeline_visible_container != null and is_instance_valid(timeline_visible_container):
		return

	for child: Node in background_context_container.get_children():
		child.queue_free()

	timeline_top_spacer = Control.new()
	timeline_top_spacer.name = "TopSpacer"
	timeline_top_spacer.custom_minimum_size = Vector2(0.0, 0.0)
	background_context_container.add_child(timeline_top_spacer)

	timeline_visible_container = VBoxContainer.new()
	timeline_visible_container.name = "VisibleItemsContainer"
	timeline_visible_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	background_context_container.add_child(timeline_visible_container)

	timeline_bottom_spacer = Control.new()
	timeline_bottom_spacer.name = "BottomSpacer"
	timeline_bottom_spacer.custom_minimum_size = Vector2(0.0, 0.0)
	background_context_container.add_child(timeline_bottom_spacer)


func _connect_timeline_signals() -> void:
	var vertical_scroll_bar: VScrollBar = scroll_container.get_v_scroll_bar()
	if vertical_scroll_bar != null and not vertical_scroll_bar.value_changed.is_connected(_on_timeline_scroll_value_changed):
		vertical_scroll_bar.value_changed.connect(_on_timeline_scroll_value_changed)


func _setup_message_tree() -> void:
	message_tree.columns = 3
	message_tree.column_titles_visible = true
	message_tree.hide_root = true
	message_tree.set_column_title(MESSAGE_TREE_STATUS_COLUMN, "Status")
	message_tree.set_column_title(MESSAGE_TREE_MESSAGE_COLUMN, "Message")
	message_tree.set_column_title(MESSAGE_TREE_ACTIONS_COLUMN, "Actions")
	message_tree.set_column_expand(MESSAGE_TREE_STATUS_COLUMN, false)
	message_tree.set_column_expand(MESSAGE_TREE_MESSAGE_COLUMN, true)
	message_tree.set_column_expand(MESSAGE_TREE_ACTIONS_COLUMN, false)
	message_tree.set_column_custom_minimum_width(MESSAGE_TREE_STATUS_COLUMN, 82)
	message_tree.set_column_custom_minimum_width(MESSAGE_TREE_ACTIONS_COLUMN, 72)
	if not message_tree.button_clicked.is_connected(_on_message_tree_button_clicked):
		message_tree.button_clicked.connect(_on_message_tree_button_clicked)


func _setup_add_context_menu() -> void:
	if add_context_button == null:
		return

	var popup_menu: PopupMenu = add_context_button.get_popup()
	if not popup_menu.id_pressed.is_connected(_on_add_context_menu_id_pressed):
		popup_menu.id_pressed.connect(_on_add_context_menu_id_pressed)


func _on_add_context_menu_id_pressed(menu_id: int) -> void:
	if menu_id == ADD_CONTEXT_SELECTED_NODES_ID:
		_add_selected_nodes_context()
	elif menu_id == ADD_CONTEXT_ACTIVE_SCENE_ID:
		_add_active_scene_context()
	elif menu_id == ADD_CONTEXT_SCRIPT_SELECTION_ID:
		_add_current_script_selection_context()
	elif menu_id == ADD_CONTEXT_FILESYSTEM_SELECTION_ID:
		_add_filesystem_selection_context()
	elif menu_id == ADD_CONTEXT_IMAGE_ID:
		_show_add_context_resource_dialog(EditorFileDialog.FILE_MODE_OPEN_FILE, "image")
	elif menu_id == ADD_CONTEXT_FILE_ID:
		_show_add_context_resource_dialog(EditorFileDialog.FILE_MODE_OPEN_FILE, "file")
	elif menu_id == ADD_CONTEXT_FOLDER_ID:
		_show_add_context_resource_dialog(EditorFileDialog.FILE_MODE_OPEN_DIR, "folder")
	elif menu_id == ADD_CONTEXT_CLEAR_UNPINNED_ID:
		additional_context_controller.clear_unpinned()


func _show_add_context_resource_dialog(file_mode: int, context_kind: String) -> void:
	var resource_dialog: EditorFileDialog = EditorFileDialog.new()
	resource_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	resource_dialog.file_mode = file_mode
	resource_dialog.title = "添加图片" if context_kind == "image" else "添加上下文"
	if context_kind == "image":
		resource_dialog.filters = PackedStringArray([
			"*.png, *.jpg, *.jpeg, *.webp, *.gif ; Images"
		])
	resource_dialog.size = Vector2i(720, 480)
	add_child(resource_dialog)

	if context_kind == "folder":
		resource_dialog.dir_selected.connect(_on_add_context_resource_selected.bind(context_kind, resource_dialog))
	else:
		resource_dialog.file_selected.connect(_on_add_context_resource_selected.bind(context_kind, resource_dialog))
	resource_dialog.canceled.connect(resource_dialog.queue_free)
	resource_dialog.popup_centered_ratio()


func _on_add_context_resource_selected(resource_path: String, context_kind: String, resource_dialog: EditorFileDialog) -> void:
	if resource_dialog != null and is_instance_valid(resource_dialog):
		resource_dialog.queue_free()

	var normalized_path: String = resource_path.strip_edges()
	if normalized_path.is_empty():
		return

	if context_kind == "image":
		_add_image_context(normalized_path)
		return

	var context: Dictionary = {
		"id": additional_context_controller.make_context_id(context_kind, normalized_path, ""),
		"kind": context_kind,
		"title": normalized_path.get_file() if context_kind != "folder" else normalized_path.trim_suffix("/").get_file(),
		"subtitle": normalized_path,
		"pinned": false,
		"source": "manual",
		"resourcePath": normalized_path,
		"summary": "用户为本轮消息附加了项目 %s 引用；仅在需要时通过 MCP 读取内容。" % context_kind
	}
	additional_context_controller.add_or_replace(context)


func _on_text_edit_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return

	var key_event: InputEventKey = event as InputEventKey
	if _handle_slash_command_key(key_event):
		accept_event()


func _handle_slash_command_key(event: InputEventKey) -> bool:
	if event.is_action_pressed(TEXT_COMPLETION_ACCEPT_ACTION):
		if _has_valid_slash_command_completion():
			_confirm_slash_command_completion()
			return true

		_hide_slash_command_popup()
		return false

	if not _is_slash_command_popup_open():
		return false

	if event.keycode == KEY_ESCAPE:
		_hide_slash_command_popup()
		return true
	if event.keycode == KEY_UP:
		_move_slash_command_selection(-1)
		return true
	if event.keycode == KEY_DOWN:
		_move_slash_command_selection(1)
		return true

	return false


func _is_slash_command_popup_open() -> bool:
	return slash_command_overlay != null and slash_command_overlay.visible and not slash_command_items.is_empty()


func _has_valid_slash_command_completion() -> bool:
	return _is_slash_command_popup_open() and slash_command_selected_index >= 0 and slash_command_selected_index < slash_command_items.size()

# --- backend_connection.gd ---

func _start_backend_connection_attempts(show_boot_screen: bool = true, recovery_mode: bool = false) -> void:
	connection_attempts = 0
	connection_attempt_generation += 1
	is_connecting = true
	socket_ready = false
	workspace_ready = false
	connected_workspace_id = ""
	backend_launch_started = false
	backend_health_pending = false
	backend_health_request_id = ""
	pending_socket_open_was_recovering = false
	pending_socket_open_session_id = ""
	backend_recovery_mode = recovery_mode
	if backend_launcher != null:
		backend_launcher.call("setup", backend_url, backend_dev_dir)
	if recovery_mode:
		backend_launch_deadline_msec = 0
	else:
		backend_launch_deadline_msec = Time.get_ticks_msec() + BACKEND_START_TIMEOUT_MSEC
	if not recovery_mode:
		restore_session_after_reconnect_id = ""
		pending_recovery_status_after_session_open = false
		connection_status_entry_id = ""
	if show_boot_screen:
		main_viewer.hide()
		boot_splash.show()
		boot_splash.call("show_status", "Checking backend")
	if _uses_managed_shared_runtime():
		# Shared runtimes require a fresh lease token before the first WebSocket handshake.
		backend_auth_protocol = ""
		if not _try_start_backend_process():
			return
	_connect_to_backend()


func _connect_to_backend() -> void:
	connection_attempts += 1
	var connect_error: Error = backend_connection_controller.connect_to_backend(
		backend_url,
		WEBSOCKET_BUFFER_SIZE,
		backend_auth_protocol
	)
	if connect_error != OK:
		status_button.icon = CONNECT_FAILED_ICON
		status_button.tooltip_text = "Connect failed: %d. Click to reconnect." % connect_error
		if backend_recovery_mode:
			_upsert_connection_status_entry(
				"error",
				"连接失败",
				"无法连接到 Daedalus 后端：%d\n地址：%s" % [connect_error, backend_url],
				"重试",
				"reconnect"
			)
		_retry_backend_connection()
		return
	
	status_button.icon = DISCONNECTED_ICON
	status_button.tooltip_text = "Connecting... (%d/%d)" % [connection_attempts, MAX_CONNECT_ATTEMPTS]
	if backend_recovery_mode:
		_upsert_connection_status_entry(
			"reconnecting",
			"正在重连",
			"正在重新连接 Daedalus 后端（%d/%d）\n地址：%s" % [connection_attempts, MAX_CONNECT_ATTEMPTS, backend_url]
		)


func _retry_backend_connection() -> void:
	if not backend_recovery_mode:
		if not backend_launch_started:
			if not _try_start_backend_process():
				return
		elif Time.get_ticks_msec() >= backend_launch_deadline_msec:
			_show_backend_startup_error(
				"Cannot connect to Daedalus backend",
				"Daedalus started a backend process, but it did not become reachable within 10 seconds.\n\n%s" % _get_backend_launcher_details()
			)
			return
		else:
			boot_splash.call("show_status", "Waiting for backend")

	if connection_attempts >= MAX_CONNECT_ATTEMPTS:
		is_connecting = false
		status_button.icon = CONNECT_FAILED_ICON
		status_button.tooltip_text = "Connect failed. Click to reconnect."
		if backend_recovery_mode:
			_upsert_connection_status_entry(
				"error",
				"重连失败",
				"已经尝试 %d 次，仍无法连接后端。\n请确认地址：%s" % [MAX_CONNECT_ATTEMPTS, backend_url],
				"重试",
				"reconnect"
			)
		else:
			_show_backend_startup_error(
				"Cannot connect to Daedalus backend",
				"Daedalus could not connect after %d attempts.\n\n%s" % [MAX_CONNECT_ATTEMPTS, _get_backend_launcher_details()]
			)
		return

	is_connecting = false
	var retry_generation: int = connection_attempt_generation
	await get_tree().create_timer(CONNECT_RETRY_SECONDS).timeout
	if retry_generation != connection_attempt_generation:
		return
	if socket_ready:
		return

	is_connecting = true
	_connect_to_backend()


func _try_start_backend_process() -> bool:
	if backend_launcher == null:
		_show_backend_startup_error("Cannot start Daedalus backend", "Backend launcher is unavailable.")
		return false

	var is_local_backend: bool = bool(backend_launcher.call("is_local_backend_url"))
	if not is_local_backend:
		_show_backend_startup_error(
			"Remote backend is not started automatically",
			"Daedalus only starts local backends automatically.\n\nBackend URL: %s\nStart the remote backend manually, then click Reconnect." % backend_url
		)
		return false

	var port_probe: Dictionary = backend_launcher.call("probe_local_backend_port") as Dictionary
	if bool(port_probe.get("checked", false)) and bool(port_probe.get("occupied", false)):
		boot_splash.call("show_status", "Waiting for backend")

	boot_splash.call("show_status", "Starting backend")
	var start_result: Dictionary = backend_launcher.call("start_backend") as Dictionary
	backend_launch_started = true
	backend_launch_deadline_msec = Time.get_ticks_msec() + BACKEND_START_TIMEOUT_MSEC
	if not bool(start_result.get("ok", false)):
		_show_backend_startup_error(
			"Cannot start Daedalus backend",
			str(start_result.get("details", _get_backend_launcher_details()))
		)
		return false

	var acquired_url: String = str(start_result.get("url", "")).strip_edges()
	var acquired_auth_protocol: String = str(start_result.get("authProtocol", "")).strip_edges()
	if not acquired_url.is_empty():
		backend_url = acquired_url
		backend_auth_protocol = acquired_auth_protocol

	return true


func _uses_managed_shared_runtime() -> bool:
	return backend_launcher != null \
		and backend_dev_dir.strip_edges().is_empty() \
		and bool(backend_launcher.call("is_local_backend_url"))


func _get_backend_launcher_details() -> String:
	if backend_launcher == null:
		return "Backend launcher is unavailable."

	return str(backend_launcher.call("build_diagnostic_details"))


func _show_backend_startup_error(title: String, details: String) -> void:
	is_connecting = false
	socket_ready = false
	backend_health_pending = false
	status_button.icon = CONNECT_FAILED_ICON
	status_button.tooltip_text = "Connect failed. Click to reconnect."
	backend_connection_controller.shutdown()
	main_viewer.hide()
	boot_splash.show()
	boot_splash.call("show_error", title, details)


func _on_socket_opened() -> void:
	var was_recovering: bool = backend_recovery_mode
	var session_id_to_restore: String = restore_session_after_reconnect_id
	is_connecting = false
	pending_socket_open_was_recovering = was_recovering
	pending_socket_open_session_id = session_id_to_restore
	backend_health_request_id = _send_request(RPC_METHODS.BACKEND_HEALTH, {}, "backend-health")
	if backend_health_request_id.is_empty():
		_handle_backend_health_failed("Unable to send backend health check request.")
		return

	backend_health_pending = true
	backend_health_deadline_msec = Time.get_ticks_msec() + BACKEND_HEALTH_TIMEOUT_MSEC
	status_button.icon = DISCONNECTED_ICON
	status_button.tooltip_text = "Connected. Checking backend health..."
	if boot_splash.visible:
		boot_splash.call("show_status", "Checking backend")


func _check_backend_health_timeout() -> void:
	if not backend_health_pending:
		return
	if Time.get_ticks_msec() < backend_health_deadline_msec:
		return

	_handle_backend_health_failed("The WebSocket opened, but Daedalus health check did not respond in time.")


func _handle_backend_health_response(message: Dictionary) -> bool:
	if str(message.get("id", "")) != backend_health_request_id:
		return false

	backend_health_pending = false
	var ok: bool = bool(message.get("ok", false))
	var result: Variant = message.get("result", {})
	if not ok or typeof(result) != TYPE_DICTIONARY:
		_handle_backend_health_failed("The service on this port did not return a valid Daedalus health response.")
		return true

	var result_dictionary: Dictionary = result as Dictionary
	if str(result_dictionary.get("name", "")) != "godot-daedalus-backend":
		_handle_backend_health_failed("The service on this port is not Daedalus backend.")
		return true
	var backend_mode: String = str(result_dictionary.get("mode", "")).strip_edges()
	if not backend_dev_dir.strip_edges().is_empty() and backend_mode != "development":
		_handle_backend_health_failed(
			"Daedalus is configured to use the development backend, but the connected backend reports mode '%s'. Use %s for development, or clear the backend development directory in Settings." % [
				backend_mode if not backend_mode.is_empty() else "unknown",
				DEVELOPMENT_BACKEND_URL
			]
		)
		return true

	connected_backend_version = str(result_dictionary.get("version", "")).strip_edges()
	var was_recovering: bool = pending_socket_open_was_recovering
	var session_id_to_restore: String = pending_socket_open_session_id
	pending_socket_open_was_recovering = false
	pending_socket_open_session_id = ""
	backend_health_request_id = ""
	_load_slash_commands()
	_load_skills()
	_finalize_socket_opened(was_recovering, session_id_to_restore)
	return true


func _handle_backend_health_failed(message_text: String) -> void:
	backend_health_pending = false
	backend_health_request_id = ""
	pending_socket_open_was_recovering = false
	pending_socket_open_session_id = ""
	_show_backend_startup_error(
		"Cannot verify Daedalus backend",
		"%s\n\nThis usually means another WebSocket service is using the configured port, or the backend version is too old.\n\n%s" % [message_text, _get_backend_launcher_details()]
	)


func _check_latest_backend_version_once() -> void:
	backend_manager_button.text = "Runtime diagnostics"
	backend_manager_button.tooltip_text = "View shared runtime and plugin compatibility details."


func _finalize_socket_opened(was_recovering: bool, session_id_to_restore: String) -> void:
	backend_recovery_mode = false
	has_connected_once = true
	workspace_ready = false
	pending_workspace_ready_was_recovering = was_recovering
	pending_workspace_ready_session_id = session_id_to_restore
	status_button.icon = CONNECTED_ICON
	status_button.tooltip_text = "Connected"
	boot_splash.hide()
	main_viewer.show()
	if not was_recovering:
		_show_session_list_viewer()
	elif active_session_id.is_empty():
		_show_session_list_viewer()
	text_edit.show()
	_sync_plan_overlay_input_visibility()
	_send_client_hello()
	_send_environment_config()
	if pending_provider_config_save_after_connect:
		var deferred_api_key: String = pending_provider_config_api_key
		var deferred_base_url: String = pending_provider_config_base_url
		var deferred_provider_id: String = pending_provider_config_provider
		var deferred_model_routing: Dictionary = pending_provider_config_model_routing.duplicate(true)
		pending_provider_config_api_key = ""
		pending_provider_config_base_url = ""
		pending_provider_config_provider = DEFAULT_PROVIDER_ID
		pending_provider_config_model_routing.clear()
		pending_provider_config_save_after_connect = false
		_save_provider_config_to_backend(deferred_provider_id, deferred_api_key, deferred_base_url, deferred_model_routing)
	else:
		_load_provider_config()
	_load_user_prompt()
	_load_approval_mode_from_backend()
	_check_latest_backend_version_once()


func _complete_workspace_initialization() -> void:
	if not workspace_ready:
		return

	_update_send_state()
	_load_mcp_config()
	_refresh_session_and_archive_lists()
	var was_recovering: bool = pending_workspace_ready_was_recovering
	var session_id_to_restore: String = pending_workspace_ready_session_id
	pending_workspace_ready_was_recovering = false
	pending_workspace_ready_session_id = ""
	if not was_recovering:
		_process_message_queue()
		return

	_upsert_connection_status_entry(
		"success",
		"连接已恢复",
		"工作区已连接，正在恢复当前会话。"
	)
	if not session_id_to_restore.is_empty():
		pending_recovery_status_after_session_open = true
		_send_request(RPC_METHODS.SESSION_OPEN, { "sessionId": session_id_to_restore, "limit": SESSION_OPEN_MESSAGE_LIMIT }, "session-recover-open")
	else:
		_finalize_recovery_status(false)


func _on_boot_splash_reconnect_requested() -> void:
	_start_backend_connection_attempts()


func _on_boot_splash_backend_check_requested() -> void:
	_open_backend_manager()


func _on_boot_splash_settings_requested() -> void:
	_on_settings_button_pressed()


func _on_status_button_pressed() -> void:
	if backend_connection_controller.is_open():
		return

	_restart_backend_connection(has_connected_once)


func _handle_socket_closed_after_ready() -> void:
	var close_detail: String = _format_socket_close_tooltip("Disconnected")
	var session_id_to_restore: String = active_session_id
	var was_streaming: bool = not active_stream_id.is_empty()
	socket_ready = false
	workspace_ready = false
	status_button.icon = DISCONNECTED_ICON
	status_button.tooltip_text = "%s. Reconnecting..." % close_detail
	_update_send_state()
	_sync_settings_mcp_servers()
	_begin_backend_recovery(close_detail, session_id_to_restore, was_streaming)


func _begin_backend_recovery(close_detail: String, session_id_to_restore: String, was_streaming: bool) -> void:
	restore_session_after_reconnect_id = session_id_to_restore
	pending_recovery_status_after_session_open = false
	var details: String = "%s\n正在自动重连 Daedalus 后端。" % close_detail
	if was_streaming:
		if active_queue_message_id > 0:
			_finish_active_queue_message(false, MESSAGE_QUEUE_STATUS_FAILED)
		_stop_active_stream_locally(true)
		details += "\n当前回复已在本地暂停；恢复后可以直接发送“继续”。"
	_upsert_connection_status_entry("warning", "连接中断", details)
	_start_backend_connection_attempts(false, true)


func _handle_recovered_session_open(result_dictionary: Dictionary) -> void:
	var metadata_value: Variant = result_dictionary.get("metadata", {})
	if typeof(metadata_value) == TYPE_DICTIONARY:
		_apply_session_metadata(metadata_value as Dictionary)
	_sync_pending_guides_from_result(result_dictionary)
	_apply_latest_workflow_snapshot(result_dictionary)
	_send_request(RPC_METHODS.SESSION_INFO, {}, "session-info")
	_finalize_recovery_status(true)


func _finalize_recovery_status(session_restored: bool) -> void:
	pending_recovery_status_after_session_open = false
	restore_session_after_reconnect_id = ""
	var details: String = "已重新连接 Daedalus 后端。"
	if session_restored:
		details += "\n当前会话已恢复；如果上一条回复被中断，可以继续发送。"
	_upsert_connection_status_entry("success", "连接已恢复", details)
	connection_status_entry_id = ""
	_process_message_queue()


func _on_status_item_action_requested(action_id: String) -> void:
	if action_id == "reconnect":
		_restart_backend_connection(true)
	elif action_id == "provider-settings":
		_on_settings_button_pressed()
	elif action_id.begins_with(NEXT_STEP_HINT_ACTION_PREFIX):
		var hint_message: String = next_step_hints_by_action_id.get(action_id, "")
		if not hint_message.is_empty():
			text_edit.text = hint_message
			text_edit.grab_focus()
			_send_workbench_patch({ "nextStepHintsAction": "clear" })
			_update_send_state()


func _load_provider_config() -> void:
	_send_request(RPC_METHODS.PROVIDER_CONFIG_GET, {}, "provider-config-get")


func _load_user_prompt() -> void:
	_send_request(RPC_METHODS.USER_PROMPT_GET, {}, "user-prompt-get")


func _load_provider_models(provider_id: String, refresh: bool = false) -> void:
	if not _is_socket_open() or provider_id.is_empty():
		return

	var params: Dictionary[String, Variant] = {
		"provider": provider_id,
		"refresh": refresh
	}
	_send_request(RPC_METHODS.PROVIDER_MODELS_LIST, params, "provider-models-list")


func _load_mcp_config() -> void:
	_send_request(RPC_METHODS.MCP_CONFIG_LIST, {}, "mcp-config-list")


func _send_environment_config() -> void:
	if not _is_socket_open():
		return

	var params: Dictionary[String, Variant] = {
		"godotProjectPath": ProjectSettings.globalize_path("res://")
	}
	var executable_path: String = OS.get_executable_path().strip_edges()
	if not executable_path.is_empty():
		params["godotExecutablePath"] = executable_path

	_send_request(RPC_METHODS.ENVIRONMENT_CONFIGURE, params, "environment-configure")


func _ensure_editor_instance_id() -> String:
	return editor_bridge_controller.get_editor_instance_id()


func _send_client_hello() -> void:
	if not _is_socket_open():
		return

	var executable_path: String = OS.get_executable_path().strip_edges()
	var params: Dictionary[String, Variant] = {
		"protocolVersion": 3,
		"clientType": "godot_plugin",
		"clientName": "Godot Daedalus Plugin",
		"pluginVersion": PLUGIN_VERSION,
		"pluginProtocolVersion": PLUGIN_PROTOCOL_VERSION,
		"studioBindingVersion": STUDIO_BINDING_VERSION,
		"workspaceRoot": ProjectSettings.globalize_path("res://"),
		"editorInstanceId": _ensure_editor_instance_id(),
		"capabilities": {
			"editorTools": true,
			"editorUndoRedo": true,
			"sceneViewCapture": true,
			"typedVariantV1": true,
			"scenePatchV2": true,
			"resourcePatchV1": true,
			"animationPatchV1": true,
			"mapPatchV1": true,
			"audioPatchV1": true,
			"editorNavigationV1": true,
			"safePreviewV1": true,
			"inlineDiffUndo": true,
			"inlineDiffView": true,
			"sessionSubscribe": true,
			"approval": true
		}
	}
	if not executable_path.is_empty():
		params["godotExecutablePath"] = executable_path
	_send_request(RPC_METHODS.CLIENT_HELLO, params, "client-hello")


func _update_connection_identity_tooltip() -> void:
	if status_button == null:
		return

	var identity_lines: PackedStringArray = []
	if not connected_workspace_id.is_empty():
		identity_lines.append("Workspace: %s" % connected_workspace_id)
	var editor_instance_id: String = editor_bridge_controller.get_editor_instance_id()
	if not editor_instance_id.is_empty():
		identity_lines.append("Editor: %s" % editor_instance_id)
	if identity_lines.is_empty():
		return

	var base_tooltip: String = status_button.tooltip_text.strip_edges()
	if base_tooltip.is_empty():
		base_tooltip = "Connected"
	status_button.tooltip_text = "%s\n%s" % [base_tooltip.split("\n")[0], "\n".join(identity_lines)]

# --- editor_bridge_controller.gd ---

func setup_editor_bridge(plugin: EditorPlugin) -> void:
	pending_editor_bridge_plugin = plugin
	if is_node_ready():
		editor_bridge_controller.setup(pending_editor_bridge_plugin)


func _on_editor_bridge_request_ready(method: String, params: Dictionary, request_prefix: String) -> void:
	if not _is_socket_open():
		return
	_send_request(method, params, request_prefix)

# --- provider_navigation_controller.gd ---

# --- provider_navigation_controller.gd ---
func _get_selected_model_id() -> String:
	var selected_index: int = model_button.selected
	if selected_index >= 0 and selected_index < model_button.get_item_count():
		var metadata_value: Variant = model_button.get_item_metadata(selected_index)
		if typeof(metadata_value) == TYPE_STRING:
			return str(metadata_value)

	if selected_index < 0 or selected_index >= model_ids.size():
		var fallback_models: Array[Dictionary] = _get_fallback_models_for_provider(active_provider_id)
		if not fallback_models.is_empty():
			return str(fallback_models[0].get("id", ""))
		return ""

	return model_ids[selected_index]


func _update_model_button_tooltip() -> void:
	var selected_index: int = model_button.selected
	if selected_index < 0 or selected_index >= model_ids.size():
		model_button.tooltip_text = "Select model"
		return

	var capability_texts: PackedStringArray
	var capabilities: Dictionary = model_capabilities[selected_index]
	if bool(capabilities.get("imageInput", false)):
		capability_texts.append("image")
	if bool(capabilities.get("videoInput", false)):
		capability_texts.append("video")
	if bool(capabilities.get("reasoning", false)):
		capability_texts.append("reasoning")

	var tooltip_lines: PackedStringArray = [
		"%s / %s" % [_get_provider_display_name(active_provider_id), model_ids[selected_index]]
	]
	if not capability_texts.is_empty():
		tooltip_lines.append("Capabilities: %s" % ", ".join(capability_texts))
	model_button.tooltip_text = "\n".join(tooltip_lines)


func _get_provider_display_name(provider_id: String) -> String:
	for index: int in range(provider_ids.size()):
		if provider_ids[index] == provider_id:
			return provider_names[index]

	return provider_id


func _sync_provider_catalog_from_status(status: Dictionary) -> void:
	var next_provider_ids: PackedStringArray = []
	var next_provider_names: PackedStringArray = []
	var providers_value: Variant = status.get("providers", [])
	if typeof(providers_value) == TYPE_ARRAY:
		for provider_value: Variant in providers_value as Array:
			if typeof(provider_value) != TYPE_DICTIONARY:
				continue
			var provider_status: Dictionary = provider_value as Dictionary
			if bool(provider_status.get("custom", false)) and not bool(provider_status.get("ready", false)):
				continue
			var provider_id: String = str(provider_status.get("provider", "")).strip_edges()
			if provider_id.is_empty() or next_provider_ids.has(provider_id):
				continue
			next_provider_ids.append(provider_id)
			var display_name: String = str(provider_status.get("displayName", provider_id)).strip_edges()
			next_provider_names.append(display_name if not display_name.is_empty() else provider_id)

	if next_provider_ids.is_empty():
		next_provider_ids.append(DEFAULT_PROVIDER_ID)
		next_provider_names.append("DeepSeek")
	provider_ids = next_provider_ids
	provider_names = next_provider_names
	_populate_provider_button()


func _get_selected_approval_mode() -> String:
	var selected_index: int = approval_mode_button.selected
	if selected_index < 0 or selected_index >= APPROVAL_MODE_IDS.size():
		return APPROVAL_MODE_IDS[0]

	return APPROVAL_MODE_IDS[selected_index]


func _get_active_session_metadata_payload() -> Dictionary[String, Variant]:
	return {
		"provider": active_provider_id,
		"model": _get_selected_model_id(),
		"chatMode": _get_selected_chat_mode()
	}


func _save_active_session_metadata() -> void:
	if not _is_socket_open() or active_session_id.is_empty():
		return

	_send_request(RPC_METHODS.SESSION_SAVE, _get_active_session_metadata_payload(), "session-save-metadata")


func _apply_approval_mode_to_backend() -> void:
	if not _is_socket_open():
		return

	_send_request(RPC_METHODS.APPROVAL_MODE_SET, { "mode": _get_selected_approval_mode() }, "approval-mode-set")


func _load_approval_mode_from_backend() -> void:
	if not _is_socket_open():
		return

	_send_request(RPC_METHODS.APPROVAL_LIST, {}, "approval-list")


func _on_back_button_pressed() -> void:
	if active_session_id.is_empty():
		return

	if background_context_viewer.visible:
		_show_session_list_viewer()
	else:
		_show_background_context_viewer()


func _update_navigation_state() -> void:
	if back_button == null:
		return

	back_button.disabled = active_session_id.is_empty()


func _show_session_list_viewer() -> void:
	session_list_viewer.show()
	background_context_viewer.hide()
	additional_context_viewer.hide()
	workspace_filter_button.show()
	search_session_line_edit.show()
	session_option_button.hide()
	context_length_button.hide()
	_update_navigation_state()
	_render_message_panel()


func _show_background_context_viewer() -> void:
	if active_session_id.is_empty():
		_show_session_list_viewer()
		return

	session_list_viewer.hide()
	background_context_viewer.show()
	additional_context_viewer.show()
	workspace_filter_button.hide()
	search_session_line_edit.hide()
	session_option_button.show()
	context_length_button.show()
	_update_navigation_state()
	_render_message_panel()


func _on_create_new_session_button_pressed() -> void:
	_clear_message_queue()
	_clear_manual_guides()
	_create_session("New session " + Time.get_datetime_string_from_system(false, true))


func _on_session_option_button_item_selected(index: int) -> void:
	if index < 0 or index >= session_option_button.get_item_count():
		return

	var session_id: String = str(session_option_button.get_item_metadata(index))
	if not session_id.is_empty():
		_open_session(session_id)


func _on_model_button_item_selected(index: int) -> void:
	if index < 0 or index >= model_button.get_item_count():
		return

	_update_model_button_tooltip()
	_save_active_session_metadata()
	_send_workbench_composer_patch(false, false)
	_update_send_state()


func _on_provider_option_button_item_selected(index: int) -> void:
	if index < 0 or index >= provider_option_button.get_item_count():
		return

	_switch_active_provider(_get_selected_provider_id(), true)
	_send_workbench_composer_patch(false, false)


func _on_approval_mode_button_item_selected(index: int) -> void:
	if index < 0 or index >= APPROVAL_MODE_IDS.size():
		return

	_save_active_session_metadata()
	_send_workbench_composer_patch(false, false)
	_apply_approval_mode_to_backend()


func _on_mode_button_id_pressed(menu_id: int) -> void:
	var selected_chat_mode: String = _get_chat_mode_from_menu_id(menu_id)
	if not _select_chat_mode(selected_chat_mode):
		_select_chat_mode(CHAT_MODE_AGENT)

	_save_active_session_metadata()
	_send_workbench_composer_patch(false, false)


func _on_send_button_pressed() -> void:
	var message_text: String = text_edit.text.strip_edges()
	if message_text.is_empty():
		_flush_workbench_composer_patch()
		_process_message_queue()
		return

	var additional_context_snapshot: Array[Dictionary] = _get_additional_context_snapshot()
	if _context_array_has_images(additional_context_snapshot) and not _can_send_image_contexts():
		_show_image_model_warning()
		_update_send_state()
		return

	if _should_queue_outgoing_message():
		if _enqueue_message(message_text, additional_context_snapshot):
			_discard_pending_workbench_composer_patch()
			_clear_text_edit_after_submit()
			additional_context_controller.clear_unpinned()
			_sync_workbench_composer_after_submit()
			_update_send_state()
			_process_message_queue()
		return

	if _dispatch_message_text(message_text, additional_context_snapshot):
		_discard_pending_workbench_composer_patch()
		additional_context_controller.clear_unpinned()
		if active_session_id.is_empty():
			_clear_text_edit_after_submit()
		_sync_workbench_composer_after_submit()
		_update_send_state()


func _on_user_message_resend_requested(request_id_to_retry: String, message_text: String, additional_contexts: Array = []) -> void:
	if message_text.strip_edges().is_empty() or not active_stream_id.is_empty():
		return

	var retry_additional_contexts: Array[Dictionary] = additional_context_controller.freeze_contexts_for_message(additional_contexts, true)
	if active_session_id.is_empty():
		_send_chat_text(message_text, "", retry_additional_contexts)
		return

	_trim_timeline_from_request(request_id_to_retry)
	_send_chat_text(message_text, request_id_to_retry, retry_additional_contexts)


func _trim_timeline_from_request(request_id_to_retry: String) -> void:
	if request_id_to_retry.is_empty():
		return

	var first_index: int = -1
	for index: int in range(timeline_entries.size()):
		var entry: Dictionary = timeline_entries[index]
		if str(entry.get("request_id", "")) == request_id_to_retry:
			first_index = index
			break

	if first_index < 0:
		return

	while timeline_entries.size() > first_index:
		timeline_entries.remove_at(timeline_entries.size() - 1)

	for child: Node in timeline_visible_container.get_children():
		child.queue_free()
	rendered_entry_nodes.clear()
	rendered_entry_indices.clear()
	tool_items_by_call_id.clear()
	active_assistant_item = null
	active_thinking_item = null
	active_assistant_entry_id = ""
	active_thinking_entry_id = ""
	active_assistant_text = ""
	active_stream_started_at_utc = ""
	active_stream_status_code = ""
	_clear_paused_stream_context()
	_rebuild_timeline_index_cache()
	_rebuild_timeline_height_cache()
	_clear_todo_items()
	_render_visible_timeline(true)


func _on_stop_button_pressed() -> void:
	if active_stream_id.is_empty():
		return

	var request_id_to_cancel: String = active_stream_id
	_send_request(RPC_METHODS.AI_CANCEL, { "requestId": request_id_to_cancel }, "ai-cancel")
	if active_queue_message_id > 0:
		_finish_active_queue_message(false, MESSAGE_QUEUE_STATUS_CANCELLED)
	_stop_active_stream_locally(true)


func _stop_active_stream_locally(prepare_continue: bool) -> void:
	_flush_pending_assistant_delta()
	_flush_pending_thinking_delta()
	if active_assistant_item != null:
		active_assistant_item.call("finish_message")
	if active_thinking_item != null:
		active_thinking_item.call("finish_thinking")
	file_edit_controller.set_active_session_id(active_session_id)
	file_edit_controller.complete_stream(active_assistant_entry_id)

	active_stream_id = ""
	active_stream_request_id = ""
	active_stream_started_at_utc = ""
	active_stream_status_code = ""
	active_assistant_item = null
	active_thinking_item = null
	active_assistant_entry_id = ""
	active_thinking_entry_id = ""
	active_assistant_text = ""
	file_edit_controller.clear_active_batches()
	_clear_paused_stream_context()
	_set_streaming_state(false)

	if prepare_continue and text_edit.text.strip_edges().is_empty():
		text_edit.grab_focus()


func _save_paused_stream_context() -> void:
	paused_stream_request_id = active_stream_request_id
	paused_stream_started_at_utc = active_stream_started_at_utc
	paused_assistant_entry_id = active_assistant_entry_id


func _clear_paused_stream_context() -> void:
	paused_stream_request_id = ""
	paused_stream_started_at_utc = ""
	paused_assistant_entry_id = ""


func _restore_paused_stream_context_for_continuation(continuation_request_id: String) -> void:
	active_stream_request_id = paused_stream_request_id
	if active_stream_request_id.is_empty():
		active_stream_request_id = continuation_request_id

	active_stream_started_at_utc = paused_stream_started_at_utc
	if active_stream_started_at_utc.is_empty():
		active_stream_started_at_utc = MAIN_HELPERS.get_utc_timestamp()

	active_assistant_entry_id = paused_assistant_entry_id
	if not active_assistant_entry_id.is_empty() and _find_timeline_entry_index(active_assistant_entry_id) < 0:
		active_assistant_entry_id = ""

	active_assistant_item = null
	active_assistant_text = ""
	if not active_assistant_entry_id.is_empty():
		active_assistant_text = _get_timeline_entry_content(active_assistant_entry_id)
		active_assistant_item = rendered_entry_nodes.get(active_assistant_entry_id, null) as Node
		return

	_ensure_active_assistant_item()


func _on_approve_button_pressed() -> void:
	if pending_approval_id.is_empty():
		return

	_flush_workbench_composer_patch()
	if active_queue_message_id > 0:
		_set_queue_message_status(active_queue_message_id, MESSAGE_QUEUE_STATUS_SENDING)
	var should_follow_bottom: bool = _should_follow_timeline_updates()
	var continuation_request_id: String = _send_request(RPC_METHODS.APPROVAL_APPROVE, { "approvalId": pending_approval_id }, "approval-approve")
	if continuation_request_id.is_empty():
		_show_response_error({ "error": { "message": "发送审批通过请求失败。" } })
		return

	active_stream_id = continuation_request_id
	_restore_paused_stream_context_for_continuation(continuation_request_id)
	_set_streaming_state(true)
	_scroll_to_bottom_if_following(should_follow_bottom)
	approval_dialog.visible = false


func _on_reject_button_pressed() -> void:
	if pending_approval_id.is_empty():
		return

	_flush_workbench_composer_patch()
	var reject_request_id: String = _send_request(RPC_METHODS.APPROVAL_REJECT, { "approvalId": pending_approval_id }, "approval-reject")
	if reject_request_id.is_empty():
		_show_response_error({ "error": { "message": "发送审批拒绝请求失败。" } })
		return

	_clear_paused_stream_context()
	approval_dialog.visible = false


func _on_skip_approval_button_pressed() -> void:
	approval_dialog.visible = false


func _create_session(title_text: String) -> void:
	if not _is_socket_open():
		return

	var params: Dictionary = { "title": title_text }
	var metadata_payload: Dictionary[String, Variant] = _get_active_session_metadata_payload()
	for metadata_key: Variant in metadata_payload.keys():
		var metadata_key_text: String = str(metadata_key)
		params[metadata_key_text] = metadata_payload[metadata_key_text]
	if not connected_workspace_id.is_empty():
		params["workspaceId"] = connected_workspace_id

	_send_request(RPC_METHODS.SESSION_CREATE, params, "session-create")


func _open_session(session_id: String) -> void:
	if not _is_socket_open() or not workspace_ready:
		if _is_socket_open():
			_upsert_connection_status_entry("message", "工作区正在初始化", "正在连接项目的 MCP 服务，请稍后再打开会话。")
		return

	if session_id != active_session_id:
		_clear_message_queue()
		_clear_manual_guides()
	_send_request(RPC_METHODS.SESSION_OPEN, { "sessionId": session_id, "limit": SESSION_OPEN_MESSAGE_LIMIT }, "session-open")


func _clear_message_queue() -> void:
	queued_messages.clear()
	message_queue_next_id = 0
	active_queue_message_id = 0
	_render_message_panel()
	_update_send_state()


func _apply_message_queue_snapshot_from_result(result_dictionary: Dictionary) -> bool:
	if not result_dictionary.has("messageQueue"):
		return false

	_apply_message_queue_snapshot(result_dictionary.get("messageQueue", []))
	return true


func _apply_message_queue_snapshot(queue_value: Variant) -> void:
	if typeof(queue_value) != TYPE_ARRAY:
		return

	queued_messages.clear()
	var queue_array: Array = queue_value as Array
	for item_value: Variant in queue_array:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue

		var item: Dictionary = item_value as Dictionary
		var queue_message_id: int = int(item.get("id", 0))
		if queue_message_id <= 0:
			continue

		if queue_message_id > message_queue_next_id:
			message_queue_next_id = queue_message_id

		var contexts: Array[Dictionary] = []
		var contexts_value: Variant = item.get("additionalContext", item.get("additional_context", []))
		if typeof(contexts_value) == TYPE_ARRAY:
			var context_array: Array = contexts_value as Array
			for context_value: Variant in context_array:
				if typeof(context_value) == TYPE_DICTIONARY:
					contexts.append((context_value as Dictionary).duplicate(true))

		var queued_message: Dictionary = {
			"id": queue_message_id,
			"text": str(item.get("text", "")),
			"additional_context": contexts,
			"status": str(item.get("status", MESSAGE_QUEUE_STATUS_PENDING)),
			"created_at_utc": str(item.get("createdAt", item.get("created_at_utc", ""))),
			"updated_at_utc": str(item.get("updatedAt", item.get("updated_at_utc", "")))
		}
		queued_messages.append(queued_message)

	if active_queue_message_id > 0 and _find_queue_message_index(active_queue_message_id) < 0:
		active_queue_message_id = 0

	_render_message_panel()
	_update_send_state()


func _send_workbench_patch(params: Dictionary) -> void:
	if applying_workbench_snapshot:
		return
	if not _is_socket_open():
		return

	workbench_patch_sequence += 1
	var request_params: Dictionary = params.duplicate(true)
	request_params["clientSequence"] = workbench_patch_sequence
	_send_request(RPC_METHODS.SESSION_WORKBENCH_PATCH, request_params, "session-workbench-patch")


func _queue_workbench_composer_patch(include_text: bool = true, include_context: bool = false) -> void:
	if applying_workbench_snapshot:
		return

	workbench_composer_patch_include_text = workbench_composer_patch_include_text or include_text
	workbench_composer_patch_include_context = workbench_composer_patch_include_context or include_context
	if workbench_composer_patch_debounce_pending:
		return

	workbench_composer_patch_debounce_pending = true
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		_flush_workbench_composer_patch()
		return

	var timer: SceneTreeTimer = scene_tree.create_timer(WORKBENCH_PATCH_DEBOUNCE_SECONDS)
	timer.timeout.connect(Callable(self, "_on_workbench_composer_patch_debounce_timeout"))


func _on_workbench_composer_patch_debounce_timeout() -> void:
	_flush_workbench_composer_patch()


func _flush_workbench_composer_patch() -> void:
	if not workbench_composer_patch_debounce_pending:
		return

	var include_text: bool = workbench_composer_patch_include_text
	var include_context: bool = workbench_composer_patch_include_context
	workbench_composer_patch_debounce_pending = false
	workbench_composer_patch_include_text = false
	workbench_composer_patch_include_context = false
	_send_workbench_composer_patch(include_text, include_context)


func _discard_pending_workbench_composer_patch() -> void:
	workbench_composer_patch_debounce_pending = false
	workbench_composer_patch_include_text = false
	workbench_composer_patch_include_context = false


func _sync_workbench_composer_after_submit() -> void:
	_discard_pending_workbench_composer_patch()
	if active_session_id.is_empty():
		return

	_send_workbench_composer_patch(true, true)


func _send_workbench_composer_patch(include_text: bool = true, include_context: bool = false) -> void:
	var composer: Dictionary[String, Variant] = {
		"chatMode": _get_selected_chat_mode(),
		"provider": active_provider_id,
		"model": _get_selected_model_id()
	}
	if include_text:
		composer["text"] = text_edit.text
	if include_context:
		var context_snapshot: Array[Dictionary] = additional_context_controller.get_backend_snapshot()
		composer["additionalContext"] = context_snapshot
		workbench_context_patch_in_flight = true
		workbench_context_patch_signature = JSON.stringify(context_snapshot)
	_send_workbench_patch({ "composer": composer })


func _apply_workbench_from_result(result_dictionary: Dictionary) -> bool:
	var workbench_value: Variant = result_dictionary.get("workbench", {})
	if typeof(workbench_value) != TYPE_DICTIONARY:
		return false

	_apply_workbench_snapshot(workbench_value as Dictionary)
	return true


func _apply_workbench_snapshot(workbench: Dictionary) -> void:
	var revision_value: int = int(workbench.get("revision", workbench_revision))
	if revision_value < workbench_revision:
		return

	workbench_revision = revision_value
	applying_workbench_snapshot = true
	var composer_value: Variant = workbench.get("composer", {})
	if typeof(composer_value) == TYPE_DICTIONARY:
		_apply_workbench_composer(composer_value as Dictionary)

	_apply_message_queue_snapshot_from_result(workbench)
	_sync_pending_guides_from_result(workbench)
	_apply_workbench_next_step_hints(workbench)
	applying_workbench_snapshot = false
	_update_send_state()


func _apply_workbench_composer(composer: Dictionary) -> void:
	var text_value: Variant = composer.get("text", null)
	if typeof(text_value) == TYPE_STRING and active_stream_id.is_empty() and not workbench_composer_patch_include_text:
		var composer_text: String = str(text_value)
		if text_edit.text != composer_text:
			text_edit.text = composer_text

	var chat_mode_value: String = str(composer.get("chatMode", "")).strip_edges()
	if not chat_mode_value.is_empty():
		_select_chat_mode(chat_mode_value)

	var provider_value: String = str(composer.get("provider", "")).strip_edges()
	if _is_known_provider_id(provider_value) and provider_value != active_provider_id:
		_switch_active_provider(provider_value, false)

	var model_value: String = str(composer.get("model", "")).strip_edges()
	if not model_value.is_empty():
		_select_or_add_model_id(model_value)

	var contexts_value: Variant = composer.get("additionalContext", [])
	if typeof(contexts_value) == TYPE_ARRAY:
		var incoming_contexts: Array = contexts_value as Array
		if _should_apply_workbench_context_snapshot(incoming_contexts):
			additional_context_controller.replace_items(incoming_contexts)


func _should_apply_workbench_context_snapshot(incoming_contexts: Array) -> bool:
	if not workbench_composer_patch_include_context and not workbench_context_patch_in_flight:
		return true

	var expected_signature: String = workbench_context_patch_signature
	if workbench_composer_patch_include_context or expected_signature.is_empty():
		expected_signature = JSON.stringify(additional_context_controller.get_backend_snapshot())
	var incoming_signature: String = JSON.stringify(incoming_contexts)
	if incoming_signature != expected_signature:
		return false

	if not workbench_composer_patch_include_context:
		workbench_context_patch_in_flight = false
		workbench_context_patch_signature = ""
	return true


func _apply_workbench_next_step_hints(workbench: Dictionary) -> void:
	var hints_state_value: Variant = workbench.get("nextStepHints", {})
	if typeof(hints_state_value) != TYPE_DICTIONARY:
		return

	var hints_state: Dictionary = hints_state_value as Dictionary
	var hints_value: Variant = hints_state.get("hints", [])
	var signature: String = JSON.stringify(hints_state)
	if signature == next_step_hints_signature:
		return

	next_step_hints_signature = signature
	_apply_next_step_hints_state(hints_value)


func _dispatch_message_text(message_text: String, additional_contexts: Array = []) -> bool:
	if not _is_socket_open():
		return false

	if active_session_id.is_empty():
		pending_chat_text = message_text
		pending_chat_additional_context = additional_context_controller.freeze_contexts_for_message(additional_contexts, true)
		_create_session(MAIN_HELPERS.make_session_title(message_text))
		return true

	return _send_chat_text(message_text, "", additional_contexts)

# --- chat_transport_controller.gd ---

func _create_chat_options_for_mode(chat_mode: String) -> Dictionary[String, Variant]:
	if chat_mode == CHAT_MODE_ASK:
		return {
			"stream": true,
			"toolBudget": "normal",
			"workflow": "single"
		}
	if chat_mode == CHAT_MODE_PLAN:
		return {
			"stream": false,
			"toolBudget": "normal",
			"workflow": "single"
		}

	return {
		"stream": true,
		"toolBudget": "project_edit",
		"workflow": "llm_planned"
	}


func _send_chat_text(message_text: String, retry_from_request_id: String = "", additional_contexts: Array = []) -> bool:
	if not _is_socket_open():
		return false
	var frozen_additional_contexts: Array[Dictionary] = additional_context_controller.freeze_contexts_for_message(additional_contexts, true)
	if _context_array_has_images(frozen_additional_contexts) and not _can_send_image_contexts():
		_show_image_model_warning()
		_update_send_state()
		return false

	_show_background_context_viewer()

	active_assistant_item = null
	active_assistant_entry_id = ""
	active_thinking_entry_id = ""
	active_assistant_text = ""
	file_edit_controller.clear_active_batches()
	_clear_paused_stream_context()
	_clear_todo_items()

	chat_request_id += 1
	active_stream_id = "daedalus-chat-%d" % chat_request_id
	active_stream_request_id = active_stream_id
	active_stream_started_at_utc = MAIN_HELPERS.get_utc_timestamp()
	active_stream_status_code = ""
	var timeline_additional_context_snapshot: Array[Dictionary] = additional_context_controller.clone_contexts(frozen_additional_contexts, true)
	var request_additional_context_snapshot: Array[Dictionary] = additional_context_controller.clone_contexts(frozen_additional_contexts)
	var should_follow_bottom: bool = _should_follow_timeline_updates()
	_append_timeline_entry(
		"user",
		active_stream_request_id,
		message_text,
		"",
		{
			"sent_at_utc": active_stream_started_at_utc,
			"additional_context": timeline_additional_context_snapshot
		}
	)
	active_assistant_entry_id = _append_timeline_entry(
		"assistant",
		active_stream_request_id,
		"",
		"",
		{ "started_at_utc": active_stream_started_at_utc }
	)
	_schedule_timeline_render(should_follow_bottom)

	var selected_chat_mode: String = _get_selected_chat_mode()
	_save_active_session_metadata()
	var chat_params: Dictionary[String, Variant] = {
		"message": message_text,
		"mode": selected_chat_mode,
		"promptId": "godot.assistant",
		"options": _create_chat_options_for_mode(selected_chat_mode)
	}
	var explicit_skill_refs: Array[String] = _extract_skill_refs(message_text)
	if not explicit_skill_refs.is_empty():
		chat_params["skillRefs"] = explicit_skill_refs
	if not retry_from_request_id.is_empty():
		chat_params["retryFromRequestId"] = retry_from_request_id
	if not request_additional_context_snapshot.is_empty():
		chat_params["additionalContext"] = request_additional_context_snapshot

	var payload: Dictionary[String, Variant] = {
		"type": "request",
		"id": active_stream_id,
		"method": RPC_METHODS.AI_CHAT,
		"params": chat_params
	}

	var send_error: Error = backend_connection_controller.send_json(payload)
	if send_error != OK:
		var completed_at_utc: String = MAIN_HELPERS.get_utc_timestamp()
		_show_response_error({
			"error": {
				"message": "发送请求失败：%s" % error_string(send_error)
			}
		})
		if not active_assistant_entry_id.is_empty():
			_set_timeline_entry_times(active_assistant_entry_id, active_stream_started_at_utc, completed_at_utc)
		active_stream_id = ""
		active_stream_started_at_utc = ""
		active_stream_status_code = ""
		active_assistant_item = null
		active_assistant_entry_id = ""
		_set_streaming_state(false)
		if active_queue_message_id > 0:
			_finish_active_queue_message(false, MESSAGE_QUEUE_STATUS_FAILED)
		return false

	_scroll_to_bottom_if_following(should_follow_bottom)
	_clear_text_edit_after_submit()
	_set_streaming_state(true)
	return true


func _should_queue_outgoing_message() -> bool:
	return (
		not _is_socket_open()
		or not active_stream_id.is_empty()
		or not pending_approval_id.is_empty()
		or not pending_chat_text.is_empty()
		or _has_pending_queued_messages()
	)

# --- message_queue_controller.gd ---

func _enqueue_message(message_text: String, additional_contexts: Array = []) -> bool:
	if _get_open_queue_count() >= MAX_QUEUED_MESSAGES:
		_upsert_connection_status_entry(
			"warning",
			"消息队列已满",
			"最多保留 %d 条待发送消息。请等待当前队列消化后再继续添加。" % MAX_QUEUED_MESSAGES
		)
		return false

	if _is_socket_open():
		var frozen_additional_contexts: Array[Dictionary] = additional_context_controller.freeze_contexts_for_message(additional_contexts, true)
		var backend_params: Dictionary = {
			"text": message_text,
			"additionalContext": additional_context_controller.clone_contexts(frozen_additional_contexts, true)
		}
		var add_request_id: String = _send_request(RPC_METHODS.MESSAGE_QUEUE_ADD, backend_params, "message-queue-add")
		if not add_request_id.is_empty():
			_show_background_context_viewer()
			_update_send_state()
			return true

	return _append_local_queue_message(message_text, additional_contexts)


func _append_local_queue_message(message_text: String, additional_contexts: Array = []) -> bool:
	var frozen_additional_contexts: Array[Dictionary] = additional_context_controller.freeze_contexts_for_message(additional_contexts, true)
	message_queue_next_id += 1
	var queued_message: Dictionary = {
		"id": message_queue_next_id,
		"text": message_text,
		"additional_context": additional_context_controller.clone_contexts(frozen_additional_contexts, true),
		"status": MESSAGE_QUEUE_STATUS_PENDING,
		"created_at_utc": MAIN_HELPERS.get_utc_timestamp()
	}
	queued_messages.append(queued_message)
	_show_background_context_viewer()
	_render_message_panel()
	_update_send_state()
	return true


func _process_message_queue() -> void:
	if not _can_dispatch_queued_message():
		_render_message_panel()
		return

	var queued_index: int = _find_next_pending_queue_index()
	if queued_index < 0:
		_render_message_panel()
		return

	var queued_message: Dictionary = queued_messages[queued_index]
	active_queue_message_id = int(queued_message.get("id", 0))
	_set_queue_message_status(active_queue_message_id, MESSAGE_QUEUE_STATUS_SENDING)
	var refreshed_index: int = _find_queue_message_index(active_queue_message_id)
	if refreshed_index >= 0:
		queued_message = queued_messages[refreshed_index]
	_render_message_panel()

	var queued_text: String = str(queued_message.get("text", ""))
	var queued_contexts: Array = queued_message.get("additional_context", []) as Array
	if not _dispatch_message_text(queued_text, queued_contexts):
		_finish_active_queue_message(false, MESSAGE_QUEUE_STATUS_FAILED)
		_process_message_queue()


func _can_dispatch_queued_message() -> bool:
	return (
		_is_socket_open()
		and workspace_ready
		and active_stream_id.is_empty()
		and pending_approval_id.is_empty()
		and pending_chat_text.is_empty()
	)


func _has_pending_queued_messages() -> bool:
	return _find_next_pending_queue_index() >= 0


func _find_next_pending_queue_index() -> int:
	for index: int in range(queued_messages.size()):
		var queued_message: Dictionary = queued_messages[index]
		if str(queued_message.get("status", MESSAGE_QUEUE_STATUS_PENDING)) == str(MESSAGE_QUEUE_STATUS_PENDING):
			return index

	return -1


func _find_queue_message_index(queue_message_id: int) -> int:
	for index: int in range(queued_messages.size()):
		var queued_message: Dictionary = queued_messages[index]
		if int(queued_message.get("id", 0)) == queue_message_id:
			return index

	return -1


func _get_open_queue_count() -> int:
	var open_count: int = 0
	for queued_message: Dictionary in queued_messages:
		var status: String = str(queued_message.get("status", MESSAGE_QUEUE_STATUS_PENDING))
		if status == str(MESSAGE_QUEUE_STATUS_PENDING) or status == str(MESSAGE_QUEUE_STATUS_SENDING) or status == str(MESSAGE_QUEUE_STATUS_APPROVAL):
			open_count += 1

	return open_count


func _set_queue_message_status(queue_message_id: int, status: StringName) -> void:
	var queue_index: int = _find_queue_message_index(queue_message_id)
	if queue_index < 0:
		return

	var queued_message: Dictionary = queued_messages[queue_index]
	queued_message["status"] = status
	queued_messages[queue_index] = queued_message
	if _is_socket_open():
		_send_request(
			RPC_METHODS.MESSAGE_QUEUE_STATUS,
			{
				"queueId": queue_message_id,
				"status": str(status)
			},
			"message-queue-status"
		)
	_render_message_panel()


func _finish_active_queue_message(remove_message: bool, final_status: StringName = &"failed") -> void:
	if active_queue_message_id <= 0:
		return

	var finished_queue_message_id: int = active_queue_message_id
	active_queue_message_id = 0
	if remove_message:
		_remove_queue_message(finished_queue_message_id)
	else:
		_set_queue_message_status(finished_queue_message_id, final_status)
	_render_message_panel()


func _remove_queue_message(queue_message_id: int) -> void:
	var queue_index: int = _find_queue_message_index(queue_message_id)
	if queue_index < 0:
		return

	queued_messages.remove_at(queue_index)
	if _is_socket_open():
		_send_request(RPC_METHODS.MESSAGE_QUEUE_REMOVE, { "queueId": queue_message_id }, "message-queue-remove")

# --- guide_controller.gd ---

func _handle_queue_tree_action(button_id: int, metadata: Dictionary) -> void:
	var queue_message_id: int = int(metadata.get("id", 0))
	var queue_status: String = str(metadata.get("status", ""))
	var queue_message_text: String = str(metadata.get("message", ""))
	if queue_message_id <= 0:
		return

	if button_id == MESSAGE_TREE_BUTTON_EDIT:
		if not MAIN_HELPERS.can_edit_queue_message(queue_status):
			return
		text_edit.text = queue_message_text
		text_edit.grab_focus()
		_remove_queue_message(queue_message_id)
	elif button_id == MESSAGE_TREE_BUTTON_DELETE:
		if not MAIN_HELPERS.can_delete_queue_message(queue_status):
			return
		_remove_queue_message(queue_message_id)

	_render_message_panel()
	_update_send_state()


func _handle_guide_tree_action(button_id: int, metadata: Dictionary) -> void:
	var local_id: String = str(metadata.get("local_id", ""))
	if local_id.is_empty():
		return

	if button_id == MESSAGE_TREE_BUTTON_GUIDE_NOW:
		_submit_manual_guide(local_id)
	elif button_id == MESSAGE_TREE_BUTTON_EDIT:
		_edit_manual_guide(local_id)
	elif button_id == MESSAGE_TREE_BUTTON_DELETE:
		_delete_manual_guide(local_id)


func _create_or_update_manual_guide_from_text_edit() -> void:
	var guide_text: String = text_edit.text.strip_edges()
	if guide_text.is_empty():
		return

	if not editing_guide_local_id.is_empty():
		if _update_editing_manual_guide(guide_text):
			_clear_text_edit_after_submit()
			editing_guide_local_id = ""
			_update_send_state()
		return

	manual_guide_next_id += 1
	var local_id: String = "local-guide-%d" % manual_guide_next_id
	var manual_guide: Dictionary = {
		"local_id": local_id,
		"guide_id": "",
		"client_guide_id": local_id,
		"text": guide_text,
		"status": GUIDE_STATUS_DRAFT,
		"created_at_utc": MAIN_HELPERS.get_utc_timestamp(),
		"updated_at_utc": MAIN_HELPERS.get_utc_timestamp(),
		"anchor_request_id": active_stream_request_id
	}
	manual_guides.append(manual_guide)
	_clear_text_edit_after_submit()
	_show_background_context_viewer()
	_render_message_panel()
	_update_send_state()


func _update_editing_manual_guide(guide_text: String) -> bool:
	var guide_index: int = _find_manual_guide_index(editing_guide_local_id)
	if guide_index < 0:
		return false

	var manual_guide: Dictionary = manual_guides[guide_index]
	var guide_status: String = str(manual_guide.get("status", GUIDE_STATUS_DRAFT))
	manual_guide["text"] = guide_text
	manual_guide["updated_at_utc"] = MAIN_HELPERS.get_utc_timestamp()

	if guide_status == str(GUIDE_STATUS_PENDING):
		var guide_id: String = str(manual_guide.get("guide_id", ""))
		if guide_id.is_empty() or not _is_socket_open():
			manual_guide["status"] = GUIDE_STATUS_FAILED
		else:
			var params: Dictionary[String, Variant] = {
				"guideId": guide_id,
				"text": guide_text
			}
			var update_request_id: String = _send_request(RPC_METHODS.SESSION_GUIDE_UPDATE, params, "guide-update")
			manual_guide["pending_request_id"] = update_request_id
			manual_guide["status"] = GUIDE_STATUS_PENDING
	else:
		manual_guide["status"] = GUIDE_STATUS_DRAFT

	manual_guides[guide_index] = manual_guide
	_render_message_panel()
	return true


func _submit_manual_guide(local_id: String) -> void:
	var guide_index: int = _find_manual_guide_index(local_id)
	if guide_index < 0:
		return

	if active_session_id.is_empty():
		_upsert_connection_status_entry("warning", "无法引导", "当前没有打开的会话。请先发送一条消息或打开一个会话。")
		return
	if not _is_socket_open():
		_upsert_connection_status_entry("warning", "无法引导", "后端未连接，引导会先保留在本地。")
		return

	var manual_guide: Dictionary = manual_guides[guide_index]
	var guide_status: String = str(manual_guide.get("status", GUIDE_STATUS_DRAFT))
	if not MAIN_HELPERS.can_submit_manual_guide(guide_status):
		return

	var guide_text: String = str(manual_guide.get("text", "")).strip_edges()
	if guide_text.is_empty():
		return

	var params: Dictionary[String, Variant] = {
		"clientGuideId": str(manual_guide.get("client_guide_id", local_id)),
		"text": guide_text
	}
	var anchor_request_id: String = str(manual_guide.get("anchor_request_id", ""))
	if not anchor_request_id.is_empty():
		params["anchorRequestId"] = anchor_request_id

	var add_request_id: String = _send_request(RPC_METHODS.SESSION_GUIDE_ADD, params, "guide-add")
	if add_request_id.is_empty():
		_upsert_connection_status_entry("warning", "无法引导", "引导提交失败，后端连接不可用。")
		return

	manual_guide["status"] = GUIDE_STATUS_SUBMITTING
	manual_guide["pending_request_id"] = add_request_id
	manual_guides[guide_index] = manual_guide
	_render_message_panel()


func _edit_manual_guide(local_id: String) -> void:
	var guide_index: int = _find_manual_guide_index(local_id)
	if guide_index < 0:
		return

	var manual_guide: Dictionary = manual_guides[guide_index]
	var guide_status: String = str(manual_guide.get("status", GUIDE_STATUS_DRAFT))
	if not MAIN_HELPERS.can_edit_manual_guide(guide_status):
		return

	text_edit.text = str(manual_guide.get("text", ""))
	text_edit.grab_focus()
	if guide_status == str(GUIDE_STATUS_PENDING):
		editing_guide_local_id = local_id
	elif guide_status == str(GUIDE_STATUS_DRAFT) or guide_status == str(GUIDE_STATUS_FAILED):
		manual_guides.remove_at(guide_index)
		editing_guide_local_id = ""
	else:
		editing_guide_local_id = ""
	_render_message_panel()
	_update_send_state()


func _delete_manual_guide(local_id: String) -> void:
	var guide_index: int = _find_manual_guide_index(local_id)
	if guide_index < 0:
		return

	var manual_guide: Dictionary = manual_guides[guide_index]
	var guide_status: String = str(manual_guide.get("status", GUIDE_STATUS_DRAFT))
	if not MAIN_HELPERS.can_delete_manual_guide(guide_status):
		return

	if guide_status == str(GUIDE_STATUS_PENDING):
		var guide_id: String = str(manual_guide.get("guide_id", ""))
		if not guide_id.is_empty() and _is_socket_open():
			var delete_request_id: String = _send_request(RPC_METHODS.SESSION_GUIDE_DELETE, { "guideId": guide_id }, "guide-delete")
			manual_guide["status"] = GUIDE_STATUS_DELETING
			manual_guide["pending_request_id"] = delete_request_id
			manual_guides[guide_index] = manual_guide
		else:
			manual_guides.remove_at(guide_index)
	else:
		manual_guides.remove_at(guide_index)

	if editing_guide_local_id == local_id:
		editing_guide_local_id = ""
	_render_message_panel()
	_update_send_state()


func _find_manual_guide_index(local_id: String) -> int:
	for index: int in range(manual_guides.size()):
		var manual_guide: Dictionary = manual_guides[index]
		if str(manual_guide.get("local_id", "")) == local_id:
			return index

	return -1


func _find_manual_guide_index_by_backend_id(guide_id: String, client_guide_id: String = "") -> int:
	for index: int in range(manual_guides.size()):
		var manual_guide: Dictionary = manual_guides[index]
		if not guide_id.is_empty() and str(manual_guide.get("guide_id", "")) == guide_id:
			return index
		if not client_guide_id.is_empty() and str(manual_guide.get("client_guide_id", "")) == client_guide_id:
			return index

	return -1


func _clear_manual_guides() -> void:
	manual_guides.clear()
	editing_guide_local_id = ""
	_render_message_panel()
	_update_send_state()

# --- message_router_controller.gd ---

func _send_request(method: String, params: Dictionary, id_prefix: String) -> String:
	return backend_connection_controller.send_request(method, params, id_prefix)


func _is_socket_open() -> bool:
	return backend_connection_controller.is_open()


func _format_socket_close_tooltip(prefix: String) -> String:
	var close_code: int = backend_connection_controller.get_close_code()
	var close_reason: String = backend_connection_controller.get_close_reason()
	if close_reason.is_empty():
		return "%s (%d)" % [prefix, close_code]

	return "%s (%d): %s" % [prefix, close_code, close_reason]


func _handle_message(message: Dictionary) -> void:
	var message_type: String = str(message.get("type", ""))
	if message_type == "response":
		_handle_response(message)
	elif message_type == "event":
		_handle_event(message)


func _handle_response(message: Dictionary) -> void:
	if _handle_backend_health_response(message):
		return

	var ok: bool = bool(message.get("ok", false))
	if not ok:
		if _handle_attachment_image_save_response(str(message.get("id", "")), false, {}):
			return
		if file_edit_controller.handle_batch_response(str(message.get("id", "")), false, {}):
			return
		if _handle_plan_response_error(str(message.get("id", ""))):
			return
		if str(message.get("id", "")).begins_with("mcp-config"):
			_handle_mcp_config_error(message)
			return
		if str(message.get("id", "")).begins_with("web-search-settings"):
			var web_search_error_text: String = "Failed to update web search settings."
			var web_search_error_value: Variant = message.get("error", {})
			if typeof(web_search_error_value) == TYPE_DICTIONARY:
				web_search_error_text = str((web_search_error_value as Dictionary).get("message", web_search_error_text))
			if active_settings_menu != null and is_instance_valid(active_settings_menu):
				active_settings_menu.call("show_web_search_error", web_search_error_text)
			return
		if str(message.get("id", "")).begins_with("skill-"):
			var skill_error_text: String = "Skill operation failed"
			var skill_error_value: Variant = message.get("error", {})
			if typeof(skill_error_value) == TYPE_DICTIONARY:
				skill_error_text = str((skill_error_value as Dictionary).get("message", skill_error_text))
			if active_settings_menu != null and is_instance_valid(active_settings_menu):
				active_settings_menu.call("show_skill_error", skill_error_text)
			return
		if str(message.get("id", "")).begins_with("next-step-hints"):
			next_step_hint_request_id = ""
			next_step_hint_anchor_request_id = ""
			return
		if str(message.get("id", "")).begins_with("command-list"):
			slash_commands.clear()
			_hide_slash_command_popup()
			return
		if _handle_guide_response_error(message):
			return
		if str(message.get("id", "")).begins_with("context-popup-info"):
			context_popup_open_after_info = false
		if str(message.get("id", "")).begins_with("session-timeline"):
			timeline_loading_before = false
			timeline_loading_after = false
		if str(message.get("id", "")).begins_with("session-create") and active_queue_message_id > 0:
			pending_chat_text = ""
			_finish_active_queue_message(false, MESSAGE_QUEUE_STATUS_FAILED)
			_process_message_queue()
		if str(message.get("id", "")).begins_with("session-recover-open"):
			pending_recovery_status_after_session_open = false
			restore_session_after_reconnect_id = ""
			_upsert_connection_status_entry(
				"warning",
				"连接已恢复",
				"后端已重新连接，但当前会话恢复失败。可以手动从会话列表重新打开。"
			)
			connection_status_entry_id = ""
			return
		if _handle_stale_approval_response(message):
			return
		if str(message.get("id", "")) == active_stream_id:
			_show_response_error(message)
			file_edit_controller.set_active_session_id(active_session_id)
			file_edit_controller.complete_stream(active_assistant_entry_id)
			if active_queue_message_id > 0:
				_finish_active_queue_message(false, MESSAGE_QUEUE_STATUS_FAILED)
			active_stream_id = ""
			active_stream_request_id = ""
			active_stream_started_at_utc = ""
			active_stream_status_code = ""
			active_assistant_item = null
			active_assistant_entry_id = ""
			active_assistant_text = ""
			file_edit_controller.clear_active_batches()
			_clear_paused_stream_context()
			_set_streaming_state(false)
			_process_message_queue()
		else:
			_show_background_context_viewer()
			_show_response_error(message)
		return

	var result: Variant = message.get("result", {})
	if typeof(result) != TYPE_DICTIONARY:
		return

	var result_dictionary: Dictionary = result as Dictionary
	var response_id: String = str(message.get("id", ""))
	if response_id.begins_with("web-search-settings"):
		_apply_web_search_settings_status(result_dictionary)
		return
	var applied_workbench_snapshot: bool = _apply_workbench_from_result(result_dictionary)
	if response_id.begins_with("session-workbench") and applied_workbench_snapshot:
		return
	var applied_message_queue_snapshot: bool = _apply_message_queue_snapshot_from_result(result_dictionary)
	if response_id.begins_with("message-queue") and applied_message_queue_snapshot:
		_process_message_queue()
		return
	if response_id.begins_with("client-hello"):
		var compatibility_value: Variant = result_dictionary.get("pluginCompatibility", {})
		if typeof(compatibility_value) == TYPE_DICTIONARY:
			var compatibility: Dictionary = compatibility_value as Dictionary
			if not bool(compatibility.get("accepted", true)):
				var minimum_protocol: int = int(compatibility.get("minProtocolVersion", 0))
				var maximum_protocol: int = int(compatibility.get("maxProtocolVersion", 0))
				backend_connection_controller.shutdown()
				_show_backend_startup_error(
					"Incompatible Daedalus plugin",
					"Plugin protocol %d is not supported by this backend (supported: %d-%d). Upgrade Daedalus Studio to install the matching plugin and backend." % [
						PLUGIN_PROTOCOL_VERSION,
						minimum_protocol,
						maximum_protocol
					]
				)
				return
		var connection_value: Variant = result_dictionary.get("connection", {})
		if typeof(connection_value) == TYPE_DICTIONARY:
			var connection_dictionary: Dictionary = connection_value as Dictionary
			connected_workspace_id = str(connection_dictionary.get("workspaceId", connected_workspace_id)).strip_edges()
		workspace_ready = not connected_workspace_id.is_empty()
		_update_connection_identity_tooltip()
		_complete_workspace_initialization()
		return
	if _handle_attachment_image_save_response(response_id, true, result_dictionary):
		return
	if file_edit_controller.handle_batch_response(str(message.get("id", "")), true, result_dictionary):
		return
	if _handle_plan_response(response_id, result_dictionary):
		return
	if _handle_active_chat_response_completion(response_id, result_dictionary):
		return
	if result_dictionary.has("commands"):
		_apply_slash_command_list_response(result_dictionary)
	elif result_dictionary.has("skills") and result_dictionary.has("revision"):
		_apply_skill_list_response(result_dictionary)
		if response_id.begins_with("skill-update") and active_settings_menu != null and is_instance_valid(active_settings_menu):
			active_settings_menu.call("close_skill_editor")
	elif result_dictionary.has("content") and result_dictionary.has("ref") and response_id.begins_with("skill-get"):
		var edit_ref: String = str(result_dictionary.get("ref", ""))
		var edit_name: String = edit_ref
		for metadata: Dictionary in skill_summaries:
			if str(metadata.get("ref", "")) == edit_ref:
				edit_name = str(metadata.get("name", edit_ref))
				break
		if active_settings_menu != null and is_instance_valid(active_settings_menu):
			active_settings_menu.call("show_skill_editor", edit_ref, edit_name, str(result_dictionary.get("content", "")))
	elif bool(result_dictionary.get("nextStepHints", false)):
		_apply_next_step_hints_response(str(message.get("id", "")), result_dictionary)
	elif result_dictionary.has("customMcpServers"):
		_apply_mcp_config_response(result_dictionary)
	elif bool(result_dictionary.get("guideAdded", false)) or bool(result_dictionary.get("guideUpdated", false)):
		_apply_guide_upsert_response(result_dictionary)
	elif bool(result_dictionary.get("guideDeleted", false)):
		_apply_guide_delete_response(result_dictionary)
	elif result_dictionary.has("archivedSessions"):
		if result_dictionary.has("sessions") and result_dictionary.has("workspaces"):
			_apply_session_browser_snapshot(result_dictionary)
		else:
			_update_archived_session_list(result_dictionary)
	elif result_dictionary.has("workspaces"):
		_update_workspace_list(result_dictionary)
	elif result_dictionary.has("sessions"):
		_update_session_list(result_dictionary)
	elif result_dictionary.has("keyStorage") and result_dictionary.has("configured"):
		_apply_provider_config_status(result_dictionary)
	elif result_dictionary.has("schemaVersion") and result_dictionary.has("prompt"):
		_apply_user_prompt_config(result_dictionary)
	elif result_dictionary.has("models") and result_dictionary.has("provider") and result_dictionary.has("stale"):
		_apply_provider_models_list_response(result_dictionary)
	elif result_dictionary.has("id") and result_dictionary.has("title") and result_dictionary.has("createdAt"):
		_apply_session_metadata(result_dictionary)
		_clear_chat_items()
		_refresh_session_and_archive_lists()
		if not pending_clipboard_image_payload.is_empty():
			var next_clipboard_image_payload: Dictionary = pending_clipboard_image_payload.duplicate(true)
			pending_clipboard_image_payload.clear()
			_save_clipboard_image_attachment(next_clipboard_image_payload)

		if not pending_chat_text.is_empty():
			var next_message: String = pending_chat_text
			var next_additional_context: Array[Dictionary] = additional_context_controller.clone_contexts(pending_chat_additional_context)
			pending_chat_text = ""
			pending_chat_additional_context.clear()
			if not _send_chat_text(next_message, "", next_additional_context) and active_queue_message_id > 0:
				_finish_active_queue_message(false, MESSAGE_QUEUE_STATUS_FAILED)
				_process_message_queue()
	elif bool(result_dictionary.get("opened", false)) and str(message.get("id", "")).begins_with("session-recover-open"):
		_handle_recovered_session_open(result_dictionary)
	elif bool(result_dictionary.get("opened", false)):
		var metadata: Variant = result_dictionary.get("metadata", {})
		if typeof(metadata) == TYPE_DICTIONARY:
			_apply_session_metadata(metadata as Dictionary)
		_clear_chat_items()
		_show_background_context_viewer()
		_render_timeline_blocks(result_dictionary.get("timelineBlocks", []), result_dictionary)
		_sync_pending_guides_from_result(result_dictionary)
		_apply_message_queue_snapshot_from_result(result_dictionary)
		_apply_latest_workflow_snapshot(result_dictionary)
		_refresh_session_and_archive_lists()
		_send_request(RPC_METHODS.SESSION_INFO, {}, "session-info")
	elif bool(result_dictionary.get("timeline", false)):
		if response_id.begins_with("session-timeline-after"):
			_append_next_session_timeline(result_dictionary)
		else:
			_prepend_session_timeline(result_dictionary)
	elif bool(result_dictionary.get("paused", false)) and str(result_dictionary.get("approvalId", "")).length() > 0:
		active_stream_id = ""
		active_stream_request_id = ""
		active_stream_started_at_utc = ""
		active_stream_status_code = ""
		active_assistant_item = null
		active_assistant_entry_id = ""
		active_assistant_text = ""
		_set_streaming_state(false)
		_show_approval_dialog(result_dictionary)
	elif bool(result_dictionary.get("configured", false)) and result_dictionary.has("provider"):
		_update_send_state()
	elif bool(result_dictionary.get("configured", false)) and result_dictionary.has("godotProjectPath"):
		connected_workspace_id = str(result_dictionary.get("workspaceId", connected_workspace_id)).strip_edges()
		_update_connection_identity_tooltip()
	elif result_dictionary.has("editorInstance"):
		var editor_instance_value: Variant = result_dictionary.get("editorInstance", {})
		if typeof(editor_instance_value) == TYPE_DICTIONARY:
			var editor_instance_dictionary: Dictionary = editor_instance_value as Dictionary
			editor_bridge_controller.set_editor_instance_id(str(editor_instance_dictionary.get("editorInstanceId", "")))
			connected_workspace_id = str(editor_instance_dictionary.get("workspaceId", connected_workspace_id)).strip_edges()
			_update_connection_identity_tooltip()
	elif result_dictionary.has("mode") and result_dictionary.has("pendingApprovals"):
		_apply_approval_mode_status(result_dictionary)
		if int(result_dictionary.get("pendingApprovals", 0)) > 0 and not approval_dialog.visible:
			_send_request(RPC_METHODS.APPROVAL_LIST, {}, "approval-list")
	elif result_dictionary.has("contextWindowTokens"):
		_apply_approval_mode_status(result_dictionary)
		_update_context_length(result_dictionary)
		if context_popup_open_after_info:
			context_popup_open_after_info = false
			_show_context_popup_menu()
		if int(result_dictionary.get("pendingApprovals", 0)) > 0 and not approval_dialog.visible:
			_send_request(RPC_METHODS.APPROVAL_LIST, {}, "approval-list")
	elif result_dictionary.has("pending") and result_dictionary.has("mode"):
		_apply_approval_mode_status(result_dictionary)
		_show_first_pending_approval(result_dictionary)
	elif bool(result_dictionary.get("saved", false)):
		_refresh_session_and_archive_lists()
	elif bool(result_dictionary.get("archived", false)):
		_apply_archived_session_response(result_dictionary)
	elif bool(result_dictionary.get("restored", false)):
		_refresh_session_and_archive_lists()
	elif bool(result_dictionary.get("deletedArchived", false)):
		_remove_archived_session(str(result_dictionary.get("sessionId", "")))
	elif bool(result_dictionary.get("approved", false)) or bool(result_dictionary.get("rejected", false)):
		var was_rejected: bool = bool(result_dictionary.get("rejected", false))
		pending_approval_id = ""
		_update_send_state()
		if was_rejected and active_queue_message_id > 0:
			_finish_active_queue_message(false, MESSAGE_QUEUE_STATUS_REJECTED)
			_process_message_queue()
		_send_request(RPC_METHODS.SESSION_INFO, {}, "session-info")


func _handle_event(message: Dictionary) -> void:
	var event_name: String = str(message.get("event", ""))
	var event_id: String = str(message.get("requestId", ""))
	var event_session_id: String = str(message.get("sessionId", ""))
	if not event_session_id.is_empty() and not active_session_id.is_empty() and event_session_id != active_session_id:
		return

	var data: Variant = message.get("data", {})
	if typeof(data) != TYPE_DICTIONARY:
		return

	var data_dictionary: Dictionary = data as Dictionary
	if event_name == "session.workbench.updated":
		_apply_workbench_from_result(data_dictionary)
		return
	if event_name == "message.queue.updated":
		_apply_message_queue_snapshot_from_result(data_dictionary)
		if active_stream_id.is_empty():
			_process_message_queue()
		return
	if _is_plan_message_event(event_name, data_dictionary) and active_stream_id.is_empty() and not event_id.is_empty():
		_begin_plan_followup_stream(event_id, "")
	if event_name == "agent.run.state":
		_handle_agent_run_state(data_dictionary, event_session_id, int(message.get("sequence", 0)))
	elif event_name == "agent.message.delta":
		_ensure_active_assistant_item()
		var delta_text: String = str(data_dictionary.get("text", ""))
		active_assistant_text += delta_text
		pending_assistant_delta_text += delta_text
		if active_workflow_id.is_empty():
			_update_todo_list_from_text(active_assistant_text)
		_schedule_assistant_delta_flush()
	elif event_name == "agent.summary.started":
		_begin_active_assistant_summary(data_dictionary)
	elif event_name == "agent.status":
		_append_assistant_status_event(data_dictionary)
	elif event_name == "agent.message.done":
		_complete_active_chat_stream()
	elif event_name == "agent.thinking.delta":
		_append_thinking_event(str(data_dictionary.get("text", "")))
	elif event_name == "agent.thinking.done":
		var should_follow_bottom: bool = _should_follow_timeline_updates()
		_flush_pending_thinking_delta()
		if not active_assistant_entry_id.is_empty():
			_append_assistant_thinking_to_timeline(active_assistant_entry_id, "", true)
		if active_thinking_item != null:
			active_thinking_item.call("finish_thinking")
			_schedule_timeline_render(should_follow_bottom)
		active_thinking_item = null
		active_thinking_entry_id = ""
	elif event_name == "agent.tool.call":
		_add_tool_event(_normalize_agent_tool_event_data(event_name, data_dictionary))
	elif event_name == "agent.tool.progress":
		_append_tool_event(_normalize_agent_tool_event_data(event_name, data_dictionary))
	elif event_name == "agent.tool.result":
		var normalized_tool_result: Dictionary = _normalize_agent_tool_event_data(event_name, data_dictionary)
		file_edit_controller.collect_active_batch(normalized_tool_result)
		_append_tool_event(normalized_tool_result)
	elif event_name == "agent.tool.error":
		_append_tool_event(_normalize_agent_tool_event_data(event_name, data_dictionary))
	elif event_name == "agent.tool.approval_required":
		var approval_tool_event: Dictionary = _normalize_agent_tool_event_data(event_name, data_dictionary)
		_add_tool_event(approval_tool_event)
		_show_approval_dialog(approval_tool_event)
	elif event_name == "agent.tool.approved" or event_name == "agent.tool.rejected":
		var tool_was_rejected: bool = event_name == "agent.tool.rejected"
		pending_approval_id = ""
		approval_dialog.visible = false
		_update_send_state()
		if tool_was_rejected:
			_clear_paused_stream_context()
			if active_queue_message_id > 0:
				_finish_active_queue_message(false, MESSAGE_QUEUE_STATUS_REJECTED)
				_process_message_queue()
		elif active_queue_message_id > 0:
			_set_queue_message_status(active_queue_message_id, MESSAGE_QUEUE_STATUS_SENDING)
	elif event_name.begins_with("plan."):
		_handle_plan_event(event_name, event_id, data_dictionary)
	elif event_name == "guide.applied":
		_apply_guide_applied_event(data_dictionary)
	elif event_name == "guide.deleted":
		_apply_guide_deleted_event(data_dictionary)
	elif event_name == "session.renamed":
		_apply_session_renamed_event(data_dictionary)
	elif event_name == "mcp.config.updated":
		_apply_mcp_config_response(data_dictionary)
		var mcp_error_text: String = str(data_dictionary.get("error", "")).strip_edges()
		if not mcp_error_text.is_empty() and active_settings_menu != null and is_instance_valid(active_settings_menu):
			active_settings_menu.call("show_mcp_error", mcp_error_text)
	elif event_name == "skill.catalog.changed":
		_load_skills()
	elif event_name == "editor.tool.requested":
		editor_bridge_controller.handle_tool_requested(data_dictionary)


func _handle_agent_run_state(run_state: Dictionary, event_session_id: String, event_sequence: int) -> void:
	var stage: String = str(run_state.get("stage", ""))
	var run_id: String = str(run_state.get("runId", ""))
	var revision: int = int(run_state.get("revision", -1))
	var sequence_session_id: String = event_session_id
	if sequence_session_id.is_empty():
		sequence_session_id = str(run_state.get("sessionId", ""))
	if not run_id.is_empty() and revision <= agent_run_revisions_by_id.get(run_id, -1):
		return
	if not sequence_session_id.is_empty() and event_sequence <= agent_run_sequences_by_session_id.get(sequence_session_id, -1):
		return
	if not run_id.is_empty():
		agent_run_revisions_by_id[run_id] = revision
	if not sequence_session_id.is_empty():
		agent_run_sequences_by_session_id[sequence_session_id] = event_sequence
	if not run_id.is_empty():
		active_workflow_id = run_id

	var todo_value: Variant = run_state.get("todo", null)
	if typeof(todo_value) == TYPE_DICTIONARY:
		_apply_workflow_todo_snapshot(todo_value as Dictionary)
	elif todo_value == null:
		_clear_todo_items()

	if stage == "awaiting_approval" or stage == "awaiting_tool_budget":
		var paused_request_id: String = active_stream_request_id
		_save_paused_stream_context()
		_flush_pending_assistant_delta()
		_set_streaming_state(false)
		if stage == "awaiting_approval" and active_queue_message_id > 0:
			_set_queue_message_status(active_queue_message_id, MESSAGE_QUEUE_STATUS_APPROVAL)
		_request_next_step_hints(paused_request_id, "paused")
		return

	if stage == "completed":
		_complete_active_chat_stream()
		return
	if stage == "cancelled":
		_stop_active_stream_locally(false)
		return
	if stage == "failed":
		var terminal_value: Variant = run_state.get("terminal", {})
		var terminal: Dictionary = terminal_value as Dictionary if typeof(terminal_value) == TYPE_DICTIONARY else {}
		_append_assistant_status_event({
			"status": "error",
			"title": "Backend returned an error",
			"details": str(terminal.get("message", "The run failed.")),
			"code": "agent_run_error"
		})
		_complete_active_chat_stream()
		return
	if stage == "interrupted":
		_append_assistant_status_event({
			"status": "warning",
			"title": "Run interrupted",
			"details": "The backend stopped before this run reached a terminal state. Retry it from Daedalus Studio.",
			"code": "agent_run_interrupted"
		})
		_stop_active_stream_locally(false)
		return

	_set_streaming_state(true)

# --- next_step_controller.gd ---

func _is_global_event(event_name: String) -> bool:
	return event_name == "tool.approved" or event_name == "tool.rejected" or event_name == "tool.approval_required" or event_name == "ai.paused" or event_name == "ai.cancelled" or event_name == "session.renamed" or event_name == "editor.tool.requested" or event_name == "mcp.config.updated" or event_name.begins_with("skill.") or event_name.begins_with("workflow.") or event_name.begins_with("guide.") or event_name.begins_with("message.queue.") or event_name.begins_with("session.workbench.") or event_name.begins_with("agent.") or event_name.begins_with("plan.")


func _normalize_agent_tool_event_data(event_name: String, event_data: Dictionary) -> Dictionary:
	if not event_name.begins_with("agent.tool."):
		return event_data

	var normalized_data: Dictionary = event_data.duplicate(true)
	normalized_data["type"] = event_name.replace("agent.tool.", "tool.")
	return normalized_data


func _handle_active_chat_response_completion(response_id: String, result_dictionary: Dictionary) -> bool:
	if response_id != active_stream_id:
		return false
	if not _is_final_active_chat_response(result_dictionary):
		return false

	_complete_active_chat_stream()
	return true


func _is_final_active_chat_response(result_dictionary: Dictionary) -> bool:
	return result_dictionary.has("planId") or result_dictionary.has("text") or result_dictionary.has("context")


func _complete_active_chat_stream() -> void:
	if active_stream_id.is_empty() and active_stream_request_id.is_empty() and active_assistant_entry_id.is_empty():
		return

	var should_follow_bottom: bool = _should_follow_timeline_updates()
	var completed_at_utc: String = MAIN_HELPERS.get_utc_timestamp()
	var completed_request_id: String = active_stream_request_id
	var completed_status_code: String = active_stream_status_code
	_flush_pending_assistant_delta()
	if not active_assistant_entry_id.is_empty():
		_set_timeline_entry_times(active_assistant_entry_id, active_stream_started_at_utc, completed_at_utc)
	if active_assistant_item != null:
		active_assistant_item.call("finish_message", active_stream_started_at_utc, completed_at_utc)
	file_edit_controller.set_active_session_id(active_session_id)
	file_edit_controller.complete_stream(active_assistant_entry_id)
	_schedule_timeline_render(should_follow_bottom)
	active_assistant_item = null
	active_assistant_entry_id = ""
	active_stream_id = ""
	active_stream_request_id = ""
	active_stream_started_at_utc = ""
	active_stream_status_code = ""
	active_assistant_text = ""
	_clear_paused_stream_context()
	_set_streaming_state(false)
	_send_request(RPC_METHODS.SESSION_SAVE, {}, "session-save")
	_send_request(RPC_METHODS.SESSION_INFO, {}, "session-info")
	_finish_active_queue_message(true)
	if completed_status_code != "plan" and not _has_pending_queued_messages():
		_request_next_step_hints(completed_request_id, "done")
	_process_message_queue()


func _handle_plan_response(response_id: String, result_dictionary: Dictionary) -> bool:
	if pending_plan_detail_requests.has(response_id):
		var fallback_data: Dictionary = pending_plan_detail_requests.get(response_id, {}) as Dictionary
		pending_plan_detail_requests.erase(response_id)
		var title_text: String = str(result_dictionary.get("title", fallback_data.get("title", "Plan"))).strip_edges()
		var markdown_text: String = str(result_dictionary.get("markdown", fallback_data.get("markdown", ""))).strip_edges()
		_open_plan_viewer(title_text, markdown_text)
		return true
	if bool(result_dictionary.get("planApproved", false)):
		return true
	if result_dictionary.has("planId") and (response_id.begins_with("plan-clarify") or response_id.begins_with("plan-revise")):
		return true
	return false


func _handle_plan_response_error(response_id: String) -> bool:
	if not pending_plan_detail_requests.has(response_id):
		return false

	var fallback_data: Dictionary = pending_plan_detail_requests.get(response_id, {}) as Dictionary
	pending_plan_detail_requests.erase(response_id)
	_open_plan_viewer(
		str(fallback_data.get("title", "Plan")),
		str(fallback_data.get("markdown", ""))
	)
	return true


func _handle_plan_event(event_name: String, event_id: String, event_data: Dictionary) -> void:
	if active_stream_id.is_empty() and not event_id.is_empty():
		_begin_plan_followup_stream(event_id, "", str(event_data.get("planId", "")))
	if active_stream_request_id.is_empty() and not event_id.is_empty():
		active_stream_request_id = event_id
	if active_stream_started_at_utc.is_empty():
		active_stream_started_at_utc = MAIN_HELPERS.get_utc_timestamp()

	var plan_id: String = str(event_data.get("planId", "")).strip_edges()
	if not plan_id.is_empty() and plan_assistant_entry_ids_by_plan_id.has(plan_id):
		var mapped_entry_id: String = str(plan_assistant_entry_ids_by_plan_id.get(plan_id, ""))
		if not mapped_entry_id.is_empty() and _find_timeline_entry_index(mapped_entry_id) >= 0:
			active_assistant_entry_id = mapped_entry_id
			active_assistant_item = rendered_entry_nodes.get(active_assistant_entry_id, null) as Node

	if event_name == "plan.clarification.required":
		active_stream_status_code = "plan"
		_append_assistant_status_event({
			"status": "message",
			"title": "需要澄清计划",
			"details": str(event_data.get("question", "")),
			"code": "plan",
			"iconUid": PLAN_CLARIFICATION_ICON_UID,
			"planId": plan_id
		})
		_remember_plan_assistant_entry(plan_id)
		_show_clarification_dialog(event_data)
	elif event_name == "plan.generated" or event_name == "plan.revised":
		active_stream_status_code = "plan"
		_append_plan_preview_to_active_assistant(event_data)
		_remember_plan_assistant_entry(plan_id)
		_show_plan_approval_dialog(event_data)
	elif event_name == "plan.execution.started":
		_start_plan_execution_stream(event_data)
	elif event_name == "plan.error":
		_append_assistant_status_event({
			"status": "error",
			"title": "计划模式错误",
			"details": str(event_data.get("message", "Unknown plan error")),
			"code": str(event_data.get("code", "plan_error"))
		})
	elif event_name == "plan.approved":
		clarification_dialog.hide()
		plan_approval_dialog.hide()
		_sync_plan_overlay_input_visibility()


func _remember_plan_assistant_entry(plan_id: String) -> void:
	var normalized_plan_id: String = plan_id.strip_edges()
	if normalized_plan_id.is_empty() or active_assistant_entry_id.is_empty():
		return

	plan_assistant_entry_ids_by_plan_id[normalized_plan_id] = active_assistant_entry_id


func _show_clarification_dialog(event_data: Dictionary) -> void:
	var plan_id: String = str(event_data.get("planId", "")).strip_edges()
	var question_text: String = str(event_data.get("question", "")).strip_edges()
	var replies_value: Variant = event_data.get("recommendedReplies", [])
	var replies: Array = replies_value as Array if typeof(replies_value) == TYPE_ARRAY else []
	if plan_id.is_empty() or question_text.is_empty():
		return

	plan_approval_dialog.hide()
	clarification_dialog.call("setup", question_text, replies, plan_id)
	_sync_plan_overlay_input_visibility()


func _show_plan_approval_dialog(event_data: Dictionary) -> void:
	var plan_id: String = str(event_data.get("planId", "")).strip_edges()
	if plan_id.is_empty():
		return

	clarification_dialog.hide()
	plan_approval_dialog.call("setup", plan_id, str(event_data.get("title", "Plan")))
	_sync_plan_overlay_input_visibility()


func _append_plan_preview_to_active_assistant(event_data: Dictionary) -> void:
	_show_background_context_viewer()
	var should_follow_bottom: bool = _should_follow_timeline_updates()
	_flush_pending_assistant_delta()
	_ensure_active_assistant_item()
	var plan_part: Dictionary = _create_plan_body_part(event_data)
	if plan_part.is_empty() or active_assistant_entry_id.is_empty():
		return

	var index: int = _find_timeline_entry_index(active_assistant_entry_id)
	if index >= 0:
		var entry: Dictionary = timeline_entries[index]
		var body_parts: Array = entry.get("body_parts", []) as Array
		body_parts.append(plan_part)
		entry["body_parts"] = body_parts
		entry["height_actual"] = 0.0
		timeline_entries[index] = entry
		_remember_plan_entry_from_body_parts(active_assistant_entry_id, body_parts)
		_mark_timeline_height_dirty(index)

	active_assistant_item = rendered_entry_nodes.get(active_assistant_entry_id, null) as Node
	if active_assistant_item != null:
		active_assistant_item.call("add_plan_preview", plan_part)
		_schedule_timeline_measure()
		_scroll_to_bottom_if_following(should_follow_bottom)
		return

	_schedule_timeline_render(should_follow_bottom)


func _create_plan_body_part(event_data: Dictionary) -> Dictionary:
	var plan_id: String = str(event_data.get("planId", "")).strip_edges()
	if plan_id.is_empty():
		return {}

	return {
		"type": "plan",
		"planId": plan_id,
		"title": str(event_data.get("title", "Plan")),
		"status": str(event_data.get("status", "")),
		"previewMarkdown": str(event_data.get("previewMarkdown", event_data.get("markdown", "")))
	}


func _on_plan_clarification_submitted(plan_id: String, reply: String) -> void:
	if plan_id.is_empty() or reply.strip_edges().is_empty():
		return

	_sync_plan_overlay_input_visibility()
	var clarify_request_id: String = _send_request(RPC_METHODS.PLAN_CLARIFY, {
		"planId": plan_id,
		"reply": reply
	}, "plan-clarify")
	if not clarify_request_id.is_empty():
		_begin_plan_followup_stream(clarify_request_id, reply, plan_id)


func _on_plan_approved(plan_id: String) -> void:
	if plan_id.is_empty():
		return

	_sync_plan_overlay_input_visibility()
	_send_request(RPC_METHODS.PLAN_APPROVE, {
		"planId": plan_id
	}, "plan-approve")


func _on_plan_revision_requested(plan_id: String, feedback: String) -> void:
	if plan_id.is_empty() or feedback.strip_edges().is_empty():
		return

	_sync_plan_overlay_input_visibility()
	var revise_request_id: String = _send_request(RPC_METHODS.PLAN_REVISE, {
		"planId": plan_id,
		"feedback": feedback
	}, "plan-revise")
	if not revise_request_id.is_empty():
		_begin_plan_followup_stream(revise_request_id, feedback, plan_id)


func _is_plan_message_event(event_name: String, event_data: Dictionary) -> bool:
	if event_name != "agent.message.delta" and event_name != "agent.message.done":
		return false

	return str(event_data.get("mode", "")) == "plan"


func _begin_plan_followup_stream(plan_request_id: String, _user_text: String, plan_id: String = "") -> void:
	if plan_request_id.is_empty() or not active_stream_id.is_empty():
		return

	_show_background_context_viewer()
	var normalized_plan_id: String = plan_id.strip_edges()
	var existing_entry_id: String = str(plan_assistant_entry_ids_by_plan_id.get(normalized_plan_id, ""))
	if not existing_entry_id.is_empty() and _find_timeline_entry_index(existing_entry_id) >= 0:
		active_assistant_entry_id = existing_entry_id
		active_assistant_item = rendered_entry_nodes.get(active_assistant_entry_id, null) as Node
	else:
		active_assistant_item = null
		active_assistant_entry_id = ""
	active_thinking_entry_id = ""
	active_assistant_text = _get_timeline_entry_content(active_assistant_entry_id)
	file_edit_controller.clear_active_batches()
	_clear_paused_stream_context()
	_clear_todo_items()

	active_stream_id = plan_request_id
	active_stream_request_id = plan_request_id
	active_stream_started_at_utc = MAIN_HELPERS.get_utc_timestamp()
	active_stream_status_code = "plan"
	var should_follow_bottom: bool = _should_follow_timeline_updates()
	if active_assistant_entry_id.is_empty():
		active_assistant_entry_id = _append_timeline_entry(
			"assistant",
			active_stream_request_id,
			"",
			"",
			{ "started_at_utc": active_stream_started_at_utc }
		)
		_remember_plan_assistant_entry(normalized_plan_id)
	else:
		_set_timeline_entry_times(active_assistant_entry_id, active_stream_started_at_utc, "")
		_clear_timeline_entry_completion_time(active_assistant_entry_id)
	_schedule_timeline_render(should_follow_bottom)
	_set_streaming_state(true)


func _on_plan_details_requested(plan_id: String, fallback_markdown: String) -> void:
	if plan_id.strip_edges().is_empty():
		_open_plan_viewer("Plan", fallback_markdown)
		return
	if active_session_id.is_empty() or not _is_socket_open():
		_open_plan_viewer("Plan", fallback_markdown)
		return

	var params: Dictionary[String, Variant] = {
		"sessionId": active_session_id,
		"planId": plan_id
	}
	var detail_request_id: String = _send_request(RPC_METHODS.PLAN_GET, params, "plan-get")
	if detail_request_id.is_empty():
		_open_plan_viewer("Plan", fallback_markdown)
		return

	pending_plan_detail_requests[detail_request_id] = {
		"title": "Plan",
		"markdown": fallback_markdown
	}


func _open_plan_viewer(title_text: String, markdown_text: String) -> void:
	var plan_viewer: AcceptDialog = PLAN_VIEWER_SCENE.instantiate() as AcceptDialog
	add_child(plan_viewer)
	plan_viewer.call("setup", title_text, markdown_text)
	plan_viewer.popup_centered_ratio()


func _start_plan_execution_stream(event_data: Dictionary) -> void:
	var execution_request_id: String = str(event_data.get("executionRequestId", "")).strip_edges()
	if execution_request_id.is_empty():
		return

	active_assistant_item = null
	active_assistant_entry_id = ""
	active_thinking_entry_id = ""
	active_assistant_text = ""
	file_edit_controller.clear_active_batches()
	_clear_paused_stream_context()
	_clear_todo_items()

	active_stream_id = execution_request_id
	active_stream_request_id = execution_request_id
	active_stream_started_at_utc = MAIN_HELPERS.get_utc_timestamp()
	active_stream_status_code = ""
	var title_text: String = str(event_data.get("title", "Plan")).strip_edges()
	var user_text: String = "执行已批准计划" if title_text.is_empty() else "执行已批准计划：%s" % title_text
	var should_follow_bottom: bool = _should_follow_timeline_updates()
	_append_timeline_entry("user", active_stream_request_id, user_text, "", { "sent_at_utc": active_stream_started_at_utc })
	active_assistant_entry_id = _append_timeline_entry(
		"assistant",
		active_stream_request_id,
		"",
		"",
		{ "started_at_utc": active_stream_started_at_utc }
	)
	_schedule_timeline_render(should_follow_bottom)
	_set_streaming_state(true)


func _sync_plan_overlay_input_visibility() -> void:
	if text_edit == null:
		return

	var overlay_visible: bool = (
		clarification_dialog != null and clarification_dialog.visible
	) or (
		plan_approval_dialog != null and plan_approval_dialog.visible
	)
	text_edit.visible = not overlay_visible
	_update_send_state()


func _request_next_step_hints(anchor_request_id: String, trigger: String) -> void:
	if not next_step_hints_enabled:
		return
	if not _is_socket_open() or active_session_id.is_empty():
		return
	if not next_step_hint_request_id.is_empty():
		return

	var params: Dictionary[String, Variant] = {
		"sessionId": active_session_id,
		"trigger": trigger,
		"maxHints": 3
	}
	if not anchor_request_id.is_empty():
		params["anchorRequestId"] = anchor_request_id

	next_step_hint_request_id = _send_request(RPC_METHODS.AI_NEXT_STEP_HINTS, params, "next-step-hints")
	next_step_hint_anchor_request_id = anchor_request_id
	if next_step_hint_request_id.is_empty():
		next_step_hint_anchor_request_id = ""


func _apply_next_step_hints_response(response_id: String, result_dictionary: Dictionary) -> void:
	if response_id != next_step_hint_request_id:
		return

	next_step_hint_request_id = ""
	next_step_hint_anchor_request_id = ""
	_apply_next_step_hints_state(result_dictionary.get("hints", []))


func _apply_next_step_hints_state(hints_value: Variant) -> void:
	_clear_next_step_hint_entries()
	if typeof(hints_value) != TYPE_ARRAY:
		text_edit.placeholder_text = ""
		return

	var hints: Array = hints_value as Array
	if hints.is_empty():
		text_edit.placeholder_text = ""
		return

	for index: int in range(hints.size()):
		var hint_value: Variant = hints[index]
		if typeof(hint_value) != TYPE_DICTIONARY:
			continue

		var hint: Dictionary = hint_value as Dictionary
		var hint_title: String = str(hint.get("title", "下一步")).strip_edges()
		var hint_message: String = str(hint.get("message", "")).strip_edges()
		if hint_message.is_empty():
			continue

		if index == 0:
			text_edit.placeholder_text = hint_message
			continue

		var action_id: String = "%s%d-%d" % [NEXT_STEP_HINT_ACTION_PREFIX, Time.get_ticks_msec(), index]
		next_step_hints_by_action_id[action_id] = hint_message
		var entry_id: String = _append_timeline_entry(
			"status",
			"",
			hint_message,
			"next-step-hint-%d-%d" % [Time.get_ticks_msec(), index],
			{
				"status": "message",
				"title": "下一步提示：%s" % hint_title,
				"detail": hint_message,
				"action_label": "Use",
				"action_id": action_id
			}
		)
		next_step_hint_entry_ids.append(entry_id)

	_schedule_timeline_render(_should_follow_timeline_updates())


func _clear_next_step_hint_entries() -> void:
	text_edit.placeholder_text = ""
	next_step_hints_by_action_id.clear()
	if not applying_workbench_snapshot:
		next_step_hints_signature = ""
	for entry_id: String in next_step_hint_entry_ids:
		var entry_index: int = _find_timeline_entry_index(entry_id)
		if entry_index >= 0:
			timeline_entries.remove_at(entry_index)
		var rendered_node_value: Variant = rendered_entry_nodes.get(entry_id, null)
		if rendered_node_value is Node:
			(rendered_node_value as Node).queue_free()
		rendered_entry_nodes.erase(entry_id)
		rendered_entry_indices.erase(entry_id)

	next_step_hint_entry_ids.clear()
	_rebuild_timeline_index_cache()
	_rebuild_timeline_height_cache()
	_schedule_timeline_render(_should_follow_timeline_updates())


func _handle_guide_response_error(message: Dictionary) -> bool:
	var response_id: String = str(message.get("id", ""))
	if not (response_id.begins_with("guide-add") or response_id.begins_with("guide-update") or response_id.begins_with("guide-delete")):
		return false

	for index: int in range(manual_guides.size()):
		var manual_guide: Dictionary = manual_guides[index]
		if str(manual_guide.get("pending_request_id", "")) != response_id:
			continue

		if response_id.begins_with("guide-delete"):
			manual_guide["status"] = GUIDE_STATUS_PENDING
		else:
			manual_guide["status"] = GUIDE_STATUS_FAILED
		manual_guide["pending_request_id"] = ""
		manual_guides[index] = manual_guide
		break

	_render_message_panel()
	_show_response_error(message)
	return true


func _apply_guide_upsert_response(result_dictionary: Dictionary) -> void:
	var guide_value: Variant = result_dictionary.get("guide", {})
	if typeof(guide_value) != TYPE_DICTIONARY:
		return

	var guide_dictionary: Dictionary = guide_value as Dictionary
	var guide_id: String = str(guide_dictionary.get("guideId", ""))
	var client_guide_id: String = str(guide_dictionary.get("clientGuideId", ""))
	var guide_index: int = _find_manual_guide_index_by_backend_id(guide_id, client_guide_id)
	var manual_guide: Dictionary
	if guide_index >= 0:
		manual_guide = manual_guides[guide_index]
	else:
		manual_guide_next_id += 1
		manual_guide = {
			"local_id": "remote-guide-%d" % manual_guide_next_id,
			"client_guide_id": client_guide_id
		}
		manual_guides.append(manual_guide)
		guide_index = manual_guides.size() - 1

	manual_guide["guide_id"] = guide_id
	manual_guide["client_guide_id"] = client_guide_id
	manual_guide["text"] = str(guide_dictionary.get("text", manual_guide.get("text", "")))
	manual_guide["status"] = GUIDE_STATUS_PENDING
	manual_guide["pending_request_id"] = ""
	manual_guide["updated_at_utc"] = str(guide_dictionary.get("updatedAt", MAIN_HELPERS.get_utc_timestamp()))
	manual_guide["anchor_request_id"] = MAIN_HELPERS.string_or_empty(guide_dictionary.get("anchorRequestId", ""))
	manual_guides[guide_index] = manual_guide
	_render_message_panel()


func _apply_guide_delete_response(result_dictionary: Dictionary) -> void:
	var guide_id: String = str(result_dictionary.get("guideId", ""))
	var guide_index: int = _find_manual_guide_index_by_backend_id(guide_id)
	if guide_index >= 0:
		manual_guides.remove_at(guide_index)
	_render_message_panel()


func _apply_guide_applied_event(data_dictionary: Dictionary) -> void:
	var guide_id: String = str(data_dictionary.get("guideId", ""))
	var client_guide_id: String = str(data_dictionary.get("clientGuideId", ""))
	var guide_index: int = _find_manual_guide_index_by_backend_id(guide_id, client_guide_id)
	if guide_index < 0:
		return

	var manual_guide: Dictionary = manual_guides[guide_index]
	manual_guide["status"] = GUIDE_STATUS_APPLIED
	manual_guide["pending_request_id"] = ""
	manual_guides[guide_index] = manual_guide
	_render_message_panel()


func _apply_guide_deleted_event(data_dictionary: Dictionary) -> void:
	var guide_id: String = str(data_dictionary.get("guideId", ""))
	var client_guide_id: String = str(data_dictionary.get("clientGuideId", ""))
	var guide_index: int = _find_manual_guide_index_by_backend_id(guide_id, client_guide_id)
	if guide_index >= 0:
		manual_guides.remove_at(guide_index)
	_render_message_panel()


func _sync_pending_guides_from_result(result_dictionary: Dictionary) -> void:
	var guides_value: Variant = result_dictionary.get("pendingGuides", [])
	if typeof(guides_value) != TYPE_ARRAY:
		return

	var seen_backend_ids: PackedStringArray = PackedStringArray()
	var guides_array: Array = guides_value as Array
	for guide_value: Variant in guides_array:
		if typeof(guide_value) != TYPE_DICTIONARY:
			continue

		var guide_dictionary: Dictionary = guide_value as Dictionary
		var guide_id: String = str(guide_dictionary.get("guideId", ""))
		if not guide_id.is_empty():
			seen_backend_ids.append(guide_id)
		_apply_guide_upsert_response({ "guide": guide_dictionary })

	for index: int in range(manual_guides.size() - 1, -1, -1):
		var manual_guide: Dictionary = manual_guides[index]
		var guide_id: String = str(manual_guide.get("guide_id", ""))
		var guide_status: StringName = manual_guide.get("status", GUIDE_STATUS_DRAFT) as StringName
		if guide_status == GUIDE_STATUS_DRAFT or guide_id.is_empty():
			continue
		if not seen_backend_ids.has(guide_id):
			manual_guides.remove_at(index)

	_render_message_panel()
	_update_send_state()

# --- session_list_controller.gd ---

# --- session_list_controller.gd ---
func _update_session_list(result: Dictionary) -> void:
	sessions_by_id.clear()
	session_ids_in_order.clear()

	var sessions_value: Variant = result.get("sessions", [])
	if typeof(sessions_value) != TYPE_ARRAY:
		_render_session_list()
		return

	var sessions_array: Array = sessions_value as Array
	for item: Variant in sessions_array:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var metadata: Dictionary = item as Dictionary
		var session_id: String = str(metadata.get("id", ""))
		if session_id.is_empty():
			continue

		metadata = _apply_renamed_session_override(metadata)
		sessions_by_id[session_id] = metadata
		session_ids_in_order.append(session_id)

	_render_session_list()


func _update_archived_session_list(result: Dictionary) -> void:
	archived_sessions_by_id.clear()
	archived_session_ids_in_order.clear()

	var sessions_value: Variant = result.get("archivedSessions", [])
	if typeof(sessions_value) != TYPE_ARRAY:
		_sync_settings_archived_sessions()
		return

	var sessions_array: Array = sessions_value as Array
	for item: Variant in sessions_array:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var metadata: Dictionary = item as Dictionary
		var session_id: String = str(metadata.get("id", ""))
		if session_id.is_empty():
			continue

		archived_sessions_by_id[session_id] = metadata
		archived_session_ids_in_order.append(session_id)

	_sync_settings_archived_sessions()


func _apply_session_browser_snapshot(result: Dictionary) -> void:
	_apply_workspace_snapshot(result)
	_update_session_list(result)
	_update_archived_session_list(result)


func _apply_mcp_config_response(result: Dictionary) -> void:
	custom_mcp_servers.clear()
	var servers_value: Variant = result.get("customMcpServers", [])
	if typeof(servers_value) == TYPE_ARRAY:
		var servers_array: Array = servers_value as Array
		for item: Variant in servers_array:
			if typeof(item) != TYPE_DICTIONARY:
				continue

			custom_mcp_servers.append((item as Dictionary).duplicate(true))

	_sync_settings_mcp_servers()


func _handle_mcp_config_error(message: Dictionary) -> void:
	var error_message: String = "MCP configuration failed"
	var error_value: Variant = message.get("error", {})
	if typeof(error_value) == TYPE_DICTIONARY:
		var error_dictionary: Dictionary = error_value as Dictionary
		error_message = str(error_dictionary.get("message", error_message))

	if active_settings_menu != null and is_instance_valid(active_settings_menu):
		active_settings_menu.call("show_mcp_error", error_message)
		return

	_show_background_context_viewer()
	_show_response_error(message)


func _apply_workspace_snapshot(result: Dictionary) -> void:
	workspaces_by_id.clear()
	workspace_filter_button.clear()
	workspace_filter_button.add_item("All", 0)
	workspace_filter_button.set_item_metadata(0, "")

	var workspaces_value: Variant = result.get("workspaces", [])
	var active_value: String = str(result.get("active", ""))
	if typeof(workspaces_value) == TYPE_ARRAY:
		var workspaces_array: Array = workspaces_value as Array
		for item: Variant in workspaces_array:
			if typeof(item) != TYPE_DICTIONARY:
				continue

			var workspace: Dictionary = item as Dictionary
			var workspace_id: String = str(workspace.get("id", ""))
			if workspace_id.is_empty():
				continue

			workspaces_by_id[workspace_id] = workspace
			var filter_text: String = workspace.get("name", "Workspace")
			if workspace_id == active_value:
				filter_text = "%s" % filter_text
			workspace_filter_button.add_item(filter_text)
			workspace_filter_button.set_item_metadata(workspace_filter_button.get_item_count() - 1, workspace_id)


func _update_workspace_list(result: Dictionary) -> void:
	_apply_workspace_snapshot(result)
	_render_session_list()
	_sync_settings_archived_sessions()


func _render_session_list() -> void:
	session_option_button.clear()
	_clear_session_buttons()

	if session_ids_in_order.is_empty():
		_select_active_session()
		return

	if not selected_workspace_filter.is_empty():
		_render_workspace_group(selected_workspace_filter)
	else:
		var rendered_workspace_ids: PackedStringArray
		for session_id: String in session_ids_in_order:
			var metadata: Dictionary = sessions_by_id.get(session_id, {}) as Dictionary
			var workspace_id: String = str(metadata.get("workspaceId", ""))
			if rendered_workspace_ids.has(workspace_id):
				continue

			rendered_workspace_ids.append(workspace_id)
			_render_workspace_group(workspace_id)

	_select_active_session()


func _render_workspace_group(workspace_id: String) -> void:
	var matching_session_ids: PackedStringArray
	for session_id: String in session_ids_in_order:
		var metadata: Dictionary = sessions_by_id.get(session_id, {}) as Dictionary
		if str(metadata.get("workspaceId", "")) != workspace_id:
			continue
		if not _does_session_match_filters(metadata):
			continue

		matching_session_ids.append(session_id)

	if matching_session_ids.is_empty():
		return

	var label: Label = Label.new()
	label.text = "%s  (%d)" % [_format_workspace_group_text(workspace_id), matching_session_ids.size()]
	label.theme_type_variation = &"HeaderSmall"
	session_list.add_child(label)

	for session_id: String in matching_session_ids:
		var metadata: Dictionary = sessions_by_id.get(session_id, {}) as Dictionary
		var title_text: String = str(metadata.get("title", "Untitled"))
		var updated_at: String = str(metadata.get("updatedAt", ""))

		session_option_button.add_item(title_text)
		session_option_button.set_item_metadata(session_option_button.get_item_count() - 1, session_id)

		var session_item: Button = SESSION_ITEM_SCENE.instantiate() as Button
		session_list.add_child(session_item)
		session_item.call("setup", session_id, title_text, MAIN_HELPERS.format_relative_time(updated_at))
		session_item.call("set_loading", session_id == active_session_id and not active_stream_id.is_empty())
		session_item.connect("open_requested", Callable(self, "_on_dynamic_session_item_pressed"))
		session_item.connect("archive_requested", Callable(self, "_on_session_archive_requested"))


func _does_session_match_filters(metadata: Dictionary) -> bool:
	if not selected_workspace_filter.is_empty() and str(metadata.get("workspaceId", "")) != selected_workspace_filter:
		return false

	if session_search_text.is_empty():
		return true

	var query: String = session_search_text.to_lower()
	var title_text: String = str(metadata.get("title", "")).to_lower()
	var workspace_id: String = str(metadata.get("workspaceId", ""))
	var workspace_text: String = _format_workspace_search_text(workspace_id).to_lower()

	return title_text.contains(query) or workspace_id.to_lower().contains(query) or workspace_text.contains(query)


func _format_workspace_group_text(workspace_id: String) -> String:
	if workspace_id.is_empty():
		return "No workspace"

	var workspace: Dictionary = workspaces_by_id.get(workspace_id, {}) as Dictionary
	if workspace.is_empty():
		var metadata: Dictionary = _find_workspace_metadata_from_sessions(workspace_id)
		var workspace_name: String = str(metadata.get("workspaceName", "")).strip_edges()
		if not workspace_name.is_empty():
			return workspace_name

		var workspace_root: String = str(metadata.get("workspaceRoot", "")).replace("\\", "/").trim_suffix("/")
		if not workspace_root.is_empty():
			var root_name: String = workspace_root.get_file()
			if not root_name.is_empty():
				return root_name

		return "Unknown workspace: %s" % workspace_id

	return workspace.get("name", "Workspace")


func _format_workspace_search_text(workspace_id: String) -> String:
	if workspace_id.is_empty():
		return ""

	var workspace: Dictionary = workspaces_by_id.get(workspace_id, {}) as Dictionary
	if workspace.is_empty():
		var metadata: Dictionary = _find_workspace_metadata_from_sessions(workspace_id)
		return "%s %s %s" % [
			workspace_id,
			str(metadata.get("workspaceName", "")),
			str(metadata.get("workspaceRoot", ""))
		]

	return "%s %s" % [str(workspace.get("name", "")), str(workspace.get("rootPath", ""))]


func _find_workspace_metadata_from_sessions(workspace_id: String) -> Dictionary:
	for session_id: String in session_ids_in_order:
		var metadata: Dictionary = sessions_by_id.get(session_id, {}) as Dictionary
		if str(metadata.get("workspaceId", "")) == workspace_id:
			return metadata

	for session_id: String in archived_session_ids_in_order:
		var metadata: Dictionary = archived_sessions_by_id.get(session_id, {}) as Dictionary
		if str(metadata.get("workspaceId", "")) == workspace_id:
			return metadata

	return {}


func _select_workspace_filter(workspace_id: String) -> void:
	selected_workspace_filter = workspace_id
	for index: int in range(workspace_filter_button.get_item_count()):
		if str(workspace_filter_button.get_item_metadata(index)) == workspace_id:
			workspace_filter_button.select(index)
			return


func _on_workspace_filter_button_item_selected(index: int) -> void:
	if index < 0 or index >= workspace_filter_button.get_item_count():
		return

	selected_workspace_filter = str(workspace_filter_button.get_item_metadata(index))
	_render_session_list()


func _on_search_session_line_edit_text_changed(new_text: String) -> void:
	session_search_text = new_text.strip_edges()
	_render_session_list()


func _clear_session_buttons() -> void:
	for child: Node in session_list.get_children():
		child.queue_free()


func _on_dynamic_session_item_pressed(session_id: String) -> void:
	_open_session(session_id)


func _on_session_archive_requested(session_id: String) -> void:
	if not _is_socket_open() or session_id.is_empty():
		return

	_send_request(RPC_METHODS.SESSION_ARCHIVE, { "sessionId": session_id }, "session-archive")


func _apply_archived_session_response(result_dictionary: Dictionary) -> void:
	var metadata_value: Variant = result_dictionary.get("metadata", {})
	if typeof(metadata_value) != TYPE_DICTIONARY:
		_refresh_session_and_archive_lists()
		return

	var metadata: Dictionary = metadata_value as Dictionary
	var session_id: String = str(metadata.get("id", ""))
	if not session_id.is_empty():
		sessions_by_id.erase(session_id)
		session_ids_in_order.erase(session_id)
		archived_sessions_by_id[session_id] = metadata
		if not archived_session_ids_in_order.has(session_id):
			archived_session_ids_in_order.insert(0, session_id)
		if active_session_id == session_id:
			active_session_id = ""
			_update_navigation_state()

	_render_session_list()
	_sync_settings_archived_sessions()
	_refresh_session_and_archive_lists()


func _remove_archived_session(session_id: String) -> void:
	if session_id.is_empty():
		return

	archived_sessions_by_id.erase(session_id)
	archived_session_ids_in_order.erase(session_id)
	_sync_settings_archived_sessions()


func _refresh_session_and_archive_lists() -> void:
	_send_request(RPC_METHODS.SESSION_BROWSER_SNAPSHOT, {}, "session-browser-snapshot")


func _apply_session_metadata(metadata: Dictionary) -> void:
	active_session_id = str(metadata.get("id", ""))
	var metadata_provider_id: String = str(metadata.get("provider", "")).strip_edges()
	if _is_known_provider_id(metadata_provider_id):
		active_provider_id = metadata_provider_id
		_select_provider_id(active_provider_id)
		_populate_model_button(_get_fallback_models_for_provider(active_provider_id))
		var metadata_model_id: String = str(metadata.get("model", "")).strip_edges()
		if not metadata_model_id.is_empty():
			_select_or_add_model_id(metadata_model_id)
		_load_provider_models(active_provider_id)

	var metadata_chat_mode: String = str(metadata.get("chatMode", "")).strip_edges()
	if not metadata_chat_mode.is_empty():
		_select_chat_mode(metadata_chat_mode)

	if not active_session_id.is_empty():
		sessions_by_id[active_session_id] = _apply_renamed_session_override(metadata)
		if not session_ids_in_order.has(active_session_id):
			session_ids_in_order.insert(0, active_session_id)
		_render_session_list()
	_select_active_session()
	_update_navigation_state()
	_render_message_panel()


func _apply_renamed_session_override(metadata: Dictionary) -> Dictionary:
	var session_id: String = str(metadata.get("id", ""))
	if session_id.is_empty() or not renamed_session_metadata_by_id.has(session_id):
		return metadata

	var override_metadata: Dictionary = renamed_session_metadata_by_id[session_id]
	var result: Dictionary = metadata.duplicate(true)
	var metadata_updated_at: String = str(metadata.get("updatedAt", ""))
	var override_updated_at: String = str(override_metadata.get("updatedAt", ""))
	if override_updated_at.is_empty() or metadata_updated_at.is_empty() or override_updated_at >= metadata_updated_at:
		for metadata_key: Variant in override_metadata.keys():
			result[str(metadata_key)] = override_metadata[metadata_key]

	return result


func _apply_session_renamed_event(data_dictionary: Dictionary) -> void:
	var session_id: String = str(data_dictionary.get("sessionId", ""))
	if session_id.is_empty():
		return

	var metadata_value: Variant = data_dictionary.get("metadata", {})
	var metadata: Dictionary = {}
	if typeof(metadata_value) == TYPE_DICTIONARY:
		metadata = metadata_value as Dictionary
	else:
		metadata = {
			"id": session_id,
			"title": str(data_dictionary.get("title", ""))
		}

	renamed_session_metadata_by_id[session_id] = metadata.duplicate(true)
	if sessions_by_id.has(session_id):
		var existing_metadata: Dictionary = sessions_by_id[session_id]
		for metadata_key: Variant in metadata.keys():
			existing_metadata[str(metadata_key)] = metadata[metadata_key]
		sessions_by_id[session_id] = existing_metadata
	else:
		sessions_by_id[session_id] = metadata
		session_ids_in_order.append(session_id)

	_render_session_list()
	if active_session_id == session_id:
		_select_active_session()


func _apply_provider_config_status(status: Dictionary) -> void:
	provider_config_status = status
	_sync_provider_catalog_from_status(status)
	var configured: bool = bool(status.get("configured", false))
	var provider_value: String = str(status.get("activeProvider", status.get("provider", active_provider_id))).strip_edges()
	if active_session_id.is_empty() and _is_known_provider_id(provider_value):
		active_provider_id = provider_value
	_select_provider_id(active_provider_id)
	var model_value: Variant = status.get("model", null)

	if configured:
		status_button.icon = CONNECTED_ICON
		status_button.tooltip_text = "%s provider configured" % _get_provider_display_name(active_provider_id)
	else:
		status_button.icon = STAUTS_WARNING
		status_button.tooltip_text = "Open settings and save %s API key" % _get_provider_display_name(active_provider_id)

	_populate_model_button(_get_fallback_models_for_provider(active_provider_id))
	if active_session_id.is_empty() and typeof(model_value) == TYPE_STRING:
		_select_or_add_model_id(str(model_value))
	_load_provider_models(active_provider_id)

	_update_send_state()


func _apply_web_search_settings_status(status: Dictionary) -> void:
	web_search_settings_status = status.duplicate(true)
	if active_settings_menu != null and is_instance_valid(active_settings_menu):
		active_settings_menu.call("setup_web_search_settings", web_search_settings_status)


func _apply_user_prompt_config(config: Dictionary) -> void:
	custom_instructions = str(config.get("prompt", "")).strip_edges()
	if active_settings_menu != null and is_instance_valid(active_settings_menu):
		active_settings_menu.call("setup_provider_config", provider_config_status, _get_frontend_config_snapshot())


func _apply_approval_mode_status(status: Dictionary) -> void:
	var mode_value: String = str(status.get("mode", status.get("approvalMode", ""))).strip_edges()
	if mode_value.is_empty():
		return

	_select_approval_mode(mode_value)


func _apply_provider_models_list_response(result: Dictionary) -> void:
	var provider_id: String = str(result.get("provider", "")).strip_edges()
	if provider_id != active_provider_id:
		return

	var models_value: Variant = result.get("models", [])
	if typeof(models_value) != TYPE_ARRAY:
		return

	var previous_model_id: String = _get_selected_model_id()
	_populate_model_button(models_value as Array)
	if not previous_model_id.is_empty():
		_select_model_id(previous_model_id)
	if bool(result.get("stale", false)) and result.has("error"):
		model_button.tooltip_text = "%s\nModel list is using cached/default data: %s" % [
			model_button.tooltip_text,
			str(result.get("error", ""))
		]
	_update_send_state()


func _select_active_session() -> void:
	for index: int in range(session_option_button.get_item_count()):
		if str(session_option_button.get_item_metadata(index)) == active_session_id:
			session_option_button.select(index)
			return

	if session_option_button.get_item_count() > 0:
		session_option_button.select(0)

# --- timeline_history_controller.gd ---

# --- timeline_history_controller.gd ---
func _clear_chat_items() -> void:
	tool_items_by_call_id.clear()
	active_tool_entry_ids_by_call_id.clear()
	active_assistant_item = null
	active_thinking_item = null
	active_assistant_entry_id = ""
	active_thinking_entry_id = ""
	active_stream_request_id = ""
	active_stream_started_at_utc = ""
	active_stream_status_code = ""
	_clear_paused_stream_context()
	connection_status_entry_id = ""
	active_assistant_text = ""
	pending_assistant_delta_text = ""
	pending_assistant_delta_queued = false
	pending_thinking_delta_text = ""
	pending_thinking_delta_queued = false
	pending_assistant_delta_flush_at_msec = 0
	pending_thinking_delta_flush_at_msec = 0
	timeline_measure_after_msec = 0
	next_step_hint_request_id = ""
	next_step_hint_anchor_request_id = ""
	next_step_hint_entry_ids.clear()
	next_step_hints_by_action_id.clear()
	text_edit.placeholder_text = ""
	timeline_entries.clear()
	timeline_heights.clear()
	timeline_prefix_heights.clear()
	timeline_entry_ids.clear()
	timeline_entry_indices_by_id.clear()
	plan_assistant_entry_ids_by_plan_id.clear()
	_clear_timeline_node_pools()
	rendered_entry_nodes.clear()
	rendered_entry_indices.clear()
	timeline_heights_dirty = true
	timeline_dirty_height_start_index = 0
	timeline_block_offset = 0
	timeline_has_more_before = false
	timeline_has_more_after = false
	timeline_loading_before = false
	timeline_loading_after = false
	_clear_todo_items()
	_setup_timeline_containers()
	for child: Node in timeline_visible_container.get_children():
		child.queue_free()
	timeline_top_spacer.custom_minimum_size = Vector2(0.0, 0.0)
	timeline_bottom_spacer.custom_minimum_size = Vector2(0.0, 0.0)
	_set_context_length_icon(0.0, true)
	_render_message_panel()


func _clear_timeline_entry_completion_time(entry_id: String) -> void:
	var index: int = _find_timeline_entry_index(entry_id)
	if index < 0:
		return

	var entry: Dictionary = timeline_entries[index]
	entry.erase("completed_at_utc")
	timeline_entries[index] = entry
	_mark_timeline_height_dirty(index)


func _render_timeline_blocks(blocks_value: Variant, page_info: Dictionary) -> void:
	timeline_block_offset = int(page_info.get("blockOffset", 0))
	timeline_has_more_before = bool(page_info.get("hasMoreBefore", false))
	timeline_has_more_after = bool(page_info.get("hasMoreAfter", false))
	timeline_loading_before = false
	timeline_loading_after = false
	_append_timeline_blocks(blocks_value)
	active_thinking_item = null
	active_thinking_entry_id = ""
	_rebuild_timeline_index_cache()
	_rebuild_timeline_height_cache()
	_render_visible_timeline(true)
	_restore_pending_plan_dialogs_from_snapshot(page_info)


func _restore_pending_plan_dialogs_from_snapshot(page_info: Dictionary) -> void:
	# Timeline pages are partial history. Only the backend's global pending snapshot can
	# decide whether a plan still needs input; otherwise old plan previews reopen dialogs.
	clarification_dialog.hide()
	plan_approval_dialog.hide()

	var clarification_value: Variant = page_info.get("latestPlanClarification", null)
	if typeof(clarification_value) == TYPE_DICTIONARY:
		_show_clarification_dialog(clarification_value as Dictionary)
		return

	var approval_value: Variant = page_info.get("latestPlanApproval", null)
	if typeof(approval_value) == TYPE_DICTIONARY:
		_show_plan_approval_dialog(approval_value as Dictionary)
		return

	_sync_plan_overlay_input_visibility()


func _request_previous_timeline_page() -> void:
	if timeline_loading_before or not timeline_has_more_before:
		return
	if active_session_id.is_empty() or timeline_block_offset <= 0:
		return
	if not _is_socket_open():
		return

	timeline_loading_before = true
	var params: Dictionary[String, Variant] = {
		"sessionId": active_session_id,
		"beforeOffset": timeline_block_offset,
		"limit": SESSION_OPEN_MESSAGE_LIMIT
	}
	_send_request(RPC_METHODS.SESSION_TIMELINE, params, "session-timeline")


func _request_next_timeline_page() -> void:
	if timeline_loading_after or not timeline_has_more_after:
		return
	if active_session_id.is_empty() or timeline_entries.is_empty():
		return
	if not _is_socket_open():
		return

	timeline_loading_after = true
	var params: Dictionary[String, Variant] = {
		"sessionId": active_session_id,
		"afterOffset": timeline_block_offset + timeline_entries.size(),
		"limit": SESSION_OPEN_MESSAGE_LIMIT
	}
	_send_request(RPC_METHODS.SESSION_TIMELINE, params, "session-timeline-after")


func _prepend_session_timeline(page_info: Dictionary) -> void:
	timeline_loading_before = false
	timeline_loading_after = false

	var blocks_value: Variant = page_info.get("timelineBlocks", [])
	if typeof(blocks_value) != TYPE_ARRAY:
		return

	var before_size: int = timeline_entries.size()
	_append_timeline_blocks(blocks_value)
	var after_size: int = timeline_entries.size()
	if after_size <= before_size:
		timeline_block_offset = int(page_info.get("blockOffset", timeline_block_offset))
		timeline_has_more_before = bool(page_info.get("hasMoreBefore", false))
		timeline_has_more_after = bool(page_info.get("hasMoreAfter", timeline_has_more_after))
		return

	var appended_entries: Array[Dictionary] = []
	for index: int in range(before_size, after_size):
		appended_entries.append(timeline_entries[index])

	var existing_entries: Array[Dictionary] = []
	for index: int in range(0, before_size):
		existing_entries.append(timeline_entries[index])

	var added_height: float = 0.0
	for entry: Dictionary in appended_entries:
		added_height += _get_entry_cached_height(entry)

	timeline_entries.clear()
	for entry: Dictionary in appended_entries:
		timeline_entries.append(entry)
	for entry: Dictionary in existing_entries:
		timeline_entries.append(entry)

	timeline_block_offset = int(page_info.get("blockOffset", timeline_block_offset))
	timeline_has_more_before = bool(page_info.get("hasMoreBefore", false))
	timeline_has_more_after = bool(page_info.get("hasMoreAfter", timeline_has_more_after))
	_trim_loaded_timeline_entries_from_bottom()
	_rebuild_timeline_index_cache()
	_rebuild_timeline_height_cache()
	_recycle_all_rendered_timeline_nodes()
	_render_visible_timeline(false)
	_restore_scroll_after_prepend(added_height)


func _append_next_session_timeline(page_info: Dictionary) -> void:
	timeline_loading_after = false
	timeline_loading_before = false

	var blocks_value: Variant = page_info.get("timelineBlocks", [])
	if typeof(blocks_value) != TYPE_ARRAY:
		return

	var before_size: int = timeline_entries.size()
	_append_timeline_blocks(blocks_value)
	if timeline_entries.size() <= before_size:
		timeline_has_more_after = bool(page_info.get("hasMoreAfter", false))
		return

	timeline_has_more_after = bool(page_info.get("hasMoreAfter", false))
	_trim_loaded_timeline_entries_from_top()
	_rebuild_timeline_index_cache()
	_rebuild_timeline_height_cache()
	_render_visible_timeline(false)


func _trim_loaded_timeline_entries_from_bottom() -> void:
	while timeline_entries.size() > TIMELINE_MAX_LOADED_BLOCKS:
		var last_index: int = timeline_entries.size() - 1
		var last_entry: Dictionary = timeline_entries[last_index]
		var last_entry_id: String = str(last_entry.get("id", ""))
		if _is_timeline_entry_protected_from_unload(last_entry_id):
			break

		_recycle_rendered_timeline_node(last_entry_id, last_entry)
		timeline_entries.remove_at(last_index)
		if last_index < timeline_heights.size():
			timeline_heights.remove_at(last_index)
		timeline_has_more_after = true
		timeline_heights_dirty = true
		timeline_dirty_height_start_index = mini(timeline_dirty_height_start_index, last_index) if timeline_dirty_height_start_index >= 0 else last_index


func _trim_loaded_timeline_entries_from_top() -> void:
	var removed_count: int = 0
	while timeline_entries.size() > TIMELINE_MAX_LOADED_BLOCKS:
		var first_entry: Dictionary = timeline_entries[0]
		var first_entry_id: String = str(first_entry.get("id", ""))
		if _is_timeline_entry_protected_from_unload(first_entry_id):
			break

		_recycle_rendered_timeline_node(first_entry_id, first_entry)
		timeline_entries.remove_at(0)
		if not timeline_heights.is_empty():
			timeline_heights.remove_at(0)
		removed_count += 1

	if removed_count <= 0:
		return

	timeline_block_offset += removed_count
	timeline_has_more_before = true
	timeline_heights_dirty = true
	timeline_dirty_height_start_index = 0


func _restore_scroll_after_prepend(added_height: float) -> void:
	await get_tree().process_frame
	scroll_container.scroll_vertical = int(float(scroll_container.scroll_vertical) + added_height)


func _apply_latest_workflow_snapshot(page_info: Dictionary) -> void:
	var snapshot_value: Variant = page_info.get("latestWorkflowSnapshot", null)
	if typeof(snapshot_value) != TYPE_DICTIONARY:
		return

	_apply_workflow_todo_snapshot(snapshot_value as Dictionary)


func _append_timeline_blocks(blocks_value: Variant) -> void:
	if typeof(blocks_value) != TYPE_ARRAY:
		return

	var blocks: Array = blocks_value as Array
	for block_value: Variant in blocks:
		if typeof(block_value) != TYPE_DICTIONARY:
			continue

		var block: Dictionary = block_value as Dictionary
		var block_type: String = str(block.get("type", ""))
		var request_id: String = str(block.get("requestId", ""))
		var entry_id: String = str(block.get("id", ""))
		if block_type == "user":
			var additional_contexts_value: Variant = block.get("additionalContext", [])
			var additional_contexts: Array = additional_contexts_value as Array if typeof(additional_contexts_value) == TYPE_ARRAY else []
			var user_metadata: Dictionary = {
				"sent_at_utc": str(block.get("sentAtUtc", "")),
				"additional_context": additional_context_controller.clone_contexts(additional_contexts)
			}
			var user_render_hint_height: float = _get_timeline_render_hint_height(block)
			if user_render_hint_height > 0.0:
				user_metadata["height_estimate"] = user_render_hint_height
			_append_timeline_entry(
				"user",
				request_id,
				str(block.get("content", "")),
				entry_id,
				user_metadata
			)
		elif block_type == "assistant":
			var body_parts_value: Variant = block.get("bodyParts", [])
			var body_parts: Array = body_parts_value as Array if typeof(body_parts_value) == TYPE_ARRAY else []
			var assistant_metadata: Dictionary = {
				"started_at_utc": str(block.get("startedAtUtc", "")),
				"completed_at_utc": str(block.get("completedAtUtc", "")),
				"body_parts": body_parts
			}
			var assistant_render_hint_height: float = _get_timeline_render_hint_height(block)
			if assistant_render_hint_height > 0.0:
				assistant_metadata["height_estimate"] = assistant_render_hint_height
			var assistant_entry_id: String = _append_timeline_entry(
				"assistant",
				request_id,
				str(block.get("content", "")),
				entry_id,
				assistant_metadata
			)
			_remember_plan_entry_from_body_parts(assistant_entry_id, body_parts)


func _append_session_records_to_timeline(messages_value: Variant, events_value: Variant) -> void:
	var messages: Array
	if typeof(messages_value) == TYPE_ARRAY:
		messages = messages_value as Array

	var message_request_ids: Dictionary[String, bool] = _collect_message_request_ids(messages)
	var assistant_request_ids: Dictionary[String, bool] = _collect_message_request_ids_for_role(messages, "assistant")
	var request_aliases: Dictionary[String, String] = _collect_session_event_request_aliases(events_value)
	var events_by_request_id: Dictionary[String, Array]
	var orphan_events: Array[Dictionary]
	_collect_session_events(events_value, message_request_ids, request_aliases, events_by_request_id, orphan_events)

	var consumed_request_ids: PackedStringArray
	var rendered_orphan_events: bool = false
	var request_started_at_by_id: Dictionary[String, String]

	for item: Variant in messages:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var message: Dictionary = item as Dictionary
		var role: String = str(message.get("role", ""))
		var content: String = str(message.get("content", ""))
		var request_id: String = str(message.get("requestId", ""))
		var created_at: String = str(message.get("createdAt", ""))

		if role == "user":
			var additional_contexts_value: Variant = message.get("additionalContext", [])
			var additional_contexts: Array = additional_contexts_value as Array if typeof(additional_contexts_value) == TYPE_ARRAY else []
			_append_timeline_entry(
				"user",
				request_id,
				content,
				_make_message_entry_id(message, role),
				{
					"sent_at_utc": created_at,
					"additional_context": additional_context_controller.clone_contexts(additional_contexts)
				}
			)
			if not request_id.is_empty() and not created_at.is_empty():
				request_started_at_by_id[request_id] = created_at
			if not request_id.is_empty() and not assistant_request_ids.has(request_id):
				_append_events_for_request(request_id, events_by_request_id, consumed_request_ids)
		elif role == "assistant":
			var body_parts: Array[Dictionary] = []
			if not request_id.is_empty():
				var request_records: Array = events_by_request_id.get(request_id, []) as Array
				_append_event_records(_filter_non_assistant_body_event_records(request_records))
				body_parts = _build_assistant_body_parts(request_records, content, request_id, message)
				if not consumed_request_ids.has(request_id):
					consumed_request_ids.append(request_id)
			else:
				body_parts = _build_assistant_body_parts([], content, request_id, message)
			if not rendered_orphan_events and not orphan_events.is_empty():
				_append_orphan_event_records(orphan_events)
				rendered_orphan_events = true
			var started_at_utc: String = str(request_started_at_by_id.get(request_id, ""))
			var assistant_entry_id: String = _append_timeline_entry(
				"assistant",
				request_id,
				content,
				_make_message_entry_id(message, role),
				{
					"started_at_utc": started_at_utc,
					"completed_at_utc": created_at,
					"body_parts": body_parts
				}
			)
			_remember_plan_entry_from_body_parts(assistant_entry_id, body_parts)

	if not rendered_orphan_events:
		_append_orphan_event_records(orphan_events)

	for request_id: String in events_by_request_id.keys():
		if consumed_request_ids.has(request_id):
			continue

		_append_events_for_request(request_id, events_by_request_id, consumed_request_ids)


func _make_message_entry_id(message: Dictionary, role: String) -> String:
	var request_id: String = str(message.get("requestId", ""))
	var created_at: String = str(message.get("createdAt", ""))
	if request_id.is_empty() and created_at.is_empty():
		return ""

	return "message:%s:%s:%s" % [request_id, role, created_at]


func _collect_message_request_ids(messages: Array) -> Dictionary[String, bool]:
	var ids: Dictionary[String, bool] = {}
	for item: Variant in messages:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var message: Dictionary = item as Dictionary
		var request_id: String = str(message.get("requestId", ""))
		if not request_id.is_empty():
			ids[request_id] = true

	return ids


func _collect_message_request_ids_for_role(messages: Array, target_role: String) -> Dictionary[String, bool]:
	var ids: Dictionary[String, bool] = {}
	for item: Variant in messages:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var message: Dictionary = item as Dictionary
		if str(message.get("role", "")) != target_role:
			continue

		var request_id: String = str(message.get("requestId", ""))
		if not request_id.is_empty():
			ids[request_id] = true

	return ids


func _collect_session_event_request_aliases(events_value: Variant) -> Dictionary[String, String]:
	var aliases: Dictionary[String, String] = {}
	if typeof(events_value) != TYPE_ARRAY:
		return aliases

	var events: Array = events_value as Array
	for item: Variant in events:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var event_record: Dictionary = item as Dictionary
		var event_name: String = str(event_record.get("event", ""))
		if not event_name.begins_with("plan."):
			continue
		if event_name == "plan.execution.started":
			continue

		var data_value: Variant = event_record.get("data", {})
		if typeof(data_value) != TYPE_DICTIONARY:
			continue

		var data: Dictionary = data_value as Dictionary
		var event_request_id: String = str(event_record.get("requestId", "")).strip_edges()
		if event_request_id.is_empty() or aliases.has(event_request_id):
			continue

		var canonical_request_id: String = str(data.get("requestId", "")).strip_edges()
		if not canonical_request_id.is_empty() and canonical_request_id != event_request_id:
			aliases[event_request_id] = canonical_request_id

	return aliases


func _collect_session_events(
	events_value: Variant,
	message_request_ids: Dictionary[String, bool],
	request_aliases: Dictionary[String, String],
	events_by_request_id: Dictionary[String, Array],
	orphan_events: Array[Dictionary]
) -> void:
	if typeof(events_value) != TYPE_ARRAY:
		return

	var events: Array = events_value as Array
	for event_index: int in range(events.size()):
		var item: Variant = events[event_index]
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var event_record: Dictionary = (item as Dictionary).duplicate(true)
		var original_request_id: String = str(event_record.get("requestId", "")).strip_edges()
		var canonical_request_id: String = str(request_aliases.get(original_request_id, ""))
		if not canonical_request_id.is_empty():
			event_record["requestId"] = canonical_request_id

		event_record["_timelineOrder"] = event_index
		var request_id: String = str(event_record.get("requestId", ""))
		if request_id.is_empty() or not message_request_ids.has(request_id):
			orphan_events.append(event_record)
			continue

		if not events_by_request_id.has(request_id):
			events_by_request_id[request_id] = []

		var request_events: Array = events_by_request_id[request_id]
		request_events.append(event_record)

	for request_id: String in events_by_request_id.keys():
		var records: Array = events_by_request_id.get(request_id, []) as Array
		records.sort_custom(_compare_event_records_by_created_at)

	orphan_events.sort_custom(_compare_event_records_by_created_at)


func _compare_event_records_by_created_at(left: Dictionary, right: Dictionary) -> bool:
	var left_created_at: String = str(left.get("createdAt", ""))
	var right_created_at: String = str(right.get("createdAt", ""))
	if left_created_at == right_created_at:
		return int(left.get("_timelineOrder", 0)) < int(right.get("_timelineOrder", 0))

	return left_created_at < right_created_at


func _append_events_for_request(request_id: String, events_by_request_id: Dictionary[String, Array], consumed_request_ids: PackedStringArray) -> void:
	if consumed_request_ids.has(request_id):
		return

	consumed_request_ids.append(request_id)
	var records: Array = events_by_request_id.get(request_id, []) as Array
	var body_parts: Array[Dictionary] = _build_assistant_body_parts(records, "", request_id, {})
	if not body_parts.is_empty():
		var completed_at_utc: String = _get_last_event_created_at(records)
		var entry_id: String = _append_timeline_entry(
			"assistant",
			request_id,
			"",
			"assistant-events:%s:%s" % [request_id, completed_at_utc],
			{
				"started_at_utc": _get_first_event_created_at(records),
				"completed_at_utc": completed_at_utc,
				"body_parts": body_parts
			}
		)
		_remember_plan_entry_from_body_parts(entry_id, body_parts)
		return

	_append_event_records(records)


func _append_event_records(records: Array) -> void:
	for item: Variant in records:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var event_record: Dictionary = item as Dictionary
		var event_name: String = str(event_record.get("event", ""))
		var data_value: Variant = event_record.get("data", {})
		if typeof(data_value) != TYPE_DICTIONARY:
			continue

		var data: Dictionary = data_value as Dictionary
		if not data.has("type"):
			data["type"] = event_name
		data["_eventRecordId"] = str(event_record.get("id", ""))

		_append_event_to_timeline(event_name, data, str(event_record.get("requestId", "")))


func _append_orphan_event_records(records: Array) -> void:
	var assistant_records_by_request_id: Dictionary[String, Array] = {}
	for item: Variant in records:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var event_record: Dictionary = item as Dictionary
		var request_id: String = str(event_record.get("requestId", ""))
		if request_id.is_empty():
			continue
		var event_name: String = str(event_record.get("event", ""))
		if not _is_run_error_event(event_name) and not event_name.begins_with("plan."):
			continue

		assistant_records_by_request_id[request_id] = []

	for item: Variant in records:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var event_record: Dictionary = item as Dictionary
		var request_id: String = str(event_record.get("requestId", ""))
		if assistant_records_by_request_id.has(request_id):
			var grouped_records: Array = assistant_records_by_request_id[request_id]
			grouped_records.append(event_record)
			assistant_records_by_request_id[request_id] = grouped_records

	var consumed_request_ids: Dictionary[String, bool] = {}
	for item: Variant in records:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var event_record: Dictionary = item as Dictionary
		var request_id: String = str(event_record.get("requestId", ""))
		if not assistant_records_by_request_id.has(request_id):
			_append_event_records([event_record])
			continue
		if consumed_request_ids.has(request_id):
			continue

		consumed_request_ids[request_id] = true
		var assistant_records: Array = assistant_records_by_request_id[request_id]
		var completed_at_utc: String = _get_last_event_created_at(assistant_records)
		var body_parts: Array[Dictionary] = _build_assistant_body_parts(assistant_records, "", request_id, {})
		var entry_id: String = _append_timeline_entry(
			"assistant",
			request_id,
			"",
			"assistant-events:%s:%s" % [request_id, completed_at_utc],
			{
				"started_at_utc": _get_first_event_created_at(assistant_records),
				"completed_at_utc": completed_at_utc,
				"body_parts": body_parts
			}
		)
		_remember_plan_entry_from_body_parts(entry_id, body_parts)


func _filter_non_assistant_body_event_records(records: Array) -> Array:
	var filtered_records: Array = []
	for item: Variant in records:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var event_record: Dictionary = item as Dictionary
		var event_name: String = str(event_record.get("event", ""))
		if event_name == "ai.delta" or event_name == "agent.message.delta":
			continue
		if event_name.begins_with("tool.") or event_name.begins_with("agent.tool."):
			continue
		if event_name.begins_with("ai.thinking.") or event_name.begins_with("agent.thinking."):
			continue
		if event_name == "ai.status":
			continue
		if event_name == "agent.summary.started":
			continue
		if _is_run_error_event(event_name):
			continue
		if event_name.begins_with("plan."):
			continue

		filtered_records.append(event_record)

	return filtered_records


func _build_assistant_body_parts(records: Array, message_content: String, request_id: String, assistant_message: Dictionary = {}) -> Array[Dictionary]:
	var body_parts: Array[Dictionary] = []
	var file_edit_batches: Array[Dictionary] = []
	var has_markdown_delta: bool = false
	var has_error_status: bool = false
	var records_have_markdown_delta: bool = _records_have_event(records, "ai.delta") or _records_have_event(records, "agent.message.delta")
	if not records_have_markdown_delta and not message_content.is_empty():
		_append_markdown_delta_to_body_parts(body_parts, message_content)

	for item: Variant in records:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var event_record: Dictionary = item as Dictionary
		var event_name: String = str(event_record.get("event", ""))

		var data_value: Variant = event_record.get("data", {})
		if typeof(data_value) != TYPE_DICTIONARY:
			continue

		var event_data: Dictionary = (data_value as Dictionary).duplicate(true)
		if not event_data.has("type"):
			event_data["type"] = event_name
		event_data["_eventRecordId"] = str(event_record.get("id", ""))
		if event_name == "ai.delta" or event_name == "agent.message.delta":
			var delta_text: String = str(event_data.get("text", ""))
			if not delta_text.is_empty():
				_append_markdown_delta_to_body_parts(body_parts, delta_text)
				has_markdown_delta = true
		elif event_name.begins_with("tool.") or event_name.begins_with("agent.tool."):
			var normalized_tool_event: Dictionary = _normalize_agent_tool_event_data(event_name, event_data)
			_append_tool_event_to_body_parts(body_parts, normalized_tool_event, request_id)
			file_edit_controller.append_batch_from_event(file_edit_batches, normalized_tool_event)
		elif event_name == "agent.summary.started":
			_append_summary_start_to_body_parts(body_parts, event_data)
		elif event_name == "ai.thinking.delta" or event_name == "agent.thinking.delta":
			_append_thinking_event_to_body_parts(body_parts, str(event_data.get("text", "")), false)
		elif event_name == "ai.thinking.done" or event_name == "agent.thinking.done":
			_append_thinking_event_to_body_parts(body_parts, "", true)
		elif event_name == "ai.status":
			_append_status_event_to_body_parts(body_parts, event_data)
		elif _is_run_error_event(event_name):
			_append_run_error_to_body_parts(body_parts, event_data)
			has_error_status = true
		elif event_name == "plan.generated" or event_name == "plan.revised":
			var plan_part: Dictionary = _create_plan_body_part(event_data)
			if not plan_part.is_empty():
				body_parts.append(plan_part)
		elif event_name == "plan.clarification.required":
			_append_status_event_to_body_parts(body_parts, {
				"status": "message",
				"title": "需要澄清计划",
				"details": str(event_data.get("question", "")),
				"code": "plan",
				"iconUid": PLAN_CLARIFICATION_ICON_UID,
				"planId": str(event_data.get("planId", ""))
			})

	if not has_markdown_delta and records_have_markdown_delta and not message_content.is_empty():
		_append_markdown_delta_to_body_parts(body_parts, message_content)
	if not has_error_status and str(assistant_message.get("status", "")) == "failed":
		_append_failed_message_status_to_body_parts(body_parts, assistant_message)

	file_edit_controller.set_active_session_id(active_session_id)
	var inline_diff_summary: Dictionary = file_edit_controller.create_inline_diff_summary(file_edit_batches)
	if not inline_diff_summary.is_empty():
		body_parts.append(inline_diff_summary)

	return body_parts


func _is_run_error_event(event_name: String) -> bool:
	return event_name == "agent.run.error" or event_name == "workflow.error"


func _append_run_error_to_body_parts(body_parts: Array[Dictionary], event_data: Dictionary) -> void:
	var message_text: String = str(event_data.get("message", "Unknown backend error"))
	var code_text: String = str(event_data.get("code", "agent_run_error"))
	_append_status_event_to_body_parts(body_parts, {
		"status": "error",
		"title": "后端返回错误",
		"details": message_text,
		"code": code_text
	})


func _append_failed_message_status_to_body_parts(body_parts: Array[Dictionary], assistant_message: Dictionary) -> void:
	var error_value: Variant = assistant_message.get("error", {})
	var code_text: String = "agent_run_error"
	var message_text: String = "Unknown backend error"
	if typeof(error_value) == TYPE_DICTIONARY:
		var error_dictionary: Dictionary = error_value as Dictionary
		code_text = str(error_dictionary.get("code", code_text))
		message_text = str(error_dictionary.get("message", message_text))

	_append_status_event_to_body_parts(body_parts, {
		"status": "error",
		"title": "后端返回错误",
		"details": message_text,
		"code": code_text
	})


func _get_first_event_created_at(records: Array) -> String:
	for item: Variant in records:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var event_record: Dictionary = item as Dictionary
		var created_at: String = str(event_record.get("createdAt", ""))
		if not created_at.is_empty():
			return created_at

	return ""


func _get_last_event_created_at(records: Array) -> String:
	for index: int in range(records.size() - 1, -1, -1):
		var item: Variant = records[index]
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var event_record: Dictionary = item as Dictionary
		var created_at: String = str(event_record.get("createdAt", ""))
		if not created_at.is_empty():
			return created_at

	return ""


func _records_have_event(records: Array, target_event_name: String) -> bool:
	for item: Variant in records:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var event_record: Dictionary = item as Dictionary
		if str(event_record.get("event", "")) == target_event_name:
			return true

	return false


func _append_markdown_delta_to_body_parts(body_parts: Array, delta_text: String) -> void:
	if delta_text.is_empty():
		return

	if not body_parts.is_empty():
		var last_part_value: Variant = body_parts[body_parts.size() - 1]
		if typeof(last_part_value) == TYPE_DICTIONARY:
			var last_part: Dictionary = last_part_value as Dictionary
			if str(last_part.get("type", "")) == "markdown":
				last_part["text"] = str(last_part.get("text", "")) + delta_text
				body_parts[body_parts.size() - 1] = last_part
				return

	body_parts.append({
		"type": "markdown",
		"text": delta_text
	})


func _append_tool_event_to_body_parts(body_parts: Array, event_data: Dictionary, request_id: String) -> void:
	var tool_call_id: String = _get_scoped_tool_call_key(event_data, request_id)
	for index: int in range(body_parts.size()):
		var part_value: Variant = body_parts[index]
		if typeof(part_value) != TYPE_DICTIONARY:
			continue

		var part: Dictionary = part_value as Dictionary
		if str(part.get("type", "")) != "tool":
			continue
		if str(part.get("tool_call_id", "")) != tool_call_id:
			continue

		var events_value: Variant = part.get("events", [])
		var events: Array = events_value as Array if typeof(events_value) == TYPE_ARRAY else []
		if _does_event_list_have_record(events, str(event_data.get("_eventRecordId", ""))):
			return

		events.append(event_data.duplicate(true))
		part["events"] = events
		body_parts[index] = part
		return

	body_parts.append({
		"type": "tool",
		"tool_call_id": tool_call_id,
		"events": [event_data.duplicate(true)]
	})


func _append_thinking_event_to_body_parts(body_parts: Array, delta_text: String, is_done: bool) -> void:
	for index: int in range(body_parts.size() - 1, -1, -1):
		var part_value: Variant = body_parts[index]
		if typeof(part_value) != TYPE_DICTIONARY:
			continue

		var part: Dictionary = part_value as Dictionary
		if str(part.get("type", "")) != "thinking":
			continue
		if bool(part.get("done", false)):
			continue

		if not delta_text.is_empty():
			part["text"] = str(part.get("text", "")) + delta_text
		if is_done:
			part["done"] = true
		body_parts[index] = part
		return

	body_parts.append({
		"type": "thinking",
		"text": delta_text,
		"done": is_done
	})


func _append_status_event_to_body_parts(body_parts: Array, status_data: Dictionary) -> void:
	var part: Dictionary = {
		"type": "status",
		"status": str(status_data.get("status", "message")),
		"title": str(status_data.get("title", "")),
		"details": str(status_data.get("details", status_data.get("detail", ""))),
		"actionLabel": str(status_data.get("actionLabel", status_data.get("action_label", ""))),
		"actionId": str(status_data.get("actionId", status_data.get("action_id", ""))),
		"code": str(status_data.get("code", "")),
		"iconUid": str(status_data.get("iconUid", status_data.get("icon_uid", ""))),
		"planId": str(status_data.get("planId", ""))
	}
	body_parts.append(part)


func _append_summary_start_to_body_parts(body_parts: Array, summary_data: Dictionary) -> void:
	var step_run_id: String = str(summary_data.get("stepRunId", ""))
	if step_run_id.is_empty():
		return

	for part_value: Variant in body_parts:
		if typeof(part_value) != TYPE_DICTIONARY:
			continue

		var existing_part: Dictionary = part_value as Dictionary
		if str(existing_part.get("type", "")) == "summary_start" and str(existing_part.get("stepRunId", "")) == step_run_id:
			return

	body_parts.append({
		"type": "summary_start",
		"runId": str(summary_data.get("runId", "")),
		"stepId": str(summary_data.get("stepId", "")),
		"stepRunId": step_run_id,
		"title": str(summary_data.get("title", "")),
		"foldTitle": str(summary_data.get("foldTitle", "总结前的过程"))
	})


func _on_file_edit_request_ready(params: Dictionary, group_id: String) -> void:
	if not _is_socket_open():
		return
	var request_id_value: String = _send_request(RPC_METHODS.FILE_EDIT_BATCH_GET, params, "file-edit-batch")
	file_edit_controller.register_batch_request(group_id, request_id_value)


func _on_file_edit_inline_diff_ready(entry_id: String, summary: Dictionary) -> void:
	var entry_index: int = _find_timeline_entry_index(entry_id)
	if entry_index >= 0:
		var entry: Dictionary = timeline_entries[entry_index]
		var body_parts: Array = entry.get("body_parts", []) as Array
		body_parts.append(summary.duplicate(true))
		entry["body_parts"] = body_parts
		entry["height_actual"] = 0.0
		timeline_entries[entry_index] = entry
		_mark_timeline_height_dirty(entry_index)
	if active_assistant_item != null:
		active_assistant_item.call("add_inline_diff_viewer", summary)


func _does_event_list_have_record(events: Array, event_record_id: String) -> bool:
	if event_record_id.is_empty():
		return false

	for event_value: Variant in events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue

		var event_data: Dictionary = event_value as Dictionary
		if str(event_data.get("_eventRecordId", "")) == event_record_id:
			return true

	return false

# --- timeline_entry_controller.gd ---

# --- timeline_entry_controller.gd ---
func _append_timeline_entry(entry_type: String, request_id: String, content: String, preferred_entry_id: String = "", metadata: Dictionary = {}) -> String:
	var entry_id: String = preferred_entry_id
	if entry_id.is_empty():
		entry_id = "timeline-%d-%d" % [Time.get_ticks_msec(), timeline_entries.size()]
	if timeline_entry_ids.has(entry_id):
		return entry_id

	var entry: Dictionary = {
		"id": entry_id,
		"type": entry_type,
		"request_id": request_id,
		"content": content,
		"events": [],
		"height_estimate": _estimate_timeline_entry_height(entry_type, content),
		"height_actual": 0.0,
		"collapsed": false,
		"tool_call_id": ""
	}
	for metadata_key: Variant in metadata.keys():
		entry[str(metadata_key)] = metadata[metadata_key]
	timeline_entries.append(entry)
	timeline_entry_ids[entry_id] = true
	timeline_entry_indices_by_id[entry_id] = timeline_entries.size() - 1
	timeline_heights.append(_get_entry_cached_height(entry))
	timeline_heights_dirty = true
	timeline_dirty_height_start_index = timeline_entries.size() - 1 if timeline_dirty_height_start_index < 0 else mini(timeline_dirty_height_start_index, timeline_entries.size() - 1)
	if entry_type == "assistant":
		_remember_plan_entry_from_body_parts(entry_id, entry.get("body_parts", []))
	return entry_id


func _remember_plan_entry_from_body_parts(entry_id: String, body_parts_value: Variant) -> void:
	if entry_id.is_empty() or typeof(body_parts_value) != TYPE_ARRAY:
		return

	for part_value: Variant in body_parts_value as Array:
		if typeof(part_value) != TYPE_DICTIONARY:
			continue

		var part: Dictionary = part_value as Dictionary
		var plan_id: String = str(part.get("planId", "")).strip_edges()
		if not plan_id.is_empty():
			plan_assistant_entry_ids_by_plan_id[plan_id] = entry_id


func _upsert_connection_status_entry(
	status_text: String,
	title_text: String,
	detail_text: String,
	action_label: String = "",
	action_id: String = ""
) -> void:
	var metadata: Dictionary = {
		"status": status_text,
		"title": title_text,
		"detail": detail_text,
		"action_label": action_label,
		"action_id": action_id
	}

	if connection_status_entry_id.is_empty() or _find_timeline_entry_index(connection_status_entry_id) < 0:
		connection_status_entry_id = _append_timeline_entry(
			"status",
			"",
			detail_text,
			"connection-status-%d" % Time.get_ticks_msec(),
			metadata
		)
	else:
		var index: int = _find_timeline_entry_index(connection_status_entry_id)
		if index >= 0:
			var entry: Dictionary = timeline_entries[index]
			for metadata_key: Variant in metadata.keys():
				entry[str(metadata_key)] = metadata[metadata_key]
			entry["content"] = detail_text
			entry["height_estimate"] = _estimate_timeline_entry_height("status", detail_text)
			entry["height_actual"] = 0.0
			timeline_entries[index] = entry
			_mark_timeline_height_dirty(index)

	var should_follow_bottom: bool = _should_follow_timeline_updates()
	_schedule_timeline_render(should_follow_bottom)


func _append_event_to_timeline(event_name: String, event_data: Dictionary, request_id: String) -> void:
	if event_name == "ai.thinking.delta" or event_name == "agent.thinking.delta":
		var delta_text: String = str(event_data.get("text", ""))
		if delta_text.is_empty():
			return

		if active_thinking_entry_id.is_empty():
			active_thinking_entry_id = _append_timeline_entry("thinking", request_id, "", "thinking:%s" % request_id)

		_update_timeline_entry_content(active_thinking_entry_id, _get_timeline_entry_content(active_thinking_entry_id) + delta_text)
	elif event_name == "ai.thinking.done" or event_name == "agent.thinking.done":
		_set_timeline_entry_collapsed(active_thinking_entry_id, true)
		active_thinking_entry_id = ""
	elif event_name == "tool.call" or event_name == "tool.approval_required" or event_name == "agent.tool.call" or event_name == "agent.tool.approval_required":
		_append_tool_event_to_timeline(_normalize_agent_tool_event_data(event_name, event_data), request_id)
	elif event_name == "tool.progress" or event_name == "tool.result" or event_name == "tool.error" or event_name == "tool.approved" or event_name == "tool.rejected" or event_name == "agent.tool.progress" or event_name == "agent.tool.result" or event_name == "agent.tool.error" or event_name == "agent.tool.approved" or event_name == "agent.tool.rejected":
		_append_tool_event_to_timeline(_normalize_agent_tool_event_data(event_name, event_data), request_id)
	elif event_name == "ai.status":
		_append_timeline_entry(
			"status",
			request_id,
			str(event_data.get("details", event_data.get("detail", ""))),
			"status:%s:%s" % [request_id, str(event_data.get("_eventRecordId", Time.get_ticks_msec()))],
			{
				"status": str(event_data.get("status", "message")),
				"title": str(event_data.get("title", "")),
				"detail": str(event_data.get("details", event_data.get("detail", ""))),
				"action_label": str(event_data.get("actionLabel", event_data.get("action_label", ""))),
				"action_id": str(event_data.get("actionId", event_data.get("action_id", ""))),
				"icon_uid": str(event_data.get("iconUid", event_data.get("icon_uid", "")))
			}
		)
	elif event_name == "plan.generated" or event_name == "plan.revised":
		var plan_part: Dictionary = _create_plan_body_part(event_data)
		if plan_part.is_empty():
			return

		_append_timeline_entry(
			"assistant",
			request_id,
			"",
			"plan:%s:%s" % [request_id, str(event_data.get("planId", ""))],
			{
				"completed_at_utc": MAIN_HELPERS.get_utc_timestamp(),
				"body_parts": [plan_part]
			}
		)
	elif event_name == "plan.clarification.required":
		_append_timeline_entry(
			"status",
			request_id,
			str(event_data.get("question", "")),
			"plan-clarification:%s:%s" % [request_id, str(event_data.get("planId", ""))],
			{
				"status": "message",
				"title": "需要澄清计划",
				"detail": str(event_data.get("question", "")),
				"action_label": "",
				"action_id": "",
				"icon_uid": PLAN_CLARIFICATION_ICON_UID,
				"planId": str(event_data.get("planId", ""))
			}
		)


func _append_tool_event_to_timeline(event_data: Dictionary, request_id: String) -> String:
	var tool_call_id: String = _get_scoped_tool_call_key(event_data, request_id)
	var entry_id: String = active_tool_entry_ids_by_call_id.get(tool_call_id, "")

	if entry_id.is_empty():
		entry_id = _append_timeline_entry("tool", request_id, "", "tool:%s" % tool_call_id)
		active_tool_entry_ids_by_call_id[tool_call_id] = entry_id
		_set_timeline_entry_tool_call_id(entry_id, tool_call_id)

	var index: int = _find_timeline_entry_index(entry_id)
	if index >= 0:
		var entry: Dictionary = timeline_entries[index]
		var events: Array = entry.get("events", []) as Array
		var event_record_id: String = str(event_data.get("_eventRecordId", ""))
		if not event_record_id.is_empty():
			for existing_event_value: Variant in events:
				if typeof(existing_event_value) != TYPE_DICTIONARY:
					continue

				var existing_event: Dictionary = existing_event_value as Dictionary
				if str(existing_event.get("_eventRecordId", "")) == event_record_id:
					return entry_id

		events.append(event_data.duplicate(true))
		entry["events"] = events
		entry["height_estimate"] = _estimate_timeline_entry_height("tool", "")
		var event_type: String = str(event_data.get("type", ""))
		if event_type == "tool.result" or event_type == "tool.error":
			entry["collapsed"] = true
		timeline_entries[index] = entry
		_mark_timeline_height_dirty(index)

	return entry_id


func _set_timeline_entry_tool_call_id(entry_id: String, tool_call_id: String) -> void:
	var index: int = _find_timeline_entry_index(entry_id)
	if index < 0:
		return

	var entry: Dictionary = timeline_entries[index]
	entry["tool_call_id"] = tool_call_id
	timeline_entries[index] = entry


func _set_timeline_entry_collapsed(entry_id: String, collapsed: bool) -> void:
	if entry_id.is_empty():
		return

	var index: int = _find_timeline_entry_index(entry_id)
	if index < 0:
		return

	var entry: Dictionary = timeline_entries[index]
	entry["collapsed"] = collapsed
	timeline_entries[index] = entry
	_mark_timeline_height_dirty(index)


func _set_timeline_entry_times(entry_id: String, started_at_utc: String, completed_at_utc: String) -> void:
	if entry_id.is_empty():
		return

	var index: int = _find_timeline_entry_index(entry_id)
	if index < 0:
		return

	var entry: Dictionary = timeline_entries[index]
	if not started_at_utc.strip_edges().is_empty():
		entry["started_at_utc"] = started_at_utc
	if not completed_at_utc.strip_edges().is_empty():
		entry["completed_at_utc"] = completed_at_utc
	timeline_entries[index] = entry
	_mark_timeline_height_dirty(index)


func _get_timeline_entry_content(entry_id: String) -> String:
	var index: int = _find_timeline_entry_index(entry_id)
	if index < 0:
		return ""

	var entry: Dictionary = timeline_entries[index]
	return str(entry.get("content", ""))


func _update_timeline_entry_content(entry_id: String, content: String) -> void:
	var index: int = _find_timeline_entry_index(entry_id)
	if index < 0:
		return

	var entry: Dictionary = timeline_entries[index]
	entry["content"] = content
	entry["height_estimate"] = _estimate_timeline_entry_height(str(entry.get("type", "")), content)
	entry["height_actual"] = 0.0
	timeline_entries[index] = entry
	_mark_timeline_height_dirty(index)


func _append_assistant_delta_to_timeline(entry_id: String, delta_text: String, preserve_stream_height: bool = false) -> void:
	var index: int = _find_timeline_entry_index(entry_id)
	if index < 0 or delta_text.is_empty():
		return

	var entry: Dictionary = timeline_entries[index]
	var next_content: String = str(entry.get("content", "")) + delta_text
	entry["content"] = next_content
	var body_parts: Array = entry.get("body_parts", []) as Array
	var should_add_markdown_part: bool = body_parts.is_empty()
	if not should_add_markdown_part:
		var last_part_value: Variant = body_parts[body_parts.size() - 1]
		should_add_markdown_part = typeof(last_part_value) != TYPE_DICTIONARY or str((last_part_value as Dictionary).get("type", "")) != "markdown"

	if should_add_markdown_part:
		body_parts.append({
			"type": "markdown",
			"text": delta_text
		})
	else:
		var part: Dictionary = body_parts[body_parts.size() - 1] as Dictionary
		part["text"] = str(part.get("text", "")) + delta_text
		body_parts[body_parts.size() - 1] = part

	entry["body_parts"] = body_parts
	if preserve_stream_height:
		timeline_entries[index] = entry
		return

	entry["height_estimate"] = _estimate_timeline_entry_height(str(entry.get("type", "")), next_content)
	entry["height_actual"] = 0.0
	timeline_entries[index] = entry
	_mark_timeline_height_dirty(index)


func _find_timeline_entry_index(entry_id: String) -> int:
	if entry_id.is_empty():
		return -1

	if timeline_entry_indices_by_id.has(entry_id):
		var cached_index: int = int(timeline_entry_indices_by_id[entry_id])
		if cached_index >= 0 and cached_index < timeline_entries.size():
			var cached_entry: Dictionary = timeline_entries[cached_index]
			if str(cached_entry.get("id", "")) == entry_id:
				return cached_index

	for index: int in range(timeline_entries.size()):
		var entry: Dictionary = timeline_entries[index]
		if str(entry.get("id", "")) == entry_id:
			timeline_entry_indices_by_id[entry_id] = index
			return index

	return -1

# --- timeline_virtual_controller.gd ---

func _rebuild_timeline_index_cache() -> void:
	timeline_entry_ids.clear()
	timeline_entry_indices_by_id.clear()
	active_tool_entry_ids_by_call_id.clear()
	for index: int in range(timeline_entries.size()):
		var entry: Dictionary = timeline_entries[index]
		var entry_id: String = str(entry.get("id", ""))
		if entry_id.is_empty():
			continue

		timeline_entry_ids[entry_id] = true
		timeline_entry_indices_by_id[entry_id] = index
		var tool_call_id: String = str(entry.get("tool_call_id", ""))
		if not tool_call_id.is_empty():
			active_tool_entry_ids_by_call_id[tool_call_id] = entry_id

# timeline_virtual_controller.gd

func _get_timeline_render_hint_height(block: Dictionary) -> float:
	var render_hints_value: Variant = block.get("renderHints", {})
	if typeof(render_hints_value) != TYPE_DICTIONARY:
		return 0.0

	var render_hints: Dictionary = render_hints_value as Dictionary
	var estimated_height: float = float(render_hints.get("estimatedHeight", 0.0))
	return max(0.0, estimated_height)


func _is_timeline_entry_protected_from_unload(entry_id: String) -> bool:
	if entry_id.is_empty():
		return false
	if not active_stream_id.is_empty() and entry_id == active_assistant_entry_id:
		return true
	if not active_stream_id.is_empty() and entry_id == active_thinking_entry_id:
		return true

	return false


func _get_timeline_entry_pool_type(entry_type: String) -> String:
	if entry_type == "user" or entry_type == "assistant" or entry_type == "thinking" or entry_type == "tool" or entry_type == "status":
		return entry_type

	return "assistant"


func _take_timeline_node_from_pool(entry_type: String) -> Node:
	var pool_type: String = _get_timeline_entry_pool_type(entry_type)
	if not timeline_node_pools_by_type.has(pool_type):
		return null

	var node_pool: Array = timeline_node_pools_by_type[pool_type]
	while not node_pool.is_empty():
		var node_value: Variant = node_pool.pop_back()
		var node: Node = node_value as Node
		if node != null and is_instance_valid(node):
			node.visible = true
			return node

	return null


func _recycle_rendered_timeline_node(entry_id: String, entry: Dictionary) -> void:
	if entry_id.is_empty() or not rendered_entry_nodes.has(entry_id):
		return

	var node: Node = rendered_entry_nodes.get(entry_id, null) as Node
	if node != null and is_instance_valid(node):
		if node.get_parent() == timeline_visible_container:
			timeline_visible_container.remove_child(node)

		var entry_type: String = str(entry.get("type", ""))
		var pool_type: String = _get_timeline_entry_pool_type(entry_type)
		var node_pool: Array = timeline_node_pools_by_type.get(pool_type, []) as Array
		if node_pool.size() < TIMELINE_NODE_POOL_LIMIT_PER_TYPE:
			_disconnect_timeline_node_signals(node)
			node.visible = false
			node_pool.append(node)
			timeline_node_pools_by_type[pool_type] = node_pool
		else:
			node.queue_free()

	var tool_call_id: String = str(entry.get("tool_call_id", ""))
	if not tool_call_id.is_empty() and tool_items_by_call_id.get(tool_call_id, null) == node:
		tool_items_by_call_id.erase(tool_call_id)
	if entry_id == active_assistant_entry_id:
		active_assistant_item = null
	if entry_id == active_thinking_entry_id:
		active_thinking_item = null

	rendered_entry_nodes.erase(entry_id)
	rendered_entry_indices.erase(entry_id)


func _recycle_all_rendered_timeline_nodes() -> void:
	for entry_id: String in rendered_entry_nodes.keys():
		var index: int = int(rendered_entry_indices.get(entry_id, _find_timeline_entry_index(entry_id)))
		var entry: Dictionary = {}
		if index >= 0 and index < timeline_entries.size():
			entry = timeline_entries[index]
		_recycle_rendered_timeline_node(entry_id, entry)


func _clear_timeline_node_pools() -> void:
	for node_pool_value: Variant in timeline_node_pools_by_type.values():
		if typeof(node_pool_value) != TYPE_ARRAY:
			continue

		var node_pool: Array = node_pool_value as Array
		for node_value: Variant in node_pool:
			var node: Node = node_value as Node
			if node != null and is_instance_valid(node):
				node.queue_free()

	timeline_node_pools_by_type.clear()


func _disconnect_timeline_node_signals(node: Node) -> void:
	var signal_names: PackedStringArray = [
		"content_height_changed",
		"resend_requested",
		"action_requested",
		"inline_diff_undo_requested",
		"plan_details_requested"
	]
	for signal_name: String in signal_names:
		if not node.has_signal(signal_name):
			continue

		var connections: Array = node.get_signal_connection_list(signal_name)
		for connection_value: Variant in connections:
			if typeof(connection_value) != TYPE_DICTIONARY:
				continue

			var connection: Dictionary = connection_value as Dictionary
			var callable_value: Variant = connection.get("callable", Callable())
			if typeof(callable_value) != TYPE_CALLABLE:
				continue

			var signal_callable: Callable = callable_value as Callable
			if signal_callable.is_valid():
				node.disconnect(signal_name, signal_callable)


func _estimate_timeline_entry_height(entry_type: String, content: String) -> float:
	var line_count: int = max(1, content.count("\n") + 1)
	var text_rows: int = max(line_count, int(ceil(float(content.length()) / 72.0)))

	if entry_type == "user":
		return max(TIMELINE_ESTIMATED_USER_HEIGHT, 44.0 + float(text_rows * 20))
	if entry_type == "assistant":
		return max(TIMELINE_ESTIMATED_ASSISTANT_HEIGHT, 52.0 + float(text_rows * 22))
	if entry_type == "thinking":
		return TIMELINE_ESTIMATED_THINKING_HEIGHT
	if entry_type == "tool":
		return TIMELINE_ESTIMATED_TOOL_HEIGHT
	if entry_type == "status":
		return TIMELINE_ESTIMATED_STATUS_HEIGHT

	return 96.0


func _get_entry_cached_height(entry: Dictionary) -> float:
	var actual_height: float = float(entry.get("height_actual", 0.0))
	if actual_height > 0.0:
		return max(TIMELINE_MIN_ITEM_HEIGHT, actual_height)

	return max(TIMELINE_MIN_ITEM_HEIGHT, float(entry.get("height_estimate", TIMELINE_ESTIMATED_ASSISTANT_HEIGHT)))


func _mark_timeline_height_dirty(index: int = -1) -> void:
	if index >= 0 and index < timeline_entries.size() and index < timeline_heights.size():
		timeline_heights[index] = _get_entry_cached_height(timeline_entries[index])
	if index >= 0:
		timeline_dirty_height_start_index = index if timeline_dirty_height_start_index < 0 else mini(timeline_dirty_height_start_index, index)
	else:
		timeline_dirty_height_start_index = 0
	timeline_heights_dirty = true


func _rebuild_timeline_height_cache() -> void:
	var needs_full_rebuild: bool = timeline_heights.size() != timeline_entries.size() or timeline_prefix_heights.size() != timeline_entries.size() + 1 or timeline_dirty_height_start_index <= 0
	if needs_full_rebuild:
		timeline_heights.clear()
		timeline_prefix_heights.clear()

		var running_height: float = 0.0
		timeline_prefix_heights.append(0.0)
		for entry: Dictionary in timeline_entries:
			var entry_height: float = _get_entry_cached_height(entry)
			timeline_heights.append(entry_height)
			running_height += entry_height
			timeline_prefix_heights.append(running_height)
	else:
		var start_index: int = clampi(timeline_dirty_height_start_index, 0, timeline_entries.size() - 1)
		var running_height: float = float(timeline_prefix_heights[start_index])
		for index: int in range(start_index, timeline_entries.size()):
			var entry: Dictionary = timeline_entries[index]
			var entry_height: float = _get_entry_cached_height(entry)
			timeline_heights[index] = entry_height
			running_height += entry_height
			timeline_prefix_heights[index + 1] = running_height

	timeline_heights_dirty = false
	timeline_dirty_height_start_index = -1


func _ensure_timeline_height_cache() -> void:
	if timeline_heights_dirty or timeline_heights.size() != timeline_entries.size() or timeline_prefix_heights.size() != timeline_entries.size() + 1:
		_rebuild_timeline_height_cache()


func _get_timeline_entry_height(index: int) -> float:
	if index < 0 or index >= timeline_entries.size():
		return 0.0

	_ensure_timeline_height_cache()
	return timeline_heights[index]


func _get_timeline_total_height() -> float:
	_ensure_timeline_height_cache()
	return timeline_prefix_heights[timeline_prefix_heights.size() - 1]


func _schedule_timeline_render(scroll_to_bottom: bool) -> void:
	timeline_scroll_to_bottom_queued = timeline_scroll_to_bottom_queued or scroll_to_bottom
	if timeline_render_queued:
		return

	timeline_render_queued = true
	_deferred_render_visible_timeline()


func _deferred_render_visible_timeline() -> void:
	await get_tree().process_frame
	var should_scroll_to_bottom: bool = timeline_scroll_to_bottom_queued
	timeline_render_queued = false
	timeline_scroll_to_bottom_queued = false
	_render_visible_timeline(should_scroll_to_bottom)


func _render_visible_timeline(scroll_to_bottom: bool) -> void:
	_setup_timeline_containers()

	if timeline_entries.is_empty():
		for child: Node in timeline_visible_container.get_children():
			child.queue_free()
		rendered_entry_nodes.clear()
		rendered_entry_indices.clear()
		timeline_top_spacer.custom_minimum_size = Vector2(0.0, 0.0)
		timeline_bottom_spacer.custom_minimum_size = Vector2(0.0, 0.0)
		return

	var viewport_height: float = max(1.0, scroll_container.size.y)
	var total_height: float = _get_timeline_total_height()
	var viewport_top: float = scroll_container.scroll_vertical
	if scroll_to_bottom:
		viewport_top = max(0.0, total_height - viewport_height)
		scroll_container.scroll_vertical = int(round(viewport_top))
		timeline_follow_bottom = true

	var viewport_bottom: float = viewport_top + viewport_height
	var first_index: int = _find_timeline_index_at_offset(viewport_top)
	var last_index: int = _find_timeline_index_at_offset(viewport_bottom)
	var start_index: int = maxi(0, first_index - TIMELINE_BUFFER_ITEMS)
	var end_index: int = mini(timeline_entries.size() - 1, last_index + TIMELINE_BUFFER_ITEMS)

	_sync_rendered_timeline_range(start_index, end_index)
	_update_timeline_spacers(start_index, end_index)
	_schedule_timeline_measure()

	if scroll_to_bottom:
		_scroll_timeline_to_bottom_deferred()


func _find_timeline_index_at_offset(offset: float) -> int:
	_ensure_timeline_height_cache()
	if timeline_entries.is_empty():
		return 0

	var low: int = 0
	var high: int = timeline_entries.size()
	while low < high:
		var mid: int = int((low + high) / 2)
		if timeline_prefix_heights[mid + 1] < offset:
			low = mid + 1
		else:
			high = mid

	return clampi(low, 0, timeline_entries.size() - 1)


func _sync_rendered_timeline_range(start_index: int, end_index: int) -> void:
	var wanted_ids: Dictionary[String, bool] = {}
	var created_count: int = 0
	var render_incomplete: bool = false
	for index: int in range(start_index, end_index + 1):
		var entry: Dictionary = timeline_entries[index]
		var entry_id: String = str(entry.get("id", ""))
		wanted_ids[entry_id] = true
		if not rendered_entry_nodes.has(entry_id):
			if created_count >= TIMELINE_RENDER_BUDGET_PER_FRAME:
				render_incomplete = true
				continue

			var node: Node = _instantiate_timeline_entry_node(entry, index)
			rendered_entry_nodes[entry_id] = node
			rendered_entry_indices[entry_id] = index
			timeline_visible_container.add_child(node)
			_configure_timeline_entry_node(node, entry, index)
			created_count += 1
		else:
			rendered_entry_indices[entry_id] = index

	if _is_timeline_entry_protected_from_unload(active_assistant_entry_id):
		wanted_ids[active_assistant_entry_id] = true
	if _is_timeline_entry_protected_from_unload(active_thinking_entry_id):
		wanted_ids[active_thinking_entry_id] = true

	for entry_id: String in rendered_entry_nodes.keys():
		if wanted_ids.has(entry_id):
			continue

		var old_index: int = int(rendered_entry_indices.get(entry_id, -1))
		var old_entry: Dictionary = {}
		if old_index >= 0 and old_index < timeline_entries.size():
			old_entry = timeline_entries[old_index]
		_recycle_rendered_timeline_node(entry_id, old_entry)

	var child_order: int = 0
	for index: int in range(start_index, end_index + 1):
		var entry: Dictionary = timeline_entries[index]
		var entry_id: String = str(entry.get("id", ""))
		var node: Node = rendered_entry_nodes.get(entry_id, null) as Node
		if node != null:
			timeline_visible_container.move_child(node, child_order)
			child_order += 1

	if render_incomplete:
		_schedule_timeline_render(false)


func _instantiate_timeline_entry_node(entry: Dictionary, index: int) -> Node:
	var entry_type: String = str(entry.get("type", ""))
	var node: Node = _take_timeline_node_from_pool(entry_type)

	if node == null:
		if entry_type == "user":
			node = USER_MESSAGE_ITEM_SCENE.instantiate()
		elif entry_type == "assistant":
			node = ASSISTANT_MARKDOWN_ITEM_SCENE.instantiate()
		elif entry_type == "thinking":
			node = TOOL_CALL_ITEM_SCENE.instantiate()
		elif entry_type == "tool":
			node = TOOL_CALL_ITEM_SCENE.instantiate()
		elif entry_type == "status":
			node = STATUS_ITEM_SCENE.instantiate()
		else:
			node = ASSISTANT_MARKDOWN_ITEM_SCENE.instantiate()

	if node is Control:
		var control: Control = node as Control
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var entry_id: String = str(entry.get("id", ""))
	if entry_id == active_assistant_entry_id:
		active_assistant_item = node
	elif entry_id == active_thinking_entry_id:
		active_thinking_item = node

	rendered_entry_indices[entry_id] = index
	return node


func _configure_timeline_entry_node(node: Node, entry: Dictionary, _index: int) -> void:
	var entry_type: String = str(entry.get("type", ""))

	if entry_type == "user":
		node.call("setup", str(entry.get("content", "")), str(entry.get("request_id", "")), str(entry.get("sent_at_utc", "")), entry.get("additional_context", []))
		if node.has_signal("resend_requested") and not node.is_connected("resend_requested", Callable(self, "_on_user_message_resend_requested")):
			node.connect("resend_requested", Callable(self, "_on_user_message_resend_requested"))
	elif entry_type == "assistant":
		node.call(
			"setup",
			str(entry.get("content", "")),
			str(entry.get("started_at_utc", "")),
			str(entry.get("completed_at_utc", "")),
			entry.get("body_parts", [])
		)
		if node.has_signal("action_requested") and not node.is_connected("action_requested", Callable(self, "_on_status_item_action_requested")):
			node.connect("action_requested", Callable(self, "_on_status_item_action_requested"))
		if node.has_signal("inline_diff_undo_requested") and not node.is_connected("inline_diff_undo_requested", file_edit_controller.undo_inline_diff):
			node.connect("inline_diff_undo_requested", file_edit_controller.undo_inline_diff)
		if node.has_signal("plan_details_requested") and not node.is_connected("plan_details_requested", Callable(self, "_on_plan_details_requested")):
			node.connect("plan_details_requested", Callable(self, "_on_plan_details_requested"))
	elif entry_type == "thinking":
		node.call("setup_thinking")
		var content: String = str(entry.get("content", ""))
		if not content.is_empty():
			node.call("append_thinking_delta", content)
		if bool(entry.get("collapsed", true)):
			node.call("finish_thinking")
	elif entry_type == "tool":
		_setup_tool_node_from_entry(node, entry)
		var tool_call_id: String = str(entry.get("tool_call_id", ""))
		if not tool_call_id.is_empty():
			tool_items_by_call_id[tool_call_id] = node
	elif entry_type == "status":
		node.call(
			"setup",
			str(entry.get("status", "message")),
			str(entry.get("title", "")),
			str(entry.get("detail", "")),
			str(entry.get("action_label", "")),
			str(entry.get("action_id", "")),
			str(entry.get("icon_uid", ""))
		)
		if node.has_signal("action_requested") and not node.is_connected("action_requested", Callable(self, "_on_status_item_action_requested")):
			node.connect("action_requested", Callable(self, "_on_status_item_action_requested"))
	else:
		node.call("setup", str(entry.get("content", "")))

	var entry_id: String = str(entry.get("id", ""))
	if node.has_signal("content_height_changed") and not node.is_connected("content_height_changed", _on_timeline_node_content_height_changed):
		node.connect("content_height_changed", _on_timeline_node_content_height_changed.bind(entry_id))


func _setup_tool_node_from_entry(node: Node, entry: Dictionary) -> void:
	var events: Array = entry.get("events", []) as Array
	if events.is_empty():
		node.call("setup", "Tool", "")
		return

	for index: int in range(events.size()):
		var event_value: Variant = events[index]
		if typeof(event_value) != TYPE_DICTIONARY:
			continue

		var event_data: Dictionary = event_value as Dictionary
		if index == 0:
			node.call("setup_tool_event", event_data)
		else:
			node.call("append_tool_event", event_data)


func _on_timeline_node_content_height_changed(entry_id: String) -> void:
	var index: int = _find_timeline_entry_index(entry_id)
	if index >= 0:
		var entry: Dictionary = timeline_entries[index]
		entry["height_actual"] = 0.0
		timeline_entries[index] = entry
		_mark_timeline_height_dirty(index)
	_schedule_timeline_measure()


func _update_timeline_spacers(start_index: int, end_index: int) -> void:
	_ensure_timeline_height_cache()
	var top_height: float = timeline_prefix_heights[start_index]
	var bottom_height: float = timeline_prefix_heights[timeline_prefix_heights.size() - 1] - timeline_prefix_heights[end_index + 1]

	timeline_top_spacer.custom_minimum_size = Vector2(0.0, top_height)
	timeline_bottom_spacer.custom_minimum_size = Vector2(0.0, bottom_height)


func _schedule_timeline_measure() -> void:
	var now_msec: int = Time.get_ticks_msec()
	if timeline_measure_after_msec <= now_msec:
		timeline_measure_after_msec = now_msec + TIMELINE_MEASURE_INTERVAL_MSEC
	if timeline_measure_queued:
		return

	timeline_measure_queued = true
	_deferred_measure_timeline_items()


func _deferred_measure_timeline_items() -> void:
	await get_tree().process_frame
	var delay_msec: int = timeline_measure_after_msec - Time.get_ticks_msec()
	if delay_msec > 0:
		await get_tree().create_timer(float(delay_msec) / 1000.0).timeout
	timeline_measure_queued = false

	var changed: bool = false
	var render_required: bool = false
	for entry_id: String in rendered_entry_nodes.keys():
		var node: Node = rendered_entry_nodes.get(entry_id, null) as Node
		if not (node is Control):
			continue

		var index: int = _find_timeline_entry_index(entry_id)
		if index < 0:
			continue

		var control: Control = node as Control
		var measured_height: float = max(TIMELINE_MIN_ITEM_HEIGHT, control.size.y)
		var entry: Dictionary = timeline_entries[index]
		var previous_height: float = float(entry.get("height_actual", 0.0))
		if abs(previous_height - measured_height) <= 1.0:
			continue

		entry["height_actual"] = measured_height
		timeline_entries[index] = entry
		_mark_timeline_height_dirty(index)
		changed = true
		if entry_id != active_assistant_entry_id or active_stream_id.is_empty():
			render_required = true

	if changed:
		var scroll_anchor: Dictionary[String, Variant] = _capture_timeline_scroll_anchor()
		var should_follow_bottom: bool = _should_follow_timeline_updates()
		_rebuild_timeline_height_cache()
		if render_required:
			_render_visible_timeline(should_follow_bottom)
			if not should_follow_bottom:
				_restore_timeline_scroll_anchor(scroll_anchor)
		elif should_follow_bottom:
			_scroll_timeline_to_bottom_deferred()


func _capture_timeline_scroll_anchor() -> Dictionary[String, Variant]:
	if timeline_entries.is_empty():
		return {}

	_ensure_timeline_height_cache()
	var anchor_index: int = _find_timeline_index_at_offset(float(scroll_container.scroll_vertical))
	var anchor_entry: Dictionary = timeline_entries[anchor_index]
	var anchor_entry_id: String = str(anchor_entry.get("id", ""))
	if anchor_entry_id.is_empty():
		return {}

	return {
		"entry_id": anchor_entry_id,
		"offset": float(scroll_container.scroll_vertical) - timeline_prefix_heights[anchor_index]
	}


func _restore_timeline_scroll_anchor(scroll_anchor: Dictionary[String, Variant]) -> void:
	var anchor_entry_id: String = str(scroll_anchor.get("entry_id", ""))
	if anchor_entry_id.is_empty():
		return

	var anchor_index: int = _find_timeline_entry_index(anchor_entry_id)
	if anchor_index < 0:
		return

	_ensure_timeline_height_cache()
	var anchor_offset: float = float(scroll_anchor.get("offset", 0.0))
	var next_scroll: float = max(0.0, timeline_prefix_heights[anchor_index] + anchor_offset)
	scroll_container.scroll_vertical = int(round(next_scroll))


func _scroll_timeline_to_bottom_deferred() -> void:
	timeline_deferred_scroll_version += 1
	if timeline_deferred_scroll_queued:
		return

	timeline_deferred_scroll_queued = true
	var scroll_version: int = timeline_deferred_scroll_version
	await get_tree().process_frame
	await get_tree().process_frame
	if scroll_version != timeline_deferred_scroll_version:
		timeline_deferred_scroll_queued = false
		return

	timeline_deferred_scroll_queued = false
	if not timeline_follow_bottom:
		return

	scroll_container.scroll_vertical = int(round(_get_timeline_bottom_scroll()))


func _is_timeline_near_bottom() -> bool:
	var bar: VScrollBar = scroll_container.get_v_scroll_bar()
	if bar == null:
		return true
	if not bar.is_visible_in_tree():
		return true

	return float(scroll_container.scroll_vertical) >= _get_timeline_bottom_scroll() - TIMELINE_BOTTOM_FOLLOW_THRESHOLD


func _get_timeline_bottom_scroll() -> float:
	var bar: VScrollBar = scroll_container.get_v_scroll_bar()
	if bar == null:
		return 0.0

	return max(0.0, bar.max_value - bar.page)


func _should_follow_timeline_updates() -> bool:
	return timeline_follow_bottom or _is_timeline_near_bottom()


func _scroll_to_bottom_if_following(should_follow_bottom: bool) -> void:
	if not should_follow_bottom:
		return

	timeline_follow_bottom = true
	_scroll_timeline_to_bottom_deferred()

# --- timeline_stream_controller.gd ---

# --- timeline_stream_controller.gd ---
func _add_user_message_item(message_text: String) -> void:
	var should_follow_bottom: bool = _should_follow_timeline_updates()
	var sent_at_utc: String = MAIN_HELPERS.get_utc_timestamp()
	if active_stream_started_at_utc.is_empty():
		active_stream_started_at_utc = sent_at_utc
	_append_timeline_entry("user", active_stream_request_id, message_text, "", { "sent_at_utc": sent_at_utc })
	_schedule_timeline_render(should_follow_bottom)


func _add_assistant_message_item(message_text: String) -> void:
	var should_follow_bottom: bool = _should_follow_timeline_updates()
	var completed_at_utc: String = MAIN_HELPERS.get_utc_timestamp()
	var metadata: Dictionary = { "completed_at_utc": completed_at_utc }
	if not active_stream_started_at_utc.is_empty():
		metadata["started_at_utc"] = active_stream_started_at_utc
	var entry_id: String = _append_timeline_entry("assistant", active_stream_request_id, message_text, "", metadata)
	active_assistant_entry_id = entry_id
	_schedule_timeline_render(should_follow_bottom)


func _ensure_active_assistant_item() -> void:
	if not active_assistant_entry_id.is_empty():
		active_assistant_item = rendered_entry_nodes.get(active_assistant_entry_id, null) as Node
		return

	var should_follow_bottom: bool = _should_follow_timeline_updates()
	var metadata: Dictionary = {}
	if not active_stream_started_at_utc.is_empty():
		metadata["started_at_utc"] = active_stream_started_at_utc
	active_assistant_entry_id = _append_timeline_entry("assistant", active_stream_request_id, "", "", metadata)
	_schedule_timeline_render(should_follow_bottom)
	active_assistant_item = rendered_entry_nodes.get(active_assistant_entry_id, null) as Node


func _schedule_assistant_delta_flush() -> void:
	var now_msec: int = Time.get_ticks_msec()
	if pending_assistant_delta_flush_at_msec <= now_msec:
		pending_assistant_delta_flush_at_msec = now_msec + DELTA_FLUSH_INTERVAL_MSEC
	if pending_assistant_delta_queued:
		return

	pending_assistant_delta_queued = true
	_deferred_flush_pending_assistant_delta()


func _deferred_flush_pending_assistant_delta() -> void:
	var delay_msec: int = pending_assistant_delta_flush_at_msec - Time.get_ticks_msec()
	if delay_msec > 0:
		await get_tree().create_timer(float(delay_msec) / 1000.0).timeout
	pending_assistant_delta_queued = false
	pending_assistant_delta_flush_at_msec = 0
	_flush_pending_assistant_delta()


func _flush_pending_assistant_delta() -> void:
	if pending_assistant_delta_text.is_empty() or active_assistant_entry_id.is_empty():
		return

	var should_follow_bottom: bool = _should_follow_timeline_updates()
	var delta_text: String = pending_assistant_delta_text
	pending_assistant_delta_text = ""
	var active_entry_rendered: bool = rendered_entry_nodes.has(active_assistant_entry_id)
	_append_assistant_delta_to_timeline(active_assistant_entry_id, delta_text, active_entry_rendered)

	active_assistant_item = rendered_entry_nodes.get(active_assistant_entry_id, null) as Node
	if active_assistant_item != null:
		active_assistant_item.call("append_delta", delta_text)
		_schedule_timeline_measure()
		_scroll_to_bottom_if_following(should_follow_bottom)
		return

	_schedule_timeline_render(should_follow_bottom)


func _show_response_error(message: Dictionary) -> void:
	var should_follow_bottom: bool = _should_follow_timeline_updates()
	var error_value: Variant = message.get("error", {})
	var error_message: String = "Unknown backend error"
	var error_code: String = ""
	if typeof(error_value) == TYPE_DICTIONARY:
		var error_dictionary: Dictionary = error_value as Dictionary
		error_message = str(error_dictionary.get("message", error_message))
		error_code = str(error_dictionary.get("code", ""))

	if not error_code.is_empty() and error_code == active_stream_status_code:
		if active_assistant_item != null:
			active_assistant_item.call("finish_message")
		_schedule_timeline_render(should_follow_bottom)
		_scroll_to_bottom_if_following(should_follow_bottom)
		return

	if error_code == "editor_target_required" or error_message.contains("editor_target_required"):
		_append_assistant_status_event({
			"status": "warning",
			"title": "需要选择目标 Godot 编辑器",
			"details": "同一 workspace 有多个 Godot 编辑器在线。请在目标 Godot 插件中继续当前会话，或等待前端选择器绑定 editorInstanceId 后重试。",
			"code": "editor_target_required"
		})
		if active_assistant_item != null:
			active_assistant_item.call("finish_message")
		return

	if error_code == "provider_quota_exhausted":
		_append_assistant_status_event({
			"status": "error",
			"title": "模型额度不足",
			"details": "模型供应商返回额度或余额不足，当前回复已停止。请检查账户余额、套餐额度或切换可用的 API Key 后重试。",
			"actionLabel": "Open settings",
			"actionId": "provider-settings",
			"code": error_code
		})
		if active_assistant_item != null:
			active_assistant_item.call("finish_message")
		return

	if active_assistant_item != null:
		var error_delta: String = "\n\n后端返回错误：%s" % error_message
		if not active_assistant_entry_id.is_empty():
			_append_assistant_delta_to_timeline(active_assistant_entry_id, error_delta)
		active_assistant_item.call("append_delta", error_delta)
		active_assistant_item.call("finish_message")
	elif not active_assistant_entry_id.is_empty():
		_update_timeline_entry_content(active_assistant_entry_id, _get_timeline_entry_content(active_assistant_entry_id) + "\n\n后端返回错误：%s" % error_message)
	else:
		_add_assistant_message_item("后端返回错误：%s" % error_message)

	_schedule_timeline_render(should_follow_bottom)
	_scroll_to_bottom_if_following(should_follow_bottom)


func _add_system_tool_item(title_text: String, detail_text: String) -> void:
	var should_follow_bottom: bool = _should_follow_timeline_updates()
	var entry_id: String = _append_timeline_entry("tool", active_stream_request_id, "")
	var index: int = _find_timeline_entry_index(entry_id)
	if index >= 0:
		var entry: Dictionary = timeline_entries[index]
		entry["events"] = [{
			"type": "tool.call",
			"title": title_text,
			"summary": detail_text,
			"toolCallId": entry_id,
			"toolName": title_text
		}]
		timeline_entries[index] = entry
	_schedule_timeline_render(should_follow_bottom)
	_scroll_to_bottom_if_following(should_follow_bottom)


func _add_tool_event(event_data: Dictionary) -> void:
	var should_follow_bottom: bool = _should_follow_timeline_updates()
	_flush_pending_assistant_delta()
	var item: Node = _append_active_assistant_tool_event(event_data, true)
	var tool_call_id: String = _get_scoped_tool_call_key(event_data, active_stream_request_id)
	if item != null:
		tool_items_by_call_id[tool_call_id] = item

	_schedule_timeline_render(should_follow_bottom)
	_scroll_to_bottom_if_following(should_follow_bottom)


func _append_tool_event(event_data: Dictionary) -> void:
	var should_follow_bottom: bool = _should_follow_timeline_updates()
	var tool_call_id: String = _get_scoped_tool_call_key(event_data, active_stream_request_id)
	var entry_id: String = active_tool_entry_ids_by_call_id.get(tool_call_id, "")
	if entry_id.is_empty():
		_add_tool_event(event_data)
		return

	var item: Node
	if entry_id == active_assistant_entry_id:
		item = _append_active_assistant_tool_event(event_data, false)
	else:
		_append_tool_event_to_timeline(event_data, active_stream_request_id)
		item = rendered_entry_nodes.get(entry_id, null) as Node
	if item != null:
		if entry_id != active_assistant_entry_id:
			item.call("append_tool_event", event_data)
		_scroll_to_bottom_if_following(should_follow_bottom)

	_schedule_timeline_render(should_follow_bottom)


func _append_active_assistant_tool_event(event_data: Dictionary, create_if_missing: bool) -> Node:
	_ensure_active_assistant_item()
	if active_assistant_entry_id.is_empty():
		return null

	var scoped_tool_call_id: String = _get_scoped_tool_call_key(event_data, active_stream_request_id)
	_append_assistant_tool_event_to_timeline(active_assistant_entry_id, event_data, active_stream_request_id)
	active_tool_entry_ids_by_call_id[scoped_tool_call_id] = active_assistant_entry_id

	active_assistant_item = rendered_entry_nodes.get(active_assistant_entry_id, null) as Node
	if active_assistant_item == null:
		return null

	var local_tool_call_id: String = _get_tool_call_key(event_data)
	var item: Node = active_assistant_item.call("get_tool_item", local_tool_call_id) as Node
	if item == null and create_if_missing:
		item = active_assistant_item.call("add_tool_event", event_data) as Node
	elif item != null:
		item.call("append_tool_event", event_data)
	else:
		item = active_assistant_item.call("add_tool_event", event_data) as Node

	return item


func _append_assistant_tool_event_to_timeline(entry_id: String, event_data: Dictionary, request_id: String) -> void:
	var index: int = _find_timeline_entry_index(entry_id)
	if index < 0:
		return

	var entry: Dictionary = timeline_entries[index]
	var body_parts: Array = entry.get("body_parts", []) as Array
	_append_tool_event_to_body_parts(body_parts, event_data, request_id)
	entry["body_parts"] = body_parts
	entry["height_actual"] = 0.0
	timeline_entries[index] = entry
	_mark_timeline_height_dirty(index)


func _append_assistant_status_to_timeline(entry_id: String, status_data: Dictionary) -> void:
	var index: int = _find_timeline_entry_index(entry_id)
	if index < 0:
		return

	var entry: Dictionary = timeline_entries[index]
	var body_parts: Array = entry.get("body_parts", []) as Array
	_append_status_event_to_body_parts(body_parts, status_data)
	entry["body_parts"] = body_parts
	entry["height_actual"] = 0.0
	timeline_entries[index] = entry
	_remember_plan_entry_from_body_parts(entry_id, body_parts)
	_mark_timeline_height_dirty(index)


func _append_assistant_summary_start_to_timeline(entry_id: String, summary_data: Dictionary) -> void:
	var index: int = _find_timeline_entry_index(entry_id)
	if index < 0:
		return

	var entry: Dictionary = timeline_entries[index]
	var body_parts: Array = entry.get("body_parts", []) as Array
	_append_summary_start_to_body_parts(body_parts, summary_data)
	entry["body_parts"] = body_parts
	entry["height_actual"] = 0.0
	timeline_entries[index] = entry
	_mark_timeline_height_dirty(index)


func _begin_active_assistant_summary(summary_data: Dictionary) -> void:
	var should_follow_bottom: bool = _should_follow_timeline_updates()
	_flush_pending_assistant_delta()
	_flush_pending_thinking_delta()
	_ensure_active_assistant_item()
	if active_assistant_entry_id.is_empty():
		return

	_append_assistant_summary_start_to_timeline(active_assistant_entry_id, summary_data)
	active_assistant_item = rendered_entry_nodes.get(active_assistant_entry_id, null) as Node
	if active_assistant_item != null:
		active_assistant_item.call("begin_summary", summary_data)
		_schedule_timeline_measure()
		_scroll_to_bottom_if_following(should_follow_bottom)
		return

	_schedule_timeline_render(should_follow_bottom)


func _append_assistant_status_event(status_data: Dictionary) -> void:
	var should_follow_bottom: bool = _should_follow_timeline_updates()
	_flush_pending_assistant_delta()
	_ensure_active_assistant_item()
	active_stream_status_code = str(status_data.get("code", ""))
	if not active_assistant_entry_id.is_empty():
		_append_assistant_status_to_timeline(active_assistant_entry_id, status_data)

	active_assistant_item = rendered_entry_nodes.get(active_assistant_entry_id, null) as Node
	if active_assistant_item != null:
		active_assistant_item.call("add_status", status_data)
		_schedule_timeline_measure()
		_scroll_to_bottom_if_following(should_follow_bottom)
		return

	_schedule_timeline_render(should_follow_bottom)


func _ensure_active_assistant_thinking_item() -> Node:
	_ensure_active_assistant_item()
	if active_assistant_entry_id.is_empty():
		return null

	if active_thinking_entry_id.is_empty():
		active_thinking_entry_id = "thinking:%s:%d" % [active_stream_request_id, Time.get_ticks_msec()]
		_append_assistant_thinking_to_timeline(active_assistant_entry_id, "", false)

	active_assistant_item = rendered_entry_nodes.get(active_assistant_entry_id, null) as Node
	if active_assistant_item == null:
		return null

	var item: Node = active_assistant_item.call("get_thinking_item") as Node
	if item == null:
		item = active_assistant_item.call("add_thinking") as Node
	return item


func _append_assistant_thinking_to_timeline(entry_id: String, delta_text: String, is_done: bool) -> void:
	var index: int = _find_timeline_entry_index(entry_id)
	if index < 0:
		return

	var entry: Dictionary = timeline_entries[index]
	var body_parts: Array = entry.get("body_parts", []) as Array
	_append_thinking_event_to_body_parts(body_parts, delta_text, is_done)
	entry["body_parts"] = body_parts
	entry["height_actual"] = 0.0
	timeline_entries[index] = entry
	_mark_timeline_height_dirty(index)


func _append_thinking_event(delta_text: String) -> void:
	if delta_text.is_empty():
		return

	if active_thinking_entry_id.is_empty():
		var should_follow_bottom: bool = _should_follow_timeline_updates()
		_flush_pending_assistant_delta()
		active_thinking_item = _ensure_active_assistant_thinking_item()
		_schedule_timeline_render(should_follow_bottom)

	pending_thinking_delta_text += delta_text
	_schedule_thinking_delta_flush()


func _schedule_thinking_delta_flush() -> void:
	var now_msec: int = Time.get_ticks_msec()
	if pending_thinking_delta_flush_at_msec <= now_msec:
		pending_thinking_delta_flush_at_msec = now_msec + DELTA_FLUSH_INTERVAL_MSEC
	if pending_thinking_delta_queued:
		return

	pending_thinking_delta_queued = true
	_deferred_flush_pending_thinking_delta()


func _deferred_flush_pending_thinking_delta() -> void:
	var delay_msec: int = pending_thinking_delta_flush_at_msec - Time.get_ticks_msec()
	if delay_msec > 0:
		await get_tree().create_timer(float(delay_msec) / 1000.0).timeout
	pending_thinking_delta_queued = false
	pending_thinking_delta_flush_at_msec = 0
	_flush_pending_thinking_delta()


func _flush_pending_thinking_delta() -> void:
	if pending_thinking_delta_text.is_empty() or active_thinking_entry_id.is_empty():
		return

	var should_follow_bottom: bool = _should_follow_timeline_updates()
	var delta_text: String = pending_thinking_delta_text
	pending_thinking_delta_text = ""
	if not active_assistant_entry_id.is_empty():
		_append_assistant_thinking_to_timeline(active_assistant_entry_id, delta_text, false)
	active_assistant_item = rendered_entry_nodes.get(active_assistant_entry_id, null) as Node
	if active_assistant_item != null:
		active_thinking_item = active_assistant_item.call("get_thinking_item") as Node
		if active_thinking_item == null:
			active_thinking_item = active_assistant_item.call("add_thinking") as Node
	if active_thinking_item != null:
		active_thinking_item.call("append_thinking_delta", delta_text)

	_schedule_timeline_measure()
	if should_follow_bottom:
		timeline_follow_bottom = true
		_scroll_timeline_to_bottom_deferred()


func _get_tool_call_key(event_data: Dictionary) -> String:
	var tool_call_id: String = str(event_data.get("toolCallId", ""))
	if not tool_call_id.is_empty():
		return tool_call_id

	var approval_id: String = str(event_data.get("approvalId", ""))
	if not approval_id.is_empty():
		return approval_id

	return "%s-%s" % [str(event_data.get("toolName", "tool")), str(event_data.get("step", 0))]


func _get_scoped_tool_call_key(event_data: Dictionary, request_id: String) -> String:
	var base_key: String = _get_tool_call_key(event_data)
	if request_id.is_empty():
		return base_key

	return "%s:%s" % [request_id, base_key]


func _show_approval_dialog(event_data: Dictionary) -> void:
	_show_background_context_viewer()
	var next_approval_id: String = str(event_data.get("approvalId", ""))
	if approval_dialog.visible and next_approval_id == pending_approval_id and not event_data.has("args"):
		return

	pending_approval_id = next_approval_id
	if active_queue_message_id > 0:
		_set_queue_message_status(active_queue_message_id, MESSAGE_QUEUE_STATUS_APPROVAL)
	var tool_name: String = str(event_data.get("toolName", event_data.get("llmToolName", "")))
	approval_title_label.text = "需要审批：%s" % MAIN_HELPERS.localize_tool_name_for_display(tool_name)
	var description_lines: PackedStringArray = [
		"Approval ID: `%s`" % pending_approval_id,
		"Reason: %s" % str(event_data.get("reason", "")),
		"Args: ",
		MAIN_HELPERS.format_approval_args_preview(event_data.get("args", {}), APPROVAL_ARGS_PREVIEW_LIMIT)
	]
	if bool(event_data.get("restored", false)):
		description_lines.insert(2, "Status: Restored after backend restart")
	if bool(event_data.get("interrupted", false)):
		description_lines.insert(2, "Status: Last execution interrupted, retryable")
	approval_description_label.text = "\n".join(description_lines)
	approval_dialog.visible = true
	_update_send_state()


func _show_first_pending_approval(result_dictionary: Dictionary) -> void:
	var pending_value: Variant = result_dictionary.get("pending", [])
	if typeof(pending_value) != TYPE_ARRAY:
		return

	var pending_items: Array = pending_value as Array
	if pending_items.is_empty():
		if not pending_approval_id.is_empty():
			pending_approval_id = ""
			approval_dialog.visible = false
		return

	var first_pending_value: Variant = pending_items[0]
	if typeof(first_pending_value) != TYPE_DICTIONARY:
		return

	var pending_data: Dictionary = (first_pending_value as Dictionary).duplicate(true)
	if not pending_data.has("toolName"):
		pending_data["toolName"] = str(pending_data.get("llmToolName", ""))
	_show_approval_dialog(pending_data)


func _clear_stale_approval_dialog(detail_text: String) -> void:
	if pending_approval_id.is_empty() and not approval_dialog.visible:
		return

	pending_approval_id = ""
	approval_dialog.visible = false
	_clear_paused_stream_context()
	_update_send_state()
	_upsert_connection_status_entry("warning", "Approval has expired", detail_text)


func _handle_stale_approval_response(message: Dictionary) -> bool:
	var response_id: String = str(message.get("id", ""))
	if not response_id.begins_with("approval-approve") and not response_id.begins_with("approval-reject"):
		return false

	var error_value: Variant = message.get("error", {})
	if typeof(error_value) != TYPE_DICTIONARY:
		return false

	var error_dictionary: Dictionary = error_value as Dictionary
	if str(error_dictionary.get("code", "")) != "approval_not_found":
		return false

	_clear_stale_approval_dialog("The backend currently does not have this pending approval record, which usually occurs when the backend has been restarted or hot-updated, resulting in the approval queue being cleared. Please initiate the operation again.")
	_send_request(RPC_METHODS.SESSION_INFO, {}, "session-info")
	return true

# --- context_status_controller.gd ---

# --- context_status_controller.gd ---
func _update_context_length(info: Dictionary) -> void:
	latest_context_info = info.duplicate(true)
	var context_window_tokens: int = int(info.get("contextWindowTokens", 0))
	var history_tokens_stored: int = int(info.get("historyTokensStored", 0))

	if context_window_tokens <= 0:
		_set_context_length_icon(0.0, true)
		return

	var ratio: float = float(history_tokens_stored) / float(context_window_tokens)
	_set_context_length_icon(ratio, history_tokens_stored <= 0, history_tokens_stored, context_window_tokens)

	if context_popup_menu != null and is_instance_valid(context_popup_menu) and context_popup_menu.visible:
		context_popup_menu.call("setup", latest_context_info)

	if int(info.get("pendingApprovals", 0)) <= 0:
		_clear_stale_approval_dialog("There are currently no pending approval records in the backend; if the backend was just restarted, the writing tool needs to be triggered again.")


func _set_context_length_icon(ratio: float, is_empty: bool, history_tokens_stored: int = 0, context_window_tokens: int = 0) -> void:
	var icon_path: String = "%s/empty_context_length.svg" % CONTEXT_ICON_DIR

	if not is_empty:
		var level: int = int(ceil(ratio / 0.12))
		level = clampi(level, 1, 8)
		icon_path = "%s/context_length%d.svg" % [CONTEXT_ICON_DIR, level]

	var texture: Texture2D = load(icon_path) as Texture2D
	if texture != null:
		context_length_button.icon = texture

	if ratio >= 0.96:
		context_length_button.tooltip_text = "Context usage: %s (%s / %s). The context might be too long, it's suggested to condense the conversation." % [
			MAIN_HELPERS.format_context_usage_percent(ratio),
			MAIN_HELPERS.format_compact_token_count(history_tokens_stored),
			MAIN_HELPERS.format_compact_token_count(context_window_tokens)
		]
	elif is_empty:
		if context_window_tokens > 0:
			context_length_button.tooltip_text = "Context usage: 0%% (%s / %s)" % [
				MAIN_HELPERS.format_compact_token_count(history_tokens_stored),
				MAIN_HELPERS.format_compact_token_count(context_window_tokens)
			]
		else:
			context_length_button.tooltip_text = "Context usage: 0%"
	else:
		context_length_button.tooltip_text = "Context usage: %s (%s / %s)" % [
			MAIN_HELPERS.format_context_usage_percent(ratio),
			MAIN_HELPERS.format_compact_token_count(history_tokens_stored),
			MAIN_HELPERS.format_compact_token_count(context_window_tokens)
		]


func _on_context_length_button_pressed() -> void:
	context_popup_open_after_info = false
	if not latest_context_info.is_empty():
		_show_context_popup_menu()

	if _is_socket_open() and not active_session_id.is_empty():
		context_popup_open_after_info = true
		var context_info_request_id: String = _send_request(RPC_METHODS.SESSION_INFO, {}, "context-popup-info")
		if context_info_request_id.is_empty():
			context_popup_open_after_info = false


func _show_context_popup_menu() -> void:
	var popup_menu: PopupPanel = _get_context_popup_menu()
	if popup_menu == null:
		return

	popup_menu.call("setup", latest_context_info)
	var popup_size: Vector2i = Vector2i(380, 390)
	var button_rect: Rect2 = context_length_button.get_global_rect()
	var viewport_size: Vector2 = get_viewport_rect().size
	var popup_x_max: int = max(4, int(viewport_size.x) - popup_size.x - 4)
	var popup_y_max: int = max(4, int(viewport_size.y) - popup_size.y - 4)
	var popup_x: int = int(round(button_rect.position.x + button_rect.size.x - float(popup_size.x)))
	var popup_y: int = int(round(button_rect.position.y - float(popup_size.y) - 8.0))

	if popup_y < 4:
		popup_y = int(round(button_rect.position.y + button_rect.size.y + 8.0))

	popup_x = clampi(popup_x, 4, popup_x_max)
	popup_y = clampi(popup_y, 4, popup_y_max)
	popup_menu.popup(Rect2i(Vector2i(popup_x, popup_y), popup_size))


func _get_context_popup_menu() -> PopupPanel:
	if context_popup_menu != null and is_instance_valid(context_popup_menu):
		return context_popup_menu

	var packed_scene: PackedScene = load(CONTEXT_POPUP_MENU_UID) as PackedScene
	if packed_scene == null:
		return null

	var next_context_popup_menu: PopupPanel = packed_scene.instantiate() as PopupPanel
	if next_context_popup_menu == null:
		return null

	context_popup_menu = next_context_popup_menu
	add_child(context_popup_menu)
	return context_popup_menu


func _set_streaming_state(is_streaming: bool) -> void:
	_update_send_state()
	_sync_session_item_loading_state(is_streaming)


func _sync_session_item_loading_state(is_streaming: bool) -> void:
	for child: Node in session_list.get_children():
		if not child.has_method("set_loading"):
			continue

		var item_session_id: String = str(child.get("session_id"))
		child.call("set_loading", is_streaming and item_session_id == active_session_id)


func _has_message_draft() -> bool:
	return not text_edit.text.strip_edges().is_empty()


func _should_show_send_button(is_streaming: bool, has_message_draft: bool) -> bool:
	if not is_streaming:
		return true

	return has_message_draft


func _update_send_state() -> void:
	var is_streaming: bool = not active_stream_id.is_empty()
	var has_message_draft: bool = _has_message_draft()
	var has_pending_queue: bool = _has_pending_queued_messages()
	var has_unsupported_image: bool = _context_array_has_images(additional_context_controller.get_items()) and not _can_send_image_contexts()
	var should_show_send_button: bool = _should_show_send_button(is_streaming, has_message_draft)
	send_button.visible = should_show_send_button
	stop_button.visible = is_streaming
	send_button.disabled = not text_edit.visible or (not has_message_draft and not has_pending_queue) or has_unsupported_image
	if not socket_ready:
		send_button.tooltip_text = "Queue message until reconnected"
	elif not workspace_ready:
		send_button.tooltip_text = "Queue message until workspace initialization finishes"
	elif has_unsupported_image:
		send_button.tooltip_text = "Current model does not support image input. Configure an image recognition model or remove image context."
	elif is_streaming or not pending_approval_id.is_empty():
		send_button.tooltip_text = "Queue message"
	elif _has_pending_queued_messages():
		send_button.tooltip_text = "Send next queued message"
	else:
		send_button.tooltip_text = "Send"
	stop_button.disabled = not socket_ready or not is_streaming
	create_new_session_button.visible = socket_ready
	create_new_session_button.disabled = not workspace_ready


func _clear_todo_items() -> void:
	last_todo_signature = ""
	active_workflow_id = ""
	workflow_todo_nodes_by_id.clear()
	workflow_phase_nodes_by_id.clear()
	todo_list.hide()
	for child: Node in todo_container.get_children():
		child.queue_free()


func _apply_workflow_todo_snapshot(snapshot: Dictionary) -> void:
	var workflow_id: String = str(snapshot.get("runId", snapshot.get("workflowId", "")))
	if not workflow_id.is_empty():
		active_workflow_id = workflow_id

	var phases_value: Variant = snapshot.get("steps", snapshot.get("phases", []))
	if typeof(phases_value) != TYPE_ARRAY:
		return

	var signature: String = JSON.stringify(phases_value)
	if signature == last_todo_signature:
		return

	last_todo_signature = signature
	var wanted_node_ids: Dictionary[String, bool] = {}
	var phases: Array = phases_value as Array
	for phase_value: Variant in phases:
		if typeof(phase_value) != TYPE_DICTIONARY:
			continue

		var phase: Dictionary = phase_value as Dictionary
		var phase_id: String = str(phase.get("id", ""))
		var phase_node_id: String = "phase:%s" % phase_id
		var phase_status: String = str(phase.get("status", "pending"))
		var phase_item: Node = workflow_phase_nodes_by_id.get(phase_id, null) as Node
		if phase_item == null:
			phase_item = TODO_ITEM_SCENE.instantiate()
			workflow_phase_nodes_by_id[phase_id] = phase_item
			todo_container.add_child(phase_item)

		phase_item.call("setup_status", str(phase.get("title", phase_id)), phase_status)
		wanted_node_ids[phase_node_id] = true

	for phase_id: String in workflow_phase_nodes_by_id.keys():
		if wanted_node_ids.has("phase:%s" % phase_id):
			continue

		var old_phase_item: Node = workflow_phase_nodes_by_id.get(phase_id, null) as Node
		if old_phase_item != null:
			old_phase_item.queue_free()
		workflow_phase_nodes_by_id.erase(phase_id)

	for todo_id: String in workflow_todo_nodes_by_id.keys():
		var old_todo_item: Node = workflow_todo_nodes_by_id.get(todo_id, null) as Node
		if old_todo_item != null:
			old_todo_item.queue_free()
		workflow_todo_nodes_by_id.erase(todo_id)

	todo_list.show()


func _update_todo_list_from_text(text: String) -> void:
	if not active_workflow_id.is_empty():
		return

	var todo_items: Array[Dictionary] = MAIN_HELPERS.extract_todo_items(text)
	var signature_parts: Array[String] = []
	for todo_data: Dictionary in todo_items:
		signature_parts.append("%s:%s" % [str(todo_data.get("checked", false)), str(todo_data.get("text", ""))])

	var signature: String = "\n".join(signature_parts)
	if signature == last_todo_signature:
		return

	last_todo_signature = signature
	workflow_todo_nodes_by_id.clear()
	workflow_phase_nodes_by_id.clear()
	for child: Node in todo_container.get_children():
		child.queue_free()

	if todo_items.is_empty():
		todo_list.hide()
		return

	for index: int in range(todo_items.size()):
		var todo_data: Dictionary = todo_items[index]
		var todo_text: String = str(todo_data.get("text", "")).strip_edges()
		if todo_text.is_empty():
			continue

		var todo_item: Node = TODO_ITEM_SCENE.instantiate()
		workflow_todo_nodes_by_id[str(index)] = todo_item
		todo_container.add_child(todo_item)
		todo_item.call("setup_status", todo_text, "done" if bool(todo_data.get("checked", false)) else "pending")

	todo_list.visible = todo_container.get_child_count() > 0

# --- settings_bridge.gd ---

# --- settings_bridge.gd ---
func _on_settings_button_pressed() -> void:
	var packed_scene: PackedScene = load(SETTINGS_MENU_UID)
	if packed_scene == null:
		return
	
	var settings_menu: AcceptDialog = packed_scene.instantiate()
	active_settings_menu = settings_menu
	add_child(settings_menu)
	settings_menu.call("setup_provider_config", provider_config_status, _get_frontend_config_snapshot())
	settings_menu.call("setup_web_search_settings", web_search_settings_status)
	settings_menu.call("setup_archived_sessions", _get_archived_sessions_snapshot(), _get_workspace_snapshot())
	settings_menu.call("setup_mcp_servers", _get_custom_mcp_servers_snapshot(), _is_socket_open())
	settings_menu.call("setup_skills", skill_summaries, skill_catalog_revision, _is_socket_open())
	settings_menu.connect("provider_config_save_requested", Callable(self, "_on_settings_provider_config_save_requested"))
	settings_menu.connect("provider_config_clear_requested", Callable(self, "_on_settings_provider_config_clear_requested"))
	settings_menu.connect("web_search_settings_save_requested", Callable(self, "_on_settings_web_search_settings_save_requested"))
	settings_menu.connect("frontend_config_save_requested", Callable(self, "_on_settings_frontend_config_save_requested"))
	settings_menu.connect("user_prompt_save_requested", Callable(self, "_on_settings_user_prompt_save_requested"))
	settings_menu.connect("archived_session_restore_requested", Callable(self, "_on_settings_archived_session_restore_requested"))
	settings_menu.connect("archived_session_delete_requested", Callable(self, "_on_settings_archived_session_delete_requested"))
	settings_menu.connect("mcp_server_add_requested", Callable(self, "_on_settings_mcp_server_add_requested"))
	settings_menu.connect("mcp_server_update_requested", Callable(self, "_on_settings_mcp_server_update_requested"))
	settings_menu.connect("mcp_server_remove_requested", Callable(self, "_on_settings_mcp_server_remove_requested"))
	settings_menu.connect("mcp_server_enabled_requested", Callable(self, "_on_settings_mcp_server_enabled_requested"))
	settings_menu.connect("skill_reload_requested", Callable(self, "_load_skills"))
	settings_menu.connect("skill_get_requested", Callable(self, "_on_settings_skill_get_requested"))
	settings_menu.connect("skill_enabled_requested", Callable(self, "_on_settings_skill_enabled_requested"))
	settings_menu.connect("skill_update_requested", Callable(self, "_on_settings_skill_update_requested"))
	settings_menu.connect("skill_remove_requested", Callable(self, "_on_settings_skill_remove_requested"))
	settings_menu.tree_exited.connect(_on_settings_menu_tree_exited.bind(settings_menu))
	_refresh_session_and_archive_lists()
	_load_mcp_config()
	_load_skills()
	if _is_socket_open():
		_send_request(RPC_METHODS.WEB_SEARCH_SETTINGS_GET, {}, "web-search-settings-get")


func _on_settings_skill_get_requested(skill_ref: String) -> void:
	_send_request(RPC_METHODS.SKILL_GET, { "ref": skill_ref }, "skill-get")


func _on_settings_skill_enabled_requested(skill_ref: String, enabled: bool) -> void:
	_send_request(RPC_METHODS.SKILL_SET_ENABLED, { "ref": skill_ref, "enabled": enabled }, "skill-enabled")


func _on_settings_skill_update_requested(skill_ref: String, content: String) -> void:
	_send_request(RPC_METHODS.SKILL_UPDATE, { "ref": skill_ref, "content": content }, "skill-update")


func _on_settings_skill_remove_requested(skill_ref: String) -> void:
	_send_request(RPC_METHODS.SKILL_REMOVE, { "ref": skill_ref }, "skill-remove")


func _open_backend_manager() -> void:
	var runtime_dialog: AcceptDialog = AcceptDialog.new()
	runtime_dialog.title = "Daedalus runtime diagnostics"
	runtime_dialog.ok_button_text = "Close"
	var details: RichTextLabel = RichTextLabel.new()
	details.fit_content = true
	details.custom_minimum_size = Vector2(560.0, 240.0)
	details.bbcode_enabled = true
	details.text = "\n".join([
		"[b]Plugin[/b] %s (protocol %d)" % [PLUGIN_VERSION, PLUGIN_PROTOCOL_VERSION],
		"[b]Studio binding[/b] %s" % STUDIO_BINDING_VERSION,
		"[b]Backend[/b] %s" % (connected_backend_version if not connected_backend_version.is_empty() else "not connected"),
		"[b]Connection[/b] %s" % ("connected" if _is_socket_open() else "disconnected"),
		"[b]Project[/b] %s" % ProjectSettings.globalize_path("res://"),
		"",
		_get_backend_launcher_details()
	])
	runtime_dialog.add_child(details)
	add_child(runtime_dialog)
	runtime_dialog.confirmed.connect(runtime_dialog.queue_free)
	runtime_dialog.canceled.connect(runtime_dialog.queue_free)
	runtime_dialog.popup_centered()


func _on_backend_manager_button_pressed() -> void:
	_open_backend_manager()


func _get_frontend_config_snapshot() -> Dictionary:
	return {
		"backendUrl": backend_url,
		"backendDevDir": backend_dev_dir,
		"provider": active_provider_id,
		"model": _get_selected_model_id(),
		"customInstructions": custom_instructions,
		"nextStepHintsEnabled": next_step_hints_enabled,
		"checkForUpdatesEnabled": check_for_updates_enabled
	}


func _get_archived_sessions_snapshot() -> Array[Dictionary]:
	var archived_sessions: Array[Dictionary] = []
	for session_id: String in archived_session_ids_in_order:
		var metadata: Dictionary = archived_sessions_by_id.get(session_id, {}) as Dictionary
		if metadata.is_empty():
			continue

		archived_sessions.append(metadata.duplicate(true))

	return archived_sessions


func _get_workspace_snapshot() -> Array[Dictionary]:
	var workspaces: Array[Dictionary] = []
	for workspace_id: String in workspaces_by_id.keys():
		var workspace: Dictionary = workspaces_by_id.get(workspace_id, {}) as Dictionary
		if workspace.is_empty():
			continue

		workspaces.append(workspace.duplicate(true))

	return workspaces


func _get_custom_mcp_servers_snapshot() -> Array[Dictionary]:
	var servers: Array[Dictionary] = []
	for metadata: Dictionary in custom_mcp_servers:
		servers.append(metadata.duplicate(true))

	return servers


func _sync_settings_archived_sessions() -> void:
	if active_settings_menu == null or not is_instance_valid(active_settings_menu):
		return

	active_settings_menu.call(
		"setup_archived_sessions",
		_get_archived_sessions_snapshot(),
		_get_workspace_snapshot()
	)


func _sync_settings_mcp_servers() -> void:
	if active_settings_menu == null or not is_instance_valid(active_settings_menu):
		return

	active_settings_menu.call(
		"setup_mcp_servers",
		_get_custom_mcp_servers_snapshot(),
		_is_socket_open()
	)


func _on_settings_menu_tree_exited(settings_menu: Node) -> void:
	if active_settings_menu == settings_menu:
		active_settings_menu = null


func _on_settings_archived_session_restore_requested(session_id: String) -> void:
	if not _is_socket_open() or session_id.is_empty():
		return

	_send_request(RPC_METHODS.SESSION_ARCHIVED_RESTORE, { "sessionId": session_id }, "session-archived-restore")


func _on_settings_archived_session_delete_requested(session_id: String) -> void:
	if not _is_socket_open() or session_id.is_empty():
		return

	_send_request(RPC_METHODS.SESSION_ARCHIVED_DELETE, { "sessionId": session_id }, "session-archived-delete")


func _on_settings_mcp_server_add_requested(config: Dictionary) -> void:
	if not _is_socket_open():
		if active_settings_menu != null and is_instance_valid(active_settings_menu):
			active_settings_menu.call("show_mcp_error", "Backend is disconnected. Reconnect before adding an MCP server.")
		return

	var add_request_id: String = _send_request(RPC_METHODS.MCP_CONFIG_ADD, config, "mcp-config-add")
	if add_request_id.is_empty() and active_settings_menu != null and is_instance_valid(active_settings_menu):
		active_settings_menu.call("show_mcp_error", "Failed to send MCP server configuration to backend.")


func _on_settings_mcp_server_update_requested(server_id: String, config: Dictionary) -> void:
	if not _is_socket_open() or server_id.is_empty():
		if active_settings_menu != null and is_instance_valid(active_settings_menu):
			active_settings_menu.call("show_mcp_error", "Backend is disconnected. Reconnect before editing an MCP server.")
		return

	var request_params: Dictionary = config.duplicate(true)
	request_params["serverId"] = server_id
	var update_request_id: String = _send_request(RPC_METHODS.MCP_CONFIG_UPDATE, request_params, "mcp-config-update")
	if update_request_id.is_empty() and active_settings_menu != null and is_instance_valid(active_settings_menu):
		active_settings_menu.call("show_mcp_error", "Failed to send MCP server update to backend.")


func _on_settings_mcp_server_remove_requested(server_id: String) -> void:
	if not _is_socket_open() or server_id.is_empty():
		if active_settings_menu != null and is_instance_valid(active_settings_menu):
			active_settings_menu.call("show_mcp_error", "Backend is disconnected. Reconnect before removing an MCP server.")
		return

	var remove_request_id: String = _send_request(RPC_METHODS.MCP_CONFIG_REMOVE, { "serverId": server_id }, "mcp-config-remove")
	if remove_request_id.is_empty() and active_settings_menu != null and is_instance_valid(active_settings_menu):
		active_settings_menu.call("show_mcp_error", "Failed to send MCP server removal to backend.")


func _on_settings_mcp_server_enabled_requested(server_id: String, enabled: bool) -> void:
	if not _is_socket_open() or server_id.is_empty():
		if active_settings_menu != null and is_instance_valid(active_settings_menu):
			active_settings_menu.call("show_mcp_error", "Backend is disconnected. Reconnect before changing an MCP server.")
		_sync_settings_mcp_servers()
		return

	var enabled_request_id: String = _send_request(RPC_METHODS.MCP_CONFIG_SET_ENABLED, { "serverId": server_id, "enabled": enabled }, "mcp-config-enabled")
	if enabled_request_id.is_empty() and active_settings_menu != null and is_instance_valid(active_settings_menu):
		active_settings_menu.call("show_mcp_error", "Failed to send MCP server state change to backend.")


func _on_settings_provider_config_save_requested(provider_id: String, api_key: String, base_url: String, model_routing: Dictionary) -> void:
	if not _is_socket_open():
		pending_provider_config_provider = provider_id
		pending_provider_config_api_key = api_key
		pending_provider_config_base_url = base_url
		pending_provider_config_model_routing = model_routing.duplicate(true)
		pending_provider_config_save_after_connect = true
		return

	_save_provider_config_to_backend(provider_id, api_key, base_url, model_routing)


func _save_provider_config_to_backend(provider_id: String, api_key: String, base_url: String = "", model_routing: Dictionary = {}) -> void:
	if _is_known_provider_id(provider_id):
		_switch_active_provider(provider_id, false)

	var params: Dictionary[String, Variant] = {
		"provider": active_provider_id,
		"model": _get_selected_model_id(),
		"activate": true,
		"modelRouting": model_routing if not model_routing.is_empty() else provider_config_status.get("modelRouting", {})
	}

	if not api_key.strip_edges().is_empty():
		params["apiKey"] = api_key.strip_edges()
	params["baseUrl"] = base_url.strip_edges() if not base_url.strip_edges().is_empty() else null

	_send_request(RPC_METHODS.PROVIDER_CONFIG_SET, params, "provider-config-set")


func _on_settings_provider_config_clear_requested(provider_id: String) -> void:
	var params: Dictionary[String, Variant] = {}
	if _is_known_provider_id(provider_id):
		params["provider"] = provider_id
	_send_request(RPC_METHODS.PROVIDER_CONFIG_CLEAR, params, "provider-config-clear")


func _on_settings_web_search_settings_save_requested(patch: Dictionary) -> void:
	if not _is_socket_open():
		return
	_send_request(RPC_METHODS.WEB_SEARCH_SETTINGS_UPDATE, patch, "web-search-settings-update")


func _on_settings_frontend_config_save_requested(
	next_backend_url: String,
	next_backend_dev_dir: String,
	next_step_hints_enabled_value: bool,
	next_check_for_updates_enabled: bool
) -> void:
	var normalized_backend_dev_dir: String = next_backend_dev_dir.strip_edges()
	var normalized_backend_url: String = _resolve_backend_url_for_mode(_normalize_backend_url(next_backend_url), normalized_backend_dev_dir)
	var backend_url_changed: bool = normalized_backend_url != backend_url
	var backend_dev_dir_changed: bool = normalized_backend_dev_dir != backend_dev_dir
	backend_url = normalized_backend_url
	backend_dev_dir = normalized_backend_dev_dir
	next_step_hints_enabled = next_step_hints_enabled_value
	check_for_updates_enabled = next_check_for_updates_enabled
	if not check_for_updates_enabled:
		backend_manager_button.text = "Runtime diagnostics"
		backend_manager_button.tooltip_text = "View shared runtime and plugin compatibility details."
	_save_frontend_config()
	if not next_step_hints_enabled:
		_clear_next_step_hint_entries()

	if backend_url_changed or backend_dev_dir_changed:
		_restart_backend_connection()


func _on_settings_user_prompt_save_requested(next_user_prompt: String) -> void:
	custom_instructions = next_user_prompt.strip_edges()
	if _is_socket_open():
		_send_request(RPC_METHODS.USER_PROMPT_SET, { "prompt": custom_instructions }, "user-prompt-set")


func _restart_backend_connection(recovery_mode: bool = false) -> void:
	context_popup_open_after_info = false
	socket_ready = false
	workspace_ready = false
	is_connecting = false
	backend_connection_controller.shutdown()
	_start_backend_connection_attempts(not recovery_mode, recovery_mode)


func _ready() -> void:
	main_viewer.hide()
	boot_splash.show()
	additional_context_controller.setup(additional_context_viewer, additional_context_container)
	additional_context_controller.set_deferred_render_enabled(true)
	file_edit_controller.setup(editor_bridge_controller)
	provider_navigation_controller.setup(approval_mode_button, mode_button, provider_option_button, model_button)
	if pending_editor_bridge_plugin != null:
		editor_bridge_controller.setup(pending_editor_bridge_plugin)
	backend_launcher = BACKEND_LAUNCHER_SCRIPT.new()
	_setup_options()
	_load_frontend_config()
	_setup_timeline_containers()
	_connect_timeline_signals()
	_setup_message_tree()
	_setup_add_context_menu()
	_setup_slash_command_popup()
	_setup_plan_dialogs()
	_render_message_panel()
	_clear_template_items()
	additional_context_controller.render()
	_update_send_state()
	_update_navigation_state()
	_set_context_length_icon(0.0, true)
	_start_backend_connection_attempts()


func _on_additional_context_controller_changed() -> void:
	var context_signature: String = JSON.stringify(additional_context_controller.get_backend_snapshot())
	if workbench_context_patch_in_flight and context_signature == workbench_context_patch_signature:
		_update_send_state()
		return

	_queue_workbench_composer_patch(false, true)
	_update_send_state()


func _on_additional_context_controller_status_requested(level: String, title: String, message: String) -> void:
	_upsert_connection_status_entry(level, title, message)


func _process(_delta: float) -> void:
	if backend_launcher != null:
		backend_launcher.call("poll_logs")
	backend_connection_controller.poll()
	if backend_connection_controller.is_open():
		_check_backend_health_timeout()
	elif backend_connection_controller.is_closed() and is_connecting:
		_retry_backend_connection()
	editor_bridge_controller.poll_live_context()


func _on_backend_connection_connected() -> void:
	socket_ready = true
	_on_socket_opened()


func _on_backend_connection_disconnected(_close_code: int, _close_reason: String) -> void:
	if socket_ready:
		_handle_socket_closed_after_ready()


func _on_backend_connection_protocol_error(message: String) -> void:
	push_warning(message)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if not text_edit.has_focus():
		return

	if event.keycode == KEY_V and event.ctrl_pressed:
		if _handle_clipboard_image_paste():
			accept_event()
		return

	if event.keycode == KEY_ENTER:
		if _handle_slash_command_key(event):
			accept_event()
			return
		if event.shift_pressed:
			return
		if event.ctrl_pressed:
			_create_or_update_manual_guide_from_text_edit()
			accept_event()
			return
		_on_send_button_pressed()
		accept_event()
	elif _handle_slash_command_key(event):
		accept_event()


func _exit_tree() -> void:
	backend_connection_controller.shutdown()
