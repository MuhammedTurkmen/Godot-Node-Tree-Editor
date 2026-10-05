@tool
class_name BayterekLineData
extends Resource
## Bir bağlantının görsel verisi.

enum LineType {
	STRAIGHT,
	BEZIER,
	ARC,
	STEP,
}

enum LineStyle {
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

enum TextureMode {
	NONE,
	TILE,
	STRETCH,
	TILE_FIT_HEIGHT,
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

## Where the connection line terminates relative to the arrow.
##
##   EDGE   — line stops at the arrow's line-facing edge (middle of that edge).
##   CENTER — line runs all the way to the arrow's center.
enum ArrowAnchor {
	EDGE,
	CENTER,
}

## Per-line texture filter override.
##   0 = Inherit (use tree's filter)
##   1 = Linear (smooth)
##   2 = Nearest (pixel art)
const TEXTURE_FILTER_INHERIT := 0
const TEXTURE_FILTER_LINEAR := 1
const TEXTURE_FILTER_NEAREST := 2

## Base pixel size used for VECTOR arrows at scale = 1.0.
## Texture arrows ignore this and use the texture's own size.
const VECTOR_ARROW_BASE_SIZE := 16.0

# ============================================================
# GEOMETRY
# ============================================================

@export var line_type: LineType = LineType.STRAIGHT
@export var line_style: LineStyle = LineStyle.SOLID
@export var curve_height: float = 48.0
@export var segments: int = 16
@export var reversed: bool = false

@export var step_distance: float = 48.0
@export var dash_length: float = 12.0
@export var dash_gap: float = 6.0
@export var dash_offset: float = 0.0

# ============================================================
# ENDPOINT DECORATIONS
# ============================================================

@export var start_arrow: ArrowStyle = ArrowStyle.NONE
@export var end_arrow: ArrowStyle = ArrowStyle.NONE

@export var start_offset: float = 0.0
@export var end_offset: float = 0.0

@export var start_arrow_anchor: ArrowAnchor = ArrowAnchor.EDGE
@export var end_arrow_anchor: ArrowAnchor = ArrowAnchor.EDGE

# ============================================================
# VISUAL STYLE
# ============================================================

@export var color: Color = Color(0.7, 0.7, 0.7, 0.9)
@export var thickness: float = 4.0
@export var smooth_antialiasing: bool = true
@export var flat_mode: bool = false

@export var texture_filter_override: int = TEXTURE_FILTER_INHERIT
@export var arrow_texture_filter_override: int = TEXTURE_FILTER_INHERIT

# ============================================================
# LINE TEXTURE
# ============================================================

@export var texture_mode: TextureMode = TextureMode.NONE
@export var line_texture: Texture2D = null
@export var texture_scale: Vector2 = Vector2.ONE
@export var texture_tint: Color = Color.WHITE

# ============================================================
# ARROW — START
# ============================================================
#
# Per-side configuration. START and END arrows are fully independent:
#   - different textures
#   - different uniform scales
#   - different distances from the node edge
#   - different anchor modes
#   - different flip flags
#
# ROTATION RULE (both sides):
#   The arrow ALWAYS points AT the node it is attached to.
#   - START arrow sits next to the source node → tip points at the source.
#   - END arrow sits next to the target node  → tip points at the target.
#
# POSITION RULE:
#   `arrow_distance` is the gap between the NODE EDGE and the arrow's
#   NODE-FACING edge. 0 = arrow sits flush against the node.

@export var arrow_texture_start: Texture2D = null

## Uniform scale for the START arrow (both X and Y).
@export var start_arrow_scale: float = 1.0

## Gap between the source NODE EDGE and the START arrow's NODE-facing
## edge, in pixels.
@export var start_arrow_distance: float = 0.0

## Flip the START arrow 180°.
@export var start_arrow_flip: bool = false

@export var start_arrow_tint: Color = Color.WHITE

# ============================================================
# ARROW — END
# ============================================================

@export var arrow_texture_end: Texture2D = null

## Uniform scale for the END arrow (both X and Y).
@export var end_arrow_scale: float = 1.0

## Gap between the target NODE EDGE and the END arrow's NODE-facing
## edge, in pixels.
@export var end_arrow_distance: float = 0.0

## Flip the END arrow 180°.
@export var end_arrow_flip: bool = false

@export var end_arrow_tint: Color = Color.WHITE

# ============================================================
# CAP STYLE
# ============================================================

@export var cap_start: CapStyle = CapStyle.BUTT
@export var cap_end: CapStyle = CapStyle.BUTT

# ============================================================
# WIGGLE
# ============================================================

@export var wiggle_enabled: bool = false
@export var wiggle_base_amplitude: float = 2.0
@export var wiggle_frequency: float = 2.0
@export var wiggle_speed: float = 1.0
@export var wiggle_phase_offset: float = 0.0
@export var wiggle_pattern: WigglePattern = WigglePattern.SINE
@export var wiggle_random_seed: int = 0
@export var wiggle_use_hover_intensity: bool = true
@export var wiggle_active_boost: float = 1.5

@export var wiggle_direction_mode: WiggleDirectionMode = WiggleDirectionMode.PERPENDICULAR

# ============================================================
# PER-FIELD OVERRIDE TRACKING
# ============================================================

@export_storage var overridden_fields: Dictionary = {}

func is_overridden(field_name: String) -> bool:
	return overridden_fields.has(field_name)

func set_overridden(field_name: String, overridden: bool) -> void:
	if overridden:
		overridden_fields[field_name] = true
	else:
		overridden_fields.erase(field_name)

func clear_all_overrides() -> void:
	overridden_fields.clear()

func get_overridden_fields() -> Array:
	return overridden_fields.keys()

# ============================================================
# ARROW GEOMETRY HELPERS
# ============================================================

func get_start_arrow_extent(_dir: Vector2) -> float:
	if not _has_start_arrow():
		return 0.0
	if arrow_texture_start != null:
		var tex_size: Vector2 = arrow_texture_start.get_size()
		return tex_size.x * start_arrow_scale
	return VECTOR_ARROW_BASE_SIZE * start_arrow_scale


func get_end_arrow_extent(_dir: Vector2) -> float:
	if not _has_end_arrow():
		return 0.0
	if arrow_texture_end != null:
		var tex_size: Vector2 = arrow_texture_end.get_size()
		return tex_size.x * end_arrow_scale
	return VECTOR_ARROW_BASE_SIZE * end_arrow_scale


func get_start_arrow_lateral_size() -> float:
	if not _has_start_arrow():
		return 0.0
	if arrow_texture_start != null:
		var tex_size: Vector2 = arrow_texture_start.get_size()
		return tex_size.y * start_arrow_scale
	return VECTOR_ARROW_BASE_SIZE * start_arrow_scale


func get_end_arrow_lateral_size() -> float:
	if not _has_end_arrow():
		return 0.0
	if arrow_texture_end != null:
		var tex_size: Vector2 = arrow_texture_end.get_size()
		return tex_size.y * end_arrow_scale
	return VECTOR_ARROW_BASE_SIZE * end_arrow_scale


## Distance from the source NODE EDGE to where the LINE stops.
## Stops at the arrow's line-facing edge (EDGE anchor) or its center
## (CENTER anchor).
func get_start_arrow_line_stop() -> float:
	if not _has_start_arrow():
		return 0.0

