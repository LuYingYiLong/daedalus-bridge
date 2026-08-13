@tool
extends RefCounted

const MAX_DEPTH: int = 8
const MAX_COLLECTION_ITEMS: int = 10_000
const RESOURCE_PREFIX: String = "res://"
const PLUGIN_PREFIX: String = "res://addons/daedalus_bridge/"


static func encode(value: Variant, depth: int = 0, max_depth: int = 4, max_items: int = 500) -> Variant:
	if depth > mini(max_depth, MAX_DEPTH):
		return { "$type": "Truncated", "reason": "max_depth" }
	var value_type: int = typeof(value)
	match value_type:
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			return _tag("StringName", str(value))
		TYPE_NODE_PATH:
			return _tag("NodePath", str(value))
		TYPE_VECTOR2:
			return _tag("Vector2", [value.x, value.y])
		TYPE_VECTOR2I:
			return _tag("Vector2i", [value.x, value.y])
		TYPE_VECTOR3:
			return _tag("Vector3", [value.x, value.y, value.z])
		TYPE_VECTOR3I:
			return _tag("Vector3i", [value.x, value.y, value.z])
		TYPE_VECTOR4:
			return _tag("Vector4", [value.x, value.y, value.z, value.w])
		TYPE_VECTOR4I:
			return _tag("Vector4i", [value.x, value.y, value.z, value.w])
		TYPE_RECT2:
			return _tag("Rect2", [value.position.x, value.position.y, value.size.x, value.size.y])
		TYPE_RECT2I:
			return _tag("Rect2i", [value.position.x, value.position.y, value.size.x, value.size.y])
		TYPE_COLOR:
			return _tag("Color", [value.r, value.g, value.b, value.a])
		TYPE_PLANE:
			return _tag("Plane", [value.normal.x, value.normal.y, value.normal.z, value.d])
		TYPE_QUATERNION:
			return _tag("Quaternion", [value.x, value.y, value.z, value.w])
		TYPE_AABB:
			return _tag("AABB", [
				value.position.x, value.position.y, value.position.z,
				value.size.x, value.size.y, value.size.z
			])
		TYPE_TRANSFORM2D:
			return _tag("Transform2D", [
				encode(value.x, depth + 1, max_depth, max_items),
				encode(value.y, depth + 1, max_depth, max_items),
				encode(value.origin, depth + 1, max_depth, max_items)
			])
		TYPE_BASIS:
			return _tag("Basis", [
				encode(value.x, depth + 1, max_depth, max_items),
				encode(value.y, depth + 1, max_depth, max_items),
				encode(value.z, depth + 1, max_depth, max_items)
			])
		TYPE_TRANSFORM3D:
			return {
				"$type": "Transform3D",
				"basis": encode(value.basis, depth + 1, max_depth, max_items),
				"origin": encode(value.origin, depth + 1, max_depth, max_items)
			}
		TYPE_PROJECTION:
			return _tag("Projection", [
				encode(value.x, depth + 1, max_depth, max_items),
				encode(value.y, depth + 1, max_depth, max_items),
				encode(value.z, depth + 1, max_depth, max_items),
				encode(value.w, depth + 1, max_depth, max_items)
			])
		TYPE_ARRAY:
			var source_list: Array = value as Array
			var array_limit: int = mini(source_list.size(), mini(max_items, MAX_COLLECTION_ITEMS))
			var encoded_array: Array = []
			for index in range(array_limit):
				encoded_array.append(encode(source_list[index], depth + 1, max_depth, max_items))
			if source_list.size() > array_limit:
				encoded_array.append({ "$type": "Truncated", "remaining": source_list.size() - array_limit })
			return encoded_array
		TYPE_DICTIONARY:
			var source_map: Dictionary = value as Dictionary
			var keys: Array = source_map.keys()
			var dictionary_limit: int = mini(keys.size(), mini(max_items, MAX_COLLECTION_ITEMS))
			var entries: Array = []
			for index in range(dictionary_limit):
				var key: Variant = keys[index]
				entries.append({
					"key": encode(key, depth + 1, max_depth, max_items),
					"value": encode(source_map[key], depth + 1, max_depth, max_items)
				})
			return {
				"$type": "Dictionary",
				"entries": entries,
				"truncated": keys.size() > dictionary_limit
			}
		TYPE_PACKED_BYTE_ARRAY:
			return _tag("PackedByteArray", Array(value).slice(0, max_items))
		TYPE_PACKED_INT32_ARRAY:
			return _tag("PackedInt32Array", Array(value).slice(0, max_items))
		TYPE_PACKED_INT64_ARRAY:
			return _tag("PackedInt64Array", Array(value).slice(0, max_items))
		TYPE_PACKED_FLOAT32_ARRAY:
			return _tag("PackedFloat32Array", Array(value).slice(0, max_items))
		TYPE_PACKED_FLOAT64_ARRAY:
			return _tag("PackedFloat64Array", Array(value).slice(0, max_items))
		TYPE_PACKED_STRING_ARRAY:
			return _tag("PackedStringArray", Array(value).slice(0, max_items))
		TYPE_PACKED_VECTOR2_ARRAY:
			return _tag("PackedVector2Array", _encode_packed_values(Array(value), depth, max_depth, max_items))
		TYPE_PACKED_VECTOR3_ARRAY:
			return _tag("PackedVector3Array", _encode_packed_values(Array(value), depth, max_depth, max_items))
		TYPE_PACKED_COLOR_ARRAY:
			return _tag("PackedColorArray", _encode_packed_values(Array(value), depth, max_depth, max_items))
		TYPE_RID:
			return { "$type": "Opaque", "godotType": "RID", "value": str(value), "writable": false }
		TYPE_CALLABLE:
			return { "$type": "Opaque", "godotType": "Callable", "value": str(value), "writable": false }
		TYPE_SIGNAL:
			return { "$type": "Opaque", "godotType": "Signal", "value": str(value), "writable": false }
		TYPE_OBJECT:
			if value == null:
				return null
			if value is Resource:
				var resource: Resource = value as Resource
				return {
					"$type": "Resource",
					"path": resource.resource_path,
					"class": resource.get_class(),
					"name": resource.resource_name
				}
			if value is Node:
				var node: Node = value as Node
				return {
					"$type": "Object",
					"class": node.get_class(),
					"path": str(node.get_path()),
					"instanceId": node.get_instance_id(),
					"writable": false
				}
			return {
				"$type": "Object",
				"class": value.get_class(),
				"instanceId": value.get_instance_id(),
				"writable": false
			}
		_:
			return { "$type": "Opaque", "godotType": get_type_name(value_type), "value": str(value), "writable": false }


