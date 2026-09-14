@tool
extends Node
## Autoload: BayterekSerializer
## Saves and loads runtime allocation state for a tree.
##
## Format (binary, user://):
##   uint32  - plugin version at save time
##   uint32  - tree state version
##   Variant - allocated_nodes (Array[int])
##   Variant - allocation_level (Dictionary[int, int])
##
## Save path: user://bayterek_v2/<tree_uid>.tree
## Legacy:    user://bayterek/<tree_uid>.tree (migrated on load)

const OLD_SAVE_PATH := "user://bayterek"
const SAVE_PATH := "user://bayterek_v2"

# ============================================================
# SAVE
# ============================================================

func save_tree_state(tree: BayterekTree, custom_path: String = "") -> void:
	if Engine.is_editor_hint():
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

	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_error("BayterekSerializer: could not open %s for writing (err=%d)" % [save_path, FileAccess.get_open_error()])
		return

	# Header
	file.store_32(Bayterek.get_version_number())
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
	if Engine.is_editor_hint():
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

	var saved_version: int = file.get_32()
	tree.tree_state.version = file.get_32()
	tree.tree_state.allocated_nodes = file.get_var()

	# allocation_level was added in v2.0.0
	if saved_version >= Bayterek.get_version_number("2.0.0"):
		var levels = file.get_var()
		if levels is Dictionary:
			tree.tree_state.allocation_level = levels

	file.close()

	print("BayterekSerializer: loaded ← ", save_path)

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

	# Re-save in new format
	save_tree_state(tree)

# ============================================================
# DELETE
# ============================================================

## Deletes the save file for a tree.
## Returns true if a file was deleted, false otherwise.
func delete_tree_state(tree: BayterekTree, custom_path: String = "") -> bool:
	if Engine.is_editor_hint():
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

## Checks if a save file exists for a tree.
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

func _get_tree_uid(tree: BayterekTree) -> String:
	if tree.resource_path.is_empty():
		return ""
	var uid_int: int = ResourceLoader.get_resource_uid(tree.resource_path)
	if uid_int == ResourceUID.INVALID_ID:
		return ""
	return str(uid_int)