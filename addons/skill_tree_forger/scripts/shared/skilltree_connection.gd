@tool
class_name SkillTreeConnection
extends Control
## Connection between two nodes.
##
## Structure:
##   SkillTreeConnection (Control)
##     ├── SkillTreeLine2D       ← draws the line
##     └── SkillTreeArrowOverlay ← draws the arrow heads

var from_id: int = -1
var to_id: int = -1

var line_data: SkillTreeLineData = null

var line: SkillTreeLine2D = null
var arrows: SkillTreeArrowOverlay = null

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	line = SkillTreeLine2D.new()
	line.name = "Line"
	add_child(line)

	arrows = SkillTreeArrowOverlay.new()
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