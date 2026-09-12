@tool
class_name BayterekSettingsEditor
extends Control
## Tree Settings editörü.

signal changed
signal size_changed
signal border_scale_changed
signal background_changed
signal icon_size_changed
signal node_size_changed
signal line_texture_changed
signal revealed_changed
signal allocation_changed
signal preallocation_changed
signal multiallocation_changed

@export var editor: BayterekEditor

func init() -> void:
	# TODO
	pass

func load_tree(tree_data: BayterekTree) -> void:
	# TODO
	pass
