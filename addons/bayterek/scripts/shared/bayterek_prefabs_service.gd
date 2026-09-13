@tool
class_name BayterekPrefabsService
extends BayterekBaseService
## Prefab oluşturma / senkronizasyon.

signal prefab_created(prefab: BayterekPrefab)
signal prefab_removed(prefab: BayterekPrefab)

var _ref_id_to_prefab: Dictionary = {}   # reference_id -> BayterekPrefab

func load_tree(tree_data: BayterekTree) -> void:
	_tree_data = tree_data

	_ref_id_to_prefab.clear()

	# Kayıtlı prefab'ları yükle
	for node_type in _tree_data.prefabs.keys():
		var list: Array = _tree_data.prefabs[node_type]
		for prefab in list:
			if prefab.reference_id.is_empty():
				continue
			_ref_id_to_prefab[prefab.reference_id] = prefab
			prefab_created.emit(prefab)

	# Node'ları prefab'lara bağla
	if _tree_view and _tree_view.nodes_service:
		for node in _tree_view.nodes_service.get_all_nodes():
			if not node.node_data:
				continue
			var ref_id: String = node.node_data.reference_id
			if ref_id.is_empty():
				continue
			var prefab: BayterekPrefab = _ref_id_to_prefab.get(ref_id, null)
			if prefab:
				node.prefab = prefab
				prefab.add_node(node)

func get_prefab_by_reference_id(reference_id: String) -> BayterekPrefab:
	return _ref_id_to_prefab.get(reference_id, null)

# ============================================================
# PREFAB OLUŞTURMA
# ============================================================

## Node'dan prefab oluştur. is_copy=false → referanslı prefab, is_copy=true → bağımsız kopya
func create_prefab(node: BayterekNodeButton, is_copy: bool = false) -> BayterekPrefab:
	if not node or not node.node_data:
		return null

	var prefab := BayterekPrefab.new()
	prefab.type = node.node_data.type
	prefab.node_name = node.node_data.name
	prefab.description = node.node_data.description
	prefab.icon = node.node_data.icon
	prefab.border_normal = node.node_data.border_normal
	prefab.border_intermediate = node.node_data.border_intermediate
	prefab.border_active = node.node_data.border_active
	prefab.attributes = node.node_data.attributes.duplicate(true)
	prefab.max_allocations = node.node_data.max_allocations

	if not is_copy:
		# Referanslı prefab — paylaşım
		prefab.reference_id = BayterekUUIDGenerator.v4()
		node.node_data.reference_id = prefab.reference_id
		node.prefab = prefab
		_ref_id_to_prefab[prefab.reference_id] = prefab
	else:
		# Bağımsız kopya — referans_id boş kalır
		prefab.reference_id = ""

	# Tree'ye ekle
	var t: int = prefab.type
	if not _tree_data.prefabs.has(t):
		_tree_data.prefabs[t] = []
	_tree_data.prefabs[t].append(prefab)

	prefab.add_node(node)
	prefab_created.emit(prefab)

	return prefab

# ============================================================
# MAKE UNIQUE
# ============================================================

## Node'un prefab bağlantısını kopar — kendi verisi olur
func make_unique(node: BayterekNodeButton) -> void:
	if not node or not node.prefab:
		return

	var prefab: BayterekPrefab = node.prefab
	prefab.remove_node(node)
	node.prefab = null
	node.node_data.reference_id = ""