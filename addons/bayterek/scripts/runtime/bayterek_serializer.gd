@tool
extends Node
## Autoload: BayterekSerializer
## Saves and loads runtime allocation state for a tree.
##
## Format (binary, user://):
##   uint32  - SAVE_FORMAT_VERSION (serializer schema version)
##   uint32  - tree state version (BayterekTree.version)
##   Variant - allocated_nodes (Array[int])
##   Variant - allocation_level (Dictionary[int, int])
##
## Save path: user://bayterek_v2/<tree_uid>.tree
## Legacy:    user://bayterek/<tree_uid>.tree (migrated on load)
##
## TEST MODE:
##   Set `test_mode = true` to allow save/load from the editor. This is
##   used by the automated test suite (test_serializer.gd) which runs
##   inside an EditorScript and would otherwise be blocked by the
##   `Engine.is_editor_hint()` guard.

const OLD_SAVE_PATH := "user://bayterek"
const SAVE_PATH := "user://bayterek_v2"

## Serializer schema version — bump this when the binary layout changes.
##   1 = legacy (no header, no allocation_level)
##   2 = current (header + allocation_level)
const SAVE_FORMAT_VERSION := 2

## When true, the editor-hint guard is bypassed. Only tests should set
## this — production callers rely on the guard to prevent accidental
## writes from the editor.
var test_mode: bool = false

# ============================================================
# SAVE
# ============================================================

func save_tree_state(tree: BayterekTree, custom_path: String = "") -> void:
	if not test_mode and Engine.is_editor_hint():
		return
	if not tree:
		push_error("BayterekSerializer: tree is null")
		return
	if not tree.tree_state:
		push_error("BayterekSerializer: tree.tree_state is null")
		return

	DirAccess.make_dir_recursive_absolute(SAVE_PATH)

	var uid: String = _get_tree_uid(tree)
	if uid.is_empty():
		push_error("BayterekSerializer: could not resolve UID for %s" % tree.resource_path)
		return

	# Remove legacy save if it exists
	var old_path: String = "%s/%s.tree" % [OLD_SAVE_PATH, uid]
	if FileAccess.file_exists(old_path):
		DirAccess.remove_absolute(old_path)

	var save_path: String = custom_path
	if save_path.is_empty():
		save_path = "%s/%s.tree" % [SAVE_PATH, uid]

	# Ensure the parent directory exists (custom_path might point
	# somewhere other than SAVE_PATH).
	var parent_dir: String = save_path.get_base_dir()
	if not parent_dir.is_empty() and not DirAccess.dir_exists_absolute(parent_dir):
		DirAccess.make_dir_recursive_absolute(parent_dir)

	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_error("BayterekSerializer: could not open %s for writing (err=%d)" % [save_path, FileAccess.get_open_error()])
		return

	# Header
	file.store_32(SAVE_FORMAT_VERSION)
	file.store_32(tree.tree_state.version)

	# Payload
	file.store_var(tree.tree_state.allocated_nodes)
	file.store_var(tree.tree_state.allocation_level)

	file.close()

	print("BayterekSerializer: saved → ", save_path)

# ============================================================
# LOAD
# ============================================================

func load_tree_state(tree: BayterekTree, custom_path: String = "") -> void:
	if not test_mode and Engine.is_editor_hint():
		return
	if not tree:
		push_error("BayterekSerializer: tree is null")
		return
	if not tree.tree_state:
		tree.tree_state = BayterekTreeState.new()

	DirAccess.make_dir_recursive_absolute(SAVE_PATH)

	var uid: String = _get_tree_uid(tree)
	if uid.is_empty():
		return

	# Check for legacy save first
	var old_path: String = "%s/%s.tree" % [OLD_SAVE_PATH, uid]
	if FileAccess.file_exists(old_path):
		_migrate_old_save(tree, old_path)
		return

	var save_path: String = custom_path
	if save_path.is_empty():
		save_path = "%s/%s.tree" % [SAVE_PATH, uid]

	if not FileAccess.file_exists(save_path):
		return

	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		push_error("BayterekSerializer: could not open %s for reading (err=%d)" % [save_path, FileAccess.get_open_error()])
		return

	var saved_format: int = file.get_32()

	# Legacy v1 saves had NO format header, so the first value they wrote
	# was the *tree state version*. We must detect that and shift.
	if saved_format > SAVE_FORMAT_VERSION:
		file.seek(0)
		saved_format = 1

	tree.tree_state.version = file.get_32()
	tree.tree_state.allocated_nodes = file.get_var()

	if saved_format >= 2:
		var levels = file.get_var()
		if levels is Dictionary:
			tree.tree_state.allocation_level = levels

	file.close()

	print("BayterekSerializer: loaded ← ", save_path, " (format v%d)" % saved_format)

# ============================================================
# MIGRATION (legacy -> v2)
# ============================================================

func _migrate_old_save(tree: BayterekTree, old_save_path: String) -> void:
	var file := FileAccess.open(old_save_path, FileAccess.READ)
	if not file:
		return

	tree.tree_state.version = file.get_32()
	tree.tree_state.allocated_nodes = file.get_var()
	tree.tree_state.allocation_level = {}

	file.close()
	DirAccess.remove_absolute(old_save_path)

	save_tree_state(tree)

# ============================================================
# DELETE
# ============================================================

func delete_tree_state(tree: BayterekTree, custom_path: String = "") -> bool:
	if not test_mode and Engine.is_editor_hint():
		return false
	if not tree:
		return false

	var uid: String = _get_tree_uid(tree)
	if uid.is_empty():
		return false

	var save_path: String = custom_path
	if save_path.is_empty():
		save_path = "%s/%s.tree" % [SAVE_PATH, uid]

	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
		return true
	return false

func has_save(tree: BayterekTree, custom_path: String = "") -> bool:
	if not tree:
		return false

	var uid: String = _get_tree_uid(tree)
	if uid.is_empty():
		return false

	var save_path: String = custom_path
	if save_path.is_empty():
		save_path = "%s/%s.tree" % [SAVE_PATH, uid]

	return FileAccess.file_exists(save_path)

# ============================================================
# PRIVATE
# ============================================================

## Resolves a stable identifier for a tree. Tries, in order:
##   1. The Godot-assigned UID (res:// only).
##   2. The tree's `id` field (human-readable slug).
##   3. A deterministic hash of the resource_path.
##
## Returns "" only if the tree has no path AND no id — in which case
## there is no stable identifier to key the save file on.
func _get_tree_uid(tree: BayterekTree) -> String:
	# Preferred: real Godot UID (only valid for res:// files).
	if not tree.resource_path.is_empty():
		var uid_int: int = ResourceLoader.get_resource_uid(tree.resource_path)
		if uid_int != ResourceUID.INVALID_ID:
			return str(uid_int)

	# Fallback: the tree's own id (set by the editor on creation).
	if not tree.id.is_empty():
		return "id_" + tree.id

	# Last resort: deterministic hash of the resource path.
	if not tree.resource_path.is_empty():
		return "path_" + str(hash(tree.resource_path))

	return ""