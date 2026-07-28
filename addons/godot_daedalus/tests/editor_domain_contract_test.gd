extends SceneTree

const DOMAIN_TOOLS: GDScript = preload("res://addons/godot_daedalus/scripts/controllers/daedalus_editor_domain_tools.gd")

var failures: Array[String] = []


func _initialize() -> void:
	var domain: RefCounted = DOMAIN_TOOLS.new()
	var class_search: Dictionary = domain.execute("search_classes", {
		"query": "TileMapLayer",
		"inherits": "Node",
		"limit": 10
	}, null)
	_expect(bool(class_search.get("ok", false)), "ClassDB search failed")
	_expect(int(class_search.get("total", 0)) >= 1, "TileMapLayer was not found through ClassDB")

	var schema: Dictionary = domain.execute("get_class_schema", {
		"className": "AnimationNodeStateMachine"
	}, null)
	_expect(bool(schema.get("ok", false)), "ClassDB schema inspection failed")
	_expect((schema.get("methods", []) as Array).size() > 0, "ClassDB schema has no methods")

	var performance: Dictionary = domain.execute("get_performance_snapshot", {
		"monitors": ["time/fps", "object/node_count"]
	}, null)
	_expect(bool(performance.get("ok", false)), "performance snapshot failed")
	_expect((performance.get("monitors", {}) as Dictionary).has("time/fps"), "FPS monitor missing")

	var unknown_monitor: Dictionary = domain.execute("get_performance_snapshot", {
		"monitors": ["script/unsafe_custom_monitor"]
	}, null)
	_expect(not bool(unknown_monitor.get("ok", true)), "unknown performance monitor was accepted")

	var tile_map_layer: TileMapLayer = TileMapLayer.new()
	tile_map_layer.tile_set = TileSet.new()
	var map_proposal: Dictionary = domain.execute("propose_map_patch", {
		"nodePath": ".",
		"operations": [
			{ "type": "add_atlas_source", "sourceId": 0 },
			{ "type": "add_terrain_set", "mode": TileSet.TERRAIN_MODE_MATCH_CORNERS },
			{ "type": "add_terrain", "terrainSet": 0, "name": "Ground" }
		]
	}, tile_map_layer)
	_expect(bool(map_proposal.get("ok", false)), "TileMapLayer patch proposal failed: %s" % map_proposal)
	tile_map_layer.free()

	var animation_tree: AnimationTree = AnimationTree.new()
	animation_tree.tree_root = AnimationNodeBlendTree.new()
	var animation_proposal: Dictionary = domain.execute("propose_animation_patch", {
		"nodePath": ".",
		"operations": [{
			"type": "add_graph_node",
			"name": "Idle",
			"nodeClass": "AnimationNodeAnimation",
			"position": { "$type": "Vector2", "value": [120, 80] },
			"properties": { "animation": { "$type": "StringName", "value": "idle" } }
		}]
	}, animation_tree)
	_expect(
		bool(animation_proposal.get("ok", false)),
		"AnimationTree patch proposal failed: %s" % animation_proposal
	)
	animation_tree.free()

	var audio_proposal: Dictionary = domain.execute("propose_audio_patch", {
		"operations": [
			{ "type": "add_bus", "name": "PreviewBus" },
			{
				"type": "add_effect",
				"bus": "PreviewBus",
				"effectClass": "AudioEffectReverb",
				"properties": { "wet": 0.4 }
			}
		]
	}, null)
	_expect(
		bool(audio_proposal.get("ok", false)),
		"Audio bus/effect patch proposal failed: %s" % audio_proposal
	)
	_expect(
		(audio_proposal.get("after", []) as Array).size()
			== (audio_proposal.get("before", []) as Array).size() + 1,
		"Audio patch proposal did not return a predicted bus layout"
	)

	for tool_name: String in [
		"inspect_resource",
		"inspect_animation",
		"inspect_map",
		"inspect_audio",
		"propose_resource_patch",
		"apply_resource_patch",
		"propose_animation_patch",
		"apply_animation_patch",
		"propose_map_patch",
		"apply_map_patch",
		"propose_audio_patch",
		"apply_audio_patch",
		"navigate",
		"preview_control",
		"reimport_assets",
		"bake_resource"
	]:
		var result: Dictionary = domain.execute(tool_name, {}, null)
		_expect(
			not str(result.get("error", "")).begins_with("unsupported_editor_domain_tool"),
			"tool dispatch missing: %s" % tool_name
		)

	if failures.is_empty():
		print("editor_domain_contract_test: PASS")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
