@tool
class_name BayterekShapeLayer
extends BayterekLayer
## Shape layer — circle, square, triangle, pentagon, hexagon.
## Supports fill, border (per-edge vector lines), corner rounding and shadow.
##
## Pixel mode: per-pixel "inside shape?" test on pixel centers.
## Border = inside outer AND within `bw` pixels of the outer edge.
## Fill   = inside outer AND farther than `bw` from the outer edge.
## This gives uniform border thickness on diagonal edges too (no gaps).

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

enum ShapeType {
	CIRCLE,
	SQUARE,
	TRIANGLE,
	PENTAGON,
	HEXAGON,
}

const EDGE_TOP := 0
const EDGE_RIGHT := 1
const EDGE_BOTTOM := 2
const EDGE_LEFT := 3

# ============================================================
# RENDER CACHE
# ============================================================
# Bu cache'ler, tekrarlayan pahalı hesaplamaları önler.
# Her cache, girdi parametrelerinden üretilen bir key ile eşleşir.
# Parametreler değişince key değişir → eski cache kullanılmaz.

var _pixel_spans_cache: Dictionary = {}
var _pixel_spans_cache_key: String = ""

var _polygon_cache: Dictionary = {}

var _border_segments_cache: Dictionary = {}

@export_storage var shape_type: ShapeType = ShapeType.CIRCLE

@export_storage var corner_radius: float = 0.0

# --- Fill ---
@export_storage var fill_enabled: bool = true
@export_storage var fill_configs: Dictionary = {}

# --- Border ---
@export_storage var border_enabled: bool = false
@export_storage var border_width: float = 2.0
@export_storage var border_corner_gap: bool = false
@export_storage var border_top_enabled: bool = true
@export_storage var border_right_enabled: bool = true
@export_storage var border_bottom_enabled: bool = true
@export_storage var border_left_enabled: bool = true
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

func get_clamped_corner_radius(effective_size: Vector2, _pixel_mode: bool = false) -> float:
	if shape_type == ShapeType.CIRCLE:
		return 0.0
	if border_corner_gap:
		return 0.0
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
# VERTEX COMPUTATION (vector mode)
# ============================================================

func get_polygon_vertices(effective_size: Vector2, pixel_mode: bool = false) -> PackedVector2Array:
	var cache_key: String = "poly_%d_%d_%d_%d_%d" % [
		int(round(effective_size.x)),
		int(round(effective_size.y)),
		int(shape_type),
		int(round(corner_radius * 100.0)),
		1 if pixel_mode else 0,
	]
	if _polygon_cache.has(cache_key):
		var cached: PackedVector2Array = _polygon_cache[cache_key]
		return cached

	var result: PackedVector2Array = _build_polygon(
		effective_size,
		get_clamped_corner_radius(effective_size, pixel_mode),
		pixel_mode
	)
	_polygon_cache[cache_key] = result
	return result

func get_fill_vertices(effective_size: Vector2, pixel_mode: bool = false) -> PackedVector2Array:
	var cache_key: String = "fv_%d_%d_%d_%d_%d_%d_%d" % [
		int(round(effective_size.x)),
		int(round(effective_size.y)),
		int(shape_type),
		int(round(corner_radius * 100.0)),
		int(round(border_width * 100.0)),
		1 if pixel_mode else 0,
		1 if border_enabled else 0,
	]
	if _polygon_cache.has(cache_key):
		var cached: PackedVector2Array = _polygon_cache[cache_key]
		return cached

	var result: PackedVector2Array

	if not border_enabled or border_width <= 0.0:
		result = _build_polygon(effective_size, get_clamped_corner_radius(effective_size, pixel_mode), pixel_mode)
	else:
		var inset: float = border_width
		var inner_size: Vector2 = effective_size - Vector2(inset, inset) * 2.0
		if inner_size.x <= 0.5 or inner_size.y <= 0.5:
			result = PackedVector2Array()
		else:
			var cr: float = get_clamped_corner_radius(effective_size, pixel_mode)
			var inner_radius: float = maxf(0.0, cr - inset)
			result = _build_polygon(inner_size, inner_radius, pixel_mode)

	_polygon_cache[cache_key] = result
	return result

