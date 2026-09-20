@tool
class_name BayterekNodesService
extends BayterekBaseService
## Node creation / deletion / management.

signal node_created(node: BayterekNodeButton)
signal node_pressed(node: BayterekNodeButton, additive: bool)
signal node_hovered(node: BayterekNodeButton, is_hovered: bool)
signal node_drag_started(node: BayterekNodeButton, mouse_screen_pos: Vector2)
signal node_dragged(node: BayterekNodeButton, mouse_screen_pos: Vector2)
signal node_drag_ended(node: BayterekNodeButton)
signal node_right_clicked(node: BayterekNodeButton, screen_pos: Vector2)

var _nodes: Dictionary = {}

func load_tree(tree_data: BayterekTree) -> void:
	_tree_data = tree_data

	for node_data in _tree_data.nodes:
		_create_node_from_data(node_data)

func _create_node_from_data(node_data: BayterekNode) -> BayterekNodeButton:
	var node := _build_node(node_data.type)
	if not node:
		return null

	node.node_data = node_data
	node.tree_data = _tree_data
	node.name = "Node_%d" % node_data.id

	_position_node(node, node_data.position)

	_tree_view.nodes_container.add_child(node)
	_nodes[node_data.id] = node

	node.pressed.connect(_on_node_pressed.bind(node))
	node.node_hovered.connect(_on_node_hovered)
	node.drag_started.connect(_on_node_drag_started)
	node.dragged.connect(_on_node_dragged)
	node.drag_ended.connect(_on_node_drag_ended)
	node.right_clicked.connect(_on_node_right_clicked)

	node.refresh_visuals()

	node_created.emit(node)
	return node

func create_node_from_data_paste(node_data: BayterekNode) -> BayterekNodeButton:
	if not node_data:
		return null

	var node := _build_node(node_data.type)
	if not node:
		return null

	node.node_data = node_data
	node.tree_data = _tree_data
	node.name = "Node_%d" % node_data.id

	_position_node(node, node_data.position)

	_tree_view.nodes_container.add_child(node)
	_nodes[node_data.id] = node

	node.pressed.connect(_on_node_pressed.bind(node))
	node.node_hovered.connect(_on_node_hovered)
	node.drag_started.connect(_on_node_drag_started)
	node.dragged.connect(_on_node_dragged)
	node.drag_ended.connect(_on_node_drag_ended)
	node.right_clicked.connect(_on_node_right_clicked)

	node.refresh_visuals()

	node_created.emit(node)
	return node

func get_node(node_id: int) -> BayterekNodeButton:
	return _nodes.get(node_id, null)

func get_all_nodes() -> Array:
	return _nodes.values()

# ============================================================
# CREATION
# ============================================================

func create_node(position: Vector2, node_type: BayterekNode.NodeType) -> BayterekNodeButton:
	var node := _build_node(node_type)
	if not node:
		return null

	var node_data := BayterekNode.new()
	node_data.id = _tree_data.get_next_id()
	node_data.name = _default_name(node_type)
	node_data.type = node_type
	node_data.position = position
	node_data.max_allocations = 1

	if not _tree_has_root():
		node_data.is_root = true

	# Apply tree's default design (copies layers + sizing)
	node_data.apply_defaults_from_tree(_tree_data)

	node.node_data = node_data
	node.tree_data = _tree_data
	node.name = "Node_%d" % node_data.id

	_position_node(node, position)

	_tree_view.nodes_container.add_child(node)
	_nodes[node_data.id] = node

	_tree_data.nodes.append(node_data)

	node.pressed.connect(_on_node_pressed.bind(node))
	node.node_hovered.connect(_on_node_hovered)
	node.drag_started.connect(_on_node_drag_started)
	node.dragged.connect(_on_node_dragged)
	node.drag_ended.connect(_on_node_drag_ended)
	node.right_clicked.connect(_on_node_right_clicked)

	node.refresh_visuals()

	node_created.emit(node)
	return node

