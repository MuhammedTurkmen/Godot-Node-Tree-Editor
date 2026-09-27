@tool
class_name BayterekLayerPreview
extends Control
## Live preview of a design's layer stack.

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

var bg_color: Color = Color(0.08, 0.08, 0.10, 1.0) : set = set_bg_color

var show_nine_patch_guides: bool = false

var _texture_layer_root: Node2D
var _layer_nodes: Dictionary = {}

func set_bg_color(c: Color) -> void:
	bg_color = c
	queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(200, 200)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	_texture_layer_root = Node2D.new()
	_texture_layer_root.name = "TextureLayerRoot"
	add_child(_texture_layer_root)

func set_design(d: BayterekNodeDesign) -> void:
	if design and design.layers_changed.is_connected(_on_design_changed):
		design.layers_changed.disconnect(_on_design_changed)

	design = d
	_reset_view()
	_recompute_scale()
	_rebuild_layer_nodes()

	if design:
		design.layers_changed.connect(_on_design_changed)

	queue_redraw()

func _on_design_changed(_d: BayterekNodeDesign, _change_type: String) -> void:
	_recompute_scale()
	_rebuild_layer_nodes()
	queue_redraw()

func _reset_view() -> void:
	user_zoom = 1.0
	pan_offset = Vector2.ZERO

func reset_view() -> void:
	_reset_view()
	_recompute_scale()
	_rebuild_layer_nodes()
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
	_rebuild_layer_nodes()
	queue_redraw()
	zoom_changed.emit(user_zoom)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_recompute_scale()
		_rebuild_layer_nodes()
		queue_redraw()

# ============================================================
# FIT SCALE + PAN
# ============================================================

func _compute_content_bounds() -> Rect2:
	if not design:
		return Rect2()
	if not design.bounds_layer_id.is_empty():
		return design.get_bounds_rect()
	return design.get_computed_bounds()

func _recompute_scale() -> void:
	if not design:
		_fit_scale = 1.0
		preview_scale = user_zoom
		pan_offset = Vector2.ZERO
		return

	var bounds: Rect2 = _compute_content_bounds()

	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		var computed: Vector2 = design.get_computed_size()
		bounds = Rect2(-computed * 0.5, computed)

	var available: Vector2 = size - Vector2(Bayterek.PREVIEW_MARGIN, Bayterek.PREVIEW_MARGIN) * 2.0
	if available.x <= 0.0 or available.y <= 0.0:
		_fit_scale = 1.0
	else:
		var sx: float = available.x / bounds.size.x
		var sy: float = available.y / bounds.size.y
		_fit_scale = min(sx, sy)

	preview_scale = _fit_scale * user_zoom

	var content_center: Vector2 = bounds.position + bounds.size * 0.5
	pan_offset = -content_center * preview_scale

# ============================================================
# INPUT
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
		_rebuild_layer_nodes()
		queue_redraw()
		accept_event()

# ============================================================
# LAYER NODES
# ============================================================

func rebuild_texture_rects() -> void:
	_rebuild_layer_nodes()

func _rebuild_layer_nodes() -> void:
	if not _texture_layer_root:
		return

	var valid_ids: Dictionary = {}
	if design:
		for layer in design.layers:
			if layer is BayterekTextureLayer and layer.visible:
				valid_ids[layer.layer_id] = true

	for layer_id in _layer_nodes.keys():
		if not valid_ids.has(layer_id):
			var ln: BayterekLayerNode = _layer_nodes[layer_id]
			if is_instance_valid(ln):
				ln.queue_free()
			_layer_nodes.erase(layer_id)

	if not design:
		return

	for layer in design.layers:
		if not layer or not layer.visible:
			continue
		if not (layer is BayterekTextureLayer):
			continue

		var ln: BayterekLayerNode = _layer_nodes.get(layer.layer_id, null)
		if not ln or not is_instance_valid(ln):
			ln = BayterekLayerNode.new()
			ln.name = "LayerNode_%s" % layer.layer_id
			_texture_layer_root.add_child(ln)
			_layer_nodes[layer.layer_id] = ln

		ln.set_layer(layer)

	_update_layer_nodes()

func _update_layer_nodes() -> void:
	if not design:
		return

	var states := _get_simulated_states()

	var center: Vector2 = size * 0.5 + pan_offset
	var base_xform := Transform2D(
		Vector2(preview_scale, 0),
		Vector2(0, preview_scale),
		center
	)

	var design_size: Vector2 = design.design_size

	for layer_id in _layer_nodes.keys():
		var ln: BayterekLayerNode = _layer_nodes[layer_id]
		if not is_instance_valid(ln):
			continue
		var layer: BayterekTextureLayer = ln.layer
		if not layer:
			continue

		var state_key: String = layer.get_visual_state(states)
		ln.set_state(state_key)

		var effective_mode: int = layer.get_effective_render_mode()
		var pixel_mode: bool = effective_mode == RENDER_MODE_PIXEL

		ln.update(design_size, pixel_mode)

		# Preview doesn't apply node-wide transform (no rotation/skew),
		# so both branches use the same base_xform.
		ln.transform = base_xform * layer.get_matrix(design_size, pixel_mode)

		var layer_index: int = design.layers.find(layer)
		if layer_index < 0:
			layer_index = 0
		ln.z_index = layer_index

