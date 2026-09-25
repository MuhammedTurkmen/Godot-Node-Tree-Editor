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

	if layer is BayterekShapeLayer:
		_draw_shape(layer, state_key, effective_size, combined)
	elif layer is BayterekTextureLayer:
		_draw_texture(layer, state_key, effective_size, combined)

func _draw_shape(layer: BayterekShapeLayer, state_key: String, effective_size: Vector2, xform: Transform2D) -> void:
	if layer.shadow_enabled and layer.shadow_color.a > 0.0:
		var full_verts: PackedVector2Array = layer.get_polygon_vertices(effective_size)
		if not full_verts.is_empty():
			var offset: Vector2 = layer.shadow_size * _preview_scale
			var shadow_xform := Transform2D(xform.x, xform.y, xform.origin + offset)
			_draw_fill(full_verts, shadow_xform, layer.shadow_color)

	if layer.should_draw_fill(state_key):
		var fill_color: Color = layer.get_fill_color_for_state(state_key)
		if fill_color.a > 0.0:
			var fill_verts: PackedVector2Array = layer.get_fill_vertices(effective_size)
			if fill_verts.is_empty():
				fill_verts = layer.get_polygon_vertices(effective_size)
			if not fill_verts.is_empty():
				_draw_fill(fill_verts, xform, fill_color)

	if layer.should_draw_border(state_key):
		var border_color: Color = layer.get_border_color_for_state(state_key)
		if border_color.a > 0.0 and layer.border_width > 0.0:
			var center_verts: PackedVector2Array = layer.get_border_centerline_vertices(effective_size)
			if not center_verts.is_empty():
				_draw_border_ring(center_verts, xform, border_color, layer.border_width * _preview_scale)

func _draw_fill(verts: PackedVector2Array, xform: Transform2D, color: Color) -> void:
	var transformed := PackedVector2Array()
	transformed.resize(verts.size())
	for i in verts.size():
		transformed[i] = xform * verts[i]
	draw_colored_polygon(transformed, color)

func _draw_border_ring(verts: PackedVector2Array, xform: Transform2D, color: Color, width: float) -> void:
	if verts.size() < 2:
		return
	var pts := PackedVector2Array()
	pts.resize(verts.size() + 1)
	for i in verts.size():
		pts[i] = xform * verts[i]
	pts[verts.size()] = pts[0]
	draw_polyline(pts, color, max(1.0, width), true)

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