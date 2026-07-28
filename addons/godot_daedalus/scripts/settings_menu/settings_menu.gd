@tool
extends AcceptDialog

signal provider_config_save_requested(provider_id: String, api_key: String, base_url: String, model_routing: Dictionary)
signal provider_config_clear_requested(provider_id: String)
signal web_search_settings_save_requested(patch: Dictionary)
signal frontend_config_save_requested(backend_url: String, backend_dev_dir: String, next_step_hints_enabled: bool, check_for_updates_enabled: bool)
signal user_prompt_save_requested(prompt: String)
signal archived_session_restore_requested(session_id: String)
signal archived_session_delete_requested(session_id: String)
signal mcp_server_add_requested(config: Dictionary)
signal mcp_server_update_requested(server_id: String, config: Dictionary)
signal mcp_server_remove_requested(server_id: String)
signal mcp_server_enabled_requested(server_id: String, enabled: bool)
signal skill_reload_requested
signal skill_get_requested(skill_ref: String)
signal skill_enabled_requested(skill_ref: String, enabled: bool)
signal skill_update_requested(skill_ref: String, content: String)
signal skill_remove_requested(skill_ref: String)

@onready var tab_container: TabContainer = %TabContainer
@onready var provider_option_button: OptionButton = %ProviderOptionButton
@onready var image_recognition_model_option_button: OptionButton = %ImageRecognitionModelOptionButton
@onready var workflow_planner_model_option_button: OptionButton = %WorkflowPlannerModelOptionButton
@onready var session_title_model_option_button: OptionButton = %SessionTitleModelOptionButton
@onready var provider_base_url_line_edit: LineEdit = %ProviderBaseURLLineEdit
@onready var web_search_enabled_check_box: CheckBox = %WebSearchEnabledCheckBox
@onready var web_search_model_option_button: OptionButton = %WebSearchModelOptionButton
@onready var web_search_max_results_spin_box: SpinBox = %WebSearchMaxResultsSpinBox
@onready var web_search_max_keywords_label: Label = %WebSearchMaxKeywordsLabel
@onready var web_search_max_keywords_spin_box: SpinBox = %WebSearchMaxKeywordsSpinBox
@onready var web_search_notice_label: Label = %WebSearchNoticeLabel
@onready var api_key_label: Label = %APIKeyLabel
@onready var backend_url_line_edit: LineEdit = %BackendURLLineEdit
@onready var backend_dev_dir_line_edit: LineEdit = %BackendDevDirLineEdit
@onready var deepseek_api_key_line_edit: LineEdit = %DeepseekAPIKeyLineEdit
@onready var clear_deepseek_api_key_button: Button = %ClearDeepseekAPIKeyButton
@onready var custom_instructions_label: Label = %CustomInstructionsLabel
@onready var custom_instructions_warning_button: Button = %CustomInstructionsWarningButton
@onready var check_for_updates_check_box: CheckBox = %CheckForUpdatesCheckBox
@onready var next_step_hints_check_box: CheckBox = %NextStepHintsCheckBox
@onready var custom_instructions_edit: TextEdit = %CustomInstructionsEdit
@onready var add_mcp_server_button: Button = %AddMCPServerButton
@onready var mcp_status_label: Label = %MCPStatusLabel
@onready var mcp_server_list: VBoxContainer = %MCPServerList
@onready var skills_status_label: Label = %SkillsStatusLabel
@onready var skills_list: VBoxContainer = %SkillsList
@onready var archived_workspace_filter_option_button: OptionButton = %WorkspaceFilterOptionButton
@onready var search_archived_chat_line_edit: LineEdit = %SearchArchivedChatLineEdit
@onready var delete_all_archived_chats_button: Button = %DeleteAllArchivedChatsButton
@onready var archived_chat_list: VBoxContainer = %ArchivedChatList
@onready var file_dialog: EditorFileDialog = %EditorFileDialog

const ARCHIVED_CHAT_ITEM_SCENE_UID: String = "uid://kyksk24wd7d3"
const MCP_SERVER_ITEM_SCENE_UID: String = "uid://cuwihfpwn6b68"
const ADD_MCP_SERVER_DIALOG_UID: String = "uid://cb7acb4w7s4xl"
const EDIT_MCP_SERVER_DIALOG_UID: String = "uid://c7vbtknay2b0y"
const SKILL_ITEM_SCENE_UID: String = "uid://cb877u5eo8nw4"
const EDIT_SKILL_DIALOG_UID: String = "uid://mm43il6ailq"
const CUSTOM_INSTRUCTIONS_WARNING_CHARS: int = 4000
const CUSTOM_INSTRUCTIONS_HEAVY_CHARS: int = 12000
const EDITOR_TYPE: StringName = &"Editor"
const ACCEPT_DIALOG_TYPE: StringName = &"AcceptDialog"
const EDITOR_SETTINGS_DIALOG_TYPE: StringName = &"EditorSettingsDialog"
const PANEL_STYLE_NAME: StringName = &"panel"
const BASE_STYLE_NAME: StringName = &"base_style"
const BUTTONS_SEPARATION_CONSTANT: StringName = &"buttons_separation"
const BUTTONS_MIN_WIDTH_CONSTANT: StringName = &"buttons_min_width"
const BUTTONS_MIN_HEIGHT_CONSTANT: StringName = &"buttons_min_height"
const CONFIRM_ACTION_NONE: StringName = &""
const CONFIRM_ACTION_DELETE_ARCHIVED_SESSION: StringName = &"delete_archived_session"
const CONFIRM_ACTION_DELETE_ALL_ARCHIVED_SESSIONS: StringName = &"delete_all_archived_sessions"
const PROVIDER_IDS: PackedStringArray = ["deepseek"]
const PROVIDER_NAMES: PackedStringArray = ["DeepSeek"]
const TASK_MODEL_KEYS: PackedStringArray = [
	"imageRecognition",
	"workflowPlanner",
	"sessionTitle"
]
const USE_CURRENT_MODEL_TEXT: String = "Use current model"
const USER_SKILL_SOURCES: PackedStringArray = ["project", "personal"]

var archived_sessions: Array[Dictionary]
var archived_workspaces_by_id: Dictionary[String, Dictionary]
var custom_mcp_servers: Array[Dictionary]
var skill_summaries: Array[Dictionary]
var skill_catalog_revision: String
var provider_status_by_id: Dictionary[String, Dictionary]
var provider_order: PackedStringArray
var web_search_settings: Dictionary
var web_search_settings_loaded: bool
var mcp_backend_available: bool = true
var mcp_add_pending: bool
var pending_mcp_update_server_id: String
var pending_mcp_server_metadata: Dictionary
var archived_workspace_filter: String
var archived_search_text: String
var pending_confirmation_action: StringName = CONFIRM_ACTION_NONE
var pending_delete_session_id: String
var pending_delete_session_ids: PackedStringArray
var pending_delete_mcp_server_id: String
var archive_delete_confirmation_dialog: ConfirmationDialog
var custom_instructions_warning_dialog: AcceptDialog
var mcp_delete_confirmation_dialog: ConfirmationDialog
var skill_delete_confirmation_dialog: ConfirmationDialog
var active_skill_editor: ConfirmationDialog
var pending_delete_skill_ref: String


