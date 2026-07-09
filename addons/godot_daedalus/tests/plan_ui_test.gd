@tool
extends SceneTree

const CLARIFICATION_DIALOG_SCENE: PackedScene = preload("uid://dsi4mi4uglngs")
const PLAN_APPROVAL_DIALOG_SCENE: PackedScene = preload("uid://bh21xppsf6yrh")
const PLAN_PREVIEW_ITEM_SCENE: PackedScene = preload("uid://cs2l8rbjvetsi")
const MAIN_SCRIPT: GDScript = preload("uid://c20c3llfub24q")

var failures: PackedStringArray
var submitted_plan_id: String
var submitted_reply: String
var approved_plan_id: String
var revised_plan_id: String
var revision_feedback: String
var details_plan_id: String
var details_markdown: String


func _init() -> void:
	_run_tests()
	if failures.is_empty():
		quit(0)
		return

	for failure: String in failures:
		push_error(failure)
	quit(1)


func _run_tests() -> void:
	_test_clarification_dialog()
	_test_plan_approval_dialog()
	_test_plan_preview_item()
	_test_plan_events_merge_after_clarification()
	_test_plan_clarify_request_events_merge_into_original_assistant()


func _test_clarification_dialog() -> void:
	var dialog: PanelContainer = CLARIFICATION_DIALOG_SCENE.instantiate() as PanelContainer
	root.add_child(dialog)
	dialog.connect("clarification_submitted", Callable(self, "_on_clarification_submitted"))
	dialog.call("setup", "你想先做哪一部分？", [
		{ "label": "前端", "text": "先做前端 GDS 插件", "description": "编辑器 UI" },
		{ "label": "后端", "text": "先做后端 TS 服务" }
	], "plan-demo")

	_expect_equal((dialog.get_node("%QuestionLabel") as Label).text, "你想先做哪一部分？", "clarification question")
	_expect_equal((dialog.get_node("%RecommendReplyButton") as Button).text, "前端 (Recommended)", "recommended label")
	_expect_equal((dialog.get_node("%Reply3Button") as Button).visible, false, "third reply hidden")
	(dialog.get_node("%RecommendReplyButton") as Button).emit_signal("pressed")
	_expect_equal(submitted_plan_id, "plan-demo", "recommended plan id")
	_expect_equal(submitted_reply, "先做前端 GDS 插件", "recommended reply")
	dialog.queue_free()


func _test_plan_approval_dialog() -> void:
	var dialog: PanelContainer = PLAN_APPROVAL_DIALOG_SCENE.instantiate() as PanelContainer
	root.add_child(dialog)
	dialog.connect("plan_approved", Callable(self, "_on_plan_approved"))
	dialog.connect("plan_revision_requested", Callable(self, "_on_plan_revision_requested"))
	dialog.call("setup", "plan-ready", "公开 Beta 计划")
	(dialog.get_node("%RecommendReplyButton") as Button).emit_signal("pressed")
	_expect_equal(approved_plan_id, "plan-ready", "approved plan id")

	dialog.call("setup", "plan-ready", "公开 Beta 计划")
	var feedback_edit: TextEdit = dialog.get_node("%TextEdit") as TextEdit
	feedback_edit.text = "先补测试范围"
	dialog.call("_on_text_edit_text_changed")
	_expect_equal((dialog.get_node("%SendButton") as Button).disabled, false, "revision send enabled")
	(dialog.get_node("%SendButton") as Button).emit_signal("pressed")
	_expect_equal(revised_plan_id, "plan-ready", "revision plan id")
	_expect_equal(revision_feedback, "先补测试范围", "revision feedback")
	dialog.queue_free()


func _test_plan_preview_item() -> void:
	var item: PanelContainer = PLAN_PREVIEW_ITEM_SCENE.instantiate() as PanelContainer
	root.add_child(item)
	item.connect("details_requested", Callable(self, "_on_details_requested"))
	item.call("setup", {
		"type": "plan",
		"planId": "plan-preview",
		"title": "Plan Title",
		"previewMarkdown": "## Summary\n\n- Step"
	})
	(item.get_node("VBoxContainer/HBoxContainer/DateilsButton") as Button).emit_signal("pressed")
	_expect_equal(details_plan_id, "plan-preview", "details plan id")
	_expect_equal(details_markdown, "## Summary\n\n- Step", "details fallback markdown")
	item.queue_free()


