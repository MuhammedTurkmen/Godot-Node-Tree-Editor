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
	node_data.icon = prefab.icon
	node_data.border_normal = prefab.border_normal
	node_data.border_intermediate = prefab.border_intermediate
	node_data.border_active = prefab.border_active
	node_data.position = position
	node_data.max_allocations = prefab.max_allocations
	node_data.attributes = prefab.attributes.duplicate(true)

	# Link to prefab if it's a reference prefab
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

	node.refresh_visuals()

	node_created.emit(node)
	return node

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

## Called when a node becomes allocated
func on_node_allocated(node: BayterekNodeButton) -> void:
	if not node or node.type == BayterekNode.NodeType.DECORATION:
		return

	node.set_state(Bayterek.AllocationState.ACTIVE)

	var neighbors: Array = node.node_data.out_nodes + node.node_data.in_nodes
	for neighbor_id in neighbors:
		var neighbor: BayterekNodeButton = get_node(neighbor_id)
		if neighbor:
			_refresh_node_state(neighbor)

## Called when a node is deallocated
func on_node_deallocated(node: BayterekNodeButton) -> void:
	if not node or node.type == BayterekNode.NodeType.DECORATION:
		return

	# Multi-allocation: if still has levels, keep ACTIVE
	if _tree_data.multiallocation and node.allocation_level > 0:
		node.set_state(Bayterek.AllocationState.ACTIVE)
	else:
		_refresh_node_state(node)

	var neighbors: Array = node.node_data.out_nodes + node.node_data.in_nodes
	for neighbor_id in neighbors:
		var neighbor: BayterekNodeButton = get_node(neighbor_id)
		if neighbor:
			_refresh_node_state(neighbor)

## Called when a node is preallocated (waiting for confirmation)
func on_node_preallocated(node: BayterekNodeButton) -> void:
	if not node or node.type == BayterekNode.NodeType.DECORATION:
		return

	node.set_state(Bayterek.AllocationState.PREALLOCATED_ACTIVE)

	var neighbors: Array = node.node_data.out_nodes + node.node_data.in_nodes
	for neighbor_id in neighbors:
		var neighbor: BayterekNodeButton = get_node(neighbor_id)
		if neighbor:
			_refresh_node_state(neighbor)

## Called when preallocation is cancelled
func on_node_unpreallocated(node: BayterekNodeButton) -> void:
	if not node or node.type == BayterekNode.NodeType.DECORATION:
		return

	_refresh_node_state(node)

	var neighbors: Array = node.node_data.out_nodes + node.node_data.in_nodes
	for neighbor_id in neighbors:
		var neighbor: BayterekNodeButton = get_node(neighbor_id)
		if neighbor:
			_refresh_node_state(neighbor)

## Called when a node is staged for refund
func on_node_refund_added(node: BayterekNodeButton) -> void:
	if not node or node.type == BayterekNode.NodeType.DECORATION:
		return

	node.set_state(Bayterek.AllocationState.REFUND)

	var neighbors: Array = node.node_data.out_nodes + node.node_data.in_nodes
	for neighbor_id in neighbors:
		var neighbor: BayterekNodeButton = get_node(neighbor_id)
		if neighbor:
			_refresh_node_state(neighbor)

## Called when a node is removed from refund staging
func on_node_refund_removed(node: BayterekNodeButton) -> void:
	if not node or node.type == BayterekNode.NodeType.DECORATION:
		return

	node.set_state(Bayterek.AllocationState.ACTIVE)

	var neighbors: Array = node.node_data.out_nodes + node.node_data.in_nodes
	for neighbor_id in neighbors:
		var neighbor: BayterekNodeButton = get_node(neighbor_id)
		if neighbor:
			_refresh_node_state(neighbor)

## Recomputes the correct state for a node based on its own flags and its neighbors
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

# ============================================================
# DUPLICATE NODE
# ============================================================

## Creates a copy of the given node with an offset.
## The duplicate keeps attributes, prefab reference, borders, icon, etc.
## Does NOT copy connections.
func duplicate_node(original: BayterekNodeButton, offset: Vector2 = Vector2(20, 20)) -> BayterekNodeButton:
	if not original or not original.node_data:
		return null

	# Build a new node visual
	var node := _build_node(original.type)
	if not node:
		return null

	# Copy data (deep where it matters)
	var node_data := BayterekNode.new()
	node_data.id = _tree_data.get_next_id()
	node_data.name = original.node_data.name
	node_data.description = original.node_data.description
	node_data.type = original.node_data.type
	node_data.icon = original.node_data.icon
	node_data.border_normal = original.node_data.border_normal
	node_data.border_intermediate = original.node_data.border_intermediate
	node_data.border_active = original.node_data.border_active
	node_data.position = original.node_data.position + offset
	node_data.max_allocations = original.node_data.max_allocations
	node_data.attributes = original.node_data.attributes.duplicate(true)
	node_data.is_root = false  # don't duplicate root status
	node_data.external_id = original.node_data.external_id

	# Prefab reference (keeps sharing)
	if not original.node_data.reference_id.is_empty():
		node_data.reference_id = original.node_data.reference_id
		node.prefab = original.prefab
		if original.prefab:
			original.prefab.add_node(node)

	node.node_data = node_data
	node.tree_data = _tree_data
	node.name = "Node_%d" % node_data.id

	_position_node(node, node_data.position)

	_tree_view.nodes_container.add_child(node)
	_nodes[node_data.id] = node

	_tree_data.nodes.append(node_data)

	# Connect signals
	node.pressed.connect(_on_node_pressed.bind(node))
	node.node_hovered.connect(_on_node_hovered)
	node.drag_started.connect(_on_node_drag_started)
	node.dragged.connect(_on_node_dragged)
	node.drag_ended.connect(_on_node_drag_ended)

	node.refresh_visuals()

	node_created.emit(node)
	return node