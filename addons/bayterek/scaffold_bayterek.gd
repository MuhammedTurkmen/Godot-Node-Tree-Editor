@tool
extends EditorScript
## Bayterek Plugin Scaffolder
##
## Creates the full addons/bayterek/ folder structure AND generates
## stub files for any missing scripts. Existing files are NEVER
## overwritten — this is a safe "ensure structure exists" operation.
##
## Usage:
##   1. Open this file in the Godot editor
##   2. File → Run  (or Ctrl+Shift+X)
##   3. Check the Output panel for the summary

const ROOT := "res://addons/bayterek"

# ============================================================
# DIRECTORIES TO ENSURE EXIST
# ============================================================

const DIRS: Array[String] = [
	"scenes",
	"scenes/editor",
	"scenes/shared",

	"scripts",
	"scripts/editor",
	"scripts/editor/ui",
	"scripts/resources",
	"scripts/resources/layers",
	"scripts/runtime",
	"scripts/shared",

	"shortcuts",

	# Optional: test fixture directory used by the automated tests.
	"test_fixtures",
]

# ============================================================
# FILES TO CREATE (only if missing)
# ============================================================
#
# Each entry maps a relative path (from ROOT) to its full source.
# We keep the stubs minimal so they don't clash with real files once
# they're written. The scaffolder is idempotent — running it twice has
# no effect on existing files.

