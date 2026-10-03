@tool
class_name BayterekLine2D
extends Control
## Custom polyline renderer for Bayterek connections.

# ============================================================
# ENUMS
# ============================================================

enum TextureMode {
	NONE,
	TILE,
	STRETCH,
	TILE_FIT_HEIGHT,
}

enum DashStyle {
	SOLID,
	DASHED,
	DOTTED,
	DASH_DOT,
}

enum ArrowStyle {
	NONE,
	ARROW,
	T_BAR,
	SQUARE,
	CIRCLE,
	DIAMOND,
}

enum CapStyle {
	BUTT,
	ROUND,
	SQUARE,
}

enum WigglePattern {
	SINE,
	PERLIN,
	RANDOM_JITTER,
	TRIANGLE,
	BOUNCE,
}

enum WiggleDirectionMode {
	PERPENDICULAR,
	FOLLOW_NODE_MOTION,
	AXIS_LOCK,
}

# ============================================================
# CONSTANTS
# ============================================================

const STRAIGHT_SUBDIVISIONS := 16
const FREQ_STOP_THRESHOLD := 0.05
const FREQ_RESPONSIVENESS := 3.0
const INTENSITY_HARD_STOP := 0.001

# ============================================================
# GEOMETRY
# ============================================================

var points: PackedVector2Array = PackedVector2Array() : set = set_points
var width: float = 4.0 : set = set_width

# ============================================================
# VISUAL STYLE
# ============================================================

var default_color: Color = Color(0.7, 0.7, 0.7, 0.9) : set = set_default_color
var smooth_antialiasing: bool = true : set = set_smooth_antialiasing

var flat_mode: bool = false

var texture_filter_override: int = 0 :
	set(v):
		texture_filter_override = v
		_apply_texture_filter()
		queue_redraw()

# ============================================================
# TEXTURE
# ============================================================

var texture: Texture2D = null : set = set_texture
var texture_mode: TextureMode = TextureMode.NONE : set = set_texture_mode
var texture_scale: Vector2 = Vector2.ONE : set = set_texture_scale
var texture_tint: Color = Color.WHITE : set = set_texture_tint

# ============================================================
# DASH PATTERN
# ============================================================

var dash_style: DashStyle = DashStyle.SOLID : set = set_dash_style
var dash_length: float = 12.0 : set = set_dash_length
var dash_gap: float = 6.0 : set = set_dash_gap
var dash_offset: float = 0.0 : set = set_dash_offset

# ============================================================
# CAPS AND JOINTS
# ============================================================

var cap_start: CapStyle = CapStyle.BUTT : set = set_cap_start
var cap_end: CapStyle = CapStyle.BUTT : set = set_cap_end
var round_joints: bool = false : set = set_round_joints

# ============================================================
# ARROWS
# ============================================================

var start_arrow: ArrowStyle = ArrowStyle.NONE : set = set_start_arrow
var end_arrow: ArrowStyle = ArrowStyle.NONE : set = set_end_arrow
var arrow_size: float = 12.0 : set = set_arrow_size
var arrow_texture_start: Texture2D = null : set = set_arrow_texture_start
var arrow_texture_end: Texture2D = null : set = set_arrow_texture_end
var arrow_scale: Vector2 = Vector2.ONE : set = set_arrow_scale
var arrow_tint: Color = Color.WHITE : set = set_arrow_tint
var arrow_offset_x: float = 0.0 : set = set_arrow_offset_x

# ============================================================
# WIGGLE
# ============================================================

var wiggle_enabled: bool = false
var wiggle_base_amplitude: float = 2.0
var wiggle_frequency: float = 2.0
var wiggle_speed: float = 1.0
var wiggle_phase_offset: float = 0.0
var wiggle_pattern: WigglePattern = WigglePattern.SINE
var wiggle_random_seed: int = 0
var wiggle_intensity: float = 0.0
var wiggle_active_boost: float = 1.5
var wiggle_target_is_active: bool = false

