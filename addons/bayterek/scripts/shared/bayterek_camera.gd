@tool
class_name BayterekCamera
extends RefCounted
## Pan + zoom kamerası. (Faz 3.2'de tamamlanacak)

signal zoom_changed(zoom: float, previous_zoom: float)

var _viewport: Control
var _bounds: Rect2
var _zoom: float = 1.0

func set_viewport(viewport: Control) -> void:
	_viewport = viewport
	if _viewport:
		_viewport.offset_transform_enabled = true
		_viewport.offset_transform_visual_only = false

func set_bounds(bounds: Rect2) -> void:
	_bounds = bounds

func get_zoom() -> float:
	return _zoom