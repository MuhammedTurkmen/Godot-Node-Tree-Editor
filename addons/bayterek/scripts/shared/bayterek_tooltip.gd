@tool
class_name BayterekTooltip
extends PanelContainer
## Tooltip panel shown when hovering a node.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

const CURRENCY_MAX_PER_ROW := 3
const CURRENCY_ICON_SIZE := Vector2(16, 16)
const CURRENCY_FALLBACK_ICON := "💰"

const LOC_KEY_LEVEL_MAXED := "bayterek_node_level_maxed"

## Base font size for the currency amount label. Scaled by the tree's
## `font_size_scale` at render time.
const CURRENCY_BASE_FONT_SIZE := 13

## Base font size for the "MAXED" badge. Scaled by the tree's
## `font_size_scale` at render time.
const MAXED_BASE_FONT_SIZE := 14

## Tolerance before we consider the tooltip "grown beyond expectation".
## Values smaller than this are ignored to avoid layout jitter.
const HEIGHT_TOLERANCE := 3.0

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
var _currency_container: VBoxContainer
var _currency_sep: HSeparator
var _footer_sep: HSeparator
var _footer_label: RichTextLabel

var _header_align: int = 0
var _body_align: int = 0
var _footer_align: int = 1

## The node currently being inspected. Used to re-position after a
## deferred height correction.
var _current_node: BayterekNodeButton = null

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	# _process only runs while the tooltip is visible, so we don't waste
	# CPU cycles checking an invisible panel every frame.
	set_process(false)

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

	# --- Currency container ---
	_currency_sep = HSeparator.new()
	_currency_sep.name = "CurrencySep"
	_vbox.add_child(_currency_sep)

	_currency_container = VBoxContainer.new()
	_currency_container.name = "CurrencyContainer"
	_currency_container.add_theme_constant_override("separation", 2)
	_currency_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_currency_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_currency_container)

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

	_apply_texture_filter()

## Localization helper — mirrors BayterekNodeButton._localize().
func _localize(key: String, fallback: String) -> String:
	if key.is_empty():
		return fallback
	if not is_inside_tree():
		return fallback

	var loc = get_node_or_null("/root/GameLocalization")
	if not loc or not loc.has_method("get_raw_text"):
		return fallback

	var translated: String = String(loc.call("get_raw_text", key))
	if translated.is_empty():
		return fallback
	return translated

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
# HEIGHT CORRECTION (fix for "tooltip keeps growing")
# ============================================================
#
# RichTextLabel with `fit_content = true` has a quirk: when the text
# changes, its internal layout gets recomputed on the NEXT frame, so
# the parent PanelContainer's height lags behind. If the panel's
# height was already larger than the new content requires, it never
# shrinks back — the tooltip appears to grow every time you hover.
#
# `_process()` below compares the panel's actual height against the
# height it SHOULD have (computed from the visible children). If the
# actual exceeds the expected by more than HEIGHT_TOLERANCE, we force
# a `reset_size()` and re-position.

func _process(_delta: float) -> void:
	if not visible or not _vbox:
		return

	var expected: float = _compute_expected_height()
	var actual: float = size.y

	# Only correct when the tooltip has grown noticeably beyond what
	# the content needs. Small fluctuations are ignored.
	if actual <= expected + HEIGHT_TOLERANCE:
		return

	# Force the labels to recompute their layout.
	_header_label.reset_size()
	_body_label.reset_size()
	_footer_label.reset_size()

	# Force the panel itself to shrink.
	reset_size()

	# Re-position, since the panel's bounds changed.
	if _current_node and is_instance_valid(_current_node):
		_update_position(_current_node)

## Computes the exact height the tooltip should have, based on its
## visible children + the panel's own content margins.
func _compute_expected_height() -> float:
	if not _vbox:
		return 0.0

	var sep: float = float(_vbox.get_theme_constant("separation"))
	var total: float = 0.0
	var count: int = 0

	for child in _vbox.get_children():
		if not child is Control:
			continue
		var c: Control = child
		if not c.visible:
			continue

		var child_h: float = 0.0
		if c is RichTextLabel:
			var rtl: RichTextLabel = c
			# get_content_height() returns the actual rendered height
			# of the text, which is more accurate than get_combined_minimum_size()
			# for fit_content labels.
			child_h = maxf(rtl.get_content_height(), rtl.get_combined_minimum_size().y)
		else:
			child_h = c.get_combined_minimum_size().y

		total += child_h
		count += 1

	if count > 1:
		total += sep * float(count - 1)

	# Add the panel's own content margins (top + bottom).
	var panel_style: StyleBox = get_theme_stylebox("panel")
	if panel_style:
		total += panel_style.get_margin(SIDE_TOP)
		total += panel_style.get_margin(SIDE_BOTTOM)

	return total

