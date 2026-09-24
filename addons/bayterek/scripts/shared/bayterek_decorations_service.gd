@tool
class_name BayterekDecorationsService
extends BayterekBaseService
## Dekor node'ları yönetimi.
##
## Decorations are BayterekNode entries with `is_decoration = true`.
## They live in `BayterekTree.decorations` instead of `BayterekTree.nodes`,
## and they are rendered in `decorations_container` (behind regular nodes).
##
## Decorations have no allocation logic, no prerequisites and don't
## participate in connections — they are pure visual elements.

signal decoration_created(decoration: BayterekNodeButton)
signal decoration_deleted(decoration: BayterekNodeButton)
signal decoration_changed(decoration: BayterekNodeButton)

var _decorations: Dictionary = {}   # id -> BayterekNodeButton

# ============================================================
# LOAD
# ============================================================

func load_tree(tree_data: BayterekTree) -> void:
	_tree_data = tree_data
	_decorations.clear()

	if not _tree_data:
		return

	for node_data in _tree_data.decorations:
		_create_decoration_from_data(node_data)

# ============================================================
# CREATE
# ============================================================

## Creates a new decoration node at `position` using the given design.
## If `design` is null, falls back to the tree's default design.
func create_decoration(position: Vector2, design: BayterekNodeDesign = null) -> BayterekNodeButton:
	if not _tree_data:
		return null

	var node_data := BayterekNode.new()
	node_data.id = _tree_data.get_next_id()
	node_data.position = position
	node_data.is_decoration = true
	node_data.is_root = false
	node_data.max_allocations = 0

	if design:
		node_data.name = design.name
		node_data.apply_design(design)
	else:
		node_data.apply_defaults_from_tree(_tree_data)
		node_data.name = "Decoration"

	var node := _create_decoration_from_data(node_data)
	if node:
		_tree_data.decorations.append(node_data)
		decoration_created.emit(node)
	return node

func _create_decoration_from_data(node_data: BayterekNode) -> BayterekNodeButton:
	if not node_data:
		return null

	var node := BayterekNodeButton.new()
	node.node_data = node_data
	node.tree_data = _tree_data
	node.name = "Decoration_%d" % node_data.id

	var node_size: Vector2 = node_data.design_size * node_data.scale
	if node_size.x <= 0.0 or node_size.y <= 0.0:
		node_size = Vector2(100, 100)
	node.size = node_size
	node.custom_minimum_size = node_size

	_position_decoration(node, node_data.position)

	_tree_view.decorations_container.add_child(node)
	_decorations[node_data.id] = node

	# Decorations ignore input entirely.
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	node.refresh_visuals()
	return node

# ============================================================
# QUERY
# ============================================================

func get_decoration(id: int) -> BayterekNodeButton:
	return _decorations.get(id, null)

func get_all_decorations() -> Array:
	return _decorations.values()

func has_decoration(id: int) -> bool:
	return _decorations.has(id)

# ============================================================
# UPDATE
# ============================================================

func update_position(node: BayterekNodeButton, pos_in_tree: Vector2) -> void:
	if not node or not node.node_data:
		return
	node.node_data.position = pos_in_tree
	_position_decoration(node, pos_in_tree)

func refresh_visuals(node: BayterekNodeButton) -> void:
	if not node or not node.node_data:
		return
	node.refresh_visuals()
	decoration_changed.emit(node)

# ============================================================
# DELETE
# ============================================================

func delete_decoration(node: BayterekNodeButton) -> void:
	if not node or not node.node_data:
		return

	var id: int = node.node_data.id

	_tree_data.decorations.erase(node.node_data)
	_decorations.erase(id)

	if node.is_inside_tree():
		_tree_view.decorations_container.remove_child(node)
		node.queue_free()

	decoration_deleted.emit(node)

func clear_all() -> void:
	for node in _decorations.values():
		if is_instance_valid(node):
			if node.is_inside_tree():
				_tree_view.decorations_container.remove_child(node)
			node.queue_free()
	_decorations.clear()
	if _tree_data:
		_tree_data.decorations.clear()

# ============================================================
# RESTORE (for undo)
# ============================================================

func restore_decoration(node: BayterekNodeButton, node_data: BayterekNode, index: int = -1) -> void:
	if not node or not node_data or not is_instance_valid(node):
		return

	node.node_data = node_data
	node.tree_data = _tree_data
	_decorations[node_data.id] = node

	_position_decoration(node, node_data.position)

	if not node.is_inside_tree():
		_tree_view.decorations_container.add_child(node)
	else:
		node.visible = true
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _tree_data.decorations.has(node_data):
		node.refresh_visuals()
		return

	if index >= 0 and index <= _tree_data.decorations.size():
		_tree_data.decorations.insert(index, node_data)
	else:
		_tree_data.decorations.append(node_data)

	node.refresh_visuals()
	decoration_created.emit(node)

# ============================================================
# PRIVATE
# ============================================================

func _position_decoration(node: BayterekNodeButton, pos_in_tree: Vector2) -> void:
	if not _tree_data:
		return
	var local_pos: Vector2 = pos_in_tree + (_tree_data.size * 0.5) - (node.size * 0.5)
	node.position = local_pos