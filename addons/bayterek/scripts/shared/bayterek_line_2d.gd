@tool
class_name BayterekLine2D
extends Control
## Custom Line2D replacement.
##
## Godot 4's Line2D has a broken LINE_TEXTURE_TILE mode: texture tiling
## silently fails on compressed textures, and dash patterns cannot be
## achieved by splitting the points array. This class draws lines manually
## with full control over:
##
##   - texture tiling along the polyline
##   - dash / dot / dash-dot patterns
##   - line width, color, and endpoint style
##   - any shape: straight, bezier, arc, step
##
## Usage is identical to Line2D: set `points`, `width`, `texture`, and
## the internal _draw() will render everything.

# --- Line geometry ---
var points: PackedVector2Array = PackedVector2Array() : set = set_points
var width: float = 4.0 : set = set_width

# --- Visual style ---
var default_color: Color = Color(0.7, 0.7, 0.7, 0.9) : set = set_default_color
var texture: Texture2D = null : set = set_texture

## How to draw the texture along the line.
enum TextureMode {
	NONE,
	TILE,
	STRETCH,
}
var texture_mode: TextureMode = TextureMode.NONE : set = set_texture_mode

# --- Dash pattern ---
enum DashStyle {
	SOLID,
	DASHED,
	DOTTED,
	DASH_DOT,
}
var dash_style: DashStyle = DashStyle.SOLID : set = set_dash_style
var dash_length: float = 12.0 : set = set_dash_length
var dash_gap: float = 6.0 : set = set_dash_gap

# --- Rendering options ---
## Round the joints (adds small circles at each point).
var round_joints: bool = false : set = set_round_joints
## Round the endpoints (adds small circles at start and end).
var round_caps: bool = false : set = set_round_caps

# --- Cache ---
var _cached_segments: Array = []
var _cache_dirty: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# ============================================================
# SETTERS
# ============================================================

func set_points(new_points: PackedVector2Array) -> void:
	points = new_points
	_invalidate_cache()


func set_width(new_width: float) -> void:
	width = max(0.0, new_width)
	_invalidate_cache()


func set_default_color(new_color: Color) -> void:
	default_color = new_color
	queue_redraw()


func set_texture(new_texture: Texture2D) -> void:
	texture = new_texture
	_invalidate_cache()


func set_texture_mode(new_mode: TextureMode) -> void:
	texture_mode = new_mode
	_invalidate_cache()


func set_dash_style(new_style: DashStyle) -> void:
	dash_style = new_style
	_invalidate_cache()


func set_dash_length(new_length: float) -> void:
	dash_length = max(1.0, new_length)
	_invalidate_cache()


func set_dash_gap(new_gap: float) -> void:
	dash_gap = max(0.0, new_gap)
	_invalidate_cache()


func set_round_joints(value: bool) -> void:
	round_joints = value
	queue_redraw()


func set_round_caps(value: bool) -> void:
	round_caps = value
	queue_redraw()


# ============================================================
# PUBLIC HELPERS (Line2D-compatible API)
# ============================================================

func clear_points() -> void:
	points = PackedVector2Array()
	_invalidate_cache()


func add_point(p: Vector2) -> void:
	points.append(p)
	_invalidate_cache()


func get_point_count() -> int:
	return points.size()


func get_point_position(index: int) -> Vector2:
	if index < 0 or index >= points.size():
		return Vector2.ZERO
	return points[index]


# ============================================================
# DRAW
# ============================================================

func _draw() -> void:
	if points.size() < 2:
		return
	if width <= 0.0:
		return

	# --- 1. Compute the visual segments (accounting for dash pattern) ---
	var segments: Array = _get_draw_segments()

	# --- 2. Draw each segment ---
	for seg in segments:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		_draw_segment(a, b)

	# --- 3. Round joints / caps ---
	if round_joints or round_caps:
		_draw_caps(segments)