func _ready() -> void:
	tab_container.current_tab = 0
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	if not file_dialog.dir_selected.is_connected(_on_backend_dev_dir_selected):
		file_dialog.dir_selected.connect(_on_backend_dev_dir_selected)
	if not provider_option_button.item_selected.is_connected(_on_provider_option_button_item_selected):
		provider_option_button.item_selected.connect(_on_provider_option_button_item_selected)
	if not web_search_model_option_button.item_selected.is_connected(_on_web_search_model_option_button_item_selected):
		web_search_model_option_button.item_selected.connect(_on_web_search_model_option_button_item_selected)
	_update_custom_instructions_status()
	_render_mcp_servers()
	_render_skills()
	_update_delete_all_archived_chats_button()
	call_deferred(&"_apply_editor_dialog_theme")


func setup_provider_config(status: Dictionary, frontend_config: Dictionary = {}) -> void:
	var active_provider_id: String = str(status.get("activeProvider", status.get("provider", frontend_config.get("provider", "deepseek"))))
	provider_status_by_id.clear()
	provider_order.clear()
	var providers_value: Variant = status.get("providers", [])
	if typeof(providers_value) == TYPE_ARRAY:
		var providers_array: Array = providers_value as Array
		for item: Variant in providers_array:
			if typeof(item) != TYPE_DICTIONARY:
				continue

			var provider_status: Dictionary = item as Dictionary
			var provider_id: String = str(provider_status.get("provider", "")).strip_edges()
			if not provider_id.is_empty():
				provider_status_by_id[provider_id] = provider_status
				provider_order.append(provider_id)

	if provider_status_by_id.is_empty() and status.has("provider"):
		var fallback_provider_id: String = str(status.get("provider", active_provider_id))
		provider_status_by_id[fallback_provider_id] = status
		provider_order.append(fallback_provider_id)
	if provider_order.is_empty():
		provider_order.append_array(PROVIDER_IDS)
	backend_url_line_edit.text = str(frontend_config.get("backendUrl", "ws://127.0.0.1:38180"))
	backend_dev_dir_line_edit.text = str(frontend_config.get("backendDevDir", ""))
	custom_instructions_edit.text = str(frontend_config.get("customInstructions", ""))
	next_step_hints_check_box.button_pressed = bool(frontend_config.get("nextStepHintsEnabled", false))
	check_for_updates_check_box.button_pressed = bool(frontend_config.get("checkForUpdatesEnabled", true))
	_update_custom_instructions_status()
	_populate_provider_options(active_provider_id)
	_populate_task_model_options(status)
	_update_provider_key_labels()
	show()


func setup_web_search_settings(status: Dictionary) -> void:
	web_search_settings = status.duplicate(true)
	web_search_settings_loaded = not status.is_empty()
	web_search_enabled_check_box.button_pressed = bool(status.get("enabled", false))
	web_search_max_results_spin_box.value = float(status.get("maxResults", 5))
	web_search_max_keywords_spin_box.value = float(status.get("maxKeywords", 1))
	web_search_model_option_button.clear()

	var selected_provider: String = str(status.get("provider", "")).strip_edges()
	var selected_model: String = str(status.get("model", "")).strip_edges()
	var selected_index: int = -1
	var models_value: Variant = status.get("models", [])
	if typeof(models_value) == TYPE_ARRAY:
		var models: Array = models_value as Array
		for model_value: Variant in models:
			if typeof(model_value) != TYPE_DICTIONARY:
				continue
			var model_data: Dictionary = model_value as Dictionary
			var provider_id: String = str(model_data.get("provider", "")).strip_edges()
			var model_id: String = str(model_data.get("model", "")).strip_edges()
			if provider_id.is_empty() or model_id.is_empty():
				continue
			var provider_name: String = str(model_data.get("providerDisplayName", provider_id)).strip_edges()
			var model_name: String = str(model_data.get("modelDisplayName", model_id)).strip_edges()
			var index: int = web_search_model_option_button.item_count
			web_search_model_option_button.add_item("%s / %s" % [provider_name, model_name], index)
			web_search_model_option_button.set_item_metadata(index, model_data.duplicate(true))
			if provider_id == selected_provider and model_id == selected_model:
				selected_index = index

	if selected_index >= 0:
		web_search_model_option_button.select(selected_index)
	elif web_search_model_option_button.item_count > 0:
		web_search_model_option_button.select(0)
	web_search_model_option_button.disabled = web_search_model_option_button.item_count == 0
	web_search_enabled_check_box.disabled = not web_search_settings_loaded
	web_search_max_results_spin_box.editable = web_search_settings_loaded
	_update_web_search_keyword_controls()


func show_web_search_error(message_text: String) -> void:
	web_search_notice_label.visible = true
	web_search_notice_label.text = message_text
	web_search_notice_label.modulate = Color(1.0, 0.55, 0.45)


func setup_archived_sessions(sessions: Array, workspaces: Array = []) -> void:
	archived_sessions.clear()
	for item: Variant in sessions:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		archived_sessions.append((item as Dictionary).duplicate(true))

	archived_workspaces_by_id.clear()
	for item: Variant in workspaces:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var workspace: Dictionary = item as Dictionary
		var workspace_id: String = str(workspace.get("id", ""))
		if workspace_id.is_empty():
			continue

		archived_workspaces_by_id[workspace_id] = workspace.duplicate(true)

	_populate_archived_workspace_filter()
	_render_archived_sessions()
	_update_delete_all_archived_chats_button()


func setup_mcp_servers(servers: Array, backend_available: bool = true) -> void:
	custom_mcp_servers.clear()
	for item: Variant in servers:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		custom_mcp_servers.append((item as Dictionary).duplicate(true))

	mcp_backend_available = backend_available
	mcp_add_pending = false
	pending_mcp_update_server_id = ""
	pending_mcp_server_metadata.clear()
	_render_mcp_servers()


func setup_skills(skills: Array, revision: String = "", backend_available: bool = true) -> void:
	skill_summaries.clear()
	for item: Variant in skills:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var metadata: Dictionary = (item as Dictionary).duplicate(true)
		if not USER_SKILL_SOURCES.has(str(metadata.get("source", ""))):
			continue
		skill_summaries.append(metadata)
	skill_catalog_revision = revision
	mcp_backend_available = backend_available
	_render_skills()


