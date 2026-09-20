@tool
class_name BayterekShapeLayer
extends BayterekLayer
## Shape layer — circle, square, triangle, pentagon, hexagon.
## Supports fill, border and shadow. Border sits INSIDE the shape bounds.
## Corners can be rounded with `corner_radius`.

enum ShapeType {
	CIRCLE,
	SQUARE,
	TRIANGLE,
	PENTAGON,
	HEXAGON,
}

@export_storage var shape_type: ShapeType = ShapeType.CIRCLE

## Corner rounding radius in pixels. 0 = sharp corners.
## Applies to SQUARE, TRIANGLE, PENTAGON, HEXAGON. Ignored for CIRCLE.
@export_storage var corner_radius: float = 0.0

# --- Fill ---
@export_storage var fill_enabled: bool = true
## state -> {"enabled": bool, "color": Color}
@export_storage var fill_configs: Dictionary = {}

# --- Border ---
@export_storage var border_enabled: bool = false
@export_storage var border_width: float = 2.0
## state -> {"enabled": bool, "color": Color}
@export_storage var border_configs: Dictionary = {}

# --- Shadow ---
@export_storage var shadow_enabled: bool = false
@export_storage var shadow_color: Color = Color(0, 0, 0, 0.5)
@export_storage var shadow_size: Vector2 = Vector2(4, 4)
@export_storage var shadow_blur: float = 0.0

func _init() -> void:
	super._init()
	layer_name = "Shape"
	fill_configs = {
		"normal": {"enabled": true, "color": Color(0.4, 0.7, 1.0, 1.0)},
	}
	border_configs = {
		"normal": {"enabled": true, "color": Color(1.0, 1.0, 1.0, 1.0)},
	}

# ============================================================
# STATE CHECKBOX
# ============================================================

func _is_state_checkbox_on(state: String) -> bool:
	if fill_enabled and _is_config_enabled(fill_configs, state):
		return true
	if border_enabled and _is_config_enabled(border_configs, state):
		return true
	return false

func _is_config_enabled(configs: Dictionary, state: String) -> bool:
	if not configs.has(state):
		return false
	var entry = configs[state]
	if not entry is Dictionary:
		return false
	return entry.get("enabled", false)

# ============================================================
# COLOR RESOLUTION
# ============================================================

func get_fill_color_for_state(state_key: String) -> Color:
	if not fill_enabled:
		return Color.WHITE
	if _is_config_enabled(fill_configs, state_key):
		return fill_configs[state_key].get("color", Color.WHITE)
	if _is_config_enabled(fill_configs, "normal"):
		return fill_configs["normal"].get("color", Color.WHITE)
	return Color.WHITE

func get_border_color_for_state(state_key: String) -> Color:
	if not border_enabled:
		return Color.WHITE
	if _is_config_enabled(border_configs, state_key):
		return border_configs[state_key].get("color", Color.WHITE)
	if _is_config_enabled(border_configs, "normal"):
		return border_configs["normal"].get("color", Color.WHITE)
	return Color.WHITE

func should_draw_fill(state_key: String) -> bool:
	if not fill_enabled:
		return false
	if _is_config_enabled(fill_configs, state_key):
		return true
	return _is_config_enabled(fill_configs, "normal")

func should_draw_border(state_key: String) -> bool:
	if not border_enabled:
		return false
	if _is_config_enabled(border_configs, state_key):
		return true
	return _is_config_enabled(border_configs, "normal")

# ============================================================
# CONFIG SETTERS
# ============================================================

func set_fill_config(state: String, enabled: bool, color: Color) -> void:
	fill_configs[state] = {"enabled": enabled, "color": color}

func set_border_config(state: String, enabled: bool, color: Color) -> void:
	border_configs[state] = {"enabled": enabled, "color": color}

func ensure_fill_config(state: String) -> void:
	if not fill_configs.has(state):
		fill_configs[state] = {"enabled": false, "color": Color.WHITE}

func ensure_border_config(state: String) -> void:
	if not border_configs.has(state):
		border_configs[state] = {"enabled": false, "color": Color.WHITE}

# ============================================================
# VERTEX COMPUTATION
# ============================================================

## Base polygon at the given size, centered at (0, 0).
##
## `radius_override`: when >= 0, overrides `corner_radius` for this call
## (used internally to compute the inset fill with a smaller radius so
## the fill's corners are concentric with the border's inner edge).
func get_polygon_vertices(effective_size: Vector2, radius_override: float = -1.0) -> PackedVector2Array:
	var half: Vector2 = effective_size * 0.5
	var base_verts: PackedVector2Array

	match shape_type:
		ShapeType.CIRCLE:
			# Circle is already round — skip rounding.
			return _make_circle_vertices(half, 32)
		ShapeType.SQUARE:
			base_verts = PackedVector2Array([
				Vector2(-half.x, -half.y),
				Vector2( half.x, -half.y),
				Vector2( half.x,  half.y),
				Vector2(-half.x,  half.y),
			])
		ShapeType.TRIANGLE:
			base_verts = _make_regular_polygon(half, 3, -PI * 0.5)
		ShapeType.PENTAGON:
			base_verts = _make_regular_polygon(half, 5, -PI * 0.5)
		ShapeType.HEXAGON:
			base_verts = _make_regular_polygon(half, 6, -PI * 0.5)
		_:
			return PackedVector2Array()

	var r: float = corner_radius if radius_override < 0.0 else radius_override
	if r > 0.0:
		return _apply_corner_rounding(base_verts, r)
	return base_verts

