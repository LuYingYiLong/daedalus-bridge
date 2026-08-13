@tool
extends RefCounted

const VARIANT_CODEC_PATH: String = "res://addons/daedalus_bridge/scripts/variant_codec.gd"
const MAX_PROPERTIES: int = 500
const MAX_PATCH_OPERATIONS: int = 100
const MAX_MAP_CELLS: int = 10_000
const DEFAULT_AUDIO_BUS_LAYOUT_PATH: String = "res://default_bus_layout.tres"

var editor_interface: EditorInterface
var editor_selection: EditorSelection
var editor_undo_redo: EditorUndoRedoManager
var variant_codec: RefCounted


func setup(interface_value: EditorInterface, selection_value: EditorSelection, undo_redo_value: EditorUndoRedoManager) -> void:
	editor_interface = interface_value
	editor_selection = selection_value
	editor_undo_redo = undo_redo_value
	var variant_codec_script: GDScript = load(VARIANT_CODEC_PATH) as GDScript
	if variant_codec_script == null:
		push_error("Editor Bridge Variant codec could not be loaded.")
		return
	variant_codec = variant_codec_script.new()


func execute(tool_name: String, args: Dictionary, edited_root: Node) -> Dictionary:
	match tool_name:
		"search_classes":
			return _search_classes(args)
		"get_class_schema":
			return _get_class_schema(args)
		"inspect_resource":
			return _inspect_resource(args)
		"inspect_animation":
			return _inspect_animation(args, edited_root)
		"inspect_map":
			return _inspect_map(args, edited_root)
		"inspect_audio":
			return _inspect_audio(args, edited_root)
		"get_performance_snapshot":
			return _get_performance_snapshot(args)
		"propose_resource_patch":
			return _propose_resource_patch(args)
		"apply_resource_patch":
			return _apply_resource_patch(args)
		"propose_animation_patch":
			return _propose_animation_patch(args, edited_root)
		"apply_animation_patch":
			return _apply_animation_patch(args, edited_root)
		"propose_map_patch":
			return _propose_map_patch(args, edited_root)
		"apply_map_patch":
			return _apply_map_patch(args, edited_root)
		"propose_audio_patch":
			return _propose_audio_patch(args)
		"apply_audio_patch":
			return _apply_audio_patch(args)
		"navigate":
			return _navigate(args, edited_root)
		"preview_control":
			return _preview_control(args, edited_root)
		"reimport_assets":
			return _reimport_assets(args)
		"bake_resource":
			return _bake_resource(args, edited_root)
	return { "ok": false, "error": "unsupported_editor_domain_tool:%s" % tool_name }


func _search_classes(args: Dictionary) -> Dictionary:
	var query: String = str(args.get("query", "")).strip_edges().to_lower()
	var inherits: String = str(args.get("inherits", "")).strip_edges()
	var include_abstract: bool = bool(args.get("includeAbstract", true))
	var offset: int = maxi(0, int(args.get("offset", 0)))
	var limit: int = clampi(int(args.get("limit", 50)), 1, 100)
	if not inherits.is_empty() and not ClassDB.class_exists(inherits):
		return { "ok": false, "error": "class_not_found:%s" % inherits }

	var matched: Array = []
	for class_name_value in ClassDB.get_class_list():
		var class_name_text: String = str(class_name_value)
		if not query.is_empty() and not class_name_text.to_lower().contains(query):
			continue
		if not inherits.is_empty() and class_name_text != inherits and not ClassDB.is_parent_class(class_name_text, inherits):
			continue
		if not include_abstract and not ClassDB.can_instantiate(class_name_text):
			continue
		matched.append(class_name_value)
	matched.sort()

	var items: Array = []
	for index in range(offset, mini(offset + limit, matched.size())):
		var class_name_text: String = str(matched[index])
		items.append({
			"name": class_name_text,
			"parent": ClassDB.get_parent_class(class_name_text),
			"canInstantiate": ClassDB.can_instantiate(class_name_text),
			"isVirtual": ClassDB.is_class_enabled(class_name_text) and not ClassDB.can_instantiate(class_name_text)
		})
	return {
		"ok": true,
		"items": items,
		"offset": offset,
		"limit": limit,
		"total": matched.size(),
		"hasMore": offset + items.size() < matched.size()
	}


func _get_class_schema(args: Dictionary) -> Dictionary:
	var class_name_text: String = str(args.get("className", "")).strip_edges()
	if not ClassDB.class_exists(class_name_text):
		return { "ok": false, "error": "class_not_found:%s" % class_name_text }
	var schema: Dictionary = {
		"ok": true,
		"className": class_name_text,
		"parent": ClassDB.get_parent_class(class_name_text),
		"canInstantiate": ClassDB.can_instantiate(class_name_text),
		"enumNames": Array(ClassDB.class_get_enum_list(class_name_text)),
		"integerConstants": Array(ClassDB.class_get_integer_constant_list(class_name_text))
	}
	if bool(args.get("includeProperties", true)):
		schema["properties"] = _compact_class_members(ClassDB.class_get_property_list(class_name_text), 500)
	if bool(args.get("includeMethods", true)):
		schema["methods"] = _compact_class_members(ClassDB.class_get_method_list(class_name_text), 500)
	if bool(args.get("includeSignals", true)):
		schema["signals"] = _compact_class_members(ClassDB.class_get_signal_list(class_name_text), 500)
	return schema


func _compact_class_members(members: Array, limit: int) -> Array:
	var compact: Array = []
	for index in range(mini(members.size(), limit)):
		var member: Dictionary = members[index]
		var item: Dictionary = {}
		for key in ["name", "type", "hint", "hint_string", "usage", "flags", "return"]:
			if member.has(key):
				item[key] = variant_codec.encode(member[key], 0, 2, 50)
		if member.has("args"):
			item["args"] = variant_codec.encode(member["args"], 0, 2, 50)
		compact.append(item)
	return compact


func _inspect_resource(args: Dictionary) -> Dictionary:
	var resolved: Dictionary = _resolve_resource_target(args, true)
	if not bool(resolved.get("ok", false)):
		return resolved
	var resource: Resource = resolved.get("resource") as Resource
	var offset: int = maxi(0, int(args.get("offset", 0)))
	var limit: int = clampi(int(args.get("limit", 100)), 1, MAX_PROPERTIES)
	var max_depth: int = clampi(int(args.get("maxDepth", 2)), 0, 4)
	var summary: Dictionary = _serialize_object(resource, offset, limit, max_depth)
	return {
		"ok": true,
		"resourcePath": str(args.get("resourcePath", "")),
		"propertyPath": args.get("propertyPath", []),
		"resource": summary,
		"fingerprint": variant_codec.fingerprint(summary)
	}


func _serialize_object(target: Object, offset: int = 0, limit: int = 100, max_depth: int = 2) -> Dictionary:
	var properties: Array = []
	var property_list: Array = target.get_property_list()
	var visible_properties: Array = []
	for property_info in property_list:
		var usage: int = int(property_info.get("usage", 0))
		if usage & (PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR) == 0:
			continue
		var property_name: String = str(property_info.get("name", ""))
		if property_name.is_empty() or property_name.begins_with("_"):
			continue
		visible_properties.append(property_info)

	for index in range(offset, mini(offset + limit, visible_properties.size())):
		var property_info: Dictionary = visible_properties[index]
		var property_name: String = str(property_info.get("name", ""))
		var property_value: Variant = target.get(property_name)
		var property_hint: int = int(property_info.get("hint", PROPERTY_HINT_NONE))
		var encoded_value: Variant
		if typeof(property_value) == TYPE_INT and property_hint in [PROPERTY_HINT_ENUM, PROPERTY_HINT_FLAGS]:
			encoded_value = {
				"$type": "Enum" if property_hint == PROPERTY_HINT_ENUM else "Flags",
				"value": property_value,
				"members": str(property_info.get("hint_string", ""))
			}
		else:
			encoded_value = variant_codec.encode(property_value, 0, max_depth, 500)
		properties.append({
			"name": property_name,
			"type": int(property_info.get("type", TYPE_NIL)),
			"typeName": variant_codec.get_type_name(int(property_info.get("type", TYPE_NIL))),
			"hint": property_hint,
			"hintString": str(property_info.get("hint_string", "")),
			"usage": int(property_info.get("usage", 0)),
			"value": encoded_value
		})
	return {
		"class": target.get_class(),
		"properties": properties,
		"offset": offset,
		"limit": limit,
		"total": visible_properties.size(),
		"hasMore": offset + properties.size() < visible_properties.size()
	}


func _resolve_resource_target(args: Dictionary, allow_plugin_read: bool) -> Dictionary:
	var resource_path: String = str(args.get("resourcePath", "")).strip_edges().replace("\\", "/")
	if not variant_codec.is_safe_resource_path(resource_path, allow_plugin_read):
		return { "ok": false, "error": "unsafe_resource_path" }
	var resource: Resource = load(resource_path)
	if resource == null:
		return { "ok": false, "error": "resource_not_found:%s" % resource_path }
	var property_path_value: Variant = args.get("propertyPath", [])
	if typeof(property_path_value) != TYPE_ARRAY:
		return { "ok": false, "error": "invalid_property_path" }
	var target: Variant = resource
	for path_part in property_path_value as Array:
		if typeof(path_part) == TYPE_STRING:
			if not target is Object or not _object_has_property(target as Object, str(path_part)):
				return { "ok": false, "error": "property_path_not_found:%s" % str(path_part) }
			target = (target as Object).get(str(path_part))
		elif typeof(path_part) == TYPE_INT and target is Array:
			var index: int = int(path_part)
			if index < 0 or index >= (target as Array).size():
				return { "ok": false, "error": "property_path_index_out_of_range" }
			target = (target as Array)[index]
		else:
			return { "ok": false, "error": "invalid_property_path_part" }
	if not target is Resource:
		return { "ok": false, "error": "property_path_is_not_resource" }
	return {
		"ok": true,
		"root": resource,
		"resource": target as Resource,
		"resourcePath": resource_path
	}


func _object_has_property(target: Object, property_name: String) -> bool:
	for property_info in target.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			return true
	return false


func _propose_resource_patch(args: Dictionary) -> Dictionary:
	var prepared: Dictionary = _prepare_resource_patch(args)
	if not bool(prepared.get("ok", false)):
		return prepared
	return {
		"ok": true,
		"valid": true,
		"resourcePath": prepared.get("resourcePath"),
		"propertyPath": args.get("propertyPath", []),
		"operationCount": (prepared.get("operations", []) as Array).size(),
		"operations": args.get("operations", []),
		"before": prepared.get("before"),
		"after": prepared.get("after"),
		"fingerprint": prepared.get("fingerprint"),
		"warnings": []
	}


func _apply_resource_patch(args: Dictionary) -> Dictionary:
	if editor_undo_redo == null:
		return { "ok": false, "error": "editor_undo_redo_unavailable" }
	var prepared: Dictionary = _prepare_resource_patch(args)
	if not bool(prepared.get("ok", false)):
		return prepared
	var expected_fingerprint: String = str(args.get("expectedFingerprint", "")).strip_edges()
	if not expected_fingerprint.is_empty() and expected_fingerprint != str(prepared.get("fingerprint", "")):
		return {
			"ok": false,
			"error": "resource_patch_conflict",
			"expectedFingerprint": expected_fingerprint,
			"actualFingerprint": prepared.get("fingerprint")
		}

	var action_title: String = _action_title(args, "Resource patch")
	editor_undo_redo.create_action(action_title)
	for prepared_operation in prepared.get("operations", []) as Array:
		_add_prepared_resource_operation(prepared_operation)
	editor_undo_redo.commit_action()

	var should_save: bool = bool(args.get("saveAfter", true))
	var save_error: Error = OK
	if should_save:
		save_error = ResourceSaver.save(prepared.get("root") as Resource, str(prepared.get("resourcePath", "")))
	return {
		"ok": save_error == OK,
		"operations": (prepared.get("operations", []) as Array).size(),
		"saved": should_save and save_error == OK,
		"fingerprintBefore": prepared.get("fingerprint"),
		"fingerprintAfter": variant_codec.fingerprint(_serialize_object(prepared.get("resource") as Resource, 0, 500, 3)),
		"error": "" if save_error == OK else "resource_save_failed:%d" % int(save_error)
	}


