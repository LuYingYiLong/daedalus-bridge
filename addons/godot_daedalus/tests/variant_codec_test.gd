extends SceneTree

const CODEC: GDScript = preload("res://addons/godot_daedalus/scripts/controllers/daedalus_variant_codec.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_round_trip("Vector2", Vector2(1.25, -3.5))
	_round_trip("Vector3i", Vector3i(1, 2, 3))
	_round_trip("Vector4", Vector4(1, 2, 3, 4))
	_round_trip("Rect2", Rect2(1, 2, 3, 4))
	_round_trip("Transform2D", Transform2D(0.25, Vector2(3, 4)))
	_round_trip("Basis", Basis.from_euler(Vector3(0.1, 0.2, 0.3)))
	_round_trip("Transform3D", Transform3D(Basis.IDENTITY, Vector3(4, 5, 6)))
	_round_trip("Quaternion", Quaternion.from_euler(Vector3(0.1, 0.2, 0.3)))
	_round_trip("Plane", Plane(Vector3.UP, 2.0))
	_round_trip("AABB", AABB(Vector3.ONE, Vector3(2, 3, 4)))
	_round_trip("Projection", Projection.IDENTITY)
	_round_trip("Color", Color(0.1, 0.2, 0.3, 0.4))
	_round_trip("NodePath", NodePath("Root/Child"))
	_round_trip("StringName", StringName("Player"))
	_round_trip("PackedByteArray", PackedByteArray([1, 2, 255]))
	_round_trip("PackedVector2Array", PackedVector2Array([Vector2.ONE, Vector2(2, 3)]))
	_round_trip("Dictionary", { "nested": [Vector2i(3, 4), { "ok": true }] })

	_expect(CODEC.is_safe_resource_path("res://assets/player.tres"), "safe res:// path rejected")
	_expect(not CODEC.is_safe_resource_path("res://../outside.tres"), "path traversal accepted")
	_expect(not CODEC.is_safe_resource_path("user://secret.tres"), "user:// path accepted")
	_expect(not CODEC.is_safe_resource_path("res://.godot/imported/file.ctex"), ".godot path accepted")
	_expect(
		not CODEC.is_safe_resource_path("res://addons/godot_daedalus/plugin.cfg"),
		"plugin write path accepted"
	)
	_expect(
		bool(CODEC.decode({ "$type": "Opaque", "godotType": "RID" }).get("ok", true)) == false,
		"opaque payload became writable"
	)
	_expect(
		bool(CODEC.decode({ "$type": "UnknownVariant", "value": [] }).get("ok", true)) == false,
		"unknown variant tag was accepted"
	)

	if failures.is_empty():
		print("variant_codec_test: PASS")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _round_trip(label: String, value: Variant) -> void:
	var encoded: Variant = CODEC.encode(value, 0, 8, 10_000)
	var decoded: Dictionary = CODEC.decode(encoded, value)
	_expect(bool(decoded.get("ok", false)), "%s failed to decode: %s" % [label, decoded])
	if bool(decoded.get("ok", false)):
		_expect(decoded.get("value") == value, "%s changed during round trip" % label)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