var wiggle_direction_mode: WiggleDirectionMode = WiggleDirectionMode.PERPENDICULAR
var wiggle_source_velocity: Vector2 = Vector2.ZERO

var _effective_frequency: float = 0.0
var _wiggle_clock: float = 0.0
var _jitter_value: float = 0.0
var _jitter_refresh_timer: float = 0.0
const JITTER_REFRESH_INTERVAL := 0.05

# ============================================================
# CACHE
# ============================================================

var _cached_segments: Array = []
var _cache_dirty: bool = true

# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_texture_filter()
	set_process(false)
	_seed_from_instance_if_needed()


func _process(delta: float) -> void:
	var target_freq: float = wiggle_frequency * wiggle_intensity

	if target_freq < FREQ_STOP_THRESHOLD:
		_effective_frequency = 0.0
		set_process(false)
		_invalidate_cache()
		return

	var lerp_factor: float = 1.0 - exp(-FREQ_RESPONSIVENESS * delta)
	_effective_frequency = lerpf(_effective_frequency, target_freq, lerp_factor)

	if _effective_frequency < FREQ_STOP_THRESHOLD:
		_effective_frequency = 0.0
		set_process(false)
		_invalidate_cache()
		return

	_wiggle_clock += delta * wiggle_speed * _effective_frequency

	if wiggle_pattern == WigglePattern.RANDOM_JITTER:
		_jitter_refresh_timer -= delta
		if _jitter_refresh_timer <= 0.0:
			_jitter_refresh_timer = JITTER_REFRESH_INTERVAL
			_jitter_value = randf() * 2.0 - 1.0

	queue_redraw()


func _seed_from_instance_if_needed() -> void:
	if wiggle_random_seed == 0:
		wiggle_random_seed = int(get_instance_id()) & 0x7FFFFFFF
	_jitter_value = _pseudo_rand(-1.0, 1.0, float(wiggle_random_seed))

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

func set_smooth_antialiasing(v: bool) -> void:
	smooth_antialiasing = v
	queue_redraw()

func set_texture(new_texture: Texture2D) -> void:
	texture = new_texture
	_invalidate_cache()

func set_texture_mode(new_mode: TextureMode) -> void:
	texture_mode = new_mode
	_invalidate_cache()

func set_texture_scale(s: Vector2) -> void:
	texture_scale = s
	_invalidate_cache()

func set_texture_tint(c: Color) -> void:
	texture_tint = c
	queue_redraw()

func set_dash_style(new_style: DashStyle) -> void:
	dash_style = new_style
	_invalidate_cache()

func set_dash_length(new_length: float) -> void:
	dash_length = max(1.0, new_length)
	_invalidate_cache()

func set_dash_gap(new_gap: float) -> void:
	dash_gap = max(0.0, new_gap)
	_invalidate_cache()

func set_dash_offset(v: float) -> void:
	dash_offset = v
	_invalidate_cache()

func set_cap_start(v: CapStyle) -> void:
	cap_start = v
	queue_redraw()

func set_cap_end(v: CapStyle) -> void:
	cap_end = v
	queue_redraw()

func set_round_joints(v: bool) -> void:
	round_joints = v
	queue_redraw()

func set_start_arrow(new_style: ArrowStyle) -> void:
	start_arrow = new_style
	queue_redraw()

func set_end_arrow(new_style: ArrowStyle) -> void:
	end_arrow = new_style
	queue_redraw()

func set_arrow_size(new_size: float) -> void:
	arrow_size = max(1.0, new_size)
	queue_redraw()

func set_arrow_texture_start(t: Texture2D) -> void:
	arrow_texture_start = t
	queue_redraw()

func set_arrow_texture_end(t: Texture2D) -> void:
	arrow_texture_end = t
	queue_redraw()

func set_arrow_scale(s: Vector2) -> void:
	arrow_scale = s
	queue_redraw()

func set_arrow_tint(c: Color) -> void:
	arrow_tint = c
	queue_redraw()