func _prepare_resource_patch(args: Dictionary) -> Dictionary:
	var resolved: Dictionary = _resolve_resource_target(args, false)
	if not bool(resolved.get("ok", false)):
		return resolved
	var root_resource_path: String = str(resolved.get("resourcePath", ""))
	if FileAccess.file_exists("%s.import" % root_resource_path):
		return { "ok": false, "error": "imported_resource_is_read_only" }
	var operations_value: Variant = args.get("operations", [])
	if typeof(operations_value) != TYPE_ARRAY:
		return { "ok": false, "error": "invalid_operations" }
	var operations: Array = operations_value as Array
	if operations.is_empty() or operations.size() > MAX_PATCH_OPERATIONS:
		return { "ok": false, "error": "invalid_operation_count" }
	var target: Resource = resolved.get("resource") as Resource
	var prepared_operations: Array = []
	for operation_value in operations:
		if typeof(operation_value) != TYPE_DICTIONARY:
			return { "ok": false, "error": "invalid_operation" }
		var prepared_operation: Dictionary = _prepare_resource_operation(target, operation_value as Dictionary)
		if not bool(prepared_operation.get("ok", false)):
			return prepared_operation
		prepared_operations.append(prepared_operation)
	var before: Dictionary = _serialize_object(target, 0, 500, 3)
	var preview_target: Resource = target.duplicate(true) as Resource
	if preview_target == null:
		return { "ok": false, "error": "resource_preview_duplicate_failed" }
	for operation_value in operations:
		var preview_operation: Dictionary = _prepare_resource_operation(
			preview_target,
			operation_value as Dictionary
		)
		if not bool(preview_operation.get("ok", false)):
			return preview_operation
		_execute_prepared_resource_operation(preview_operation)
	return {
		"ok": true,
		"root": resolved.get("root"),
		"resource": target,
		"resourcePath": resolved.get("resourcePath"),
		"operations": prepared_operations,
		"before": before,
		"after": _serialize_object(preview_target, 0, 500, 3),
		"fingerprint": variant_codec.fingerprint(before)
	}


func _prepare_resource_operation(target: Resource, operation: Dictionary) -> Dictionary:
	var operation_type: String = str(operation.get("type", ""))
	if operation_type in ["set_property", "reset_property", "create_subresource", "duplicate_subresource", "assign_resource", "clear_resource"]:
		var property_name: String = str(operation.get("property", "")).strip_edges()
		if property_name.is_empty() or not _object_has_property(target, property_name):
			return { "ok": false, "error": "property_not_found:%s" % property_name }
		var old_value: Variant = target.get(property_name)
		var new_value: Variant = null
		if operation_type == "set_property":
			var decoded: Dictionary = variant_codec.decode(operation.get("value"), old_value)
			if not bool(decoded.get("ok", false)):
				return decoded
			new_value = decoded.get("value")
		elif operation_type == "reset_property":
			if not ClassDB.can_instantiate(target.get_class()):
				return { "ok": false, "error": "resource_class_has_no_default_instance" }
			var default_instance: Variant = ClassDB.instantiate(target.get_class())
			if not default_instance is Object or not _object_has_property(default_instance as Object, property_name):
				return { "ok": false, "error": "property_default_unavailable" }
			new_value = (default_instance as Object).get(property_name)
		elif operation_type == "create_subresource":
			var resource_class: String = str(operation.get("resourceClass", "")).strip_edges()
			if not ClassDB.class_exists(resource_class) or not ClassDB.is_parent_class(resource_class, "Resource"):
				return { "ok": false, "error": "invalid_resource_class:%s" % resource_class }
			new_value = ClassDB.instantiate(resource_class)
			if not new_value is Resource:
				return { "ok": false, "error": "resource_instantiate_failed" }
			_apply_initial_properties(new_value as Resource, operation.get("properties", {}))
		elif operation_type == "duplicate_subresource":
			if not old_value is Resource:
				return { "ok": false, "error": "property_is_not_resource" }
			new_value = (old_value as Resource).duplicate(true)
		elif operation_type == "assign_resource":
			var assigned_path: String = str(operation.get("resourcePath", "")).strip_edges()
			if not variant_codec.is_safe_resource_path(assigned_path, false):
				return { "ok": false, "error": "unsafe_resource_path" }
			new_value = load(assigned_path)
			if not new_value is Resource:
				return { "ok": false, "error": "resource_not_found:%s" % assigned_path }
		return {
			"ok": true,
			"kind": "property",
			"target": target,
			"property": property_name,
			"oldValue": old_value,
			"newValue": new_value
		}
	if operation_type == "set_shader_parameter":
		if not target is ShaderMaterial:
			return { "ok": false, "error": "resource_is_not_shader_material" }
		var parameter_name: StringName = StringName(str(operation.get("parameter", "")))
		var old_parameter: Variant = (target as ShaderMaterial).get_shader_parameter(parameter_name)
		var decoded_parameter: Dictionary = variant_codec.decode(operation.get("value"), old_parameter)
		if not bool(decoded_parameter.get("ok", false)):
			return decoded_parameter
		return {
			"ok": true,
			"kind": "method",
			"target": target,
			"method": "set_shader_parameter",
			"doArgs": [parameter_name, decoded_parameter.get("value")],
			"undoArgs": [parameter_name, old_parameter]
		}
	if operation_type == "set_mesh_surface_material":
		if not target is Mesh:
			return { "ok": false, "error": "resource_is_not_mesh" }
		var surface: int = int(operation.get("surface", -1))
		if surface < 0 or surface >= (target as Mesh).get_surface_count():
			return { "ok": false, "error": "mesh_surface_out_of_range" }
		var material_value: Variant = operation.get("material")
		var material: Material = null
		if material_value != null:
			var decoded_material: Dictionary = variant_codec.decode(material_value)
			if not bool(decoded_material.get("ok", false)) or not decoded_material.get("value") is Material:
				return { "ok": false, "error": "invalid_material_resource" }
			material = decoded_material.get("value") as Material
		return {
			"ok": true,
			"kind": "method",
			"target": target,
			"method": "surface_set_material",
			"doArgs": [surface, material],
			"undoArgs": [surface, (target as Mesh).surface_get_material(surface)]
		}
	if operation_type == "set_multimesh_instance":
		if not target is MultiMesh:
			return { "ok": false, "error": "resource_is_not_multimesh" }
		var instance_index: int = int(operation.get("index", -1))
		if instance_index < 0 or instance_index >= (target as MultiMesh).instance_count:
			return { "ok": false, "error": "multimesh_index_out_of_range" }
		var property_kind: String = str(operation.get("property", "transform"))
		return _prepare_multimesh_operation(target as MultiMesh, instance_index, property_kind, operation.get("value"))
	return { "ok": false, "error": "unsupported_resource_operation:%s" % operation_type }


func _prepare_multimesh_operation(multimesh: MultiMesh, index: int, property_kind: String, payload: Variant) -> Dictionary:
	var method_name: String
	var old_value: Variant
	if property_kind == "transform":
		method_name = "set_instance_transform"
		old_value = multimesh.get_instance_transform(index)
	elif property_kind == "transform_2d":
		method_name = "set_instance_transform_2d"
		old_value = multimesh.get_instance_transform_2d(index)
	elif property_kind == "color":
		method_name = "set_instance_color"
		old_value = multimesh.get_instance_color(index)
	elif property_kind == "custom_data":
		method_name = "set_instance_custom_data"
		old_value = multimesh.get_instance_custom_data(index)
	else:
		return { "ok": false, "error": "unsupported_multimesh_property:%s" % property_kind }
	var decoded: Dictionary = variant_codec.decode(payload, old_value)
	if not bool(decoded.get("ok", false)):
		return decoded
	return {
		"ok": true,
		"kind": "method",
		"target": multimesh,
		"method": method_name,
		"doArgs": [index, decoded.get("value")],
		"undoArgs": [index, old_value]
	}


func _add_prepared_resource_operation(operation: Dictionary) -> void:
	var target: Object = operation.get("target") as Object
	if str(operation.get("kind", "")) == "property":
		editor_undo_redo.add_do_property(target, str(operation.get("property", "")), operation.get("newValue"))
		editor_undo_redo.add_undo_property(target, str(operation.get("property", "")), operation.get("oldValue"))
		return
	var method_name: String = str(operation.get("method", ""))
	editor_undo_redo.add_do_method(self, "_call_methodv", target, method_name, operation.get("doArgs", []))
	editor_undo_redo.add_undo_method(self, "_call_methodv", target, method_name, operation.get("undoArgs", []))


func _execute_prepared_resource_operation(operation: Dictionary) -> void:
	var target: Object = operation.get("target") as Object
	if str(operation.get("kind", "")) == "property":
		target.set(str(operation.get("property", "")), operation.get("newValue"))
		return
	target.callv(str(operation.get("method", "")), operation.get("doArgs", []) as Array)


func _apply_initial_properties(resource: Resource, properties_value: Variant) -> void:
	if typeof(properties_value) != TYPE_DICTIONARY:
		return
	for property_key in (properties_value as Dictionary).keys():
		var property_name: String = str(property_key)
		if not _object_has_property(resource, property_name):
			continue
		var decoded: Dictionary = variant_codec.decode((properties_value as Dictionary)[property_key], resource.get(property_name))
		if bool(decoded.get("ok", false)):
			resource.set(property_name, decoded.get("value"))


func _action_title(args: Dictionary, fallback: String) -> String:
	var title: String = str(args.get("title", fallback)).strip_edges()
	if title.is_empty():
		title = fallback
	if not title.begins_with("Daedalus:"):
		title = "Daedalus: %s" % title
	return title


func _inspect_animation(args: Dictionary, edited_root: Node) -> Dictionary:
	var target: Variant = _resolve_animation_target(args, edited_root)
	if target == null:
		return { "ok": false, "error": "animation_target_not_found" }
	if _is_animation_library_host(target):
		var libraries: Array = []
		for library_name in target.call("get_animation_library_list"):
			var library: AnimationLibrary = target.call("get_animation_library", library_name) as AnimationLibrary
			var animations: Array = []
			for animation_name in library.get_animation_list():
				var animation: Animation = library.get_animation(animation_name)
				animations.append(_serialize_animation(animation_name, animation))
			libraries.append({
				"name": str(library_name),
				"resourcePath": library.resource_path,
				"animations": animations
			})
		return {
			"ok": true,
			"kind": "AnimationMixer",
			"class": target.get_class(),
			"libraries": libraries,
			"active": (target as AnimationPlayer).current_animation if target is AnimationPlayer else ""
		}
	if target is AnimationTree:
		var tree_root: AnimationNode = (target as AnimationTree).tree_root
		if tree_root == null:
			return { "ok": true, "kind": "AnimationTree", "treeRoot": null }
		return {
			"ok": true,
			"kind": "AnimationTree",
			"treeRoot": _serialize_animation_node(tree_root)
		}
	if target is Animation:
		return { "ok": true, "kind": "Animation", "animation": _serialize_animation("", target as Animation) }
	if target is AnimationNode:
		return {
			"ok": true,
			"kind": "AnimationNode",
			"resource": _serialize_object(target as AnimationNode, 0, 500, 3)
		}
	return { "ok": false, "error": "unsupported_animation_target:%s" % (target as Object).get_class() }


func _serialize_animation(animation_name: StringName, animation: Animation) -> Dictionary:
	var tracks: Array = []
	for track_index in range(animation.get_track_count()):
		var keys: Array = []
		var key_count: int = mini(animation.track_get_key_count(track_index), 500)
		for key_index in range(key_count):
			keys.append({
				"time": animation.track_get_key_time(track_index, key_index),
				"transition": animation.track_get_key_transition(track_index, key_index),
				"value": variant_codec.encode(animation.track_get_key_value(track_index, key_index), 0, 3, 100)
			})
		tracks.append({
			"index": track_index,
			"type": animation.track_get_type(track_index),
			"path": str(animation.track_get_path(track_index)),
			"enabled": animation.track_is_enabled(track_index),
			"interpolationType": animation.track_get_interpolation_type(track_index),
			"loopWrap": animation.track_get_interpolation_loop_wrap(track_index),
			"keys": keys,
			"keyCount": animation.track_get_key_count(track_index),
			"keysTruncated": animation.track_get_key_count(track_index) > key_count
		})
	return {
		"name": str(animation_name),
		"length": animation.length,
		"loopMode": animation.loop_mode,
		"step": animation.step,
		"trackCount": animation.get_track_count(),
		"tracks": tracks
	}


func _resolve_animation_target(args: Dictionary, edited_root: Node) -> Variant:
	var resource_path: String = str(args.get("resourcePath", "")).strip_edges()
	if not resource_path.is_empty():
		if not variant_codec.is_safe_resource_path(resource_path, true):
			return null
		return load(resource_path)
	var node_path: String = str(args.get("nodePath", "")).strip_edges()
	if edited_root == null or node_path.is_empty():
		return null
	if node_path == ".":
		return edited_root
	if not edited_root.has_node(NodePath(node_path)):
		return null
	return edited_root.get_node(NodePath(node_path))


func _propose_animation_patch(args: Dictionary, edited_root: Node) -> Dictionary:
	var prepared: Dictionary = _prepare_animation_patch(args, edited_root)
	if not bool(prepared.get("ok", false)):
		return prepared
	return {
		"ok": true,
		"valid": true,
		"operationCount": (args.get("operations", []) as Array).size(),
		"operations": args.get("operations", []),
		"before": prepared.get("before"),
		"after": prepared.get("after"),
		"fingerprint": prepared.get("fingerprint"),
		"warnings": []
	}


