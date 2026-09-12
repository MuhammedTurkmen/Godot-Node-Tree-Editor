@tool
class_name BayterekPrefabDrop
extends Control
## Prefab drag-drop alanı.

signal prefab_dropped(prefab: BayterekPrefab)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is BayterekPrefab

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	prefab_dropped.emit(data)