# ============================================================
# PIXEL ART MODE
# ============================================================

func _apply_texture_filter() -> void:
	var pixel_mode: bool = false
	if tree_view and tree_view._tree_data:
		pixel_mode = tree_view._tree_data.pixel_art_mode

	var filter_mode: int = (
		CanvasItem.TEXTURE_FILTER_NEAREST if pixel_mode
		else CanvasItem.TEXTURE_FILTER_LINEAR
	)

	var labels: Array = [_header_label, _body_label, _footer_label]
	for lbl in labels:
		if is_instance_valid(lbl):
			lbl.texture_filter = filter_mode

	for child in _currency_container.get_children():
		_apply_filter_recursive(child, filter_mode)

func _apply_filter_recursive(node: Node, filter_mode: int) -> void:
	if node is CanvasItem:
		(node as CanvasItem).texture_filter = filter_mode
	for child in node.get_children():
		_apply_filter_recursive(child, filter_mode)

# ============================================================
# PUBLIC API
# ============================================================

func inspect(node: BayterekNodeButton) -> void:
	if not node or not node.node_data:
		reset()
		return

	_current_node = node

	# Re-apply filter in case the tree's pixel_art_mode changed.
	_apply_texture_filter()

	if node.tree_data:
		_header_align = node.tree_data.tooltip_header_align
		_body_align = node.tree_data.tooltip_body_align
		_footer_align = node.tree_data.tooltip_footer_align
		_apply_alignments()

	var sections: Dictionary = node.format_tooltip_sections()
	header_label_set_text(sections.get("header", ""))
	body_label_set_text(sections.get("body", ""))
	footer_label_set_text(sections.get("footer", ""))

	# Force layout recalculation on every label.
	_header_label.reset_size()
	_body_label.reset_size()
	_footer_label.reset_size()

	if node.is_maxed():
		_build_maxed_row()
	else:
		_build_currency_row(node.get_currency_entries())

	_header_sep.visible = not _body_label.text.is_empty() and not _header_label.text.is_empty()
	_currency_sep.visible = _currency_container.get_child_count() > 0 and (
		not _body_label.text.is_empty() or not _header_label.text.is_empty()
	)
	_footer_sep.visible = not _footer_label.text.is_empty() and (
		not _body_label.text.is_empty()
		or not _header_label.text.is_empty()
		or _currency_container.get_child_count() > 0
	)

	reset_size()
	visible = true
	set_process(true)
	_update_position(node)

# ============================================================
# CURRENCY ROW BUILDER
# ============================================================

func _build_currency_row(entries: Array) -> void:
	for child in _currency_container.get_children():
		child.queue_free()

	if entries.is_empty():
		return

	var icon_scale: float = 1.0
	if tree_view and tree_view._tree_data:
		icon_scale = tree_view._tree_data.currency_icon_scale
	if icon_scale <= 0.0:
		icon_scale = 1.0

	var font_scale: float = 1.0
	if tree_view and tree_view._tree_data:
		font_scale = tree_view._tree_data.font_size_scale
	if font_scale <= 0.0:
		font_scale = 1.0

	var currency_font_size: int = max(6, int(round(float(CURRENCY_BASE_FONT_SIZE) * font_scale)))

	var pixel_mode: bool = false
	if tree_view and tree_view._tree_data:
		pixel_mode = tree_view._tree_data.pixel_art_mode
	var icon_filter: int = (
		CanvasItem.TEXTURE_FILTER_NEAREST if pixel_mode
		else CanvasItem.TEXTURE_FILTER_LINEAR
	)

	var current_row: HBoxContainer = null
	var count_in_row: int = 0

	for entry in entries:
		if not entry is Dictionary:
			continue

		if current_row == null or count_in_row >= CURRENCY_MAX_PER_ROW:
			current_row = HBoxContainer.new()
			current_row.add_theme_constant_override("separation", 1)
			current_row.alignment = BoxContainer.ALIGNMENT_CENTER
			current_row.size_flags_horizontal = SIZE_EXPAND_FILL
			current_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_currency_container.add_child(current_row)
			count_in_row = 0

		var icon: Texture2D = entry.get("icon", null)
		var amount: int = int(entry.get("amount", 0))
		var affordable: bool = bool(entry.get("affordable", true))

		if icon != null:
			var tex_rect := TextureRect.new()
			tex_rect.texture = icon
			tex_rect.custom_minimum_size = CURRENCY_ICON_SIZE * icon_scale
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tex_rect.texture_filter = icon_filter
			current_row.add_child(tex_rect)
		else:
			var emoji := Label.new()
			emoji.text = CURRENCY_FALLBACK_ICON
			emoji.add_theme_font_size_override("font_size", currency_font_size)
			emoji.mouse_filter = Control.MOUSE_FILTER_IGNORE
			emoji.texture_filter = icon_filter
			current_row.add_child(emoji)

		var amount_lbl := Label.new()
		amount_lbl.text = str(amount)

		var text_color: Color
		if amount < 0:
			text_color = Color(0.5, 1.0, 0.5)
		elif amount == 0:
			text_color = Color(0.7, 0.7, 0.7)
		else:
			text_color = Color(0.56, 0.96, 0.56) if affordable else Color(1.0, 0.4, 0.4)

		amount_lbl.add_theme_color_override("font_color", text_color)
		amount_lbl.add_theme_font_size_override("font_size", currency_font_size)
		amount_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		amount_lbl.texture_filter = icon_filter
		current_row.add_child(amount_lbl)

		count_in_row += 1

