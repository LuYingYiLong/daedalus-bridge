@tool
extends MarginContainer

signal action_requested(action_id: String)
signal inline_diff_undo_requested(summary: Dictionary)
signal plan_details_requested(plan_id: String, fallback_markdown: String)

const TOOL_CALL_ITEM_SCENE: PackedScene = preload("uid://c2a5o7qi58fus")
const STATUS_ITEM_SCENE: PackedScene = preload("uid://cljnln76ye4o5")
const INLINE_DIFF_VIEWER_SCENE: PackedScene = preload("uid://s13mo8fn3boc")
const PLAN_PREVIEW_ITEM_SCENE: PackedScene = preload("uid://cs2l8rbjvetsi")
const MARKDOWN_THEME: Theme = preload("uid://dhartxld7pqyb")
const ELAPSED_UPDATE_INTERVAL_SECONDS: float = 1.0
const STREAM_MARKDOWN_LAYOUT_FLUSH_MSEC: int = 96
const STREAM_MARKDOWN_MAX_UNSTABLE_LINES: int = 12

@onready var header_container: VBoxContainer = $VBoxContainer/HeaderContainer
@onready var elapsed_time_label: Label = %ElapsedTimeLabel
@onready var body_container: VBoxContainer = %BodyContainer
@onready var footer_container: HBoxContainer = %FooterContainer
@onready var end_time_label: Label = %EndTimeLabel

var current_markdown_label: MarkdownLabel
var markdown_segments: PackedStringArray = PackedStringArray()
var tool_items_by_call_id: Dictionary[String, Node] = {}
var thinking_item: Node
var thinking_finished_current: bool
var started_at_utc_current: String
var completed_at_utc_current: String
var elapsed_update_accumulator: float
var summary_started_current: bool
var summary_fold_container: FoldableContainer
var summary_fold_body_container: VBoxContainer
var lazy_summary_parts: Array[Dictionary]
var lazy_summary_loaded: bool
var body_part_container_override: VBoxContainer


func clear_message() -> void:
	for child: Node in body_container.get_children():
		child.queue_free()

	current_markdown_label = null
	markdown_segments.clear()
	tool_items_by_call_id.clear()
	thinking_item = null
	thinking_finished_current = false
	summary_started_current = false
	summary_fold_container = null
	summary_fold_body_container = null
	lazy_summary_parts.clear()
	lazy_summary_loaded = false
	body_part_container_override = null
	_set_completion_times("", "")


func append_delta(delta_text: String) -> void:
	if delta_text.is_empty():
		return

	var label: MarkdownLabel = _ensure_current_markdown_label()
	label.append_text(delta_text)
	if markdown_segments.is_empty():
		markdown_segments.append(delta_text)
	else:
		markdown_segments[markdown_segments.size() - 1] += delta_text


func finish_message(started_at_utc: String = "", completed_at_utc: String = "") -> void:
	_finish_current_markdown_label()
	var normalized_started_at: String = started_at_utc.strip_edges()
	var normalized_completed_at: String = completed_at_utc.strip_edges()
	if normalized_started_at.is_empty():
		normalized_started_at = started_at_utc_current
	if normalized_completed_at.is_empty() and not normalized_started_at.is_empty():
		normalized_completed_at = _get_utc_timestamp()
	_set_completion_times(normalized_started_at, normalized_completed_at)


func setup(
	message_text: String,
	started_at_utc: String = "",
	completed_at_utc: String = "",
	body_parts: Array = []
) -> void:
	clear_message()
	if not body_parts.is_empty():
		_setup_body_parts(body_parts)
	elif not message_text.is_empty():
		append_delta(message_text)
		if not completed_at_utc.strip_edges().is_empty():
			_finish_current_markdown_label()
	_set_completion_times(started_at_utc, completed_at_utc)


func add_tool_event(event_data: Dictionary) -> Node:
	_finish_current_markdown_label()
	var tool_call_id: String = _get_tool_call_key(event_data)
	var tool_item: Node = TOOL_CALL_ITEM_SCENE.instantiate()
	_get_body_part_container().add_child(tool_item)
	if tool_item.has_signal("content_height_changed"):
		tool_item.connect("content_height_changed", Callable(self, "_on_body_child_content_height_changed"))
	tool_item.call("setup_tool_event", event_data)
	if not tool_call_id.is_empty():
		tool_items_by_call_id[tool_call_id] = tool_item
	return tool_item


func append_tool_event(event_data: Dictionary) -> void:
	var tool_call_id: String = _get_tool_call_key(event_data)
	var tool_item: Node = tool_items_by_call_id.get(tool_call_id, null) as Node
	if tool_item == null:
		add_tool_event(event_data)
		return

	tool_item.call("append_tool_event", event_data)