static func decode(payload: Variant, expected: Variant = null) -> Dictionary:
	return _decode(payload, expected, 0)


static func fingerprint(value: Variant) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	var serialized: String = JSON.stringify(encode(value, 0, 6, 2000))
	context.update(serialized.to_utf8_buffer())
	return context.finish().hex_encode()


static func is_safe_resource_path(resource_path: String, allow_plugin: bool = false) -> bool:
	var normalized: String = resource_path.strip_edges().replace("\\", "/")
	if not normalized.begins_with(RESOURCE_PREFIX):
		return false
	var relative_path: String = normalized.trim_prefix(RESOURCE_PREFIX)
	if (
		relative_path.is_empty()
		or relative_path.begins_with("/")
		or relative_path.contains("/../")
		or relative_path.begins_with("../")
		or relative_path.ends_with("/..")
		or relative_path.contains("//")
	):
		return false
	if normalized.begins_with("res://.godot/"):
		return false
	if not allow_plugin and normalized.begins_with(PLUGIN_PREFIX):
		return false
	return true


static func _decode(payload: Variant, expected: Variant, depth: int) -> Dictionary:
	if depth > MAX_DEPTH:
		return _error("variant_max_depth")
	if payload == null or typeof(payload) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
		if expected is int and typeof(payload) == TYPE_FLOAT:
			return _ok(int(payload))
		if expected is float and typeof(payload) == TYPE_INT:
			return _ok(float(payload))
		return _ok(payload)
	if typeof(payload) == TYPE_ARRAY:
		var result_array: Array = []
		if (payload as Array).size() > MAX_COLLECTION_ITEMS:
			return _error("variant_collection_too_large")
		for item in payload as Array:
			var decoded_item: Dictionary = _decode(item, null, depth + 1)
			if not bool(decoded_item.get("ok", false)):
				return decoded_item
			result_array.append(decoded_item.get("value"))
		return _ok(result_array)
	if typeof(payload) != TYPE_DICTIONARY:
		return _error("unsupported_variant_payload")

	var source: Dictionary = payload as Dictionary
	var tag: String = str(source.get("$type", ""))
	if tag.is_empty():
		var plain_map: Dictionary = {}
		for key in source.keys():
			var decoded_value: Dictionary = _decode(source[key], null, depth + 1)
			if not bool(decoded_value.get("ok", false)):
				return decoded_value
			plain_map[str(key)] = decoded_value.get("value")
		return _ok(plain_map)
	if tag in ["Opaque", "Object", "Truncated"]:
		return _error("variant_type_is_read_only:%s" % tag)
	if tag == "Resource":
		var resource_path: String = str(source.get("path", ""))
		if not is_safe_resource_path(resource_path, false):
			return _error("unsafe_resource_path")
		var resource: Resource = load(resource_path)
		if resource == null:
			return _error("resource_not_found:%s" % resource_path)
		return _ok(resource)
	if tag == "Dictionary":
		var entries_value: Variant = source.get("entries", [])
		if typeof(entries_value) != TYPE_ARRAY or (entries_value as Array).size() > MAX_COLLECTION_ITEMS:
			return _error("invalid_dictionary_entries")
		var decoded_map: Dictionary = {}
		for entry_value in entries_value as Array:
			if typeof(entry_value) != TYPE_DICTIONARY:
				return _error("invalid_dictionary_entry")
			var entry: Dictionary = entry_value as Dictionary
			var decoded_key: Dictionary = _decode(entry.get("key"), null, depth + 1)
			var decoded_value: Dictionary = _decode(entry.get("value"), null, depth + 1)
			if not bool(decoded_key.get("ok", false)):
				return decoded_key
			if not bool(decoded_value.get("ok", false)):
				return decoded_value
			decoded_map[decoded_key.get("value")] = decoded_value.get("value")
		return _ok(decoded_map)

	var values_value: Variant = source.get("value", [])
	var values: Array = values_value as Array if typeof(values_value) == TYPE_ARRAY else []
	match tag:
		"StringName":
			return _ok(StringName(str(source.get("value", ""))))
		"NodePath":
			return _ok(NodePath(str(source.get("value", ""))))
		"Enum", "Flags":
			var numeric_value: Variant = source.get("value")
			if typeof(numeric_value) != TYPE_INT:
				return _error("invalid_%s_value" % tag)
			return _ok(int(numeric_value))
		"Vector2":
			return _require_numbers(tag, values, 2, func(v: Array) -> Variant: return Vector2(v[0], v[1]))
		"Vector2i":
			return _require_numbers(tag, values, 2, func(v: Array) -> Variant: return Vector2i(v[0], v[1]))
		"Vector3":
			return _require_numbers(tag, values, 3, func(v: Array) -> Variant: return Vector3(v[0], v[1], v[2]))
		"Vector3i":
			return _require_numbers(tag, values, 3, func(v: Array) -> Variant: return Vector3i(v[0], v[1], v[2]))
		"Vector4":
			return _require_numbers(tag, values, 4, func(v: Array) -> Variant: return Vector4(v[0], v[1], v[2], v[3]))
		"Vector4i":
			return _require_numbers(tag, values, 4, func(v: Array) -> Variant: return Vector4i(v[0], v[1], v[2], v[3]))
		"Rect2":
			return _require_numbers(tag, values, 4, func(v: Array) -> Variant: return Rect2(v[0], v[1], v[2], v[3]))
		"Rect2i":
			return _require_numbers(tag, values, 4, func(v: Array) -> Variant: return Rect2i(v[0], v[1], v[2], v[3]))
		"Color":
			return _require_numbers(tag, values, 4, func(v: Array) -> Variant: return Color(v[0], v[1], v[2], v[3]))
		"Plane":
			return _require_numbers(tag, values, 4, func(v: Array) -> Variant: return Plane(v[0], v[1], v[2], v[3]))
		"Quaternion":
			return _require_numbers(tag, values, 4, func(v: Array) -> Variant: return Quaternion(v[0], v[1], v[2], v[3]))
		"AABB":
			return _require_numbers(tag, values, 6, func(v: Array) -> Variant:
				return AABB(Vector3(v[0], v[1], v[2]), Vector3(v[3], v[4], v[5])))
		"Transform2D":
			return _decode_transform2d(values, depth)
		"Basis":
			return _decode_basis(values, depth)
		"Transform3D":
			return _decode_transform3d(source, depth)
		"Projection":
			return _decode_projection(values, depth)
		"PackedByteArray":
			return _ok(PackedByteArray(values))
		"PackedInt32Array":
			return _ok(PackedInt32Array(values))
		"PackedInt64Array":
			return _ok(PackedInt64Array(values))
		"PackedFloat32Array":
			return _ok(PackedFloat32Array(values))
		"PackedFloat64Array":
			return _ok(PackedFloat64Array(values))
		"PackedStringArray":
			return _ok(PackedStringArray(values))
		"PackedVector2Array":
			return _decode_packed(values, depth, TYPE_VECTOR2)
		"PackedVector3Array":
			return _decode_packed(values, depth, TYPE_VECTOR3)
		"PackedColorArray":
			return _decode_packed(values, depth, TYPE_COLOR)
		_:
			return _error("unsupported_variant_tag:%s" % tag)