func create_from_prefab(position: Vector2, prefab: BayterekPrefab) -> BayterekNodeButton:
	if not prefab:
		return null

	var node := _build_node(prefab.type)
	if not node:
		return null

	var node_data := BayterekNode.new()
	node_data.id = _tree_data.get_next_id()
	node_data.name = prefab.node_name
	node_data.description = prefab.description
	node_data.type = prefab.type
	node_data.position = position
	node_data.max_allocations = prefab.max_allocations
	node_data.attributes = prefab.attributes.duplicate(true)

	if not _tree_has_root():
		node_data.is_root = true

	# 1) Apply prefab's design if set
	if not prefab.design_id.is_empty():
		var design: BayterekNodeDesign = Bayterek.get_designs_registry().get_design_by_id(prefab.design_id)
		if design:
			node_data.apply_design(design)
		else:
			node_data.apply_defaults_from_tree(_tree_data)
	else:
		# 2) Fallback: tree default design
		node_data.apply_defaults_from_tree(_tree_data)

	# 3) Prefab's own layers override (if any)
	if prefab.get_layer_count() > 0:
		node_data.copy_layers_from(prefab.layers)

	if not prefab.reference_id.is_empty():
		node_data.reference_id = prefab.reference_id
		node.prefab = prefab
		prefab.add_node(node)

	node.node_data = node_data
	node.tree_data = _tree_data
	node.name = "Node_%d" % node_data.id

	_position_node(node, position)

	_tree_view.nodes_container.add_child(node)
	_nodes[node_data.id] = node

	_tree_data.nodes.append(node_data)

	node.pressed.connect(_on_node_pressed.bind(node))
	node.node_hovered.connect(_on_node_hovered)
	node.drag_started.connect(_on_node_drag_started)
	node.dragged.connect(_on_node_dragged)
	node.drag_ended.connect(_on_node_drag_ended)
	node.right_clicked.connect(_on_node_right_clicked)

	node.refresh_visuals()

	node_created.emit(node)
	return node

# ============================================================
# AUTO-ROOT HELPER
# ============================================================

func _tree_has_root() -> bool:
	if not _tree_data or not _tree_data.nodes:
		return false
	for n in _tree_data.nodes:
		if n and n.is_root:
			return true
	return false

# ============================================================
# DELETE / RESTORE
# ============================================================

func delete_node(node: BayterekNodeButton) -> void:
	if not node or not node.node_data:
		return

	_nodes.erase(node.node_data.id)
	_tree_data.nodes.erase(node.node_data)
	_tree_view.nodes_container.remove_child(node)

func restore_node(node: BayterekNodeButton, node_data: BayterekNode, index: int = -1) -> void:
	if not node or not node_data:
		return
	if not is_instance_valid(node):
		return

	node.node_data = node_data
	node.tree_data = _tree_data
	_nodes[node_data.id] = node

	_position_node(node, node_data.position)

	if not node.is_inside_tree():
		_tree_view.nodes_container.add_child(node)
	else:
		node.visible = true

	if _tree_data.nodes.has(node_data):
		node.refresh_visuals()
		node_created.emit(node)
		return

	if index >= 0 and index <= _tree_data.nodes.size():
		_tree_data.nodes.insert(index, node_data)
	else:
		_tree_data.nodes.append(node_data)

	node.refresh_visuals()
	node_created.emit(node)

# ============================================================
# POSITION
# ============================================================

func update_position(node: BayterekNodeButton, pos_in_tree: Vector2) -> void:
	if not node or not node.node_data:
		return
	node.node_data.position = pos_in_tree
	_position_node(node, pos_in_tree)

# ============================================================
# ALLOCATION STATE CALLBACKS
# ============================================================

func on_node_allocated(node: BayterekNodeButton) -> void:
	if not node or node.type == BayterekNode.NodeType.DECORATION:
		return
	_refresh_node_state(node)
	_refresh_neighbors(node)

func on_node_deallocated(node: BayterekNodeButton) -> void:
	if not node or node.type == BayterekNode.NodeType.DECORATION:
		return
	_refresh_node_state(node)
	_refresh_neighbors(node)

func on_node_preallocated(node: BayterekNodeButton) -> void:
	if not node or node.type == BayterekNode.NodeType.DECORATION:
		return
	_refresh_node_state(node)
	_refresh_neighbors(node)

