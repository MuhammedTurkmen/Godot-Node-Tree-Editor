@tool
class_name BayterekShapeLayer
extends BayterekLayer
## Shape layer — circle, square, triangle, pentagon, hexagon.
## Supports fill, border and shadow. Border sits INSIDE the shape bounds.
## Corners can be rounded with `corner_radius`.
##
## BORDER GEOMETRY
## ----------------
##   effective_size          = size                       (outer bound)
##   border_width            = w
##   fill                    = size - 2w                  (inset by w on each side)
##   border centerline       = size - w                   (midway between outer & inner)
##
## The border is drawn as a polyline stroked with thickness = w, centered on
## the centerline polygon. draw_polyline expands w/2 outward and w/2 inward:
##   outer edge = (size - w) + w = size                   ✅ matches outer bound
##   inner edge = (size - w) - w = size - 2w              ✅ meets the fill
##
## ROUNDED CORNER CONSISTENCY
## --------------------------
## All three polygons (outer, centerline, fill) share the SAME arc centers
## and arc angles. Only the arc radius differs (r, r-w, r-2w). This keeps
## rounded corners concentric — otherwise the border would look warped.

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
	fill_configs = _make_default_fill_configs()
	border_configs = _make_default_border_configs()

## Default fill colors for every state. All disabled by default — the
## user enables the ones they want. Colors are pre-populated so enabling
## a state gives an immediate, meaningful result.
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

## Default border colors — same palette, tuned for edge contrast.
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
# VERTEX COMPUTATION
# ============================================================

## Base polygon at the given size, centered at (0, 0).
##
## `inset` (>= 0): how far the polygon is pushed inward from `effective_size`.
##   inset = 0   → outer polygon
##   inset = w   → border centerline polygon
##   inset = 2w  → fill polygon
##
## When `inset > 0`, the polygon is sized `effective_size - 2*inset` and its
## arc centers/angles are derived from the OUTER polygon's corner geometry,
## so all concentric polygons share the same corner arc centers. This keeps
## rounded borders visually uniform.
func get_polygon_vertices(effective_size: Vector2, inset: float = 0.0) -> PackedVector2Array:
	var half: Vector2 = (effective_size * 0.5) - Vector2(inset, inset)
	if half.x <= 0.0 or half.y <= 0.0:
		return PackedVector2Array()

	var base_verts: PackedVector2Array

	match shape_type:
		ShapeType.CIRCLE:
			var radius: float = min(half.x, half.y)
			return _make_circle_vertices(radius, 32)
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

	# Rounded corners: outer radius reduced by `inset` so the arc stays
	# concentric with the outer arc. But the arc CENTER must be computed
	# from the outer polygon's geometry, not from this (smaller) polygon.
	if corner_radius > 0.0:
		var outer_half: Vector2 = effective_size * 0.5
		var outer_verts: PackedVector2Array = _make_base_polygon(outer_half)
		var r_outer: float = corner_radius
		var r_this: float = max(0.0, corner_radius - inset)
		if r_this <= 0.01:
			return base_verts
		return _apply_shared_corner_rounding(outer_verts, base_verts, r_outer, r_this)

	return base_verts

## Builds the raw (un-rounded) polygon for the OUTER size, used to derive
## the shared corner arc geometry.
func _make_base_polygon(outer_half: Vector2) -> PackedVector2Array:
	match shape_type:
		ShapeType.SQUARE:
			return PackedVector2Array([
				Vector2(-outer_half.x, -outer_half.y),
				Vector2( outer_half.x, -outer_half.y),
				Vector2( outer_half.x,  outer_half.y),
				Vector2(-outer_half.x,  outer_half.y),
			])
		ShapeType.TRIANGLE:
			return _make_regular_polygon(outer_half, 3, -PI * 0.5)
		ShapeType.PENTAGON:
			return _make_regular_polygon(outer_half, 5, -PI * 0.5)
		ShapeType.HEXAGON:
			return _make_regular_polygon(outer_half, 6, -PI * 0.5)
		_:
			return PackedVector2Array()

## Vertices for the FILL. When a border is active, the fill is inset by
## `2 * border_width` total (i.e. `border_width` on each side) and its corner
## radius is reduced accordingly, so:
##   outer edge of border  = effective_size
##   inner edge of border  = effective_size - 2*border_width
##   fill boundary         = inner edge (they meet exactly)
func get_fill_vertices(effective_size: Vector2) -> PackedVector2Array:
	if not border_enabled or border_width <= 0.0:
		return get_polygon_vertices(effective_size, 0.0)
	return get_polygon_vertices(effective_size, border_width)

## Vertices for the BORDER's CENTERLINE.
##   centerline = (outer + inner) / 2 = (size + size - 2w)/2 = size - w
func get_border_centerline_vertices(effective_size: Vector2) -> PackedVector2Array:
	if border_width <= 0.0:
		return get_polygon_vertices(effective_size, 0.0)
	return get_polygon_vertices(effective_size, border_width * 0.5)