func _apply_animation_patch(args: Dictionary, edited_root: Node) -> Dictionary:
	if editor_undo_redo == null:
		return { "ok": false, "error": "editor_undo_redo_unavailable" }
	var prepared: Dictionary = _prepare_animation_patch(args, edited_root)
	if not bool(prepared.get("ok", false)):
		return prepared
	var expected_fingerprint: String = str(args.get("expectedFingerprint", "")).strip_edges()
	if not expected_fingerprint.is_empty() and expected_fingerprint != str(prepared.get("fingerprint", "")):
		return { "ok": false, "error": "animation_patch_conflict", "actualFingerprint": prepared.get("fingerprint") }
	editor_undo_redo.create_action(_action_title(args, "Animation patch"))
	if str(prepared.get("kind", "")) == "mixer":
		var mixer: Object = prepared.get("mixer") as Object
		editor_undo_redo.add_do_method(self, "_replace_animation_libraries", mixer, prepared.get("afterLibraries"))
		editor_undo_redo.add_undo_method(self, "_replace_animation_libraries", mixer, prepared.get("beforeLibraries"))
	else:
		var animation_tree: AnimationTree = prepared.get("animationTree") as AnimationTree
		editor_undo_redo.add_do_property(animation_tree, "tree_root", prepared.get("afterRoot"))
		editor_undo_redo.add_undo_property(animation_tree, "tree_root", prepared.get("beforeRoot"))
	editor_undo_redo.commit_action()
	var should_save: bool = bool(args.get("saveAfter", true))
	var save_error: Error = OK
	if should_save and editor_interface != null:
		save_error = editor_interface.save_scene()
	return {
		"ok": save_error == OK,
		"operations": (args.get("operations", []) as Array).size(),
		"saved": should_save and save_error == OK,
		"error": "" if save_error == OK else "editor_save_failed:%d" % int(save_error)
	}


func _prepare_animation_patch(args: Dictionary, edited_root: Node) -> Dictionary:
	var target: Variant = _resolve_animation_target(args, edited_root)
	var operations_value: Variant = args.get("operations", [])
	if typeof(operations_value) != TYPE_ARRAY:
		return { "ok": false, "error": "invalid_operations" }
	var operations: Array = operations_value as Array
	if operations.is_empty() or operations.size() > MAX_PATCH_OPERATIONS:
		return { "ok": false, "error": "invalid_operation_count" }

	if target is AnimationTree:
		var animation_tree: AnimationTree = target as AnimationTree
		if animation_tree.tree_root == null:
			return { "ok": false, "error": "animation_tree_has_no_root" }
		var before_root: AnimationNode = animation_tree.tree_root.duplicate(true) as AnimationNode
		var after_root: AnimationNode = before_root.duplicate(true) as AnimationNode
		for operation_value in operations:
			if typeof(operation_value) != TYPE_DICTIONARY:
				return { "ok": false, "error": "invalid_animation_operation" }
			var node_error: String = _apply_animation_node_operation(after_root, operation_value as Dictionary)
			if not node_error.is_empty():
				return { "ok": false, "error": node_error }
		var before_node_summary: Dictionary = _serialize_animation_node(before_root)
		return {
			"ok": true,
			"kind": "tree",
			"animationTree": animation_tree,
			"beforeRoot": before_root,
			"afterRoot": after_root,
			"before": before_node_summary,
			"after": _serialize_animation_node(after_root),
			"fingerprint": variant_codec.fingerprint(before_node_summary)
		}
	if not _is_animation_library_host(target):
		return { "ok": false, "error": "animation_target_must_be_animation_mixer_or_tree" }
	var before_libraries: Dictionary = _duplicate_animation_libraries(target as Object)
	var after_libraries: Dictionary = _duplicate_library_dictionary(before_libraries)
	for operation_value in operations:
		if typeof(operation_value) != TYPE_DICTIONARY:
			return { "ok": false, "error": "invalid_animation_operation" }
		var error: String = _apply_animation_operation(after_libraries, operation_value as Dictionary)
		if not error.is_empty():
			return { "ok": false, "error": error }
	var before_summary: Dictionary = _summarize_animation_libraries(before_libraries)
	var after_summary: Dictionary = _summarize_animation_libraries(after_libraries)
	return {
		"ok": true,
		"kind": "mixer",
		"mixer": target,
		"beforeLibraries": before_libraries,
		"afterLibraries": after_libraries,
		"before": before_summary,
		"after": after_summary,
		"fingerprint": variant_codec.fingerprint(before_summary)
	}


func _duplicate_animation_libraries(mixer: Object) -> Dictionary:
	var libraries: Dictionary = {}
	for library_name in mixer.call("get_animation_library_list"):
		var library: AnimationLibrary = mixer.call("get_animation_library", library_name) as AnimationLibrary
		libraries[str(library_name)] = library.duplicate(true)
	return libraries


func _is_animation_library_host(target: Variant) -> bool:
	if not target is Object:
		return false
	var object: Object = target as Object
	return (
		object.has_method("get_animation_library_list")
		and object.has_method("get_animation_library")
		and object.has_method("add_animation_library")
	)


func _duplicate_library_dictionary(source: Dictionary) -> Dictionary:
	var duplicate: Dictionary = {}
	for key in source.keys():
		duplicate[str(key)] = (source[key] as AnimationLibrary).duplicate(true)
	return duplicate


func _summarize_animation_libraries(libraries: Dictionary) -> Dictionary:
	var summary: Dictionary = {}
	for key in libraries.keys():
		var library: AnimationLibrary = libraries[key] as AnimationLibrary
		var animations: Dictionary = {}
		for animation_name in library.get_animation_list():
			var animation: Animation = library.get_animation(animation_name)
			animations[str(animation_name)] = {
				"length": animation.length,
				"loopMode": animation.loop_mode,
				"trackCount": animation.get_track_count()
			}
		summary[str(key)] = animations
	return summary


func _apply_animation_operation(libraries: Dictionary, operation: Dictionary) -> String:
	var operation_type: String = str(operation.get("type", ""))
	var library_name: String = str(operation.get("library", ""))
	if operation_type == "add_library":
		if libraries.has(library_name):
			return "animation_library_exists:%s" % library_name
		libraries[library_name] = AnimationLibrary.new()
		return ""
	if operation_type == "remove_library":
		if not libraries.has(library_name):
			return "animation_library_not_found:%s" % library_name
		libraries.erase(library_name)
		return ""
	if operation_type == "rename_library":
		var new_library_name: String = str(operation.get("name", ""))
		if not libraries.has(library_name) or new_library_name.is_empty() or libraries.has(new_library_name):
			return "invalid_animation_library_rename"
		libraries[new_library_name] = libraries[library_name]
		libraries.erase(library_name)
		return ""
	if not libraries.has(library_name):
		return "animation_library_not_found:%s" % library_name
	var library: AnimationLibrary = libraries[library_name] as AnimationLibrary
	var animation_name: StringName = StringName(str(operation.get("animation", "")))
	if operation_type == "add_animation":
		if library.has_animation(animation_name):
			return "animation_exists:%s" % str(animation_name)
		var animation: Animation = Animation.new()
		animation.length = maxf(0.001, float(operation.get("length", 1.0)))
		animation.loop_mode = int(operation.get("loopMode", Animation.LOOP_NONE))
		library.add_animation(animation_name, animation)
		return ""
	if operation_type == "remove_animation":
		if not library.has_animation(animation_name):
			return "animation_not_found:%s" % str(animation_name)
		library.remove_animation(animation_name)
		return ""
	if operation_type == "rename_animation":
		var new_animation_name: StringName = StringName(str(operation.get("name", "")))
		if not library.has_animation(animation_name) or str(new_animation_name).is_empty() or library.has_animation(new_animation_name):
			return "invalid_animation_rename"
		library.rename_animation(animation_name, new_animation_name)
		return ""
	if not library.has_animation(animation_name):
		return "animation_not_found:%s" % str(animation_name)
	var animation: Animation = library.get_animation(animation_name)
	return _apply_animation_track_operation(animation, operation)


func _apply_animation_track_operation(animation: Animation, operation: Dictionary) -> String:
	var operation_type: String = str(operation.get("type", ""))
	var track_index: int = int(operation.get("track", -1))
	if operation_type == "add_track":
		var track_type: int = _animation_track_type(str(operation.get("trackType", "value")))
		if track_type < 0:
			return "invalid_animation_track_type"
		track_index = animation.add_track(track_type)
		animation.track_set_path(track_index, NodePath(str(operation.get("path", ""))))
		return ""
	if track_index < 0 or track_index >= animation.get_track_count():
		return "animation_track_out_of_range"
	if operation_type == "remove_track":
		animation.remove_track(track_index)
		return ""
	if operation_type == "set_track_path":
		animation.track_set_path(track_index, NodePath(str(operation.get("path", ""))))
		return ""
	if operation_type == "set_track_enabled":
		animation.track_set_enabled(track_index, bool(operation.get("enabled", true)))
		return ""
	if operation_type == "set_track_interpolation":
		animation.track_set_interpolation_type(
			track_index,
			int(operation.get("interpolationType", Animation.INTERPOLATION_LINEAR))
		)
		animation.track_set_interpolation_loop_wrap(track_index, bool(operation.get("loopWrap", true)))
		return ""
	if operation_type == "insert_key":
		var decoded: Dictionary = variant_codec.decode(operation.get("value"))
		if not bool(decoded.get("ok", false)):
			return str(decoded.get("error", "invalid_key_value"))
		animation.track_insert_key(
			track_index,
			maxf(0.0, float(operation.get("time", 0.0))),
			decoded.get("value"),
			float(operation.get("transition", 1.0))
		)
		return ""
	if operation_type == "remove_key":
		var key_index: int = int(operation.get("key", -1))
		if key_index < 0 and operation.has("time"):
			key_index = animation.track_find_key(track_index, float(operation.get("time", 0.0)), Animation.FIND_MODE_APPROX)
		if key_index < 0 or key_index >= animation.track_get_key_count(track_index):
			return "animation_key_not_found"
		animation.track_remove_key(track_index, key_index)
		return ""
	if operation_type == "set_animation_properties":
		animation.length = maxf(0.001, float(operation.get("length", animation.length)))
		animation.loop_mode = int(operation.get("loopMode", animation.loop_mode))
		animation.step = maxf(0.0, float(operation.get("step", animation.step)))
		return ""
	return "unsupported_animation_operation:%s" % operation_type


func _animation_track_type(track_type: String) -> int:
	var types: Dictionary = {
		"value": Animation.TYPE_VALUE,
		"position_3d": Animation.TYPE_POSITION_3D,
		"rotation_3d": Animation.TYPE_ROTATION_3D,
		"scale_3d": Animation.TYPE_SCALE_3D,
		"blend_shape": Animation.TYPE_BLEND_SHAPE,
		"method": Animation.TYPE_METHOD,
		"bezier": Animation.TYPE_BEZIER,
		"audio": Animation.TYPE_AUDIO,
		"animation": Animation.TYPE_ANIMATION
	}
	return int(types.get(track_type, -1))


