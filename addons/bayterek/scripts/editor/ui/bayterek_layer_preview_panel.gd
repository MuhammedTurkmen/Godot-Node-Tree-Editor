@tool
class_name BayterekLayerPreviewPanel
extends VBoxContainer
## Right-column large preview panel with zoom controls + background
## color quick-switch buttons (S / B / M).

## Preset background colors for the S / B / M quick-switch buttons.
const BG_BLACK := Color(0.05, 0.05, 0.07, 1.0)
const BG_WHITE := Color(0.95, 0.95, 0.95, 1.0)
const BG_BLUE := Color(0.10, 0.18, 0.32, 1.0)

var _preview: BayterekLayerPreview
var _design_info: Label
var _zoom_label: Label

var _bg_btn_black: Button
var _bg_btn_white: Button
var _bg_btn_blue: Button
var _bg_group: ButtonGroup

func _ready() -> void:
	add_theme_constant_override("separation", 4)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	_build_ui()

func _build_ui() -> void:
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 4)
	add_child(header_row)

	var header := Label.new()
	header.text = "Preview"
	header.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	header.size_flags_horizontal = SIZE_EXPAND_FILL
	header_row.add_child(header)

	_build_bg_color_buttons(header_row)

	var vsep := VSeparator.new()
	header_row.add_child(vsep)

	var zoom_out_btn := Button.new()
	zoom_out_btn.text = "−"
	zoom_out_btn.tooltip_text = "Zoom out (mouse wheel down)"
	zoom_out_btn.custom_minimum_size = Vector2(24, 22)
	zoom_out_btn.pressed.connect(func():
		if _preview: _preview.zoom_out()
	)
	header_row.add_child(zoom_out_btn)

	var zoom_in_btn := Button.new()
	zoom_in_btn.text = "+"
	zoom_in_btn.tooltip_text = "Zoom in (mouse wheel up)"
	zoom_in_btn.custom_minimum_size = Vector2(24, 22)
	zoom_in_btn.pressed.connect(func():
		if _preview: _preview.zoom_in()
	)
	header_row.add_child(zoom_in_btn)

	var fit_btn := Button.new()
	fit_btn.text = "Fit"
	fit_btn.tooltip_text = "Reset zoom and pan"
	fit_btn.custom_minimum_size = Vector2(34, 22)
	fit_btn.pressed.connect(func():
		if _preview: _preview.reset_view()
	)
	header_row.add_child(fit_btn)

	_preview = BayterekLayerPreview.new()
	_preview.size_flags_horizontal = SIZE_EXPAND_FILL
	_preview.size_flags_vertical = SIZE_EXPAND_FILL
	_preview.custom_minimum_size = Vector2(260, 260)
	_preview.zoom_changed.connect(_on_zoom_changed)
	add_child(_preview)

	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 6)
	add_child(info_row)

	_design_info = Label.new()
	_design_info.text = "(no design selected)"
	_design_info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_design_info.add_theme_font_size_override("font_size", 11)
	_design_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_design_info.size_flags_horizontal = SIZE_EXPAND_FILL
	info_row.add_child(_design_info)

	_zoom_label = Label.new()
	_zoom_label.text = "100%"
	_zoom_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_zoom_label.add_theme_font_size_override("font_size", 11)
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_row.add_child(_zoom_label)

	if _bg_btn_black:
		_bg_btn_black.button_pressed = true
		_apply_bg_color(BG_BLACK)

# ============================================================
# BACKGROUND COLOR BUTTONS
# ============================================================

func _build_bg_color_buttons(parent: HBoxContainer) -> void:
	_bg_group = ButtonGroup.new()

	_bg_btn_black = _make_bg_button("S", BG_BLACK, "Siyah arka plan (dark)")
	_bg_btn_white = _make_bg_button("B", BG_WHITE, "Beyaz arka plan (light)")
	_bg_btn_blue = _make_bg_button("M", BG_BLUE, "Mavi arka plan (blue)")

	_bg_btn_black.button_group = _bg_group
	_bg_btn_white.button_group = _bg_group
	_bg_btn_blue.button_group = _bg_group

	_bg_btn_black.pressed.connect(func(): _apply_bg_color(BG_BLACK))
	_bg_btn_white.pressed.connect(func(): _apply_bg_color(BG_WHITE))
	_bg_btn_blue.pressed.connect(func(): _apply_bg_color(BG_BLUE))

	parent.add_child(_bg_btn_black)
	parent.add_child(_bg_btn_white)
	parent.add_child(_bg_btn_blue)

func _make_bg_button(label: String, bg_preview_color: Color, tooltip: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.tooltip_text = tooltip
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(26, 22)
	btn.focus_mode = Control.FOCUS_NONE

	var text_color: Color
	if bg_preview_color.get_luminance() > 0.5:
		text_color = Color(0.1, 0.1, 0.1)
	else:
		text_color = Color(0.95, 0.95, 0.95)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color)
	btn.add_theme_color_override("font_pressed_color", text_color)
	btn.add_theme_color_override("font_focus_color", text_color)

	var normal := _make_stylebox(bg_preview_color, false)
	var hover := _make_stylebox(_lighten(bg_preview_color, 0.15), false)
	var pressed := _make_stylebox(_lighten(bg_preview_color, 0.25), true)
	var focus := _make_stylebox(_lighten(bg_preview_color, 0.15), true)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", focus)

	btn.add_theme_stylebox_override("checked", pressed)
	btn.add_theme_stylebox_override("checked_hover", pressed)

	return btn

func _make_stylebox(color: Color, accent_border: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2

	if accent_border:
		sb.border_color = Color(0.4, 0.7, 1.0, 0.9)
		sb.set_border_width_all(1)

	return sb

func _lighten(c: Color, amount: float) -> Color:
	return Color(
		minf(c.r + amount, 1.0),
		minf(c.g + amount, 1.0),
		minf(c.b + amount, 1.0),
		c.a
	)

func _apply_bg_color(c: Color) -> void:
	if _preview:
		_preview.bg_color = c

# ============================================================
# PUBLIC
# ============================================================

func set_design(design: BayterekNodeDesign) -> void:
	_preview.set_design(design)
	_preview.show_nine_patch_guides = true
	if design:
		var computed: Vector2 = design.get_computed_size()
		_design_info.text = "Size: %.0f × %.0f  •  Layers: %d" % [
			computed.x, computed.y, design.get_layer_count()
		]
	else:
		_design_info.text = "(no design selected)"
	_update_zoom_label()

func refresh() -> void:
	if not _preview:
		return
	_preview._apply_texture_filter()
	_preview.queue_redraw()

# ============================================================
# HANDLERS
# ============================================================

func _on_zoom_changed(_zoom: float) -> void:
	_update_zoom_label()

func _update_zoom_label() -> void:
	if not _zoom_label or not _preview:
		return
	var pct: int = int(round(_preview.user_zoom * 100.0))
	_zoom_label.text = "%d%%" % pct