static func _tag(tag: String, value: Variant) -> Dictionary:
	return { "$type": tag, "value": value }


static func _encode_packed_values(values: Array, depth: int, max_depth: int, max_items: int) -> Array:
	var result: Array = []
	for index in range(mini(values.size(), max_items)):
		result.append(encode(values[index], depth + 1, max_depth, max_items))
	return result


static func _require_numbers(tag: String, values: Array, count: int, factory: Callable) -> Dictionary:
	if values.size() != count:
		return _error("invalid_%s_length" % tag)
	for value in values:
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
			return _error("invalid_%s_component" % tag)
	return _ok(factory.call(values))


static func _decode_transform2d(values: Array, depth: int) -> Dictionary:
	if values.size() != 3:
		return _error("invalid_Transform2D_length")
	var x: Dictionary = _decode(values[0], null, depth + 1)
	var y: Dictionary = _decode(values[1], null, depth + 1)
	var origin: Dictionary = _decode(values[2], null, depth + 1)
	if not bool(x.get("ok", false)) or not bool(y.get("ok", false)) or not bool(origin.get("ok", false)):
		return _error("invalid_Transform2D_component")
	return _ok(Transform2D(x.get("value"), y.get("value"), origin.get("value")))


static func _decode_basis(values: Array, depth: int) -> Dictionary:
	if values.size() != 3:
		return _error("invalid_Basis_length")
	var x: Dictionary = _decode(values[0], null, depth + 1)
	var y: Dictionary = _decode(values[1], null, depth + 1)
	var z: Dictionary = _decode(values[2], null, depth + 1)
	if not bool(x.get("ok", false)) or not bool(y.get("ok", false)) or not bool(z.get("ok", false)):
		return _error("invalid_Basis_component")
	return _ok(Basis(x.get("value"), y.get("value"), z.get("value")))