func show_skill_error(message_text: String) -> void:
	if active_skill_editor != null and is_instance_valid(active_skill_editor):
		active_skill_editor.call("show_error", message_text)
		active_skill_editor.popup_centered()
		return
	skills_status_label.visible = true
	skills_status_label.text = message_text
	skills_status_label.tooltip_text = message_text


func show_skill_editor(skill_ref: String, skill_name: String, content: String) -> void:
	_close_skill_editor()
	var packed_scene: PackedScene = load(EDIT_SKILL_DIALOG_UID)
	if packed_scene == null:
		show_skill_error("Edit skill dialog is unavailable.")
		return
	active_skill_editor = packed_scene.instantiate() as ConfirmationDialog
	add_child(active_skill_editor)
	active_skill_editor.call("setup", skill_ref, skill_name, content)
	active_skill_editor.connect("save_requested", Callable(self, "_on_skill_editor_save_requested"))
	active_skill_editor.canceled.connect(_close_skill_editor)
	active_skill_editor.close_requested.connect(_close_skill_editor)
	active_skill_editor.popup_centered()


func close_skill_editor() -> void:
	_close_skill_editor()


func _render_skills() -> void:
	if skills_list == null or skills_status_label == null:
		return
	for child_node: Node in skills_list.get_children():
		child_node.queue_free()
	if not mcp_backend_available:
		skills_status_label.visible = true
		skills_status_label.text = "Backend is disconnected. Skill settings are unavailable."
		return
	if skill_summaries.is_empty():
		skills_status_label.visible = true
		skills_status_label.text = "No project or personal skills discovered"
		return
	skills_status_label.visible = true
	skills_status_label.text = _format_skills_status()
	skills_status_label.tooltip_text = skills_status_label.text
	var packed_scene: PackedScene = load(SKILL_ITEM_SCENE_UID)
	if packed_scene == null:
		show_skill_error("Skill item scene is unavailable.")
		return
	for source_name: String in USER_SKILL_SOURCES:
		var source_skills: Array[Dictionary] = []
		for metadata: Dictionary in skill_summaries:
			if str(metadata.get("source", "")) == source_name:
				source_skills.append(metadata)
		if source_skills.is_empty():
			continue
		var source_label: Label = Label.new()
		source_label.text = "%s skills" % source_name.capitalize()
		source_label.theme_type_variation = &"HeaderSmall"
		skills_list.add_child(source_label)
		for metadata: Dictionary in source_skills:
			var item_node: Node = packed_scene.instantiate()
			skills_list.add_child(item_node)
			item_node.call("setup", metadata)
			item_node.connect("edit_requested", Callable(self, "_on_skill_edit_requested"))
			item_node.connect("remove_requested", Callable(self, "_on_skill_remove_requested"))
			item_node.connect("enabled_changed", Callable(self, "_on_skill_enabled_changed"))


func _format_skills_status() -> String:
	var total_count: int = skill_summaries.size()
	var enabled_count: int
	for metadata: Dictionary in skill_summaries:
		if bool(metadata.get("enabled", false)):
			enabled_count += 1

	var total_label: String = "skill" if total_count == 1 else "skills"
	return "%d %s - %d enabled" % [total_count, total_label, enabled_count]


func _on_skill_edit_requested(skill_ref: String) -> void:
	skill_get_requested.emit(skill_ref)


func _on_refresh_skills_button_pressed() -> void:
	skill_reload_requested.emit()


func _on_skill_enabled_changed(skill_ref: String, enabled: bool) -> void:
	skill_enabled_requested.emit(skill_ref, enabled)


func _on_skill_remove_requested(skill_ref: String, skill_name: String) -> void:
	_close_skill_delete_confirmation()
	pending_delete_skill_ref = skill_ref
	skill_delete_confirmation_dialog = ConfirmationDialog.new()
	skill_delete_confirmation_dialog.title = "Remove personal skill"
	skill_delete_confirmation_dialog.dialog_text = "Delete %s and its personal skill directory?\n\nThis cannot be undone." % skill_name
	skill_delete_confirmation_dialog.ok_button_text = "Delete"
	add_child(skill_delete_confirmation_dialog)
	skill_delete_confirmation_dialog.confirmed.connect(_on_skill_delete_confirmed)
	skill_delete_confirmation_dialog.canceled.connect(_close_skill_delete_confirmation)
	skill_delete_confirmation_dialog.close_requested.connect(_close_skill_delete_confirmation)
	skill_delete_confirmation_dialog.popup_centered()


func _on_skill_delete_confirmed() -> void:
	if not pending_delete_skill_ref.is_empty():
		skill_remove_requested.emit(pending_delete_skill_ref)
	_close_skill_delete_confirmation()


func _on_skill_editor_save_requested(skill_ref: String, content: String) -> void:
	skill_update_requested.emit(skill_ref, content)


func _close_skill_editor() -> void:
	if active_skill_editor != null and is_instance_valid(active_skill_editor):
		active_skill_editor.queue_free()
	active_skill_editor = null


func _close_skill_delete_confirmation() -> void:
	pending_delete_skill_ref = ""
	if skill_delete_confirmation_dialog != null and is_instance_valid(skill_delete_confirmation_dialog):
		skill_delete_confirmation_dialog.queue_free()
	skill_delete_confirmation_dialog = null


func show_mcp_error(message_text: String) -> void:
	mcp_add_pending = false
	pending_mcp_update_server_id = ""
	pending_mcp_server_metadata.clear()
	mcp_status_label.visible = true
	mcp_status_label.text = message_text
	mcp_status_label.tooltip_text = message_text


func _on_confirmed() -> void:
	var api_key: String = deepseek_api_key_line_edit.text.strip_edges()
	frontend_config_save_requested.emit(
		backend_url_line_edit.text.strip_edges(),
		backend_dev_dir_line_edit.text.strip_edges(),
		next_step_hints_check_box.button_pressed,
		check_for_updates_check_box.button_pressed
	)
	user_prompt_save_requested.emit(custom_instructions_edit.text.strip_edges())
	provider_config_save_requested.emit(
		_get_selected_provider_id(),
		api_key,
		provider_base_url_line_edit.text.strip_edges(),
		_get_model_routing_payload()
	)
	if web_search_settings_loaded:
		var web_search_patch: Dictionary = {
			"enabled": web_search_enabled_check_box.button_pressed,
			"maxResults": int(web_search_max_results_spin_box.value),
			"maxKeywords": int(web_search_max_keywords_spin_box.value)
		}
		var selected_search_index: int = web_search_model_option_button.selected
		if selected_search_index >= 0 and selected_search_index < web_search_model_option_button.item_count:
			var selected_metadata: Variant = web_search_model_option_button.get_item_metadata(selected_search_index)
			if typeof(selected_metadata) == TYPE_DICTIONARY:
				var selected_search_model: Dictionary = selected_metadata as Dictionary
				web_search_patch["provider"] = str(selected_search_model.get("provider", ""))
				web_search_patch["model"] = str(selected_search_model.get("model", ""))
		web_search_settings_save_requested.emit(web_search_patch)
	queue_free()


