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

## Endpoint decorations.
@export var start_arrow: ArrowStyle = ArrowStyle.NONE
@export var end_arrow: ArrowStyle = ArrowStyle.NONE
@export var arrow_size: float = 12.0