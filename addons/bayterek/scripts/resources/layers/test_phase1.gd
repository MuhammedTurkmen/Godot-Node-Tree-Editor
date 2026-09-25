@tool
extends EditorScript
## Master test runner + Phase 1 layer tests.
##
## Call `run_all()` to execute every Bayterek test suite and see a
## summary table at the end.
##
## Call `run()` for the legacy behaviour (Phase 1 tests only).

const SAVE_PATH := "user://bayterek_phase1_test.tres"

# ============================================================
# EDITOR SCRIPT ENTRY POINT
# ============================================================

## Called by the editor when the user runs this script (Ctrl+Shift+X).
func _run() -> void:
	run_all()

# ============================================================
# MASTER RUNNER
# ============================================================

static func run_all() -> void:
	print("")
	print("╔══════════════════════════════════════════════════╗")
	print("║   Bayterek Test Suite — Full Run                 ║")
	print("╚══════════════════════════════════════════════════╝")
	print("")

	var results: Dictionary = {}

	results["Phase 1 (layers)"] = _run_phase1()
	results["Allocation"] = _run_allocation()
	results["Serializer"] = _run_serializer()
	results["Prefab"] = _run_prefab()
	results["Copy/Paste"] = _run_copy_paste()

	print("")
	print("╔══════════════════════════════════════════════════╗")
	print("║   Summary                                        ║")
	print("╚══════════════════════════════════════════════════╝")

	var all_ok: bool = true
	for name in results.keys():
		var ok: bool = results[name]
		var marker: String = "✓ PASS" if ok else "✗ FAIL"
		print("  %s  %s" % [marker, name])
		if not ok:
			all_ok = false

	if all_ok:
		print("")
		print("🎉  ALL TESTS PASSED  🎉")
	else:
		push_error("Some tests failed — see above.")

	# Clean up test artifacts so the editor's resource cache doesn't
	# trip over a missing file on the next idle frame.
	_cleanup_test_files()

# ============================================================
# CLEANUP
# ============================================================

## Removes temporary files created by the test suite and asks the
## editor to re-scan so its resource cache evicts stale entries.
static func _cleanup_test_files() -> void:
	# Phase 1 round-trip file.
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

	# UID sidecar if it was created.
	var uid_path: String = SAVE_PATH + ".uid"
	if FileAccess.file_exists(uid_path):
		DirAccess.remove_absolute(uid_path)

	# Serializer test fixture (created by test_serializer.gd).
	var serializer_tree := "res://addons/bayterek/test_fixtures/serializer_test_tree.tres"
	if FileAccess.file_exists(serializer_tree):
		DirAccess.remove_absolute(serializer_tree)
	var serializer_uid: String = serializer_tree + ".uid"
	if FileAccess.file_exists(serializer_uid):
		DirAccess.remove_absolute(serializer_uid)

	# Serializer save file.
	var serializer_save := "user://bayterek_serializer_test.tree"
	if FileAccess.file_exists(serializer_save):
		DirAccess.remove_absolute(serializer_save)

	# Ask the editor to re-scan so its cache forgets the deleted .tres.
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()

# ============================================================
# SUB RUNNERS
# ============================================================

static func _run_phase1() -> bool:
	return _run_phase1_internal()

static func _run_allocation() -> bool:
	var Test = load("res://addons/bayterek/scripts/resources/layers/test_allocation.gd")
	if not Test:
		push_error("Could not load test_allocation.gd")
		return false
	return Test.run() as bool

static func _run_serializer() -> bool:
	var Test = load("res://addons/bayterek/scripts/runtime/test_serializer.gd")
	if not Test:
		push_error("Could not load test_serializer.gd")
		return false
	return Test.run() as bool

static func _run_prefab() -> bool:
	var Test = load("res://addons/bayterek/scripts/shared/test_prefab.gd")
	if not Test:
		push_error("Could not load test_prefab.gd")
		return false
	return Test.run() as bool

static func _run_copy_paste() -> bool:
	var Test = load("res://addons/bayterek/scripts/editor/test_copy_paste.gd")
	if not Test:
		push_error("Could not load test_copy_paste.gd")
		return false
	return Test.run() as bool

# ============================================================
# LEGACY ENTRY POINT
# ============================================================

## Old entry point — runs the master suite.
static func run() -> void:
	run_all()

# ============================================================
# PHASE 1 (layer tests) — returns overall pass/fail
# ============================================================

static func _run_phase1_internal() -> bool:
	print("=== Bayterek Phase 1 Test ===")
	var ok: bool = true

	ok = _test_transform() and ok
	ok = _test_shape_layer() and ok
	ok = _test_texture_layer() and ok
	ok = _test_node_layers() and ok
	ok = _test_prefab_layers() and ok
	ok = _test_round_trip() and ok

	if ok:
		print("=== ALL TESTS PASSED ===")
	else:
		push_error("=== SOME TESTS FAILED ===")

	return ok

