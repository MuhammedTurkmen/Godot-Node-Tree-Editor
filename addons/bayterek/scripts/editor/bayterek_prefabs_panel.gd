@tool
class_name BayterekPrefabPanelEditor
extends Control
## Prefab listesi paneli.

signal changed

@export var filter: LineEdit
@export var list: ItemList

var editor: BayterekEditor

func add_prefab(prefab: BayterekPrefab, is_copy: bool = false) -> void:
	# TODO
	pass
