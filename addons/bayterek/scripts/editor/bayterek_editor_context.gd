@tool
class_name BayterekEditorContext
extends PopupMenu
## Sağ tık context menu.

signal new_node(node_type: int)
signal duplicate_node
signal delete_node
signal save_as_prefab
signal save_as_copy
signal make_unique

@export var editor: BayterekEditor

func init() -> void:
	# TODO
	pass

func update_items(node: BayterekNodeButton) -> void:
	# TODO
	pass
