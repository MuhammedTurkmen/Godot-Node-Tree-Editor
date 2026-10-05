@tool
class_name BayterekConnection
extends Control
## Connection between two nodes.
##
## Structure:
##   BayterekConnection (Control)
##     ├── BayterekLine2D       ← draws the line
##     └── BayterekArrowOverlay ← draws the arrow heads

var from_id: int = -1
var to_id: int = -1

var line_data: BayterekLineData = null

var line: BayterekLine2D = null
var arrows: BayterekArrowOverlay = null

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	line = BayterekLine2D.new()
	line.name = "Line"
	add_child(line)

	arrows = BayterekArrowOverlay.new()
	arrows.name = "Arrows"
	add_child(arrows)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func clear_points() -> void:
	if line:
		line.clear_points()

func add_point(p: Vector2) -> void:
	if line:
		line.add_point(p)

func get_point_count() -> int:
	return line.get_point_count() if line else 0

func get_point_position(index: int) -> Vector2:
	return line.get_point_position(index) if line else Vector2.ZERO


func set_points(pts: PackedVector2Array) -> void:
	if line:
		line.points = pts