@tool
class_name BayterekLayerPreviewPanel
extends VBoxContainer
## Right-column large preview panel with zoom controls.

var _preview: BayterekLayerPreview
var _design_info: Label
var _zoom_label: Label

func _ready() -> void:
	add_theme_constant_override("separation", 4)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	_build_ui()

func _build_ui() -> void:
	# --- Header row: title + zoom controls ---
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 4)
	add_child(header_row)

	var header := Label.new()
	header.text = "Preview"
	header.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	header.size_flags_horizontal = SIZE_EXPAND_FILL
	header_row.add_child(header)

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

	# --- Big preview ---
	_preview = BayterekLayerPreview.new()
	_preview.size_flags_horizontal = SIZE_EXPAND_FILL
	_preview.size_flags_vertical = SIZE_EXPAND_FILL
	_preview.custom_minimum_size = Vector2(260, 260)
	_preview.zoom_changed.connect(_on_zoom_changed)
	add_child(_preview)

	# --- Info line: design info + zoom % ---
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

# ============================================================
# PUBLIC
# ============================================================

func set_design(design: BayterekNodeDesign) -> void:
	_preview.set_design(design)
	if design:
		_design_info.text = "Size: %.0f × %.0f  •  Layers: %d" % [
			design.design_size.x, design.design_size.y, design.get_layer_count()
		]
	else:
		_design_info.text = "(no design selected)"
	_update_zoom_label()

func refresh() -> void:
	_preview.queue_redraw()

# ============================================================
# HANDLERS
# ============================================================

func _on_zoom_changed(zoom: float) -> void:
	_update_zoom_label()

func _update_zoom_label() -> void:
	if not _zoom_label or not _preview:
		return
	var pct: int = int(round(_preview.user_zoom * 100.0))
	_zoom_label.text = "%d%%" % pct