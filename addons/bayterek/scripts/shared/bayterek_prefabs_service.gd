@tool
class_name BayterekPrefabsService
extends BayterekBaseService
## Prefab creation / sync / deletion. Design-merkezli.

signal prefab_created(prefab: BayterekPrefab)
signal prefab_removed(prefab: BayterekPrefab)
signal prefab_changed(prefab: BayterekPrefab)

var _ref_id_to_prefab: Dictionary = {}

func load_tree(tree_data: BayterekTree) -> void:
	_tree_data = tree_data
	_ref_id_to_prefab.clear()

	for prefab in _tree_data.prefabs:
		if not prefab:
			continue
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
	return _tree_data.prefabs.duplicate() if _tree_data else []

# ============================================================
# CREATE PREFAB
# ============================================================

func create_prefab(node: BayterekNodeButton, prefab_name: String) -> BayterekPrefab:
	if not node or not node.node_data:
		return null
	if prefab_name.strip_edges().is_empty():
		return null

	var trimmed: String = prefab_name.strip_edges()

	var prefab := BayterekPrefab.new()
	prefab.reference_id = BayterekUUIDGenerator.v4()
	prefab.id = Bayterek.to_snake_case(trimmed)
	prefab.node_name = trimmed
	prefab.description = node.node_data.description
	prefab.attributes = node.node_data.attributes.duplicate(true)
	prefab.max_allocations = node.node_data.max_allocations
	prefab.design_id = node.node_data.design_id

	var design: BayterekNodeDesign = null
	if not prefab.design_id.is_empty():
		design = Bayterek.get_designs_registry().get_design_by_id(prefab.design_id)
	if design:
		prefab.copy_exported_fields_from(design)

	node.node_data.reference_id = prefab.reference_id
	node.prefab = prefab
	_ref_id_to_prefab[prefab.reference_id] = prefab

	_tree_data.prefabs.append(prefab)
	prefab.add_node(node)

	prefab_created.emit(prefab)
	return prefab

# ============================================================
# RENAME / DUPLICATE
# ============================================================

func rename_prefab(prefab: BayterekPrefab, new_name: String) -> bool:
	if not prefab:
		return false
	var trimmed: String = new_name.strip_edges()
	if trimmed.is_empty():
		return false
	if trimmed == prefab.node_name:
		return true

	prefab.set_node_name(trimmed)
	prefab_changed.emit(prefab)
	return true

func duplicate_prefab(source: BayterekPrefab) -> BayterekPrefab:
	if not source:
		return null

	var copy := BayterekPrefab.new()
	copy.reference_id = BayterekUUIDGenerator.v4()
	copy.node_name = source.node_name + " Copy"
	copy.id = Bayterek.to_snake_case(copy.node_name)
	copy.description = source.description
	copy.design_id = source.design_id
	copy.attributes = source.attributes.duplicate(true)
	copy.max_allocations = source.max_allocations
	copy.exported_fields = source.exported_fields.duplicate(true)
	copy.exported_values = source.exported_values.duplicate(true)

	_tree_data.prefabs.append(copy)
	_ref_id_to_prefab[copy.reference_id] = copy

	prefab_created.emit(copy)
	return copy

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
	node.node_data.clear_all_exported_overrides()

# ============================================================
# DELETE PREFAB
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
					node.node_data.clear_all_exported_overrides()

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
					node.node_data.clear_all_exported_overrides()

	_tree_data.prefabs.erase(prefab)

	if not prefab.reference_id.is_empty():
		_ref_id_to_prefab.erase(prefab.reference_id)

	prefab.nodes.clear()
	prefab_removed.emit(prefab)

func find_orphan_prefabs() -> Array:
	var orphans: Array = []
	for prefab in get_all_prefabs():
		if prefab.reference_id.is_empty():
			continue
		if prefab.get_nodes().is_empty():
			orphans.append(prefab)
	return orphans

func cleanup_orphan_prefabs() -> int:
	var orphans: Array = find_orphan_prefabs()
	for prefab in orphans:
		delete_prefab(prefab, DeleteMode.ORPHAN_NODES)
	return orphans.size()

# ============================================================
# EXPORTED VALUES
# ============================================================

func set_prefab_exported_value(prefab: BayterekPrefab, field_path: String, value: Variant) -> void:
	if not prefab:
		return
	if not prefab.is_field_exported(field_path):
		return
	prefab.exported_values[field_path] = value
	prefab.exported_values_changed.emit(prefab)

	for node in prefab.get_nodes():
		if not is_instance_valid(node):
			continue
		node.rebuild_from_design()

	prefab_changed.emit(prefab)

func set_node_exported_override(node: BayterekNodeButton, field_path: String, value: Variant) -> void:
	if not node or not node.node_data:
		return
	node.node_data.set_exported_override(field_path, value)
	node.rebuild_from_design()

func clear_node_exported_override(node: BayterekNodeButton, field_path: String) -> void:
	if not node or not node.node_data:
		return
	node.node_data.clear_exported_override(field_path)
	node.rebuild_from_design()

func notify_exported_values_changed(prefab: BayterekPrefab) -> void:
	if not prefab:
		return
	for node in prefab.get_nodes():
		if is_instance_valid(node) and node.has_method("rebuild_from_design"):
			node.rebuild_from_design()
	prefab_changed.emit(prefab)

# ============================================================
# RESET TO PREFAB
# ============================================================

func reset_node_to_prefab_defaults(node: BayterekNodeButton) -> void:
	if not node or not node.prefab or not node.node_data:
		return

	var prefab: BayterekPrefab = node.prefab

	node.node_data.name = prefab.node_name
	node.node_data.description = prefab.description
	node.node_data.attributes = prefab.attributes.duplicate(true)
	node.node_data.max_allocations = prefab.max_allocations
	node.node_data.design_id = prefab.design_id
	node.node_data.clear_all_attribute_overrides()
	node.node_data.clear_all_exported_overrides()

	var design: BayterekNodeDesign = null
	if not prefab.design_id.is_empty():
		design = Bayterek.get_designs_registry().get_design_by_id(prefab.design_id)
	if design:
		node.node_data.design_size = design.design_size
		node.node_data.scale = design.scale
		node.node_data.copy_layers_from(design.layers)

	if not prefab.exported_values.is_empty():
		node.node_data.exported_overrides = prefab.exported_values.duplicate(true)

	if node.has_method("rebuild_from_design"):
		node.rebuild_from_design()

func reset_attribute_to_prefab_default(node: BayterekNodeButton, attr_id: String) -> void:
	if not node or not node.prefab or not node.node_data:
		return

	var prefab: BayterekPrefab = node.prefab

	if prefab.attributes.has(attr_id):
		node.node_data.attributes[attr_id] = prefab.attributes[attr_id].duplicate(true)
	else:
		node.node_data.attributes.erase(attr_id)

	node.node_data.clear_attribute_override(attr_id)