# ============================================================
# TRANSFORM
# ============================================================

static func _test_transform() -> bool:
	print("--- Transform ---")
	var t := BayterekLayerTransform.new()
	t.position = Vector2(20, 10)
	t.size = Vector2(50, 50)
	t.rotation = 45.0
	t.pivot_mode = BayterekLayerTransform.PivotMode.CENTER

	var design := Vector2(100, 100)
	var m: Transform2D = t.get_matrix(design)
	assert(m is Transform2D)

	var pivot_px: Vector2 = t.get_pivot_px(t.get_effective_size(design))
	assert(pivot_px == Vector2(25, 25))

	t.pivot_mode = BayterekLayerTransform.PivotMode.TOP_LEFT
	assert(t.get_normalized_pivot() == Vector2(0, 0))

	t.pivot_mode = BayterekLayerTransform.PivotMode.CUSTOM
	t.pivot = Vector2(0.25, 0.75)
	assert(t.get_normalized_pivot() == Vector2(0.25, 0.75))

	var copy: BayterekLayerTransform = t.duplicate_transform()
	assert(copy.pivot == t.pivot)

	print("  transform OK")
	return true

# ============================================================
# SHAPE LAYER
# ============================================================

static func _test_shape_layer() -> bool:
	print("--- Shape Layer ---")
	var layer := BayterekShapeLayer.new()
	assert(layer.shape_type == BayterekShapeLayer.ShapeType.CIRCLE)
	assert(layer.fill_enabled)
	assert(layer.fill_configs.has("normal"))

	var node_states := {
		"normal": true, "hover": false, "locked": false,
		"preallocated": false, "prerefund": false, "max_level": false,
		"allocateable": false, "not_allocateable": false,
	}

	var key: String = layer.get_visual_state(node_states)
	assert(key == "normal")
	var c: Color = layer.get_fill_color_for_state(key)
	assert(c.a > 0.0)

	layer.set_fill_config("hover", true, Color.RED)
	node_states["hover"] = true
	key = layer.get_visual_state(node_states)
	assert(key == "hover")
	assert(layer.get_fill_color_for_state(key) == Color.RED)

	# Circle polygon: segment count comes from Bayterek.CIRCLE_SEGMENTS.
	var verts: PackedVector2Array = layer.get_polygon_vertices(Vector2(100, 100))
	assert(verts.size() == Bayterek.CIRCLE_SEGMENTS)

	# Square: exactly 4 corners (no corner radius by default).
	layer.shape_type = BayterekShapeLayer.ShapeType.SQUARE
	layer.corner_radius = 0.0
	verts = layer.get_polygon_vertices(Vector2(100, 100))
	assert(verts.size() == 4)

	# Duplicate deep-copies fill_configs.
	var copy = layer.duplicate_layer()
	assert(copy is BayterekShapeLayer)
	assert(copy.fill_configs.has("hover"))
	copy.fill_configs["hover"]["color"] = Color.BLUE
	assert(layer.fill_configs["hover"]["color"] == Color.RED)

	print("  shape layer OK")
	return true

# ============================================================
# TEXTURE LAYER
# ============================================================

static func _test_texture_layer() -> bool:
	print("--- Texture Layer ---")
	var layer := BayterekTextureLayer.new()
	assert(layer.icon_enabled)
	assert(layer.icon_configs.has("normal"))

	assert(not layer.should_draw_icon("normal"))

	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	layer.set_icon_config("normal", true, tex)
	assert(layer.should_draw_icon("normal"))
	assert(layer.get_icon_for_state("normal") == tex)

	layer.tint_enabled = true
	layer.set_tint_config("normal", true, Color.RED)
	assert(layer.get_tint_for_state("normal") == Color.RED)

	var copy = layer.duplicate_layer()
	assert(copy is BayterekTextureLayer)
	assert(copy.icon_configs["normal"]["texture"] == tex)

	print("  texture layer OK")
	return true

# ============================================================
# NODE LAYERS
# ============================================================