func _on_clear_deepseek_api_key_button_pressed() -> void:
	provider_config_clear_requested.emit(_get_selected_provider_id())
	queue_free()


func _on_close_requested() -> void:
	queue_free()


func _populate_provider_options(active_provider_id: String) -> void:
	provider_option_button.clear()
	for provider_id: String in provider_order:
		var index: int = provider_option_button.get_item_count()
		provider_option_button.add_item(_get_provider_display_name(provider_id), index)
		provider_option_button.set_item_metadata(index, provider_id)

	for index: int in range(provider_option_button.get_item_count()):
		if str(provider_option_button.get_item_metadata(index)) == active_provider_id:
			provider_option_button.select(index)
			return

	provider_option_button.select(0)


func _populate_task_model_options(status: Dictionary) -> void:
	var routing: Dictionary = {}
	var routing_value: Variant = status.get("modelRouting", {})
	if typeof(routing_value) == TYPE_DICTIONARY:
		routing = routing_value as Dictionary

	_populate_task_model_option_button(image_recognition_model_option_button, "imageRecognition", routing)
	_populate_task_model_option_button(workflow_planner_model_option_button, "workflowPlanner", routing)
	_populate_task_model_option_button(session_title_model_option_button, "sessionTitle", routing)


func _populate_task_model_option_button(option_button: OptionButton, routing_key: String, routing: Dictionary) -> void:
	option_button.clear()
	option_button.add_item(USE_CURRENT_MODEL_TEXT, 0)
	option_button.set_item_metadata(0, null)

	var selected_provider: String = ""
	var selected_model: String = ""
	var selected_value: Variant = routing.get(routing_key, null)
	if typeof(selected_value) == TYPE_DICTIONARY:
		var selected_ref: Dictionary = selected_value as Dictionary
		selected_provider = str(selected_ref.get("provider", "")).strip_edges()
		selected_model = str(selected_ref.get("model", "")).strip_edges()

	for provider_id: String in provider_order:
		var provider_status: Dictionary = provider_status_by_id.get(provider_id, {}) as Dictionary
		if not bool(provider_status.get("configured", false)):
			continue

		var models: Array[Dictionary] = _collect_provider_task_models(provider_status)
		for model_data: Dictionary in models:
			var model_id: String = str(model_data.get("id", "")).strip_edges()
			if model_id.is_empty():
				continue

			var display_name: String = str(model_data.get("displayName", model_id)).strip_edges()
			if display_name.is_empty():
				display_name = model_id
			var item_index: int = option_button.get_item_count()
			option_button.add_item("%s / %s" % [_get_provider_display_name(provider_id), display_name], item_index)
			option_button.set_item_metadata(item_index, {
				"provider": provider_id,
				"model": model_id
			})

	if not selected_provider.is_empty() and not selected_model.is_empty():
		for index: int in range(option_button.get_item_count()):
			var metadata_value: Variant = option_button.get_item_metadata(index)
			if typeof(metadata_value) != TYPE_DICTIONARY:
				continue

			var metadata: Dictionary = metadata_value as Dictionary
			if str(metadata.get("provider", "")) == selected_provider and str(metadata.get("model", "")) == selected_model:
				option_button.select(index)
				return

		var missing_index: int = option_button.get_item_count()
		option_button.add_item("%s / %s" % [_get_provider_display_name(selected_provider), selected_model], missing_index)
		option_button.set_item_metadata(missing_index, {
			"provider": selected_provider,
			"model": selected_model
		})
		option_button.select(missing_index)
		return

	option_button.select(0)


func _collect_provider_task_models(provider_status: Dictionary) -> Array[Dictionary]:
	var models_by_id: Dictionary[String, Dictionary] = {}
	for key: String in ["modelsCache", "fallbackModels"]:
		var models_value: Variant = provider_status.get(key, [])
		if typeof(models_value) != TYPE_ARRAY:
			continue

		for item: Variant in models_value as Array:
			if typeof(item) != TYPE_DICTIONARY:
				continue

			var model_data: Dictionary = (item as Dictionary).duplicate(true)
			var model_id: String = str(model_data.get("id", "")).strip_edges()
			if model_id.is_empty() or models_by_id.has(model_id):
				continue
			models_by_id[model_id] = model_data

	var configured_model: String = str(provider_status.get("model", "")).strip_edges()
	if not configured_model.is_empty() and not models_by_id.has(configured_model):
		models_by_id[configured_model] = {
			"id": configured_model,
			"displayName": configured_model
		}

	var result: Array[Dictionary] = []
	for model_id: String in models_by_id.keys():
		result.append(models_by_id[model_id])
	return result


func _get_model_routing_payload() -> Dictionary:
	return {
		"imageRecognition": _get_task_model_ref(image_recognition_model_option_button),
		"workflowPlanner": _get_task_model_ref(workflow_planner_model_option_button),
		"sessionTitle": _get_task_model_ref(session_title_model_option_button)
	}


func _get_task_model_ref(option_button: OptionButton) -> Variant:
	var selected_index: int = option_button.selected
	if selected_index < 0 or selected_index >= option_button.get_item_count():
		return null

	var metadata_value: Variant = option_button.get_item_metadata(selected_index)
	if typeof(metadata_value) != TYPE_DICTIONARY:
		return null

	var metadata: Dictionary = metadata_value as Dictionary
	var provider_id: String = str(metadata.get("provider", "")).strip_edges()
	var model_id: String = str(metadata.get("model", "")).strip_edges()
	if provider_id.is_empty() or model_id.is_empty():
		return null

	return {
		"provider": provider_id,
		"model": model_id
	}


func _get_selected_provider_id() -> String:
	var selected_index: int = provider_option_button.selected
	if selected_index >= 0 and selected_index < provider_option_button.get_item_count():
		return str(provider_option_button.get_item_metadata(selected_index))

	return provider_order[0] if not provider_order.is_empty() else PROVIDER_IDS[0]


func _get_selected_provider_name() -> String:
	var selected_index: int = provider_option_button.selected
	if selected_index >= 0 and selected_index < provider_option_button.get_item_count():
		return provider_option_button.get_item_text(selected_index)

	return _get_provider_display_name(_get_selected_provider_id())


func _get_provider_display_name(provider_id: String) -> String:
	var provider_status: Dictionary = provider_status_by_id.get(provider_id, {}) as Dictionary
	var display_name: String = str(provider_status.get("displayName", "")).strip_edges()
	if not display_name.is_empty():
		return display_name

	for index: int in range(PROVIDER_IDS.size()):
		if PROVIDER_IDS[index] == provider_id:
			return PROVIDER_NAMES[index]

	return provider_id


