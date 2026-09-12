@tool
class_name BayterekMoveTool
extends Control
## Node taşıma oku.

signal moved(positions: Array[Vector2])
signal released(positions: Array[Vector2], start_positions: Array[Vector2])

var nodes: Array[BayterekNodeButton] = []
