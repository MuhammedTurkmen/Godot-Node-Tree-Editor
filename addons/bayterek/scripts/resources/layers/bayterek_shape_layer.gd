@tool
class_name BayterekShapeLayer
extends BayterekLayer
## Shape layer — circle, square, triangle, pentagon, hexagon.
## Supports fill, border and shadow.
##
## BORDER GEOMETRY
## ----------------
##   outer_size        = effective_size              (outer bound, = button size)
##   border_width      = w
##   inner_size        = effective_size - 2w         (fill bound)
##   corner_radius     = outer polygon corner radius (auto-clamped)
##
## INNER CORNER RADIUS
## -------------------
## The inner polygon's corner radius is derived automatically as
## `max(0, corner_radius - border_width)`, so the border stays roughly
## constant-thickness in the rounded corners. It is NOT user-configurable.
##
## CORNER RADIUS CLAMP
## -------------------
## `corner_radius` is auto-clamped to:
##
##     min(effective_size.x, effective_size.y) / 2 * 0.99
##
## i.e. 99% of half the smaller dimension. This prevents the rounding
## from eating past the shape's centerline and collapsing the shape.
##
## CRITICAL — WINDING-AWARE ARC SWEEP
## ----------------------------------
## Arcs must sweep in the same direction as the polygon's winding, or the
## polygon becomes self-intersecting and draw_colored_polygon fails with
## "Invalid polygon data, triangulation failed".

enum ShapeType {
	CIRCLE,
	SQUARE,
	TRIANGLE,
	PENTAGON,
	HEXAGON,
}

@export_storage var shape_type: ShapeType = ShapeType.CIRCLE

## Corner rounding radius in pixels. 0 = sharp corners.
## Auto-clamped to `min(width, height) / 2 * 0.99`.
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

## Corner radius clamp factor — max radius = min(w, h) / 2 * CLAMP_FACTOR
const CORNER_RADIUS_CLAMP_FACTOR := 0.99

func _init() -> void:
	super._init()
	layer_name = "Shape"
	fill_configs = _make_default_fill_configs()
	border_configs = _make_default_border_configs()

static func _make_default_fill_configs() -> Dictionary:
	return {
		"normal":           {"enabled": false, "color": Color("7FB8FF")},
		"hover":            {"enabled": false, "color": Color("FFD966")},
		"locked":           {"enabled": false, "color": Color("666666")},
		"preallocated":     {"enabled": false, "color": Color("FFA640")},
		"prerefund":        {"enabled": false, "color": Color("FF8080")},
		"max_level":        {"enabled": false, "color": Color("FFE066")},
		"allocateable":     {"enabled": false, "color": Color("8EF58E")},
		"not_allocateable": {"enabled": false, "color": Color("FF6666")},
	}

