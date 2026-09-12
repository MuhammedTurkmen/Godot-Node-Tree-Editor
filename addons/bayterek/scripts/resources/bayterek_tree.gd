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

var tree_state: BayterekTreeState

func get_next_id() -> int:
	id_counter += 1
	return id_counter