func _get_optional_string(record: Dictionary, key: String) -> String:
	var value: Variant = record.get(key, null)
	if typeof(value) != TYPE_STRING:
		return ""

	return (value as String).strip_edges()


func _update_provider_key_labels() -> void:
	var provider_name: String = _get_selected_provider_name()
	var provider_status: Dictionary = provider_status_by_id.get(_get_selected_provider_id(), {}) as Dictionary
	var configured: bool = bool(provider_status.get("configured", false))
	var default_base_url: String = _get_optional_string(provider_status, "defaultBaseUrl")
	var custom_base_url: String = _get_optional_string(provider_status, "baseUrl")
	provider_base_url_line_edit.placeholder_text = default_base_url
	provider_base_url_line_edit.text = custom_base_url
	provider_base_url_line_edit.tooltip_text = "OpenAI-compatible request base URL for %s. Leave empty to use %s." % [
		provider_name,
		default_base_url if not default_base_url.is_empty() else "the provider default"
	]
	api_key_label.text = "%s API Key" % provider_name
	deepseek_api_key_line_edit.placeholder_text = "Set new API key" if configured else "Set API key"
	clear_deepseek_api_key_button.disabled = not configured
	clear_deepseek_api_key_button.tooltip_text = "Clear saved %s API key" % provider_name


func _on_provider_option_button_item_selected(_index: int) -> void:
	_update_provider_key_labels()


func _on_web_search_model_option_button_item_selected(_index: int) -> void:
	_update_web_search_keyword_controls()


func _update_web_search_keyword_controls() -> void:
	var supports_max_keywords: bool
	var charged_per_unit: bool
	var selected_index: int = web_search_model_option_button.selected
	if selected_index >= 0 and selected_index < web_search_model_option_button.item_count:
		var metadata_value: Variant = web_search_model_option_button.get_item_metadata(selected_index)
		if typeof(metadata_value) == TYPE_DICTIONARY:
			var metadata: Dictionary = metadata_value as Dictionary
			var search_options_value: Variant = metadata.get("searchOptions", {})
			if typeof(search_options_value) == TYPE_DICTIONARY:
				var search_options: Dictionary = search_options_value as Dictionary
				var max_keywords_value: Variant = search_options.get("maxKeywords", null)
				if typeof(max_keywords_value) == TYPE_DICTIONARY:
					var max_keywords: Dictionary = max_keywords_value as Dictionary
					supports_max_keywords = true
					web_search_max_keywords_spin_box.min_value = float(max_keywords.get("min", 1))
					web_search_max_keywords_spin_box.max_value = float(max_keywords.get("max", 3))
					charged_per_unit = bool(max_keywords.get("chargedPerUnit", false))

	web_search_max_keywords_label.visible = supports_max_keywords
	web_search_max_keywords_spin_box.visible = supports_max_keywords
	web_search_max_keywords_spin_box.editable = supports_max_keywords and web_search_settings_loaded
	web_search_notice_label.visible = charged_per_unit
	if charged_per_unit:
		web_search_notice_label.modulate = Color.WHITE
		web_search_notice_label.text = "This provider may charge for each search keyword. Enable its web search service and review pricing before use."


func _on_workspace_filter_option_button_item_selected(index: int) -> void:
	if index < 0 or index >= archived_workspace_filter_option_button.get_item_count():
		return

	archived_workspace_filter = str(archived_workspace_filter_option_button.get_item_metadata(index))
	_render_archived_sessions()


func _on_search_archived_chat_line_edit_text_changed(new_text: String) -> void:
	archived_search_text = new_text.strip_edges()
	_render_archived_sessions()


func _populate_archived_workspace_filter() -> void:
	var previous_filter: String = archived_workspace_filter
	var workspace_ids: PackedStringArray
	for metadata: Dictionary in archived_sessions:
		var workspace_id: String = str(metadata.get("workspaceId", ""))
		if workspace_ids.has(workspace_id):
			continue

		workspace_ids.append(workspace_id)

	archived_workspace_filter_option_button.clear()
	archived_workspace_filter_option_button.add_item("All", 0)
	archived_workspace_filter_option_button.set_item_metadata(0, "")

	for workspace_id: String in workspace_ids:
		archived_workspace_filter_option_button.add_item(_format_workspace_name(workspace_id))
		archived_workspace_filter_option_button.set_item_metadata(
			archived_workspace_filter_option_button.get_item_count() - 1,
			workspace_id
		)

	archived_workspace_filter = ""
	for index: int in range(archived_workspace_filter_option_button.get_item_count()):
		if str(archived_workspace_filter_option_button.get_item_metadata(index)) == previous_filter:
			archived_workspace_filter = previous_filter
			archived_workspace_filter_option_button.select(index)
			return

	archived_workspace_filter_option_button.select(0)


func _render_mcp_servers() -> void:
	for child_node: Node in mcp_server_list.get_children():
		child_node.queue_free()

	var has_update_pending: bool = not pending_mcp_update_server_id.is_empty()
	add_mcp_server_button.disabled = not mcp_backend_available or mcp_add_pending or has_update_pending
	add_mcp_server_button.tooltip_text = "Adding custom MCP server..." if mcp_add_pending else ("Updating custom MCP server..." if has_update_pending else ("Add custom MCP server" if mcp_backend_available else "Backend is disconnected"))
	if not mcp_backend_available:
		mcp_status_label.visible = true
		mcp_status_label.text = "Backend is disconnected. MCP server settings are unavailable."
	elif mcp_add_pending:
		mcp_status_label.visible = true
		mcp_status_label.text = "Adding custom MCP server..."
	elif has_update_pending:
		mcp_status_label.visible = true
		mcp_status_label.text = "Updating custom MCP server..."
	elif custom_mcp_servers.is_empty():
		mcp_status_label.visible = true
		mcp_status_label.text = "No custom MCP servers"
	else:
		mcp_status_label.visible = true
		mcp_status_label.text = _format_mcp_status()
		mcp_status_label.tooltip_text = mcp_status_label.text

	var rendered_servers: Array[Dictionary] = []
	for metadata: Dictionary in custom_mcp_servers:
		var rendered_metadata: Dictionary = metadata.duplicate(true)
		if str(rendered_metadata.get("id", "")) == pending_mcp_update_server_id:
			rendered_metadata["pending"] = true
			rendered_metadata["status"] = "connecting"
		rendered_servers.append(rendered_metadata)
	if mcp_add_pending and not pending_mcp_server_metadata.is_empty():
		rendered_servers.append(pending_mcp_server_metadata.duplicate(true) as Dictionary)

	if rendered_servers.is_empty():
		return

	var item_scene: PackedScene = load(MCP_SERVER_ITEM_SCENE_UID) as PackedScene
	if item_scene == null:
		return

	for metadata: Dictionary in rendered_servers:
		var mcp_server_item: Node = item_scene.instantiate()
		mcp_server_list.add_child(mcp_server_item)
		mcp_server_item.call("setup", metadata)
		mcp_server_item.connect("remove_requested", Callable(self, "_on_mcp_server_item_remove_requested"))
		mcp_server_item.connect("edit_requested", Callable(self, "_on_mcp_server_item_edit_requested"))
		mcp_server_item.connect("enabled_changed", Callable(self, "_on_mcp_server_item_enabled_changed"))


