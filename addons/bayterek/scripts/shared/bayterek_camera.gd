@tool
class_name BayterekCamera
extends RefCounted
## Pan + zoom kamerası.

signal zoom_changed(zoom: float, previous_zoom: float)

var _viewport: Control
var _bounds: Rect2
var _zoom: float = 1.0