func get_border_centerline_vertices(effective_size: Vector2, pixel_mode: bool = false) -> PackedVector2Array:
	var cache_key: String = "bcv_%d_%d_%d_%d_%d_%d" % [
		int(round(effective_size.x)),
		int(round(effective_size.y)),
		int(shape_type),
		int(round(corner_radius * 100.0)),
		int(round(border_width * 100.0)),
		1 if pixel_mode else 0,
	]
	if _polygon_cache.has(cache_key):
		return _polygon_cache[cache_key]

	var result: PackedVector2Array

	if border_width <= 0.0:
		result = _build_polygon(effective_size, get_clamped_corner_radius(effective_size, pixel_mode), pixel_mode)
	else:
		var inset: float = border_width * 0.5
		var center_size: Vector2 = effective_size - Vector2(inset, inset) * 2.0
		if center_size.x <= 0.5 or center_size.y <= 0.5:
			result = PackedVector2Array()
		else:
			var cr: float = get_clamped_corner_radius(effective_size, pixel_mode)
			var center_radius: float = maxf(0.0, cr - inset)
			result = _build_polygon(center_size, center_radius, pixel_mode)

	_polygon_cache[cache_key] = result
	return result

func get_border_vertices(effective_size: Vector2, pixel_mode: bool = false) -> PackedVector2Array:
	return get_polygon_vertices(effective_size, pixel_mode)

# ============================================================
# BORDER SEGMENT COMPUTATION (vector mode)
# ============================================================

func get_border_segments(effective_size: Vector2, pixel_mode: bool = false) -> Array:
	var cache_key: String = "bs_%d_%d_%d_%d_%d_%d_%d_%d_%d_%d_%d_%d" % [
		int(round(effective_size.x)),
		int(round(effective_size.y)),
		int(shape_type),
		int(round(corner_radius * 100.0)),
		int(round(border_width * 100.0)),
		1 if border_corner_gap else 0,
		1 if border_top_enabled else 0,
		1 if border_right_enabled else 0,
		1 if border_bottom_enabled else 0,
		1 if border_left_enabled else 0,
		1 if pixel_mode else 0,
		1 if border_enabled else 0,
	]
	if _border_segments_cache.has(cache_key):
		return _border_segments_cache[cache_key]

	var center_verts: PackedVector2Array = get_border_centerline_vertices(effective_size, pixel_mode)
	if center_verts.size() < 2:
		_border_segments_cache[cache_key] = []
		return []

	if shape_type == ShapeType.CIRCLE:
		var ring: Array = [_make_closed_ring(center_verts)]
		_border_segments_cache[cache_key] = ring
		return ring

	if not border_corner_gap and enabled_edge_count() >= 4:
		var ring2: Array = [_make_closed_ring(center_verts)]
		_border_segments_cache[cache_key] = ring2
		return ring2

	var half: Vector2 = effective_size * 0.5
	var tol: float = maxf(border_width * 0.5 + 0.5, 1.0) + get_clamped_corner_radius(effective_size, pixel_mode)

	var result: Array = []

	if border_corner_gap:
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
		for edge in [EDGE_TOP, EDGE_RIGHT, EDGE_BOTTOM, EDGE_LEFT]:
			if not is_edge_enabled(edge):
				continue
			var pts: PackedVector2Array = _collect_edge_vertices(center_verts, half, tol, edge)
			if pts.size() >= 2:
				result.append(pts)

	_border_segments_cache[cache_key] = result
	return result

func _make_closed_ring(center_verts: PackedVector2Array) -> PackedVector2Array:
	var ring := PackedVector2Array()
	ring.resize(center_verts.size() + 1)
	for i in center_verts.size():
		ring[i] = center_verts[i]
	ring[center_verts.size()] = center_verts[0]
	return ring

func _collect_edge_vertices(center_verts: PackedVector2Array, half: Vector2, tol: float, edge: int) -> PackedVector2Array:
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

