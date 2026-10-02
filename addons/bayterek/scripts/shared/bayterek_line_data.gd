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

## Endpoint decorations for the start / end of a connection.
## "One-sided arrow"  = START_NONE + END_ARROW
## "Two-sided arrow"  = START_ARROW + END_ARROW
enum ArrowStyle {
	NONE,
	ARROW,
	T_BAR,
	SQUARE,
	CIRCLE,
	DIAMOND,
}

## How the line texture is mapped along the polyline.
##
##   NONE             → no texture; use `color`
##   TILE             → repeat the texture along the line at native size
##   STRETCH          → stretch the texture across the whole line
##   TILE_FIT_HEIGHT  → tile along X, but scale Y to match `thickness`
enum TextureMode {
	NONE,
	TILE,
	STRETCH,
	TILE_FIT_HEIGHT,
}

## How the endpoints of the line are drawn when NOT using arrows.
##
##   BUTT    → flat cut perpendicular to the line (default)
##   ROUND   → half-circle cap
##   SQUARE  → extended flat cap
enum CapStyle {
	BUTT,
	ROUND,
	SQUARE,
}

## Waveform shape used for wiggle animation.
##
##   SINE          → smooth periodic wave
##   PERLIN        → organic noise-driven drift
##   RANDOM_JITTER → discrete random offsets every frame
##   TRIANGLE      → sawtooth pattern
enum WigglePattern {
	SINE,
	PERLIN,
	RANDOM_JITTER,
	TRIANGLE,
	BOUNCE,
}

# ============================================================
# GEOMETRY
# ============================================================

@export var line_type: LineType = LineType.STRAIGHT
@export var line_style: LineStyle = LineStyle.SOLID
@export var curve_height: float = 48.0
@export var segments: int = 16
@export var reversed: bool = false

## Step / square shape only.
## Distance from the node edges before the line makes its turn.
@export var step_distance: float = 48.0

## Dash / dot pattern length in pixels.
## For DASHED: single segment length.
## For DOTTED: dot length (kept small).
## For DASH_DOT: long segment length (short segment is dash_length * 0.25).
@export var dash_length: float = 12.0

## Gap length in pixels between dash/dot segments.
@export var dash_gap: float = 6.0

## Offset along the dash pattern start (in pixels).
## Useful for "marching ants" animations when combined with a tween.
@export var dash_offset: float = 0.0

# ============================================================
# ENDPOINT DECORATIONS
# ============================================================

@export var start_arrow: ArrowStyle = ArrowStyle.NONE
@export var end_arrow: ArrowStyle = ArrowStyle.NONE
@export var arrow_size: float = 12.0

## Additional offset (in pixels) between the node's edge and the
## start/end point of the line. Useful when arrows or textures need
## extra space to sit nicely without overlapping the node.
##
## `start_offset` shifts the start point AWAY from the source node.
## `end_offset`   shifts the end point AWAY from the target node.
@export var start_offset: float = 0.0
@export var end_offset: float = 0.0

# ============================================================
# VISUAL STYLE
# ============================================================

## Base line color. Used when `texture_mode` is NONE, or as a tint
## multiplier when a texture is set (via `texture_tint`).
@export var color: Color = Color(0.7, 0.7, 0.7, 0.9)

## Line thickness in pixels.
@export var thickness: float = 4.0

## When false, the line is drawn without antialiasing — a crisp,
## single-color "flat" look. Useful for pixel-art or high-contrast
## styles.
@export var smooth_antialiasing: bool = true

# ============================================================
# LINE TEXTURE
# ============================================================

@export var texture_mode: TextureMode = TextureMode.NONE
@export var line_texture: Texture2D = null

## Multiplier applied to the texture when tiling/stretching.
## (1, 1) = native size; (2, 1) = twice as wide along the line.
@export var texture_scale: Vector2 = Vector2.ONE

## Multiplicative color applied on top of the texture.
@export var texture_tint: Color = Color.WHITE

# ============================================================
# ARROW TEXTURE
# ============================================================

## Optional textures for the start/end arrows. When set, the arrow is
## drawn as a sprite instead of the shape-based arrow style.
@export var arrow_texture_start: Texture2D = null
@export var arrow_texture_end: Texture2D = null

