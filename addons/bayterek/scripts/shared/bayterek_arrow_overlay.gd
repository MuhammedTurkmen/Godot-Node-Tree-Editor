@tool
class_name BayterekArrowOverlay
extends Control
## Draws the arrow heads of a connection as a SEPARATE CanvasItem.

# ============================================================
# ENUMS
# ============================================================

enum ArrowStyle {
	NONE,
	ARROW,
	T_BAR,
	SQUARE,
	CIRCLE,
	DIAMOND,
}

# ============================================================
# CONSTANTS
# ============================================================

const MIN_ARROW_SIZE := 2.0
const DEBUG_POLYGON := true

# ============================================================
# ARROW CONFIG
# ============================================================

var start_arrow: ArrowStyle = ArrowStyle.NONE : set = set_start_arrow
var end_arrow: ArrowStyle = ArrowStyle.NONE : set = set_end_arrow
var arrow_size: float = 12.0 : set = set_arrow_size

var arrow_texture_start: Texture2D = null : set = set_arrow_texture_start
var arrow_texture_end: Texture2D = null : set = set_arrow_texture_end

var arrow_scale: Vector2 = Vector2.ONE
var arrow_tint: Color = Color.WHITE : set = set_arrow_tint
var arrow_offset_x: float = 0.0 : set = set_arrow_offset_x

var arrow_texture_pivot: Vector2 = Vector2(0.5, 0.5)

var default_color: Color = Color(0.7, 0.7, 0.7, 0.9) : set = set_default_color

var arrow_texture_filter_override: int = 0 :
	set(v):
		arrow_texture_filter_override = v
		_apply_texture_filter()
		queue_redraw()

# ============================================================
# GEOMETRY INPUT
# ============================================================

var line_start: Vector2 = Vector2.ZERO
var line_end: Vector2 = Vector2.ZERO
var start_outward: Vector2 = Vector2.ZERO
var end_outward: Vector2 = Vector2.ZERO

# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_texture_filter()

# ============================================================
# SETTERS
# ============================================================

func set_start_arrow(style: ArrowStyle) -> void:
	start_arrow = style
	queue_redraw()

func set_end_arrow(style: ArrowStyle) -> void:
	end_arrow = style
	queue_redraw()

func set_arrow_size(size: float) -> void:
	arrow_size = max(1.0, size)
	queue_redraw()

func set_arrow_texture_start(t: Texture2D) -> void:
	arrow_texture_start = t
	queue_redraw()

func set_arrow_texture_end(t: Texture2D) -> void:
	arrow_texture_end = t
	queue_redraw()

func set_arrow_scale(s: Vector2) -> void:
	arrow_scale = Vector2(maxf(0.05, s.x), maxf(0.05, s.y))
	queue_redraw()

func set_arrow_tint(c: Color) -> void:
	arrow_tint = c
	queue_redraw()

func set_arrow_offset_x(v: float) -> void:
	arrow_offset_x = v
	queue_redraw()

func set_default_color(c: Color) -> void:
	default_color = c
	queue_redraw()

# ============================================================
# GEOMETRY SETTER
# ============================================================

func set_endpoints(start_pt: Vector2, end_pt: Vector2) -> void:
	line_start = start_pt
	line_end = end_pt

	var delta: Vector2 = end_pt - start_pt
	var len: float = delta.length()
	if len > 0.0001:
		var dir: Vector2 = delta / len
		start_outward = -dir
		end_outward = dir
	else:
		start_outward = Vector2.ZERO
		end_outward = Vector2.ZERO

	queue_redraw()

# ============================================================
# TEXTURE FILTER
# ============================================================

func _apply_texture_filter() -> void:
	match arrow_texture_filter_override:
		1:
			texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		2:
			texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_:
			texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

# ============================================================
# DRAW
# ============================================================

func _draw() -> void:
	_draw_start_arrow()
	_draw_end_arrow()

func _draw_start_arrow() -> void:
	if start_arrow == ArrowStyle.NONE and arrow_texture_start == null:
		return
	if start_outward == Vector2.ZERO:
		return

	var tip: Vector2 = line_start + start_outward * arrow_offset_x

	if arrow_texture_start != null:
		_draw_arrow_texture(tip, start_outward, arrow_texture_start)
	else:
		_draw_arrow_shape(tip, start_outward, start_arrow)

func _draw_end_arrow() -> void:
	if end_arrow == ArrowStyle.NONE and arrow_texture_end == null:
		return
	if end_outward == Vector2.ZERO:
		return

	var tip: Vector2 = line_end + end_outward * arrow_offset_x

	if arrow_texture_end != null:
		_draw_arrow_texture(tip, end_outward, arrow_texture_end)
	else:
		_draw_arrow_shape(tip, end_outward, end_arrow)