func _serialize_animation_node(node: AnimationNode, depth: int = 0) -> Dictionary:
	var summary: Dictionary = {
		"class": node.get_class(),
		"resourcePath": node.resource_path,
		"properties": _serialize_object(node, 0, 200, 2).get("properties", [])
	}
	if depth >= 4:
		summary["truncated"] = true
		return summary
	if node is AnimationNodeBlendTree:
		var children: Array = []
		for child_name in (node as AnimationNodeBlendTree).get_node_list():
			children.append({
				"name": str(child_name),
				"position": variant_codec.encode((node as AnimationNodeBlendTree).get_node_position(child_name)),
				"node": _serialize_animation_node((node as AnimationNodeBlendTree).get_node(child_name), depth + 1)
			})
		summary["nodes"] = children
	elif node is AnimationNodeStateMachine:
		var states: Array = []
		for state_name in (node as AnimationNodeStateMachine).get_node_list():
			states.append({
				"name": str(state_name),
				"position": variant_codec.encode((node as AnimationNodeStateMachine).get_node_position(state_name)),
				"node": _serialize_animation_node((node as AnimationNodeStateMachine).get_node(state_name), depth + 1)
			})
		var transitions: Array = []
		for transition_index in range((node as AnimationNodeStateMachine).get_transition_count()):
			transitions.append({
				"from": str((node as AnimationNodeStateMachine).get_transition_from(transition_index)),
				"to": str((node as AnimationNodeStateMachine).get_transition_to(transition_index)),
				"transition": _serialize_object(
					(node as AnimationNodeStateMachine).get_transition(transition_index),
					0,
					100,
					2
				)
			})
		summary["states"] = states
		summary["transitions"] = transitions
	elif node is AnimationNodeBlendSpace1D:
		var points_1d: Array = []
		for point_index in range((node as AnimationNodeBlendSpace1D).get_blend_point_count()):
			points_1d.append({
				"index": point_index,
				"name": str((node as AnimationNodeBlendSpace1D).get_blend_point_name(point_index)),
				"position": (node as AnimationNodeBlendSpace1D).get_blend_point_position(point_index),
				"node": _serialize_animation_node(
					(node as AnimationNodeBlendSpace1D).get_blend_point_node(point_index),
					depth + 1
				)
			})
		summary["points"] = points_1d
	elif node is AnimationNodeBlendSpace2D:
		var points_2d: Array = []
		for point_index in range((node as AnimationNodeBlendSpace2D).get_blend_point_count()):
			points_2d.append({
				"index": point_index,
				"name": str((node as AnimationNodeBlendSpace2D).get_blend_point_name(point_index)),
				"position": variant_codec.encode((node as AnimationNodeBlendSpace2D).get_blend_point_position(point_index)),
				"node": _serialize_animation_node(
					(node as AnimationNodeBlendSpace2D).get_blend_point_node(point_index),
					depth + 1
				)
			})
		var triangles: Array = []
		for triangle_index in range((node as AnimationNodeBlendSpace2D).get_triangle_count()):
			triangles.append([
				(node as AnimationNodeBlendSpace2D).get_triangle_point(triangle_index, 0),
				(node as AnimationNodeBlendSpace2D).get_triangle_point(triangle_index, 1),
				(node as AnimationNodeBlendSpace2D).get_triangle_point(triangle_index, 2)
			])
		summary["points"] = points_2d
		summary["triangles"] = triangles
	return summary


func _apply_animation_node_operation(root: AnimationNode, operation: Dictionary) -> String:
	var operation_type: String = str(operation.get("type", ""))
	if operation_type == "set_node_property":
		var property_name: String = str(operation.get("property", ""))
		if property_name.is_empty() or not _object_has_property(root, property_name):
			return "animation_node_property_not_found:%s" % property_name
		var decoded_property: Dictionary = variant_codec.decode(operation.get("value"), root.get(property_name))
		if not bool(decoded_property.get("ok", false)):
			return str(decoded_property.get("error", "invalid_animation_node_property"))
		root.set(property_name, decoded_property.get("value"))
		return ""
	if operation_type in ["add_graph_node", "remove_graph_node", "rename_graph_node", "move_graph_node"]:
		return _apply_animation_graph_node_operation(root, operation)
	if operation_type in ["connect_graph_node", "disconnect_graph_node"]:
		if not root is AnimationNodeBlendTree:
			return "animation_root_is_not_blend_tree"
		var input_node: StringName = StringName(str(operation.get("inputNode", "")))
		var input_index: int = int(operation.get("inputIndex", -1))
		if input_index < 0 or not (root as AnimationNodeBlendTree).has_node(input_node):
			return "invalid_blend_tree_input"
		if operation_type == "connect_graph_node":
			var output_node: StringName = StringName(str(operation.get("outputNode", "")))
			if not (root as AnimationNodeBlendTree).has_node(output_node):
				return "blend_tree_output_not_found"
			(root as AnimationNodeBlendTree).connect_node(input_node, input_index, output_node)
		else:
			(root as AnimationNodeBlendTree).disconnect_node(input_node, input_index)
		return ""
	if operation_type in ["add_transition", "remove_transition"]:
		if not root is AnimationNodeStateMachine:
			return "animation_root_is_not_state_machine"
		var from_state: StringName = StringName(str(operation.get("from", "")))
		var to_state: StringName = StringName(str(operation.get("to", "")))
		if (
			not (root as AnimationNodeStateMachine).has_node(from_state)
			or not (root as AnimationNodeStateMachine).has_node(to_state)
		):
			return "animation_state_not_found"
		if operation_type == "remove_transition":
			if not (root as AnimationNodeStateMachine).has_transition(from_state, to_state):
				return "animation_transition_not_found"
			(root as AnimationNodeStateMachine).remove_transition(from_state, to_state)
			return ""
		if (root as AnimationNodeStateMachine).has_transition(from_state, to_state):
			return "animation_transition_exists"
		var transition: AnimationNodeStateMachineTransition = AnimationNodeStateMachineTransition.new()
		var property_error: String = _set_object_properties(transition, operation.get("properties", {}))
		if not property_error.is_empty():
			return property_error
		(root as AnimationNodeStateMachine).add_transition(from_state, to_state, transition)
		return ""
	if operation_type in [
		"add_blend_point", "remove_blend_point", "move_blend_point",
		"rename_blend_point", "reorder_blend_point"
	]:
		return _apply_blend_space_point_operation(root, operation)
	if operation_type in ["add_triangle", "remove_triangle"]:
		if not root is AnimationNodeBlendSpace2D:
			return "animation_root_is_not_blend_space_2d"
		if operation_type == "add_triangle":
			(root as AnimationNodeBlendSpace2D).add_triangle(
				int(operation.get("x", -1)),
				int(operation.get("y", -1)),
				int(operation.get("z", -1)),
				int(operation.get("index", -1))
			)
		else:
			var triangle_index: int = int(operation.get("index", -1))
			if triangle_index < 0 or triangle_index >= (root as AnimationNodeBlendSpace2D).get_triangle_count():
				return "blend_triangle_out_of_range"
			(root as AnimationNodeBlendSpace2D).remove_triangle(triangle_index)
		return ""
	return "unsupported_animation_node_operation:%s" % operation_type


func _apply_animation_graph_node_operation(root: AnimationNode, operation: Dictionary) -> String:
	if not root is AnimationNodeBlendTree and not root is AnimationNodeStateMachine:
		return "animation_root_is_not_graph"
	var node_name: StringName = StringName(str(operation.get("name", "")))
	var has_node: bool = (
		(root as AnimationNodeBlendTree).has_node(node_name)
		if root is AnimationNodeBlendTree
		else (root as AnimationNodeStateMachine).has_node(node_name)
	)
	var operation_type: String = str(operation.get("type", ""))
	if operation_type == "add_graph_node":
		if str(node_name).is_empty() or has_node:
			return "invalid_animation_graph_node_name"
		var child_result: Dictionary = _create_animation_node(operation, false)
		if not bool(child_result.get("ok", false)):
			return str(child_result.get("error", "animation_node_create_failed"))
		var position_result: Dictionary = variant_codec.decode(
			operation.get("position", { "$type": "Vector2", "value": [0, 0] }),
			Vector2.ZERO
		)
		if not bool(position_result.get("ok", false)) or not position_result.get("value") is Vector2:
			return "invalid_animation_graph_position"
		if root is AnimationNodeBlendTree:
			(root as AnimationNodeBlendTree).add_node(node_name, child_result.get("value"), position_result.get("value"))
		else:
			(root as AnimationNodeStateMachine).add_node(node_name, child_result.get("value"), position_result.get("value"))
		return ""
	if not has_node:
		return "animation_graph_node_not_found:%s" % str(node_name)
	if operation_type == "remove_graph_node":
		if root is AnimationNodeBlendTree:
			(root as AnimationNodeBlendTree).remove_node(node_name)
		else:
			(root as AnimationNodeStateMachine).remove_node(node_name)
		return ""
	if operation_type == "rename_graph_node":
		var new_name: StringName = StringName(str(operation.get("newName", "")))
		if str(new_name).is_empty():
			return "invalid_animation_graph_node_name"
		if root is AnimationNodeBlendTree:
			(root as AnimationNodeBlendTree).rename_node(node_name, new_name)
		else:
			(root as AnimationNodeStateMachine).rename_node(node_name, new_name)
		return ""
	var position_result: Dictionary = variant_codec.decode(operation.get("position"), Vector2.ZERO)
	if not bool(position_result.get("ok", false)) or not position_result.get("value") is Vector2:
		return "invalid_animation_graph_position"
	if root is AnimationNodeBlendTree:
		(root as AnimationNodeBlendTree).set_node_position(node_name, position_result.get("value"))
	else:
		(root as AnimationNodeStateMachine).set_node_position(node_name, position_result.get("value"))
	return ""


func _apply_blend_space_point_operation(root: AnimationNode, operation: Dictionary) -> String:
	if not root is AnimationNodeBlendSpace1D and not root is AnimationNodeBlendSpace2D:
		return "animation_root_is_not_blend_space"
	var operation_type: String = str(operation.get("type", ""))
	var point_index: int = int(operation.get("index", -1))
	var point_count: int = (
		(root as AnimationNodeBlendSpace1D).get_blend_point_count()
		if root is AnimationNodeBlendSpace1D
		else (root as AnimationNodeBlendSpace2D).get_blend_point_count()
	)
	if operation_type == "add_blend_point":
		var child_result: Dictionary = _create_animation_node(operation, true)
		if not bool(child_result.get("ok", false)):
			return str(child_result.get("error", "animation_node_create_failed"))
		var point_name: StringName = StringName(str(operation.get("name", "")))
		if root is AnimationNodeBlendSpace1D:
			var blend_space_1d: AnimationNodeBlendSpace1D = root as AnimationNodeBlendSpace1D
			blend_space_1d.add_blend_point(
				child_result.get("value"),
				float(operation.get("position", 0.0)),
				point_index
			)
			if not str(point_name).is_empty():
				var added_index_1d: int = point_index if point_index >= 0 else blend_space_1d.get_blend_point_count() - 1
				blend_space_1d.set_blend_point_name(added_index_1d, point_name)
		else:
			var position_result: Dictionary = variant_codec.decode(operation.get("position"), Vector2.ZERO)
			if not bool(position_result.get("ok", false)) or not position_result.get("value") is Vector2:
				return "invalid_blend_point_position"
			var blend_space_2d: AnimationNodeBlendSpace2D = root as AnimationNodeBlendSpace2D
			blend_space_2d.add_blend_point(
				child_result.get("value"),
				position_result.get("value"),
				point_index
			)
			if not str(point_name).is_empty():
				var added_index_2d: int = point_index if point_index >= 0 else blend_space_2d.get_blend_point_count() - 1
				blend_space_2d.set_blend_point_name(added_index_2d, point_name)
		return ""
	if point_index < 0 or point_index >= point_count:
		return "blend_point_out_of_range"
	if operation_type == "remove_blend_point":
		if root is AnimationNodeBlendSpace1D:
			(root as AnimationNodeBlendSpace1D).remove_blend_point(point_index)
		else:
			(root as AnimationNodeBlendSpace2D).remove_blend_point(point_index)
	elif operation_type == "move_blend_point":
		if root is AnimationNodeBlendSpace1D:
			(root as AnimationNodeBlendSpace1D).set_blend_point_position(
				point_index,
				float(operation.get("position", 0.0))
			)
		else:
			var position_result: Dictionary = variant_codec.decode(operation.get("position"), Vector2.ZERO)
			if not bool(position_result.get("ok", false)) or not position_result.get("value") is Vector2:
				return "invalid_blend_point_position"
			(root as AnimationNodeBlendSpace2D).set_blend_point_position(point_index, position_result.get("value"))
	elif operation_type == "rename_blend_point":
		if root is AnimationNodeBlendSpace1D:
			(root as AnimationNodeBlendSpace1D).set_blend_point_name(point_index, StringName(str(operation.get("name", ""))))
		else:
			(root as AnimationNodeBlendSpace2D).set_blend_point_name(point_index, StringName(str(operation.get("name", ""))))
	else:
		var to_index: int = int(operation.get("toIndex", -1))
		if to_index < 0 or to_index >= point_count:
			return "blend_point_out_of_range"
		if root is AnimationNodeBlendSpace1D:
			(root as AnimationNodeBlendSpace1D).reorder_blend_point(point_index, to_index)
		else:
			(root as AnimationNodeBlendSpace2D).reorder_blend_point(point_index, to_index)
	return ""


func _create_animation_node(operation: Dictionary, require_root: bool) -> Dictionary:
	var class_name_text: String = str(operation.get("nodeClass", "")).strip_edges()
	var base_class: String = "AnimationRootNode" if require_root else "AnimationNode"
	if (
		not ClassDB.class_exists(class_name_text)
		or not ClassDB.is_parent_class(class_name_text, base_class)
		or not ClassDB.can_instantiate(class_name_text)
	):
		return { "ok": false, "error": "invalid_animation_node_class:%s" % class_name_text }
	var value: Variant = ClassDB.instantiate(class_name_text)
	if not value is AnimationNode:
		return { "ok": false, "error": "animation_node_create_failed" }
	var property_error: String = _set_object_properties(value as Object, operation.get("properties", {}))
	if not property_error.is_empty():
		return { "ok": false, "error": property_error }
	return { "ok": true, "value": value }


