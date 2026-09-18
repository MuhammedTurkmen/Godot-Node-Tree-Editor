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

## Creates a node from pre-built node_data. Used by paste.
## Does NOT auto-root. Does NOT append to _tree_data.nodes
## (the caller's undo system handles that via restore_node).
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

	# Auto-root: if the tree has no root yet, make this the first root.
	if not _tree_has_root():
		node_data.is_root = true

	# Apply default visuals from tree
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

	# Auto-root: if the tree has no root yet, make this the first root.
	if not _tree_has_root():
		node_data.is_root = true

	# Defaults from tree, then override with prefab's visuals
	node_data.apply_defaults_from_tree(_tree_data)
	_apply_prefab_visuals(node_data, prefab)

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
	node.right_clicked.connect(_on_node_right_clicked)

	node.refresh_visuals()

	node_created.emit(node)
	return node

# ============================================================
# AUTO-ROOT HELPER
# ============================================================

## Returns true if the tree already has at least one node marked as root.
func _tree_has_root() -> bool:
	if not _tree_data or not _tree_data.nodes:
		return false
	for n in _tree_data.nodes:
		if n and n.is_root:
			return true
	return false

# ============================================================
# PREFAB VISUAL COPY
# ============================================================

func _apply_prefab_visuals(node_data: BayterekNode, prefab: BayterekPrefab) -> void:
	node_data.border_texture_locked = prefab.border_texture_locked
	node_data.border_texture_normal = prefab.border_texture_normal
	node_data.border_texture_hover = prefab.border_texture_hover
	node_data.border_texture_max_level = prefab.border_texture_max_level

	node_data.border_color_locked = prefab.border_color_locked
	node_data.border_color_normal = prefab.border_color_normal
	node_data.border_color_hover = prefab.border_color_hover
	node_data.border_color_allocate = prefab.border_color_allocate
	node_data.border_color_refund = prefab.border_color_refund
	node_data.border_color_max_level = prefab.border_color_max_level
	node_data.border_color_allocatable = prefab.border_color_allocatable
	node_data.border_color_not_allocatable = prefab.border_color_not_allocatable

	node_data.icon_texture_locked = prefab.icon_texture_locked
	node_data.icon_texture_normal = prefab.icon_texture_normal
	node_data.icon_texture_hover = prefab.icon_texture_hover
	node_data.icon_texture_max_level = prefab.icon_texture_max_level

	node_data.icon_color_locked = prefab.icon_color_locked
	node_data.icon_color_normal = prefab.icon_color_normal
	node_data.icon_color_hover = prefab.icon_color_hover
	node_data.icon_color_allocate = prefab.icon_color_allocate
	node_data.icon_color_refund = prefab.icon_color_refund
	node_data.icon_color_max_level = prefab.icon_color_max_level
	node_data.icon_color_allocatable = prefab.icon_color_allocatable
	node_data.icon_color_not_allocatable = prefab.icon_color_not_allocatable

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
	var neighbors: Array = node.node_data.out_nodes + node.node_data.in_nodes
	for neighbor_id in neighbors:
		var neighbor: BayterekNodeButton = get_node(neighbor_id)
		if neighbor:
			_refresh_node_state(neighbor)

func on_node_deallocated(node: BayterekNodeButton) -> void:
	if not node or node.type == BayterekNode.NodeType.DECORATION:
		return
	_refresh_node_state(node)
	var neighbors: Array = node.node_data.out_nodes + node.node_data.in_nodes
	for neighbor_id in neighbors:
		var neighbor: BayterekNodeButton = get_node(neighbor_id)
		if neighbor:
			_refresh_node_state(neighbor)

func on_node_preallocated(node: BayterekNodeButton) -> void:
	if not node or node.type == BayterekNode.NodeType.DECORATION:
		return
	_refresh_node_state(node)
	var neighbors: Array = node.node_data.out_nodes + node.node_data.in_nodes
	for neighbor_id in neighbors:
		var neighbor: BayterekNodeButton = get_node(neighbor_id)
		if neighbor:
			_refresh_node_state(neighbor)

