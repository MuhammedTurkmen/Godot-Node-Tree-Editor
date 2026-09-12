@tool
extends Button
## Editör ikonu taşıyan buton.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

@export var icon_name: String = "Node":
	set(value):
		icon_name = value
		_update_icon()

func _enter_tree() -> void:
	_update_icon()

func _update_icon() -> void:
	if not Engine.is_editor_hint():
		return
	var theme := EditorInterface.get_editor_theme()
	if theme.has_icon(icon_name, Bayterek.ICON_THEME):
		icon = theme.get_icon(icon_name, Bayterek.ICON_THEME)
	else:
		icon = null
