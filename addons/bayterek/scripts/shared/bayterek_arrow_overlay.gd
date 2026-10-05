@tool
class_name BayterekArrowOverlay
extends Control
## Draws the arrow heads of a connection as a SEPARATE CanvasItem.
##
## Positioning model:
##   - The connection's service computes each arrow's CENTER (world pos)
##     and ANGLE (radians, direction the tip points).
##   - This overlay draws the arrow at that center, rotated by that angle.
##   - The arrow's pivot is always its geometric center.
##
## ROTATION:
##   Both START and END arrows point AT the node they are attached to.
##   - START arrow (next to source node)  → tip points at the source node.
##   - END arrow   (next to target node)  → tip points at the target node.

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

const MIN_VECTOR_SIZE := 2.0
const DEBUG_POLYGON := false
const VECTOR_ARROW_BASE_SIZE := 16.0

# ============================================================
# ARROW CONFIG
# ============================================================

var start_arrow: ArrowStyle = ArrowStyle.NONE : set = set_start_arrow
var end_arrow: ArrowStyle = ArrowStyle.NONE : set = set_end_arrow

var arrow_texture_start: Texture2D = null : set = set_arrow_texture_start
var arrow_texture_end: Texture2D = null : set = set_arrow_texture_end

var start_arrow_scale: float = 1.0 : set = set_start_arrow_scale
var end_arrow_scale: float = 1.0 : set = set_end_arrow_scale

var start_arrow_tint: Color = Color.WHITE : set = set_start_arrow_tint
var end_arrow_tint: Color = Color.WHITE : set = set_end_arrow_tint

var default_color: Color = Color(0.7, 0.7, 0.7, 0.9) : set = set_default_color

var arrow_texture_filter_override: int = 0 :
	set(v):
		arrow_texture_filter_override = v
		_apply_texture_filter()
		queue_redraw()

# ============================================================
# GEOMETRY INPUT (set by the connections service)
# ============================================================

var start_arrow_center: Vector2 = Vector2.ZERO
var end_arrow_center: Vector2 = Vector2.ZERO

var start_arrow_angle: float = 0.0
var end_arrow_angle: float = 0.0

var start_arrow_extent: float = 0.0
var end_arrow_extent: float = 0.0

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

func set_arrow_texture_start(t: Texture2D) -> void:
	arrow_texture_start = t
	queue_redraw()

func set_arrow_texture_end(t: Texture2D) -> void:
	arrow_texture_end = t
	queue_redraw()

func set_start_arrow_scale(s: float) -> void:
	start_arrow_scale = maxf(0.01, s)
	queue_redraw()

func set_end_arrow_scale(s: float) -> void:
	end_arrow_scale = maxf(0.01, s)
	queue_redraw()

func set_start_arrow_tint(c: Color) -> void:
	start_arrow_tint = c
	queue_redraw()

func set_end_arrow_tint(c: Color) -> void:
	end_arrow_tint = c
	queue_redraw()

func set_default_color(c: Color) -> void:
	default_color = c
	queue_redraw()

# ============================================================
# GEOMETRY SETTER
# ============================================================

func set_arrow_geometry(
	p_start_center: Vector2,
	p_start_angle: float,
	p_start_extent: float,
	p_end_center: Vector2,
	p_end_angle: float,
	p_end_extent: float
) -> void:
	start_arrow_center = p_start_center
	start_arrow_angle = p_start_angle
	start_arrow_extent = p_start_extent

	end_arrow_center = p_end_center
	end_arrow_angle = p_end_angle
	end_arrow_extent = p_end_extent

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
	if start_arrow_extent < 0.5:
		return

	if arrow_texture_start != null:
		_draw_arrow_texture(start_arrow_center, start_arrow_angle, start_arrow_scale, start_arrow_tint, arrow_texture_start)
	else:
		_draw_arrow_shape(start_arrow_center, start_arrow_angle, start_arrow_scale, start_arrow, start_arrow_tint)


