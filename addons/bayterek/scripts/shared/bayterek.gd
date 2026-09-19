@tool
class_name Bayterek
extends RefCounted
## Global constants and helper functions.

const VERSION := "0.1.0"

const ROOT_PATH_SETTING := "addons/bayterek/root_path"
const DEFAULT_ROOT_PATH := "res://bayterek_data"
const REGISTRY_FILENAME_SETTING := "addons/bayterek/registry_filename"
const DEFAULT_REGISTRY_FILENAME := "registry.tres"

const ICON_THEME := &"EditorIcons"
const GROUP_ICON := "Folder"
const TREE_ICON := "KeyValue"

const BlankIcon: Texture2D = null  # TODO: preload("res://addons/bayterek/blank_icon.png")

# --- Editor visual constants ---
const GRID_CELL_SIZE := Vector2(16, 16)
const GRID_PRIMARY_STEP := 4
const GRID_LINE_COLOR := Color(1, 1, 1, 0.12)
const GRID_LINE_WIDTH := 1.0
const DEFAULT_TREE_SIZE := Vector2(5000, 5000)

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

## Alignment for tooltip header, body, and footer.
enum TooltipAlign {
	LEFT,
	CENTER,
	RIGHT,
}

# --- Static editor-side registry ---

static var _editor_registry: BayterekRegistry = null

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
	return ResourceSaver.save(_editor_registry, get_registry_path())

## Removes groups and trees whose backing .tres files no longer exist.
## Prevents dead UID references from being written into registry.tres.
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
		print("Bayterek: save öncesi temizlik → %d grup, %d tree atıldı." % [dropped_groups, dropped_trees])

static func _load_editor_registry() -> void:
	var path: String = get_registry_path()

	# Clean start: file doesn't exist
	if not FileAccess.file_exists(path):
		_create_editor_registry()

	var loaded = ResourceLoader.load(path, "BayterekRegistry", ResourceLoader.CACHE_MODE_IGNORE)

	# If deserialization failed (dead refs break typed arrays), rebuild from disk
	if not loaded or not loaded is BayterekRegistry:
		push_warning("Bayterek: Registry bozuk, diskteki dosyalardan yeniden inşa ediliyor...")
		_editor_registry = _rebuild_registry_from_disk()
		ResourceSaver.save(_editor_registry, path)
		return

	_editor_registry = loaded

	# Sanity check: if groups is suspiciously empty but disk has data,
	# fall back to rebuilding.
	if _editor_registry.groups.is_empty() and _has_group_files_on_disk():
		push_warning("Bayterek: Registry boş ama diskte grup var, yeniden inşa ediliyor...")
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

		# Drop groups whose .tres file is gone
		if group.resource_path.is_empty() or not FileAccess.file_exists(group.resource_path):
			push_warning("Bayterek: Registry'de ölü grup referansı temizlendi: %s" % group.resource_path)
			dirty = true
			continue

		# Drop trees whose .tres files are gone
		var clean_trees: Array[BayterekTree] = []
		for tree in group.trees:
			if tree == null:
				dirty = true
				continue
			if tree.resource_path.is_empty() or not FileAccess.file_exists(tree.resource_path):
				push_warning("Bayterek: Registry'de ölü tree referansı temizlendi: %s" % tree.resource_path)
				dirty = true
				continue
			clean_trees.append(tree)

		group.trees = clean_trees
		clean_groups.append(group)

	_editor_registry.groups = clean_groups

	if dirty:
		ResourceSaver.save(_editor_registry, get_registry_path())
		print("Bayterek: Registry sanitize edildi ve kaydedildi.")

static func _create_editor_registry() -> void:
	DirAccess.make_dir_recursive_absolute(get_root_path())
	var reg := BayterekRegistry.new()
	ResourceSaver.save(reg, get_registry_path())

# --- Rebuild from disk ---

## Scans bayterek_data/ recursively for .tres files that are BayterekGroup
## resources, and rebuilds a fresh registry from them.
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

		# Refresh trees: scan the same dir for .tres files, skip the group file itself
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
		result.append("%s/%s" % [root, d])
	return result

static func _find_group_tres_in(dir_path: String) -> String:
	var dir_name: String = dir_path.get_file()
	var expected: String = "%s/%s.tres" % [dir_path, dir_name]
	if FileAccess.file_exists(expected):
		return expected

	# Fallback: any .tres file that is a BayterekGroup
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	for f in files:
		if not f.ends_with(".tres"):
			continue
		var full: String = "%s/%s" % [dir_path, f]
		var res = ResourceLoader.load(full, "BayterekGroup", ResourceLoader.CACHE_MODE_IGNORE)
		if res and res is BayterekGroup:
			return full
	return ""

# --- Paths ---

static func get_root_path() -> String:
	return ProjectSettings.get_setting(ROOT_PATH_SETTING, DEFAULT_ROOT_PATH)

static func get_registry_filename() -> String:
	return ProjectSettings.get_setting(REGISTRY_FILENAME_SETTING, DEFAULT_REGISTRY_FILENAME)

static func get_registry_path() -> String:
	return "%s/%s" % [get_root_path(), get_registry_filename()]

# --- Helpers ---

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