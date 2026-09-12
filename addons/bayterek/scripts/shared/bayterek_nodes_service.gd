@tool
class_name BayterekNodesService
extends BayterekBaseService
## Node oluşturma / silme / yönetme.

signal node_created(node: BayterekNodeButton)
signal node_pressed(node: BayterekNodeButton)
signal node_hovered(node: BayterekNodeButton, is_hovered: bool)

var _nodes: Dictionary[int, BayterekNodeButton] = {}

func load_tree(tree_data: BayterekTree) -> void:
	_tree_data = tree_data

func get_node(node_id: int) -> BayterekNodeButton:
	return _nodes.get(node_id, null)