## Renders a centred "MAXED" badge when the node is fully allocated.
func _build_maxed_row() -> void:
	for child in _currency_container.get_children():
		child.queue_free()

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_currency_container.add_child(row)

	var pixel_mode: bool = false
	if tree_view and tree_view._tree_data:
		pixel_mode = tree_view._tree_data.pixel_art_mode

	var font_scale: float = 1.0
	if tree_view and tree_view._tree_data:
		font_scale = tree_view._tree_data.font_size_scale
	if font_scale <= 0.0:
		font_scale = 1.0

	var maxed_font_size: int = max(6, int(round(float(MAXED_BASE_FONT_SIZE) * font_scale)))

	var lbl := Label.new()
	lbl.text = _localize(LOC_KEY_LEVEL_MAXED, "MAXED")
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	lbl.add_theme_font_size_override("font_size", maxed_font_size)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.texture_filter = (
		CanvasItem.TEXTURE_FILTER_NEAREST if pixel_mode
		else CanvasItem.TEXTURE_FILTER_LINEAR
	)
	row.add_child(lbl)

func header_label_set_text(t: String) -> void:
	if not _header_label:
		return
	_header_label.text = t
	_header_label.reset_size()

func body_label_set_text(t: String) -> void:
	if not _body_label:
		return
	_body_label.text = t
	_body_label.reset_size()

func footer_label_set_text(t: String) -> void:
	if not _footer_label:
		return
	_footer_label.text = t
	_footer_label.reset_size()

func reset() -> void:
	visible = false
	set_process(false)
	_current_node = null
	if _header_label:
		_header_label.text = ""
		_header_label.reset_size()
	if _body_label:
		_body_label.text = ""
		_body_label.reset_size()
	if _footer_label:
		_footer_label.text = ""
		_footer_label.reset_size()
	for child in _currency_container.get_children():
		child.queue_free()

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

	var node_rect: Rect2 = node.get_global_rect()
	var tooltip_size: Vector2 = size

	var has_h: bool = absf(node_offset.x) > 0.01
	var has_v: bool = absf(node_offset.y) > 0.01

	var target_pos: Vector2

	if has_h and has_v:
		if node_offset.x > 0:
			target_pos.x = node_rect.position.x + node_rect.size.x + node_offset.x
		else:
			target_pos.x = node_rect.position.x + node_offset.x - tooltip_size.x

		if node_offset.y > 0:
			target_pos.y = node_rect.position.y + node_rect.size.y + node_offset.y
		else:
			target_pos.y = node_rect.position.y + node_offset.y - tooltip_size.y

	elif has_h and not has_v:
		target_pos.y = node_rect.position.y + node_rect.size.y * 0.5 - tooltip_size.y * 0.5
		if node_offset.x > 0:
			target_pos.x = node_rect.position.x + node_rect.size.x + node_offset.x
		else:
			target_pos.x = node_rect.position.x + node_offset.x - tooltip_size.x

	elif has_v and not has_h:
		target_pos.x = node_rect.position.x + node_rect.size.x * 0.5 - tooltip_size.x * 0.5
		if node_offset.y > 0:
			target_pos.y = node_rect.position.y + node_rect.size.y + node_offset.y
		else:
			target_pos.y = node_rect.position.y + node_offset.y - tooltip_size.y

	else:
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