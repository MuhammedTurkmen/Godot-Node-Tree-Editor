@tool
class_name BayterekPrefabThumbnail
extends Control
## Small design preview for prefab cards.

const PADDING := 4.0

var design: BayterekNodeDesign = null

var _preview_scale: float = 1.0

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_design(d: BayterekNodeDesign) -> void:
	design = d
	_recompute_scale()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_recompute_scale()
		queue_redraw()

func _recompute_scale() -> void:
	if not design:
		_preview_scale = 1.0
		return

	var computed: Vector2 = design.get_computed_size()
	if computed.x <= 0.0 or computed.y <= 0.0:
		_preview_scale = 1.0
		return

	var available: Vector2 = size - Vector2(PADDING, PADDING) * 2.0
	if available.x <= 0.0 or available.y <= 0.0:
		_preview_scale = 1.0
		return

	var sx: float = available.x / computed.x
	var sy: float = available.y / computed.y
	_preview_scale = min(sx, sy)

func _draw() -> void:
	if not design:
		return

	var center: Vector2 = size * 0.5
	var base_xform := Transform2D(
		Vector2(_preview_scale, 0),
		Vector2(0, _preview_scale),
		center
	)

	var states := _get_neutral_states()

	for layer in design.layers:
		if not layer or not layer.visible:
			continue
		_draw_layer(layer, states, base_xform)

func _get_neutral_states() -> Dictionary:
	return {
		"normal": true,
		"hover": false,
		"clicked": false,
		"locked": false,
		"preallocated": false,
		"prerefund": false,
		"max_level": false,
		"allocateable": false,
		"not_allocateable": false,
	}

func _draw_layer(layer: BayterekLayer, states: Dictionary, base_xform: Transform2D) -> void:
	var state_key: String = layer.get_visual_state(states)
	var design_size: Vector2 = design.design_size
	var effective_mode: int = layer.get_effective_render_mode()
	var pixel_mode: bool = effective_mode == 1
	var layer_matrix: Transform2D = layer.get_matrix(design_size, pixel_mode)
	var effective_size: Vector2 = layer.get_size(design_size)
	var combined: Transform2D = base_xform * layer_matrix

	if layer is BayterekTextureLayer:
		_draw_texture(layer, state_key, effective_size, combined)

func _draw_texture(layer: BayterekTextureLayer, state_key: String, effective_size: Vector2, xform: Transform2D) -> void:
	if not layer.should_draw_icon(state_key):
		return
	var tex: Texture2D = layer.get_icon_for_state(state_key)
	if not tex:
		return
	var tint: Color = layer.get_tint_for_state(state_key)

	draw_set_transform_matrix(xform)
	draw_texture_rect(tex, Rect2(-effective_size * 0.5, effective_size), false, tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)