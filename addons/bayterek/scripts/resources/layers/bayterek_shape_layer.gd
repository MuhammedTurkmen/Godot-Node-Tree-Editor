@tool
class_name BayterekShapeLayer
extends BayterekLayer
## Shape layer — circle, square, triangle, pentagon, hexagon.
## Supports fill, border (per-edge vector lines) and shadow.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

enum ShapeType {
	CIRCLE,
	SQUARE,
	TRIANGLE,
	PENTAGON,
	HEXAGON,
}

## Edge indices — used by `is_edge_enabled()`.
const EDGE_TOP := 0
const EDGE_RIGHT := 1
const EDGE_BOTTOM := 2
const EDGE_LEFT := 3

@export_storage var shape_type: ShapeType = ShapeType.CIRCLE

## Corner rounding radius in pixels. 0 = sharp corners.
@export_storage var corner_radius: float = 0.0

# --- Fill ---
@export_storage var fill_enabled: bool = true
## state -> {"enabled": bool, "color": Color}
@export_storage var fill_configs: Dictionary = {}

# --- Border ---
@export_storage var border_enabled: bool = false
@export_storage var border_width: float = 2.0

## When true, each straight edge is trimmed by `border_width / 2` at both
## ends so the corners stay empty (each corner shows a border_width ×
## border_width square gap). Useful for pixel art style frames.
@export_storage var border_corner_gap: bool = false

## Which edges are drawn. Ignored for CIRCLE (always draws a full ring).
@export_storage var border_top_enabled: bool = true
@export_storage var border_right_enabled: bool = true
@export_storage var border_bottom_enabled: bool = true
@export_storage var border_left_enabled: bool = true

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