func _test_plan_events_merge_after_clarification() -> void:
	var main_node: VBoxContainer = MAIN_SCRIPT.new() as VBoxContainer
	var timeline_blocks: Array = [
		{
			"id": "user-request-plan",
			"type": "user",
			"requestId": "request-plan",
			"content": "写一个本地井字棋",
			"sentAtUtc": "2026-07-09T00:00:00.000Z"
		},
		{
			"id": "assistant-request-plan",
			"type": "assistant",
			"requestId": "request-plan",
			"content": "需要澄清：请选择目标形态。",
			"startedAtUtc": "2026-07-09T00:00:01.000Z",
			"completedAtUtc": "2026-07-09T00:02:00.000Z",
			"bodyParts": [
				{
					"type": "markdown",
					"text": "需要澄清：请选择目标形态。"
				},
				{
					"type": "status",
					"code": "plan",
					"title": "需要澄清计划",
					"details": "请选择 CLI 还是 Godot 场景。",
					"iconUid": "uid://d1nq6i1hauij0",
					"severity": "info",
					"planId": "plan-merge",
					"recommendedReplies": []
				},
				{
					"type": "plan",
					"planId": "plan-merge",
					"status": "ready",
					"title": "井字棋 CLI 计划",
					"previewMarkdown": "## Summary\n\n实现 CLI 井字棋。"
				}
			]
		}
	]
	main_node.call("_append_timeline_blocks", timeline_blocks)
	var timeline_entries: Array = main_node.get("timeline_entries") as Array
	_expect_equal(timeline_entries.size(), 2, "merged plan timeline entry count")
	var assistant_entry: Dictionary = timeline_entries[1] as Dictionary
	_expect_equal(str(assistant_entry.get("type", "")), "assistant", "merged plan assistant entry type")
	var body_parts: Array = assistant_entry.get("body_parts", []) as Array
	_expect_equal(body_parts.size(), 3, "merged plan body part count")
	_expect_equal(str((body_parts[1] as Dictionary).get("type", "")), "status", "merged clarification status")
	_expect_equal(str((body_parts[1] as Dictionary).get("iconUid", "")), "uid://d1nq6i1hauij0", "clarification icon uid")
	_expect_equal(str((body_parts[2] as Dictionary).get("type", "")), "plan", "merged plan preview")
	_expect_equal(str((body_parts[2] as Dictionary).get("planId", "")), "plan-merge", "merged plan preview id")
	main_node.free()


func _test_plan_clarify_request_events_merge_into_original_assistant() -> void:
	var main_node: VBoxContainer = MAIN_SCRIPT.new() as VBoxContainer
	var timeline_blocks: Array = [
		{
			"id": "user-request-plan",
			"type": "user",
			"requestId": "request-plan",
			"content": "写一个本地井字棋",
			"sentAtUtc": "2026-07-09T00:00:00.000Z"
		},
		{
			"id": "assistant-request-plan",
			"type": "assistant",
			"requestId": "request-plan",
			"content": "需要澄清：请选择目标形态。",
			"startedAtUtc": "2026-07-09T00:00:01.000Z",
			"completedAtUtc": "2026-07-09T00:00:05.000Z",
			"bodyParts": [
				{
					"type": "markdown",
					"text": "需要澄清：请选择目标形态。"
				},
				{
					"type": "thinking",
					"text": "根据澄清补充读取项目结构。"
				},
				{
					"type": "tool",
					"toolCallId": "tool-read",
					"toolName": "mcp_godot_list_project_files",
					"status": "completed",
					"summary": "列出项目文件"
				},
				{
					"type": "plan",
					"planId": "plan-alias",
					"status": "ready",
					"title": "井字棋 CLI 计划",
					"previewMarkdown": "## Summary\n\n实现 CLI 井字棋。"
				}
			]
		}
	]
	main_node.call("_append_timeline_blocks", timeline_blocks)
	var timeline_entries: Array = main_node.get("timeline_entries") as Array
	_expect_equal(timeline_entries.size(), 2, "aliased plan timeline entry count")
	var assistant_entry: Dictionary = timeline_entries[1] as Dictionary
	var body_parts: Array = assistant_entry.get("body_parts", []) as Array
	_expect_equal(body_parts.size(), 4, "aliased plan body part count")
	_expect_equal(str((body_parts[1] as Dictionary).get("type", "")), "thinking", "aliased thinking part")
	_expect_equal(str((body_parts[2] as Dictionary).get("type", "")), "tool", "aliased tool part")
	_expect_equal(str((body_parts[3] as Dictionary).get("type", "")), "plan", "aliased plan part")
	main_node.free()


func _on_clarification_submitted(plan_id: String, reply: String) -> void:
	submitted_plan_id = plan_id
	submitted_reply = reply


func _on_plan_approved(plan_id: String) -> void:
	approved_plan_id = plan_id


func _on_plan_revision_requested(plan_id: String, feedback: String) -> void:
	revised_plan_id = plan_id
	revision_feedback = feedback


func _on_details_requested(plan_id: String, fallback_markdown: String) -> void:
	details_plan_id = plan_id
	details_markdown = fallback_markdown


func _expect_equal(actual_value: Variant, expected_value: Variant, label_text: String) -> void:
	if actual_value == expected_value:
		return

	failures.append("%s: expected %s, got %s" % [label_text, str(expected_value), str(actual_value)])