func get_tool_item(tool_call_id: String) -> Node:
	return tool_items_by_call_id.get(tool_call_id, null) as Node


func add_thinking() -> Node:
	_finish_current_markdown_label()
	if thinking_item != null and is_instance_valid(thinking_item) and not thinking_finished_current:
		return thinking_item

	thinking_item = TOOL_CALL_ITEM_SCENE.instantiate()
	thinking_finished_current = false
	_get_body_part_container().add_child(thinking_item)
	if thinking_item.has_signal("content_height_changed"):
		thinking_item.connect("content_height_changed", Callable(self, "_on_body_child_content_height_changed"))
	thinking_item.call("setup_thinking")
	return thinking_item


func append_thinking_delta(delta_text: String) -> void:
	if delta_text.is_empty():
		return

	var item: Node = add_thinking()
	item.call("append_thinking_delta", delta_text)


func finish_thinking() -> void:
	if thinking_item == null or not is_instance_valid(thinking_item):
		return

	thinking_item.call("finish_thinking")
	thinking_finished_current = true


func get_thinking_item() -> Node:
	return thinking_item if thinking_item != null and is_instance_valid(thinking_item) and not thinking_finished_current else null


func add_status(status_data: Dictionary) -> Node:
	_finish_current_markdown_label()
	var status_item: Node = STATUS_ITEM_SCENE.instantiate()
	_get_body_part_container().add_child(status_item)
	if status_item.has_signal("action_requested"):
		status_item.connect("action_requested", Callable(self, "_on_status_item_action_requested"))
	status_item.call(
		"setup",
		str(status_data.get("status", "message")),
		str(status_data.get("title", "")),
		str(status_data.get("details", status_data.get("detail", ""))),
		str(status_data.get("actionLabel", status_data.get("action_label", ""))),
		str(status_data.get("actionId", status_data.get("action_id", ""))),
		str(status_data.get("iconUid", status_data.get("icon_uid", "")))
	)
	return status_item


func add_inline_diff_viewer(summary: Dictionary) -> Node:
	_finish_current_markdown_label()
	var inline_diff_viewer: Node = INLINE_DIFF_VIEWER_SCENE.instantiate()
	_get_body_part_container().add_child(inline_diff_viewer)
	if inline_diff_viewer.has_signal("undo_requested"):
		inline_diff_viewer.connect("undo_requested", Callable(self, "_on_inline_diff_undo_requested"))
	inline_diff_viewer.call("setup", summary)
	return inline_diff_viewer


func add_plan_preview(plan_data: Dictionary) -> Node:
	_finish_current_markdown_label()
	var plan_preview: Node = PLAN_PREVIEW_ITEM_SCENE.instantiate()
	_get_body_part_container().add_child(plan_preview)
	if plan_preview.has_signal("details_requested"):
		plan_preview.connect("details_requested", Callable(self, "_on_plan_details_requested"))
	plan_preview.call("setup", plan_data)
	return plan_preview


func begin_summary(summary_data: Dictionary) -> void:
	_finish_current_markdown_label()
	if summary_started_current:
		return

	summary_started_current = true
	var fold_children: Array[Node] = []
	for child: Node in body_container.get_children():
		fold_children.append(child)

	if fold_children.is_empty():
		return

	var fold_title: String = str(summary_data.get("foldTitle", "总结前的过程")).strip_edges()
	if fold_title.is_empty():
		fold_title = "总结前的过程"

	summary_fold_container = FoldableContainer.new()
	summary_fold_container.title = fold_title
	summary_fold_container.title_text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary_fold_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_foldable_container_folded(summary_fold_container, true)

	summary_fold_body_container = VBoxContainer.new()
	summary_fold_body_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_fold_container.add_child(summary_fold_body_container)

	body_container.add_child(summary_fold_container)
	body_container.move_child(summary_fold_container, 0)
	for child: Node in fold_children:
		body_container.remove_child(child)
		summary_fold_body_container.add_child(child)

	queue_sort()


func _begin_lazy_summary(summary_data: Dictionary, pre_summary_parts: Array[Dictionary]) -> void:
	if summary_started_current:
		return

	summary_started_current = true
	if pre_summary_parts.is_empty():
		return

	var fold_title: String = str(summary_data.get("foldTitle", "总结前的过程")).strip_edges()
	if fold_title.is_empty():
		fold_title = "总结前的过程"

	summary_fold_container = FoldableContainer.new()
	summary_fold_container.title = fold_title
	summary_fold_container.title_text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary_fold_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_foldable_container_folded(summary_fold_container, true)

	summary_fold_body_container = VBoxContainer.new()
	summary_fold_body_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_fold_container.add_child(summary_fold_body_container)
	body_container.add_child(summary_fold_container)

	lazy_summary_parts.clear()
	for part: Dictionary in pre_summary_parts:
		lazy_summary_parts.append(part.duplicate(true))
	lazy_summary_loaded = false
	set_process(true)


