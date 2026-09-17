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

@export var line_type: LineType = LineType.STRAIGHT
@export var curve_height: float = 48.0
@export var segments: int = 16
@export var reversed: bool = false

## Step / square shape only.
## Distance from the node edges before the line makes its turn.
@export var step_distance: float = 48.0