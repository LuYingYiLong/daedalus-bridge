@tool
extends SceneTree

const SETTINGS_SCENE: PackedScene = preload("res://addons/godot_daedalus/scenes/settings_menu/settings_menu.tscn")
const EDIT_SKILL_SCENE: PackedScene = preload("res://addons/godot_daedalus/scenes/settings_menu/edit_skill_dialog.tscn")
const MAIN_SCRIPT: GDScript = preload("res://addons/godot_daedalus/scripts/main.gd")

var failures: PackedStringArray


func _init() -> void:
	call_deferred(&"_run_tests")


func _run_tests() -> void:
	var settings_menu: AcceptDialog = SETTINGS_SCENE.instantiate() as AcceptDialog
	root.add_child(settings_menu)
	await process_frame
	settings_menu.call("setup_skills", [
		{
			"ref": "project:test-skill",
			"slug": "test-skill",
			"name": "Test Skill",
			"description": "Project workflow",
			"source": "project",
			"enabled": true,
			"valid": true,
			"editable": true,
			"removable": false,
			"displayPath": "res://.github/skills/test-skill/SKILL.md"
		},
		{
			"ref": "personal:personal-skill",
			"slug": "personal-skill",
			"name": "Personal Skill",
			"description": "Personal workflow",
			"source": "personal",
			"enabled": false,
			"valid": true,
			"editable": true,
			"removable": true,
			"displayPath": "%USERPROFILE%/.daedalus/skills/personal-skill/SKILL.md"
		}
	], "revision-test", true)
	await process_frame
	var skills_list: VBoxContainer = settings_menu.find_child("SkillsList", true, false) as VBoxContainer
	_expect_equal(skills_list.get_child_count(), 4, "grouped skill list child count")
	var skills_status_label: Label = settings_menu.find_child("SkillsStatusLabel", true, false) as Label
	_expect_equal(skills_status_label.text, "2 skills - 1 enabled", "skill status count")

	var edit_dialog: ConfirmationDialog = EDIT_SKILL_SCENE.instantiate() as ConfirmationDialog
	root.add_child(edit_dialog)
	await process_frame
	var document_text: String = "---\nname: Test\ndescription: Test skill\n---\n\n# Test"
	edit_dialog.call("setup", "project:test-skill", "Test Skill", document_text)
	var text_edit: TextEdit = edit_dialog.find_child("TextEdit", true, false) as TextEdit
	_expect_equal(text_edit.text, document_text, "skill editor content")

	var main_node: VBoxContainer = MAIN_SCRIPT.new() as VBoxContainer
	main_node.set("skill_summaries", [{
		"ref": "project:test-skill",
		"enabled": true,
		"valid": true
	}])
	var refs: Array = main_node.call("_extract_skill_refs", "Use @project:test-skill for this request") as Array
	_expect_equal(refs, ["project:test-skill"], "explicit skill refs")

	settings_menu.queue_free()
	edit_dialog.queue_free()
	main_node.free()
	if failures.is_empty():
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _expect_equal(actual_value: Variant, expected_value: Variant, label_text: String) -> void:
	if actual_value == expected_value:
		return
	failures.append("%s: expected %s, got %s" % [label_text, str(expected_value), str(actual_value)])