func _maybe_load_lazy_summary_on_expand() -> bool:
	if lazy_summary_loaded or lazy_summary_parts.is_empty():
		return false
	if summary_fold_container == null or not is_instance_valid(summary_fold_container):
		return false
	if summary_fold_body_container == null or not is_instance_valid(summary_fold_body_container):
		return false
	if _is_foldable_container_folded(summary_fold_container):
		return true

	body_part_container_override = summary_fold_body_container
	for part: Dictionary in lazy_summary_parts:
		_setup_body_part(part)
	body_part_container_override = null
	lazy_summary_loaded = true
	lazy_summary_parts.clear()
	queue_sort()
	return false


func _get_body_part_container() -> VBoxContainer:
	if body_part_container_override != null and is_instance_valid(body_part_container_override):
		return body_part_container_override

	return body_container


func _on_mouse_entered() -> void:
	footer_container.modulate.a = 1.0


func _on_mouse_exited() -> void:
	footer_container.modulate.a = 0.0


func _on_copy_button_pressed() -> void:
	DisplayServer.clipboard_set("\n\n".join(markdown_segments))


func _process(delta: float) -> void:
	var has_pending_lazy_summary: bool = _maybe_load_lazy_summary_on_expand()
	if started_at_utc_current.is_empty() or not completed_at_utc_current.is_empty():
		if has_pending_lazy_summary:
			set_process(true)
			return

		set_process(false)
		return

	elapsed_update_accumulator += delta
	if elapsed_update_accumulator < ELAPSED_UPDATE_INTERVAL_SECONDS:
		return

	elapsed_update_accumulator = 0.0
	_update_elapsed_label(started_at_utc_current, _get_utc_timestamp())


func _setup_body_parts(body_parts: Array) -> void:
	var pre_summary_parts: Array[Dictionary] = []
	var summary_seen: bool = false

	for part_value: Variant in body_parts:
		if typeof(part_value) != TYPE_DICTIONARY:
			continue

		var part: Dictionary = part_value as Dictionary
		var part_type: String = str(part.get("type", ""))
		if not summary_seen:
			if part_type == "summary_start":
				_begin_lazy_summary(part, pre_summary_parts)
				summary_seen = true
				continue

			pre_summary_parts.append(part.duplicate(true))
			continue

		_setup_body_part(part)

	if not summary_seen:
		for part: Dictionary in pre_summary_parts:
			_setup_body_part(part)


func _setup_body_part(part: Dictionary) -> void:
	var part_type: String = str(part.get("type", ""))
	if part_type == "markdown":
		var text: String = str(part.get("text", ""))
		if text.is_empty():
			return

		append_delta(text)
		_finish_current_markdown_label()
	elif part_type == "tool":
		var events_value: Variant = part.get("events", [])
		if typeof(events_value) != TYPE_ARRAY:
			return

		var events: Array = events_value as Array
		var is_first_event: bool = true
		for event_value: Variant in events:
			if typeof(event_value) != TYPE_DICTIONARY:
				continue

			var event_data: Dictionary = event_value as Dictionary
			if is_first_event:
				add_tool_event(event_data)
				is_first_event = false
			else:
				append_tool_event(event_data)
	elif part_type == "thinking":
		var text: String = str(part.get("text", ""))
		if not text.is_empty():
			append_thinking_delta(text)
		else:
			add_thinking()
		if bool(part.get("done", false)):
			finish_thinking()
	elif part_type == "status":
		add_status(part)
	elif part_type == "inline_diff":
		add_inline_diff_viewer(part)
	elif part_type == "plan":
		add_plan_preview(part)
	elif part_type == "summary_start":
		begin_summary(part)


func _ensure_current_markdown_label() -> MarkdownLabel:
	if current_markdown_label != null and is_instance_valid(current_markdown_label):
		return current_markdown_label

	current_markdown_label = MarkdownLabel.new()
	current_markdown_label.content_margin = 8
	current_markdown_label.context_menu_enabled = true
	current_markdown_label.fit_content = true
	current_markdown_label.scroll_active = false
	current_markdown_label.streaming_enabled = true
	current_markdown_label.deferred_layout_enabled = true
	current_markdown_label.max_unstable_lines = STREAM_MARKDOWN_MAX_UNSTABLE_LINES
	current_markdown_label.layout_flush_interval_msec = STREAM_MARKDOWN_LAYOUT_FLUSH_MSEC
	current_markdown_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	current_markdown_label.theme = MARKDOWN_THEME
	_get_body_part_container().add_child(current_markdown_label)
	current_markdown_label.clear()
	markdown_segments.append("")
	return current_markdown_label


