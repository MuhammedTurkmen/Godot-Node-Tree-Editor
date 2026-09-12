@tool
class_name BayterekConnectionsService
extends BayterekBaseService
## Bağlantı oluşturma / güncelleme.

signal line_created(line: BayterekConnection, from_id: int, to_id: int)
signal node_connected(from_node: BayterekNodeButton, to_id: int)
signal node_disconnected(from_node: BayterekNodeButton, to_id: int)

func load_tree(tree_data: BayterekTree) -> void:
	_tree_data = tree_data

func create_connection(from_node: BayterekNodeButton, to_node: BayterekNodeButton) -> void:
	# TODO
	pass

func update_connected_lines(node: BayterekNodeButton) -> void:
	# TODO
	pass