static func _make_default_border_configs() -> Dictionary:
	return {
		"normal":           {"enabled": false, "color": Color("F2F2F2")},
		"hover":            {"enabled": false, "color": Color("FFBF00")},
		"locked":           {"enabled": false, "color": Color("444444")},
		"preallocated":     {"enabled": false, "color": Color("FF8000")},
		"prerefund":        {"enabled": false, "color": Color("FF4D4D")},
		"max_level":        {"enabled": false, "color": Color("FFCC00")},
		"allocateable":     {"enabled": false, "color": Color("4DDB4D")},
		"not_allocateable": {"enabled": false, "color": Color("FF3333")},
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
# INNER CORNER RADIUS (auto-derived, not user-editable)
# ============================================================

## Auto-derived inner corner radius:
##   inner_r = max(0, corner_radius - border_width)
## The inner polygon's arc radius shrinks by `border_width` to keep the
## border roughly constant-thickness in rounded corners.
func get_inner_corner_radius(effective_size: Vector2) -> float:
	var cr: float = get_clamped_corner_radius(effective_size)
	return maxf(0.0, cr - border_width)

# ============================================================
# CLAMPED CORNER RADIUS
# ============================================================

## Returns `corner_radius` clamped to:
##
##     min(effective_size.x, effective_size.y) / 2 * 0.99
##
## i.e. 99% of half the smaller dimension.
func get_clamped_corner_radius(effective_size: Vector2) -> float:
	if corner_radius <= 0.0:
		return 0.0
	var limit: float = _corner_radius_limit(effective_size)
	return minf(corner_radius, limit)

## Maximum radius allowed by the shape's geometry:
##   min(width, height) / 2 * 0.99
func _corner_radius_limit(effective_size: Vector2) -> float:
	var smaller_dim: float = minf(effective_size.x, effective_size.y)
	if smaller_dim <= 0.0:
		return 0.0
	return smaller_dim * 0.5 * CORNER_RADIUS_CLAMP_FACTOR

# ============================================================
# VERTEX COMPUTATION
# ============================================================

## Outer polygon at `effective_size`, rounded with the clamped corner radius.
func get_polygon_vertices(effective_size: Vector2) -> PackedVector2Array:
	return _build_polygon(effective_size, get_clamped_corner_radius(effective_size))

## Fill polygon: size shrunk by `2*border_width`, rounded with the
## auto-derived inner corner radius.
func get_fill_vertices(effective_size: Vector2) -> PackedVector2Array:
	if not border_enabled or border_width <= 0.0:
		return _build_polygon(effective_size, get_clamped_corner_radius(effective_size))

	var inner_size: Vector2 = effective_size - Vector2(border_width, border_width) * 2.0
	if inner_size.x <= 0.5 or inner_size.y <= 0.5:
		return PackedVector2Array()

	return _build_polygon(inner_size, get_inner_corner_radius(effective_size))

## Kept for API compatibility — returns the outer polygon.
func get_border_centerline_vertices(effective_size: Vector2) -> PackedVector2Array:
	return get_polygon_vertices(effective_size)

## Returns the outer polygon for shadow / outline use.
func get_border_vertices(effective_size: Vector2) -> PackedVector2Array:
	return get_polygon_vertices(effective_size)

# ============================================================
# INTERNAL POLYGON BUILDER
# ============================================================

func _build_polygon(size_vec: Vector2, radius: float) -> PackedVector2Array:
	var half: Vector2 = size_vec * 0.5
	if half.x <= 0.0 or half.y <= 0.0:
		return PackedVector2Array()

	var base_verts: PackedVector2Array

	match shape_type:
		ShapeType.CIRCLE:
			var r: float = minf(half.x, half.y)
			return _make_circle_vertices(r, 48)
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

	if radius > 0.0:
		return _apply_corner_rounding(base_verts, radius)
	return base_verts

func _make_circle_vertices(radius: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(segments)
	for i in segments:
		var angle: float = TAU * float(i) / float(segments)
		pts[i] = Vector2(cos(angle), sin(angle)) * radius
	return pts

func _make_regular_polygon(half: Vector2, sides: int, start_angle: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(sides)
	var radius: float = minf(half.x, half.y)
	for i in sides:
		var angle: float = start_angle + TAU * float(i) / float(sides)
		pts[i] = Vector2(cos(angle), sin(angle)) * radius
	return pts

## Rounds each corner of the polygon with an arc of the given radius.
##
## CRITICAL: The arc must sweep in the SAME direction as the polygon's
## winding, otherwise the arc folds back on itself and the resulting
## polygon is self-intersecting → draw_colored_polygon fails with
## "Invalid polygon data, triangulation failed".
func _apply_corner_rounding(verts: PackedVector2Array, radius: float) -> PackedVector2Array:
	if radius <= 0.01 or verts.size() < 3:
		return verts

	var result := PackedVector2Array()
	var n: int = verts.size()

	# --- Detect polygon winding via signed area ---
	var signed_area: float = 0.0
	for i in n:
		var a: Vector2 = verts[i]
		var b: Vector2 = verts[(i + 1) % n]
		signed_area += (a.x * b.y - b.x * a.y)
	var positive_winding: bool = signed_area > 0.0

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

		if angle < 0.001 or angle > PI - 0.001:
			result.append(curr_v)
			continue

		var half_angle: float = angle * 0.5
		var tan_half: float = tan(half_angle)
		var sin_half: float = sin(half_angle)
		if tan_half < 0.0001 or absf(sin_half) < 0.0001:
			result.append(curr_v)
			continue

		# Tangent distance from the corner along each edge.
		# NOTE: minf() only takes 2 arguments, so we nest the call.
		var d: float = radius / tan_half
		d = minf(d, minf(len_prev * 0.5, len_next * 0.5))

		var p_start: Vector2 = curr_v + dir_prev * d
		var p_end: Vector2 = curr_v + dir_next * d

		# Arc center along the inward bisector.
		var bisector: Vector2 = dir_prev + dir_next
		if bisector.length_squared() < 0.0001:
			result.append(curr_v)
			continue
		bisector = bisector.normalized()

		var r_eff: float = d * tan_half
		var arc_center: Vector2 = curr_v + bisector * (r_eff / sin_half)

		# --- Winding-aware arc sweep ---
		var a_start: float = (p_start - arc_center).angle()
		var a_end: float = (p_end - arc_center).angle()
		var delta: float = a_end - a_start

		if positive_winding:
			while delta <= 0.0:
				delta += TAU
			while delta > TAU:
				delta -= TAU
		else:
			while delta >= 0.0:
				delta -= TAU
			while delta < -TAU:
				delta += TAU

		var segments: int = clampi(int(ceil(radius * 0.75)), 4, 32)
		for s in range(segments + 1):
			var t: float = float(s) / float(segments)
			var ang: float = a_start + delta * t
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