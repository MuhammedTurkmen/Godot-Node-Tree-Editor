@tool
class_name Bayterek
extends RefCounted
## Global constants and helper functions.

const VERSION := "0.1.0"

const ROOT_PATH_SETTING := "addons/bayterek/root_path"
const DEFAULT_ROOT_PATH := "res://data/bayterek"
const REGISTRY_FILENAME_SETTING := "addons/bayterek/registry_filename"
const DEFAULT_REGISTRY_FILENAME := "registry.tres"

## Enables verbose (debug-level) logging across the plugin.
## Controlled via Project Settings → Addons → Bayterek → Verbose.
const VERBOSE_SETTING := "addons/bayterek/verbose"
const DEFAULT_VERBOSE := false

# --- Design system ---
const DESIGNS_DIR_NAME := "designs"
const DESIGNS_REGISTRY_FILENAME := "designs_registry.tres"

const ICON_THEME := &"EditorIcons"
const GROUP_ICON := "Folder"
const TREE_ICON := "KeyValue"
const DESIGN_ICON := "PackedScene"

const BlankIcon: Texture2D = null

# --- Editor canvas grid ---
const GRID_CELL_SIZE := Vector2(16, 16)
const GRID_PRIMARY_STEP := 4
const GRID_LINE_COLOR := Color(1, 1, 1, 0.12)
const GRID_LINE_WIDTH := 1.0
const DEFAULT_TREE_SIZE := Vector2(5000, 5000)

# ============================================================
# RENDER / SHAPE CONSTANTS
# ============================================================

## Number of segments used to smooth each rounded corner of a polygon.
## Higher = smoother, slower. Applied to every corner of every shape.
const CORNER_SEGMENTS := 20

## Maximum corner radius as a fraction of min(width, height) / 2.
## 0.99 = almost a full circle for the corner geometry.
const CORNER_RADIUS_CLAMP_FACTOR := 0.99

## Number of segments used to approximate a full circle shape.
const CIRCLE_SEGMENTS := 48

# ============================================================
# NODE VISUAL CONSTANTS
# ============================================================

const CROWN_FONT_SIZE := 18
const CROWN_COLOR := Color(1.0, 0.85, 0.35)
const CROWN_OUTLINE_COLOR := Color(0, 0, 0, 0.9)
const CROWN_OUTLINE_SIZE := 2

const SELECTION_BORDER_COLOR := Color(1, 0.6, 0.1, 1)
const SELECTION_BORDER_WIDTH := 2
const SELECTION_BORDER_RADIUS := 2
const SELECTION_BORDER_OFFSET := 3

# ============================================================
# CAMERA CONSTANTS
# ============================================================

const CAMERA_MIN_ZOOM := 0.4
const CAMERA_MAX_ZOOM := 3.0
const CAMERA_ZOOM_STEP := 0.1

# ============================================================
# LAYER PREVIEW CONSTANTS (Node Editor)
# ============================================================

const PREVIEW_MARGIN := 20.0
const PREVIEW_MIN_USER_ZOOM := 0.1
const PREVIEW_MAX_USER_ZOOM := 8.0
const PREVIEW_ZOOM_STEP := 1.15

# ============================================================
# PREFAB BAR CONSTANTS
# ============================================================

const PREFABS_BAR_COLLAPSED_HEIGHT := 28
const PREFABS_BAR_EXPANDED_HEIGHT := 120

const PREFAB_CARD_WIDTH := 80
const PREFAB_CARD_HEIGHT := 100
const PREFAB_CARD_THUMB_SIZE := 64

const PREFAB_THUMBNAIL_PADDING := 4.0

# ============================================================
# GROUP FRAME CONSTANTS
# ============================================================

const GROUP_FRAME_PADDING := 20.0
const GROUP_FRAME_TITLE_HEIGHT := 22.0
const GROUP_FRAME_BORDER_WIDTH := 2.0

# ============================================================
# TOAST CONSTANTS
# ============================================================

const TOAST_BOTTOM_MARGIN := 50.0
const TOAST_LEFT_MARGIN := 16.0
const TOAST_MIN_WIDTH := 220.0
const TOAST_PADDING_X := 12
const TOAST_PADDING_Y := 5

# ============================================================
# LINE / CONNECTION CONSTANTS
# ============================================================

const LINE_DEFAULT_WIDTH := 4.0
const LINE_DEFAULT_COLOR := Color(0.7, 0.7, 0.7, 0.9)
const LINE_DASH_LENGTH := 12.0
const LINE_DASH_GAP := 6.0