func set_arrow_offset_x(v: float) -> void:
	arrow_offset_x = v
	queue_redraw()

# ============================================================
# TEXTURE FILTER
# ============================================================

func _apply_texture_filter() -> void:
	match texture_filter_override:
		1:
			texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		2:
			texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_:
			texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE

# ============================================================
# WIGGLE SETTERS
# ============================================================

func set_wiggle_enabled(enabled: bool) -> void:
	if wiggle_enabled == enabled:
		if enabled and not is_processing() and wiggle_intensity > INTENSITY_HARD_STOP:
			set_process(true)
		return

	wiggle_enabled = enabled
	_invalidate_cache()

	if enabled:
		set_process(true)


func set_wiggle_intensity(intensity: float, target_is_active: bool) -> void:
	var new_intensity: float = maxf(0.0, intensity)

	if new_intensity < INTENSITY_HARD_STOP:
		var was_wiggling: bool = wiggle_intensity > INTENSITY_HARD_STOP or _effective_frequency > 0.0

		wiggle_intensity = 0.0
		wiggle_target_is_active = target_is_active

		if was_wiggling:
			_effective_frequency = 0.0
			set_process(false)
			_invalidate_cache()

		return

	if is_equal_approx(new_intensity, wiggle_intensity) and target_is_active == wiggle_target_is_active:
		return

	wiggle_intensity = new_intensity
	wiggle_target_is_active = target_is_active

	if wiggle_enabled and wiggle_intensity > INTENSITY_HARD_STOP:
		if not is_processing():
			set_process(true)

	if wiggle_enabled:
		queue_redraw()


func set_wiggle_source_velocity(velocity: Vector2) -> void:
	wiggle_source_velocity = velocity

# ============================================================
# PUBLIC HELPERS
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

	var segments: Array = _get_draw_segments()

	for seg in segments:
		_draw_segment(seg[0], seg[1])

	if round_joints:
		_draw_round_joints(segments)

	_draw_caps(segments)
	_draw_arrows(segments)


func _draw_segment(a: Vector2, b: Vector2) -> void:
	var seg_vec: Vector2 = b - a
	var seg_len: float = seg_vec.length()
	if seg_len < 0.001:
		return

	if texture_mode == TextureMode.NONE or texture == null:
		if flat_mode:
			_draw_flat_line(a, b, seg_len)
		else:
			draw_line(a, b, default_color, width, smooth_antialiasing)
		return

	match texture_mode:
		TextureMode.STRETCH:
			_draw_textured_stretch(a, b, seg_len)
		TextureMode.TILE:
			_draw_textured_tile(a, b, seg_len, false)
		TextureMode.TILE_FIT_HEIGHT:
			_draw_textured_tile(a, b, seg_len, true)


func _draw_flat_line(a: Vector2, b: Vector2, seg_len: float) -> void:
	if seg_len < 0.001:
		return
	var dir: Vector2 = (b - a) / seg_len
	var perp: Vector2 = Vector2(-dir.y, dir.x) * (width * 0.5)

	draw_colored_polygon(
		PackedVector2Array([a - perp, b - perp, b + perp, a + perp]),
		default_color
	)


func _draw_textured_stretch(a: Vector2, b: Vector2, seg_len: float) -> void:
	if seg_len < 0.001:
		return
	var dir: Vector2 = (b - a) / seg_len
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var tex_size: Vector2 = texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	var half_w: float = width * 0.5
	var p0: Vector2 = a - perp * half_w
	var p1: Vector2 = b - perp * half_w
	var p2: Vector2 = b + perp * half_w
	var p3: Vector2 = a + perp * half_w

	var poly := PackedVector2Array([p0, p1, p2, p3])
	var uvs := PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1),
	])
	var colors := PackedColorArray([texture_tint, texture_tint, texture_tint, texture_tint])
	draw_polygon(poly, colors, uvs, texture)


