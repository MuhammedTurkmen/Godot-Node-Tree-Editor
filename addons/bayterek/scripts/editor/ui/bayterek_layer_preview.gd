@tool
class_name BayterekLayerPreview
extends Control
## Live preview of a design's layer stack.
## Supports mouse-wheel zoom and middle-drag pan.
##
## In pixel render mode, `preview_scale` is snapped to an integer so the
## preview grid stays perfectly aligned (Aseprite-style).

signal zoom_changed(zoom: float)

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

const RENDER_MODE_VECTOR := 0
const RENDER_MODE_PIXEL := 1

var design: BayterekNodeDesign = null

var preview_scale: float = 1.0
var user_zoom: float = 1.0
var pan_offset: Vector2 = Vector2.ZERO
var _fit_scale: float = 1.0

var _panning: bool = false
var _pan_start_mouse: Vector2 = Vector2.ZERO
var _pan_start_offset: Vector2 = Vector2.ZERO

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
	_apply_texture_filter()
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
	_set_user_zoom(user_zoom * Bayterek.PREVIEW_ZOOM_STEP)

func zoom_out() -> void:
	_set_user_zoom(user_zoom / Bayterek.PREVIEW_ZOOM_STEP)

func _set_user_zoom(z: float) -> void:
	var clamped: float = clampf(z, Bayterek.PREVIEW_MIN_USER_ZOOM, Bayterek.PREVIEW_MAX_USER_ZOOM)
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

func _is_pixel_design() -> bool:
	if not design:
		return false
	return int(design.render_mode) == RENDER_MODE_PIXEL

func _apply_texture_filter() -> void:
	if not design:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		return
	if _is_pixel_design():
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

# ============================================================
# FIT SCALE + PAN
# ============================================================

func _compute_content_bounds() -> Rect2:
	if not design:
		return Rect2()

	var has_any: bool = false
	var min_x: float = INF
	var min_y: float = INF
	var max_x: float = -INF
	var max_y: float = -INF

	var design_size: Vector2 = design.design_size

	for layer in design.layers:
		if not layer or not layer.visible:
			continue

		var effective_size: Vector2 = layer.get_size(design_size)
		if effective_size.x <= 0.0 or effective_size.y <= 0.0:
			continue

		var matrix: Transform2D = layer.get_matrix(design_size)
		var half: Vector2 = effective_size * 0.5

		var corners: Array[Vector2] = [
			Vector2(-half.x, -half.y),
			Vector2( half.x, -half.y),
			Vector2( half.x,  half.y),
			Vector2(-half.x,  half.y),
		]

		for c in corners:
			var w: Vector2 = matrix * c
			min_x = minf(min_x, w.x)
			min_y = minf(min_y, w.y)
			max_x = maxf(max_x, w.x)
			max_y = maxf(max_y, w.y)
			has_any = true

	if not has_any:
		return Rect2()

	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _recompute_scale() -> void:
	if not design:
		_fit_scale = 1.0
		preview_scale = user_zoom
		pan_offset = Vector2.ZERO
		return

	var bounds: Rect2 = _compute_content_bounds()

	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		bounds = Rect2(-design.design_size * 0.5, design.design_size)

	var available: Vector2 = size - Vector2(Bayterek.PREVIEW_MARGIN, Bayterek.PREVIEW_MARGIN) * 2.0
	if available.x <= 0.0 or available.y <= 0.0:
		_fit_scale = 1.0
	else:
		var sx: float = available.x / bounds.size.x
		var sy: float = available.y / bounds.size.y
		_fit_scale = min(sx, sy)

	if _is_pixel_design():
		var snapped_fit: int = maxi(1, int(floor(_fit_scale)))
		_fit_scale = float(snapped_fit)

	preview_scale = _fit_scale * user_zoom

	if _is_pixel_design():
		preview_scale = maxf(1.0, float(maxi(1, int(floor(preview_scale)))))

	var content_center: Vector2 = bounds.position + bounds.size * 0.5
	pan_offset = -content_center * preview_scale

