@tool
class_name BayterekLayer
extends Resource
## Tüm katmanların türediği base sınıf.

const STATES: Array[String] = [
	"normal",
	"hover",
	"clicked",
	"locked",
	"preallocated",
	"prerefund",
	"max_level",
	"allocateable",
	"not_allocateable",
]

const STATE_PRIORITY: Array[String] = [
	"clicked",
	"hover",
	"prerefund",
	"preallocated",
	"allocateable",
	"not_allocateable",
	"max_level",
	"locked",
	"normal",
]

## Kalıcı layer kimliği (UUID v4). Export field path'lerinde kullanılır.
@export_storage var layer_id: String = ""

@export_storage var layer_name: String = "Layer"
@export_storage var visible: bool = true
@export_storage var transform: BayterekLayerTransform
@export_storage var animation_id: String = ""
@export_storage var animated: bool = false

func _init() -> void:
	if layer_id.is_empty():
		layer_id = BayterekUUIDGenerator.v4()
	if not transform:
		transform = BayterekLayerTransform.new()

func get_visual_state(node_states: Dictionary) -> String:
	for state in STATE_PRIORITY:
		if not _is_state_checkbox_on(state):
			continue
		if state == "normal":
			return "normal"
		if node_states.get(state, false):
			return state
	return "normal"

func _is_state_checkbox_on(_state: String) -> bool:
	return false

func get_size(design_size: Vector2) -> Vector2:
	if not transform:
		return design_size
	return transform.get_effective_size(design_size)

func get_matrix(design_size: Vector2) -> Transform2D:
	if not transform:
		return Transform2D.IDENTITY
	return transform.get_matrix(design_size)

## Duplicate ederken layer_id KORUNUR. Yeni bir ID istiyorsanız
## caller tarafından atanmalı (örn. Layer Editor'ün "Duplicate" butonu).
func duplicate_layer() -> BayterekLayer:
	var copy := BayterekLayer.new()
	_copy_base_to(copy)
	return copy

func _copy_base_to(target: BayterekLayer) -> void:
	target.layer_id = layer_id
	target.layer_name = layer_name
	target.visible = visible
	target.transform = transform.duplicate_transform() if transform else BayterekLayerTransform.new()
	target.animation_id = animation_id
	target.animated = animated

func _to_string() -> String:
	return "%s(id=%s, name='%s', visible=%s)" % [
		get_script().resource_path.get_file() if get_script() else "BayterekLayer",
		layer_id,
		layer_name,
		visible,
	]