func _finish_current_markdown_label() -> void:
	if current_markdown_label == null or not is_instance_valid(current_markdown_label):
		current_markdown_label = null
		return

	current_markdown_label.finish_stream()
	current_markdown_label = null


func _set_foldable_container_folded(container: FoldableContainer, is_folded: bool) -> void:
	for property: Dictionary in container.get_property_list():
		var property_name: String = str(property.get("name", ""))
		if property_name == "folded" or property_name == "collapsed":
			container.set(property_name, is_folded)
			return
		if property_name == "expanded":
			container.set(property_name, not is_folded)
			return


func _is_foldable_container_folded(container: FoldableContainer) -> bool:
	for property: Dictionary in container.get_property_list():
		var property_name: String = str(property.get("name", ""))
		if property_name == "folded" or property_name == "collapsed":
			return bool(container.get(property_name))
		if property_name == "expanded":
			return not bool(container.get(property_name))

	return true


func _on_body_child_content_height_changed() -> void:
	queue_sort()


func _on_status_item_action_requested(action_id: String) -> void:
	action_requested.emit(action_id)


func _on_inline_diff_undo_requested(summary: Dictionary) -> void:
	inline_diff_undo_requested.emit(summary)


func _on_plan_details_requested(plan_id: String, fallback_markdown: String) -> void:
	plan_details_requested.emit(plan_id, fallback_markdown)


func _set_completion_times(started_at_utc: String, completed_at_utc: String) -> void:
	var normalized_completed_at: String = completed_at_utc.strip_edges()
	var normalized_started_at: String = started_at_utc.strip_edges()
	started_at_utc_current = normalized_started_at
	completed_at_utc_current = normalized_completed_at
	var has_started_time: bool = not normalized_started_at.is_empty()
	var has_completed_time: bool = not normalized_completed_at.is_empty()

	end_time_label.visible = has_completed_time
	if has_completed_time:
		end_time_label.text = "Completed: %s" % _format_utc_time(normalized_completed_at)

	header_container.visible = has_started_time
	if has_started_time:
		var elapsed_until: String = normalized_completed_at if has_completed_time else _get_utc_timestamp()
		_update_elapsed_label(normalized_started_at, elapsed_until)

	set_process(has_started_time and not has_completed_time)


func _update_elapsed_label(started_at_utc: String, until_utc: String) -> void:
	var elapsed_seconds: int = maxi(0, _timestamp_to_unix(until_utc) - _timestamp_to_unix(started_at_utc))
	elapsed_time_label.text = "Elapsed: %s" % _format_elapsed_seconds(elapsed_seconds)


func _format_utc_time(timestamp: String) -> String:
	var formatted_timestamp: String = timestamp.strip_edges()
	if formatted_timestamp.is_empty():
		return ""
	if formatted_timestamp.ends_with(" UTC"):
		return formatted_timestamp
	if formatted_timestamp.ends_with("Z"):
		formatted_timestamp = formatted_timestamp.substr(0, formatted_timestamp.length() - 1)
	var dot_index: int = formatted_timestamp.find(".")
	if dot_index >= 0:
		formatted_timestamp = formatted_timestamp.substr(0, dot_index)
	formatted_timestamp = formatted_timestamp.replace("T", " ")
	return "%s UTC" % formatted_timestamp


func _timestamp_to_unix(timestamp: String) -> int:
	var normalized_timestamp: String = timestamp.strip_edges()
	if normalized_timestamp.ends_with("Z"):
		normalized_timestamp = normalized_timestamp.substr(0, normalized_timestamp.length() - 1)
	var dot_index: int = normalized_timestamp.find(".")
	if dot_index >= 0:
		normalized_timestamp = normalized_timestamp.substr(0, dot_index)
	normalized_timestamp = normalized_timestamp.replace("T", " ")
	return int(Time.get_unix_time_from_datetime_string(normalized_timestamp))


func _get_utc_timestamp() -> String:
	return "%sZ" % Time.get_datetime_string_from_system(true, false)


func _get_tool_call_key(event_data: Dictionary) -> String:
	var tool_call_id: String = str(event_data.get("toolCallId", ""))
	if not tool_call_id.is_empty():
		return tool_call_id

	var approval_id: String = str(event_data.get("approvalId", ""))
	if not approval_id.is_empty():
		return "approval:%s" % approval_id

	return str(event_data.get("toolName", "tool"))


func _format_elapsed_seconds(elapsed_seconds: int) -> String:
	if elapsed_seconds < 60:
		return "%ds" % elapsed_seconds
	if elapsed_seconds < 3600:
		return "%dm %02ds" % [int(elapsed_seconds / 60), elapsed_seconds % 60]

	return "%dh %02dm %02ds" % [int(elapsed_seconds / 3600), int(elapsed_seconds / 60) % 60, elapsed_seconds % 60]