func _draw_segment(a: Vector2, b: Vector2) -> void:
	var seg_vec: Vector2 = b - a
	var seg_len: float = seg_vec.length()
	if seg_len < 0.001:
		return

	if texture_mode == TextureMode.NONE or texture == null:
		# Solid color line
		draw_line(a, b, default_color, width, true)
		return

	if texture_mode == TextureMode.STRETCH:
		# Stretch the whole texture across the segment
		_draw_textured_line_stretch(a, b, seg_len)
		return

	# TILE mode
	_draw_textured_line_tile(a, b, seg_len)


## Draw a textured line with the texture stretched once along the segment.
func _draw_textured_line_stretch(a: Vector2, b: Vector2, seg_len: float) -> void:
	var dir: Vector2 = (b - a) / seg_len
	var perp: Vector2 = Vector2(-dir.y, dir.x)

	var tex_size: Vector2 = texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	var half_w: float = width * 0.5

	# 4 corners of the quad
	var p0: Vector2 = a - perp * half_w
	var p1: Vector2 = b - perp * half_w
	var p2: Vector2 = b + perp * half_w
	var p3: Vector2 = a + perp * half_w

	var poly: PackedVector2Array = PackedVector2Array([p0, p1, p2, p3])
	var uvs: PackedVector2Array = PackedVector2Array([
		Vector2(0, 0),
		Vector2(1, 0),
		Vector2(1, 1),
		Vector2(0, 1),
	])
	var colors: PackedColorArray = PackedColorArray([
		default_color, default_color, default_color, default_color
	])

	draw_polygon(poly, colors, uvs, texture)


## Draw a textured line where the texture tiles along the segment length.
func _draw_textured_line_tile(a: Vector2, b: Vector2, seg_len: float) -> void:
	var dir: Vector2 = (b - a) / seg_len
	var perp: Vector2 = Vector2(-dir.y, dir.x)

	var tex_size: Vector2 = texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	# How many texture pixels map to one world pixel along the line?
	# We want the texture to appear at its native scale (1:1) so a 32x6
	# texture drawn on a 4px thick line will show 4px of the texture's
	# height and tile horizontally at its native 32px interval.
	var tile_length: float = tex_size.x
	var half_w: float = width * 0.5

	var travelled: float = 0.0
	while travelled < seg_len:
		var tile_start: Vector2 = a + dir * travelled
		var this_tile: float = min(tile_length, seg_len - travelled)
		var tile_end: Vector2 = a + dir * (travelled + this_tile)

		var p0: Vector2 = tile_start - perp * half_w
		var p1: Vector2 = tile_end - perp * half_w
		var p2: Vector2 = tile_end + perp * half_w
		var p3: Vector2 = tile_start + perp * half_w

		# UVs: horizontal fraction = this_tile / tile_length,
		# vertical fraction = width / tex_size.y (crop or stretch).
		var u_frac: float = this_tile / tile_length
		var v_frac: float = width / tex_size.y

		var poly: PackedVector2Array = PackedVector2Array([p0, p1, p2, p3])
		var uvs: PackedVector2Array = PackedVector2Array([
			Vector2(0, 0),
			Vector2(u_frac, 0),
			Vector2(u_frac, v_frac),
			Vector2(0, v_frac),
		])
		var colors: PackedColorArray = PackedColorArray([
			default_color, default_color, default_color, default_color
		])

		draw_polygon(poly, colors, uvs, texture)

		travelled += this_tile


func _draw_caps(segments: Array) -> void:
	if segments.is_empty():
		return

	var radius: float = width * 0.5

	if round_joints:
		# Draw a filled circle at each intermediate joint
		for i in range(segments.size() - 1):
			var joint: Vector2 = segments[i][1]
			draw_circle(joint, radius, default_color)

	if round_caps:
		# Draw filled circles at the two endpoints of the whole line
		draw_circle(segments[0][0], radius, default_color)
		draw_circle(segments[segments.size() - 1][1], radius, default_color)


# ============================================================
# SEGMENT COMPUTATION (shape + dash)
# ============================================================