# ============================================================
# ENUMS
# ============================================================

enum AllocationState {
	NORMAL,
	INTERMEDIATE,
	ACTIVE,
	PREALLOCATED_INTERMEDIATE,
	PREALLOCATED_ACTIVE,
	REFUND,
}

enum TooltipCorner {
	TOP_LEFT,
	TOP_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_RIGHT,
}

enum TooltipAlign {
	LEFT,
	CENTER,
	RIGHT,
}

# ============================================================
# STATIC EDITOR-SIDE REGISTRIES
# ============================================================

static var _editor_registry: BayterekRegistry = null
static var _designs_registry: BayterekDesignRegistry = null

# ============================================================
# TREE REGISTRY
# ============================================================

static func get_editor_registry() -> BayterekRegistry:
	if not _editor_registry:
		_load_editor_registry()
	return _editor_registry

static func reload_editor_registry() -> void:
	_load_editor_registry()

static func clear_editor_registry() -> void:
	_editor_registry = null

static func save_editor_registry() -> Error:
	if not _editor_registry:
		return FAILED
	_purge_dead_references()
	return safe_save(_editor_registry, get_registry_path())

static func _purge_dead_references() -> void:
	if not _editor_registry:
		return

	var valid_groups: Array[BayterekGroup] = []
	var dropped_groups: int = 0
	var dropped_trees: int = 0

	for group in _editor_registry.groups:
		if group == null:
			dropped_groups += 1
			continue
		if group.resource_path.is_empty() or not FileAccess.file_exists(group.resource_path):
			dropped_groups += 1
			continue

		var valid_trees: Array[BayterekTree] = []
		for tree in group.trees:
			if tree == null:
				dropped_trees += 1
				continue
			if tree.resource_path.is_empty() or not FileAccess.file_exists(tree.resource_path):
				dropped_trees += 1
				continue
			valid_trees.append(tree)

		group.trees = valid_trees
		valid_groups.append(group)

	_editor_registry.groups = valid_groups

	if dropped_groups > 0 or dropped_trees > 0:
		BayterekLogger.info("pre-save cleanup → %d group(s), %d tree(s) dropped." % [dropped_groups, dropped_trees], "registry")

static func _load_editor_registry() -> void:
	var path: String = get_registry_path()

	if not FileAccess.file_exists(path):
		_create_editor_registry()

	var loaded = ResourceLoader.load(path, "BayterekRegistry", ResourceLoader.CACHE_MODE_IGNORE)

	if not loaded or not loaded is BayterekRegistry:
		BayterekLogger.warn("Registry corrupt, rebuilding from disk...", "registry")
		_editor_registry = _rebuild_registry_from_disk()
		ResourceSaver.save(_editor_registry, path)
		return

	_editor_registry = loaded

	if _editor_registry.groups.is_empty() and _has_group_files_on_disk():
		BayterekLogger.warn("Registry empty but groups exist on disk, rebuilding...", "registry")
		_editor_registry = _rebuild_registry_from_disk()
		ResourceSaver.save(_editor_registry, path)
		return

	_sanitize_editor_registry()

static func _sanitize_editor_registry() -> void:
	if not _editor_registry:
		return

	var dirty: bool = false
	var clean_groups: Array[BayterekGroup] = []

	for group in _editor_registry.groups:
		if group == null:
			dirty = true
			continue
		if group.resource_path.is_empty() or not FileAccess.file_exists(group.resource_path):
			BayterekLogger.warn("Dead group reference removed: %s" % group.resource_path, "registry")
			dirty = true
			continue

		var clean_trees: Array[BayterekTree] = []
		for tree in group.trees:
			if tree == null:
				dirty = true
				continue
			if tree.resource_path.is_empty() or not FileAccess.file_exists(tree.resource_path):
				BayterekLogger.warn("Dead tree reference removed: %s" % tree.resource_path, "registry")
				dirty = true
				continue
			clean_trees.append(tree)

		group.trees = clean_trees
		clean_groups.append(group)

	_editor_registry.groups = clean_groups

	if dirty:
		ResourceSaver.save(_editor_registry, get_registry_path())
		BayterekLogger.info("Registry sanitized and saved.", "registry")

static func _create_editor_registry() -> void:
	DirAccess.make_dir_recursive_absolute(get_root_path())
	var reg := BayterekRegistry.new()
	ResourceSaver.save(reg, get_registry_path())