# ============================================================
# INPUT — zoom & pan
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_set_user_zoom(user_zoom * Bayterek.PREVIEW_ZOOM_STEP)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_set_user_zoom(user_zoom / Bayterek.PREVIEW_ZOOM_STEP)
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

	var effective_mode: int = layer.get_effective_render_mode(int(design.render_mode))
	var pixel_mode: bool = effective_mode == RENDER_MODE_PIXEL

	var combined: Transform2D = base_xform * layer_matrix

	if layer is BayterekShapeLayer:
		if pixel_mode and layer.is_axis_aligned():
			_draw_shape_pixel(layer, state_key, effective_size, combined)
		else:
			_draw_shape(layer, state_key, effective_size, combined, pixel_mode)
	elif layer is BayterekTextureLayer:
		_draw_texture(layer, state_key, effective_size, combined, pixel_mode)

	if show_pivot_markers and layer.transform:
		_draw_pivot_marker(layer, combined, effective_size)

## Pixel scanline path — uses `get_pixel_spans()`. Debug dump runs once.
func _draw_shape_pixel(layer: BayterekShapeLayer, state_key: String, effective_size: Vector2, combined: Transform2D) -> void:
	# --- DEBUG DUMP (runs once) ---
	if not get_meta("_dumped", false):
		set_meta("_dumped", true)
		var s: Dictionary = layer.get_pixel_spans(effective_size)
		var fills: Array = s.get("fill", [])
		var borders: Array = s.get("border", [])
		print("=== SPANS size=", effective_size, " shape=", layer.shape_type,
			" bw=", layer.border_width, " R=", layer.corner_radius, " ===")
		print("FILL count=", fills.size())
		for i in range(maxi(0, fills.size() - 5), fills.size()):
			print("  fill[", i, "]=", fills[i])
		print("BORDER count=", borders.size())
		for i in range(maxi(0, borders.size() - 8), borders.size()):
			print("  border[", i, "]=", borders[i])
	# --- END DEBUG ---

	var spans: Dictionary = layer.get_pixel_spans(effective_size)
	var fill_spans: Array = spans.get("fill", [])
	var border_spans: Array = spans.get("border", [])

	# Shadow (integer offset, no blur).
	if layer.shadow_enabled and layer.shadow_color.a > 0.0:
		var offset: Vector2 = (layer.shadow_size * preview_scale).floor()
		var shadow_xform := Transform2D(combined.x, combined.y, combined.origin + offset)
		for rect_v in fill_spans:
			var r: Rect2i = rect_v
			var tl: Vector2 = shadow_xform * Vector2(r.position.x, r.position.y)
			var br: Vector2 = shadow_xform * Vector2(r.position.x + r.size.x, r.position.y + r.size.y)
			draw_rect(Rect2(tl, br - tl), layer.shadow_color, true)

	if layer.should_draw_fill(state_key):
		var fill_color: Color = layer.get_fill_color_for_state(state_key)
		if fill_color.a > 0.0:
			for rect_v in fill_spans:
				var r: Rect2i = rect_v
				var tl: Vector2 = combined * Vector2(r.position.x, r.position.y)
				var br: Vector2 = combined * Vector2(r.position.x + r.size.x, r.position.y + r.size.y)
				draw_rect(Rect2(tl, br - tl), fill_color, true)

	if layer.should_draw_border(state_key):
		var border_color: Color = layer.get_border_color_for_state(state_key)
		if border_color.a > 0.0 and layer.border_width > 0.0:
			for rect_v in border_spans:
				var r: Rect2i = rect_v
				var tl: Vector2 = combined * Vector2(r.position.x, r.position.y)
				var br: Vector2 = combined * Vector2(r.position.x + r.size.x, r.position.y + r.size.y)
				draw_rect(Rect2(tl, br - tl), border_color, true)

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
		"clicked": false,
		"locked": false,
		"preallocated": false,
		"prerefund": false,
		"max_level": false,
		"allocateable": false,
		"not_allocateable": false,
	}