func _draw_textured_tile(a: Vector2, b: Vector2, seg_len: float, fit_height: bool) -> void:
	if seg_len < 0.001:
		return
	var dir: Vector2 = (b - a) / seg_len
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var tex_size: Vector2 = texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	var tile_length: float = tex_size.x * texture_scale.x
	if tile_length < 1.0:
		tile_length = 1.0

	var half_w: float = width * 0.5
	var travelled: float = 0.0

	var v0: float = 0.0
	var v1: float = 1.0
	if not fit_height:
		var span: float = width / tex_size.y
		v0 = 0.5 - span * 0.5
		v1 = 0.5 + span * 0.5

	while travelled < seg_len:
		var this_tile: float = min(tile_length, seg_len - travelled)
		var tile_start: Vector2 = a + dir * travelled
		var tile_end: Vector2 = a + dir * (travelled + this_tile)

		var p0: Vector2 = tile_start - perp * half_w
		var p1: Vector2 = tile_end - perp * half_w
		var p2: Vector2 = tile_end + perp * half_w
		var p3: Vector2 = tile_start + perp * half_w

		var u_frac: float = this_tile / tile_length

		var poly := PackedVector2Array([p0, p1, p2, p3])
		var uvs := PackedVector2Array([
			Vector2(0.0, v0),
			Vector2(u_frac, v0),
			Vector2(u_frac, v1),
			Vector2(0.0, v1),
		])
		var colors := PackedColorArray([texture_tint, texture_tint, texture_tint, texture_tint])
		draw_polygon(poly, colors, uvs, texture)

		travelled += this_tile


func _draw_round_joints(segments: Array) -> void:
	if segments.size() < 2:
		return
	var radius: float = width * 0.5
	for i in range(segments.size() - 1):
		var joint: Vector2 = segments[i][1]
		draw_circle(joint, radius, default_color)

func _draw_caps(segments: Array) -> void:
	if segments.is_empty():
		return

	var radius: float = width * 0.5

	match cap_start:
		CapStyle.ROUND:
			var p0: Vector2 = segments[0][0]
			draw_circle(p0, radius, default_color)
		CapStyle.SQUARE:
			var a0: Vector2 = segments[0][0]
			var b0: Vector2 = segments[0][1]
			var dir0: Vector2 = (b0 - a0)
			if dir0.length() > 0.001:
				dir0 = dir0.normalized()
				var ext: Vector2 = a0 - dir0 * radius
				var perp: Vector2 = Vector2(-dir0.y, dir0.x) * radius
				draw_colored_polygon(
					PackedVector2Array([a0 - perp, a0 + perp, ext + perp, ext - perp]),
					default_color
				)
		_:
			pass

	match cap_end:
		CapStyle.ROUND:
			var p1: Vector2 = segments[segments.size() - 1][1]
			draw_circle(p1, radius, default_color)
		CapStyle.SQUARE:
			var last_seg: Array = segments[segments.size() - 1]
			var a1: Vector2 = last_seg[0]
			var b1: Vector2 = last_seg[1]
			var dir1: Vector2 = (b1 - a1)
			if dir1.length() > 0.001:
				dir1 = dir1.normalized()
				var ext2: Vector2 = b1 + dir1 * radius
				var perp2: Vector2 = Vector2(-dir1.y, dir1.x) * radius
				draw_colored_polygon(
					PackedVector2Array([b1 - perp2, b1 + perp2, ext2 + perp2, ext2 - perp2]),
					default_color
				)
		_:
			pass


func _draw_arrows(segments: Array) -> void:
	if segments.is_empty():
		return

	var first_seg: Array = segments[0]
	var last_seg: Array = segments[segments.size() - 1]

	if start_arrow != ArrowStyle.NONE or arrow_texture_start != null:
		var dir: Vector2 = first_seg[1] - first_seg[0]
		if dir.length() > 0.001:
			var tip: Vector2 = first_seg[0]
			var outward: Vector2 = -dir.normalized()
			_draw_arrow_endpoint(tip, outward, start_arrow, arrow_texture_start)

	if end_arrow != ArrowStyle.NONE or arrow_texture_end != null:
		var dir2: Vector2 = last_seg[1] - last_seg[0]
		if dir2.length() > 0.001:
			var tip2: Vector2 = last_seg[1]
			var outward2: Vector2 = dir2.normalized()
			_draw_arrow_endpoint(tip2, outward2, end_arrow, arrow_texture_end)


