@tool
extends SceneTree

const MAIN_SCRIPT: GDScript = preload("uid://c20c3llfub24q")

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
	var main_node: VBoxContainer = MAIN_SCRIPT.new() as VBoxContainer
	_test_index_cache(main_node)
	_test_height_dirty_rebuild(main_node)
	_test_loaded_block_trim(main_node)
	main_node.free()
	_finish_tests()


func _test_index_cache(main_node: VBoxContainer) -> void:
	_reset_timeline_state(main_node)
	for index: int in range(160):
		main_node.call(
			"_append_timeline_entry",
			"user" if index % 2 == 0 else "assistant",
			"request-%d" % index,
			"message %d" % index,
			"entry-%d" % index
		)

	main_node.call("_rebuild_timeline_index_cache")
	var indices_by_id: Dictionary = main_node.get("timeline_entry_indices_by_id") as Dictionary
	_expect_equal(indices_by_id.size(), 160, "index cache covers all entries")
	_expect_equal(int(main_node.call("_find_timeline_entry_index", "entry-0")), 0, "first entry index")
	_expect_equal(int(main_node.call("_find_timeline_entry_index", "entry-159")), 159, "last entry index")


func _test_height_dirty_rebuild(main_node: VBoxContainer) -> void:
	_reset_timeline_state(main_node)
	for index: int in range(12):
		main_node.call(
			"_append_timeline_entry",
			"assistant",
			"request-height-%d" % index,
			"message %d" % index,
			"height-entry-%d" % index,
			{ "height_estimate": 100.0 + float(index) }
		)

	main_node.call("_rebuild_timeline_height_cache")
	var timeline_entries: Array = main_node.get("timeline_entries") as Array
	var changed_entry: Dictionary = timeline_entries[6] as Dictionary
	changed_entry["height_actual"] = 260.0
	timeline_entries[6] = changed_entry
	main_node.call("_mark_timeline_height_dirty", 6)
	main_node.call("_rebuild_timeline_height_cache")

	var timeline_heights: Array = main_node.get("timeline_heights") as Array
	_expect_equal(int(round(float(timeline_heights[6]))), 260, "dirty height updates changed entry")


func _test_loaded_block_trim(main_node: VBoxContainer) -> void:
	_reset_timeline_state(main_node)
	for index: int in range(260):
		main_node.call(
			"_append_timeline_entry",
			"user",
			"request-trim-%d" % index,
			"message %d" % index,
			"trim-entry-%d" % index
		)

	main_node.call("_trim_loaded_timeline_entries_from_top")
	var timeline_entries: Array = main_node.get("timeline_entries") as Array
	_expect_equal(timeline_entries.size(), 240, "top trim keeps loaded block limit")
	_expect_equal(int(main_node.get("timeline_block_offset")), 20, "top trim advances block offset")
	var first_entry: Dictionary = timeline_entries[0] as Dictionary
	_expect_equal(str(first_entry.get("id", "")), "trim-entry-20", "top trim removes oldest entries")


func _reset_timeline_state(main_node: VBoxContainer) -> void:
	(main_node.get("timeline_entries") as Array).clear()
	(main_node.get("timeline_heights") as Array).clear()
	(main_node.get("timeline_prefix_heights") as Array).clear()
	(main_node.get("timeline_entry_ids") as Dictionary).clear()
	(main_node.get("timeline_entry_indices_by_id") as Dictionary).clear()
	(main_node.get("rendered_entry_nodes") as Dictionary).clear()
	(main_node.get("rendered_entry_indices") as Dictionary).clear()
	main_node.set("timeline_block_offset", 0)
	main_node.set("timeline_has_more_before", false)
	main_node.set("timeline_has_more_after", false)
	main_node.set("timeline_heights_dirty", true)
	main_node.set("timeline_dirty_height_start_index", 0)


func _expect_equal(actual_value: Variant, expected_value: Variant, label_text: String) -> void:
	if actual_value == expected_value:
		return

	failures.append("%s: expected %s, got %s" % [label_text, str(expected_value), str(actual_value)])
