@tool
class_name BayterekLayerPreview
extends Control
## Live preview of a design's layer stack.
## Renders the same way BayterekNodeButton does, but scaled to fit.
## Supports mouse-wheel zoom and middle-drag pan.

signal zoom_changed(zoom: float)

const PREVIEW_MARGIN := 20.0
const MIN_USER_ZOOM := 0.1
const MAX_USER_ZOOM := 8.0
const ZOOM_STEP := 1.15

var design: BayterekNodeDesign = null

var preview_scale: float = 1.0
var user_zoom: float = 1.0
var pan_offset: Vector2 = Vector2.ZERO
var _fit_scale: float = 1.0

var _panning: bool = false
var _pan_start_mouse: Vector2 = Vector2.ZERO
var _pan_start_offset: Vector2 = Vector2.ZERO

## Draw a small marker at each layer's pivot point.
var show_pivot_markers: bool = true

func _ready() -> void:
	custom_minimum_size = Vector2(200, 200)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.10, 1.0)
	style.border_color = Color(0.25, 0.25, 0.30, 1.0)
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)

func set_design(d: BayterekNodeDesign) -> void:
	design = d
	_reset_view()
	_recompute_scale()
	queue_redraw()

func _reset_view() -> void:
	user_zoom = 1.0
	pan_offset = Vector2.ZERO

func reset_view() -> void:
	_reset_view()
	_recompute_scale()
	queue_redraw()
	zoom_changed.emit(user_zoom)

func zoom_in() -> void:
	_set_user_zoom(user_zoom * ZOOM_STEP)

func zoom_out() -> void:
	_set_user_zoom(user_zoom / ZOOM_STEP)

func _set_user_zoom(z: float) -> void:
	var clamped: float = clampf(z, MIN_USER_ZOOM, MAX_USER_ZOOM)
	if is_equal_approx(clamped, user_zoom):
		return
	user_zoom = clamped
	_recompute_scale()
	queue_redraw()
	zoom_changed.emit(user_zoom)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_recompute_scale()
		queue_redraw()

func _recompute_scale() -> void:
	if not design:
		_fit_scale = 1.0
		preview_scale = user_zoom
		return

	var available: Vector2 = size - Vector2(PREVIEW_MARGIN, PREVIEW_MARGIN) * 2.0
	if design.design_size.x <= 0 or design.design_size.y <= 0:
		_fit_scale = 1.0
	else:
		var sx: float = available.x / design.design_size.x
		var sy: float = available.y / design.design_size.y
		_fit_scale = min(sx, sy)

	preview_scale = _fit_scale * user_zoom

# ============================================================
# INPUT — zoom & pan
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_set_user_zoom(user_zoom * ZOOM_STEP)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_set_user_zoom(user_zoom / ZOOM_STEP)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
			if _panning:
				_pan_start_mouse = event.position
				_pan_start_offset = pan_offset
			accept_event()
	elif event is InputEventMouseMotion and _panning:
		pan_offset = _pan_start_offset + (event.position - _pan_start_mouse)
		queue_redraw()
		accept_event()

# ============================================================
# DRAW
# ============================================================

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.08, 0.10, 1.0), true)

	if not design:
		return

	_draw_background_grid()

	var center: Vector2 = size * 0.5 + pan_offset
	var base_xform := Transform2D(
		Vector2(preview_scale, 0),
		Vector2(0, preview_scale),
		center
	)

	_draw_design_center_marker(center)

	for layer in design.layers:
		if not layer or not layer.visible:
			continue
		_draw_layer(layer, base_xform)

func _draw_design_center_marker(center: Vector2) -> void:
	var c := Color(0.5, 0.6, 0.8, 0.35)
	draw_line(center - Vector2(10, 0), center + Vector2(10, 0), c, 1.0)
	draw_line(center - Vector2(0, 10), center + Vector2(0, 10), c, 1.0)

func _draw_background_grid() -> void:
	var step: float = 16.0 * preview_scale
	if step < 4.0:
		step = 4.0
	var color := Color(1, 1, 1, 0.05)

	var origin: Vector2 = Vector2(fposmod(pan_offset.x, step), fposmod(pan_offset.y, step))

	var x: float = origin.x
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), color, 1.0)
		x += step

	var y: float = origin.y
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), color, 1.0)
		y += step

func _draw_layer(layer: BayterekLayer, base_xform: Transform2D) -> void:
	var simulated := _get_simulated_states()
	var state_key: String = layer.get_visual_state(simulated)
	var design_size: Vector2 = design.design_size
	var layer_matrix: Transform2D = layer.get_matrix(design_size)
	var effective_size: Vector2 = layer.get_size(design_size)

	var combined: Transform2D = base_xform * layer_matrix

	if layer is BayterekShapeLayer:
		_draw_shape(layer, state_key, effective_size, combined)
	elif layer is BayterekTextureLayer:
		_draw_texture(layer, state_key, effective_size, combined)

	if show_pivot_markers and layer.transform:
		_draw_pivot_marker(layer, combined, effective_size)

