@tool
class_name BayterekTreeState
extends RefCounted
## Runtime allocation durumu.

var version: int = 1
var allocated_nodes: Array[int] = []
var allocation_level: Dictionary = {}