## Returns an Array of [Vector2, Vector2] pairs — each pair is a solid
## sub-segment that should be drawn (dash pattern already applied).
func _get_draw_segments() -> Array:
	if not _cache_dirty:
		return _cached_segments

	# 1. Base segments = each consecutive pair of points
	var base_segments: Array = []
	for i in range(points.size() - 1):
		base_segments.append([points[i], points[i + 1]])

	# 2. Apply dash pattern if needed
	var result: Array = []
	match dash_style:
		DashStyle.SOLID:
			result = base_segments
		DashStyle.DASHED:
			result = _apply_dash_pattern(base_segments, dash_length, dash_gap)
		DashStyle.DOTTED:
			var dot: float = max(1.0, dash_length * 0.25)
			result = _apply_dash_pattern(base_segments, dot, dash_gap)
		DashStyle.DASH_DOT:
			var long_len: float = dash_length
			var short_len: float = max(1.0, dash_length * 0.25)
			result = _apply_dash_dot_pattern(base_segments, long_len, short_len, dash_gap)
		_:
			result = base_segments

	_cached_segments = result
	_cache_dirty = false
	return result


func _invalidate_cache() -> void:
	_cache_dirty = true
	queue_redraw()


# ============================================================
# DASH PATTERN COMPUTATION
# ============================================================

## Splits base segments into dashes: on_length drawn, off_length skipped.
func _apply_dash_pattern(base_segments: Array, on_length: float, off_length: float) -> Array:
	var result: Array = []
	if on_length <= 0.1:
		return base_segments

	var pattern_cycle: float = on_length + off_length
	var distance: float = 0.0

	for seg in base_segments:
		var seg_start: Vector2 = seg[0]
		var seg_end: Vector2 = seg[1]
		var seg_vec: Vector2 = seg_end - seg_start
		var seg_len: float = seg_vec.length()

		if seg_len < 0.001:
			continue

		var seg_dir: Vector2 = seg_vec / seg_len
		var t: float = 0.0

		while t < seg_len:
			var phase: float = fposmod(distance + t, pattern_cycle)
			var remaining: float = seg_len - t

			if phase < on_length:
				var on_remaining: float = on_length - phase
				var drawn: float = min(remaining, on_remaining)
				result.append([
					seg_start + seg_dir * t,
					seg_start + seg_dir * (t + drawn),
				])
				t += drawn
			else:
				var off_remaining: float = pattern_cycle - phase
				t += min(remaining, off_remaining)

		distance += seg_len

	return result


## Splits base segments into dash-dot pattern:
## long, gap, short, gap, repeat.
func _apply_dash_dot_pattern(base_segments: Array, long_len: float, short_len: float, gap: float) -> Array:
	var result: Array = []
	var pattern_cycle: float = long_len + gap + short_len + gap
	var distance: float = 0.0

	for seg in base_segments:
		var seg_start: Vector2 = seg[0]
		var seg_end: Vector2 = seg[1]
		var seg_vec: Vector2 = seg_end - seg_start
		var seg_len: float = seg_vec.length()

		if seg_len < 0.001:
			continue

		var seg_dir: Vector2 = seg_vec / seg_len
		var t: float = 0.0

		while t < seg_len:
			var phase: float = fposmod(distance + t, pattern_cycle)
			var remaining: float = seg_len - t

			var on_remaining: float = 0.0

			if phase < long_len:
				on_remaining = long_len - phase
			elif phase < long_len + gap:
				var off1: float = (long_len + gap) - phase
				t += min(remaining, off1)
				continue
			elif phase < long_len + gap + short_len:
				on_remaining = (long_len + gap + short_len) - phase
			else:
				var off2: float = pattern_cycle - phase
				t += min(remaining, off2)
				continue

			var drawn: float = min(remaining, on_remaining)
			result.append([
				seg_start + seg_dir * t,
				seg_start + seg_dir * (t + drawn),
			])
			t += drawn

		distance += seg_len

	return result