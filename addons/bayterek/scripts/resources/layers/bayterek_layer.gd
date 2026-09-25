@tool
class_name BayterekLayer
extends Resource
## Tüm katmanların türediği base sınıf.

## Layer-level override for the design's render mode.
enum RenderModeOverride {
	INHERIT,
	VECTOR,
	PIXEL,
}

## Per-layer texture filter override. INHERIT uses the design's filter.
enum TextureFilterOverride {
	INHERIT,
	LINEAR,
	NEAREST,
}

## Render mode int values, matching BayterekNodeDesign.RenderMode.
## Duplicated here to avoid a cyclic dependency between
## BayterekLayer and BayterekNodeDesign.
const RENDER_MODE_VECTOR := 0
const RENDER_MODE_PIXEL := 1

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

## Per-layer render mode override. INHERIT uses the design's mode.
@export_storage var render_mode_override: RenderModeOverride = RenderModeOverride.INHERIT

## Per-layer texture filter override. INHERIT uses the design's filter.
@export_storage var texture_filter_override: TextureFilterOverride = TextureFilterOverride.INHERIT

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

func get_matrix(design_size: Vector2, pixel_mode: bool = false) -> Transform2D:
	if not transform:
		return Transform2D.IDENTITY
	return transform.get_matrix(design_size, pixel_mode)

## Resolves the effective render mode for this layer.
## `design_mode` is an int (0 = Vector, 1 = Pixel), same values as
## BayterekNodeDesign.RenderMode. Returns the effective int mode.
## Does NOT reference BayterekNodeDesign to avoid a cyclic dependency.
func get_effective_render_mode(design_mode: int) -> int:
	match render_mode_override:
		RenderModeOverride.VECTOR:
			return RENDER_MODE_VECTOR
		RenderModeOverride.PIXEL:
			return RENDER_MODE_PIXEL
		_:
			return design_mode

## Resolves the effective texture filter for this layer.
## `design_filter` is an int (0 = Linear, 1 = Nearest), matching
## BayterekNodeDesign.TextureFilter. Returns the effective int filter.
## Does NOT reference BayterekNodeDesign to avoid a cyclic dependency.
func get_effective_texture_filter(design_filter: int) -> int:
	match texture_filter_override:
		TextureFilterOverride.LINEAR:
			return 0   # TEXTURE_FILTER_LINEAR
		TextureFilterOverride.NEAREST:
			return 1   # TEXTURE_FILTER_NEAREST
		_:
			return design_filter

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
	target.render_mode_override = render_mode_override
	target.texture_filter_override = texture_filter_override

func _to_string() -> String:
	return "%s(id=%s, name='%s', visible=%s)" % [
		get_script().resource_path.get_file() if get_script() else "BayterekLayer",
		layer_id,
		layer_name,
		visible,
	]