func on_node_unpreallocated(node: BayterekNodeButton) -> void:
	if not node or node.type == BayterekNode.NodeType.DECORATION:
		return
	_refresh_node_state(node)
	var neighbors: Array = node.node_data.out_nodes + node.node_data.in_nodes
	for neighbor_id in neighbors:
		var neighbor: BayterekNodeButton = get_node(neighbor_id)
		if neighbor:
			_refresh_node_state(neighbor)

func on_node_refund_added(node: BayterekNodeButton) -> void:
	if not node or node.type == BayterekNode.NodeType.DECORATION:
		return
	_refresh_node_state(node)
	var neighbors: Array = node.node_data.out_nodes + node.node_data.in_nodes
	for neighbor_id in neighbors:
		var neighbor: BayterekNodeButton = get_node(neighbor_id)
		if neighbor:
			_refresh_node_state(neighbor)

func on_node_refund_removed(node: BayterekNodeButton) -> void:
	if not node or node.type == BayterekNode.NodeType.DECORATION:
		return
	_refresh_node_state(node)
	var neighbors: Array = node.node_data.out_nodes + node.node_data.in_nodes
	for neighbor_id in neighbors:
		var neighbor: BayterekNodeButton = get_node(neighbor_id)
		if neighbor:
			_refresh_node_state(neighbor)

## Recomputes the visual state for a node based on its flags.
## Now only computes the internal state machine; the actual visual
## is picked by `BayterekNodeButton._resolve_visual_state()`.
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

## Recomputes `is_allocatable` for every node in the tree and refreshes
## visuals. Called by the tree view after every allocation-related change.
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

	# Mirror of BayterekAllocationService._is_prerequisite_satisfied for
	# the initial state (no exclusions).
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
	node_data.icon = src.icon
	node_data.position = src.position + offset
	node_data.max_allocations = src.max_allocations
	node_data.attributes = src.attributes.duplicate(true)
	node_data.is_root = false
	node_data.external_id = src.external_id

	# Copy visuals
	node_data.border_texture_locked = src.border_texture_locked
	node_data.border_texture_normal = src.border_texture_normal
	node_data.border_texture_hover = src.border_texture_hover
	node_data.border_texture_max_level = src.border_texture_max_level

	node_data.border_color_locked = src.border_color_locked
	node_data.border_color_normal = src.border_color_normal
	node_data.border_color_hover = src.border_color_hover
	node_data.border_color_allocate = src.border_color_allocate
	node_data.border_color_refund = src.border_color_refund
	node_data.border_color_max_level = src.border_color_max_level
	node_data.border_color_allocatable = src.border_color_allocatable
	node_data.border_color_not_allocatable = src.border_color_not_allocatable

	node_data.icon_texture_locked = src.icon_texture_locked
	node_data.icon_texture_normal = src.icon_texture_normal
	node_data.icon_texture_hover = src.icon_texture_hover
	node_data.icon_texture_max_level = src.icon_texture_max_level

	node_data.icon_color_locked = src.icon_color_locked
	node_data.icon_color_normal = src.icon_color_normal
	node_data.icon_color_hover = src.icon_color_hover
	node_data.icon_color_allocate = src.icon_color_allocate
	node_data.icon_color_refund = src.icon_color_refund
	node_data.icon_color_max_level = src.icon_color_max_level
	node_data.icon_color_allocatable = src.icon_color_allocatable
	node_data.icon_color_not_allocatable = src.icon_color_not_allocatable

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

	# NOTE: _tree_data.nodes.append is done by editor's restore_node().
	node.pressed.connect(_on_node_pressed.bind(node))
	node.node_hovered.connect(_on_node_hovered)
	node.drag_started.connect(_on_node_drag_started)
	node.dragged.connect(_on_node_dragged)
	node.drag_ended.connect(_on_node_drag_ended)
	node.right_clicked.connect(_on_node_right_clicked)

	node.refresh_visuals()

	node_created.emit(node)
	return node