func on_node_unpreallocated(node: BayterekNodeButton) -> void:
	if not node or node.type == BayterekNode.NodeType.DECORATION:
		return
	_refresh_node_state(node)
	_refresh_neighbors(node)

func on_node_refund_added(node: BayterekNodeButton) -> void:
	if not node or node.type == BayterekNode.NodeType.DECORATION:
		return
	_refresh_node_state(node)
	_refresh_neighbors(node)

func on_node_refund_removed(node: BayterekNodeButton) -> void:
	if not node or node.type == BayterekNode.NodeType.DECORATION:
		return
	_refresh_node_state(node)
	_refresh_neighbors(node)

func _refresh_neighbors(node: BayterekNodeButton) -> void:
	var neighbors: Array = node.node_data.out_nodes + node.node_data.in_nodes
	for neighbor_id in neighbors:
		var neighbor: BayterekNodeButton = get_node(neighbor_id)
		if neighbor:
			_refresh_node_state(neighbor)

func _refresh_node_state(node: BayterekNodeButton) -> void:
	if not node or not node.node_data:
		return
	if node.type == BayterekNode.NodeType.DECORATION:
		return

	if node.preallocated:
		node.set_state(Bayterek.AllocationState.PREALLOCATED_ACTIVE)
		return

	if node.allocated:
		if node.refund:
			node.set_state(Bayterek.AllocationState.REFUND)
		else:
			node.set_state(Bayterek.AllocationState.ACTIVE)
		return

	var neighbors: Array = node.node_data.out_nodes + node.node_data.in_nodes
	for neighbor_id in neighbors:
		var neighbor: BayterekNodeButton = get_node(neighbor_id)
		if not neighbor:
			continue

		if neighbor.allocated and not neighbor.refund:
			node.set_state(Bayterek.AllocationState.INTERMEDIATE)
			return

		if neighbor.preallocated:
			node.set_state(Bayterek.AllocationState.PREALLOCATED_INTERMEDIATE)
			return

	node.set_state(Bayterek.AllocationState.NORMAL)

# ============================================================
# ALLOCATABLE FLAG BROADCAST
# ============================================================

func refresh_allocatable_flags(active_ids: Array) -> void:
	for node in _nodes.values():
		if not is_instance_valid(node) or not node.node_data:
			continue
		if node.type == BayterekNode.NodeType.DECORATION:
			continue
		var was: bool = node.is_allocatable
		var now: bool = _compute_allocatable(node, active_ids)
		node.is_allocatable = now
		if was != now:
			node.refresh_visuals()

func _compute_allocatable(node: BayterekNodeButton, active_ids: Array) -> bool:
	if not _tree_data or not _tree_data.allocation:
		return false
	if node.allocated:
		return false

	var nd: BayterekNode = node.node_data
	if nd.is_root:
		return true

	match nd.prerequisite_mode:
		BayterekNode.PrerequisiteMode.ANY:
			for nid in nd.in_nodes:
				if active_ids.has(nid):
					return true
			for nid in nd.out_nodes:
				if active_ids.has(nid):
					return true
			return false

		BayterekNode.PrerequisiteMode.COUNT:
			if nd.in_nodes.is_empty():
				for nid in nd.out_nodes:
					if active_ids.has(nid):
						return true
				return false
			var count: int = 0
			for nid in nd.in_nodes:
				if active_ids.has(nid):
					count += 1
					if count >= nd.prerequisite_count:
						return true
			return false

		BayterekNode.PrerequisiteMode.ALL:
			if nd.in_nodes.is_empty():
				for nid in nd.out_nodes:
					if active_ids.has(nid):
						return true
				return false
			for nid in nd.in_nodes:
				if not active_ids.has(nid):
					return false
			return true

		BayterekNode.PrerequisiteMode.GROUP_COMPLETE:
			if nd.prerequisite_group_id.is_empty():
				return true
			var group: BayterekNodeGroup = _tree_data.get_group_by_id(nd.prerequisite_group_id)
			if not group:
				return true
			for member_id in group.node_ids:
				if not active_ids.has(member_id):
					return false
			return true

	return false

