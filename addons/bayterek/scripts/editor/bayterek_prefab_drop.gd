@tool
class_name BayterekPrefabDrop
extends Control
## Canvas drop zone for prefabs.

signal prefab_dropped(prefab: BayterekPrefab, at_position: Vector2)

var editor: BayterekEditor

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	return data.get("type", "") == "prefab"

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not data is Dictionary:
		return
	var prefab = data.get("prefab", null)
	if prefab is BayterekPrefab:
		prefab_dropped.emit(prefab, at_position)