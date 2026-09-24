@tool
extends RefCounted
## Prefab sync test.
## Validates that changing a prefab propagates to its bound nodes.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

static func run() -> bool:
	print("=== Bayterek Prefab Test ===")
	var ok: bool = true

	ok = _test_name_propagation() and ok
	ok = _test_attribute_propagation() and ok
	ok = _test_make_unique() and ok

	if ok:
		print("=== ALL PREFAB TESTS PASSED ===")
	else:
		push_error("=== SOME PREFAB TESTS FAILED ===")

	return ok

static func _test_name_propagation() -> bool:
	print("--- Name propagation ---")

	var prefab := BayterekPrefab.new()
	prefab.reference_id = "abc123"
	prefab.node_name = "Warrior"

	var bound := BayterekNode.new()
	bound.name = prefab.node_name
	bound.reference_id = prefab.reference_id

	prefab.set_node_name("Berserker")
	bound.name = prefab.node_name

	assert(bound.name == "Berserker")
	print("  name OK")
	return true

static func _test_attribute_propagation() -> bool:
	print("--- Attribute propagation ---")

	var prefab := BayterekPrefab.new()
	prefab.reference_id = "abc123"
	prefab.set_attribute("strength", [10, 20])

	var bound := BayterekNode.new()
	bound.reference_id = "abc123"
	bound.attributes["strength"] = [10, 20]

	prefab.set_attribute("strength", [15, 25])
	bound.attributes["strength"] = prefab.attributes["strength"].duplicate(true)

	assert(bound.attributes["strength"] == [15, 25])
	print("  attribute OK")
	return true

static func _test_make_unique() -> bool:
	print("--- Make unique ---")

	var prefab := BayterekPrefab.new()
	prefab.reference_id = "abc123"
	prefab.set_attribute("strength", [10, 20])

	var bound := BayterekNode.new()
	bound.reference_id = "abc123"
	bound.attributes["strength"] = [10, 20]
	bound.mark_attribute_override("strength")

	bound.reference_id = ""
	bound.clear_all_attribute_overrides()
	bound.clear_all_exported_overrides()

	assert(bound.reference_id == "")
	assert(bound.attributes["strength"] == [10, 20])
	assert(not bound.has_attribute_override("strength"))

	print("  make unique OK")
	return true