const FILES := {

# =========================================================================
# ROOT
# =========================================================================

"plugin.cfg": """[plugin]

name="Bayterek"
description="Node-based tree editor (skill tree, passive tree, etc.) for Godot 4."
author=""
version="0.1.0"
script="bayterek_plugin.gd"
""",

"bayterek_plugin.gd": """@tool
extends EditorPlugin
## Bayterek plugin entry point.
##
## This is the plugin's lifecycle hook. On enter, it registers the
## autoloads, project settings, and the main editor screen. On exit,
## it cleans all of them up so the editor can be toggled safely.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

var _main_screen: Control = null
var _distraction: bool = false

func _enter_tree() -> void:
	BayterekLogger.sync_with_project_settings()
	BayterekPicker.reset_state()
	BayterekLayerStateColors.reset_copy_state()

	_register_autoloads()
	_register_settings()
	_ensure_data_directories()
	_create_main_screen()

	BayterekLogger.info("Plugin ready (v%s)." % Bayterek.VERSION, "plugin")

func _exit_tree() -> void:
	BayterekPicker.shutdown()
	BayterekLayerStateColors.reset_copy_state()

	if _main_screen:
		_main_screen.queue_free()
		_main_screen = null

	_remove_autoloads()
	BayterekLogger.info("Plugin shut down.", "plugin")

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "Bayterek"

func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("Node", Bayterek.ICON_THEME)

func _make_visible(visible: bool) -> void:
	if not _main_screen:
		return
	_main_screen.visible = visible
	if visible:
		_distraction = EditorInterface.distraction_free_mode
		EditorInterface.distraction_free_mode = true
	else:
		EditorInterface.distraction_free_mode = _distraction
	if visible and _main_screen.has_method("init"):
		_main_screen.init()

func _register_autoloads() -> void:
	if not ProjectSettings.has_setting("autoload/BayterekLoader"):
		add_autoload_singleton("BayterekLoader", "res://addons/bayterek/scripts/shared/bayterek_loader.gd")
	if not ProjectSettings.has_setting("autoload/BayterekSerializer"):
		add_autoload_singleton("BayterekSerializer", "res://addons/bayterek/scripts/runtime/bayterek_serializer.gd")

func _remove_autoloads() -> void:
	remove_autoload_singleton("BayterekLoader")
	remove_autoload_singleton("BayterekSerializer")

func _register_settings() -> void:
	_register_setting(Bayterek.ROOT_PATH_SETTING, Bayterek.DEFAULT_ROOT_PATH, PROPERTY_HINT_DIR, "res://")
	_register_setting(Bayterek.REGISTRY_FILENAME_SETTING, Bayterek.DEFAULT_REGISTRY_FILENAME, PROPERTY_HINT_NONE, "")
	_register_setting(Bayterek.VERBOSE_SETTING, Bayterek.DEFAULT_VERBOSE, PROPERTY_HINT_NONE, "")

func _register_setting(name: String, default_value: Variant, hint: int, hint_string: String) -> void:
	if not ProjectSettings.has_setting(name):
		ProjectSettings.set_setting(name, default_value)
	ProjectSettings.set_initial_value(name, default_value)
	ProjectSettings.add_property_info({
		"name": name,
		"type": typeof(default_value),
		"hint": hint,
		"hint_string": hint_string,
	})

func _ensure_data_directories() -> void:
	var root: String = Bayterek.get_root_path()
	var designs: String = Bayterek.get_designs_dir()
	if not DirAccess.dir_exists_absolute(root):
		DirAccess.make_dir_recursive_absolute(root)
	if not DirAccess.dir_exists_absolute(designs):
		DirAccess.make_dir_recursive_absolute(designs)

func _create_main_screen() -> void:
	var script = load("res://addons/bayterek/scripts/editor/bayterek_main_screen.gd")
	if not script or not script.can_instantiate():
		BayterekLogger.error("BayterekMainScreen script not found.", "plugin")
		return
	_main_screen = script.new()
	if not _main_screen:
		return
	_main_screen.name = "BayterekMainScreen"
	EditorInterface.get_editor_main_screen().add_child(_main_screen)
	_main_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_make_visible(false)
""",

# =========================================================================
# SCRIPTS / SHARED
# =========================================================================

"scripts/shared/bayterek.gd": """@tool
class_name Bayterek
extends RefCounted
## Global constants and helper functions.

const VERSION := "0.1.0"

const ROOT_PATH_SETTING := "addons/bayterek/root_path"
const DEFAULT_ROOT_PATH := "res://data/bayterek"
const REGISTRY_FILENAME_SETTING := "addons/bayterek/registry_filename"
const DEFAULT_REGISTRY_FILENAME := "registry.tres"

const VERBOSE_SETTING := "addons/bayterek/verbose"
const DEFAULT_VERBOSE := false

const DESIGNS_DIR_NAME := "designs"
const DESIGNS_REGISTRY_FILENAME := "designs_registry.tres"

const ICON_THEME := &"EditorIcons"
const GROUP_ICON := "Folder"
const TREE_ICON := "KeyValue"
const DESIGN_ICON := "PackedScene"

const BlankIcon: Texture2D = null

const GRID_CELL_SIZE := Vector2(16, 16)
const GRID_PRIMARY_STEP := 4
const GRID_LINE_COLOR := Color(1, 1, 1, 0.12)
const GRID_LINE_WIDTH := 1.0
const DEFAULT_TREE_SIZE := Vector2(5000, 5000)

const CORNER_SEGMENTS := 20
const CORNER_RADIUS_CLAMP_FACTOR := 0.99
const CIRCLE_SEGMENTS := 48

const CROWN_FONT_SIZE := 18
const CROWN_COLOR := Color(1.0, 0.85, 0.35)
const CROWN_OUTLINE_COLOR := Color(0, 0, 0, 0.9)
const CROWN_OUTLINE_SIZE := 2

const SELECTION_BORDER_COLOR := Color(1, 0.6, 0.1, 1)
const SELECTION_BORDER_WIDTH := 2
const SELECTION_BORDER_RADIUS := 2
const SELECTION_BORDER_OFFSET := 3

const CAMERA_MIN_ZOOM := 0.4
const CAMERA_MAX_ZOOM := 3.0
const CAMERA_ZOOM_STEP := 0.1

const PREVIEW_MARGIN := 20.0
const PREVIEW_MIN_USER_ZOOM := 0.1
const PREVIEW_MAX_USER_ZOOM := 8.0
const PREVIEW_ZOOM_STEP := 1.15

enum AllocationState {
	NORMAL,
	INTERMEDIATE,
	ACTIVE,
	PREALLOCATED_INTERMEDIATE,
	PREALLOCATED_ACTIVE,
	REFUND,
}

enum TooltipCorner { TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT }
enum TooltipAlign  { LEFT, CENTER, RIGHT }

static var _editor_registry: BayterekRegistry = null
static var _designs_registry: BayterekDesignRegistry = null

# ------------------------------------------------------------
# Tree registry
# ------------------------------------------------------------

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
	return safe_save(_editor_registry, get_registry_path())

static func _load_editor_registry() -> void:
	var path: String = get_registry_path()
	if not FileAccess.file_exists(path):
		_create_editor_registry()
	var loaded = ResourceLoader.load(path, "BayterekRegistry", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded is BayterekRegistry:
		_editor_registry = loaded
	else:
		_editor_registry = BayterekRegistry.new()
		ResourceSaver.save(_editor_registry, path)

static func _create_editor_registry() -> void:
	DirAccess.make_dir_recursive_absolute(get_root_path())
	var reg := BayterekRegistry.new()
	ResourceSaver.save(reg, get_registry_path())

# ------------------------------------------------------------
# Design registry
# ------------------------------------------------------------

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
	if loaded is BayterekDesignRegistry:
		_designs_registry = loaded
	else:
		_designs_registry = BayterekDesignRegistry.new()
		ResourceSaver.save(_designs_registry, path)

static func _create_designs_registry() -> void:
	DirAccess.make_dir_recursive_absolute(get_designs_dir())
	var reg := BayterekDesignRegistry.new()
	ResourceSaver.save(reg, get_designs_registry_path())

# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------

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

# ------------------------------------------------------------
# Save helpers
# ------------------------------------------------------------

static func safe_save(resource: Resource, path: String) -> Error:
	if not resource or path.is_empty():
		return ERR_INVALID_PARAMETER

	var dir: String = path.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

	return ResourceSaver.save(resource, path)

static func copy_uid_sidecar(src_path: String, dst_path: String) -> void:
	var src_uid: String = src_path + ".uid"
	var dst_uid: String = dst_path + ".uid"
	if not FileAccess.file_exists(src_uid):
		return
	if FileAccess.file_exists(dst_uid):
		DirAccess.remove_absolute(dst_uid)
	var src_file := FileAccess.open(src_uid, FileAccess.READ)
	if not src_file: return
	var content: String = src_file.get_as_text()
	src_file.close()
	var dst_file := FileAccess.open(dst_uid, FileAccess.WRITE)
	if not dst_file: return
	dst_file.store_string(content)
	dst_file.close()

static func move_uid_sidecar(old_path: String, new_path: String) -> void:
	var old_uid: String = old_path + ".uid"
	var new_uid: String = new_path + ".uid"
	if not FileAccess.file_exists(old_uid):
		return
	if FileAccess.file_exists(new_uid):
		DirAccess.remove_absolute(new_uid)
	DirAccess.rename_absolute(old_uid, new_uid)

static func delete_resource_with_sidecar(path: String) -> void:
	var uid_path: String = path + ".uid"
	if FileAccess.file_exists(uid_path):
		DirAccess.remove_absolute(uid_path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

static func to_snake_case(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9]+")
	var result: String = regex.sub(text.strip_edges(), "_", true)
	return result.to_lower()

static func get_version_number(version: String = VERSION) -> int:
	var parts = version.split(".")
	if parts.size() < 3:
		return 0
	return int(parts[0]) * 10000 + int(parts[1]) * 100 + int(parts[2])
""",

"scripts/shared/bayterek_logger.gd": """@tool
class_name BayterekLogger
extends RefCounted
## Centralized logging.

enum Level { DEBUG, INFO, WARN, ERROR }

static var min_level: Level = Level.INFO
static var prefix: String = ""

static func debug(message: String, tag: String = "") -> void: _log(Level.DEBUG, message, tag)
static func info(message: String, tag: String = "") -> void:  _log(Level.INFO, message, tag)
static func warn(message: String, tag: String = "") -> void:  _log(Level.WARN, message, tag)
static func error(message: String, tag: String = "") -> void: _log(Level.ERROR, message, tag)

static func sync_with_project_settings() -> void:
	if ProjectSettings.has_setting("addons/bayterek/verbose"):
		var verbose: bool = ProjectSettings.get_setting("addons/bayterek/verbose", false)
		min_level = Level.DEBUG if verbose else Level.INFO

static func set_level(level: Level) -> void: min_level = level
static func set_prefix(p: String) -> void: prefix = p

static func _log(level: Level, message: String, tag: String) -> void:
	if level < min_level:
		return
	var level_str: String = ["DEBUG", "INFO", "WARN", "ERROR"][level]
	var tag_str: String = "" if tag.is_empty() else " [%s]" % tag
	var line: String = "[Bayterek] [%s]%s %s" % [level_str, tag_str, message]
	match level:
		Level.DEBUG, Level.INFO:
			print(line)
		Level.WARN:
			push_warning(line)
		Level.ERROR:
			push_error(line)
""",

"scripts/shared/bayterek_loader.gd": """@tool
extends Node
## Autoload: BayterekLoader.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

var _registry: BayterekRegistry
var _active_node_editor: Node = null

func _init() -> void:
	_load_registry()

func _ready() -> void:
	set_process_input(true)

func get_registry() -> BayterekRegistry:
	return _registry

func register_node_editor(editor: Node) -> void:
	_active_node_editor = editor

func unregister_node_editor(editor: Node) -> void:
	if _active_node_editor == editor:
		_active_node_editor = null

func _load_registry() -> void:
	var path: String = Bayterek.get_registry_path()
	if not ResourceLoader.exists(path):
		if OS.has_feature("editor"):
			DirAccess.make_dir_recursive_absolute(Bayterek.get_root_path())
			_registry = BayterekRegistry.new()
			ResourceSaver.save(_registry, path)
		return
	_registry = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as BayterekRegistry
""",

# =========================================================================
# SCRIPTS / RESOURCES
# =========================================================================

"scripts/resources/bayterek_registry.gd": """@tool
class_name BayterekRegistry
extends Resource

@export_storage var groups: Array[BayterekGroup] = []

func find_group_by_path(path: String) -> BayterekGroup:
	for g in groups:
		if g.resource_path == path:
			return g
	return null

func get_tree_by_path(path: String) -> BayterekTree:
	for g in groups:
		for t in g.trees:
			if t.resource_path == path:
				return t
	return null
""",

"scripts/resources/bayterek_group.gd": """@tool
class_name BayterekGroup
extends Resource

@export_storage var name: String
@export_storage var trees: Array[BayterekTree] = []
""",

"scripts/resources/bayterek_tree.gd": """@tool
class_name BayterekTree
extends Resource

@export_storage var version: int = 1
@export_storage var id: String
@export_storage var name: String
@export_storage var revealed: bool = true
@export_storage var allocation: bool = true
@export_storage var preallocation: bool = true
@export_storage var multiallocation: bool = false
@export_storage var chain_connection_mode: bool = true
@export_storage var allocation_confirm: bool = false
@export_storage var refund_confirm: bool = false
@export_storage var show_group_frames: bool = true
@export_storage var group_frame_title_align: int = 0
@export_storage var hover_animations_enabled: bool = true
@export_storage var tooltip_header_align: int = 0
@export_storage var tooltip_body_align: int = 0
@export_storage var tooltip_footer_align: int = 1
@export_storage var size: Vector2 = Vector2(5000, 5000)
@export_storage var bg_color: Color = Color(0.1, 0.1, 0.1)
@export_storage var bg_texture: Texture2D
@export_storage var line_texture_normal: Texture2D
@export_storage var line_texture_intermediate: Texture2D
@export_storage var line_texture_active: Texture2D
@export_storage var texture_filter: int = 0
@export_storage var id_counter: int = 0
@export_storage var border_scale: float = 1.5
@export_storage var nodes: Array[BayterekNode] = []
@export_storage var decorations: Array[BayterekNode] = []
@export_storage var prefabs: Array[BayterekPrefab] = []
@export_storage var attributes: Dictionary = {}
@export_storage var node_groups: Array[BayterekNodeGroup] = []
@export_storage var hierarchy_split_offset: int = 200
@export_storage var prefabs_split_offset: int = -180
@export_storage var inspector_split_offset: int = -320
@export_storage var prefabs_bar_visible: bool = true
@export_storage var default_design_id: String = ""

var tree_state: BayterekTreeState

func _init() -> void:
	nodes = []; decorations = []; prefabs = []; attributes = []; node_groups = []
	tree_state = BayterekTreeState.new()

func get_next_id() -> int:
	id_counter += 1
	return id_counter

func get_godot_texture_filter() -> int:
	match texture_filter:
		1: return CanvasItem.TEXTURE_FILTER_NEAREST
		_: return CanvasItem.TEXTURE_FILTER_LINEAR
""",

"scripts/resources/bayterek_node.gd": """@tool
class_name BayterekNode
extends Resource

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

enum PrerequisiteMode { ANY, COUNT, ALL, GROUP_COMPLETE }
const MAX_LAYERS := 6

@export_storage var is_root: bool = false
@export_storage var is_decoration: bool = false
@export_storage var reference_id: String = ""
@export_storage var id: int = 0
@export_storage var external_id: String = ""
@export_storage var name: String = ""
@export_storage var description: String = ""
@export_storage var design_id: String = ""
@export_storage var position: Vector2 = Vector2.ZERO
@export_storage var design_size: Vector2 = Vector2(100, 100)
@export_storage var scale: Vector2 = Vector2.ONE
@export_storage var node_rotation: float = 0.0
@export_storage var node_skew: Vector2 = Vector2.ZERO
@export_storage var line_data: Dictionary = {}
@export_storage var out_nodes: Array[int] = []
@export_storage var in_nodes: Array[int] = []
@export_storage var attributes: Dictionary = {}
@export_storage var max_allocations: int = 1
@export_storage var locked: bool = false
@export_storage var prerequisite_mode: PrerequisiteMode = PrerequisiteMode.ANY
@export_storage var prerequisite_count: int = 1
@export_storage var prerequisite_group_id: String = ""
@export_storage var group_id: String = ""
@export_storage var layers: Array[BayterekLayer] = []
@export_storage var overridden_attributes: Dictionary = {}
@export_storage var exported_overrides: Dictionary = {}
""",

"scripts/resources/bayterek_attribute.gd": """@tool
class_name BayterekAttribute
extends Resource

@export_storage var id: String
@export_storage var name: String
@export_storage var effect: String
@export_storage var value_count: int = 0
""",

"scripts/resources/bayterek_prefab.gd": """@tool
class_name BayterekPrefab
extends Resource

signal name_changed(prefab)
signal description_changed(prefab)
signal attribute_changed(prefab, attribute_id, removed)
signal max_allocations_changed(prefab)
signal exported_values_changed(prefab)

@export_storage var reference_id: String
@export_storage var id: String
@export_storage var node_name: String
@export_storage var description: String
@export_storage var design_id: String = ""
@export_storage var attributes: Dictionary = {}
@export_storage var max_allocations: int = 1
@export_storage var exported_fields: Dictionary = {}
@export_storage var exported_values: Dictionary = {}

var nodes: Array = []
""",

"scripts/resources/bayterek_tree_state.gd": """@tool
class_name BayterekTreeState
extends RefCounted

var version: int = 1
var allocated_nodes: Array[int] = []
var allocation_level: Dictionary = {}
""",

"scripts/resources/bayterek_node_group.gd": """@tool
class_name BayterekNodeGroup
extends Resource

@export_storage var id: String = ""
@export_storage var name: String = "New Group"
@export_storage var color: Color = Color(0.4, 0.7, 1.0, 1.0)
@export_storage var node_ids: Array[int] = []

static func generate_id() -> String:
	return BayterekUUIDGenerator.v4()
""",

"scripts/resources/bayterek_design_registry.gd": """@tool
class_name BayterekDesignRegistry
extends Resource

@export_storage var designs: Array[BayterekNodeDesign] = []

func get_design_by_id(design_id: String) -> BayterekNodeDesign:
	for d in designs:
		if d and d.id == design_id:
			return d
	return null

func add_design(design: BayterekNodeDesign) -> bool:
	if not design or designs.has(design):
		return false
	for existing in designs:
		if existing and existing.id == design.id:
			return false
	designs.append(design)
	return true
""",

"scripts/resources/bayterek_node_design.gd": """@tool
class_name BayterekNodeDesign
extends Resource

signal layers_changed(design, change_type)
signal name_changed(design)
signal description_changed(design)
signal exported_fields_changed(design)

@export_storage var id: String = ""
@export_storage var name: String = "New Design"
@export_storage var description: String = ""
@export_storage var category: String = ""
@export_storage var design_size: Vector2 = Vector2(100, 100)
@export_storage var scale: Vector2 = Vector2.ONE
@export_storage var layers: Array[BayterekLayer] = []
@export_storage var bounds_layer_id: String = ""
@export_storage var exported_fields: Dictionary = {}

func _init() -> void:
	layers = []
	exported_fields = {}
""",

# =========================================================================
# SCRIPTS / RESOURCES / LAYERS
# =========================================================================

"scripts/resources/layers/bayterek_layer.gd": """@tool
class_name BayterekLayer
extends Resource

enum RenderModeOverride { INHERIT, VECTOR, PIXEL }
enum TextureFilterOverride { INHERIT, LINEAR, NEAREST }

const STATES: Array[String] = [
	"normal", "hover", "clicked", "locked", "preallocated",
	"prerefund", "max_level", "allocateable", "not_allocateable",
]

const STATE_PRIORITY: Array[String] = [
	"clicked", "hover", "prerefund", "preallocated", "allocateable",
	"not_allocateable", "max_level", "locked", "normal",
]

@export_storage var layer_id: String = ""
@export_storage var layer_name: String = "Layer"
@export_storage var visible: bool = true
@export_storage var transform: BayterekLayerTransform
@export_storage var animation_id: String = ""
@export_storage var animated: bool = false
@export_storage var absolute: bool = false
@export_storage var render_mode_override: RenderModeOverride = RenderModeOverride.INHERIT
@export_storage var texture_filter_override: TextureFilterOverride = TextureFilterOverride.INHERIT

func _init() -> void:
	if layer_id.is_empty():
		layer_id = BayterekUUIDGenerator.v4()
	if not transform:
		transform = BayterekLayerTransform.new()

func get_visual_state(node_states: Dictionary) -> String:
	for state in STATE_PRIORITY:
		if state == "normal":
			return "normal"
		if node_states.get(state, false):
			return state
	return "normal"

func get_size(design_size: Vector2) -> Vector2:
	if not transform: return design_size
	return transform.get_effective_size(design_size)

func get_matrix(design_size: Vector2, pixel_mode: bool = false) -> Transform2D:
	if not transform: return Transform2D.IDENTITY
	return transform.get_matrix(design_size, pixel_mode)

func get_effective_render_mode() -> int:
	match render_mode_override:
		RenderModeOverride.VECTOR: return 0
		RenderModeOverride.PIXEL: return 1
		_: return 0

func duplicate_layer() -> BayterekLayer:
	var copy := BayterekLayer.new()
	copy.layer_id = layer_id
	copy.layer_name = layer_name
	copy.visible = visible
	copy.transform = transform.duplicate_transform() if transform else BayterekLayerTransform.new()
	copy.animation_id = animation_id
	copy.animated = animated
	copy.absolute = absolute
	copy.render_mode_override = render_mode_override
	copy.texture_filter_override = texture_filter_override
	return copy
""",

"scripts/resources/layers/bayterek_layer_transform.gd": """@tool
class_name BayterekLayerTransform
extends Resource

enum PivotMode {
	TOP_LEFT, TOP_CENTER, TOP_RIGHT,
	MID_LEFT, CENTER, MID_RIGHT,
	BOTTOM_LEFT, BOTTOM_CENTER, BOTTOM_RIGHT, CUSTOM,
}

@export_storage var position: Vector2 = Vector2.ZERO
@export_storage var size: Vector2 = Vector2.ZERO
@export_storage var scale: Vector2 = Vector2.ONE
@export_storage var flip_x: bool = false
@export_storage var flip_y: bool = false
@export_storage var rotation: float = 0.0
@export_storage var skew: Vector2 = Vector2.ZERO
@export_storage var pivot: Vector2 = Vector2(0.5, 0.5)
@export_storage var pivot_mode: PivotMode = PivotMode.CENTER
@export_storage var scale_from_pivot: bool = false

func get_effective_size(design_size: Vector2) -> Vector2:
	var base: Vector2 = design_size
	if size.x > 0.0 and size.y > 0.0:
		base = size
	var sx: float = scale.x if absf(scale.x) > 0.0001 else 1.0
	var sy: float = scale.y if absf(scale.y) > 0.0001 else 1.0
	return Vector2(base.x * sx, base.y * sy)

func get_matrix(_design_size: Vector2, _pixel_mode: bool = false) -> Transform2D:
	return Transform2D.IDENTITY

func duplicate_transform() -> BayterekLayerTransform:
	var copy := BayterekLayerTransform.new()
	copy.position = position
	copy.size = size
	copy.scale = scale
	copy.flip_x = flip_x
	copy.flip_y = flip_y
	copy.rotation = rotation
	copy.skew = skew
	copy.pivot = pivot
	copy.pivot_mode = pivot_mode
	copy.scale_from_pivot = scale_from_pivot
	return copy
""",

"scripts/resources/layers/bayterek_texture_layer.gd": """@tool
class_name BayterekTextureLayer
extends BayterekLayer

enum StretchMode { STRETCH, KEEP_ASPECT, TILE, NINE_PATCH }

@export_storage var icon_enabled: bool = true
@export_storage var icon_configs: Dictionary = {}
@export_storage var tint_enabled: bool = false
@export_storage var tint_configs: Dictionary = {}
@export_storage var stretch_mode: StretchMode = StretchMode.STRETCH
@export_storage var nine_patch_margin_left: int = 8
@export_storage var nine_patch_margin_top: int = 8
@export_storage var nine_patch_margin_right: int = 8
@export_storage var nine_patch_margin_bottom: int = 8
@export_storage var nine_patch_draw_center: bool = true

func _init() -> void:
	super._init()
	layer_name = "Texture"
	icon_configs = {"normal": {"enabled": true, "texture": null}}

func get_icon_for_state(state_key: String) -> Texture2D:
	if not icon_enabled: return null
	if icon_configs.has(state_key) and icon_configs[state_key].get("enabled", false):
		return icon_configs[state_key].get("texture", null)
	if icon_configs.has("normal"):
		return icon_configs["normal"].get("texture", null)
	return null

func get_tint_for_state(state_key: String) -> Color:
	if not tint_enabled: return Color.WHITE
	if tint_configs.has(state_key) and tint_configs[state_key].get("enabled", false):
		return tint_configs[state_key].get("color", Color.WHITE)
	if tint_configs.has("normal"):
		return tint_configs["normal"].get("color", Color.WHITE)
	return Color.WHITE

func duplicate_layer() -> BayterekLayer:
	var copy := BayterekTextureLayer.new()
	copy.layer_id = layer_id
	copy.layer_name = layer_name
	copy.visible = visible
	copy.transform = transform.duplicate_transform() if transform else BayterekLayerTransform.new()
	copy.icon_enabled = icon_enabled
	copy.icon_configs = icon_configs.duplicate(true)
	copy.tint_enabled = tint_enabled
	copy.tint_configs = tint_configs.duplicate(true)
	copy.stretch_mode = stretch_mode
	copy.nine_patch_margin_left = nine_patch_margin_left
	copy.nine_patch_margin_top = nine_patch_margin_top
	copy.nine_patch_margin_right = nine_patch_margin_right
	copy.nine_patch_margin_bottom = nine_patch_margin_bottom
	copy.nine_patch_draw_center = nine_patch_draw_center
	return copy
""",

# =========================================================================
# SCRIPTS / RUNTIME
# =========================================================================

"scripts/runtime/bayterek_serializer.gd": """@tool
extends Node
## Autoload: BayterekSerializer.

const OLD_SAVE_PATH := "user://bayterek"
const SAVE_PATH := "user://bayterek_v2"
const SAVE_FORMAT_VERSION := 2

var test_mode: bool = false

func save_tree_state(tree: BayterekTree, custom_path: String = "") -> void:
	if not test_mode and Engine.is_editor_hint(): return
	if not tree or not tree.tree_state: return
	DirAccess.make_dir_recursive_absolute(SAVE_PATH)
	var uid: String = _get_tree_uid(tree)
	if uid.is_empty(): return
	var save_path: String = custom_path if not custom_path.is_empty() else "%s/%s.tree" % [SAVE_PATH, uid]
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if not file: return
	file.store_32(SAVE_FORMAT_VERSION)
	file.store_32(tree.tree_state.version)
	file.store_var(tree.tree_state.allocated_nodes)
	file.store_var(tree.tree_state.allocation_level)
	file.close()

func load_tree_state(tree: BayterekTree, custom_path: String = "") -> void:
	if not test_mode and Engine.is_editor_hint(): return
	if not tree: return
	if not tree.tree_state:
		tree.tree_state = BayterekTreeState.new()
	DirAccess.make_dir_recursive_absolute(SAVE_PATH)
	var uid: String = _get_tree_uid(tree)
	if uid.is_empty(): return
	var save_path: String = custom_path if not custom_path.is_empty() else "%s/%s.tree" % [SAVE_PATH, uid]
	if not FileAccess.file_exists(save_path): return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file: return
	var fmt: int = file.get_32()
	if fmt > SAVE_FORMAT_VERSION:
		file.seek(0)
		fmt = 1
	tree.tree_state.version = file.get_32()
	tree.tree_state.allocated_nodes = file.get_var()
	if fmt >= 2:
		var levels = file.get_var()
		if levels is Dictionary:
			tree.tree_state.allocation_level = levels
	file.close()

func delete_tree_state(tree: BayterekTree, custom_path: String = "") -> bool:
	if not test_mode and Engine.is_editor_hint(): return false
	if not tree: return false
	var uid: String = _get_tree_uid(tree)
	if uid.is_empty(): return false
	var save_path: String = custom_path if not custom_path.is_empty() else "%s/%s.tree" % [SAVE_PATH, uid]
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
		return true
	return false

func has_save(tree: BayterekTree, custom_path: String = "") -> bool:
	if not tree: return false
	var uid: String = _get_tree_uid(tree)
	if uid.is_empty(): return false
	var save_path: String = custom_path if not custom_path.is_empty() else "%s/%s.tree" % [SAVE_PATH, uid]
	return FileAccess.file_exists(save_path)

func _get_tree_uid(tree: BayterekTree) -> String:
	if not tree.resource_path.is_empty():
		var uid_int: int = ResourceLoader.get_resource_uid(tree.resource_path)
		if uid_int != ResourceUID.INVALID_ID:
			return str(uid_int)
	if not tree.id.is_empty():
		return "id_" + tree.id
	if not tree.resource_path.is_empty():
		return "path_" + str(hash(tree.resource_path))
	return ""
""",

# =========================================================================
# SCRIPTS / EDITOR
# =========================================================================

"scripts/editor/bayterek_main_screen.gd": """@tool
class_name BayterekMainScreen
extends MarginContainer

signal update_available(version)
signal dirty_changed(editor, dirty)
signal tree_closed(editor)

var initialized: bool = false
var tab_container: TabContainer
var browser = null
var node_editor = null
var save_confirmation: ConfirmationDialog
var _open_editors: Dictionary = {}

func _ready() -> void:
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL

func _exit_tree() -> void:
	initialized = false
	_open_editors.clear()
	tab_container = null
	browser = null
	node_editor = null
	save_confirmation = null

func init() -> void:
	if initialized: return
	initialized = true
	_build_ui()
	if browser and browser.has_method("init"): browser.init()
	if node_editor and node_editor.has_method("refresh"): node_editor.refresh()

func _build_ui() -> void:
	if tab_container: return
	tab_container = TabContainer.new()
	tab_container.size_flags_horizontal = SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(tab_container)

	var browser_script = load("res://addons/bayterek/scripts/editor/bayterek_browser.gd")
	if browser_script and browser_script.can_instantiate():
		browser = browser_script.new()
		browser.name = "Browser"
		if "main_screen" in browser: browser.main_screen = self
		tab_container.add_child(browser)
		tab_container.set_tab_title(0, "Browser")

	var ne_script = load("res://addons/bayterek/scripts/editor/bayterek_node_editor_screen.gd")
	if ne_script and ne_script.can_instantiate():
		node_editor = ne_script.new()
		node_editor.name = "NodeEditor"
		tab_container.add_child(node_editor)
		tab_container.set_tab_title(1, "Node Editor")

func has_open_tree(path: String) -> bool:
	return _open_editors.has(path)

func get_open_tree_paths() -> Array:
	return _open_editors.keys()
""",

"scripts/editor/bayterek_node_editor_screen.gd": """@tool
class_name BayterekNodeEditorScreen
extends MarginContainer

signal design_changed(design)
signal design_category_changed
signal dirty_changed(dirty)

const AUTOSAVE_DEBOUNCE_MS := 600
const MAX_UNDO_HISTORY := 100

var _undo_redo: UndoRedo = null
var _dirty: bool = false
var _autosave_countdown: float = 0.0
var _is_shutting_down: bool = false
var _loader: Node = null
var _current_design: BayterekNodeDesign = null

func _ready() -> void:
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	_undo_redo = UndoRedo.new()
	set_process(true)
	_loader = get_node_or_null("/root/BayterekLoader")
	if _loader and _loader.has_method("register_node_editor"):
		_loader.register_node_editor(self)

func _exit_tree() -> void:
	_is_shutting_down = true
	set_process(false)
	if _loader and _loader.has_method("unregister_node_editor"):
		_loader.unregister_node_editor(self)
	_loader = null
	_undo_redo = null

func _process(delta: float) -> void:
	if _is_shutting_down or _autosave_countdown <= 0.0: return
	_autosave_countdown -= delta
	if _autosave_countdown > 0.0: return
	_autosave_countdown = 0.0
	_flush_save()

func refresh() -> void:
	pass

func get_current_design() -> BayterekNodeDesign:
	return _current_design

func is_dirty() -> bool:
	return _dirty

func try_handle_undo() -> bool:
	if _is_shutting_down or not _undo_redo: return false
	if not _undo_redo.has_undo(): return false
	_undo_redo.undo()
	mark_dirty()
	return true

func try_handle_redo() -> bool:
	if _is_shutting_down or not _undo_redo: return false
	if not _undo_redo.has_redo(): return false
	_undo_redo.redo()
	mark_dirty()
	return true

func commit_undoable(action_name: String, do_cb: Callable, undo_cb: Callable) -> bool:
	if _is_shutting_down or not _current_design or not _undo_redo: return false
	_undo_redo.create_action(action_name)
	_undo_redo.add_do_method(do_cb)
	_undo_redo.add_undo_method(undo_cb)
	_undo_redo.commit_action()
	mark_dirty()
	return true

func mark_dirty() -> void:
	if _is_shutting_down: return
	if not _dirty:
		_dirty = true
		dirty_changed.emit(true)
	_autosave_countdown = AUTOSAVE_DEBOUNCE_MS / 1000.0

func _flush_save() -> void:
	if not _dirty or not _current_design: return
	var err: Error = BayterekDesignService.save_design(_current_design)
	if err == OK:
		_dirty = false
		dirty_changed.emit(false)
""",

"scripts/editor/bayterek_browser.gd": """@tool
class_name BayterekBrowser
extends MarginContainer

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

enum GroupMenuId { CREATE, DELETE, DUPLICATE }
enum TreeMenuId  { CREATE, DELETE, DUPLICATE }

var main_screen = null

func _ready() -> void:
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL

func init() -> void:
	pass
""",

# =========================================================================
# SCRIPTS / EDITOR / UI
# =========================================================================

"scripts/editor/ui/bayterek_design_list_panel.gd": """@tool
class_name BayterekDesignListPanel
extends VBoxContainer

signal design_selected(design)
signal collapsed_changed(collapsed)
signal design_category_changed

func _ready() -> void:
	size_flags_vertical = SIZE_EXPAND_FILL

func refresh() -> void:
	pass

func get_selected_design():
	return null
""",

"scripts/editor/ui/bayterek_procedural_grid.gd": """@tool
class_name BayterekProceduralGrid
extends Control

@export var cell_size: Vector2 = Vector2(16, 16)
@export var primary_line_step: int = 4
@export var line_color: Color = Color(1, 1, 1, 0.12)
@export var line_width: float = 1.0

var target: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if target: queue_redraw()

func _draw() -> void:
	if not target: return
	pass
""",

"scripts/editor/ui/fade_out.gd": """@tool
extends PanelContainer

var _fade_after: float = 3.0
var _fading: bool = false
var _fade_duration: float = 1.0
var _fade_timer: float = 0.0
var _paused: bool = false
var interactable: bool = true

func _ready() -> void:
	if interactable:
		mouse_entered.connect(func(): _paused = true)
		mouse_exited.connect(func(): _paused = false)

func _process(delta: float) -> void:
	if not _fading and not _paused:
		_fade_after -= delta
		if _fade_after <= 0.0 and _fade_timer <= 0.0:
			_fade_timer = _fade_duration
			_fading = true
	if _fading:
		if _fade_timer > 0.0:
			_fade_timer -= delta
			modulate.a = clamp(_fade_timer / _fade_duration, 0.0, 1.0)
		else:
			queue_free()
""",

"scripts/editor/ui/icon_button.gd": """@tool
extends Button

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

@export var icon_name: String = "Node":
	set(v):
		icon_name = v
		_update_icon()

func _enter_tree() -> void:
	_update_icon()

func _update_icon() -> void:
	if not Engine.is_editor_hint(): return
	var theme := EditorInterface.get_editor_theme()
	if theme.has_icon(icon_name, Bayterek.ICON_THEME):
		icon = theme.get_icon(icon_name, Bayterek.ICON_THEME)
""",

"scripts/editor/ui/line_edit_icon.gd": """@tool
extends LineEdit

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

@export var icon: String = "Node":
	set(v):
		icon = v
		_update_icon()

func _enter_tree() -> void:
	_update_icon()

func _update_icon() -> void:
	if has_theme_icon(icon, Bayterek.ICON_THEME):
		right_icon = get_theme_icon(icon, Bayterek.ICON_THEME)
""",

"scripts/editor/ui/texture_input.gd": """@tool
class_name BayterekInspectorTextureInput
extends HBoxContainer

signal texture_dropped(path: String)
signal cleared

@export var title: String = "Texture":
	set(v):
		title = v

func set_texture(_texture: Texture2D) -> void:
	pass
""",

# =========================================================================
# SCRIPTS / EDITOR / UTILITIES
# =========================================================================

"scripts/editor/fuzzy_search.gd": """@tool
class_name BayterekFuzzySearch
extends RefCounted

var case_sensitive: bool = false
var allow_subsequences: bool = true

func matches(query: String, target: String) -> bool:
	if query.is_empty(): return true
	if target.is_empty(): return false
	var q := query if case_sensitive else query.to_lower()
	var t := target if case_sensitive else target.to_lower()
	if t.find(q) != -1: return true
	if not allow_subsequences: return false
	var q_idx: int = 0
	for i in range(t.length()):
		if t[i] == q[q_idx]:
			q_idx += 1
			if q_idx >= q.length(): return true
	return false
""",

"scripts/editor/uuid_generator.gd": """@tool
class_name BayterekUUIDGenerator
extends RefCounted

static func v4() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bytes := PackedByteArray()
	bytes.resize(16)
	for i in range(16):
		bytes[i] = rng.randi_range(0, 255)
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80
	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
		bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15],
	]
""",
}

