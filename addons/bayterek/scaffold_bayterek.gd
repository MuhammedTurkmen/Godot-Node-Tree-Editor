@tool
extends EditorScript
## Bayterek Plugin Scaffolder
## addons/bayterek/ altındaki tüm klasör ve stub dosyaları oluşturur.
## Kullanım: Bu dosyayı Godot'ta aç → File > Run (Ctrl+Shift+X)
## Mevcut dosyaların üzerine YAZMAZ.

const ROOT := "res://addons/bayterek"

const DIRS := [
	"scenes",
	"scenes/editor",
	"scenes/shared",
	"scripts",
	"scripts/editor",
	"scripts/editor/ui",
	"scripts/resources",
	"scripts/runtime",
	"scripts/shared",
	"shortcuts",
]

const FILES := {

# =========================================================================
# ROOT
# =========================================================================

"plugin.cfg": """[plugin]

name="Bayterek"
description="Node-based tree editor (skill tree, passive tree, etc.) for Godot 4 Mono."
author="YourName"
version="0.1.0"
script="bayterek_plugin.gd"
""",

"bayterek_plugin.gd": """@tool
extends EditorPlugin
## Bayterek plugin entry point.
## TODO: Ana ekran, autoload'lar, project settings.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

func _enter_tree() -> void:
	pass

func _exit_tree() -> void:
	pass
""",

# =========================================================================
# SCRIPTS / SHARED
# =========================================================================

"scripts/shared/bayterek.gd": """@tool
class_name Bayterek
extends RefCounted
## Global sabitler ve yardımcı fonksiyonlar.

const VERSION := "0.1.0"

const ROOT_PATH_SETTING := "addons/bayterek/root_path"
const DEFAULT_ROOT_PATH := "res://bayterek_data"
const REGISTRY_FILENAME_SETTING := "addons/bayterek/registry_filename"
const DEFAULT_REGISTRY_FILENAME := "registry.tres"

const ICON_THEME := &"EditorIcons"
const GROUP_ICON := "Folder"
const TREE_ICON := "KeyValue"

# TODO: blank_icon.png ekle -> preload("res://addons/bayterek/blank_icon.png")
const BlankIcon: Texture2D = null

enum AllocationState {
	NORMAL,
	INTERMEDIATE,
	ACTIVE,
	PREALLOCATED_INTERMEDIATE,
	PREALLOCATED_ACTIVE,
	REFUND,
}

static func get_root_path() -> String:
	return ProjectSettings.get_setting(ROOT_PATH_SETTING, DEFAULT_ROOT_PATH)

static func get_registry_filename() -> String:
	return ProjectSettings.get_setting(REGISTRY_FILENAME_SETTING, DEFAULT_REGISTRY_FILENAME)

static func get_registry_path() -> String:
	return "%s/%s" % [get_root_path(), get_registry_filename()]
""",

"scripts/shared/bayterek_base_service.gd": """@tool
class_name BayterekBaseService
extends RefCounted
## Tüm servislerin türediği temel sınıf.

var _tree_view: BayterekTreeView
var _tree_data: BayterekTree
var _scene: PackedScene

func _init(tree_view: BayterekTreeView) -> void:
	_tree_view = tree_view

func set_scene(scene: PackedScene) -> void:
	_scene = scene
""",

"scripts/shared/bayterek_camera.gd": """@tool
class_name BayterekCamera
extends RefCounted
## Pan + zoom kamerası.

signal zoom_changed(zoom: float, previous_zoom: float)

var _viewport: Control
var _bounds: Rect2
var _zoom: float = 1.0
""",

"scripts/shared/bayterek_connection.gd": """@tool
class_name BayterekConnection
extends Line2D
## Node bağlantı çizgisi.
""",

"scripts/shared/bayterek_line_data.gd": """@tool
class_name BayterekLineData
extends Resource
## Bir bağlantının görsel verisi.

enum LineType {
	STRAIGHT,
	BEZIER,
	ARC,
}

@export var line_type: LineType = LineType.STRAIGHT
@export var curve_height: float = 48.0
@export var segments: int = 16
@export var reversed: bool = false
""",

"scripts/shared/bayterek_loader.gd": """@tool
extends Node
## Autoload: BayterekLoader. Registry ve tree yükleme API'si.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

var _registry: BayterekRegistry

func get_registry() -> BayterekRegistry:
	return _registry

func load_tree(path: String, as_unique: bool = false) -> BayterekTree:
	# TODO
	return null

func add_tree_to_registry(group: BayterekGroup, tree: BayterekTree) -> void:
	# TODO
	pass
""",

"scripts/shared/bayterek_node_button.gd": """@tool
class_name BayterekNodeButton
extends BaseButton
## Tek bir node'un sahnedeki görsel temsili.

signal node_hovered(node: BayterekNodeButton, is_hovered: bool)

var tree: BayterekTree
var tree_view: BayterekTreeView
var node_data: BayterekNode
var prefab: BayterekPrefab
var allocated: bool = false
var preallocated: bool = false
var refund: bool = false
var allocation_level: int = 0
var state: Bayterek.AllocationState = Bayterek.AllocationState.NORMAL
""",

"scripts/shared/bayterek_tooltip.gd": """@tool
class_name BayterekTooltip
extends Control
## Node hover tooltip.

@export var label: RichTextLabel

func inspect(node: BayterekNodeButton) -> void:
	# TODO
	pass

func reset() -> void:
	if label:
		label.text = ""
""",

"scripts/shared/bayterek_tree_view.gd": """@tool
class_name BayterekTreeView
extends Control
## Runtime tree görünümü.

signal node_created(node: BayterekNode)
signal node_allocated(node: BayterekNode)
signal node_deallocated(node: BayterekNode)
signal prefab_created(prefab: BayterekPrefab)
signal line_created(line: BayterekConnection, from_id: int, to_id: int)
signal tree_version_mismatch(tree: BayterekTree, saved_version: int)

var main_container: Control
var nodes_container: Control
var lines_container: Control
var decorations_container: Control
var background_container: Control

var camera: BayterekCamera
var nodes_service: BayterekNodesService
var connections_service: BayterekConnectionsService
var decorations_service: BayterekDecorationsService
var prefabs_service: BayterekPrefabsService
var allocation_service: BayterekAllocationService

var _tree_data: BayterekTree

func load_tree(tree_data: BayterekTree, decoration_scene: PackedScene, node_scene: PackedScene, line_scene: PackedScene, tooltip_scene: PackedScene) -> void:
	# TODO
	pass
""",

"scripts/shared/bayterek_builder.gd": """@tool
class_name BayterekBuilder
extends RefCounted
## BayterekTreeView inşa edicisi.

var _tree: BayterekTree
var _parent: Node

func _init(tree_data: BayterekTree) -> void:
	_tree = tree_data

func set_parent(parent: Node) -> BayterekBuilder:
	_parent = parent
	return self

func build() -> BayterekTreeView:
	# TODO
	return null
""",

"scripts/shared/bayterek_nodes_service.gd": """@tool
class_name BayterekNodesService
extends BayterekBaseService
## Node oluşturma / silme / yönetme.

signal node_created(node: BayterekNodeButton)
signal node_pressed(node: BayterekNodeButton)
signal node_hovered(node: BayterekNodeButton, is_hovered: bool)

var _nodes: Dictionary[int, BayterekNodeButton] = {}

func load_tree(tree_data: BayterekTree) -> void:
	_tree_data = tree_data

func get_node(node_id: int) -> BayterekNodeButton:
	return _nodes.get(node_id, null)
""",

"scripts/shared/bayterek_connections_service.gd": """@tool
class_name BayterekConnectionsService
extends BayterekBaseService
## Bağlantı oluşturma / güncelleme.

signal line_created(line: BayterekConnection, from_id: int, to_id: int)
signal node_connected(from_node: BayterekNodeButton, to_id: int)
signal node_disconnected(from_node: BayterekNodeButton, to_id: int)

func load_tree(tree_data: BayterekTree) -> void:
	_tree_data = tree_data

func create_connection(from_node: BayterekNodeButton, to_node: BayterekNodeButton) -> void:
	# TODO
	pass

func update_connected_lines(node: BayterekNodeButton) -> void:
	# TODO
	pass
""",

"scripts/shared/bayterek_decorations_service.gd": """@tool
class_name BayterekDecorationsService
extends BayterekBaseService
## Dekor node'ları yönetimi.

signal decoration_created(decoration: BayterekNodeButton)
signal decoration_pressed(node: BayterekNodeButton)

func load_tree(tree_data: BayterekTree) -> void:
	_tree_data = tree_data
""",

"scripts/shared/bayterek_prefabs_service.gd": """@tool
class_name BayterekPrefabsService
extends BayterekBaseService
## Prefab oluşturma / senkronizasyon.

signal prefab_created(prefab: BayterekPrefab)

var prefabs: Dictionary = {}
var _ref_id_to_prefab: Dictionary = {}

func load_tree(tree_data: BayterekTree) -> void:
	_tree_data = tree_data

func get_prefab_by_reference_id(reference_id: String) -> BayterekPrefab:
	return _ref_id_to_prefab.get(reference_id, null)
""",

"scripts/shared/bayterek_allocation_service.gd": """@tool
class_name BayterekAllocationService
extends BayterekBaseService
## Allocation / preallocation / refund yönetimi.

signal node_preallocated(node: BayterekNodeButton)
signal node_unpreallocated(node: BayterekNodeButton)
signal node_allocated(node: BayterekNodeButton)
signal node_deallocated(node: BayterekNodeButton)
signal refund_mode_entered
signal refund_mode_exited
signal node_refund_added(node: BayterekNodeButton)
signal node_refund_removed(node: BayterekNodeButton)

var preallocation_check: Callable
var allocation_check: Callable
var deallocation_check: Callable
var refund_check: Callable

var _preallocated_nodes: Array[int] = []
var _refund_nodes: Array[int] = []
var _refund_mode: bool = false

func load_tree(tree_data: BayterekTree) -> void:
	_tree_data = tree_data

func on_node_pressed(node: BayterekNodeButton) -> void:
	# TODO
	pass
""",

# =========================================================================
# SCRIPTS / RESOURCES
# =========================================================================

"scripts/resources/bayterek_registry.gd": """@tool
class_name BayterekRegistry
extends Resource
## Tüm grupları tutan kök resource.

@export_storage var groups: Array[BayterekGroup] = []
""",

"scripts/resources/bayterek_group.gd": """@tool
class_name BayterekGroup
extends Resource
## Tree grubu.

@export_storage var name: String
@export_storage var trees: Array[BayterekTree] = []
""",

"scripts/resources/bayterek_tree.gd": """@tool
class_name BayterekTree
extends Resource
## Ana ağaç verisi.

@export_storage var version: int = 1
@export_storage var id: String
@export_storage var name: String
@export_storage var revealed: bool = true
@export_storage var allocation: bool = true
@export_storage var preallocation: bool = true
@export_storage var multiallocation: bool = false

@export_storage var size: Vector2 = Vector2(5000, 5000)
@export_storage var bg_color: Color = Color(0.1, 0.1, 0.1)
@export_storage var bg_texture: Texture2D
@export_storage var line_texture_normal: Texture2D
@export_storage var line_texture_intermediate: Texture2D
@export_storage var line_texture_active: Texture2D

@export_storage var id_counter: int = 0
@export_storage var border_scale: float = 1.5
@export_storage var icon_sizes: Dictionary = {}
@export_storage var icons: Dictionary = {}
@export_storage var node_size: Dictionary = {}
@export_storage var nodes: Array[BayterekNode] = []
@export_storage var decorations: Array[BayterekNode] = []
@export_storage var prefabs: Dictionary = {}
@export_storage var attributes: Dictionary = {}

var tree_state: BayterekTreeState

func get_next_id() -> int:
	id_counter += 1
	return id_counter
""",

"scripts/resources/bayterek_node.gd": """@tool
class_name BayterekNode
extends Resource
## Tek bir node'un veri modeli.

enum NodeType {
	SMALL,
	MEDIUM,
	LARGE,
	DECORATION,
}

@export_storage var is_root: bool = false
@export_storage var reference_id: String = ""
@export_storage var id: int = 0
@export_storage var external_id: String = ""
@export_storage var name: String = ""
@export_storage var description: String = ""

@export_storage var type: NodeType = NodeType.SMALL
@export_storage var icon: Texture2D
@export_storage var border_normal: Texture2D
@export_storage var border_intermediate: Texture2D
@export_storage var border_active: Texture2D

@export_storage var position: Vector2 = Vector2.ZERO
@export_storage var line_data: Dictionary = {}
@export_storage var out_nodes: Array[int] = []
@export_storage var in_nodes: Array[int] = []
@export_storage var attributes: Dictionary = {}
@export_storage var max_allocations: int = 1
@export_storage var locked: bool = false
""",

"scripts/resources/bayterek_attribute.gd": """@tool
class_name BayterekAttribute
extends Resource
## Attribute tanımı.

@export_storage var id: String
@export_storage var name: String
@export_storage var effect: String
@export_storage var value_count: int = 0
""",

"scripts/resources/bayterek_prefab.gd": """@tool
class_name BayterekPrefab
extends Resource
## Paylaşılan node şablonu.

signal name_changed(prefab: BayterekPrefab)
signal description_changed(prefab: BayterekPrefab)
signal icon_changed(prefab: BayterekPrefab)
signal border_changed(prefab: BayterekPrefab)
signal attribute_changed(prefab: BayterekPrefab, attribute_id: String, removed: bool)
signal max_allocations_changed(prefab: BayterekPrefab)

@export_storage var reference_id: String
@export_storage var id: String
@export_storage var node_name: String
@export_storage var description: String
@export_storage var type: BayterekNode.NodeType = BayterekNode.NodeType.SMALL
@export_storage var icon: Texture2D
@export_storage var border_normal: Texture2D
@export_storage var border_intermediate: Texture2D
@export_storage var border_active: Texture2D
@export_storage var attributes: Dictionary = {}
@export_storage var max_allocations: int = 1

var nodes: Array[BayterekNodeButton] = []
""",

"scripts/resources/bayterek_tree_state.gd": """@tool
class_name BayterekTreeState
extends RefCounted
## Runtime allocation durumu.

var version: int = 1
var allocated_nodes: Array[int] = []
var allocation_level: Dictionary = {}
""",

# =========================================================================
# SCRIPTS / RUNTIME
# =========================================================================

"scripts/runtime/bayterek_serializer.gd": """@tool
extends Node
## Autoload: BayterekSerializer. Runtime tree state kaydetme / yükleme.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

const OLD_SAVE_PATH := "user://bayterek"
const SAVE_PATH := "user://bayterek_v2"

func save_tree_state(tree: BayterekTree, custom_path: String = "") -> void:
	# TODO
	pass

func load_tree_state(tree: BayterekTree, custom_path: String = "") -> void:
	# TODO
	pass
""",

# =========================================================================
# SCRIPTS / EDITOR
# =========================================================================

"scripts/editor/bayterek_main_screen.gd": """@tool
class_name BayterekMainScreen
extends Control
## Ana ekran (Browser + Editor sekmeleri).

signal update_available(version: String)
signal dirty_changed(editor: BayterekEditor, dirty: bool)
signal tree_closed(editor: BayterekEditor)

@export var tab_container: TabContainer
@export var browser: BayterekBrowser
@export var editor_scene: PackedScene
@export var save_confirmation: ConfirmationDialog
@export var http_request: HTTPRequest

var initialized: bool = false

func init() -> void:
	initialized = true

func open_tree(path: String) -> void:
	# TODO
	pass
""",

"scripts/editor/bayterek_browser.gd": """@tool
class_name BayterekBrowser
extends Control
## Grup / tree listeleme, oluşturma, silme.

@export var main_screen: BayterekMainScreen
@export var tree_ui: BayterekTreeUI
@export var search_bar: LineEdit
@export var group_menu: MenuButton
@export var tree_menu: MenuButton
@export var load_time_label: Label
@export var groups_count_label: Label
@export var trees_count_label: Label
@export var version_label: RichTextLabel
@export var delete_confirmation: ConfirmationDialog
@export var docs_button: Button

func init() -> void:
	# TODO
	pass
""",

"scripts/editor/bayterek_editor.gd": """@tool
class_name BayterekEditor
extends Control
## Graph editörü.

signal dirty_changed(editor: BayterekEditor, dirty: bool)
signal tree_closed(editor: BayterekEditor)
signal node_deleted(node: BayterekNodeButton)
signal node_selected(node: BayterekNodeButton)
signal node_moved(node: BayterekNodeButton, new_position: Vector2)
signal node_attribute_changed(node: BayterekNodeButton, attribute_id: String, removed: bool)

var tree: BayterekTree
var selected_nodes: Array[BayterekNodeButton] = []
var dirty: bool = false

func init() -> void:
	# TODO
	pass

func edit_tree(path: String) -> void:
	# TODO
	pass

func save_tree() -> void:
	# TODO
	pass

func close_tree() -> void:
	# TODO
	pass
""",

"scripts/editor/bayterek_hierarchy.gd": """@tool
class_name BayterekTreeHierarchy
extends Tree
## Sol panel hiyerarşi.

signal changed

@export var editor: BayterekEditor

func init() -> void:
	# TODO
	pass
""",

"scripts/editor/bayterek_inspector.gd": """@tool
class_name BayterekTreeEditorInspector
extends Control
## Node Inspector.

signal changed

@export var editor: BayterekEditor
@export var icon_selector: BayterekIconSelector

func init(tree_view: BayterekTreeView) -> void:
	# TODO
	pass
""",

"scripts/editor/bayterek_settings.gd": """@tool
class_name BayterekSettingsEditor
extends Control
## Tree Settings editörü.

signal changed
signal size_changed
signal border_scale_changed
signal background_changed
signal icon_size_changed
signal node_size_changed
signal line_texture_changed
signal revealed_changed
signal allocation_changed
signal preallocation_changed
signal multiallocation_changed

@export var editor: BayterekEditor

func init() -> void:
	# TODO
	pass

func load_tree(tree_data: BayterekTree) -> void:
	# TODO
	pass
""",

"scripts/editor/bayterek_attributes_editor.gd": """@tool
class_name BayterekAttributesEditor
extends Control
## Attribute listesi editörü.

signal changed

@export var editor: BayterekEditor
@export var add_button: Button
@export var filter_input: LineEdit
@export var tree: BayterekTreeUI

func init() -> void:
	# TODO
	pass

func load_tree() -> void:
	# TODO
	pass
""",

"scripts/editor/bayterek_editor_context.gd": """@tool
class_name BayterekEditorContext
extends PopupMenu
## Sağ tık context menu.

signal new_node(node_type: int)
signal duplicate_node
signal delete_node
signal save_as_prefab
signal save_as_copy
signal make_unique

@export var editor: BayterekEditor

func init() -> void:
	# TODO
	pass

func update_items(node: BayterekNodeButton) -> void:
	# TODO
	pass
""",

"scripts/editor/bayterek_icon_selector.gd": """@tool
class_name BayterekIconSelector
extends Popup
## Spritesheet icon seçici.

signal icon_selected(node_type: int, texture: Texture2D, region: Vector2)

@export var editor: BayterekEditor

func init() -> void:
	# TODO
	pass

func load_icons(node_type: int) -> void:
	# TODO
	pass
""",

"scripts/editor/bayterek_prefabs_bar.gd": """@tool
class_name BayterekPrefabsBar
extends TabBar
## Prefab alt bar.

signal changed

@export var editor: BayterekEditor
@export var prefab_panel_scene: PackedScene
@export var splitter: SplitContainer
@export var prefabs_panel: Control

func init() -> void:
	# TODO
	pass
""",

"scripts/editor/bayterek_prefabs_panel.gd": """@tool
class_name BayterekPrefabPanelEditor
extends Control
## Prefab listesi paneli.

signal changed

@export var filter: LineEdit
@export var list: ItemList

var editor: BayterekEditor

func add_prefab(prefab: BayterekPrefab, is_copy: bool = false) -> void:
	# TODO
	pass
""",

"scripts/editor/bayterek_prefab_drop.gd": """@tool
class_name BayterekPrefabDrop
extends Control
## Prefab drag-drop alanı.

signal prefab_dropped(prefab: BayterekPrefab)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is BayterekPrefab

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	prefab_dropped.emit(data)
""",

"scripts/editor/bayterek_selection_box.gd": """@tool
class_name BayterekSelectionBox
extends Panel
## Alan seçim kutusu.

signal selected(rect: Rect2)

var selecting: bool = false
var _view: BayterekTreeView

func set_view(view: BayterekTreeView) -> void:
	_view = view
""",

"scripts/editor/bayterek_move_tool.gd": """@tool
class_name BayterekMoveTool
extends Control
## Node taşıma oku.

signal moved(positions: Array[Vector2])
signal released(positions: Array[Vector2], start_positions: Array[Vector2])

var nodes: Array[BayterekNodeButton] = []
""",

"scripts/editor/bayterek_validator.gd": """@tool
class_name BayterekValidator
extends Control
## Tree uyarı / hata denetleyici.

@export var editor: BayterekEditor
@export var prints_container: Control
@export var warning_btn: Button
@export var error_btn: Button

func init() -> void:
	# TODO
	pass

func validate() -> void:
	# TODO
	pass
""",

"scripts/editor/fuzzy_search.gd": """@tool
class_name BayterekFuzzySearch
extends RefCounted
## Godot'un core fuzzy_search portu.
## TODO: Orijinal yggdrasil'deki implementasyonu buraya taşı.

var tokens: Array = []
var case_sensitive: bool = false
var start_offset: int = 0
var max_results: int = 100
var max_misses: int = 2
var allow_subsequences: bool = true

func set_query(_query: String, _case_sensitive: bool = false) -> void:
	# TODO
	pass

func search(_target: String, _result) -> bool:
	# TODO
	return false

func search_all(_targets: PackedStringArray, _results: Array) -> void:
	# TODO
	pass
""",

"scripts/editor/uuid_generator.gd": """@tool
class_name BayterekUUIDGenerator
extends RefCounted
## UUID v4 üretici.

static func v4() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bytes := PackedByteArray()
	bytes.resize(16)
	for i in range(16):
		bytes[i] = rng.randi_range(0, 255)
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80
	return _bytes_to_uuid(bytes)

static func _bytes_to_uuid(bytes: PackedByteArray) -> String:
	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		bytes[0], bytes[1], bytes[2], bytes[3],
		bytes[4], bytes[5],
		bytes[6], bytes[7],
		bytes[8], bytes[9],
		bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15],
	]
""",

# =========================================================================
# SCRIPTS / EDITOR / UI
# =========================================================================

"scripts/editor/ui/fade_out.gd": """@tool
extends PanelContainer
## Fade-out bildirim paneli.

var _fade_after: float = 3.0
var _fading: bool = false
var _fade_duration: float = 1.0
var _fade_timer: float = 0.0
var _paused: bool = false
var interactable: bool = true
""",

"scripts/editor/ui/icon_button.gd": """@tool
extends Button
## Editör ikonu taşıyan buton.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

@export var icon_name: String = "Node":
	set(value):
		icon_name = value
		_update_icon()

func _enter_tree() -> void:
	_update_icon()

func _update_icon() -> void:
	if not Engine.is_editor_hint():
		return
	var theme := EditorInterface.get_editor_theme()
	if theme.has_icon(icon_name, Bayterek.ICON_THEME):
		icon = theme.get_icon(icon_name, Bayterek.ICON_THEME)
	else:
		icon = null
""",

"scripts/editor/ui/line_edit_icon.gd": """@tool
extends LineEdit
## Sağ ikonlu LineEdit.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

@export var icon: String = "Node":
	set(value):
		icon = value
		_update_icon()

func _enter_tree() -> void:
	_update_icon()

func _update_icon() -> void:
	if has_theme_icon(icon, Bayterek.ICON_THEME):
		right_icon = get_theme_icon(icon, Bayterek.ICON_THEME)
	else:
		right_icon = null
""",

"scripts/editor/ui/texture_input.gd": """@tool
class_name BayterekInspectorTextureInput
extends Control
## Texture input widget'ı (drag-drop + browse + clear).

signal texture_dropped(path: String)

@export var title: String
@export var title_label: Label
@export var texture_rect: TextureRect
@export var load_button: Button
@export var clear_button: Button
@export var empty_label: Label

func _enter_tree() -> void:
	if title_label:
		title_label.text = title
""",

"scripts/editor/ui/bayterek_procedural_grid.gd": """@tool
class_name BayterekProceduralGrid
extends Control
## Prosedürel grid çizimi.

@export var primary_line_step: int = 4
@export var line_color: Color = Color(1, 1, 1, 0.12)
@export var line_width: float = 1.0
var cell_size: Vector2 = Vector2(16, 16)
var parent: Control
""",

"scripts/editor/ui/bayterek_tree_ui.gd": """@tool
class_name BayterekTreeUI
extends Tree
## Yeniden adlandırma destekli Tree.

signal edit_started(item: TreeItem)
signal edit_canceled(item: TreeItem)

@export var rename_shortcut: Shortcut

func init() -> void:
	create_item()
""",

# =========================================================================
# SHORTCUTS
# =========================================================================

"shortcuts/save.tres": """[gd_resource type="Shortcut" format=3]

[sub_resource type="InputEventKey" id="InputEventKey_save"]
device = -1
ctrl_pressed = true
keycode = 83

[resource]
events = [SubResource("InputEventKey_save")]
""",

"shortcuts/close.tres": """[gd_resource type="Shortcut" format=3]

[sub_resource type="InputEventKey" id="InputEventKey_close"]
device = -1
ctrl_pressed = true
keycode = 87

[resource]
events = [SubResource("InputEventKey_close")]
""",

"shortcuts/delete.tres": """[gd_resource type="Shortcut" format=3]

[sub_resource type="InputEventKey" id="InputEventKey_delete"]
device = -1
keycode = 4194312

[resource]
events = [SubResource("InputEventKey_delete")]
""",

"shortcuts/duplicate.tres": """[gd_resource type="Shortcut" format=3]

[sub_resource type="InputEventKey" id="InputEventKey_dupe"]
device = -1
ctrl_pressed = true
keycode = 68

[resource]
events = [SubResource("InputEventKey_dupe")]
""",

"shortcuts/undo.tres": """[gd_resource type="Shortcut" format=3]

[sub_resource type="InputEventKey" id="InputEventKey_undo"]
device = -1
ctrl_pressed = true
keycode = 90

[resource]
events = [SubResource("InputEventKey_undo")]
""",

"shortcuts/redo.tres": """[gd_resource type="Shortcut" format=3]

[sub_resource type="InputEventKey" id="InputEventKey_redo1"]
device = -1
ctrl_pressed = true
shift_pressed = true
keycode = 90

[sub_resource type="InputEventKey" id="InputEventKey_redo2"]
device = -1
ctrl_pressed = true
keycode = 89

[resource]
events = [SubResource("InputEventKey_redo1"), SubResource("InputEventKey_redo2")]
""",

"shortcuts/rename.tres": """[gd_resource type="Shortcut" format=3]

[sub_resource type="InputEventKey" id="InputEventKey_rename"]
device = -1
keycode = 4194333

[resource]
events = [SubResource("InputEventKey_rename")]
""",

"shortcuts/new_group.tres": """[gd_resource type="Shortcut" format=3]

[sub_resource type="InputEventKey" id="InputEventKey_ng"]
device = -1
ctrl_pressed = true
keycode = 66

[resource]
events = [SubResource("InputEventKey_ng")]
""",

"shortcuts/new_tree.tres": """[gd_resource type="Shortcut" format=3]

[sub_resource type="InputEventKey" id="InputEventKey_nt"]
device = -1
ctrl_pressed = true
keycode = 78

[resource]
events = [SubResource("InputEventKey_nt")]
""",
}

# =========================================================================
# RUN
# =========================================================================

func _run() -> void:
	print("=== Bayterek Scaffolder başladı ===")
	print("Hedef: ", ROOT)
	_create_dirs()
	_create_files()
	print("=== Tamamlandı. Editör dosya sistemini tarıyor... ===")
	EditorInterface.get_resource_filesystem().scan()

func _create_dirs() -> void:
	for rel: String in DIRS:
		var path: String = ROOT if rel.is_empty() else ROOT + "/" + rel
		if DirAccess.dir_exists_absolute(path):
			continue
		var err: Error = DirAccess.make_dir_recursive_absolute(path)
		if err != OK:
			push_error("Klasör oluşturulamadı: %s (hata=%s)" % [path, err])
		else:
			print("Klasör: ", path)

func _create_files() -> void:
	for rel: String in FILES.keys():
		var full: String = ROOT + "/" + rel
		if FileAccess.file_exists(full):
			print("Atlandı (mevcut): ", full)
			continue
		var f: FileAccess = FileAccess.open(full, FileAccess.WRITE)
		if f == null:
			push_error("Dosya oluşturulamadı: %s" % full)
			continue
		f.store_string(String(FILES[rel]))
		f.close()
		print("Dosya: ", full)