func _draw_arrow_endpoint(tip: Vector2, outward: Vector2, style: ArrowStyle, arrow_tex: Texture2D) -> void:
	var offset_tip: Vector2 = tip + outward * arrow_offset_x

	if arrow_tex != null:
		_draw_arrow_texture(offset_tip, outward, arrow_tex)
		return

	_draw_arrow_shape(offset_tip, outward, style)


func _draw_arrow_texture(tip: Vector2, outward: Vector2, tex: Texture2D) -> void:
	var tex_size: Vector2 = tex.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	var angle: float = atan2(outward.y, outward.x)

	var scaled_size: Vector2 = Vector2(
		tex_size.x * arrow_scale.x,
		tex_size.y * arrow_scale.y
	)

	var center_local: Vector2 = Vector2(scaled_size.x * 0.5, 0.0)
	var rotated_offset: Vector2 = center_local.rotated(angle)
	var center: Vector2 = tip + rotated_offset

	var xform := Transform2D(angle, center)
	xform = xform.scaled(Vector2(arrow_scale.x, arrow_scale.y))

	draw_set_transform_matrix(xform)
	var rect := Rect2(-tex_size * 0.5, tex_size)
	draw_texture_rect(tex, rect, false, arrow_tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_arrow_shape(tip: Vector2, outward: Vector2, style: ArrowStyle) -> void:
	var size: float = arrow_size
	var perp: Vector2 = Vector2(-outward.y, outward.x)

	match style:
		ArrowStyle.ARROW:
			var apex: Vector2 = tip + outward * size
			var left: Vector2 = tip + perp * (size * 0.5)
			var right: Vector2 = tip - perp * (size * 0.5)
			draw_colored_polygon(PackedVector2Array([apex, left, right]), default_color)

		ArrowStyle.T_BAR:
			# Length runs along `perp`, thickness runs along `outward`.
			#
			# Thickness is FIXED at size * 0.35 — it must NOT scale with
			# the line width, otherwise a thick line produces a giant
			# T_BAR that dwarfs the whole arrow.
			var half_len: float = size * 0.6
			var thickness: float = max(2.0, size * 0.35)
			var half_th: float = thickness * 0.5

			var along_outward: Vector2 = outward * half_th

			var left_end: Vector2 = tip + perp * half_len
			var right_end: Vector2 = tip - perp * half_len

			var p0: Vector2 = left_end + along_outward
			var p1: Vector2 = right_end + along_outward
			var p2: Vector2 = right_end - along_outward
			var p3: Vector2 = left_end - along_outward

			draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3]), default_color)

		ArrowStyle.SQUARE:
			var half_s: float = size * 0.5
			var back: Vector2 = tip - outward * half_s
			var front: Vector2 = tip + outward * half_s
			var top_back: Vector2 = back + perp * half_s
			var bot_back: Vector2 = back - perp * half_s
			var top_front: Vector2 = front + perp * half_s
			var bot_front: Vector2 = front - perp * half_s
			draw_colored_polygon(
				PackedVector2Array([top_back, top_front, bot_front, bot_back]),
				default_color
			)

		ArrowStyle.CIRCLE:
			draw_circle(tip, size * 0.5, default_color)

		ArrowStyle.DIAMOND:
			var d_size: float = size * 0.65
			var apex: Vector2 = tip + outward * d_size
			var back_pt: Vector2 = tip - outward * d_size
			var left: Vector2 = tip + perp * d_size
			var right: Vector2 = tip - perp * d_size
			draw_colored_polygon(
				PackedVector2Array([apex, left, back_pt, right]),
				default_color
			)