	var extent: float = get_start_arrow_extent(Vector2.RIGHT)

	match start_arrow_anchor:
		ArrowAnchor.CENTER:
			return start_arrow_distance + extent * 0.5
		_:
			return start_arrow_distance + extent


## Same as above but for the END arrow.
func get_end_arrow_line_stop() -> float:
	if not _has_end_arrow():
		return 0.0

	var extent: float = get_end_arrow_extent(Vector2.RIGHT)

	match end_arrow_anchor:
		ArrowAnchor.CENTER:
			return end_arrow_distance + extent * 0.5
		_:
			return end_arrow_distance + extent


## World-space center of the START arrow.
##
## `node_edge`   = point on the SOURCE node's boundary facing the target.
## `outward_dir` = direction from the SOURCE node toward the target.
##
## The arrow's NODE-facing edge sits at `node_edge + outward_dir * distance`.
## Its center is `extent/2` further along `outward_dir`.
func get_start_arrow_center(node_edge: Vector2, outward_dir: Vector2) -> Vector2:
	if not _has_start_arrow():
		return node_edge
	var extent: float = get_start_arrow_extent(outward_dir)
	var center_dist: float = start_arrow_distance + extent * 0.5
	return node_edge + outward_dir * center_dist


## World-space center of the END arrow.
##
## `node_edge`   = point on the TARGET node's boundary facing the source.
## `outward_dir` = direction from the TARGET node toward the source.
func get_end_arrow_center(node_edge: Vector2, outward_dir: Vector2) -> Vector2:
	if not _has_end_arrow():
		return node_edge
	var extent: float = get_end_arrow_extent(outward_dir)
	var center_dist: float = end_arrow_distance + extent * 0.5
	return node_edge + outward_dir * center_dist


## Rotation angle (radians) for the START arrow.
##
## The START arrow sits between the source node and the line. Its tip
## MUST point AT the source node, which means pointing OPPOSITE to
## `line_dir` (since `line_dir` goes from source → target).
func get_start_arrow_angle(line_dir: Vector2) -> float:
	var a: float = (-line_dir).angle()
	if start_arrow_flip:
		a += PI
	return a


## Rotation angle (radians) for the END arrow.
##
## The END arrow sits between the target node and the line. Its tip
## MUST point AT the target node, which also means pointing OPPOSITE
## to `line_dir` (since `line_dir` goes from source → target).
func get_end_arrow_angle(line_dir: Vector2) -> float:
	var a: float = (-line_dir).angle()
	if end_arrow_flip:
		a += PI
	return a


func _has_start_arrow() -> bool:
	return start_arrow != ArrowStyle.NONE or arrow_texture_start != null


func _has_end_arrow() -> bool:
	return end_arrow != ArrowStyle.NONE or arrow_texture_end != null


# ============================================================
# HELPERS
# ============================================================

func duplicate_line_data() -> BayterekLineData:
	var copy := BayterekLineData.new()
	copy.line_type = line_type
	copy.line_style = line_style
	copy.curve_height = curve_height
	copy.segments = segments
	copy.reversed = reversed
	copy.step_distance = step_distance
	copy.dash_length = dash_length
	copy.dash_gap = dash_gap
	copy.dash_offset = dash_offset
	copy.start_arrow = start_arrow
	copy.end_arrow = end_arrow
	copy.start_offset = start_offset
	copy.end_offset = end_offset
	copy.start_arrow_anchor = start_arrow_anchor
	copy.end_arrow_anchor = end_arrow_anchor
	copy.color = color
	copy.thickness = thickness
	copy.smooth_antialiasing = smooth_antialiasing
	copy.flat_mode = flat_mode
	copy.texture_filter_override = texture_filter_override
	copy.arrow_texture_filter_override = arrow_texture_filter_override
	copy.texture_mode = texture_mode
	copy.line_texture = line_texture
	copy.texture_scale = texture_scale
	copy.texture_tint = texture_tint
	copy.arrow_texture_start = arrow_texture_start
	copy.arrow_texture_end = arrow_texture_end
	copy.start_arrow_scale = start_arrow_scale
	copy.end_arrow_scale = end_arrow_scale
	copy.start_arrow_distance = start_arrow_distance
	copy.end_arrow_distance = end_arrow_distance
	copy.start_arrow_flip = start_arrow_flip
	copy.end_arrow_flip = end_arrow_flip
	copy.start_arrow_tint = start_arrow_tint
	copy.end_arrow_tint = end_arrow_tint
	copy.cap_start = cap_start
	copy.cap_end = cap_end
	copy.wiggle_enabled = wiggle_enabled
	copy.wiggle_base_amplitude = wiggle_base_amplitude
	copy.wiggle_frequency = wiggle_frequency
	copy.wiggle_speed = wiggle_speed
	copy.wiggle_phase_offset = wiggle_phase_offset
	copy.wiggle_pattern = wiggle_pattern
	copy.wiggle_random_seed = wiggle_random_seed
	copy.wiggle_use_hover_intensity = wiggle_use_hover_intensity
	copy.wiggle_active_boost = wiggle_active_boost
	copy.wiggle_direction_mode = wiggle_direction_mode
	copy.overridden_fields = overridden_fields.duplicate(true)
	return copy


func has_line_texture() -> bool:
	return texture_mode != TextureMode.NONE and line_texture != null


func has_start_arrow_texture() -> bool:
	return arrow_texture_start != null


func has_end_arrow_texture() -> bool:
	return arrow_texture_end != null