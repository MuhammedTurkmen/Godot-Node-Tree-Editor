@tool
class_name BayterekProceduralGrid
extends Control
## Prosedürel grid çizimi.

@export var primary_line_step: int = 4
@export var line_color: Color = Color(1, 1, 1, 0.12)
@export var line_width: float = 1.0
var cell_size: Vector2 = Vector2(16, 16)
var parent: Control