# ============================================================
# SEGMENT COMPUTATION
# ============================================================

func _get_draw_segments() -> Array:
	if not _cache_dirty:
		return _cached_segments

	if not wiggle_enabled:
		var raw_segments: Array = []
		for i in range(points.size() - 1):
			raw_segments.append([points[i], points[i + 1]])
		var raw_result: Array = _apply_dash_style(raw_segments)
		_cached_segments = raw_result
		_cache_dirty = false
		return raw_result

	var working_points: PackedVector2Array = points

	var wiggle_wants_geometry: bool = _effective_frequency > FREQ_STOP_THRESHOLD

	if wiggle_wants_geometry and working_points.size() == 2 and STRAIGHT_SUBDIVISIONS > 1:
		working_points = _subdivide_polyline(working_points, STRAIGHT_SUBDIVISIONS)

	if wiggle_wants_geometry and working_points.size() >= 3:
		working_points = _apply_wiggle(working_points)

	var base_segments: Array = []
	for i in range(working_points.size() - 1):
		base_segments.append([working_points[i], working_points[i + 1]])

	var result: Array = _apply_dash_style(base_segments)

	if not wiggle_wants_geometry:
		_cached_segments = result
		_cache_dirty = false

	return result


func _apply_dash_style(base_segments: Array) -> Array:
	match dash_style:
		DashStyle.SOLID:
			return base_segments
		DashStyle.DASHED:
			return _apply_dash_pattern(base_segments, dash_length, dash_gap)
		DashStyle.DOTTED:
			var dot: float = max(1.0, dash_length * 0.25)
			return _apply_dash_pattern(base_segments, dot, dash_gap)
		DashStyle.DASH_DOT:
			var long_len: float = dash_length
			var short_len: float = max(1.0, dash_length * 0.25)
			return _apply_dash_dot_pattern(base_segments, long_len, short_len, dash_gap)
		_:
			return base_segments


func _invalidate_cache() -> void:
	_cache_dirty = true
	queue_redraw()

# ------------------------------------------------------------
# SUBDIVISION
# ------------------------------------------------------------

func _subdivide_polyline(src: PackedVector2Array, subdivisions: int) -> PackedVector2Array:
	if src.size() < 2 or subdivisions < 2:
		return src

	var out := PackedVector2Array()
	var n: int = src.size()

	for i in range(n - 1):
		var a: Vector2 = src[i]
		var b: Vector2 = src[i + 1]

		if i == 0:
			out.append(a)

		for j in range(1, subdivisions + 1):
			var t: float = float(j) / float(subdivisions)
			out.append(a.lerp(b, t))

	return out

# ------------------------------------------------------------
# WIGGLE GEOMETRY
# ------------------------------------------------------------

func _apply_wiggle(src: PackedVector2Array) -> PackedVector2Array:
	var n: int = src.size()
	if n < 3:
		return src

	var result := PackedVector2Array()
	result.resize(n)

	result[0] = src[0]
	result[n - 1] = src[n - 1]

	var amp: float = wiggle_base_amplitude * wiggle_intensity
	if wiggle_target_is_active:
		amp *= wiggle_active_boost
	if amp <= 0.0001:
		return src

	var clock: float = _wiggle_clock

	var motion_dir: Vector2 = wiggle_source_velocity
	var motion_len: float = motion_dir.length()

	var follow_dir: Vector2 = Vector2.ZERO
	if motion_len > 0.0001:
		follow_dir = motion_dir / motion_len

	var axis_lock_dir: Vector2 = Vector2.ZERO
	var axis_lock_valid: bool = false
	if motion_len > 0.0001:
		if absf(motion_dir.x) > absf(motion_dir.y):
			axis_lock_dir = Vector2(signf(motion_dir.x), 0.0)
		else:
			axis_lock_dir = Vector2(0.0, signf(motion_dir.y))
		axis_lock_valid = true

	for i in range(1, n - 1):
		var prev: Vector2 = src[i - 1]
		var next: Vector2 = src[i + 1]
		var dir: Vector2 = next - prev
		var dir_len: float = dir.length()

		if dir_len < 0.0001:
			result[i] = src[i]
			continue

		var perp_local: Vector2 = Vector2(-dir.y, dir.x) / dir_len

		var perp: Vector2
		match wiggle_direction_mode:
			WiggleDirectionMode.FOLLOW_NODE_MOTION:
				if follow_dir != Vector2.ZERO:
					perp = follow_dir
				else:
					perp = perp_local
			WiggleDirectionMode.AXIS_LOCK:
				if axis_lock_valid:
					perp = axis_lock_dir
				else:
					perp = perp_local
			_:
				perp = perp_local

		var t: float = float(i) / float(n - 1)
		var taper: float = sin(PI * t)
		var wave: float = _evaluate_waveform(i, t, clock)

		result[i] = src[i] + perp * amp * wave * taper

	return result