func _find_edge_endpoints(center_verts: PackedVector2Array, half: Vector2, tol: float) -> Dictionary:
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
# PIXEL SCANLINE — point-in-shape test + edge-distance border
# ============================================================

func is_axis_aligned() -> bool:
	if not transform:
		return true
	return is_zero_approx(transform.rotation) and is_zero_approx(transform.skew.x) and is_zero_approx(transform.skew.y)

## Returns { "fill": [Rect2i...], "border": [Rect2i...] } in design
## coordinates (0,0 = shape center). All rects have height 1.
##
## Border classification uses distance-to-edge, not an inner polygon.
## This guarantees uniform thickness on diagonal edges across all shapes.
func get_pixel_spans(effective_size: Vector2) -> Dictionary:
	var cache_key: String = "ps_%d_%d_%d_%d_%d_%d_%d_%d" % [
		int(round(effective_size.x)),
		int(round(effective_size.y)),
		int(shape_type),
		int(round(corner_radius * 100.0)),
		int(round(border_width * 100.0)),
		1 if border_enabled else 0,
		1 if border_corner_gap else 0,
		1 if fill_enabled else 0,
	]
	if cache_key == _pixel_spans_cache_key:
		return _pixel_spans_cache

	var fill_spans: Array = []
	var border_spans: Array = []

	var W: int = int(round(effective_size.x))
	var H: int = int(round(effective_size.y))
	if W <= 0 or H <= 0:
		var empty: Dictionary = {"fill": fill_spans, "border": border_spans}
		_pixel_spans_cache = empty
		_pixel_spans_cache_key = cache_key
		return empty

	var bw: int = 0
	if border_enabled and border_width > 0.0:
		bw = maxi(1, int(round(border_width)))

	var R: int = 0
	if shape_type != ShapeType.CIRCLE and corner_radius > 0.0 and not border_corner_gap:
		var limit: int = int(floor(min(W, H) * 0.5 * Bayterek.CORNER_RADIUS_CLAMP_FACTOR))
		R = clampi(int(round(corner_radius)), 0, limit)

	var outer_poly: PackedVector2Array = PackedVector2Array()
	if shape_type in [ShapeType.TRIANGLE, ShapeType.PENTAGON, ShapeType.HEXAGON]:
		outer_poly = _shape_pixel_outline(W, H, R)

	var x_off: int = -W / 2
	var y_off: int = -H / 2

	for y in range(H):
		var row_fill_runs: Array = []
		var row_border_runs: Array = []
		var fill_active: bool = false
		var border_active: bool = false
		var fill_start: int = 0
		var border_start: int = 0

		for x in range(W):
			var ox: float = float(x) + 0.5
			var oy: float = float(y) + 0.5

			var outer_hit: bool = _pixel_inside(ox, oy, W, H, R, outer_poly)

			var is_fill: bool = false
			var is_border: bool = false

			if outer_hit:
				if bw > 0:
					var dist_to_edge: float = _pixel_edge_distance(
						ox, oy, W, H, R, outer_poly
					)
					if dist_to_edge <= float(bw):
						is_border = true
					else:
						is_fill = true
				else:
					is_fill = true

			if is_fill and not fill_active:
				fill_active = true
				fill_start = x
			elif not is_fill and fill_active:
				fill_active = false
				row_fill_runs.append(Vector2i(fill_start, x))

			if is_border and not border_active:
				border_active = true
				border_start = x
			elif not is_border and border_active:
				border_active = false
				row_border_runs.append(Vector2i(border_start, x))

		if fill_active:
			row_fill_runs.append(Vector2i(fill_start, W))
		if border_active:
			row_border_runs.append(Vector2i(border_start, W))

		for r in row_fill_runs:
			fill_spans.append(Rect2i(r.x + x_off, y + y_off, r.y - r.x, 1))
		for r in row_border_runs:
			border_spans.append(Rect2i(r.x + x_off, y + y_off, r.y - r.x, 1))

	var result: Dictionary = {"fill": fill_spans, "border": border_spans}
	_pixel_spans_cache = result
	_pixel_spans_cache_key = cache_key
	return result

