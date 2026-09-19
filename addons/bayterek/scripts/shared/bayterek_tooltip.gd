@tool
class_name BayterekTooltip
extends PanelContainer
## Tooltip panel shown when hovering a node.
##
## Layout:
##   ┌───────────────────────────┐
##   │  Header   (name)          │  ← tooltip_header_align
##   ├───────────────────────────┤
##   │  Body     (attrs + desc)  │  ← tooltip_body_align
##   ├───────────────────────────┤
##   │  Footer   (level)         │  ← tooltip_footer_align
##   └───────────────────────────┘

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
@export var node_offset: Vector2 = Vector2(20, 0)

## Reference to the tree view (used for FIXED_CORNER positioning and clamping)
var tree_view: Control = null

# ============================================================
# SUB-CONTROLS
# ============================================================

var _vbox: VBoxContainer
var _header_label: RichTextLabel
var _header_sep: HSeparator
var _body_label: RichTextLabel
var _footer_sep: HSeparator
var _footer_label: RichTextLabel

# Alignment (0 = left, 1 = center, 2 = right)
var _header_align: int = 0
var _body_align: int = 0
var _footer_align: int = 1

# ============================================================
# READY
# ============================================================

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_ui()

func _build_ui() -> void:
	if _vbox:
		return

	# Remove any pre-existing children (in case a .tscn set them up)
	for child in get_children():
		child.queue_free()

	_vbox = VBoxContainer.new()
	_vbox.name = "VBox"
	_vbox.add_theme_constant_override("separation", 6)
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vbox)

	# --- Header ---
	_header_label = RichTextLabel.new()
	_header_label.name = "Header"
	_header_label.bbcode_enabled = true
	_header_label.fit_content = true
	_header_label.scroll_active = false
	_header_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header_label.custom_minimum_size = Vector2(260, 0)
	_header_label.custom_maximum_size = Vector2(550, -1)
	_header_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_header_label)

	# --- Header separator ---
	_header_sep = HSeparator.new()
	_header_sep.name = "HeaderSep"
	_vbox.add_child(_header_sep)

	# --- Body ---
	_body_label = RichTextLabel.new()
	_body_label.name = "Body"
	_body_label.bbcode_enabled = true
	_body_label.fit_content = true
	_body_label.scroll_active = false
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size = Vector2(260, 0)
	_body_label.custom_maximum_size = Vector2(550, -1)
	_body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_body_label)

	# --- Footer separator ---
	_footer_sep = HSeparator.new()
	_footer_sep.name = "FooterSep"
	_vbox.add_child(_footer_sep)

	# --- Footer ---
	_footer_label = RichTextLabel.new()
	_footer_label.name = "Footer"
	_footer_label.bbcode_enabled = true
	_footer_label.fit_content = true
	_footer_label.scroll_active = false
	_footer_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_footer_label.custom_minimum_size = Vector2(260, 0)
	_footer_label.custom_maximum_size = Vector2(550, -1)
	_footer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_footer_label)

	_apply_alignments()

func _apply_alignments() -> void:
	_set_label_align(_header_label, _header_align)
	_set_label_align(_body_label, _body_align)
	_set_label_align(_footer_label, _footer_align)

func _set_label_align(label: RichTextLabel, align: int) -> void:
	if not label:
		return
	match align:
		1: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		2: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

# ============================================================
# PUBLIC API
# ============================================================

## Fills the tooltip from a node and shows it.
func inspect(node: BayterekNodeButton) -> void:
	if not node or not node.node_data:
		reset()
		return

	# Read alignment from the tree (if available)
	if node.tree_data:
		_header_align = node.tree_data.tooltip_header_align
		_body_align = node.tree_data.tooltip_body_align
		_footer_align = node.tree_data.tooltip_footer_align
		_apply_alignments()

	# Ask the node for its formatted sections
	var sections: Dictionary = node.format_tooltip_sections()
	_header_label.text = sections.get("header", "")
	_body_label.text = sections.get("body", "")
	_footer_label.text = sections.get("footer", "")

	# Hide separators if a section is empty
	_header_sep.visible = not _body_label.text.is_empty() and not _header_label.text.is_empty()
	_footer_sep.visible = not _footer_label.text.is_empty() and (not _body_label.text.is_empty() or not _header_label.text.is_empty())

	# Reset size, then show
	reset_size()
	visible = true
	_update_position(node)

## Hides and clears the tooltip.
func reset() -> void:
	visible = false
	if _header_label:
		_header_label.text = ""
	if _body_label:
		_body_label.text = ""
	if _footer_label:
		_footer_label.text = ""

## Re-positions the tooltip if it's already visible.
func update_position_for(node: BayterekNodeButton) -> void:
	if not visible or not node:
		return
	_update_position(node)

# ============================================================
# CONFIGURATION HELPERS
# ============================================================

func set_position_right() -> void:
	position_mode = PositionMode.NEAR_NODE
	node_offset = Vector2(20, 0)

func set_position_left() -> void:
	position_mode = PositionMode.NEAR_NODE
	node_offset = Vector2(-20, 0)

func set_position_top() -> void:
	position_mode = PositionMode.NEAR_NODE
	node_offset = Vector2(0, -20)

func set_position_bottom() -> void:
	position_mode = PositionMode.NEAR_NODE
	node_offset = Vector2(0, 20)

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

	var place_horizontal: bool = absf(node_offset.x) > 0.01
	var place_vertical: bool = absf(node_offset.y) > 0.01

	if place_horizontal and not place_vertical:
		target_pos.y = node_center.y - tooltip_size.y * 0.5
		if node_offset.x > 0:
			target_pos.x = node_global.x + node_size.x + node_offset.x
		else:
			target_pos.x = node_global.x + node_offset.x - tooltip_size.x

	elif place_vertical and not place_horizontal:
		target_pos.x = node_center.x - tooltip_size.x * 0.5
		if node_offset.y > 0:
			target_pos.y = node_global.y + node_size.y + node_offset.y
		else:
			target_pos.y = node_global.y + node_offset.y - tooltip_size.y

	elif place_horizontal and place_vertical:
		target_pos = node_global + node_offset
		if node_offset.x < 0:
			target_pos.x = node_global.x + node_offset.x - tooltip_size.x + node_size.x
		if node_offset.y < 0:
			target_pos.y = node_global.y + node_offset.y - tooltip_size.y + node_size.y

	else:
		target_pos.y = node_center.y - tooltip_size.y * 0.5
		target_pos.x = node_global.x + node_size.x + 20

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