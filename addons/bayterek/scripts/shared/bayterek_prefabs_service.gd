@tool
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