## Distance from (px, py) to the shape's nearest edge.
## Circle: r - d. Square: min(hw - |lx|, hh - |ly|). Polygon: min segment distance.
func _pixel_edge_distance(px: float, py: float, W: int, H: int, R: int, poly: PackedVector2Array) -> float:
	if shape_type == ShapeType.CIRCLE:
		var cx: float = float(W) * 0.5
		var cy: float = float(H) * 0.5
		var r: float = minf(cx, cy)
		return r - Vector2(px, py).distance_to(Vector2(cx, cy))

	if shape_type == ShapeType.SQUARE:
		var cx2: float = float(W) * 0.5
		var cy2: float = float(H) * 0.5
		var hw: float = float(W) * 0.5
		var hh: float = float(H) * 0.5
		var dx: float = hw - absf(px - cx2)
		var dy: float = hh - absf(py - cy2)
		var r2: int = clampi(R, 0, int(minf(hw, hh)))
		if r2 > 0:
			var ax: float = absf(px - cx2)
			var ay: float = absf(py - cy2)
			if ax > hw - r2 and ay > hh - r2:
				var arc_cx: float = hw - r2
				var arc_cy: float = hh - r2
				var qx: float = ax - arc_cx
				var qy: float = ay - arc_cy
				return float(r2) - sqrt(qx * qx + qy * qy)
		return minf(dx, dy)

	if poly.size() < 2:
		return 1e9
	var best: float = 1e9
	var n: int = poly.size()
	for i in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		var d: float = _point_segment_distance(px, py, a, b)
		if d < best:
			best = d
	return best

