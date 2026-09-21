@tool
class_name BayterekTree
extends Resource
## Main tree data.

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

@export_storage var show_group_frames: bool = false
@export_storage var group_frame_title_align: int = 0

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

# Editor layout
@export_storage var hierarchy_split_offset: int = 200
@export_storage var prefabs_split_offset: int = -180
@export_storage var inspector_split_offset: int = -320

## Prefab bar görünürlüğü (kalıcı).
@export_storage var prefabs_bar_visible: bool = true

## Default design applied to newly created nodes.
@export_storage var default_design_id: String = ""

var tree_state: BayterekTreeState

func _init() -> void:
	nodes = []
	decorations = []
	prefabs = []
	attributes = {}
	node_groups = []
	tree_state = BayterekTreeState.new()

	hierarchy_split_offset = 200
	prefabs_split_offset = -180
	inspector_split_offset = -320

func get_next_id() -> int:
	id_counter += 1
	return id_counter

func get_godot_texture_filter() -> int:
	match texture_filter:
		1: return CanvasItem.TEXTURE_FILTER_NEAREST
		_: return CanvasItem.TEXTURE_FILTER_LINEAR

# ============================================================
# PREFAB HELPERS
# ============================================================

func get_prefab_by_reference_id(reference_id: String) -> BayterekPrefab:
	if reference_id.is_empty():
		return null
	for p in prefabs:
		if p and p.reference_id == reference_id:
			return p
	return null

func add_prefab(prefab: BayterekPrefab) -> void:
	if not prefab:
		return
	if prefabs.has(prefab):
		return
	prefabs.append(prefab)

func remove_prefab(prefab: BayterekPrefab) -> void:
	prefabs.erase(prefab)

# ============================================================
# GROUP HELPERS
# ============================================================

func get_group_by_id(group_id: String) -> BayterekNodeGroup:
	if group_id.is_empty():
		return null
	for g in node_groups:
		if g and g.id == group_id:
			return g
	return null

func add_group(group: BayterekNodeGroup) -> void:
	if not group:
		return
	if group.id.is_empty():
		group.id = BayterekNodeGroup.generate_id()
	node_groups.append(group)

func remove_group(group: BayterekNodeGroup) -> void:
	node_groups.erase(group)

func get_group_of_node(node_id: int) -> BayterekNodeGroup:
	for node_data in nodes:
		if node_data.id == node_id:
			if node_data.group_id.is_empty():
				return null
			return get_group_by_id(node_data.group_id)
	return null