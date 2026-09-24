@tool
extends RefCounted
## Serializer round-trip test.
## Validates that tree state (allocated_nodes + allocation_level) is
## correctly saved to disk and loaded back.
##
## The serializer normally refuses to save/load from the editor. We flip
## `test_mode` on the autoload for the duration of the run so the tests
## can exercise the real code paths.

const FIXTURE_DIR := "res://addons/bayterek/test_fixtures"
const TREE_PATH := "res://addons/bayterek/test_fixtures/serializer_test_tree.tres"
const SAVE_PATH := "user://bayterek_serializer_test.tree"

static func run() -> bool:
	print("=== Bayterek Serializer Test ===")
	var ok: bool = true

	var serializer = _get_serializer()
	if not serializer:
		push_error("Serializer autoload not found. Enable the plugin.")
		return false

	# Enable test mode for the duration of the run.
	serializer.test_mode = true

	_prepare_fixture_dir()
	_prepare_tree_resource()

	ok = _test_save_load_roundtrip() and ok
	ok = _test_multiallocation_levels() and ok
	ok = _test_delete_and_has_save() and ok

	if ok:
		print("=== ALL SERIALIZER TESTS PASSED ===")
	else:
		push_error("=== SOME SERIALIZER TESTS FAILED ===")

	_cleanup()

	# Restore production behaviour.
	serializer.test_mode = false

	return ok

# ============================================================
# FIXTURE SETUP / TEARDOWN
# ============================================================

static func _prepare_fixture_dir() -> void:
	if not DirAccess.dir_exists_absolute(FIXTURE_DIR):
		DirAccess.make_dir_recursive_absolute(FIXTURE_DIR)

## Creates a minimal BayterekTree .tres under res:// with a stable id.
static func _prepare_tree_resource() -> void:
	if FileAccess.file_exists(TREE_PATH):
		DirAccess.remove_absolute(TREE_PATH)

	var tree := BayterekTree.new()
	tree.name = "SerializerTestTree"
	tree.id = "serializer_test_fixture"
	tree.tree_state = BayterekTreeState.new()

	var err: Error = ResourceSaver.save(tree, TREE_PATH)
	if err != OK:
		push_error("Could not create test tree fixture (%d)" % err)
		return

	EditorInterface.get_resource_filesystem().scan()

## Deletes physical files, then asks the editor to re-scan so that the
## resource cache evicts the entry for the deleted .tres. Without this
## second step, Godot's resource loader trips over a missing file on
## the next idle frame (`resource_format_text.cpp:1587`).
static func _cleanup() -> void:
	# Delete physical files first.
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

	if FileAccess.file_exists(TREE_PATH):
		DirAccess.remove_absolute(TREE_PATH)

	var uid_path: String = TREE_PATH + ".uid"
	if FileAccess.file_exists(uid_path):
		DirAccess.remove_absolute(uid_path)

	if DirAccess.dir_exists_absolute(FIXTURE_DIR):
		var files: PackedStringArray = DirAccess.get_files_at(FIXTURE_DIR)
		if files.is_empty():
			DirAccess.remove_absolute(FIXTURE_DIR)

	# Then ask the editor to re-scan. This evicts the cached entry
	# for the deleted .tres so the next idle frame doesn't crash.
	EditorInterface.get_resource_filesystem().scan()

# ============================================================
# ROUND-TRIP
# ============================================================

static func _test_save_load_roundtrip() -> bool:
	print("--- Save / Load round-trip ---")

	var serializer = _get_serializer()
	if not serializer:
		push_error("  Serializer autoload not found. Enable the plugin.")
		return false

	var tree: BayterekTree = _load_fixture()
	if not tree:
		return false

	tree.tree_state = BayterekTreeState.new()
	tree.tree_state.version = 5
	tree.tree_state.allocated_nodes = [1, 2, 3, 7, 42]
	tree.tree_state.allocation_level = {1: 1, 2: 3, 7: 2}

	serializer.call("save_tree_state", tree, SAVE_PATH)

	if not FileAccess.file_exists(SAVE_PATH):
		push_error("  Save file not created: %s" % SAVE_PATH)
		return false

	var loaded: BayterekTree = _load_fixture()
	if not loaded:
		return false
	loaded.tree_state = BayterekTreeState.new()

	serializer.call("load_tree_state", loaded, SAVE_PATH)

	assert(loaded.tree_state.allocated_nodes == [1, 2, 3, 7, 42])
	assert(loaded.tree_state.allocation_level == {1: 1, 2: 3, 7: 2})
	assert(loaded.tree_state.version == 5)

	print("  round-trip OK")
	return true

static func _test_multiallocation_levels() -> bool:
	print("--- Multi-allocation levels ---")

	var serializer = _get_serializer()
	if not serializer:
		return false

	var tree: BayterekTree = _load_fixture()
	if not tree:
		return false

	tree.tree_state = BayterekTreeState.new()
	tree.tree_state.version = 1
	tree.tree_state.allocated_nodes = [5, 6]
	tree.tree_state.allocation_level = {5: 2, 6: 4}

	serializer.call("save_tree_state", tree, SAVE_PATH)

	var loaded: BayterekTree = _load_fixture()
	if not loaded:
		return false
	loaded.tree_state = BayterekTreeState.new()

	serializer.call("load_tree_state", loaded, SAVE_PATH)

	assert(loaded.tree_state.allocation_level[5] == 2)
	assert(loaded.tree_state.allocation_level[6] == 4)

	print("  levels OK")
	return true

static func _test_delete_and_has_save() -> bool:
	print("--- Delete / has_save ---")

	var serializer = _get_serializer()
	if not serializer:
		return false

	var tree: BayterekTree = _load_fixture()
	if not tree:
		return false

	tree.tree_state = BayterekTreeState.new()

	serializer.call("save_tree_state", tree, SAVE_PATH)
	assert(serializer.call("has_save", tree, SAVE_PATH) == true)

	var deleted: bool = serializer.call("delete_tree_state", tree, SAVE_PATH)
	assert(deleted == true)
	assert(serializer.call("has_save", tree, SAVE_PATH) == false)

	assert(serializer.call("delete_tree_state", tree, SAVE_PATH) == false)

	print("  delete / has_save OK")
	return true

# ============================================================
# HELPERS
# ============================================================

static func _get_serializer() -> Node:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var root := (main_loop as SceneTree).root
		if root:
			return root.get_node_or_null("BayterekSerializer")
	return null

static func _load_fixture() -> BayterekTree:
	var tree: BayterekTree = ResourceLoader.load(TREE_PATH, "BayterekTree", ResourceLoader.CACHE_MODE_IGNORE)
	if not tree:
		push_error("  Could not load fixture: %s" % TREE_PATH)
		return null
	tree.resource_path = TREE_PATH
	if tree.id.is_empty():
		tree.id = "serializer_test_fixture"
	return tree