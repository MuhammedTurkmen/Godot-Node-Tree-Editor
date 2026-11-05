@tool
class_name SkillTreeBaseService
extends RefCounted
## Tüm servislerin türediği temel sınıf.

var _tree_view: SkillTreeView
var _tree_data: SkillTree
var _scene: PackedScene

func _init(tree_view: SkillTreeView) -> void:
	_tree_view = tree_view

func set_scene(scene: PackedScene) -> void:
	_scene = scene