func _draw_shape(layer: BayterekShapeLayer, state_key: String, effective_size: Vector2, xform: Transform2D, pixel_mode: bool) -> void:
	if layer.shadow_enabled and layer.shadow_color.a > 0.0:
		var full_verts: PackedVector2Array = layer.get_polygon_vertices(effective_size, pixel_mode)
		if not full_verts.is_empty():
			_draw_shape_shadow(layer, full_verts, xform, pixel_mode)

	var draw_border: bool = layer.should_draw_border(state_key)
	var draw_fill: bool = layer.should_draw_fill(state_key)

	if draw_fill:
		var fill_color: Color = layer.get_fill_color_for_state(state_key)
		if fill_color.a > 0.0:
			var fill_verts: PackedVector2Array = layer.get_fill_vertices(effective_size, pixel_mode)
			if fill_verts.is_empty():
				fill_verts = layer.get_polygon_vertices(effective_size, pixel_mode)
			if not fill_verts.is_empty():
				_draw_fill(fill_verts, xform, fill_color)

	if draw_border:
		var border_color: Color = layer.get_border_color_for_state(state_key)
		if border_color.a > 0.0 and layer.border_width > 0.0:
			var layer_avg: float = 1.0
			if layer.transform:
				layer_avg = layer.transform.get_avg_scale()
			var scaled_width: float = layer.border_width * preview_scale * layer_avg
			var use_caps: bool = not layer.border_corner_gap
			var antialiased: bool = not pixel_mode

			var segments: Array = layer.get_border_segments(effective_size, pixel_mode)
			for seg in segments:
				if not (seg is PackedVector2Array):
					continue
				var pts: PackedVector2Array = seg
				if pts.size() < 2:
					continue

				var transformed := PackedVector2Array()
				transformed.resize(pts.size())
				for i in pts.size():
					transformed[i] = xform * pts[i]

				if transformed.size() == 2:
					draw_line(transformed[0], transformed[1], border_color, scaled_width, antialiased)
					if use_caps:
						_draw_cap(transformed[0], border_color, scaled_width)
						_draw_cap(transformed[1], border_color, scaled_width)
				else:
					draw_polyline(transformed, border_color, scaled_width, antialiased)
					if use_caps:
						_draw_cap(transformed[0], border_color, scaled_width)
						_draw_cap(transformed[transformed.size() - 1], border_color, scaled_width)

func _draw_cap(pos: Vector2, color: Color, width: float) -> void:
	var radius: float = width * 0.5
	if radius < 0.5:
		return
	draw_circle(pos, radius, color)

func _draw_shape_shadow(layer: BayterekShapeLayer, verts: PackedVector2Array, xform: Transform2D, pixel_mode: bool) -> void:
	var offset: Vector2 = layer.shadow_size * preview_scale
	var blur: float = layer.shadow_blur * preview_scale
	var base_color: Color = layer.shadow_color

	if pixel_mode or blur <= 0.01:
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

func _draw_texture(layer: BayterekTextureLayer, state_key: String, effective_size: Vector2, xform: Transform2D, pixel_mode: bool) -> void:
	if not layer.should_draw_icon(state_key):
		return
	var tex: Texture2D = layer.get_icon_for_state(state_key)
	if not tex:
		return
	var tint: Color = layer.get_tint_for_state(state_key)

	if pixel_mode:
		var half: Vector2 = effective_size * 0.5
		var tl: Vector2 = xform * (-half)
		var br: Vector2 = xform * half
		var dst_pos: Vector2 = tl.floor()
		var dst_size: Vector2 = (br - tl).floor()
		draw_set_transform_matrix(Transform2D.IDENTITY)
		draw_texture_rect(tex, Rect2(dst_pos, dst_size), false, tint)
		return

	draw_set_transform_matrix(xform)
	draw_texture_rect(tex, Rect2(-effective_size * 0.5, effective_size), false, tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)