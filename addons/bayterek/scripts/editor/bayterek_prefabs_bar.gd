@tool
class_name BayterekPrefabsBar
extends TabBar
## Prefab alt bar.

signal changed

@export var editor: BayterekEditor
@export var prefab_panel_scene: PackedScene
@export var splitter: SplitContainer
@export var prefabs_panel: Control

func init() -> void:
	# TODO
	pass