static func _decode_transform3d(source: Dictionary, depth: int) -> Dictionary:
	var basis: Dictionary = _decode(source.get("basis"), null, depth + 1)
	var origin: Dictionary = _decode(source.get("origin"), null, depth + 1)
	if not bool(basis.get("ok", false)) or not bool(origin.get("ok", false)):
		return _error("invalid_Transform3D_component")
	return _ok(Transform3D(basis.get("value"), origin.get("value")))


static func _decode_projection(values: Array, depth: int) -> Dictionary:
	if values.size() != 4:
		return _error("invalid_Projection_length")
	var columns: Array = []
	for value in values:
		var decoded: Dictionary = _decode(value, null, depth + 1)
		if not bool(decoded.get("ok", false)) or not decoded.get("value") is Vector4:
			return _error("invalid_Projection_component")
		columns.append(decoded.get("value") as Vector4)
	return _ok(Projection(columns[0], columns[1], columns[2], columns[3]))


static func _decode_packed(values: Array, depth: int, expected_type: int) -> Dictionary:
	if values.size() > MAX_COLLECTION_ITEMS:
		return _error("variant_collection_too_large")
	var decoded_values: Array = []
	for value in values:
		var decoded: Dictionary = _decode(value, null, depth + 1)
		if not bool(decoded.get("ok", false)) or typeof(decoded.get("value")) != expected_type:
			return _error("invalid_packed_array_component")
		decoded_values.append(decoded.get("value"))
	match expected_type:
		TYPE_VECTOR2:
			return _ok(PackedVector2Array(decoded_values))
		TYPE_VECTOR3:
			return _ok(PackedVector3Array(decoded_values))
		TYPE_COLOR:
			return _ok(PackedColorArray(decoded_values))
	return _error("unsupported_packed_array_type")


