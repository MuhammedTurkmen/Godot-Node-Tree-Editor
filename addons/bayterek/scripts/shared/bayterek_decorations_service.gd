@tool
class_name BayterekDecorationsService
extends BayterekBaseService
## Dekor node'ları yönetimi.

signal decoration_created(decoration: BayterekNodeButton)
signal decoration_pressed(node: BayterekNodeButton)

func load_tree(tree_data: BayterekTree) -> void:
	_tree_data = tree_data
