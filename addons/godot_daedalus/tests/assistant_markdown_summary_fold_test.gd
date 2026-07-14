@tool
extends SceneTree

const ASSISTANT_MARKDOWN_ITEM_SCENE: PackedScene = preload("uid://c3s4jlxtm21ci")

var failures: PackedStringArray


func _init() -> void:
	_run_tests.call_deferred()


func _finish() -> void:
	if failures.is_empty():
		quit(0)
		return

	for failure: String in failures:
		push_error(failure)
	quit(1)


func _run_tests() -> void:
	var item: MarginContainer = ASSISTANT_MARKDOWN_ITEM_SCENE.instantiate() as MarginContainer
	root.add_child(item)
	item.call("setup", "", "", "", [
		{
			"type": "thinking",
			"text": "读取项目。",
			"done": true
		},
		{
			"type": "summary_start",
			"runId": "workflow-a",
			"stepId": "summarize",
			"stepRunId": "phase-run-summary",
			"title": "总结交付",
			"foldTitle": "总结前的过程"
		},
		{
			"type": "markdown",
			"text": "总结完成。"
		}
	])
	await process_frame

	var body_container: VBoxContainer = item.get_node("%BodyContainer") as VBoxContainer
	_expect_equal(body_container.get_child_count(), 2, "body contains folded history plus visible summary")
	var fold_container: FoldableContainer = body_container.get_child(0) as FoldableContainer
	_expect_equal(fold_container != null, true, "first body child is fold container")
	if fold_container != null:
		_expect_equal(fold_container.title, "总结前的过程", "fold title")
		var fold_body: VBoxContainer = fold_container.get_child(0) as VBoxContainer
		_expect_equal(fold_body != null, true, "fold body exists")
		if fold_body != null:
			_expect_equal(fold_body.get_child_count(), 0, "pre-summary child is lazy before expand")
			_set_folded(fold_container, false)
			await process_frame
			await process_frame
			_expect_equal(fold_body.get_child_count(), 1, "pre-summary child loads after expand")
	_expect_equal(body_container.get_child(1) is MarkdownLabel, true, "summary markdown remains visible")

	item.call("begin_summary", {
		"stepRunId": "phase-run-summary",
		"foldTitle": "重复总结"
	})
	await process_frame
	_expect_equal(body_container.get_child_count(), 2, "duplicate summary marker is idempotent")

	item.call("clear_message")
	item.call("begin_summary", {
		"stepRunId": "phase-run-empty",
		"foldTitle": "空过程"
	})
	await process_frame
	_expect_equal(body_container.get_child_count(), 0, "empty pre-summary content does not create fold")

	item.queue_free()
	_finish()


func _expect_equal(actual_value: Variant, expected_value: Variant, label_text: String) -> void:
	if actual_value == expected_value:
		return

	failures.append("%s: expected %s, got %s" % [label_text, str(expected_value), str(actual_value)])


func _set_folded(container: FoldableContainer, is_folded: bool) -> void:
	for property: Dictionary in container.get_property_list():
		var property_name: String = str(property.get("name", ""))
		if property_name == "folded" or property_name == "collapsed":
			container.set(property_name, is_folded)
			return
		if property_name == "expanded":
			container.set(property_name, not is_folded)
			return
