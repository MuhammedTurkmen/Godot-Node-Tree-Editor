@tool
class_name BayterekTooltip
extends PanelContainer
## Tooltip panel shown when hovering a node.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

enum PositionMode {
	NEAR_NODE,
	FIXED_CORNER,
}

@export var position_mode: PositionMode = PositionMode.NEAR_NODE
@export var corner: int = Bayterek.TooltipCorner.BOTTOM_RIGHT
@export var corner_margin: Vector2 = Vector2(20, 20)
@export var node_offset: Vector2 = Vector2(20, 0)

var tree_view: Control = null

var _vbox: VBoxContainer
var _header_label: RichTextLabel
var _header_sep: HSeparator
var _body_label: RichTextLabel
var _footer_sep: HSeparator
var _footer_label: RichTextLabel

var _header_align: int = 0
var _body_align: int = 0
var _footer_align: int = 1

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()

func _build_ui() -> void:
	if _vbox:
		return

	for child in get_children():
		child.queue_free()

	_vbox = VBoxContainer.new()
	_vbox.name = "VBox"
	_vbox.add_theme_constant_override("separation", 6)
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vbox)

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

	_header_sep = HSeparator.new()
	_header_sep.name = "HeaderSep"
	_vbox.add_child(_header_sep)

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

	_footer_sep = HSeparator.new()
	_footer_sep.name = "FooterSep"
	_vbox.add_child(_footer_sep)

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

func inspect(node: BayterekNodeButton) -> void:
	if not node or not node.node_data:
		reset()
		return

	if node.tree_data:
		_header_align = node.tree_data.tooltip_header_align
		_body_align = node.tree_data.tooltip_body_align
		_footer_align = node.tree_data.tooltip_footer_align
		_apply_alignments()

	var sections: Dictionary = node.format_tooltip_sections()
	header_label_set_text(sections.get("header", ""))
	body_label_set_text(sections.get("body", ""))
	footer_label_set_text(sections.get("footer", ""))

	_header_sep.visible = not _body_label.text.is_empty() and not _header_label.text.is_empty()
	_footer_sep.visible = not _footer_label.text.is_empty() and (not _body_label.text.is_empty() or not _header_label.text.is_empty())

	reset_size()
	visible = true
	_update_position(node)

## Wrappers — `RichTextLabel.text` in BBCode mode needs to be set this way
## so a deferred re-layout happens before `reset_size()`.
func header_label_set_text(t: String) -> void:
	_header_label.text = t

func body_label_set_text(t: String) -> void:
	_body_label.text = t

func footer_label_set_text(t: String) -> void:
	_footer_label.text = t

func reset() -> void:
	visible = false
	if _header_label:
		_header_label.text = ""
	if _body_label:
		_body_label.text = ""
	if _footer_label:
		_footer_label.text = ""

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

## Places the tooltip near the node using the node's on-screen rect.
##
## The node's `size` is the visible bounds (largest layer), so we use
## it directly to compute the node's screen edges. The tooltip is
## placed OUTSIDE these edges.
func _position_near_node(node: BayterekNodeButton) -> void:
	if not node:
		return

	# Get the node's rect in SCREEN coordinates.
	var node_rect: Rect2 = node.get_global_rect()
	var tooltip_size: Vector2 = size

	var has_h: bool = absf(node_offset.x) > 0.01
	var has_v: bool = absf(node_offset.y) > 0.01

	var target_pos: Vector2

	if has_h and has_v:
		# Corner placement: choose side based on sign of offset.
		if node_offset.x > 0:
			target_pos.x = node_rect.position.x + node_rect.size.x + node_offset.x
		else:
			target_pos.x = node_rect.position.x + node_offset.x - tooltip_size.x

		if node_offset.y > 0:
			target_pos.y = node_rect.position.y + node_rect.size.y + node_offset.y
		else:
			target_pos.y = node_rect.position.y + node_offset.y - tooltip_size.y

	elif has_h and not has_v:
		# Horizontal-only: align to node vertical center, place OUTSIDE.
		target_pos.y = node_rect.position.y + node_rect.size.y * 0.5 - tooltip_size.y * 0.5
		if node_offset.x > 0:
			target_pos.x = node_rect.position.x + node_rect.size.x + node_offset.x
		else:
			target_pos.x = node_rect.position.x + node_offset.x - tooltip_size.x

	elif has_v and not has_h:
		# Vertical-only: align to node horizontal center, place OUTSIDE.
		target_pos.x = node_rect.position.x + node_rect.size.x * 0.5 - tooltip_size.x * 0.5
		if node_offset.y > 0:
			target_pos.y = node_rect.position.y + node_rect.size.y + node_offset.y
		else:
			target_pos.y = node_rect.position.y + node_offset.y - tooltip_size.y

	else:
		# No offset: default to the right of the node, vertically centered.
		target_pos.y = node_rect.position.y + node_rect.size.y * 0.5 - tooltip_size.y * 0.5
		target_pos.x = node_rect.position.x + node_rect.size.x + 20

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