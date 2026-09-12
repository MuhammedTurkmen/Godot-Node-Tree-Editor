@tool
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
