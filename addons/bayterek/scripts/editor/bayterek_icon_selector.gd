@tool
class_name BayterekIconSelector
extends Popup
## Spritesheet icon seçici.

signal icon_selected(node_type: int, texture: Texture2D, region: Vector2)

@export var editor: BayterekEditor

func init() -> void:
	# TODO
	pass

func load_icons(node_type: int) -> void:
	# TODO
	pass
