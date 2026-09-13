@tool
class_name BayterekPrefabsService
extends BayterekBaseService
## Prefab oluşturma / senkronizasyon / silme.

signal prefab_created(prefab: BayterekPrefab)
signal prefab_removed(prefab: BayterekPrefab)

var _ref_id_to_prefab: Dictionary = {}   # reference_id -> BayterekPrefab

func load_tree(tree_data: BayterekTree) -> void:
	_tree_data = tree_data

	_ref_id_to_prefab.clear()

	for node_type in _tree_data.prefabs.keys():
		var list: Array = _tree_data.prefabs[node_type]
		for prefab in list:
			if prefab.reference_id.is_empty():
				continue
			_ref_id_to_prefab[prefab.reference_id] = prefab
			prefab_created.emit(prefab)

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

func get_all_prefabs() -> Array:
	var result: Array = []
	for node_type in _tree_data.prefabs.keys():
		for p in _tree_data.prefabs[node_type]:
			result.append(p)
	return result

# ============================================================
# PREFAB OLUŞTURMA
# ============================================================

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
		prefab.reference_id = BayterekUUIDGenerator.v4()
		node.node_data.reference_id = prefab.reference_id
		node.prefab = prefab
		_ref_id_to_prefab[prefab.reference_id] = prefab
	else:
		prefab.reference_id = ""

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

func make_unique(node: BayterekNodeButton) -> void:
	if not node or not node.prefab:
		return

	var prefab: BayterekPrefab = node.prefab
	prefab.remove_node(node)
	node.prefab = null
	node.node_data.reference_id = ""
	node.node_data.clear_all_attribute_overrides()

# ============================================================
# FAZ 8f — PREFAB SİLME
# ============================================================

enum DeleteMode {
	ORPHAN_NODES,
	DELETE_NODES,
	MAKE_UNIQUE,
}

func delete_prefab(prefab: BayterekPrefab, mode: DeleteMode = DeleteMode.ORPHAN_NODES) -> void:
	if not prefab:
		return

	var nodes_snapshot: Array = prefab.get_nodes().duplicate()

	match mode:
		DeleteMode.ORPHAN_NODES:
			for node in nodes_snapshot:
				if not is_instance_valid(node):
					continue
				node.prefab = null
				if node.node_data:
					node.node_data.reference_id = ""
					node.node_data.clear_all_attribute_overrides()

		DeleteMode.DELETE_NODES:
			if _tree_view and _tree_view.nodes_service:
				for node in nodes_snapshot:
					if not is_instance_valid(node):
						continue
					if _tree_view.connections_service:
						_tree_view.connections_service.remove_all_connections_of(node)
					_tree_view.nodes_service.delete_node(node)
					_tree_view.node_deleted.emit(node)

		DeleteMode.MAKE_UNIQUE:
			for node in nodes_snapshot:
				if not is_instance_valid(node):
					continue
				node.prefab = null
				if node.node_data:
					node.node_data.reference_id = ""
					node.node_data.clear_all_attribute_overrides()

	var t: int = prefab.type
	if _tree_data.prefabs.has(t):
		var list: Array = _tree_data.prefabs[t]
		list.erase(prefab)

	if not prefab.reference_id.is_empty():
		_ref_id_to_prefab.erase(prefab.reference_id)

	prefab.nodes.clear()

	prefab_removed.emit(prefab)

## Orphan prefab'ları bul (referanslı ama node'u olmayan)
func find_orphan_prefabs() -> Array:
	var orphans: Array = []
	for prefab in get_all_prefabs():
		if prefab.reference_id.is_empty():
			continue
		if prefab.get_nodes().is_empty():
			orphans.append(prefab)
	return orphans

## Tüm orphan prefab'ları sil
func cleanup_orphan_prefabs() -> int:
	var orphans: Array = find_orphan_prefabs()
	for prefab in orphans:
		delete_prefab(prefab, DeleteMode.ORPHAN_NODES)
	return orphans.size()

# ============================================================
# FAZ 8e — RESET TO PREFAB
# ============================================================

## Node'un tüm verisini prefab default'una döndür
func reset_node_to_prefab_defaults(node: BayterekNodeButton) -> void:
	if not node or not node.prefab or not node.node_data:
		return

	var prefab: BayterekPrefab = node.prefab

	node.node_data.name = prefab.node_name
	node.node_data.description = prefab.description
	node.node_data.icon = prefab.icon
	node.node_data.border_normal = prefab.border_normal
	node.node_data.border_intermediate = prefab.border_intermediate
	node.node_data.border_active = prefab.border_active
	node.node_data.attributes = prefab.attributes.duplicate(true)
	node.node_data.max_allocations = prefab.max_allocations
	node.node_data.clear_all_attribute_overrides()

	if node.has_method("refresh_visuals"):
		node.refresh_visuals()

## Tek bir attribute'u prefab default'una döndür
func reset_attribute_to_prefab_default(node: BayterekNodeButton, attr_id: String) -> void:
	if not node or not node.prefab or not node.node_data:
		return

	var prefab: BayterekPrefab = node.prefab

	if prefab.attributes.has(attr_id):
		node.node_data.attributes[attr_id] = prefab.attributes[attr_id].duplicate(true)
	else:
		node.node_data.attributes.erase(attr_id)

	node.node_data.clear_attribute_override(attr_id)