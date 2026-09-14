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
	return ResourceSaver.save(_editor_registry, get_registry_path())

static func _load_editor_registry() -> void:
	var path: String = get_registry_path()
	if not ResourceLoader.exists(path):
		_create_editor_registry()
	_editor_registry = ResourceLoader.load(path, "BayterekRegistry", ResourceLoader.CACHE_MODE_IGNORE) as BayterekRegistry

static func _create_editor_registry() -> void:
	DirAccess.make_dir_recursive_absolute(get_root_path())
	var reg := BayterekRegistry.new()
	ResourceSaver.save(reg, get_registry_path())

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