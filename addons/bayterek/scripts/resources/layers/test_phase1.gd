@tool
extends RefCounted
## Phase 1 smoke test.
## Validates layer creation, state resolution, config helpers,
## and ResourceSaver / ResourceLoader round-trip.

const SAVE_PATH := "user://bayterek_phase1_test.tres"

static func run() -> void:
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

	# Only "normal" is configured -> always returns normal.
	var key: String = layer.get_visual_state(node_states)
	assert(key == "normal")
	var c: Color = layer.get_fill_color_for_state(key)
	assert(c.a > 0.0)

	# Add a hover config; node hovered -> should pick hover.
	layer.set_fill_config("hover", true, Color.RED)
	node_states["hover"] = true
	key = layer.get_visual_state(node_states)
	assert(key == "hover")
	assert(layer.get_fill_color_for_state(key) == Color.RED)

	# Vertices: circle should yield 32 points.
	var verts: PackedVector2Array = layer.get_polygon_vertices(Vector2(100, 100))
	assert(verts.size() == 32)

	# Square: 4 verts.
	layer.shape_type = BayterekShapeLayer.ShapeType.SQUARE
	verts = layer.get_polygon_vertices(Vector2(100, 100))
	assert(verts.size() == 4)

	# Duplicate.
	var copy = layer.duplicate_layer()
	assert(copy is BayterekShapeLayer)
	assert(copy.fill_configs.has("hover"))
	# deep copy: mutating one doesn't touch the other.
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

	# No texture -> should not draw.
	assert(not layer.should_draw_icon("normal"))

	# Assign a 1x1 white texture.
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	layer.set_icon_config("normal", true, tex)
	assert(layer.should_draw_icon("normal"))
	assert(layer.get_icon_for_state("normal") == tex)

	# Tint.
	layer.tint_enabled = true
	layer.set_tint_config("normal", true, Color.RED)
	assert(layer.get_tint_for_state("normal") == Color.RED)

	# Duplicate.
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

	# Add up to 6 layers.
	for i in 6:
		var s := BayterekShapeLayer.new()
		s.layer_name = "L%d" % i
		assert(node.add_layer(s))
	assert(node.get_layer_count() == 6)
	assert(not node.can_add_layer())

	# 7th should fail.
	var extra := BayterekShapeLayer.new()
	assert(not node.add_layer(extra))

	# Remove.
	var removed = node.remove_layer(0)
	assert(removed != null)
	assert(node.get_layer_count() == 5)

	# Move.
	assert(node.move_layer(0, 4))
	assert(node.get_layer(4).layer_name == "L1")

	# Active state resolution.
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

static func _test_prefab_layers() -> bool:
	print("--- Prefab Layers ---")
	var prefab := BayterekPrefab.new()
	prefab.node_name = "Test Prefab"

	var received: Array = []
	var handler := func(_p: BayterekPrefab, change_type: String) -> void:
		received.append(change_type)
	prefab.layers_changed.connect(handler)

	var s1 := BayterekShapeLayer.new()
	prefab.add_layer(s1)
	assert(received.back() == "add")

	prefab.add_layer(BayterekTextureLayer.new())
	assert(received.back() == "add")

	prefab.move_layer(0, 1)
	assert(received.back() == "reorder")

	prefab.remove_layer(0)
	assert(received.back() == "remove")

	prefab.copy_layers_from([s1, BayterekTextureLayer.new()])
	assert(received.back() == "reset")
	assert(prefab.get_layer_count() == 2)

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