static func _rebuild_registry_from_disk() -> BayterekRegistry:
	var reg := BayterekRegistry.new()
	var root: String = get_root_path()

	if not DirAccess.dir_exists_absolute(root):
		return reg

	var group_dirs: Array[String] = _list_group_dirs(root)

	for dir_path in group_dirs:
		var group_file: String = _find_group_tres_in(dir_path)
		if group_file.is_empty():
			continue

		var grp = ResourceLoader.load(group_file, "BayterekGroup", ResourceLoader.CACHE_MODE_IGNORE)
		if not grp or not grp is BayterekGroup:
			continue

		var valid_trees: Array[BayterekTree] = []
		var files: PackedStringArray = DirAccess.get_files_at(dir_path)
		for file_name in files:
			if not file_name.ends_with(".tres"):
				continue
			var full_path: String = "%s/%s" % [dir_path, file_name]
			if full_path == group_file:
				continue

			var tree_res = ResourceLoader.load(full_path, "BayterekTree", ResourceLoader.CACHE_MODE_IGNORE)
			if tree_res and tree_res is BayterekTree:
				valid_trees.append(tree_res)

		grp.trees = valid_trees
		reg.groups.append(grp)

	return reg

static func _has_group_files_on_disk() -> bool:
	var root: String = get_root_path()
	if not DirAccess.dir_exists_absolute(root):
		return false
	return not _list_group_dirs(root).is_empty()

static func _list_group_dirs(root: String) -> Array[String]:
	var result: Array[String] = []
	var dirs: PackedStringArray = DirAccess.get_directories_at(root)
	for d in dirs:
		if d == DESIGNS_DIR_NAME:
			continue
		result.append("%s/%s" % [root, d])
	return result

static func _find_group_tres_in(dir_path: String) -> String:
	var dir_name: String = dir_path.get_file()
	var expected: String = "%s/%s.tres" % [dir_path, dir_name]
	if FileAccess.file_exists(expected):
		return expected

	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	for f in files:
		if not f.ends_with(".tres"):
			continue
		var full: String = "%s/%s" % [dir_path, f]
		var res = ResourceLoader.load(full, "BayterekGroup", ResourceLoader.CACHE_MODE_IGNORE)
		if res and res is BayterekGroup:
			return full
	return ""

# ============================================================
# DESIGN REGISTRY
# ============================================================

static func get_designs_registry() -> BayterekDesignRegistry:
	if not _designs_registry:
		_load_designs_registry()
	return _designs_registry

static func reload_designs_registry() -> void:
	_load_designs_registry()

static func clear_designs_registry() -> void:
	_designs_registry = null

static func save_designs_registry() -> Error:
	if not _designs_registry:
		return FAILED
	return safe_save(_designs_registry, get_designs_registry_path())

static func _load_designs_registry() -> void:
	var path: String = get_designs_registry_path()

	if not FileAccess.file_exists(path):
		_create_designs_registry()

	var loaded = ResourceLoader.load(path, "BayterekDesignRegistry", ResourceLoader.CACHE_MODE_IGNORE)

	if not loaded or not loaded is BayterekDesignRegistry:
		BayterekLogger.warn("Design registry corrupt, rebuilding from disk...", "designs")
		_designs_registry = _rebuild_designs_registry_from_disk()
		ResourceSaver.save(_designs_registry, path)
		return

	_designs_registry = loaded
	_sanitize_designs_registry()

static func _sanitize_designs_registry() -> void:
	if not _designs_registry:
		return

	var dirty: bool = false
	var clean: Array[BayterekNodeDesign] = []

	for design in _designs_registry.designs:
		if design == null:
			dirty = true
			continue
		if design.resource_path.is_empty() or not FileAccess.file_exists(design.resource_path):
			BayterekLogger.warn("Dead design reference removed: %s" % design.resource_path, "designs")
			dirty = true
			continue
		clean.append(design)

	_designs_registry.designs = clean

	if dirty:
		ResourceSaver.save(_designs_registry, get_designs_registry_path())
		BayterekLogger.info("Design registry sanitized and saved.", "designs")

static func _create_designs_registry() -> void:
	DirAccess.make_dir_recursive_absolute(get_designs_dir())
	var reg := BayterekDesignRegistry.new()
	ResourceSaver.save(reg, get_designs_registry_path())