func _draw_end_arrow() -> void:
	if end_arrow == ArrowStyle.NONE and arrow_texture_end == null:
		return
	if end_arrow_extent < 0.5:
		return

	if arrow_texture_end != null:
		_draw_arrow_texture(end_arrow_center, end_arrow_angle, end_arrow_scale, end_arrow_tint, arrow_texture_end)
	else:
		_draw_arrow_shape(end_arrow_center, end_arrow_angle, end_arrow_scale, end_arrow, end_arrow_tint)

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
			print("[BayterekArrowOverlay] SKIP degenerate %s: area=%.4f" % [tag, area])

	if absf(area) < 1.0:
		return

	draw_colored_polygon(pts, color)

# ============================================================
# TEXTURE ARROW
# ============================================================
#
# The arrow is drawn centered on `center`, rotated by `angle`. The
# texture's local +X axis is aligned with the arrow's tip direction.
#
# NOTE: We build the transform manually so the pivot is EXACTLY the
# arrow center, avoiding any ambiguity with the Control's own transform.

func _draw_arrow_texture(center: Vector2, angle: float, scale: float, tint: Color, tex: Texture2D) -> void:
	if tex == null:
		return

	var tex_size: Vector2 = tex.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	var half_size: Vector2 = tex_size * 0.5

	# Rotation matrix
	var cos_a: float = cos(angle)
	var sin_a: float = sin(angle)
	var rot := Transform2D(
		Vector2(cos_a, sin_a),
		Vector2(-sin_a, cos_a),
		Vector2.ZERO
	)

	# Scale uniformly, then rotate
	var basis := Transform2D(
		rot.x * scale,
		rot.y * scale,
		Vector2.ZERO
	)

	# origin = center - (rotated & scaled half_size)
	var origin: Vector2 = center - (basis * half_size)

	var xform := Transform2D(basis.x, basis.y, origin)

	draw_set_transform_matrix(xform)
	var rect := Rect2(Vector2.ZERO, tex_size)
	draw_texture_rect(tex, rect, false, tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)

# ============================================================
# VECTOR ARROW
# ============================================================

func _draw_arrow_shape(center: Vector2, angle: float, scale: float, style: ArrowStyle, color: Color) -> void:
	var size: float = VECTOR_ARROW_BASE_SIZE * scale
	if size < MIN_VECTOR_SIZE:
		return

	var ax: Vector2 = Vector2(cos(angle), sin(angle))
	var ay: Vector2 = Vector2(-ax.y, ax.x)

	match style:
		ArrowStyle.ARROW:
			var apex: Vector2 = center + ax * (size * 0.5)
			var back_l: Vector2 = center - ax * (size * 0.5) + ay * (size * 0.5)
			var back_r: Vector2 = center - ax * (size * 0.5) - ay * (size * 0.5)
			_safe_draw_polygon(PackedVector2Array([apex, back_l, back_r]), color, "arrow")

		ArrowStyle.T_BAR:
			var half_len: float = size * 0.6
			var thickness: float = maxf(2.0, size * 0.35)
			var half_th: float = thickness * 0.5

			var left_end: Vector2 = center + ay * half_len
			var right_end: Vector2 = center - ay * half_len

			var p0: Vector2 = left_end + ax * half_th
			var p1: Vector2 = right_end + ax * half_th
			var p2: Vector2 = right_end - ax * half_th
			var p3: Vector2 = left_end - ax * half_th

			_safe_draw_polygon(PackedVector2Array([p0, p1, p2, p3]), color, "t_bar")

		ArrowStyle.SQUARE:
			var half_s: float = size * 0.5
			var p0: Vector2 = center - ax * half_s - ay * half_s
			var p1: Vector2 = center + ax * half_s - ay * half_s
			var p2: Vector2 = center + ax * half_s + ay * half_s
			var p3: Vector2 = center - ax * half_s + ay * half_s
			_safe_draw_polygon(PackedVector2Array([p0, p1, p2, p3]), color, "square")

		ArrowStyle.CIRCLE:
			var radius: float = size * 0.5
			if radius < 0.5:
				return
			draw_circle(center, radius, color)

		ArrowStyle.DIAMOND:
			var d_size: float = size * 0.65
			var apex: Vector2 = center + ax * d_size
			var back_pt: Vector2 = center - ax * d_size
			var left: Vector2 = center + ay * d_size
			var right: Vector2 = center - ay * d_size
			_safe_draw_polygon(
				PackedVector2Array([apex, left, back_pt, right]),
				color,
				"diamond"
			)