func _draw_pivot_marker(layer: BayterekLayer, combined: Transform2D, effective_size: Vector2) -> void:
	var t: BayterekLayerTransform = layer.transform
	if not t:
		return

	var pivot_local: Vector2 = t.get_pivot_local(effective_size)
	var pivot_screen: Vector2 = combined * pivot_local

	var cross_color := Color(1.0, 0.2, 0.2, 0.9)
	var arm := 6.0
	draw_line(pivot_screen - Vector2(arm, 0), pivot_screen + Vector2(arm, 0), cross_color, 1.5)
	draw_line(pivot_screen - Vector2(0, arm), pivot_screen + Vector2(0, arm), cross_color, 1.5)

	draw_circle(pivot_screen, 3.0, cross_color)
	draw_arc(pivot_screen, 3.0, 0.0, TAU, 16, Color(0, 0, 0, 0.9), 1.0, true)

func _get_simulated_states() -> Dictionary:
	return {
		"normal": true,
		"hover": false,
		"locked": false,
		"preallocated": false,
		"prerefund": false,
		"max_level": false,
		"allocateable": false,
		"not_allocateable": false,
	}

func _draw_shape(layer: BayterekShapeLayer, state_key: String, effective_size: Vector2, xform: Transform2D) -> void:
	# --- Shadow (based on full outline) ---
	if layer.shadow_enabled and layer.shadow_color.a > 0.0:
		var full_verts: PackedVector2Array = layer.get_polygon_vertices(effective_size)
		if not full_verts.is_empty():
			_draw_shape_shadow(layer, full_verts, xform)

	var draw_border: bool = layer.should_draw_border(state_key)
	var draw_fill: bool = layer.should_draw_fill(state_key)

	# --- Border ---
	if draw_border:
		var border_color: Color = layer.get_border_color_for_state(state_key)
		if border_color.a > 0.0 and layer.border_width > 0.0:
			var outer_verts: PackedVector2Array = layer.get_polygon_vertices(effective_size)
			if not outer_verts.is_empty():
				_draw_border_polyline(outer_verts, xform, border_color, layer.border_width)

	# --- Fill on top (covers the inner half of the border) ---
	if draw_fill:
		var fill_color: Color = layer.get_fill_color_for_state(state_key)
		if fill_color.a > 0.0:
			var verts: PackedVector2Array = layer.get_fill_vertices(effective_size)
			if verts.is_empty():
				verts = layer.get_polygon_vertices(effective_size)
			if not verts.is_empty():
				_draw_fill(verts, xform, fill_color)

	# --- DEBUG visualization (remove once corners are tuned) ---
	if layer.corner_radius > 0.0:
		var raw_verts: PackedVector2Array = layer._make_raw_polygon(effective_size)
		if raw_verts.size() >= 2:
			var raw_pts := PackedVector2Array()
			raw_pts.resize(raw_verts.size() + 1)
			for i in raw_verts.size():
				raw_pts[i] = xform * raw_verts[i]
			raw_pts[raw_verts.size()] = raw_pts[0]
			draw_polyline(raw_pts, Color(0.3, 0.5, 1.0, 0.6), 1.0)

func _draw_border_polyline(verts: PackedVector2Array, xform: Transform2D, color: Color, width: float) -> void:
	if verts.size() < 2:
		return

	var scaled_width: float = width * preview_scale
	var pts := PackedVector2Array()
	pts.resize(verts.size() + 1)
	for i in verts.size():
		pts[i] = xform * verts[i]
	pts[verts.size()] = pts[0]

	draw_polyline(pts, color, scaled_width * 2.0, true)

func _draw_shape_shadow(layer: BayterekShapeLayer, verts: PackedVector2Array, xform: Transform2D) -> void:
	var offset: Vector2 = layer.shadow_size * preview_scale
	var blur: float = layer.shadow_blur * preview_scale
	var base_color: Color = layer.shadow_color

	if blur <= 0.01:
		var shadow_xform := Transform2D(xform.x, xform.y, xform.origin + offset)
		_draw_fill(verts, shadow_xform, base_color)
		return

	var passes: int = 4
	var alpha_per_pass: float = base_color.a / float(passes)
	var color_per_pass := Color(base_color.r, base_color.g, base_color.b, alpha_per_pass)

	var dir: Vector2 = offset
	if dir.length_squared() > 0.0001:
		dir = dir.normalized()
	else:
		dir = Vector2.ZERO

	for i in passes:
		var spread: float = blur * (float(i) / float(passes - 1))
		var pass_offset: Vector2 = offset - dir * spread * 0.5
		var expanded: PackedVector2Array = _expand_verts(verts, spread)

		var shadow_xform := Transform2D(xform.x, xform.y, xform.origin + pass_offset)
		_draw_fill(expanded, shadow_xform, color_per_pass)

func _draw_fill(verts: PackedVector2Array, xform: Transform2D, color: Color) -> void:
	var transformed := PackedVector2Array()
	transformed.resize(verts.size())
	for i in verts.size():
		transformed[i] = xform * verts[i]
	draw_colored_polygon(transformed, color)

func _expand_verts(verts: PackedVector2Array, offset: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(verts.size())
	for i in verts.size():
		var v: Vector2 = verts[i]
		var dir: Vector2 = v
		if dir.length_squared() > 0.0001:
			dir = dir.normalized()
		out[i] = v + dir * offset
	return out

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