## Scale of the arrow sprite. Applied on top of the natural texture
## size (or `arrow_size` when using shape-based arrows).
@export var arrow_scale: Vector2 = Vector2.ONE

## Multiplicative color applied to the arrow sprite.
@export var arrow_tint: Color = Color.WHITE

## Additional offset (in pixels) between the arrow tip and the line
## endpoint. Positive values push the arrow slightly past the line.
@export var arrow_offset_x: float = 0.0

# ============================================================
# CAP STYLE
# ============================================================

@export var cap_start: CapStyle = CapStyle.BUTT
@export var cap_end: CapStyle = CapStyle.BUTT

# ============================================================
# WIGGLE (SHAKE) ANIMATION
# ============================================================

## Whether the wiggle effect is active for this line.
@export var wiggle_enabled: bool = false

## Base wiggle amplitude in pixels. This is the maximum lateral
## displacement applied to the middle of the line.
##
## When `wiggle_use_hover_intensity` is true, the effective amplitude
## is scaled by the target node's current visual offset (hover lift).
@export var wiggle_base_amplitude: float = 2.0

## Oscillation frequency in Hz. Higher = faster shake.
@export var wiggle_frequency: float = 2.0

## Global speed multiplier for the wiggle clock.
@export var wiggle_speed: float = 1.0

## Phase offset in radians. Use to stagger multiple wiggling lines so
## they don't all move in perfect sync.
@export var wiggle_phase_offset: float = 0.0

## Waveform shape used for the wiggle.
@export var wiggle_pattern: WigglePattern = WigglePattern.SINE

## Per-line seed for RANDOM_JITTER and PERLIN patterns. 0 = auto-
## generate from the line's id at runtime.
@export var wiggle_random_seed: int = 0

## When true, the wiggle amplitude is scaled by how far the target
## node currently is from its resting position (i.e. how much it has
## been lifted by a hover animation). No hover = no wiggle.
@export var wiggle_use_hover_intensity: bool = true

## Multiplier applied to the effective amplitude when the target node
## is in an active/allocated state. Set to 1.0 to disable the boost.
@export var wiggle_active_boost: float = 1.5

# ============================================================
# PER-FIELD OVERRIDE TRACKING (Aşama 6 + 7)
# ============================================================
#
# When a user edits a field on a specific connection from the
# Inspector, we mark that field as "overridden". Then, when the user
# changes a tree-level DEFAULT from the Settings tab, we know not to
# overwrite the per-line override.
#
# This is the standard "inheritance with override" pattern: values
# inherit from the tree until the user explicitly edits them, at which
# point they become independent.
#
# Keys are field names (strings), values are always true.
# We use a Dictionary because Godot's built-in "has" checks are O(1).
@export_storage var overridden_fields: Dictionary = {}

## Returns true if the given field was explicitly overridden on this line.
func is_overridden(field_name: String) -> bool:
	return overridden_fields.has(field_name)

## Marks a field as overridden (or clears the override if `overridden`
## is false). Once overridden, tree-level default changes won't touch
## this field.
func set_overridden(field_name: String, overridden: bool) -> void:
	if overridden:
		overridden_fields[field_name] = true
	else:
		overridden_fields.erase(field_name)

## Clears ALL per-field overrides. Used by "Reset to defaults" actions.
func clear_all_overrides() -> void:
	overridden_fields.clear()

## Returns a list of all overridden field names. Used for debug output
## and by the Inspector to show which fields are customized.
func get_overridden_fields() -> Array:
	return overridden_fields.keys()

# ============================================================
# HELPERS
# ============================================================

## Returns a new BayterekLineData with the same values as this one.
## Used by the copy/paste path and by prefab instantiation.
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
	copy.overridden_fields = overridden_fields.duplicate(true)
	return copy


## Returns true if the line has any visual texture to draw.
func has_line_texture() -> bool:
	return texture_mode != TextureMode.NONE and line_texture != null


## Returns true if the start endpoint should use a texture.
func has_start_arrow_texture() -> bool:
	return arrow_texture_start != null


## Returns true if the end endpoint should use a texture.
func has_end_arrow_texture() -> bool:
	return arrow_texture_end != null