# ============================================================
# PRIVATE
# ============================================================

func _build_node(node_type: BayterekNode.NodeType) -> BayterekNodeButton:
	var node := BayterekNodeButton.new()
	var node_size: Vector2 = _get_node_size(node_type)
	node.size = node_size
	node.custom_minimum_size = node_size
	return node

func _position_node(node: BayterekNodeButton, pos_in_tree: Vector2) -> void:
	var local_pos: Vector2 = pos_in_tree + (_tree_data.size * 0.5) - (node.size * 0.5)
	node.position = local_pos

func _get_node_size(node_type: BayterekNode.NodeType) -> Vector2:
	match node_type:
		BayterekNode.NodeType.SMALL:  return Vector2(27, 27)
		BayterekNode.NodeType.MEDIUM: return Vector2(48, 48)
		BayterekNode.NodeType.LARGE:  return Vector2(64, 64)
		BayterekNode.NodeType.DECORATION: return Vector2(32, 32)
	return Vector2(32, 32)

func _default_name(node_type: BayterekNode.NodeType) -> String:
	match node_type:
		BayterekNode.NodeType.SMALL:  return "Small Node"
		BayterekNode.NodeType.MEDIUM: return "Medium Node"
		BayterekNode.NodeType.LARGE:  return "Large Node"
		BayterekNode.NodeType.DECORATION: return "Decoration"
	return "Node"

# ============================================================
# SIGNAL HANDLERS
# ============================================================

func _on_node_pressed(node: BayterekNodeButton) -> void:
	var additive: bool = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
	node_pressed.emit(node, additive)

func _on_node_hovered(node: BayterekNodeButton, is_hovered: bool) -> void:
	node_hovered.emit(node, is_hovered)

func _on_node_drag_started(node: BayterekNodeButton, mouse_screen_pos: Vector2) -> void:
	node_drag_started.emit(node, mouse_screen_pos)

func _on_node_dragged(node: BayterekNodeButton, mouse_screen_pos: Vector2) -> void:
	node_dragged.emit(node, mouse_screen_pos)

func _on_node_drag_ended(node: BayterekNodeButton) -> void:
	node_drag_ended.emit(node)

func _on_node_right_clicked(node: BayterekNodeButton, screen_pos: Vector2) -> void:
	node_right_clicked.emit(node, screen_pos)

# ============================================================
# DUPLICATE NODE
# ============================================================

func duplicate_node(original: BayterekNodeButton, offset: Vector2 = Vector2(20, 20)) -> BayterekNodeButton:
	if not original or not original.node_data:
		return null

	var node := _build_node(original.type)
	if not node:
		return null

	var src: BayterekNode = original.node_data
	var node_data := BayterekNode.new()
	node_data.id = _tree_data.get_next_id()
	node_data.name = src.name
	node_data.description = src.description
	node_data.type = src.type
	node_data.position = src.position + offset
	node_data.max_allocations = src.max_allocations
	node_data.attributes = src.attributes.duplicate(true)
	node_data.is_root = false
	node_data.external_id = src.external_id
	node_data.design_id = src.design_id
	node_data.design_size = src.design_size
	node_data.scale = src.scale

	node_data.copy_layers_from(src.layers)

	if not src.reference_id.is_empty():
		node_data.reference_id = src.reference_id
		node.prefab = original.prefab
		if original.prefab:
			original.prefab.add_node(node)

	node.node_data = node_data
	node.tree_data = _tree_data
	node.name = "Node_%d" % node_data.id

	_position_node(node, node_data.position)

	_tree_view.nodes_container.add_child(node)
	_nodes[node_data.id] = node

	node.pressed.connect(_on_node_pressed.bind(node))
	node.node_hovered.connect(_on_node_hovered)
	node.drag_started.connect(_on_node_drag_started)
	node.dragged.connect(_on_node_dragged)
	node.drag_ended.connect(_on_node_drag_ended)
	node.right_clicked.connect(_on_node_right_clicked)

	node.refresh_visuals()

	node_created.emit(node)
	return node