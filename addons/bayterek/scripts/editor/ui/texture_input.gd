@tool
class_name BayterekInspectorTextureInput
extends Control
## Texture input widget'ı (drag-drop + browse + clear).

signal texture_dropped(path: String)

@export var title: String
@export var title_label: Label
@export var texture_rect: TextureRect
@export var load_button: Button
@export var clear_button: Button
@export var empty_label: Label

func _enter_tree() -> void:
	if title_label:
		title_label.text = title