# ============================================================
# RUN
# ============================================================

func _run() -> void:
	print("")
	print("╔══════════════════════════════════════════════════╗")
	print("║   Bayterek Scaffolder                            ║")
	print("╚══════════════════════════════════════════════════╝")
	print("Target: ", ROOT)
	print("")

	var created_dirs: int = 0
	var skipped_dirs: int = 0
	var created_files: int = 0
	var skipped_files: int = 0

	# --- Directories ---
	print("── Directories ──")
	for rel in DIRS:
		var path: String = ROOT if rel.is_empty() else ROOT + "/" + rel
		if DirAccess.dir_exists_absolute(path):
			skipped_dirs += 1
			continue
		var err: Error = DirAccess.make_dir_recursive_absolute(path)
		if err != OK:
			push_error("  ✗ Could not create: %s (err=%d)" % [path, err])
		else:
			created_dirs += 1
			print("  ✓ Created: ", path)

	# --- Files ---
	print("")
	print("── Files ──")
	for rel in FILES.keys():
		var path: String = ROOT + "/" + rel
		if FileAccess.file_exists(path):
			skipped_files += 1
			continue
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			push_error("  ✗ Could not create: %s (err=%d)" % [path, FileAccess.get_open_error()])
			continue
		f.store_string(String(FILES[rel]))
		f.close()
		created_files += 1
		print("  ✓ Created: ", path)

	# --- Summary ---
	print("")
	print("──────────────────────────────────────────────────")
	print("Directories: %d created, %d existing" % [created_dirs, skipped_dirs])
	print("Files:       %d created, %d existing" % [created_files, skipped_files])
	print("──────────────────────────────────────────────────")

	if created_dirs == 0 and created_files == 0:
		print("Everything already exists. Nothing to do.")
	else:
		print("Rescanning filesystem...")
		EditorInterface.get_resource_filesystem().scan()

	print("")