func _evaluate_waveform(i: int, t: float, clock: float) -> float:
	var phase: float = wiggle_phase_offset

	match wiggle_pattern:
		WigglePattern.SINE:
			return sin(clock * TAU + phase + t * 1.5)

		WigglePattern.PERLIN:
			var sample: float = _perlin_1d(t * 2.0 + clock + phase)
			return sample * 2.0 - 1.0

		WigglePattern.RANDOM_JITTER:
			var per_point: float = _pseudo_rand(-0.3, 0.3, float(wiggle_random_seed + i * 17))
			return clampf(_jitter_value + per_point, -1.0, 1.0)

		WigglePattern.TRIANGLE:
			var p: float = fposmod(clock + phase + t * 1.5, 1.0)
			return absf(p * 2.0 - 1.0) * 2.0 - 1.0

		WigglePattern.BOUNCE:
			var cycle_pos: float = fposmod(clock + phase * 0.3, 1.0)
			var env: float = _ease_out_bounce(cycle_pos)
			var carrier: float = sin(clock * TAU + phase + t * 1.5)
			return carrier * env

	return 0.0


func _ease_out_bounce(x: float) -> float:
	var n1: float = 7.5625
	var d1: float = 2.75
	var v: float = x
	if v < 1.0 / d1:
		return 1.0 - (n1 * v * v)
	elif v < 2.0 / d1:
		v -= 1.5 / d1
		return 1.0 - (n1 * v * v + 0.75)
	elif v < 2.5 / d1:
		v -= 2.25 / d1
		return 1.0 - (n1 * v * v + 0.9375)
	else:
		v -= 2.625 / d1
		return 1.0 - (n1 * v * v + 0.984375)


func _perlin_1d(x: float) -> float:
	var v: float = 0.0
	v += sin(x * 1.0 + wiggle_random_seed * 0.001) * 0.5
	v += sin(x * 2.3 + wiggle_random_seed * 0.002) * 0.25
	v += sin(x * 4.7 + wiggle_random_seed * 0.003) * 0.125
	v += sin(x * 9.1 + wiggle_random_seed * 0.005) * 0.0625
	return clampf(v * 0.5 + 0.5, 0.0, 1.0)


func _pseudo_rand(lo: float, hi: float, seed_val: float) -> float:
	var n: float = sin(seed_val * 12.9898) * 43758.5453
	n = n - floor(n)
	return lo + (hi - lo) * n

# ------------------------------------------------------------
# DASH PATTERN
# ------------------------------------------------------------

func _apply_dash_pattern(base_segments: Array, on_length: float, off_length: float) -> Array:
	var result: Array = []
	if on_length <= 0.1:
		return base_segments

	var pattern_cycle: float = on_length + off_length
	var distance: float = dash_offset

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


func _apply_dash_dot_pattern(base_segments: Array, long_len: float, short_len: float, gap: float) -> Array:
	var result: Array = []
	var pattern_cycle: float = long_len + gap + short_len + gap
	var distance: float = dash_offset

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