static func _make_default_fill_configs() -> Dictionary:
	return {
		"normal":           {"enabled": false, "color": Color("7FB8FF")},
		"hover":            {"enabled": false, "color": Color("FFD966")},
		"clicked":          {"enabled": false, "color": Color("B38A00")},
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
		"clicked":          {"enabled": false, "color": Color("A87A00")},
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
# EDGE MASKS
# ============================================================

func is_edge_enabled(edge: int) -> bool:
	if shape_type == ShapeType.CIRCLE:
		return true
	match edge:
		EDGE_TOP:    return border_top_enabled
		EDGE_RIGHT:  return border_right_enabled
		EDGE_BOTTOM: return border_bottom_enabled
		EDGE_LEFT:   return border_left_enabled
	return false

func enabled_edge_count() -> int:
	var c: int = 0
	if border_top_enabled: c += 1
	if border_right_enabled: c += 1
	if border_bottom_enabled: c += 1
	if border_left_enabled: c += 1
	return c

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
# CLAMPED CORNER RADIUS
# ============================================================

func get_clamped_corner_radius(effective_size: Vector2) -> float:
	if corner_radius <= 0.0:
		return 0.0
	var limit: float = _corner_radius_limit(effective_size)
	return minf(corner_radius, limit)

func _corner_radius_limit(effective_size: Vector2) -> float:
	var smaller_dim: float = minf(effective_size.x, effective_size.y)
	if smaller_dim <= 0.0:
		return 0.0
	return smaller_dim * 0.5 * Bayterek.CORNER_RADIUS_CLAMP_FACTOR

# ============================================================
# VERTEX COMPUTATION
# ============================================================

func get_polygon_vertices(effective_size: Vector2) -> PackedVector2Array:
	return _build_polygon(effective_size, get_clamped_corner_radius(effective_size))

func get_fill_vertices(effective_size: Vector2) -> PackedVector2Array:
	if not border_enabled or border_width <= 0.0:
		return _build_polygon(effective_size, get_clamped_corner_radius(effective_size))

	# Fill, border'ın iç kenarından bir miktar içeride kalır.
	var inset: float = border_width
	var inner_size: Vector2 = effective_size - Vector2(inset, inset) * 2.0
	if inner_size.x <= 0.5 or inner_size.y <= 0.5:
		return PackedVector2Array()

	var cr: float = get_clamped_corner_radius(effective_size)
	var inner_radius: float = maxf(0.0, cr - inset)

	return _build_polygon(inner_size, inner_radius)

func get_border_centerline_vertices(effective_size: Vector2) -> PackedVector2Array:
	if border_width <= 0.0:
		return _build_polygon(effective_size, get_clamped_corner_radius(effective_size))

	var inset: float = border_width * 0.5
	var center_size: Vector2 = effective_size - Vector2(inset, inset) * 2.0
	if center_size.x <= 0.5 or center_size.y <= 0.5:
		return PackedVector2Array()

	var cr: float = get_clamped_corner_radius(effective_size)
	var center_radius: float = maxf(0.0, cr - inset)

	return _build_polygon(center_size, center_radius)

func get_border_vertices(effective_size: Vector2) -> PackedVector2Array:
	return get_polygon_vertices(effective_size)

# ============================================================
# BORDER SEGMENT COMPUTATION
# ============================================================

## Returns an Array of PackedVector2Array polylines to draw as border.
##
## Rules:
##   CIRCLE  → single closed ring (edge masks & corner gap ignored).
##   Others, corner_gap = false (normal mode):
##     4 edges on  → single closed ring (guarantees closed corners).
##     1-3 edges   → one polyline per enabled edge.
##   Others, corner_gap = true (pixel-art frame):
##     Each enabled edge is a straight 2-point line, trimmed by
##     `border_width / 2` at each end. Corners show a border_width ×
##     border_width square gap.
func get_border_segments(effective_size: Vector2) -> Array:
	var center_verts: PackedVector2Array = get_border_centerline_vertices(effective_size)
	if center_verts.size() < 2:
		return []

	# Circle: always a full closed ring.
	if shape_type == ShapeType.CIRCLE:
		return [_make_closed_ring(center_verts)]

	# Normal mode + all 4 edges on → single closed ring.
	if not border_corner_gap and enabled_edge_count() >= 4:
		return [_make_closed_ring(center_verts)]

	var half: Vector2 = effective_size * 0.5
	var tol: float = maxf(border_width * 0.5 + 0.5, 1.0) + get_clamped_corner_radius(effective_size)

	var result: Array = []

	if border_corner_gap:
		# --- Corner gap mode: each edge is a straight 2-point line. ---
		# Her uçtan border_width / 2 kırpılır → köşede toplam border_width
		# kadar (yani border_width × border_width kare) boşluk kalır.
		var gap: float = maxf(border_width, 1.0) * 0.5
		var endpoints: Dictionary = _find_edge_endpoints(center_verts, half, tol)

		for edge in [EDGE_TOP, EDGE_RIGHT, EDGE_BOTTOM, EDGE_LEFT]:
			if not is_edge_enabled(edge):
				continue
			if not endpoints.has(edge):
				continue

			var ep: Dictionary = endpoints[edge]
			var a: Vector2 = ep["start"]
			var b: Vector2 = ep["end"]
			var seg_len: float = a.distance_to(b)
			if seg_len <= gap * 2.0:
				continue

			var dir: Vector2 = (b - a) / seg_len
			var a_trim: Vector2 = a + dir * gap
			var b_trim: Vector2 = b - dir * gap

			result.append(PackedVector2Array([a_trim, b_trim]))
	else:
		# --- Normal mode with 1-3 edges: per-edge polylines. ---
		for edge in [EDGE_TOP, EDGE_RIGHT, EDGE_BOTTOM, EDGE_LEFT]:
			if not is_edge_enabled(edge):
				continue
			var pts: PackedVector2Array = _collect_edge_vertices(center_verts, half, tol, edge)
			if pts.size() >= 2:
				result.append(pts)

	return result

func _make_closed_ring(center_verts: PackedVector2Array) -> PackedVector2Array:
	var ring := PackedVector2Array()
	ring.resize(center_verts.size() + 1)
	for i in center_verts.size():
		ring[i] = center_verts[i]
	ring[center_verts.size()] = center_verts[0]
	return ring

func _collect_edge_vertices(
	center_verts: PackedVector2Array,
	half: Vector2,
	tol: float,
	edge: int
) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in center_verts:
		if _vertex_on_edge(v, half, tol, edge):
			out.append(v)
	return out

func _vertex_on_edge(p: Vector2, half: Vector2, tol: float, edge: int) -> bool:
	match edge:
		EDGE_TOP:    return absf(p.y - (-half.y)) <= tol
		EDGE_BOTTOM: return absf(p.y - half.y) <= tol
		EDGE_LEFT:   return absf(p.x - (-half.x)) <= tol
		EDGE_RIGHT:  return absf(p.x - half.x) <= tol
	return false

## Finds, for each edge, the pair of vertices on that edge that are
## farthest apart. These act as the edge's endpoints when corner gap is on.
## For sharp-cornered polygons this is exactly the two corner vertices.
## For rounded corners this ignores the arc and gives the arc's two ends.
func _find_edge_endpoints(
	center_verts: PackedVector2Array,
	half: Vector2,
	tol: float
) -> Dictionary:
	var edge_verts: Dictionary = {}
	for v in center_verts:
		for edge in [EDGE_TOP, EDGE_RIGHT, EDGE_BOTTOM, EDGE_LEFT]:
			if _vertex_on_edge(v, half, tol, edge):
				if not edge_verts.has(edge):
					edge_verts[edge] = []
				edge_verts[edge].append(v)

	var result: Dictionary = {}
	for edge in edge_verts.keys():
		var arr: Array = edge_verts[edge]
		if arr.size() < 2:
			continue
		var best_dist: float = -1.0
		var best_a: Vector2 = arr[0]
		var best_b: Vector2 = arr[0]
		for i in arr.size():
			for j in range(i + 1, arr.size()):
				var d: float = (arr[i] as Vector2).distance_to(arr[j] as Vector2)
				if d > best_dist:
					best_dist = d
					best_a = arr[i]
					best_b = arr[j]
		result[edge] = {"start": best_a, "end": best_b}

	return result

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
			return _make_circle_vertices(r, Bayterek.CIRCLE_SEGMENTS)
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

func _apply_corner_rounding(verts: PackedVector2Array, radius: float) -> PackedVector2Array:
	if radius <= 0.01 or verts.size() < 3:
		return verts

	var result := PackedVector2Array()
	var n: int = verts.size()

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

		var d: float = radius / tan_half
		d = minf(d, minf(len_prev * 0.5, len_next * 0.5))

		var p_start: Vector2 = curr_v + dir_prev * d
		var p_end: Vector2 = curr_v + dir_next * d

		var bisector: Vector2 = dir_prev + dir_next
		if bisector.length_squared() < 0.0001:
			result.append(curr_v)
			continue
		bisector = bisector.normalized()

		var r_eff: float = d * tan_half
		var arc_center: Vector2 = curr_v + bisector * (r_eff / sin_half)

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

		var segments: int = Bayterek.CORNER_SEGMENTS
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
	copy.border_corner_gap = border_corner_gap
	copy.border_top_enabled = border_top_enabled
	copy.border_right_enabled = border_right_enabled
	copy.border_bottom_enabled = border_bottom_enabled
	copy.border_left_enabled = border_left_enabled
	copy.border_configs = border_configs.duplicate(true)
	copy.shadow_enabled = shadow_enabled
	copy.shadow_color = shadow_color
	copy.shadow_size = shadow_size
	copy.shadow_blur = shadow_blur
	return copy

func _to_string() -> String:
	return "BayterekShapeLayer(name='%s', type=%s)" % [layer_name, ShapeType.keys()[shape_type]]