## Vertices used for the BORDER's outer edge — the full shape outline.
func get_border_vertices(effective_size: Vector2) -> PackedVector2Array:
	return get_polygon_vertices(effective_size, 0.0)

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
	var radius: float = min(half.x, half.y)
	for i in sides:
		var angle: float = start_angle + TAU * float(i) / float(sides)
		pts[i] = Vector2(cos(angle), sin(angle)) * radius
	return pts

## Applies rounded corners to `inner_verts` using arc geometry derived from
## `outer_verts` and the OUTER corner radius. This guarantees that the arc
## center and arc angles are identical for the outer and inner polygons —
## only the arc radius shrinks by the inset amount.
##
## Each vertex in `inner_verts` is assumed to correspond to the same corner
## as the same-index vertex in `outer_verts`.
func _apply_shared_corner_rounding(
	outer_verts: PackedVector2Array,
	inner_verts: PackedVector2Array,
	r_outer: float,
	r_inner: float
) -> PackedVector2Array:
	if r_inner <= 0.01 or inner_verts.size() < 3:
		return inner_verts
	if outer_verts.size() != inner_verts.size():
		# Shape mismatch — fall back to per-polygon rounding.
		return _apply_corner_rounding(inner_verts, r_inner)

	var result := PackedVector2Array()
	var n: int = outer_verts.size()

	for i in n:
		var o_prev: Vector2 = outer_verts[(i - 1 + n) % n]
		var o_curr: Vector2 = outer_verts[i]
		var o_next: Vector2 = outer_verts[(i + 1) % n]

		var to_prev: Vector2 = o_prev - o_curr
		var to_next: Vector2 = o_next - o_curr
		var len_prev: float = to_prev.length()
		var len_next: float = to_next.length()
		if len_prev < 0.0001 or len_next < 0.0001:
			result.append(inner_verts[i])
			continue

		var dir_prev: Vector2 = to_prev / len_prev
		var dir_next: Vector2 = to_next / len_next

		var cos_angle: float = clampf(dir_prev.dot(dir_next), -1.0, 1.0)
		var angle: float = acos(cos_angle)

		if angle < 0.01 or angle > PI - 0.01:
			result.append(inner_verts[i])
			continue

		var half_angle: float = angle * 0.5
		var tan_half: float = tan(half_angle)
		if tan_half < 0.0001:
			result.append(inner_verts[i])
			continue

		var sin_half: float = sin(half_angle)
		if absf(sin_half) < 0.0001:
			result.append(inner_verts[i])
			continue

		# Outer corner geometry — limits and center.
		var d_outer: float = r_outer / tan_half
		d_outer = min(d_outer, len_prev * 0.5, len_next * 0.5)
		var r_outer_eff: float = d_outer * tan_half

		var bisector: Vector2 = dir_prev + dir_next
		if bisector.length_squared() < 0.0001:
			result.append(inner_verts[i])
			continue
		bisector = bisector.normalized()

		# Arc center measured from the OUTER corner vertex.
		var arc_center: Vector2 = o_curr + bisector * (r_outer_eff / sin_half)

		# Inner radius is reduced by the inset.
		var r_this: float = max(0.0, r_outer_eff - (r_outer - r_inner))
		if r_this <= 0.01:
			result.append(inner_verts[i])
			continue

		# Tangent points on the INNER polygon: offset from inner corner
		# along the same edge directions used for the outer polygon.
		var d_inner: float = r_this / tan_half
		var i_curr: Vector2 = inner_verts[i]
		var i_prev: Vector2 = inner_verts[(i - 1 + n) % n]
		var i_next: Vector2 = inner_verts[(i + 1) % n]

		var i_to_prev: Vector2 = i_prev - i_curr
		var i_to_next: Vector2 = i_next - i_curr
		var i_len_prev: float = i_to_prev.length()
		var i_len_next: float = i_to_next.length()
		if i_len_prev < 0.0001 or i_len_next < 0.0001:
			result.append(inner_verts[i])
			continue

		var i_dir_prev: Vector2 = i_to_prev / i_len_prev
		var i_dir_next: Vector2 = i_to_next / i_len_next

		d_inner = min(d_inner, i_len_prev * 0.5, i_len_next * 0.5)
		r_this = d_inner * tan_half

		var p_start: Vector2 = i_curr + i_dir_prev * d_inner
		var p_end: Vector2 = i_curr + i_dir_next * d_inner

		var ang_start: float = (p_start - arc_center).angle()
		var ang_end: float = (p_end - arc_center).angle()

		var delta: float = ang_end - ang_start
		while delta > PI:
			delta -= TAU
		while delta < -PI:
			delta += TAU

		var segments: int = clampi(int(ceil(r_this * 0.75)), 4, 24)
		for s in range(segments + 1):
			if s == 0:
				result.append(p_start)
				continue
			if s == segments:
				result.append(p_end)
				continue
			var t: float = float(s) / float(segments)
			var ang: float = ang_start + delta * t
			result.append(arc_center + Vector2(cos(ang), sin(ang)) * r_this)

	return result

## Legacy per-polygon rounding (fallback only).
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