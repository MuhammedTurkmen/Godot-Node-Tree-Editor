@tool
class_name BayterekCamera
extends RefCounted
## Pan + zoom camera.
##
## CONTROLS:
##   - Right mouse button + drag → pan
##   - Right mouse button (no drag) → context menu (handled by the tree view)
##   - Mouse wheel → zoom
##
## NOTE: Middle-mouse pan is intentionally NOT supported anymore.
## Only right-drag pans the camera.

signal zoom_changed(zoom: float, previous_zoom: float)

## Right-click drag threshold: if the user releases without moving more
## than this many pixels, it's treated as a click (context menu) instead
## of a pan.
const RIGHT_CLICK_DRAG_THRESHOLD := 4.0

const MIN_ZOOM := 0.4
const MAX_ZOOM := 3.0
const ZOOM_STEP := 0.1

var _viewport: Control
var _bounds: Rect2
var _zoom: float = 1.0

var _dragging: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

# --- Right-click pan state ---
var _right_button_down: bool = false
var _right_drag_start: Vector2 = Vector2.ZERO
var _right_drag_accumulated: float = 0.0

func set_viewport(viewport: Control) -> void:
	_viewport = viewport
	if not _viewport:
		return

	_viewport.offset_transform_enabled = true
	_viewport.offset_transform_visual_only = false
	_viewport.offset_transform_pivot_ratio = Vector2(0.5, 0.5)

	_zoom = 1.0
	_viewport.offset_transform_position = Vector2.ZERO
	_viewport.offset_transform_scale = Vector2.ONE

	var parent: Node = _viewport.get_parent()
	if parent and parent is Control:
		(parent as Control).resized.connect(_on_viewport_resized)

func set_bounds(bounds: Rect2) -> void:
	_bounds = bounds

	if _viewport:
		_viewport.offset_transform_position = Vector2.ZERO

	_clamp()

func get_zoom() -> float:
	return _zoom

# ============================================================
# INPUT
# ============================================================

func input(event: InputEvent) -> void:
	if not _viewport:
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				set_zoom(_zoom + ZOOM_STEP)

		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				set_zoom(_zoom - ZOOM_STEP)

		MOUSE_BUTTON_RIGHT:
			if event.pressed:
				# Start tracking a potential right-drag.
				_right_button_down = true
				_right_drag_start = event.position
				_right_drag_accumulated = 0.0
			else:
				# Release: end drag if it was a drag.
				if _dragging:
					_dragging = false
				_right_button_down = false
				_right_drag_accumulated = 0.0

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	# --- Right-button drag ---
	if _right_button_down:
		# First, check if the accumulated movement exceeds the threshold.
		# If so, we transition from "click pending" to "dragging".
		if not _dragging:
			var moved: float = event.position.distance_to(_right_drag_start)
			_right_drag_accumulated = moved
			if moved > RIGHT_CLICK_DRAG_THRESHOLD:
				_dragging = true
				_last_mouse_pos = event.position
			return

		# Already dragging — apply pan delta.
		var delta: Vector2 = event.position - _last_mouse_pos
		_last_mouse_pos = event.position
		_pan(delta)

# ============================================================
# PUBLIC QUERY
# ============================================================

## Returns true if a right-drag is currently active (i.e. the user
## pressed the right mouse button and moved past the threshold).
func is_right_drag_active() -> bool:
	return _right_button_down and _dragging

## Returns true if a right-click gesture just happened (pressed and
## released without exceeding the drag threshold).
func was_right_click_only() -> bool:
	return _right_button_down and not _dragging

## Returns true if the right mouse button is currently held down
## (regardless of whether it's been dragging).
func is_right_button_down() -> bool:
	return _right_button_down

# ============================================================
# ZOOM / PAN
# ============================================================

func set_zoom(new_zoom: float) -> void:
	if not _viewport:
		return

	var clamped: float = clampf(new_zoom, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(clamped, _zoom):
		return

	var previous: float = _zoom
	_zoom = clamped
	_viewport.offset_transform_scale = Vector2(_zoom, _zoom)

	var factor: float = _zoom / previous
	_viewport.offset_transform_position *= factor

	_clamp()
	zoom_changed.emit(_zoom, previous)

func _pan(delta: Vector2) -> void:
	_viewport.offset_transform_position += delta
	_clamp()

# ============================================================
# FOCUS
# ============================================================

## Centers the camera on a tree-space point and sets zoom.
func focus_on(target_center: Vector2, target_zoom: float = 1.0) -> void:
	if not _viewport:
		return

	var clamped_zoom: float = clampf(target_zoom, MIN_ZOOM, MAX_ZOOM)
	var previous: float = _zoom
	_zoom = clamped_zoom
	_viewport.offset_transform_scale = Vector2(_zoom, _zoom)

	var tree_size: Vector2 = _viewport.size
	var pivot: Vector2 = tree_size / 2.0
	var target_local: Vector2 = target_center + tree_size / 2.0
	var delta: Vector2 = target_local - pivot

	_viewport.offset_transform_position = -delta * _zoom

	zoom_changed.emit(_zoom, previous)

# ============================================================
# CLAMP
# ============================================================

func _clamp() -> void:
	if not _viewport or _bounds.size == Vector2.ZERO:
		return

	var parent: Control = _viewport.get_parent() as Control
	if not parent:
		return

	var view_size: Vector2 = parent.size
	var cam_pos: Vector2 = _viewport.offset_transform_position

	var bounds_min: Vector2 = _bounds.position * _zoom
	var bounds_max: Vector2 = (_bounds.position + _bounds.size) * _zoom

	var min_pos: Vector2 = bounds_min + view_size * 0.5
	var max_pos: Vector2 = bounds_max - view_size * 0.5

	if min_pos.x > max_pos.x:
		cam_pos.x = (bounds_min.x + bounds_max.x) * 0.5
	else:
		cam_pos.x = clampf(cam_pos.x, min_pos.x, max_pos.x)

	if min_pos.y > max_pos.y:
		cam_pos.y = (bounds_min.y + bounds_max.y) * 0.5
	else:
		cam_pos.y = clampf(cam_pos.y, min_pos.y, max_pos.y)

	_viewport.offset_transform_position = cam_pos

func _on_viewport_resized() -> void:
	_clamp()