@tool
class_name BayterekNodesService
extends BayterekBaseService
## Node oluşturma / silme / yönetme.

signal node_created(node: BayterekNodeButton)
signal node_pressed(node: BayterekNodeButton, additive: bool)
signal node_drag_started(node: BayterekNodeButton, mouse_screen_pos: Vector2)
signal node_dragged(node: BayterekNodeButton, mouse_screen_pos: Vector2)
signal node_drag_ended(node: BayterekNodeButton)

var _nodes: Dictionary = {}   # id -> BayterekNodeButton

func load_tree(tree_data: BayterekTree) -> void:
	_tree_data = tree_data

func get_node(node_id: int) -> BayterekNodeButton:
	return _nodes.get(node_id, null)

func get_all_nodes() -> Array:
	return _nodes.values()

# ============================================================
# OLUŞTURMA
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
	node.name = "Node_%d" % node_data.id

	_position_node(node, position)

	_tree_view.nodes_container.add_child(node)
	_nodes[node_data.id] = node

	_tree_data.nodes.append(node_data)

	node.pressed.connect(_on_node_pressed.bind(node))
	node.drag_started.connect(_on_node_drag_started)
	node.dragged.connect(_on_node_dragged)
	node.drag_ended.connect(_on_node_drag_ended)

	node_created.emit(node)
	return node

# ============================================================
# SİLME
# ============================================================

func delete_node(node: BayterekNodeButton) -> void:
	if not node or not node.node_data:
		return

	_nodes.erase(node.node_data.id)
	_tree_data.nodes.erase(node.node_data)
	_tree_view.nodes_container.remove_child(node)
	node.queue_free()

# ============================================================
# POZİSYON
# ============================================================

func update_position(node: BayterekNodeButton, pos_in_tree: Vector2) -> void:
	if not node or not node.node_data:
		return

	node.node_data.position = pos_in_tree
	_position_node(node, pos_in_tree)

# ============================================================
# PRIVATE
# ============================================================

func _build_node(node_type: BayterekNode.NodeType) -> BayterekNodeButton:
	var node := BayterekNodeButton.new()

	var node_size: Vector2 = _get_node_size(node_type)
	node.size = node_size
	node.custom_minimum_size = node_size

	var icon := ColorRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.color = _get_type_color(node_type)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.add_child(icon)

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

func _get_type_color(node_type: BayterekNode.NodeType) -> Color:
	match node_type:
		BayterekNode.NodeType.SMALL:  return Color(0.4, 0.7, 1.0, 0.8)
		BayterekNode.NodeType.MEDIUM: return Color(0.4, 1.0, 0.5, 0.8)
		BayterekNode.NodeType.LARGE:  return Color(1.0, 0.7, 0.4, 0.8)
		BayterekNode.NodeType.DECORATION: return Color(0.7, 0.5, 1.0, 0.8)
	return Color.WHITE

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

func _on_node_drag_started(node: BayterekNodeButton, mouse_screen_pos: Vector2) -> void:
	node_drag_started.emit(node, mouse_screen_pos)

func _on_node_dragged(node: BayterekNodeButton, mouse_screen_pos: Vector2) -> void:
	node_dragged.emit(node, mouse_screen_pos)

func _on_node_drag_ended(node: BayterekNodeButton) -> void:
	node_drag_ended.emit(node)