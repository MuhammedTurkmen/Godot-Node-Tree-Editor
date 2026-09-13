@tool
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

# Editor layout
@export_storage var hierarchy_split_offset: int = 200
@export_storage var prefabs_split_offset: int = -180
@export_storage var inspector_split_offset: int = -320

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

	# Editor layout defaults (eski .tres dosyaları için garantile)
	hierarchy_split_offset = 200
	prefabs_split_offset = -180
	inspector_split_offset = -320

func get_next_id() -> int:
	id_counter += 1
	return id_counter

func get_node_size(node_type: BayterekNode.NodeType) -> Vector2:
	return node_size.get(node_type, Vector2.ZERO)