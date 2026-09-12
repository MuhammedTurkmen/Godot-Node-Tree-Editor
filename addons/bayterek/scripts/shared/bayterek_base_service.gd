@tool
class_name BayterekBaseService
extends RefCounted
## Tüm servislerin türediği temel sınıf.

var _tree_view: BayterekTreeView
var _tree_data: BayterekTree
var _scene: PackedScene

func _init(tree_view: BayterekTreeView) -> void:
	_tree_view = tree_view

func set_scene(scene: PackedScene) -> void:
	_scene = scene