func _set_object_properties(target: Object, properties_value: Variant) -> String:
	if typeof(properties_value) != TYPE_DICTIONARY:
		return "invalid_properties"
	for property_key in (properties_value as Dictionary).keys():
		var property_name: String = str(property_key)
		if not _object_has_property(target, property_name):
			return "property_not_found:%s" % property_name
		var decoded: Dictionary = variant_codec.decode(
			(properties_value as Dictionary)[property_key],
			target.get(property_name)
		)
		if not bool(decoded.get("ok", false)):
			return str(decoded.get("error", "invalid_property_value"))
		target.set(property_name, decoded.get("value"))
	return ""


func _replace_animation_libraries(mixer: Object, libraries: Dictionary) -> void:
	for library_name in mixer.call("get_animation_library_list"):
		mixer.call("remove_animation_library", library_name)
	for library_key in libraries.keys():
		mixer.call(
			"add_animation_library",
			StringName(str(library_key)),
			libraries[library_key] as AnimationLibrary
		)


func inspect_live_node(target: Node, args: Dictionary) -> Dictionary:
	var offset: int = maxi(0, int(args.get("offset", 0)))
	var limit: int = clampi(int(args.get("limit", 100)), 1, MAX_PROPERTIES)
	var max_depth: int = clampi(int(args.get("maxDepth", 2)), 0, 4)
	var summary: Dictionary = _serialize_object(target, offset, limit, max_depth)
	summary["nodePath"] = str(target.get_path())
	summary["sceneFilePath"] = target.scene_file_path
	summary["groups"] = Array(target.get_groups())
	return {
		"ok": true,
		"node": summary,
		"fingerprint": variant_codec.fingerprint(summary)
	}


func _inspect_map(args: Dictionary, edited_root: Node) -> Dictionary:
	var resolved: Dictionary = _resolve_scene_node(args, edited_root)
	if not bool(resolved.get("ok", false)):
		return resolved
	var target: Node = resolved.get("node") as Node
	var limit: int = clampi(int(args.get("limit", 1000)), 1, MAX_MAP_CELLS)
	var region: Dictionary = args.get("region", {}) as Dictionary
	var cells: Array = []
	if _is_2d_tile_map(target):
		for cell in _tile_map_get_used_cells(target):
			if not _cell_in_region_2d(cell, region):
				continue
			cells.append({
				"position": variant_codec.encode(cell),
				"sourceId": _tile_map_get_cell_source_id(target, cell),
				"atlasCoords": variant_codec.encode(_tile_map_get_cell_atlas_coords(target, cell)),
				"alternativeTile": _tile_map_get_cell_alternative_tile(target, cell)
			})
			if cells.size() >= limit:
				break
		return {
			"ok": true,
			"kind": target.get_class(),
			"nodePath": str(target.get_path()),
			"tileSet": variant_codec.encode(_tile_map_get_tile_set(target)),
			"cells": cells,
			"truncated": cells.size() >= limit,
			"fingerprint": variant_codec.fingerprint(cells)
		}
	if target is GridMap:
		for cell in (target as GridMap).get_used_cells():
			if not _cell_in_region_3d(cell, region):
				continue
			cells.append({
				"position": variant_codec.encode(cell),
				"item": (target as GridMap).get_cell_item(cell),
				"orientation": (target as GridMap).get_cell_item_orientation(cell)
			})
			if cells.size() >= limit:
				break
		return {
			"ok": true,
			"kind": "GridMap",
			"nodePath": str(target.get_path()),
			"meshLibrary": variant_codec.encode((target as GridMap).mesh_library),
			"cells": cells,
			"truncated": cells.size() >= limit,
			"fingerprint": variant_codec.fingerprint(cells)
		}
	return { "ok": false, "error": "node_is_not_supported_map" }


func _propose_map_patch(args: Dictionary, edited_root: Node) -> Dictionary:
	var prepared: Dictionary = _prepare_map_patch(args, edited_root)
	if not bool(prepared.get("ok", false)):
		return prepared
	return {
		"ok": true,
		"valid": true,
		"operations": prepared.get("operations"),
		"before": variant_codec.encode({
			"cells": prepared.get("before"),
			"tileSet": _summarize_tile_set(prepared.get("beforeTileSet") as TileSet)
		}, 0, 4, MAX_MAP_CELLS),
		"after": variant_codec.encode({
			"cells": prepared.get("after"),
			"tileSet": _summarize_tile_set(prepared.get("afterTileSet") as TileSet)
		}, 0, 4, MAX_MAP_CELLS),
		"fingerprint": prepared.get("fingerprint"),
		"warnings": prepared.get("warnings", [])
	}


func _apply_map_patch(args: Dictionary, edited_root: Node) -> Dictionary:
	if editor_undo_redo == null:
		return { "ok": false, "error": "editor_undo_redo_unavailable" }
	var prepared: Dictionary = _prepare_map_patch(args, edited_root)
	if not bool(prepared.get("ok", false)):
		return prepared
	var expected_fingerprint: String = str(args.get("expectedFingerprint", "")).strip_edges()
	if not expected_fingerprint.is_empty() and expected_fingerprint != str(prepared.get("fingerprint", "")):
		return {
			"ok": false,
			"error": "map_patch_conflict",
			"expectedFingerprint": expected_fingerprint,
			"actualFingerprint": prepared.get("fingerprint")
		}
	var target: Node = prepared.get("node") as Node
	editor_undo_redo.create_action(_action_title(args, "Map patch"))
	editor_undo_redo.add_do_method(
		self,
		"_restore_map_state",
		target,
		prepared.get("after"),
		prepared.get("afterTileSet")
	)
	editor_undo_redo.add_undo_method(
		self,
		"_restore_map_state",
		target,
		prepared.get("before"),
		prepared.get("beforeTileSet")
	)
	editor_undo_redo.commit_action()
	target.get_tree().edited_scene_root = edited_root
	return {
		"ok": true,
		"operations": (prepared.get("operations", []) as Array).size(),
		"fingerprintBefore": prepared.get("fingerprint"),
		"fingerprintAfter": variant_codec.fingerprint({
			"cells": prepared.get("after"),
			"tileSet": _summarize_tile_set(prepared.get("afterTileSet") as TileSet)
		})
	}


func _prepare_map_patch(args: Dictionary, edited_root: Node) -> Dictionary:
	var resolved: Dictionary = _resolve_scene_node(args, edited_root)
	if not bool(resolved.get("ok", false)):
		return resolved
	var target: Node = resolved.get("node") as Node
	if not _is_2d_tile_map(target) and not target is GridMap:
		return { "ok": false, "error": "node_is_not_supported_map" }
	var operations_value: Variant = args.get("operations", [])
	if typeof(operations_value) != TYPE_ARRAY:
		return { "ok": false, "error": "invalid_operations" }
	var operations: Array = operations_value as Array
	if operations.is_empty() or operations.size() > MAX_PATCH_OPERATIONS:
		return { "ok": false, "error": "invalid_operation_count" }
	var before: Array = _snapshot_map_cells(target)
	var after: Array = before.duplicate(true)
	var before_tile_set: TileSet = null
	var after_tile_set: TileSet = null
	if _is_2d_tile_map(target):
		before_tile_set = _tile_map_get_tile_set(target)
		after_tile_set = before_tile_set.duplicate(true) as TileSet if before_tile_set != null else TileSet.new()
	var warnings: Array = []
	for operation_value in operations:
		if typeof(operation_value) != TYPE_DICTIONARY:
			return { "ok": false, "error": "invalid_operation" }
		var operation: Dictionary = operation_value as Dictionary
		var error: String
		if str(operation.get("type", "")) in [
			"set_tileset_property",
			"add_atlas_source",
			"remove_tileset_source",
			"create_atlas_tile",
			"remove_atlas_tile",
			"add_terrain_set",
			"remove_terrain_set",
			"set_terrain_set_mode",
			"add_terrain",
			"remove_terrain",
			"set_terrain_name",
			"set_terrain_color"
		]:
			if after_tile_set == null:
				return { "ok": false, "error": "tileset_operation_requires_tile_map_layer" }
			error = _apply_virtual_tileset_operation(after_tile_set, operation)
		else:
			error = _apply_virtual_map_operation(after, target, operation)
		if not error.is_empty():
			return { "ok": false, "error": error }
	if after.size() > MAX_MAP_CELLS:
		return { "ok": false, "error": "map_cell_limit_exceeded" }
	if _is_2d_tile_map(target) and after_tile_set != null:
		for cell in after:
			var source_id: int = int(cell.get("sourceId", -1))
			if not after_tile_set.has_source(source_id):
				return { "ok": false, "error": "map_cell_source_not_found:%d" % source_id }
			var source: TileSetSource = after_tile_set.get_source(source_id)
			if (
				source is TileSetAtlasSource
				and not (source as TileSetAtlasSource).has_tile(
					cell.get("atlasCoords", Vector2i(-1, -1)) as Vector2i
				)
			):
				return { "ok": false, "error": "map_cell_atlas_tile_not_found" }
	if target is GridMap:
		var mesh_library: MeshLibrary = (target as GridMap).mesh_library
		if mesh_library == null and not after.is_empty():
			return { "ok": false, "error": "grid_map_has_no_mesh_library" }
		for cell in after:
			if not mesh_library.has_item(int(cell.get("item", -1))):
				return { "ok": false, "error": "mesh_library_item_not_found" }
	return {
		"ok": true,
		"node": target,
		"operations": operations,
		"before": before,
		"after": after,
		"beforeTileSet": before_tile_set,
		"afterTileSet": after_tile_set,
		"fingerprint": variant_codec.fingerprint({
			"cells": before,
			"tileSet": _summarize_tile_set(before_tile_set)
		}),
		"warnings": warnings
	}


func _snapshot_map_cells(target: Node) -> Array:
	var cells: Array = []
	if _is_2d_tile_map(target):
		for position in _tile_map_get_used_cells(target):
			cells.append({
				"position": position,
				"sourceId": _tile_map_get_cell_source_id(target, position),
				"atlasCoords": _tile_map_get_cell_atlas_coords(target, position),
				"alternativeTile": _tile_map_get_cell_alternative_tile(target, position)
			})
	elif target is GridMap:
		for position in (target as GridMap).get_used_cells():
			cells.append({
				"position": position,
				"item": (target as GridMap).get_cell_item(position),
				"orientation": (target as GridMap).get_cell_item_orientation(position)
			})
	return cells


func _apply_virtual_map_operation(cells: Array, target: Node, operation: Dictionary) -> String:
	var operation_type: String = str(operation.get("type", ""))
	if operation_type in ["clear", "clear_cells", "replace_all"]:
		cells.clear()
		if operation_type != "replace_all":
			return ""
		var replacement_value: Variant = operation.get("cells", [])
		if typeof(replacement_value) != TYPE_ARRAY:
			return "invalid_map_cells"
		for replacement in replacement_value as Array:
			if typeof(replacement) != TYPE_DICTIONARY:
				return "invalid_map_cell"
			var replacement_error: String = _apply_virtual_map_operation(cells, target, replacement as Dictionary)
			if not replacement_error.is_empty():
				return replacement_error
		return ""
	if operation_type not in ["set_cell", "erase_cell"]:
		return "unsupported_map_operation:%s" % operation_type
	var position_result: Dictionary = _decode_map_position(operation.get("position"), target)
	if not bool(position_result.get("ok", false)):
		return str(position_result.get("error", "invalid_map_position"))
	var position: Variant = position_result.get("value")
	var existing_index: int = _find_map_cell(cells, position)
	if operation_type == "erase_cell":
		if existing_index >= 0:
			cells.remove_at(existing_index)
		return ""
	var cell: Dictionary = { "position": position }
	if _is_2d_tile_map(target):
		var source_id: int = int(operation.get("sourceId", -1))
		if source_id < 0:
			return "invalid_tile_source_id"
		var atlas_result: Dictionary = variant_codec.decode(operation.get("atlasCoords", {
			"$type": "Vector2i", "x": -1, "y": -1
		}), Vector2i.ZERO)
		if not bool(atlas_result.get("ok", false)) or not atlas_result.get("value") is Vector2i:
			return "invalid_tile_atlas_coords"
		cell["sourceId"] = source_id
		cell["atlasCoords"] = atlas_result.get("value")
		cell["alternativeTile"] = int(operation.get("alternativeTile", 0))
	else:
		var item: int = int(operation.get("item", -1))
		if item < 0:
			return "invalid_mesh_library_item"
		cell["item"] = item
		cell["orientation"] = int(operation.get("orientation", 0))
	if existing_index >= 0:
		cells[existing_index] = cell
	else:
		cells.append(cell)
	return ""