func _format_mcp_status() -> String:
	var enabled_count: int
	var connected_count: int
	for metadata: Dictionary in custom_mcp_servers:
		if bool(metadata.get("enabled", false)):
			enabled_count += 1
		if str(metadata.get("status", "")) == "connected":
			connected_count += 1
	return "%d configured  ·  %d enabled  ·  %d connected" % [custom_mcp_servers.size(), enabled_count, connected_count]


func _render_archived_sessions() -> void:
	for child_node: Node in archived_chat_list.get_children():
		child_node.queue_free()

	var item_scene: PackedScene = load(ARCHIVED_CHAT_ITEM_SCENE_UID) as PackedScene
	if item_scene == null:
		return

	var rendered_count: int = 0
	for metadata: Dictionary in archived_sessions:
		if not _does_archived_session_match_filters(metadata):
			continue

		var archived_chat_item: Node = item_scene.instantiate()
		archived_chat_list.add_child(archived_chat_item)
		archived_chat_item.call(
			"setup",
			str(metadata.get("id", "")),
			str(metadata.get("title", "Untitled")),
			_format_archived_time(metadata)
		)
		archived_chat_item.connect(
			"restore_requested",
			Callable(self, "_on_archived_chat_item_restore_requested")
		)
		archived_chat_item.connect(
			"delete_requested",
			Callable(self, "_on_archived_chat_item_delete_requested")
		)
		rendered_count += 1

	if rendered_count == 0:
		var empty_label: Label = Label.new()
		empty_label.text = "No archived chats"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.theme_type_variation = &"LabelNoMargin"
		archived_chat_list.add_child(empty_label)

	_update_delete_all_archived_chats_button()


func _does_archived_session_match_filters(metadata: Dictionary) -> bool:
	if not archived_workspace_filter.is_empty() and str(metadata.get("workspaceId", "")) != archived_workspace_filter:
		return false

	if archived_search_text.is_empty():
		return true

	var query: String = archived_search_text.to_lower()
	var title_text: String = str(metadata.get("title", "")).to_lower()
	var workspace_id: String = str(metadata.get("workspaceId", ""))
	var workspace_text: String = _format_workspace_name(workspace_id).to_lower()

	return title_text.contains(query) or workspace_id.to_lower().contains(query) or workspace_text.contains(query)


func _format_archived_time(metadata: Dictionary) -> String:
	var archived_at: String = str(metadata.get("archivedAt", ""))
	if not archived_at.is_empty():
		return "Archived " + _format_relative_time(archived_at)

	return _format_relative_time(str(metadata.get("updatedAt", "")))


func _format_relative_time(timestamp: String) -> String:
	if timestamp.is_empty():
		return ""

	return timestamp.replace("T", " ").replace("Z", "")


func _format_workspace_name(workspace_id: String) -> String:
	if workspace_id.is_empty():
		return "No workspace"

	var workspace: Dictionary = archived_workspaces_by_id.get(workspace_id, {}) as Dictionary
	if workspace.is_empty():
		return workspace_id

	return str(workspace.get("name", workspace_id))


func _on_archived_chat_item_restore_requested(session_id: String) -> void:
	archived_session_restore_requested.emit(session_id)


func _on_archived_chat_item_delete_requested(session_id: String) -> void:
	if session_id.is_empty():
		return

	var title_text: String = _get_archived_session_title(session_id)
	var session_ids: PackedStringArray = [session_id]
	_show_archive_delete_confirmation(
		CONFIRM_ACTION_DELETE_ARCHIVED_SESSION,
		"Delete archived chat?",
		"Delete archived chat \"%s\" permanently?\n\nThis cannot be undone." % title_text,
		session_ids
	)


func _apply_editor_dialog_theme() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree() or _is_in_edited_scene():
		return

	var editor_theme: Theme = EditorInterface.get_editor_theme()
	if editor_theme == null:
		return

	var panel_style: StyleBox = _find_editor_settings_panel_style(editor_theme)
	if panel_style != null:
		var panel_style_copy: StyleBox = panel_style.duplicate(true) as StyleBox
		if panel_style_copy != null:
			add_theme_stylebox_override(PANEL_STYLE_NAME, panel_style_copy)

	_copy_accept_dialog_constant(editor_theme, BUTTONS_SEPARATION_CONSTANT)
	_copy_accept_dialog_constant(editor_theme, BUTTONS_MIN_WIDTH_CONSTANT)
	_copy_accept_dialog_constant(editor_theme, BUTTONS_MIN_HEIGHT_CONSTANT)


func _find_editor_settings_panel_style(editor_theme: Theme) -> StyleBox:
	var panel_style: StyleBox = _get_editor_stylebox(
		editor_theme,
		PANEL_STYLE_NAME,
		EDITOR_SETTINGS_DIALOG_TYPE
	)
	if panel_style != null:
		return panel_style

	panel_style = _get_editor_stylebox(editor_theme, PANEL_STYLE_NAME, ACCEPT_DIALOG_TYPE)
	if panel_style != null:
		return panel_style

	return _get_editor_stylebox(editor_theme, BASE_STYLE_NAME, EDITOR_TYPE)


func _get_editor_stylebox(
	editor_theme: Theme,
	style_name: StringName,
	theme_type: StringName
) -> StyleBox:
	if not editor_theme.has_stylebox(style_name, theme_type):
		return null

	return editor_theme.get_stylebox(style_name, theme_type)


func _copy_accept_dialog_constant(editor_theme: Theme, constant_name: StringName) -> void:
	if not editor_theme.has_constant(constant_name, ACCEPT_DIALOG_TYPE):
		return

	add_theme_constant_override(
		constant_name,
		editor_theme.get_constant(constant_name, ACCEPT_DIALOG_TYPE)
	)


func _is_in_edited_scene() -> bool:
	if not is_inside_tree():
		return false

	var edited_scene_root: Node = get_tree().get_edited_scene_root()
	if edited_scene_root == null:
		return false

	return edited_scene_root == self or edited_scene_root.is_ancestor_of(self)


