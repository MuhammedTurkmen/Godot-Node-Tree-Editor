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

## How the wiggle direction is chosen at each interior point.
##
##   PERPENDICULAR       → classic wiggle: displacement is perpendicular
##                         to the local line direction.  A horizontal
##                         line sways vertically, a vertical line sways
##                         horizontally.
##
##   FOLLOW_NODE_MOTION  → displacement follows the SOURCE node's
##                         movement direction. If the node is lifting
##                         upward, the line wiggles upward; if it's
##                         descending, the wiggle is downward.
##
##   AXIS_LOCK           → the wiggle displacement is locked to the
##                         world axis (X or Y) that matches the node's
##                         motion axis. A node moving vertically makes
##                         its lines sway vertically (never sideways);
##                         a node moving horizontally makes its lines
##                         sway horizontally (never up/down).
enum WiggleDirectionMode {
	PERPENDICULAR,
	FOLLOW_NODE_MOTION,
	AXIS_LOCK,
}

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

# ============================================================
# VISUAL STYLE
# ============================================================

@export var color: Color = Color(0.7, 0.7, 0.7, 0.9)
@export var thickness: float = 4.0
@export var smooth_antialiasing: bool = true

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

## How the wiggle direction is chosen.
##
##   PERPENDICULAR      → classic perpendicular sway (default).
##   FOLLOW_NODE_MOTION → sway follows the node's actual motion
##                        direction.
##   AXIS_LOCK          → sway is locked to the world axis matching
##                        the node's motion axis (vertical motion =
##                        vertical sway; horizontal motion = horizontal
##                        sway).
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
	copy.color = color
	copy.thickness = thickness
	copy.smooth_antialiasing = smooth_antialiasing
	copy.texture_mode = texture_mode
	copy.line_texture = line_texture
	copy.texture_scale = texture_scale
	copy.texture_tint = texture_tint
	copy.arrow_texture_start = arrow_texture_start
	copy.arrow_texture_end = arrow_texture_end
	copy.arrow_scale = arrow_scale
	copy.arrow_tint = arrow_tint
	copy.arrow_offset_x = arrow_offset_x
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