func _restore_map_state(target: Node, cells: Array, tile_set: TileSet) -> void:
	if _is_2d_tile_map(target):
		_tile_map_set_tile_set(target, tile_set)
		_tile_map_clear(target)
		for cell_value in cells:
			var cell: Dictionary = cell_value as Dictionary
			_tile_map_set_cell(
				target,
				cell.get("position", Vector2i.ZERO) as Vector2i,
				int(cell.get("sourceId", -1)),
				cell.get("atlasCoords", Vector2i(-1, -1)) as Vector2i,
				int(cell.get("alternativeTile", 0))
			)
	elif target is GridMap:
		(target as GridMap).clear()
		for cell_value in cells:
			var cell: Dictionary = cell_value as Dictionary
			(target as GridMap).set_cell_item(
				cell.get("position", Vector3i.ZERO) as Vector3i,
				int(cell.get("item", -1)),
				int(cell.get("orientation", 0))
			)


func _apply_virtual_tileset_operation(tile_set: TileSet, operation: Dictionary) -> String:
	var operation_type: String = str(operation.get("type", ""))
	if operation_type == "set_tileset_property":
		var property_name: String = str(operation.get("property", ""))
		if property_name.is_empty() or not _object_has_property(tile_set, property_name):
			return "tileset_property_not_found:%s" % property_name
		var decoded_property: Dictionary = variant_codec.decode(operation.get("value"), tile_set.get(property_name))
		if not bool(decoded_property.get("ok", false)):
			return str(decoded_property.get("error", "invalid_tileset_property"))
		tile_set.set(property_name, decoded_property.get("value"))
		return ""
	if operation_type == "add_atlas_source":
		var atlas_source: TileSetAtlasSource = TileSetAtlasSource.new()
		if operation.has("texture") and operation.get("texture") != null:
			var decoded_texture: Dictionary = variant_codec.decode(operation.get("texture"))
			if not bool(decoded_texture.get("ok", false)) or not decoded_texture.get("value") is Texture2D:
				return "invalid_tileset_atlas_texture"
			atlas_source.texture = decoded_texture.get("value") as Texture2D
		if operation.has("textureRegionSize"):
			var region_size: Dictionary = variant_codec.decode(operation.get("textureRegionSize"), Vector2i(16, 16))
			if not bool(region_size.get("ok", false)) or not region_size.get("value") is Vector2i:
				return "invalid_tileset_texture_region_size"
			atlas_source.texture_region_size = region_size.get("value")
		var added_source_id: int = tile_set.add_source(atlas_source, int(operation.get("sourceId", -1)))
		return "" if added_source_id >= 0 else "tileset_source_add_failed"
	if operation_type in [
		"add_terrain_set",
		"remove_terrain_set",
		"set_terrain_set_mode",
		"add_terrain",
		"remove_terrain",
		"set_terrain_name",
		"set_terrain_color"
	]:
		return _apply_virtual_terrain_operation(tile_set, operation)
	var source_id: int = int(operation.get("sourceId", -1))
	if source_id < 0 or not tile_set.has_source(source_id):
		return "tileset_source_not_found"
	if operation_type == "remove_tileset_source":
		tile_set.remove_source(source_id)
		return ""
	var source: TileSetSource = tile_set.get_source(source_id)
	if operation_type in ["create_atlas_tile", "remove_atlas_tile"]:
		if not source is TileSetAtlasSource:
			return "tileset_source_is_not_atlas"
		var atlas_coords_result: Dictionary = variant_codec.decode(operation.get("atlasCoords"), Vector2i.ZERO)
		if not bool(atlas_coords_result.get("ok", false)) or not atlas_coords_result.get("value") is Vector2i:
			return "invalid_tile_atlas_coords"
		var atlas_coords: Vector2i = atlas_coords_result.get("value") as Vector2i
		if operation_type == "create_atlas_tile":
			var size_result: Dictionary = variant_codec.decode(
				operation.get("size", { "$type": "Vector2i", "value": [1, 1] }),
				Vector2i.ONE
			)
			if not bool(size_result.get("ok", false)) or not size_result.get("value") is Vector2i:
				return "invalid_atlas_tile_size"
			if (source as TileSetAtlasSource).has_tile(atlas_coords):
				return "atlas_tile_exists"
			(source as TileSetAtlasSource).create_tile(atlas_coords, size_result.get("value"))
		else:
			if not (source as TileSetAtlasSource).has_tile(atlas_coords):
				return "atlas_tile_not_found"
			(source as TileSetAtlasSource).remove_tile(atlas_coords)
		return ""
	return "unsupported_tileset_operation:%s" % operation_type


func _apply_virtual_terrain_operation(tile_set: TileSet, operation: Dictionary) -> String:
	var operation_type: String = str(operation.get("type", ""))
	var terrain_set: int = int(operation.get("terrainSet", -1))
	if operation_type == "add_terrain_set":
		var insert_at: int = int(operation.get("index", -1))
		tile_set.add_terrain_set(insert_at)
		terrain_set = tile_set.get_terrain_sets_count() - 1 if insert_at < 0 else insert_at
		if operation.has("mode"):
			tile_set.set_terrain_set_mode(terrain_set, int(operation.get("mode", TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)))
		return ""
	if terrain_set < 0 or terrain_set >= tile_set.get_terrain_sets_count():
		return "terrain_set_out_of_range"
	if operation_type == "remove_terrain_set":
		tile_set.remove_terrain_set(terrain_set)
		return ""
	if operation_type == "set_terrain_set_mode":
		tile_set.set_terrain_set_mode(
			terrain_set,
			int(operation.get("mode", TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES))
		)
		return ""
	if operation_type == "add_terrain":
		var insert_at: int = int(operation.get("index", -1))
		tile_set.add_terrain(terrain_set, insert_at)
		var terrain_index: int = tile_set.get_terrains_count(terrain_set) - 1 if insert_at < 0 else insert_at
		if operation.has("name"):
			tile_set.set_terrain_name(terrain_set, terrain_index, str(operation.get("name", "")))
		if operation.has("color"):
			var color_result: Dictionary = variant_codec.decode(operation.get("color"), Color.TRANSPARENT)
			if not bool(color_result.get("ok", false)) or not color_result.get("value") is Color:
				return "invalid_terrain_color"
			tile_set.set_terrain_color(terrain_set, terrain_index, color_result.get("value"))
		return ""
	var terrain: int = int(operation.get("terrain", -1))
	if terrain < 0 or terrain >= tile_set.get_terrains_count(terrain_set):
		return "terrain_out_of_range"
	if operation_type == "remove_terrain":
		tile_set.remove_terrain(terrain_set, terrain)
	elif operation_type == "set_terrain_name":
		tile_set.set_terrain_name(terrain_set, terrain, str(operation.get("name", "")))
	elif operation_type == "set_terrain_color":
		var color_result: Dictionary = variant_codec.decode(operation.get("color"), Color.TRANSPARENT)
		if not bool(color_result.get("ok", false)) or not color_result.get("value") is Color:
			return "invalid_terrain_color"
		tile_set.set_terrain_color(terrain_set, terrain, color_result.get("value"))
	else:
		return "unsupported_tileset_operation:%s" % operation_type
	return ""


func _summarize_tile_set(tile_set: TileSet) -> Variant:
	if tile_set == null:
		return null
	var sources: Array = []
	for source_index in range(tile_set.get_source_count()):
		var source_id: int = tile_set.get_source_id(source_index)
		var source: TileSetSource = tile_set.get_source(source_id)
		var source_summary: Dictionary = {
			"id": source_id,
			"class": source.get_class()
		}
		if source is TileSetAtlasSource:
			source_summary["texture"] = variant_codec.encode((source as TileSetAtlasSource).texture)
			source_summary["textureRegionSize"] = variant_codec.encode(
				(source as TileSetAtlasSource).texture_region_size
			)
			source_summary["tileCount"] = (source as TileSetAtlasSource).get_tiles_count()
		sources.append(source_summary)
	var terrain_sets: Array = []
	for terrain_set_index in range(tile_set.get_terrain_sets_count()):
		var terrains: Array = []
		for terrain_index in range(tile_set.get_terrains_count(terrain_set_index)):
			terrains.append({
				"name": tile_set.get_terrain_name(terrain_set_index, terrain_index),
				"color": variant_codec.encode(tile_set.get_terrain_color(terrain_set_index, terrain_index))
			})
		terrain_sets.append({
			"mode": tile_set.get_terrain_set_mode(terrain_set_index),
			"terrains": terrains
		})
	return {
		"tileSize": variant_codec.encode(tile_set.tile_size),
		"sources": sources,
		"terrainSets": terrain_sets
	}


func _decode_map_position(payload: Variant, target: Node) -> Dictionary:
	var expected: Variant = Vector2i.ZERO if _is_2d_tile_map(target) else Vector3i.ZERO
	var decoded: Dictionary = variant_codec.decode(payload, expected)
	if not bool(decoded.get("ok", false)):
		return decoded
	if _is_2d_tile_map(target) and not decoded.get("value") is Vector2i:
		return { "ok": false, "error": "map_position_requires_vector2i" }
	if target is GridMap and not decoded.get("value") is Vector3i:
		return { "ok": false, "error": "map_position_requires_vector3i" }
	return decoded


func _find_map_cell(cells: Array, position: Variant) -> int:
	for index in range(cells.size()):
		if cells[index].get("position") == position:
			return index
	return -1


func _is_2d_tile_map(target: Variant) -> bool:
	if target is TileMap:
		return true
	if not target is Object:
		return false
	var object: Object = target as Object
	return (
		object.get_class() == "TileMapLayer"
		and object.has_method("get_used_cells")
		and object.has_method("set_cell")
	)


func _tile_map_get_used_cells(target: Node) -> Array:
	if target is TileMap:
		return (target as TileMap).get_used_cells(0)
	return target.call("get_used_cells") as Array


func _tile_map_get_cell_source_id(target: Node, position: Vector2i) -> int:
	if target is TileMap:
		return (target as TileMap).get_cell_source_id(0, position)
	return int(target.call("get_cell_source_id", position))


func _tile_map_get_cell_atlas_coords(target: Node, position: Vector2i) -> Vector2i:
	if target is TileMap:
		return (target as TileMap).get_cell_atlas_coords(0, position)
	return target.call("get_cell_atlas_coords", position) as Vector2i


func _tile_map_get_cell_alternative_tile(target: Node, position: Vector2i) -> int:
	if target is TileMap:
		return (target as TileMap).get_cell_alternative_tile(0, position)
	return int(target.call("get_cell_alternative_tile", position))


func _tile_map_get_tile_set(target: Node) -> TileSet:
	return target.get("tile_set") as TileSet


func _tile_map_set_tile_set(target: Node, tile_set: TileSet) -> void:
	target.set("tile_set", tile_set)


func _tile_map_clear(target: Node) -> void:
	if target is TileMap:
		(target as TileMap).clear_layer(0)
		return
	target.call("clear")


func _tile_map_set_cell(
	target: Node,
	position: Vector2i,
	source_id: int,
	atlas_coords: Vector2i,
	alternative_tile: int
) -> void:
	if target is TileMap:
		(target as TileMap).set_cell(0, position, source_id, atlas_coords, alternative_tile)
		return
	target.call("set_cell", position, source_id, atlas_coords, alternative_tile)


func _cell_in_region_2d(cell: Vector2i, region: Dictionary) -> bool:
	if region.is_empty():
		return true
	var x: int = int(region.get("x", 0))
	var y: int = int(region.get("y", 0))
	var width: int = maxi(1, int(region.get("width", 1)))
	var height: int = maxi(1, int(region.get("height", 1)))
	return cell.x >= x and cell.x < x + width and cell.y >= y and cell.y < y + height


func _cell_in_region_3d(cell: Vector3i, region: Dictionary) -> bool:
	if region.is_empty():
		return true
	var x: int = int(region.get("x", 0))
	var y: int = int(region.get("y", 0))
	var z: int = int(region.get("z", 0))
	var width: int = maxi(1, int(region.get("width", 1)))
	var height: int = maxi(1, int(region.get("height", 1)))
	var depth: int = maxi(1, int(region.get("depth", 1)))
	return (
		cell.x >= x and cell.x < x + width
		and cell.y >= y and cell.y < y + height
		and cell.z >= z and cell.z < z + depth
	)


func _inspect_audio(args: Dictionary, edited_root: Node) -> Dictionary:
	var buses: Array = []
	for bus_index in range(AudioServer.bus_count):
		var effects: Array = []
		for effect_index in range(AudioServer.get_bus_effect_count(bus_index)):
			var effect: AudioEffect = AudioServer.get_bus_effect(bus_index, effect_index)
			effects.append({
				"index": effect_index,
				"class": effect.get_class() if effect != null else "Unknown",
				"enabled": AudioServer.is_bus_effect_enabled(bus_index, effect_index),
				"resource": variant_codec.encode(effect)
			})
		buses.append({
			"index": bus_index,
			"name": AudioServer.get_bus_name(bus_index),
			"send": AudioServer.get_bus_send(bus_index),
			"volumeDb": AudioServer.get_bus_volume_db(bus_index),
			"mute": AudioServer.is_bus_mute(bus_index),
			"solo": AudioServer.is_bus_solo(bus_index),
			"bypassEffects": AudioServer.is_bus_bypassing_effects(bus_index),
			"effects": effects
		})
	var player_summary: Variant = null
	if args.has("nodePath"):
		var resolved: Dictionary = _resolve_scene_node(args, edited_root)
		if not bool(resolved.get("ok", false)):
			return resolved
		var player: Node = resolved.get("node") as Node
		if not _is_audio_player(player):
			return { "ok": false, "error": "node_is_not_audio_stream_player" }
		player_summary = _serialize_object(player, 0, 100, 2)
	return {
		"ok": true,
		"buses": buses,
		"player": player_summary,
		"fingerprint": variant_codec.fingerprint(buses)
	}