static func get_type_name(value_type: int) -> String:
	match value_type:
		TYPE_NIL:
			return "Nil"
		TYPE_BOOL:
			return "bool"
		TYPE_INT:
			return "int"
		TYPE_FLOAT:
			return "float"
		TYPE_STRING:
			return "String"
		TYPE_VECTOR2:
			return "Vector2"
		TYPE_VECTOR2I:
			return "Vector2i"
		TYPE_RECT2:
			return "Rect2"
		TYPE_RECT2I:
			return "Rect2i"
		TYPE_VECTOR3:
			return "Vector3"
		TYPE_VECTOR3I:
			return "Vector3i"
		TYPE_TRANSFORM2D:
			return "Transform2D"
		TYPE_VECTOR4:
			return "Vector4"
		TYPE_VECTOR4I:
			return "Vector4i"
		TYPE_PLANE:
			return "Plane"
		TYPE_QUATERNION:
			return "Quaternion"
		TYPE_AABB:
			return "AABB"
		TYPE_BASIS:
			return "Basis"
		TYPE_TRANSFORM3D:
			return "Transform3D"
		TYPE_PROJECTION:
			return "Projection"
		TYPE_COLOR:
			return "Color"
		TYPE_STRING_NAME:
			return "StringName"
		TYPE_NODE_PATH:
			return "NodePath"
		TYPE_RID:
			return "RID"
		TYPE_OBJECT:
			return "Object"
		TYPE_CALLABLE:
			return "Callable"
		TYPE_SIGNAL:
			return "Signal"
		TYPE_DICTIONARY:
			return "Dictionary"
		TYPE_ARRAY:
			return "Array"
		TYPE_PACKED_BYTE_ARRAY:
			return "PackedByteArray"
		TYPE_PACKED_INT32_ARRAY:
			return "PackedInt32Array"
		TYPE_PACKED_INT64_ARRAY:
			return "PackedInt64Array"
		TYPE_PACKED_FLOAT32_ARRAY:
			return "PackedFloat32Array"
		TYPE_PACKED_FLOAT64_ARRAY:
			return "PackedFloat64Array"
		TYPE_PACKED_STRING_ARRAY:
			return "PackedStringArray"
		TYPE_PACKED_VECTOR2_ARRAY:
			return "PackedVector2Array"
		TYPE_PACKED_VECTOR3_ARRAY:
			return "PackedVector3Array"
		TYPE_PACKED_COLOR_ARRAY:
			return "PackedColorArray"
	return "VariantType:%d" % value_type


static func _ok(value: Variant) -> Dictionary:
	return { "ok": true, "value": value }


static func _error(message: String) -> Dictionary:
	return { "ok": false, "error": message }
