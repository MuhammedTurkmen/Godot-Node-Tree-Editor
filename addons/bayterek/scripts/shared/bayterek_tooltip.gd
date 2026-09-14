@tool
class_name BayterekTooltip
extends PanelContainer
## Tooltip panel shown when hovering a node.
## Displays node name, allocation level, attributes and description.
## Rich BBCode formatting.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

enum PositionMode {
	NEAR_NODE,
	FIXED_CORNER,
}

## Where to place the tooltip
@export var position_mode: PositionMode = PositionMode.NEAR_NODE

## Which corner to anchor to when position_mode == FIXED_CORNER
@export var corner: int = Bayterek.TooltipCorner.BOTTOM_RIGHT

## Margin from the corner (in pixels)
@export var corner_margin: Vector2 = Vector2(20, 20)

## Offset from the node when position_mode == NEAR_NODE.
## X axis: positive = right, negative = left.
## Y axis: positive = down, negative = up.
## The perpendicular axis is auto-centered on the node.
@export var node_offset: Vector2 = Vector2(20, 0)

## Reference to the tree view (used for FIXED_CORNER positioning and clamping)
var tree_view: Control = null

@export var label: RichTextLabel

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if label:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE

# ============================================================
# PUBLIC API
# ============================================================

## Fills the tooltip with the node's formatted content and shows it.
func inspect(node: BayterekNodeButton) -> void:
	if not node or not node.node_data:
		reset()
		return
	if not label:
		return

	label.text = node.format_tooltip()
	label.reset_size()
	reset_size()

	visible = true
	_update_position(node)

## Hides and clears the tooltip.
func reset() -> void:
	visible = false
	if label:
		label.text = ""

## Re-positions the tooltip if it's already visible.
func update_position_for(node: BayterekNodeButton) -> void:
	if not visible or not node:
		return
	_update_position(node)

# ============================================================
# CONFIGURATION HELPERS
# ============================================================

## NEAR_NODE: tooltip appears to the RIGHT of the node
func set_position_right() -> void:
	position_mode = PositionMode.NEAR_NODE
	node_offset = Vector2(20, 0)

## NEAR_NODE: tooltip appears to the LEFT of the node
func set_position_left() -> void:
	position_mode = PositionMode.NEAR_NODE
	node_offset = Vector2(-20, 0)

## NEAR_NODE: tooltip appears ABOVE the node
func set_position_top() -> void:
	position_mode = PositionMode.NEAR_NODE
	node_offset = Vector2(0, -20)

## NEAR_NODE: tooltip appears BELOW the node
func set_position_bottom() -> void:
	position_mode = PositionMode.NEAR_NODE
	node_offset = Vector2(0, 20)

## FIXED_CORNER helpers
func set_corner_top_left() -> void:
	position_mode = PositionMode.FIXED_CORNER
	corner = Bayterek.TooltipCorner.TOP_LEFT

func set_corner_top_right() -> void:
	position_mode = PositionMode.FIXED_CORNER
	corner = Bayterek.TooltipCorner.TOP_RIGHT

func set_corner_bottom_left() -> void:
	position_mode = PositionMode.FIXED_CORNER
	corner = Bayterek.TooltipCorner.BOTTOM_LEFT

func set_corner_bottom_right() -> void:
	position_mode = PositionMode.FIXED_CORNER
	corner = Bayterek.TooltipCorner.BOTTOM_RIGHT

# ============================================================
# POSITIONING
# ============================================================

func _update_position(node: BayterekNodeButton) -> void:
	match position_mode:
		PositionMode.NEAR_NODE:
			_position_near_node(node)
		PositionMode.FIXED_CORNER:
			_position_fixed_corner()

func _position_near_node(node: BayterekNodeButton) -> void:
	if not node:
		return

	var node_global: Vector2 = node.get_global_position()
	var node_size: Vector2 = node.size
	var node_center: Vector2 = node_global + node_size * 0.5
	var tooltip_size: Vector2 = size

	var target_pos: Vector2 = Vector2.ZERO

	# Determine placement direction from offset
	var place_horizontal: bool = absf(node_offset.x) > 0.01
	var place_vertical: bool = absf(node_offset.y) > 0.01

	if place_horizontal and not place_vertical:
		# === LEFT or RIGHT placement ===
		# Vertically: tooltip center = node center
		target_pos.y = node_center.y - tooltip_size.y * 0.5

		if node_offset.x > 0:
			# RIGHT of node
			target_pos.x = node_global.x + node_size.x + node_offset.x
		else:
			# LEFT of node
			target_pos.x = node_global.x + node_offset.x - tooltip_size.x

	elif place_vertical and not place_horizontal:
		# === TOP or BOTTOM placement ===
		# Horizontally: tooltip center = node center
		target_pos.x = node_center.x - tooltip_size.x * 0.5

		if node_offset.y > 0:
			# BELOW node
			target_pos.y = node_global.y + node_size.y + node_offset.y
		else:
			# ABOVE node
			target_pos.y = node_global.y + node_offset.y - tooltip_size.y

	elif place_horizontal and place_vertical:
		# === Diagonal (both offsets non-zero) ===
		target_pos = node_global + node_offset
		if node_offset.x < 0:
			target_pos.x = node_global.x + node_offset.x - tooltip_size.x + node_size.x
		if node_offset.y < 0:
			target_pos.y = node_global.y + node_offset.y - tooltip_size.y + node_size.y

	else:
		# === Zero offset → default to right, vertically centered ===
		target_pos.y = node_center.y - tooltip_size.y * 0.5
		target_pos.x = node_global.x + node_size.x + 20

	# Clamp to viewport
	target_pos = _clamp_to_viewport(target_pos, tooltip_size)

	global_position = target_pos

func _position_fixed_corner() -> void:
	if not tree_view:
		return

	var tree_rect: Rect2 = tree_view.get_global_rect()
	var tooltip_size: Vector2 = size

	var target_pos: Vector2 = Vector2.ZERO

	match corner:
		Bayterek.TooltipCorner.TOP_LEFT:
			target_pos = tree_rect.position + corner_margin
		Bayterek.TooltipCorner.TOP_RIGHT:
			target_pos = tree_rect.position + Vector2(
				tree_rect.size.x - tooltip_size.x - corner_margin.x,
				corner_margin.y
			)
		Bayterek.TooltipCorner.BOTTOM_LEFT:
			target_pos = tree_rect.position + Vector2(
				corner_margin.x,
				tree_rect.size.y - tooltip_size.y - corner_margin.y
			)
		Bayterek.TooltipCorner.BOTTOM_RIGHT:
			target_pos = tree_rect.position + tree_rect.size - tooltip_size - corner_margin
		_:
			target_pos = tree_rect.position + tree_rect.size - tooltip_size - corner_margin

	global_position = target_pos

## Clamps a position so the tooltip stays within the viewport.
func _clamp_to_viewport(pos: Vector2, tooltip_size: Vector2) -> Vector2:
	var viewport_rect: Rect2 = get_viewport_rect()

	if pos.x + tooltip_size.x > viewport_rect.size.x:
		pos.x = viewport_rect.size.x - tooltip_size.x - 8
	if pos.y + tooltip_size.y > viewport_rect.size.y:
		pos.y = viewport_rect.size.y - tooltip_size.y - 8
	if pos.x < 8:
		pos.x = 8
	if pos.y < 8:
		pos.y = 8

	return pos