func _propose_audio_patch(args: Dictionary) -> Dictionary:
	var validated: Dictionary = _validate_audio_patch(args)
	if not bool(validated.get("ok", false)):
		return validated
	var before: Array = _summarize_audio_buses()
	return {
		"ok": true,
		"valid": true,
		"operations": validated.get("operations"),
		"before": before,
		"after": validated.get("after"),
		"fingerprint": variant_codec.fingerprint(before),
		"warnings": []
	}


func _apply_audio_patch(args: Dictionary) -> Dictionary:
	if editor_undo_redo == null:
		return { "ok": false, "error": "editor_undo_redo_unavailable" }
	var validated: Dictionary = _validate_audio_patch(args)
	if not bool(validated.get("ok", false)):
		return validated
	var before_summary: Array = _summarize_audio_buses()
	var fingerprint: String = variant_codec.fingerprint(before_summary)
	var expected_fingerprint: String = str(args.get("expectedFingerprint", "")).strip_edges()
	if not expected_fingerprint.is_empty() and expected_fingerprint != fingerprint:
		return {
			"ok": false,
			"error": "audio_patch_conflict",
			"expectedFingerprint": expected_fingerprint,
			"actualFingerprint": fingerprint
		}
	var before_layout: AudioBusLayout = AudioServer.generate_bus_layout()
	var operation_error: String = _apply_audio_operations(validated.get("operations", []) as Array)
	if not operation_error.is_empty():
		AudioServer.set_bus_layout(before_layout)
		return { "ok": false, "error": operation_error }
	var after_layout: AudioBusLayout = AudioServer.generate_bus_layout()
	var after_summary: Array = _summarize_audio_buses()
	AudioServer.set_bus_layout(before_layout)
	editor_undo_redo.create_action(_action_title(args, "Audio patch"))
	editor_undo_redo.add_do_method(self, "_set_audio_bus_layout", after_layout)
	editor_undo_redo.add_undo_method(self, "_set_audio_bus_layout", before_layout)
	editor_undo_redo.commit_action()
	return {
		"ok": true,
		"operations": (validated.get("operations", []) as Array).size(),
		"saved": FileAccess.file_exists(DEFAULT_AUDIO_BUS_LAYOUT_PATH),
		"fingerprintBefore": fingerprint,
		"fingerprintAfter": variant_codec.fingerprint(after_summary)
	}


func _validate_audio_patch(args: Dictionary) -> Dictionary:
	var operations_value: Variant = args.get("operations", [])
	if typeof(operations_value) != TYPE_ARRAY:
		return { "ok": false, "error": "invalid_operations" }
	var operations: Array = operations_value as Array
	if operations.is_empty() or operations.size() > MAX_PATCH_OPERATIONS:
		return { "ok": false, "error": "invalid_operation_count" }
	var supported: Array = [
		"add_bus", "remove_bus", "move_bus", "rename_bus", "set_bus_send",
		"set_bus_volume", "set_bus_mute", "set_bus_solo", "set_bus_bypass",
		"add_effect", "remove_effect", "set_effect_enabled"
	]
	for operation_value in operations:
		if typeof(operation_value) != TYPE_DICTIONARY:
			return { "ok": false, "error": "invalid_operation" }
		var operation: Dictionary = operation_value as Dictionary
		var operation_type: String = str(operation.get("type", ""))
		if operation_type not in supported:
			return { "ok": false, "error": "unsupported_audio_operation:%s" % operation_type }
		if operation_type == "add_effect":
			var effect_result: Dictionary = _create_audio_effect(operation)
			if not bool(effect_result.get("ok", false)):
				return effect_result
	var simulation: Dictionary = _simulate_audio_operations(_summarize_audio_buses(), operations)
	if not bool(simulation.get("ok", false)):
		return simulation
	return { "ok": true, "operations": operations, "after": simulation.get("buses") }


func _simulate_audio_operations(before: Array, operations: Array) -> Dictionary:
	var buses: Array = before.duplicate(true)
	for operation_value in operations:
		var operation: Dictionary = operation_value as Dictionary
		var operation_type: String = str(operation.get("type", ""))
		if operation_type == "add_bus":
			var insert_at: int = int(operation.get("index", buses.size()))
			if insert_at < 1 or insert_at > buses.size():
				return { "ok": false, "error": "audio_bus_index_out_of_range" }
			var bus_name: String = str(operation.get("name", "")).strip_edges()
			if bus_name.is_empty() or _find_virtual_audio_bus(buses, bus_name) >= 0:
				return { "ok": false, "error": "invalid_or_duplicate_audio_bus_name" }
			buses.insert(insert_at, {
				"name": bus_name,
				"send": "Master",
				"volumeDb": 0.0,
				"mute": false,
				"solo": false,
				"bypassEffects": false,
				"effects": []
			})
			continue
		var bus_index: int = (
			int(operation.get("busIndex", -1))
			if operation.has("busIndex")
			else _find_virtual_audio_bus(buses, str(operation.get("bus", "")))
		)
		if bus_index < 0 or bus_index >= buses.size():
			return { "ok": false, "error": "audio_bus_not_found" }
		var bus: Dictionary = buses[bus_index]
		if operation_type == "remove_bus":
			if bus_index == 0:
				return { "ok": false, "error": "cannot_remove_master_bus" }
			buses.remove_at(bus_index)
		elif operation_type == "move_bus":
			var to_index: int = int(operation.get("toIndex", -1))
			if bus_index == 0 or to_index < 1 or to_index >= buses.size():
				return { "ok": false, "error": "invalid_audio_bus_move" }
			var moved_bus: Dictionary = buses.pop_at(bus_index)
			buses.insert(to_index, moved_bus)
		elif operation_type == "rename_bus":
			var new_name: String = str(operation.get("name", "")).strip_edges()
			var existing_index: int = _find_virtual_audio_bus(buses, new_name)
			if new_name.is_empty() or (existing_index >= 0 and existing_index != bus_index):
				return { "ok": false, "error": "invalid_or_duplicate_audio_bus_name" }
			bus["name"] = new_name
		elif operation_type == "set_bus_send":
			var send_name: String = str(operation.get("send", "Master"))
			if _find_virtual_audio_bus(buses, send_name) < 0 or send_name == str(bus.get("name", "")):
				return { "ok": false, "error": "invalid_audio_bus_send" }
			bus["send"] = send_name
		elif operation_type == "set_bus_volume":
			bus["volumeDb"] = float(operation.get("volumeDb", 0.0))
		elif operation_type == "set_bus_mute":
			bus["mute"] = bool(operation.get("enabled", true))
		elif operation_type == "set_bus_solo":
			bus["solo"] = bool(operation.get("enabled", true))
		elif operation_type == "set_bus_bypass":
			bus["bypassEffects"] = bool(operation.get("enabled", true))
		elif operation_type == "add_effect":
			var effect_result: Dictionary = _create_audio_effect(operation)
			var effect: AudioEffect = effect_result.get("value") as AudioEffect
			var effects: Array = bus.get("effects", []) as Array
			var effect_index: int = int(operation.get("index", -1))
			var effect_summary: Dictionary = { "class": effect.get_class(), "enabled": true }
			if effect_index < 0:
				effects.append(effect_summary)
			elif effect_index <= effects.size():
				effects.insert(effect_index, effect_summary)
			else:
				return { "ok": false, "error": "audio_effect_index_out_of_range" }
		elif operation_type in ["remove_effect", "set_effect_enabled"]:
			var effects: Array = bus.get("effects", []) as Array
			var effect_index: int = int(operation.get("effectIndex", -1))
			if effect_index < 0 or effect_index >= effects.size():
				return { "ok": false, "error": "audio_effect_not_found" }
			if operation_type == "remove_effect":
				effects.remove_at(effect_index)
			else:
				(effects[effect_index] as Dictionary)["enabled"] = bool(operation.get("enabled", true))
	return { "ok": true, "buses": buses }


func _find_virtual_audio_bus(buses: Array, bus_name: String) -> int:
	for index in range(buses.size()):
		if str(buses[index].get("name", "")) == bus_name:
			return index
	return -1


func _apply_audio_operations(operations: Array) -> String:
	for operation_value in operations:
		var operation: Dictionary = operation_value as Dictionary
		var operation_type: String = str(operation.get("type", ""))
		var bus_index: int = _resolve_audio_bus_index(operation)
		if operation_type == "add_bus":
			var insert_at: int = clampi(int(operation.get("index", AudioServer.bus_count)), 1, AudioServer.bus_count)
			AudioServer.add_bus(insert_at)
			AudioServer.set_bus_name(insert_at, str(operation.get("name", "Bus %d" % insert_at)))
			continue
		if bus_index < 0 or bus_index >= AudioServer.bus_count:
			return "audio_bus_not_found"
		if operation_type == "remove_bus":
			if bus_index == 0:
				return "cannot_remove_master_bus"
			AudioServer.remove_bus(bus_index)
		elif operation_type == "move_bus":
			if bus_index == 0:
				return "cannot_move_master_bus"
			AudioServer.move_bus(bus_index, clampi(int(operation.get("toIndex", bus_index)), 1, AudioServer.bus_count - 1))
		elif operation_type == "rename_bus":
			AudioServer.set_bus_name(bus_index, str(operation.get("name", "")))
		elif operation_type == "set_bus_send":
			AudioServer.set_bus_send(bus_index, str(operation.get("send", "Master")))
		elif operation_type == "set_bus_volume":
			AudioServer.set_bus_volume_db(bus_index, float(operation.get("volumeDb", 0.0)))
		elif operation_type == "set_bus_mute":
			AudioServer.set_bus_mute(bus_index, bool(operation.get("enabled", true)))
		elif operation_type == "set_bus_solo":
			AudioServer.set_bus_solo(bus_index, bool(operation.get("enabled", true)))
		elif operation_type == "set_bus_bypass":
			AudioServer.set_bus_bypass_effects(bus_index, bool(operation.get("enabled", true)))
		elif operation_type == "add_effect":
			var effect_result: Dictionary = _create_audio_effect(operation)
			if not bool(effect_result.get("ok", false)):
				return str(effect_result.get("error", "invalid_audio_effect"))
			AudioServer.add_bus_effect(
				bus_index,
				effect_result.get("value") as AudioEffect,
				int(operation.get("index", -1))
			)
		elif operation_type == "remove_effect":
			var effect_index: int = int(operation.get("effectIndex", -1))
			if effect_index < 0 or effect_index >= AudioServer.get_bus_effect_count(bus_index):
				return "audio_effect_not_found"
			AudioServer.remove_bus_effect(bus_index, effect_index)
		elif operation_type == "set_effect_enabled":
			var effect_index: int = int(operation.get("effectIndex", -1))
			if effect_index < 0 or effect_index >= AudioServer.get_bus_effect_count(bus_index):
				return "audio_effect_not_found"
			AudioServer.set_bus_effect_enabled(bus_index, effect_index, bool(operation.get("enabled", true)))
	return ""


func _create_audio_effect(operation: Dictionary) -> Dictionary:
	if operation.has("effect"):
		var decoded: Dictionary = variant_codec.decode(operation.get("effect"))
		if not bool(decoded.get("ok", false)) or not decoded.get("value") is AudioEffect:
			return { "ok": false, "error": "invalid_audio_effect" }
		return { "ok": true, "value": decoded.get("value") }
	var effect_class: String = str(operation.get("effectClass", "")).strip_edges()
	if (
		not ClassDB.class_exists(effect_class)
		or not ClassDB.is_parent_class(effect_class, "AudioEffect")
		or not ClassDB.can_instantiate(effect_class)
	):
		return { "ok": false, "error": "invalid_audio_effect_class:%s" % effect_class }
	var effect: AudioEffect = ClassDB.instantiate(effect_class) as AudioEffect
	if effect == null:
		return { "ok": false, "error": "audio_effect_create_failed" }
	var property_error: String = _set_object_properties(effect, operation.get("properties", {}))
	if not property_error.is_empty():
		return { "ok": false, "error": property_error }
	return { "ok": true, "value": effect }