func _on_custom_instructions_warning_button_pressed() -> void:
	if custom_instructions_warning_dialog != null and is_instance_valid(custom_instructions_warning_dialog):
		custom_instructions_warning_dialog.popup_centered()
		return

	var custom_instructions_text: String = custom_instructions_edit.text.strip_edges()
	var character_count: int = custom_instructions_text.length()
	custom_instructions_warning_dialog = AcceptDialog.new()
	custom_instructions_warning_dialog.title = "User prompt context"
	var dialog_lines: PackedStringArray = [
		"The user prompt is saved in the backend and applied to every chat request.",
		"",
		"Current size: %s",
		"",
		"Long prompts consume context before the conversation history is selected.",
		"",
		"Priority: backend/system rules > tool safety > project instruction files such as AGENTS.md > current chat request > user prompt."
	]
	custom_instructions_warning_dialog.dialog_text = "\n".join(dialog_lines) % _format_character_count(character_count)
	add_child(custom_instructions_warning_dialog)
	custom_instructions_warning_dialog.confirmed.connect(Callable(self, "_on_custom_instructions_warning_dialog_closed"))
	custom_instructions_warning_dialog.close_requested.connect(Callable(self, "_on_custom_instructions_warning_dialog_closed"))
	custom_instructions_warning_dialog.popup_centered()


func _on_delete_all_archived_chats_button_pressed() -> void:
	if archived_sessions.is_empty():
		return

	var session_ids: PackedStringArray
	for metadata: Dictionary in archived_sessions:
		var session_id: String = str(metadata.get("id", ""))
		if session_id.is_empty():
			continue

		session_ids.append(session_id)

	if session_ids.is_empty():
		return

	_show_archive_delete_confirmation(
		CONFIRM_ACTION_DELETE_ALL_ARCHIVED_SESSIONS,
		"Delete all archived chats?",
		"Delete all %d archived chats permanently?\n\nThis cannot be undone." % session_ids.size(),
		session_ids
	)


func _on_custom_instructions_edit_text_changed() -> void:
	_update_custom_instructions_status()


func _update_custom_instructions_status() -> void:
	if custom_instructions_edit == null or custom_instructions_warning_button == null:
		return

	var custom_instructions_text: String = custom_instructions_edit.text.strip_edges()
	var character_count: int = custom_instructions_text.length()
	var has_custom_instructions: bool = character_count > 0
	var status_text: String = _format_custom_instructions_status(character_count)

	custom_instructions_label.text = "User prompt"
	custom_instructions_label.tooltip_text = status_text
	custom_instructions_edit.tooltip_text = status_text
	custom_instructions_warning_button.visible = character_count >= CUSTOM_INSTRUCTIONS_WARNING_CHARS
	custom_instructions_warning_button.disabled = not has_custom_instructions
	custom_instructions_warning_button.tooltip_text = status_text


func _format_custom_instructions_status(character_count: int) -> String:
	if character_count <= 0:
		return "No backend user prompt is configured."

	var status_text: String = "Backend user prompt: %s." % _format_character_count(character_count)
	if character_count >= CUSTOM_INSTRUCTIONS_HEAVY_CHARS:
		return status_text + " This is very long and will consume a noticeable amount of context every request."
	if character_count >= CUSTOM_INSTRUCTIONS_WARNING_CHARS:
		return status_text + " This is long enough to affect context usage every request."

	return status_text + " Priority: backend/system rules > tool safety > project instruction files > current chat request > user prompt."


func _format_character_count(character_count: int) -> String:
	if character_count >= 1000:
		return "%.1fk chars" % (float(character_count) / 1000.0)

	return "%d chars" % character_count


func _get_archived_session_title(session_id: String) -> String:
	for metadata: Dictionary in archived_sessions:
		if str(metadata.get("id", "")) == session_id:
			var title_text: String = str(metadata.get("title", "Untitled")).strip_edges()
			if not title_text.is_empty():
				return title_text

	return "Untitled"


func _show_archive_delete_confirmation(
	action: StringName,
	title_text: String,
	message_text: String,
	session_ids: PackedStringArray
) -> void:
	if session_ids.is_empty():
		return

	_close_archive_delete_confirmation_dialog()
	pending_confirmation_action = action
	pending_delete_session_id = session_ids[0]
	pending_delete_session_ids.clear()
	for session_id: String in session_ids:
		pending_delete_session_ids.append(session_id)

	archive_delete_confirmation_dialog = ConfirmationDialog.new()
	archive_delete_confirmation_dialog.title = title_text
	archive_delete_confirmation_dialog.dialog_text = message_text
	archive_delete_confirmation_dialog.ok_button_text = "Delete"
	add_child(archive_delete_confirmation_dialog)
	archive_delete_confirmation_dialog.confirmed.connect(Callable(self, "_on_archive_delete_confirmation_confirmed"))
	archive_delete_confirmation_dialog.canceled.connect(Callable(self, "_on_archive_delete_confirmation_closed"))
	archive_delete_confirmation_dialog.close_requested.connect(Callable(self, "_on_archive_delete_confirmation_closed"))
	archive_delete_confirmation_dialog.popup_centered()


func _on_archive_delete_confirmation_confirmed() -> void:
	if pending_confirmation_action == CONFIRM_ACTION_DELETE_ARCHIVED_SESSION:
		archived_session_delete_requested.emit(pending_delete_session_id)
	elif pending_confirmation_action == CONFIRM_ACTION_DELETE_ALL_ARCHIVED_SESSIONS:
		for session_id: String in pending_delete_session_ids:
			archived_session_delete_requested.emit(session_id)

	_on_archive_delete_confirmation_closed()


func _on_archive_delete_confirmation_closed() -> void:
	pending_confirmation_action = CONFIRM_ACTION_NONE
	pending_delete_session_id = ""
	pending_delete_session_ids.clear()
	_close_archive_delete_confirmation_dialog()


func _close_archive_delete_confirmation_dialog() -> void:
	if archive_delete_confirmation_dialog == null or not is_instance_valid(archive_delete_confirmation_dialog):
		archive_delete_confirmation_dialog = null
		return

	archive_delete_confirmation_dialog.queue_free()
	archive_delete_confirmation_dialog = null


func _on_custom_instructions_warning_dialog_closed() -> void:
	if custom_instructions_warning_dialog == null or not is_instance_valid(custom_instructions_warning_dialog):
		custom_instructions_warning_dialog = null
		return

	custom_instructions_warning_dialog.queue_free()
	custom_instructions_warning_dialog = null


func _update_delete_all_archived_chats_button() -> void:
	if delete_all_archived_chats_button == null:
		return

	delete_all_archived_chats_button.disabled = archived_sessions.is_empty()
	delete_all_archived_chats_button.tooltip_text = "Delete all archived chats permanently." if not archived_sessions.is_empty() else "No archived chats to delete."


