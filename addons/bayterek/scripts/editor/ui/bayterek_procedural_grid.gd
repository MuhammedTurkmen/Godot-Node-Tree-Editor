@tool
class_name BayterekProceduralGrid
extends Control
## Prosedürel grid çizimi.
## Parent (main_container) offset_transform'ini takip eder.

@export var cell_size: Vector2 = Vector2(16, 16)
@export var primary_line_step: int = 4
@export var line_color: Color = Color(1, 1, 1, 0.12)
@export var line_width: float = 1.0

## Grid'in takip edeceği container (zoom/pan uygulanan).
var target: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if target:
		queue_redraw()

func _draw() -> void:
	if not target or not is_inside_tree():
		return

	var scale_factor: Vector2 = target.offset_transform_scale
	var pan: Vector2 = target.offset_transform_position
	var view_size: Vector2 = size

	# Küçük (secondary) grid
	var step: Vector2 = cell_size * scale_factor
	_draw_grid_lines(step, pan, view_size, line_color, line_width)

	# Büyük (primary) grid
	if primary_line_step > 0:
		var primary_step: Vector2 = cell_size * primary_line_step * scale_factor
		_draw_grid_lines(primary_step, pan, view_size, line_color, line_width * 1.5)

func _draw_grid_lines(step: Vector2, pan: Vector2, view_size: Vector2, color: Color, width: float) -> void:
	if step.x <= 0.5 or step.y <= 0.5:
		return

	# Grid'i pan'e göre kaydır
	var origin_x: float = fposmod(pan.x, step.x)
	var origin_y: float = fposmod(pan.y, step.y)

	var x: float = origin_x
	while x <= view_size.x:
		draw_line(Vector2(x, 0), Vector2(x, view_size.y), color, width)
		x += step.x

	var y: float = origin_y
	while y <= view_size.y:
		draw_line(Vector2(0, y), Vector2(view_size.x, y), color, width)
		y += step.y