func _resolve_audio_bus_index(operation: Dictionary) -> int:
	if operation.has("busIndex"):
		return int(operation.get("busIndex", -1))
	var bus_name: StringName = StringName(str(operation.get("bus", "")))
	return AudioServer.get_bus_index(bus_name)


func _summarize_audio_buses() -> Array:
	var buses: Array = []
	for bus_index in range(AudioServer.bus_count):
		var effects: Array = []
		for effect_index in range(AudioServer.get_bus_effect_count(bus_index)):
			var effect: AudioEffect = AudioServer.get_bus_effect(bus_index, effect_index)
			effects.append({
				"class": effect.get_class() if effect != null else "Unknown",
				"enabled": AudioServer.is_bus_effect_enabled(bus_index, effect_index)
			})
		buses.append({
			"name": AudioServer.get_bus_name(bus_index),
			"send": AudioServer.get_bus_send(bus_index),
			"volumeDb": AudioServer.get_bus_volume_db(bus_index),
			"mute": AudioServer.is_bus_mute(bus_index),
			"solo": AudioServer.is_bus_solo(bus_index),
			"bypassEffects": AudioServer.is_bus_bypassing_effects(bus_index),
			"effects": effects
		})
	return buses


func _set_audio_bus_layout(layout: AudioBusLayout) -> void:
	AudioServer.set_bus_layout(layout)
	ResourceSaver.save(layout, DEFAULT_AUDIO_BUS_LAYOUT_PATH)


func _get_performance_snapshot(args: Dictionary) -> Dictionary:
	var monitor_names: Dictionary = _performance_monitor_allowlist()
	var requested_value: Variant = args.get("monitors", [])
	var requested: Array = requested_value as Array if typeof(requested_value) == TYPE_ARRAY else []
	if requested.is_empty():
		requested = monitor_names.keys()
	var monitors: Dictionary = {}
	for requested_name_value in requested:
		var requested_name: String = str(requested_name_value)
		if not monitor_names.has(requested_name):
			return { "ok": false, "error": "performance_monitor_not_allowed:%s" % requested_name }
		monitors[requested_name] = Performance.get_monitor(int(monitor_names[requested_name]))
	return { "ok": true, "monitors": monitors, "capturedAtMsec": Time.get_ticks_msec() }


func _performance_monitor_allowlist() -> Dictionary:
	return {
		"time/fps": Performance.TIME_FPS,
		"time/process": Performance.TIME_PROCESS,
		"time/physics_process": Performance.TIME_PHYSICS_PROCESS,
		"memory/static": Performance.MEMORY_STATIC,
		"memory/static_max": Performance.MEMORY_STATIC_MAX,
		"object/count": Performance.OBJECT_COUNT,
		"object/resource_count": Performance.OBJECT_RESOURCE_COUNT,
		"object/node_count": Performance.OBJECT_NODE_COUNT,
		"render/objects_in_frame": Performance.RENDER_TOTAL_OBJECTS_IN_FRAME,
		"render/primitives_in_frame": Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME,
		"render/draw_calls_in_frame": Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME,
		"physics_2d/active_objects": Performance.PHYSICS_2D_ACTIVE_OBJECTS,
		"physics_3d/active_objects": Performance.PHYSICS_3D_ACTIVE_OBJECTS
	}


func _navigate(args: Dictionary, edited_root: Node) -> Dictionary:
	if editor_interface == null:
		return { "ok": false, "error": "editor_interface_unavailable" }
	var action: String = str(args.get("action", ""))
	if action == "open_scene":
		var scene_path: String = str(args.get("scenePath", ""))
		if not variant_codec.is_safe_resource_path(scene_path, false) or not scene_path.ends_with(".tscn"):
			return { "ok": false, "error": "unsafe_scene_path" }
		editor_interface.open_scene_from_path(scene_path)
		return { "ok": true, "scenePath": scene_path }
	if action == "select_nodes":
		if editor_selection == null:
			return { "ok": false, "error": "editor_selection_unavailable" }
		var node_paths_value: Variant = args.get("nodePaths", [])
		if typeof(node_paths_value) != TYPE_ARRAY:
			return { "ok": false, "error": "invalid_node_paths" }
		var nodes: Array = []
		for node_path_value in node_paths_value as Array:
			var resolved: Dictionary = _resolve_scene_node({ "nodePath": str(node_path_value) }, edited_root)
			if not bool(resolved.get("ok", false)):
				return resolved
			nodes.append(resolved.get("node") as Node)
		editor_selection.clear()
		for node in nodes:
			editor_selection.add_node(node)
		return { "ok": true, "selected": nodes.size() }
	var resource_path: String = str(args.get("resourcePath", ""))
	if not variant_codec.is_safe_resource_path(resource_path, true):
		return { "ok": false, "error": "unsafe_resource_path" }
	if action == "open_script":
		var script: Script = load(resource_path) as Script
		if script == null:
			return { "ok": false, "error": "script_not_found" }
		editor_interface.edit_script(
			script,
			maxi(0, int(args.get("line", 1)) - 1),
			maxi(0, int(args.get("column", 1)) - 1),
			true
		)
		return { "ok": true }
	if action == "inspect_resource":
		var resource: Resource = load(resource_path)
		if resource == null:
			return { "ok": false, "error": "resource_not_found" }
		editor_interface.inspect_object(resource)
		return { "ok": true }
	if action == "focus_filesystem":
		editor_interface.get_file_system_dock().navigate_to_path(resource_path)
		return { "ok": true }
	return { "ok": false, "error": "unsupported_navigation_action:%s" % action }


func _preview_control(args: Dictionary, edited_root: Node) -> Dictionary:
	var resolved: Dictionary = _resolve_scene_node(args, edited_root)
	if not bool(resolved.get("ok", false)):
		return resolved
	var target: Node = resolved.get("node") as Node
	var kind: String = str(args.get("kind", ""))
	var action: String = str(args.get("action", ""))
	if kind == "animation" and target is AnimationPlayer:
		var animation_player: AnimationPlayer = target as AnimationPlayer
		if action == "play":
			animation_player.play(StringName(str(args.get("name", ""))))
		elif action == "pause":
			animation_player.pause()
		elif action == "stop":
			animation_player.stop()
		elif action == "seek":
			animation_player.seek(maxf(0.0, float(args.get("position", 0.0))), true)
		elif action == "restart":
			animation_player.stop()
			animation_player.play(StringName(str(args.get("name", ""))))
		else:
			return { "ok": false, "error": "unsupported_preview_action" }
		return { "ok": true, "kind": kind, "action": action }
	if kind == "audio" and _is_audio_player(target):
		if action in ["play", "restart"]:
			target.call("play", maxf(0.0, float(args.get("position", 0.0))))
		elif action == "stop":
			target.call("stop")
		else:
			return { "ok": false, "error": "audio_preview_supports_play_restart_stop" }
		return { "ok": true, "kind": kind, "action": action }
	if kind == "particles" and (target is GPUParticles2D or target is GPUParticles3D or target is CPUParticles2D or target is CPUParticles3D):
		if action not in ["play", "restart", "stop"]:
			return { "ok": false, "error": "particles_preview_supports_play_restart_stop" }
		target.set("emitting", action != "stop")
		if action == "restart":
			target.call("restart")
		return { "ok": true, "kind": kind, "action": action }
	return { "ok": false, "error": "preview_target_kind_mismatch" }


func _reimport_assets(args: Dictionary) -> Dictionary:
	if editor_interface == null:
		return { "ok": false, "error": "editor_interface_unavailable" }
	var paths_value: Variant = args.get("resourcePaths", [])
	if typeof(paths_value) != TYPE_ARRAY:
		return { "ok": false, "error": "invalid_resource_paths" }
	var paths: PackedStringArray = PackedStringArray()
	for path_value in paths_value as Array:
		var resource_path: String = str(path_value).replace("\\", "/")
		if not variant_codec.is_safe_resource_path(resource_path, false):
			return { "ok": false, "error": "unsafe_resource_path:%s" % resource_path }
		var absolute_path: String = ProjectSettings.globalize_path(resource_path)
		if not FileAccess.file_exists(absolute_path):
			return { "ok": false, "error": "resource_not_found:%s" % resource_path }
		paths.append(resource_path)
	editor_interface.get_resource_filesystem().reimport_files(paths)
	return { "ok": true, "reimported": Array(paths) }


func _bake_resource(args: Dictionary, edited_root: Node) -> Dictionary:
	var kind: String = str(args.get("kind", ""))
	if kind == "navigation_mesh":
		var resolved: Dictionary = _resolve_scene_node(args, edited_root)
		if not bool(resolved.get("ok", false)):
			return resolved
		var navigation_region: Node = resolved.get("node") as Node
		if not navigation_region is NavigationRegion3D:
			return { "ok": false, "error": "node_is_not_navigation_region_3d" }
		(navigation_region as NavigationRegion3D).bake_navigation_mesh(false)
		return { "ok": true, "kind": kind, "nodePath": str(navigation_region.get_path()) }
	if kind == "lightmap":
		var resolved: Dictionary = _resolve_scene_node(args, edited_root)
		if not bool(resolved.get("ok", false)):
			return resolved
		var lightmap: Node = resolved.get("node") as Node
		if not lightmap is LightmapGI:
			return { "ok": false, "error": "node_is_not_lightmap_gi" }
		if not lightmap.has_method("bake"):
			return { "ok": false, "error": "lightmap_bake_api_unavailable" }
		var bake_error: int = int(lightmap.call("bake"))
		return { "ok": bake_error == LightmapGI.BAKE_ERROR_OK, "bakeError": bake_error, "kind": kind }
	if kind == "mesh_library":
		return _bake_mesh_library(args)
	return { "ok": false, "error": "unsupported_bake_kind:%s" % kind }


func _bake_mesh_library(args: Dictionary) -> Dictionary:
	var resource_path: String = str(args.get("resourcePath", "")).replace("\\", "/")
	if not variant_codec.is_safe_resource_path(resource_path, false):
		return { "ok": false, "error": "unsafe_resource_path" }
	var mesh_library: MeshLibrary = load(resource_path) as MeshLibrary
	if mesh_library == null:
		return { "ok": false, "error": "mesh_library_not_found" }
	var source_scene_path: String = str(args.get("scenePath", "")).replace("\\", "/")
	if not variant_codec.is_safe_resource_path(source_scene_path, false):
		return { "ok": false, "error": "unsafe_source_scene_path" }
	var source_scene: PackedScene = load(source_scene_path) as PackedScene
	if source_scene == null:
		return { "ok": false, "error": "source_scene_not_found" }
	var source_root: Node = source_scene.instantiate()
	var next_id: int = 0
	var added: int = 0
	for child in source_root.get_children():
		if not child is MeshInstance3D or (child as MeshInstance3D).mesh == null:
			continue
		while mesh_library.has_item(next_id):
			next_id += 1
		mesh_library.create_item(next_id)
		mesh_library.set_item_name(next_id, child.name)
		mesh_library.set_item_mesh(next_id, (child as MeshInstance3D).mesh)
		mesh_library.set_item_mesh_transform(next_id, (child as MeshInstance3D).transform)
		added += 1
		next_id += 1
	source_root.free()
	var save_error: Error = ResourceSaver.save(mesh_library, resource_path)
	return {
		"ok": save_error == OK,
		"kind": "mesh_library",
		"itemsAdded": added,
		"error": "" if save_error == OK else "mesh_library_save_failed:%d" % int(save_error)
	}


func _resolve_scene_node(args: Dictionary, edited_root: Node) -> Dictionary:
	if edited_root == null:
		return { "ok": false, "error": "no_edited_scene" }
	var expected_scene_path: String = str(args.get("scenePath", "")).strip_edges().replace("\\", "/")
	if not expected_scene_path.is_empty():
		if not variant_codec.is_safe_resource_path(expected_scene_path, false):
			return { "ok": false, "error": "unsafe_scene_path" }
		if edited_root.scene_file_path != expected_scene_path:
			return {
				"ok": false,
				"error": "edited_scene_mismatch",
				"expectedScenePath": expected_scene_path,
				"actualScenePath": edited_root.scene_file_path
			}
	var node_path_text: String = str(args.get("nodePath", ".")).strip_edges()
	var target: Node = edited_root
	if not node_path_text.is_empty() and node_path_text != ".":
		var candidate: Node = edited_root.get_node_or_null(NodePath(node_path_text))
		if candidate == null and node_path_text == str(edited_root.get_path()):
			candidate = edited_root
		if candidate == null:
			return { "ok": false, "error": "node_not_found:%s" % node_path_text }
		target = candidate
	return { "ok": true, "node": target }


func _is_audio_player(target: Node) -> bool:
	return target is AudioStreamPlayer or target is AudioStreamPlayer2D or target is AudioStreamPlayer3D


func _call_methodv(target: Object, method_name: String, arguments: Array) -> void:
	target.callv(method_name, arguments)
