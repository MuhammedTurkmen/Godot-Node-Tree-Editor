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

## Per-line texture filter override.
##   0 = Inherit (use tree's filter)
##   1 = Linear (smooth)
##   2 = Nearest (pixel art)
const TEXTURE_FILTER_INHERIT := 0
const TEXTURE_FILTER_LINEAR := 1
const TEXTURE_FILTER_NEAREST := 2

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
@export var arrow_size: float = 12.0
@export var start_offset: float = 0.0
@export var end_offset: float = 0.0

@export var start_arrow_backoff: float = 0.0
@export var end_arrow_backoff: float = 0.0

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
# ARROW TEXTURE
# ============================================================

@export var arrow_texture_start: Texture2D = null
@export var arrow_texture_end: Texture2D = null
@export var arrow_scale: Vector2 = Vector2.ONE
@export var arrow_tint: Color = Color.WHITE
@export var arrow_offset_x: float = 0.0

## Pivot point in the arrow texture's UV space (0..1).
## This is the point that lands exactly on the connection's tip.
##   (0.5, 0.5) = center   ← default
##   (1.0, 0.5) = right edge center (ideal for arrow-head textures)
##   (0.0, 0.5) = left edge center
@export var arrow_texture_pivot: Vector2 = Vector2(0.5, 0.5)

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
	copy.arrow_size = arrow_size
	copy.start_offset = start_offset
	copy.end_offset = end_offset
	copy.start_arrow_backoff = start_arrow_backoff
	copy.end_arrow_backoff = end_arrow_backoff
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
	copy.arrow_scale = arrow_scale
	copy.arrow_tint = arrow_tint
	copy.arrow_offset_x = arrow_offset_x
	copy.arrow_texture_pivot = arrow_texture_pivot
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


## Returns the effective START backoff in pixels.
##
## Rules:
##   - If the user set `start_arrow_backoff > 0`, use it.
##   - TEXTURE arrow → 0 (the texture is drawn at the node edge).
##   - T_BAR → 0 (it sits flush on the line tip).
##   - Other vector arrows → arrow_size * 0.5.
##
## IMPORTANT: texture arrows return 0 so that changing `arrow_size`
## does NOT shift the line endpoints — arrow_size only affects vector
## arrow shapes, and the endpoints must stay stable when a texture is
## in use.
func get_effective_start_backoff() -> float:
	if start_arrow_backoff > 0.0:
		return start_arrow_backoff

	if arrow_texture_start != null:
		return 0.0

	if start_arrow == ArrowStyle.T_BAR:
		return 0.0
	if start_arrow != ArrowStyle.NONE:
		return arrow_size * 0.5
	return 0.0


## Same rules as `get_effective_start_backoff()`, but for the END arrow.
func get_effective_end_backoff() -> float:
	if end_arrow_backoff > 0.0:
		return end_arrow_backoff

	if arrow_texture_end != null:
		return 0.0

	if end_arrow == ArrowStyle.T_BAR:
		return 0.0
	if end_arrow != ArrowStyle.NONE:
		return arrow_size * 0.5
	return 0.0