static func _test_node_layers() -> bool:
	print("--- Node Layers ---")
	var node := BayterekNode.new()
	assert(node.design_size == Vector2(100, 100))
	assert(node.scale == Vector2.ONE)
	assert(node.get_layer_count() == 0)

	for i in 6:
		var s := BayterekShapeLayer.new()
		s.layer_name = "L%d" % i
		assert(node.add_layer(s))
	assert(node.get_layer_count() == 6)
	assert(not node.can_add_layer())

	var extra := BayterekShapeLayer.new()
	assert(not node.add_layer(extra))

	var removed = node.remove_layer(0)
	assert(removed != null)
	assert(node.get_layer_count() == 5)

	assert(node.move_layer(0, 4))
	assert(node.get_layer(4).layer_name == "L1")

	var flags := {
		"is_hovered": true,
		"allocated": false,
		"preallocated": false,
		"refund": false,
		"allocation_level": 0,
		"is_allocatable": true,
	}
	var states: Dictionary = node.resolve_active_states(flags)
	assert(states["hover"] == true)
	assert(states["allocateable"] == true)
	assert(states["not_allocateable"] == false)
	assert(states["normal"] == false)

	flags["is_hovered"] = false
	states = node.resolve_active_states(flags)
	assert(states["hover"] == false)
	assert(states["allocateable"] == true)
	assert(states["normal"] == false)

	flags["allocated"] = true
	flags["is_allocatable"] = false
	states = node.resolve_active_states(flags)
	assert(states["allocateable"] == false)
	assert(states["normal"] == true)

	print("  node layers OK")
	return true

# ============================================================
# PREFAB LAYERS
# ============================================================
# NOTE: BayterekPrefab does NOT emit `layers_changed` — that signal
# lives on BayterekNodeDesign. This test verifies the prefab's
# attribute side effects instead.

static func _test_prefab_layers() -> bool:
	print("--- Prefab Layers ---")
	var prefab := BayterekPrefab.new()
	prefab.node_name = "Test Prefab"

	var received: Array = []
	var handler := func(_p: BayterekPrefab, attribute_id: String, removed: bool) -> void:
		received.append({"id": attribute_id, "removed": removed})
	prefab.attribute_changed.connect(handler)

	prefab.set_attribute("strength", [10, 20])
	assert(received.size() == 1)
	assert(received.back()["id"] == "strength")
	assert(received.back()["removed"] == false)

	prefab.set_attribute("agility", [5, 10])
	assert(received.size() == 2)

	prefab.remove_attribute("strength")
	assert(received.size() == 3)
	assert(received.back()["removed"] == true)
	assert(not prefab.attributes.has("strength"))
	assert(prefab.attributes.has("agility"))

	prefab.attributes["agility"] = [7, 14]
	assert(prefab.attributes["agility"] == [7, 14])

	print("  prefab layers OK")
	return true

# ============================================================
# ROUND-TRIP
# ============================================================

static func _test_round_trip() -> bool:
	print("--- Round-trip ---")
	var node := BayterekNode.new()
	node.name = "RT Node"
	node.id = 42
	node.design_size = Vector2(200, 200)
	node.scale = Vector2(0.5, 0.5)

	var shape := BayterekShapeLayer.new()
	shape.layer_name = "Background"
	shape.shape_type = BayterekShapeLayer.ShapeType.HEXAGON
	shape.set_fill_config("hover", true, Color(1, 0.5, 0.2, 1.0))
	shape.transform.position = Vector2(15, -5)
	shape.transform.rotation = 30.0
	node.add_layer(shape)

	var tex_layer := BayterekTextureLayer.new()
	tex_layer.layer_name = "Icon"
	tex_layer.tint_enabled = true
	tex_layer.set_tint_config("normal", true, Color(0.5, 0.5, 0.5, 1.0))
	node.add_layer(tex_layer)

	var save_err: Error = ResourceSaver.save(node, SAVE_PATH)
	if save_err != OK:
		push_error("Save failed: %d" % save_err)
		return false

	var loaded = ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not loaded is BayterekNode:
		push_error("Load failed or wrong type.")
		return false

	var n: BayterekNode = loaded
	assert(n.design_size == Vector2(200, 200))
	assert(n.scale == Vector2(0.5, 0.5))
	assert(n.get_layer_count() == 2)

	var l0 = n.get_layer(0)
	assert(l0 is BayterekShapeLayer)
	assert(l0.layer_name == "Background")
	assert(l0.shape_type == BayterekShapeLayer.ShapeType.HEXAGON)
	assert(l0.fill_configs.has("hover"))
	var hc: Color = l0.fill_configs["hover"]["color"]
	assert(is_equal_approx(hc.r, 1.0) and is_equal_approx(hc.g, 0.5))
	assert(l0.transform.rotation == 30.0)

	var l1 = n.get_layer(1)
	assert(l1 is BayterekTextureLayer)
	assert(l1.tint_enabled)
	var tc: Color = l1.tint_configs["normal"]["color"]
	assert(is_equal_approx(tc.r, 0.5))

	print("  round-trip OK (saved to %s)" % SAVE_PATH)
	return true