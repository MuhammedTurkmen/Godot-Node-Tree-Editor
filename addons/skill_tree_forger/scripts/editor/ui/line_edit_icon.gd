@tool
extends LineEdit
## Sağ ikonlu LineEdit.

const Bayterek = preload("res://addons/skill_tree_forger/scripts/shared/skill_tree_forger.gd")

@export var icon: String = "Node":
	set(value):
		icon = value
		_update_icon()

func _enter_tree() -> void:
	_update_icon()

func _update_icon() -> void:
	if has_theme_icon(icon, Bayterek.ICON_THEME):
		right_icon = get_theme_icon(icon, Bayterek.ICON_THEME)
	else:
		right_icon = null