static func _rebuild_designs_registry_from_disk() -> BayterekDesignRegistry:
	var reg := BayterekDesignRegistry.new()
	var dir_path: String = get_designs_dir()

	if not DirAccess.dir_exists_absolute(dir_path):
		return reg

	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	for f in files:
		if not f.ends_with(".tres"):
			continue
		var full: String = "%s/%s" % [dir_path, f]
		if full == get_designs_registry_path():
			continue
		var res = ResourceLoader.load(full, "BayterekNodeDesign", ResourceLoader.CACHE_MODE_IGNORE)
		if res and res is BayterekNodeDesign:
			reg.designs.append(res)

	return reg

# ============================================================
# PATHS
# ============================================================

static func get_root_path() -> String:
	return ProjectSettings.get_setting(ROOT_PATH_SETTING, DEFAULT_ROOT_PATH)

static func get_registry_filename() -> String:
	return ProjectSettings.get_setting(REGISTRY_FILENAME_SETTING, DEFAULT_REGISTRY_FILENAME)

static func get_registry_path() -> String:
	return "%s/%s" % [get_root_path(), get_registry_filename()]

static func get_designs_dir() -> String:
	return "%s/%s" % [get_root_path(), DESIGNS_DIR_NAME]

static func get_designs_registry_path() -> String:
	return "%s/%s" % [get_designs_dir(), DESIGNS_REGISTRY_FILENAME]

# ============================================================
# SAFE SAVE HELPERS
# ============================================================

## Saves a resource atomically: writes to a temp file first, then moves
## it over the target. Prevents partial writes from corrupting existing
## files if the editor crashes mid-save.
##
## Returns OK on success, or an error code.
static func safe_save(resource: Resource, path: String) -> Error:
	if not resource:
		BayterekLogger.error("safe_save: resource is null", "save")
		return ERR_INVALID_PARAMETER
	if path.is_empty():
		BayterekLogger.error("safe_save: path is empty", "save")
		return ERR_INVALID_PARAMETER

	var tmp_path: String = path + ".tmp"

	# Write to temp file
	var err: Error = ResourceSaver.save(resource, tmp_path)
	if err != OK:
		BayterekLogger.error("safe_save: temp save failed (%d) for %s" % [err, tmp_path], "save")
		return err

	# Make sure target dir exists
	var dir: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

	# If target exists, remove it first (rename is atomic on most systems
	# but Godot's DirAccess.rename_absolute can fail if target exists)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	var move_err: Error = DirAccess.rename_absolute(tmp_path, path)
	if move_err != OK:
		BayterekLogger.error("safe_save: rename failed (%d) %s → %s" % [move_err, tmp_path, path], "save")
		# Cleanup temp
		if FileAccess.file_exists(tmp_path):
			DirAccess.remove_absolute(tmp_path)
		return move_err

	return OK


## Copies a .uid sidecar from `src_path` to `dst_path`, if it exists.
## Also removes any stale .uid at dst first.
static func copy_uid_sidecar(src_path: String, dst_path: String) -> void:
	var src_uid: String = src_path + ".uid"
	var dst_uid: String = dst_path + ".uid"

	if not FileAccess.file_exists(src_uid):
		return

	if FileAccess.file_exists(dst_uid):
		DirAccess.remove_absolute(dst_uid)

	var src_file := FileAccess.open(src_uid, FileAccess.READ)
	if not src_file:
		return
	var content: String = src_file.get_as_text()
	src_file.close()

	var dst_file := FileAccess.open(dst_uid, FileAccess.WRITE)
	if not dst_file:
		return
	dst_file.store_string(content)
	dst_file.close()


## Moves a .uid sidecar (alias for rename). Used when a file moves.
static func move_uid_sidecar(old_path: String, new_path: String) -> void:
	var old_uid: String = old_path + ".uid"
	var new_uid: String = new_path + ".uid"

	if not FileAccess.file_exists(old_uid):
		return

	if FileAccess.file_exists(new_uid):
		DirAccess.remove_absolute(new_uid)

	DirAccess.rename_absolute(old_uid, new_uid)


## Deletes a resource file plus its .uid sidecar.
static func delete_resource_with_sidecar(path: String) -> void:
	var uid_path: String = path + ".uid"
	if FileAccess.file_exists(uid_path):
		DirAccess.remove_absolute(uid_path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

# ============================================================
# HELPERS
# ============================================================

static func to_snake_case(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9]+")
	var result: String = regex.sub(text.strip_edges(), "_", true)
	return result.to_lower()

static func get_version_number(version: String = VERSION) -> int:
	var parts = version.split(".")
	if parts.size() < 3:
		return 0
	var major = int(parts[0]) * 10000
	var minor = int(parts[1]) * 100
	var patch = int(parts[2])
	return major + minor + patch