## Vertices used for the FILL. When a border is active, the fill is inset
## by `border_width` and its corner radius is reduced by the same amount,
## so the inner arc stays concentric with the outer border arc.
func get_fill_vertices(effective_size: Vector2) -> PackedVector2Array:
	if not border_enabled or border_width <= 0.0:
		return get_polygon_vertices(effective_size)

	var inset_size: Vector2 = effective_size - Vector2(border_width, border_width) * 2.0
	if inset_size.x <= 0.5 or inset_size.y <= 0.5:
		return PackedVector2Array()

	var inner_radius: float = max(0.0, corner_radius - border_width)
	return get_polygon_vertices(inset_size, inner_radius)

## Vertices used for the BORDER's outer edge — the full shape outline.
func get_border_vertices(effective_size: Vector2) -> PackedVector2Array:
	return get_polygon_vertices(effective_size)

## DEBUG ONLY: returns the un-rounded polygon for comparison.
func _make_raw_polygon(effective_size: Vector2) -> PackedVector2Array:
	var half: Vector2 = effective_size * 0.5
	match shape_type:
		ShapeType.SQUARE:
			return PackedVector2Array([
				Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
				Vector2(half.x, half.y), Vector2(-half.x, half.y),
			])
		ShapeType.TRIANGLE: return _make_regular_polygon(half, 3, -PI * 0.5)
		ShapeType.PENTAGON: return _make_regular_polygon(half, 5, -PI * 0.5)
		ShapeType.HEXAGON: return _make_regular_polygon(half, 6, -PI * 0.5)
		_: return PackedVector2Array()

func _make_circle_vertices(half: Vector2, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(segments)
	var radius: float = min(half.x, half.y)
	for i in segments:
		var angle: float = TAU * float(i) / float(segments)
		pts[i] = Vector2(cos(angle), sin(angle)) * radius
	return pts

func _make_regular_polygon(half: Vector2, sides: int, start_angle: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(sides)
	var radius: float = min(half.x, half.y)
	for i in sides:
		var angle: float = start_angle + TAU * float(i) / float(sides)
		pts[i] = Vector2(cos(angle), sin(angle)) * radius
	return pts

## Replaces each corner of a convex polygon with a smooth arc of `radius`.
## Works for any convex polygon with at least 3 vertices.
## Segment count is adaptive (grows with radius) and endpoints are locked
## to the exact edge points so the arc doesn't bulge beyond the edges.
func _apply_corner_rounding(verts: PackedVector2Array, radius: float) -> PackedVector2Array:
	if radius <= 0.01 or verts.size() < 3:
		return verts

	var result := PackedVector2Array()
	var n: int = verts.size()

	for i in n:
		var prev_v: Vector2 = verts[(i - 1 + n) % n]
		var curr_v: Vector2 = verts[i]
		var next_v: Vector2 = verts[(i + 1) % n]

		var to_prev: Vector2 = prev_v - curr_v
		var to_next: Vector2 = next_v - curr_v
		var len_prev: float = to_prev.length()
		var len_next: float = to_next.length()
		if len_prev < 0.0001 or len_next < 0.0001:
			result.append(curr_v)
			continue

		var dir_prev: Vector2 = to_prev / len_prev
		var dir_next: Vector2 = to_next / len_next

		var cos_angle: float = clampf(dir_prev.dot(dir_next), -1.0, 1.0)
		var angle: float = acos(cos_angle)

		if angle < 0.01 or angle > PI - 0.01:
			result.append(curr_v)
			continue

		var half_angle: float = angle * 0.5
		var tan_half: float = tan(half_angle)
		if tan_half < 0.0001:
			result.append(curr_v)
			continue

		var d: float = radius / tan_half
		d = min(d, len_prev * 0.5, len_next * 0.5)

		var p_start: Vector2 = curr_v + dir_prev * d
		var p_end: Vector2 = curr_v + dir_next * d

		var bisector: Vector2 = dir_prev + dir_next
		if bisector.length_squared() < 0.0001:
			result.append(curr_v)
			continue
		bisector = bisector.normalized()

		var r_eff: float = d * tan_half
		var sin_half: float = sin(half_angle)
		if absf(sin_half) < 0.0001:
			result.append(curr_v)
			continue

		var arc_center: Vector2 = curr_v + bisector * (r_eff / sin_half)

		var ang_start: float = (p_start - arc_center).angle()
		var ang_end: float = (p_end - arc_center).angle()

		var delta: float = ang_end - ang_start
		while delta > PI:
			delta -= TAU
		while delta < -PI:
			delta += TAU

		var segments: int = clampi(int(ceil(radius * 0.75)), 4, 24)
		for s in range(segments + 1):
			if s == 0:
				result.append(p_start)
				continue
			if s == segments:
				result.append(p_end)
				continue
			var t: float = float(s) / float(segments)
			var ang: float = ang_start + delta * t
			result.append(arc_center + Vector2(cos(ang), sin(ang)) * r_eff)

	return result

# ============================================================
# DUPLICATE
# ============================================================

func duplicate_layer() -> BayterekLayer:
	var copy := BayterekShapeLayer.new()
	_copy_base_to(copy)
	copy.shape_type = shape_type
	copy.corner_radius = corner_radius
	copy.fill_enabled = fill_enabled
	copy.fill_configs = fill_configs.duplicate(true)
	copy.border_enabled = border_enabled
	copy.border_width = border_width
	copy.border_configs = border_configs.duplicate(true)
	copy.shadow_enabled = shadow_enabled
	copy.shadow_color = shadow_color
	copy.shadow_size = shadow_size
	copy.shadow_blur = shadow_blur
	return copy

func _to_string() -> String:
	return "BayterekShapeLayer(name='%s', type=%s)" % [layer_name, ShapeType.keys()[shape_type]]