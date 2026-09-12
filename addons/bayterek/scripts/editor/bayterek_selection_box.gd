@tool
class_name BayterekSelectionBox
extends Panel
## Alan seçim kutusu.

signal selected(rect: Rect2)

var selecting: bool = false
var _view: BayterekTreeView

func set_view(view: BayterekTreeView) -> void:
	_view = view
