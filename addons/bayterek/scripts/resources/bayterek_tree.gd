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

## When true, allocation requires a Confirm step (preallocation mode).
## When false (default), clicking a node allocates it immediately.
@export_storage var allocation_confirm: bool = false

## When true, refund requires a Confirm step (staging mode).
## When false (default), clicking a node in refund mode deallocates it immediately.
@export_storage var refund_confirm: bool = false

## Runtime'da (oyun içinde) grup frame'lerinin görünüp görünmemesi.
## Editörde her zaman görünür — bu sadece runtime için geçerli.
@export_storage var show_group_frames: bool = false

## Frame title'larının hizalaması:
## 0 = Sol (normal), 1 = Ortalanmış (centered)
@export_storage var group_frame_title_align: int = 0

## Tooltip alignment settings.
## 0 = Left, 1 = Center, 2 = Right
@export_storage var tooltip_header_align: int = 0
@export_storage var tooltip_body_align: int = 0
@export_storage var tooltip_footer_align: int = 1

@export_storage var size: Vector2 = Vector2(5000, 5000)
@export_storage var bg_color: Color = Color(0.1, 0.1, 0.1)
@export_storage var bg_texture: Texture2D
@export_storage var line_texture_normal: Texture2D
@export_storage var line_texture_intermediate: Texture2D
@export_storage var line_texture_active: Texture2D

## Texture filter for nodes, borders, icons.
## 0 = Linear (smooth, default)
## 1 = Nearest (pixel art)
@export_storage var texture_filter: int = 0

@export_storage var id_counter: int = 0
@export_storage var border_scale: float = 1.5
@export_storage var icon_sizes: Dictionary = {}
@export_storage var icons: Dictionary = {}
@export_storage var node_size: Dictionary = {}
@export_storage var nodes: Array[BayterekNode] = []
@export_storage var decorations: Array[BayterekNode] = []
@export_storage var prefabs: Dictionary = {}
@export_storage var attributes: Dictionary = {}

## Node groups (visual + logical prerequisite grouping)
@export_storage var node_groups: Array[BayterekNodeGroup] = []

# Editor layout
@export_storage var hierarchy_split_offset: int = 200
@export_storage var prefabs_split_offset: int = -180
@export_storage var inspector_split_offset: int = -320

# ============================================================
# DEFAULT NODE VISUALS — used when creating new nodes
# ============================================================

# Border textures
@export_storage var default_border_texture_locked: Texture2D = null
@export_storage var default_border_texture_normal: Texture2D = null
@export_storage var default_border_texture_hover: Texture2D = null
@export_storage var default_border_texture_max_level: Texture2D = null

# Border colors
@export_storage var default_border_color_locked: Color = Color(0.5, 0.5, 0.5, 1.0)
@export_storage var default_border_color_normal: Color = Color(1, 1, 1, 1)
@export_storage var default_border_color_hover: Color = Color(1.2, 1.2, 1.2, 1)
@export_storage var default_border_color_allocate: Color = Color(1.0, 0.9, 0.3, 1)
@export_storage var default_border_color_refund: Color = Color(1.0, 0.4, 0.4, 1)
@export_storage var default_border_color_max_level: Color = Color(1.0, 0.85, 0.2, 1)
@export_storage var default_border_color_allocatable: Color = Color(0.6, 1.0, 0.6, 1)
@export_storage var default_border_color_not_allocatable: Color = Color(0.6, 0.6, 0.6, 1)

# Icon textures
@export_storage var default_icon_texture_locked: Texture2D = null
@export_storage var default_icon_texture_normal: Texture2D = null
@export_storage var default_icon_texture_hover: Texture2D = null
@export_storage var default_icon_texture_max_level: Texture2D = null

# Icon colors
@export_storage var default_icon_color_locked: Color = Color(0.5, 0.5, 0.5, 1.0)
@export_storage var default_icon_color_normal: Color = Color(1, 1, 1, 1)
@export_storage var default_icon_color_hover: Color = Color(1.2, 1.2, 1.2, 1)
@export_storage var default_icon_color_allocate: Color = Color(1.0, 0.9, 0.3, 1)
@export_storage var default_icon_color_refund: Color = Color(1.0, 0.4, 0.4, 1)
@export_storage var default_icon_color_max_level: Color = Color(1.0, 0.85, 0.2, 1)
@export_storage var default_icon_color_allocatable: Color = Color(0.6, 1.0, 0.6, 1)
@export_storage var default_icon_color_not_allocatable: Color = Color(0.6, 0.6, 0.6, 1)

var tree_state: BayterekTreeState

func _init() -> void:
	nodes = []
	decorations = []
	prefabs = {}
	attributes = {}
	node_groups = []
	icon_sizes = {
		BayterekNode.NodeType.SMALL: Vector2.ZERO,
		BayterekNode.NodeType.MEDIUM: Vector2.ZERO,
		BayterekNode.NodeType.LARGE: Vector2.ZERO
	}
	icons = {
		BayterekNode.NodeType.SMALL: null,
		BayterekNode.NodeType.MEDIUM: null,
		BayterekNode.NodeType.LARGE: null
	}
	node_size = {
		BayterekNode.NodeType.SMALL: Vector2(27, 27),
		BayterekNode.NodeType.MEDIUM: Vector2(48, 48),
		BayterekNode.NodeType.LARGE: Vector2(64, 64)
	}
	tree_state = BayterekTreeState.new()

	hierarchy_split_offset = 200
	prefabs_split_offset = -180
	inspector_split_offset = -320

func get_next_id() -> int:
	id_counter += 1
	return id_counter

func get_node_size(node_type: BayterekNode.NodeType) -> Vector2:
	return node_size.get(node_type, Vector2.ZERO)

## Returns the Godot texture filter enum value for CanvasItem.
func get_godot_texture_filter() -> int:
	match texture_filter:
		1: return CanvasItem.TEXTURE_FILTER_NEAREST
		_: return CanvasItem.TEXTURE_FILTER_LINEAR

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

## Returns the group a node belongs to, or null if ungrouped.
func get_group_of_node(node_id: int) -> BayterekNodeGroup:
	for node_data in nodes:
		if node_data.id == node_id:
			if node_data.group_id.is_empty():
				return null
			return get_group_by_id(node_data.group_id)
	return null