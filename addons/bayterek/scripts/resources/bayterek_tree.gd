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