func _on_add_mcp_server_button_pressed() -> void:
	if not mcp_backend_available:
		show_mcp_error("Backend is disconnected. Reconnect before adding an MCP server.")
		return

	var packed_scene: PackedScene = load(ADD_MCP_SERVER_DIALOG_UID) as PackedScene
	if packed_scene == null:
		show_mcp_error("Add MCP server dialog could not be loaded.")
		return

	var dialog: ConfirmationDialog = packed_scene.instantiate() as ConfirmationDialog
	add_child(dialog)
	var submit_callable: Callable = Callable(self, "_on_add_mcp_server_dialog_submitted").bind(dialog)
	dialog.connect("server_config_submitted", submit_callable)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()


func _on_add_mcp_server_dialog_submitted(config: Dictionary, dialog: ConfirmationDialog) -> void:
	mcp_add_pending = true
	pending_mcp_server_metadata = _create_pending_mcp_server_metadata(config)
	mcp_server_add_requested.emit(config)
	_render_mcp_servers()
	if dialog != null and is_instance_valid(dialog):
		dialog.queue_free()


func _create_pending_mcp_server_metadata(config: Dictionary) -> Dictionary:
	var metadata: Dictionary = {
		"id": "__pending_mcp_server__",
		"name": str(config.get("name", "Custom MCP")),
		"description": str(config.get("description", "")),
		"transport": str(config.get("transport", "stdio")),
		"enabled": true,
		"status": "connecting",
		"toolCount": 0,
		"pending": true
	}

	var command_text: String = str(config.get("command", "")).strip_edges()
	if not command_text.is_empty():
		metadata["command"] = command_text

	var url_text: String = str(config.get("url", "")).strip_edges()
	if not url_text.is_empty():
		metadata["url"] = url_text

	var env_value: Variant = config.get("env", {})
	if typeof(env_value) == TYPE_DICTIONARY:
		metadata["envNames"] = (env_value as Dictionary).keys()

	var headers_value: Variant = config.get("headers", {})
	if typeof(headers_value) == TYPE_DICTIONARY:
		metadata["headerNames"] = (headers_value as Dictionary).keys()

	return metadata


func _on_mcp_server_item_edit_requested(server_id: String) -> void:
	if server_id.is_empty():
		return
	if not mcp_backend_available:
		show_mcp_error("Backend is disconnected. Reconnect before editing MCP servers.")
		return

	var metadata: Dictionary = _find_mcp_server_metadata(server_id)
	if metadata.is_empty():
		show_mcp_error("MCP server could not be found.")
		return

	var packed_scene: PackedScene = load(EDIT_MCP_SERVER_DIALOG_UID) as PackedScene
	if packed_scene == null:
		show_mcp_error("Edit MCP server dialog could not be loaded.")
		return

	var dialog: ConfirmationDialog = packed_scene.instantiate() as ConfirmationDialog
	add_child(dialog)
	dialog.call("setup_server", metadata)
	var submit_callable: Callable = Callable(self, "_on_edit_mcp_server_dialog_submitted").bind(dialog)
	dialog.connect("server_config_submitted", submit_callable)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()


func _on_edit_mcp_server_dialog_submitted(server_id: String, config: Dictionary, dialog: ConfirmationDialog) -> void:
	if server_id.is_empty():
		show_mcp_error("MCP server id is missing.")
		return

	pending_mcp_update_server_id = server_id
	mcp_server_update_requested.emit(server_id, config)
	_render_mcp_servers()
	if dialog != null and is_instance_valid(dialog):
		dialog.queue_free()


func _on_mcp_server_item_enabled_changed(server_id: String, enabled: bool) -> void:
	if server_id.is_empty():
		return
	if not mcp_backend_available:
		show_mcp_error("Backend is disconnected. Reconnect before changing MCP servers.")
		_render_mcp_servers()
		return

	mcp_server_enabled_requested.emit(server_id, enabled)


func _on_mcp_server_item_remove_requested(server_id: String) -> void:
	if server_id.is_empty():
		return
	if not mcp_backend_available:
		show_mcp_error("Backend is disconnected. Reconnect before removing MCP servers.")
		return

	var server_name: String = _get_mcp_server_name(server_id)
	_close_mcp_delete_confirmation_dialog()
	pending_delete_mcp_server_id = server_id
	mcp_delete_confirmation_dialog = ConfirmationDialog.new()
	mcp_delete_confirmation_dialog.title = "Remove MCP server?"
	mcp_delete_confirmation_dialog.dialog_text = "Remove custom MCP server \"%s\"?\n\nSaved env/header secrets for this server will be deleted." % server_name
	mcp_delete_confirmation_dialog.ok_button_text = "Remove"
	add_child(mcp_delete_confirmation_dialog)
	mcp_delete_confirmation_dialog.confirmed.connect(Callable(self, "_on_mcp_delete_confirmation_confirmed"))
	mcp_delete_confirmation_dialog.canceled.connect(Callable(self, "_on_mcp_delete_confirmation_closed"))
	mcp_delete_confirmation_dialog.close_requested.connect(Callable(self, "_on_mcp_delete_confirmation_closed"))
	mcp_delete_confirmation_dialog.popup_centered()


func _on_mcp_delete_confirmation_confirmed() -> void:
	if not pending_delete_mcp_server_id.is_empty():
		mcp_server_remove_requested.emit(pending_delete_mcp_server_id)

	_on_mcp_delete_confirmation_closed()


func _on_mcp_delete_confirmation_closed() -> void:
	pending_delete_mcp_server_id = ""
	_close_mcp_delete_confirmation_dialog()


func _close_mcp_delete_confirmation_dialog() -> void:
	if mcp_delete_confirmation_dialog == null or not is_instance_valid(mcp_delete_confirmation_dialog):
		mcp_delete_confirmation_dialog = null
		return

	mcp_delete_confirmation_dialog.queue_free()
	mcp_delete_confirmation_dialog = null


func _get_mcp_server_name(server_id: String) -> String:
	for metadata: Dictionary in custom_mcp_servers:
		if str(metadata.get("id", "")) == server_id:
			var server_name: String = str(metadata.get("name", "Custom MCP")).strip_edges()
			if not server_name.is_empty():
				return server_name

	return "Custom MCP"


func _find_mcp_server_metadata(server_id: String) -> Dictionary:
	for metadata: Dictionary in custom_mcp_servers:
		if str(metadata.get("id", "")) == server_id:
			return metadata.duplicate(true)

	return {}


func _on_backend_dev_dir_button_pressed() -> void:
	var current_dir_text: String = backend_dev_dir_line_edit.text.strip_edges()
	if not current_dir_text.is_empty() and DirAccess.dir_exists_absolute(current_dir_text):
		file_dialog.current_dir = current_dir_text

	file_dialog.popup_centered_ratio()


func _on_backend_dev_dir_selected(dir_path: String) -> void:
	backend_dev_dir_line_edit.text = dir_path.strip_edges()
