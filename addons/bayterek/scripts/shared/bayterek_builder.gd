@tool
class_name BayterekBuilder
extends RefCounted
## BayterekTreeView inşa edicisi.

var _tree: BayterekTree
var _parent: Node

func _init(tree_data: BayterekTree) -> void:
	_tree = tree_data

func set_parent(parent: Node) -> BayterekBuilder:
	_parent = parent
	return self

func build() -> BayterekTreeView:
	# TODO
	return null