func _point_segment_distance(px: float, py: float, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var ap: Vector2 = Vector2(px, py) - a
	var ab_len_sq: float = ab.length_squared()
	if ab_len_sq < 0.0001:
		return ap.length()
	var t: float = clampf(ap.dot(ab) / ab_len_sq, 0.0, 1.0)
	var closest: Vector2 = a + ab * t
	return Vector2(px, py).distance_to(closest)

## Returns a polygon outline in local pixel coords [0..W, 0..H].
## Normalized on both axes so the polygon fills the box exactly.
func _shape_pixel_outline(W: int, H: int, R: int) -> PackedVector2Array:
	if shape_type == ShapeType.CIRCLE or shape_type == ShapeType.SQUARE:
		return PackedVector2Array()

	var sides: int = 3 if shape_type == ShapeType.TRIANGLE else (5 if shape_type == ShapeType.PENTAGON else 6)
	var half_x: float = float(W) * 0.5
	var half_y: float = float(H) * 0.5

	var base: PackedVector2Array = PackedVector2Array()
	base.resize(sides)
	var start_angle: float = -PI * 0.5
	for i in sides:
		var angle: float = start_angle + TAU * float(i) / float(sides)
		base[i] = Vector2(cos(angle) * half_x, sin(angle) * half_y)

	var y_min: float = INF
	var y_max: float = -INF
	for v in base:
		y_min = minf(y_min, v.y)
		y_max = maxf(y_max, v.y)
	var y_range: float = y_max - y_min
	if y_range > 0.001:
		var scale_y: float = float(H) / y_range
		for i in base.size():
			base[i].y = (base[i].y - y_min) * scale_y

	var x_min: float = INF
	var x_max: float = -INF
	for v in base:
		x_min = minf(x_min, v.x)
		x_max = maxf(x_max, v.x)
	var x_range: float = x_max - x_min
	if x_range > 0.001:
		var scale_x: float = float(W) / x_range
		for i in base.size():
			base[i].x = (base[i].x - x_min) * scale_x

	if R > 0:
		var center_pt: Vector2 = Vector2(float(W) * 0.5, float(H) * 0.5)
		for i in base.size():
			base[i] -= center_pt
		base = _apply_corner_rounding(base, float(R), false)
		for i in base.size():
			base[i] += center_pt

	return base

func _pixel_inside(px: float, py: float, W: int, H: int, R: int, poly: PackedVector2Array) -> bool:
	if shape_type == ShapeType.CIRCLE:
		var cx: float = float(W) * 0.5
		var cy: float = float(H) * 0.5
		var r: float = minf(cx, cy)
		var dx: float = px - cx
		var dy: float = py - cy
		return dx * dx + dy * dy <= r * r

	if shape_type == ShapeType.SQUARE:
		var cx2: float = float(W) * 0.5
		var cy2: float = float(H) * 0.5
		var hw: float = float(W) * 0.5
		var hh: float = float(H) * 0.5
		var lx: float = px - cx2
		var ly: float = py - cy2
		var r2: int = clampi(R, 0, int(minf(hw, hh)))
		var ax: float = absf(lx)
		var ay: float = absf(ly)
		if ax > hw or ay > hh:
			return false
		if r2 <= 0:
			return true
		if ax <= hw - r2 or ay <= hh - r2:
			return true
		var qx: float = ax - (hw - r2)
		var qy: float = ay - (hh - r2)
		return qx * qx + qy * qy <= float(r2) * float(r2)

	if poly.size() < 3:
		return false
	var inside: bool = false
	var n: int = poly.size()
	var j: int = n - 1
	for i in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[j]
		if absf(a.y - b.y) < 0.0001:
			j = i
			continue
		var y_min: float = minf(a.y, b.y)
		var y_max: float = maxf(a.y, b.y)
		if py < y_min or py >= y_max:
			j = i
			continue
		var t: float = (py - a.y) / (b.y - a.y)
		var x_cross: float = a.x + t * (b.x - a.x)
		if px < x_cross:
			inside = not inside
		j = i
	return inside

# ============================================================
# INTERNAL POLYGON BUILDER (vector mode)
# ============================================================

func _build_polygon(size_vec: Vector2, radius: float, pixel_mode: bool) -> PackedVector2Array:
	var half: Vector2 = size_vec * 0.5
	if half.x <= 0.0 or half.y <= 0.0:
		return PackedVector2Array()

	var base_verts: PackedVector2Array

	match shape_type:
		ShapeType.CIRCLE:
			var r: float = minf(half.x, half.y)
			return _make_circle_vertices(r, Bayterek.CIRCLE_SEGMENTS, pixel_mode)
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
		return _apply_corner_rounding(base_verts, radius, pixel_mode)
	return base_verts

func _make_circle_vertices(radius: float, segments: int, pixel_mode: bool = false) -> PackedVector2Array:
	if pixel_mode:
		segments = clampi(int(round(radius * 1.5)), 8, 32)

	var pts := PackedVector2Array()
	pts.resize(segments)
	for i in segments:
		var angle: float = TAU * float(i) / float(segments)
		var p := Vector2(cos(angle), sin(angle)) * radius
		if pixel_mode:
			p = p.snapped(Vector2(1.0, 1.0))
		pts[i] = p
	return pts

func _make_regular_polygon(half: Vector2, sides: int, start_angle: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(sides)
	for i in sides:
		var angle: float = start_angle + TAU * float(i) / float(sides)
		pts[i] = Vector2(cos(angle) * half.x, sin(angle) * half.y)
	return pts

func _apply_corner_rounding(verts: PackedVector2Array, radius: float, pixel_mode: bool = false) -> PackedVector2Array:
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

	var segments: int = Bayterek.CORNER_SEGMENTS
	if pixel_mode:
		segments = clampi(int(round(radius * 0.75)), 3, 10)

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

		for s in range(segments + 1):
			var t: float = float(s) / float(segments)
			var ang: float = a_start + delta * t
			var p: Vector2 = arc_center + Vector2(cos(ang), sin(ang)) * r_eff
			if pixel_mode:
				p = p.snapped(Vector2(1.0, 1.0))
			result.append(p)

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

# ============================================================
# CACHE MANAGEMENT
# ============================================================

func clear_render_cache() -> void:
	_pixel_spans_cache.clear()
	_pixel_spans_cache_key = ""
	_polygon_cache.clear()
	_border_segments_cache.clear()