# ============================================================
# SAFE POLYGON DRAW
# ============================================================

func _safe_draw_polygon(pts: PackedVector2Array, color: Color, tag: String = "arrow_poly") -> void:
	if pts.size() < 3:
		return

	var area: float = 0.0
	var n: int = pts.size()
	for i in range(n):
		var p0: Vector2 = pts[i]
		var p1: Vector2 = pts[(i + 1) % n]
		area += p0.x * p1.y - p1.x * p0.y

	if DEBUG_POLYGON:
		if absf(area) < 1.0:
			print("[BayterekArrowOverlay] SKIP degenerate %s: area=%.4f pts=%s arrow_size=%.3f" % [tag, area, str(pts), arrow_size])

	if absf(area) < 1.0:
		return

	draw_colored_polygon(pts, color)

# ============================================================
# TEXTURE ARROW
# ============================================================

func _draw_arrow_texture(tip: Vector2, outward: Vector2, tex: Texture2D) -> void:
	if tex == null:
		return
	var tex_size: Vector2 = tex.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	var ax: float = maxf(0.05, absf(arrow_scale.x))
	var ay: float = maxf(0.05, absf(arrow_scale.y))

	var scaled_size: Vector2 = Vector2(tex_size.x * ax, tex_size.y * ay)

	if scaled_size.x < 0.5 or scaled_size.y < 0.5:
		return

	var angle: float = atan2(outward.y, outward.x)

	var basis := Transform2D(angle, Vector2.ZERO)
	basis = basis.scaled(Vector2(ax, ay))

	var pivot_px: Vector2 = Vector2(
		tex_size.x * arrow_texture_pivot.x,
		tex_size.y * arrow_texture_pivot.y
	)

	var top_left: Vector2 = tip - (basis * pivot_px)

	var xform := Transform2D(basis.x, basis.y, top_left)

	draw_set_transform_matrix(xform)
	var rect := Rect2(Vector2.ZERO, tex_size)
	draw_texture_rect(tex, rect, false, arrow_tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)

# ============================================================
# VECTOR ARROW
# ============================================================

func _draw_arrow_shape(tip: Vector2, outward: Vector2, style: ArrowStyle) -> void:
	var size: float = arrow_size
	var perp: Vector2 = Vector2(-outward.y, outward.x)

	if size < MIN_ARROW_SIZE:
		return

	match style:
		ArrowStyle.ARROW:
			var apex: Vector2 = tip + outward * size
			var left: Vector2 = tip + perp * (size * 0.5)
			var right: Vector2 = tip - perp * (size * 0.5)
			_safe_draw_polygon(PackedVector2Array([apex, left, right]), default_color, "arrow")

		ArrowStyle.T_BAR:
			var half_len: float = size * 0.6
			var thickness: float = max(2.0, size * 0.35)
			var half_th: float = thickness * 0.5

			if half_len < 0.5 or half_th < 0.5:
				return

			var along_outward: Vector2 = outward * half_th

			var left_end: Vector2 = tip + perp * half_len
			var right_end: Vector2 = tip - perp * half_len

			var p0: Vector2 = left_end + along_outward
			var p1: Vector2 = right_end + along_outward
			var p2: Vector2 = right_end - along_outward
			var p3: Vector2 = left_end - along_outward

			_safe_draw_polygon(PackedVector2Array([p0, p1, p2, p3]), default_color, "t_bar")

		ArrowStyle.SQUARE:
			var half_s: float = size * 0.5

			if half_s < 0.5:
				return

			var back: Vector2 = tip - outward * half_s
			var front: Vector2 = tip + outward * half_s
			var top_back: Vector2 = back + perp * half_s
			var bot_back: Vector2 = back - perp * half_s
			var top_front: Vector2 = front + perp * half_s
			var bot_front: Vector2 = front - perp * half_s
			_safe_draw_polygon(
				PackedVector2Array([top_back, top_front, bot_front, bot_back]),
				default_color,
				"square"
			)

		ArrowStyle.CIRCLE:
			var radius: float = size * 0.5
			if radius < 0.5:
				return
			draw_circle(tip, radius, default_color)

		ArrowStyle.DIAMOND:
			var d_size: float = size * 0.65
			if d_size < 0.5:
				return
			var apex: Vector2 = tip + outward * d_size
			var back_pt: Vector2 = tip - outward * d_size
			var left: Vector2 = tip + perp * d_size
			var right: Vector2 = tip - perp * d_size
			_safe_draw_polygon(
				PackedVector2Array([apex, left, back_pt, right]),
				default_color,
				"diamond"
			)