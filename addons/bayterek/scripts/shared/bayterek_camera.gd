@tool
class_name BayterekCamera
extends RefCounted
## Pan + zoom kamerası.

signal zoom_changed(zoom: float, previous_zoom: float)

const MIN_ZOOM := 0.4
const MAX_ZOOM := 3.0
const ZOOM_STEP := 0.1

var _viewport: Control
var _bounds: Rect2
var _zoom: float = 1.0

var _dragging: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

func set_viewport(viewport: Control) -> void:
	_viewport = viewport
	if not _viewport:
		return
	_viewport.offset_transform_enabled = true
	_viewport.offset_transform_visual_only = false
	_viewport.offset_transform_pivot_ratio = Vector2(0.5, 0.5)

	var parent: Node = _viewport.get_parent()
	if parent and parent is Control:
		(parent as Control).resized.connect(_on_viewport_resized)

func set_bounds(bounds: Rect2) -> void:
	_bounds = bounds
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
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			set_zoom(_zoom + ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			set_zoom(_zoom - ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
			if _dragging:
				_last_mouse_pos = event.position
	elif event is InputEventMouseMotion and _dragging:
		var delta: Vector2 = event.position - _last_mouse_pos
		_last_mouse_pos = event.position
		_pan(delta)

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
# ODAKLANMA
# ============================================================

## Belirli bir tree noktasına kamerayı ortalar ve zoom yapar.
## target_center: tree koordinatında (0,0 merkez) hedef
## target_zoom: hedef zoom (0.4 - 1.0)
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

	# Doğrudan set et, clamp uygulama
	_viewport.offset_transform_position = -delta * _zoom

	# Bound'u gevşet: odaklanmada kullanıcı node'u görmek ister
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