# ============================================================
# DRAW
# ============================================================

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), bg_color, true)

	_draw_background_grid()

	if not design:
		return

	var center: Vector2 = size * 0.5 + pan_offset
	var base_xform := Transform2D(
		Vector2(preview_scale, 0),
		Vector2(0, preview_scale),
		center
	)

	_draw_design_center_marker(center)

	if show_nine_patch_guides:
		for layer in design.layers:
			if not layer or not layer.visible:
				continue
			if not (layer is BayterekTextureLayer):
				continue
			if not layer.uses_nine_patch():
				continue
			_draw_nine_patch_guides(layer, base_xform)

func _draw_design_center_marker(center: Vector2) -> void:
	var c := Color(0.5, 0.6, 0.8, 0.35)
	draw_line(center - Vector2(10, 0), center + Vector2(10, 0), c, 1.0)
	draw_line(center - Vector2(0, 10), center + Vector2(0, 10), c, 1.0)

# ============================================================
# BACKGROUND GRID
# ============================================================

func _draw_background_grid() -> void:
	var step: float = 16.0 * preview_scale
	if step < 4.0:
		step = 4.0

	var luminance: float = bg_color.get_luminance()
	var grid_color: Color
	var primary_color: Color

	if luminance > 0.6:
		grid_color = Color(0.10, 0.10, 0.15, 0.35)
		primary_color = Color(0.05, 0.05, 0.10, 0.55)
	elif luminance > 0.25:
		grid_color = Color(0.85, 0.90, 1.0, 0.28)
		primary_color = Color(0.95, 1.0, 1.0, 0.50)
	else:
		grid_color = Color(0.75, 0.80, 0.90, 0.18)
		primary_color = Color(0.90, 0.95, 1.0, 0.40)

	var origin: Vector2 = Vector2(fposmod(pan_offset.x, step), fposmod(pan_offset.y, step))

	var x: float = origin.x
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color, 1.0)
		x += step

	var y: float = origin.y
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1.0)
		y += step

	var primary_step: float = step * 4.0
	var px: float = fposmod(pan_offset.x, primary_step)
	while px < size.x:
		draw_line(Vector2(px, 0), Vector2(px, size.y), primary_color, 1.5)
		px += primary_step

	var py: float = fposmod(pan_offset.y, primary_step)
	while py < size.y:
		draw_line(Vector2(0, py), Vector2(size.x, py), primary_color, 1.5)
		py += primary_step

# ============================================================
# SIMULATED STATES
# ============================================================

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

# ============================================================
# NINE PATCH GUIDES
# ============================================================

func _draw_nine_patch_guides(layer: BayterekTextureLayer, base_xform: Transform2D) -> void:
	var tex: Texture2D = layer.get_icon_for_state("normal")
	if not tex:
		return

	var design_size: Vector2 = design.design_size
	var effective_size: Vector2 = layer.get_size(design_size)
	if effective_size.x <= 0.0 or effective_size.y <= 0.0:
		return

	var layer_matrix: Transform2D = layer.get_matrix(design_size, false)
	var combined: Transform2D = base_xform * layer_matrix

	var half: Vector2 = effective_size * 0.5
	var l: float = float(layer.nine_patch_margin_left)
	var t: float = float(layer.nine_patch_margin_top)
	var r: float = float(layer.nine_patch_margin_right)
	var b: float = float(layer.nine_patch_margin_bottom)

	var x0: float = -half.x
	var x1: float = -half.x + l
	var x2: float = half.x - r
	var x3: float = half.x

	var y0: float = -half.y
	var y1: float = -half.y + t
	var y2: float = half.y - b
	var y3: float = half.y

	var guide_color := Color(0.4, 0.9, 1.0, 0.7)
	var guide_width := 1.0

	for gx in [x1, x2]:
		var a: Vector2 = combined * Vector2(gx, y0)
		var bb: Vector2 = combined * Vector2(gx, y3)
		draw_dashed_line(a, bb, guide_color, guide_width, 4.0)

	for gy in [y1, y2]:
		var a: Vector2 = combined * Vector2(x0, gy)
		var bb: Vector2 = combined * Vector2(x3, gy)
		draw_dashed_line(a, bb, guide_color, guide_width, 4.0)