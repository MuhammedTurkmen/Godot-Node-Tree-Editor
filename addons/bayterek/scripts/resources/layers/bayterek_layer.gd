@tool
class_name BayterekLayer
extends Resource
## Tüm katmanların türediği base sınıf.

enum RenderModeOverride {
	INHERIT,
	VECTOR,
	PIXEL,
}

enum TextureFilterOverride {
	INHERIT,
	LINEAR,
	NEAREST,
}

## Render mode int values. Duplicated to avoid a cyclic dependency.
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

@export_storage var layer_id: String = ""

@export_storage var layer_name: String = "Layer"
@export_storage var visible: bool = true
@export_storage var transform: BayterekLayerTransform
@export_storage var animation_id: String = ""
@export_storage var animated: bool = false

## Per-layer render mode. INHERIT falls back to VECTOR.
@export_storage var render_mode_override: RenderModeOverride = RenderModeOverride.INHERIT

## Per-layer texture filter. INHERIT falls back to LINEAR.
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
## INHERIT defaults to VECTOR (there is no design-level setting anymore).
func get_effective_render_mode() -> int:
	match render_mode_override:
		RenderModeOverride.VECTOR:
			return RENDER_MODE_VECTOR
		RenderModeOverride.PIXEL:
			return RENDER_MODE_PIXEL
		_:
			return RENDER_MODE_VECTOR

## Resolves the effective texture filter for this layer.
## INHERIT defaults to LINEAR.
func get_effective_texture_filter() -> int:
	match texture_filter_override:
		TextureFilterOverride.LINEAR:
			return 0
		TextureFilterOverride.NEAREST:
			return 1
		_:
			return 0

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