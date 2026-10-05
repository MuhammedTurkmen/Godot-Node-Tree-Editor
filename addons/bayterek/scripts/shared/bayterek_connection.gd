@tool
class_name BayterekConnection
extends Control
## Connection between two nodes.
##
## Structure:
##   BayterekConnection (Control)
##     ├── BayterekLine2D      ← draws the line
##     └── BayterekArrowOverlay ← draws the arrow heads
##
## The two children are separate CanvasItems so they can have
## INDEPENDENT texture filters.
##
## IMPORTANT: The children are created ONLY in `_init()` and NEVER
## again. Creating them in both `_init()` and `_ready()` would result
## in duplicate children and duplicate drawing.

const DEBUG_DOUBLE_DRAW := true

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

	if DEBUG_DOUBLE_DRAW:
		print("[BayterekConnection] _init instance=", get_instance_id(),
			" line=", line.get_instance_id(),
			" arrows=", arrows.get_instance_id())

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# SAFETY: If someone re-created the children after _init (should
	# never happen), kill duplicates now so we don't double-draw.
	if get_child_count() > 2:
		if DEBUG_DOUBLE_DRAW:
			print("[BayterekConnection] _ready detected ", get_child_count(),
				" children (expected 2). Cleaning duplicates.")
		_cleanup_duplicate_children()

	if DEBUG_DOUBLE_DRAW:
		print("[BayterekConnection] _ready instance=", get_instance_id(),
			" children=", get_child_count(),
			" line_children=", line.get_child_count() if line else -1)


## Removes every BayterekLine2D / BayterekArrowOverlay child except the
## first one of each type. Defends against accidental double-adds.
func _cleanup_duplicate_children() -> void:
	var seen_line: bool = false
	var seen_arrows: bool = false
	var to_remove: Array = []

	for child in get_children():
		if child is BayterekLine2D:
			if seen_line:
				to_remove.append(child)
			else:
				seen_line = true
		elif child is BayterekArrowOverlay:
			if seen_arrows:
				to_remove.append(child)
			else:
				seen_arrows = true

	for c in to_remove:
		remove_child(c)
		c.queue_free()


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