@tool
class_name BayterekInspectorConnections
extends VBoxContainer
## Connections editor for the Node Inspector.

signal changed

var inspector: BayterekTreeEditorInspector

var _sep: HSeparator
var _title: Label
var _empty_label: Label
var _list: VBoxContainer

var _updating_ui: bool = false
var _expanded_ids: Dictionary = {}
var _entries: Dictionary = {}
var _section_state: Dictionary = {}

func _ready() -> void:
	add_theme_constant_override("separation", 4)
	_build_ui()

func _build_ui() -> void:
	_sep = HSeparator.new()
	add_child(_sep)

	_title = Label.new()
	_title.text = "Connections"
	_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	add_child(_title)

	_empty_label = Label.new()
	_empty_label.text = "(No outgoing connections)"
	_empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	add_child(_empty_label)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	add_child(_list)

# ============================================================
# PUBLIC API
# ============================================================

func refresh() -> void:
	_entries.clear()
	for child in _list.get_children():
		child.queue_free()

	if not inspector or not inspector._current_node:
		visible = false
		return

	var out_ids: Array = inspector._current_node.node_data.out_nodes
	if out_ids.is_empty():
		visible = true
		_empty_label.visible = true
		return

	visible = true
	_empty_label.visible = false

	for to_id in out_ids:
		_build_connection_entry(to_id)

# ============================================================
# ENTRY
# ============================================================

func _build_connection_entry(to_id: int) -> void:
	var node: BayterekNodeButton = inspector._current_node
	var line_data = node.node_data.line_data.get(to_id, null)
	if not line_data:
		line_data = BayterekLineData.new()
		node.node_data.line_data[to_id] = line_data

	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 4)
	_list.add_child(block)

	var header_btn := Button.new()
	header_btn.toggle_mode = true
	header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header_btn.custom_minimum_size = Vector2(0, 26)
	block.add_child(header_btn)

	var content_box := VBoxContainer.new()
	content_box.add_theme_constant_override("separation", 6)
	block.add_child(content_box)

	var should_expand: bool = _expanded_ids.get(to_id, false)
	header_btn.button_pressed = should_expand
	content_box.visible = should_expand
	header_btn.text = ("▼ Node %d" % to_id) if should_expand else ("▶ Node %d" % to_id)

	var tid_capture: int = to_id
	var header_capture: Button = header_btn
	var content_capture: VBoxContainer = content_box
	header_btn.toggled.connect(func(pressed: bool):
		content_capture.visible = pressed
		header_capture.text = ("▼ Node %d" % tid_capture) if pressed else ("▶ Node %d" % tid_capture)
		if pressed:
			_expanded_ids[tid_capture] = true
		else:
			_expanded_ids.erase(tid_capture)
	)

	if not _section_state.has(to_id):
		_section_state[to_id] = {
			"style": true,
			"texture": false,
			"arrows": false,
			"advanced": false,
		}

	_entries[to_id] = {}

	var style_body := _make_foldout(content_box, to_id, "style", "Line Style")
	_build_line_style_section(style_body, to_id, line_data)

	var tex_body := _make_foldout(content_box, to_id, "texture", "Texture")
	_build_texture_section(tex_body, to_id, line_data)

	var arrow_body := _make_foldout(content_box, to_id, "arrows", "Arrows")
	_build_arrows_section(arrow_body, to_id, line_data)

	var adv_body := _make_foldout(content_box, to_id, "advanced", "Advanced")
	_build_advanced_section(adv_body, to_id, line_data)

	# --- Bottom button row: Reset + Delete ---
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	content_box.add_child(btn_row)

	var reset_btn := Button.new()
	reset_btn.text = "↺ Reset to Tree Defaults"
	reset_btn.tooltip_text = "Clear all per-connection overrides and restore the tree's connection defaults."
	reset_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	reset_btn.pressed.connect(_on_reset_to_defaults.bind(to_id))
	btn_row.add_child(reset_btn)

	var del_btn := Button.new()
	del_btn.text = "Delete"
	del_btn.tooltip_text = "Remove this connection."
	del_btn.pressed.connect(_on_delete_connection.bind(to_id))
	btn_row.add_child(del_btn)

	_entries[to_id]["header"] = header_btn

# ============================================================
# FOLDOUT BUILDER
# ============================================================

func _make_foldout(parent: VBoxContainer, to_id: int, key: String, title: String) -> VBoxContainer:
	var fold := FoldableContainer.new()
	fold.title = title
	fold.folded = not _section_state[to_id].get(key, false)
	parent.add_child(fold)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	fold.add_child(body)

	fold.folding_changed.connect(func(is_folded: bool) -> void:
		if _section_state.has(to_id):
			_section_state[to_id][key] = not is_folded
	)

	return body

# ============================================================
# SECTION 1 — LINE STYLE
# ============================================================

func _build_line_style_section(body: VBoxContainer, to_id: int, line_data: BayterekLineData) -> void:
	var type_row := _make_labeled_row(body, "Line Type")
	var type_dropdown := _make_dropdown(type_row, ["Straight", "Bezier", "Arc", "Step"])
	type_dropdown.select(int(line_data.line_type))
	type_dropdown.item_selected.connect(_on_line_type_changed.bind(to_id))

	var style_row := _make_labeled_row(body, "Line Style")
	var style_dropdown := _make_dropdown(style_row, ["Solid", "Dashed", "Dotted", "Dash-Dot"])
	style_dropdown.select(int(line_data.line_style))
	style_dropdown.item_selected.connect(_on_line_style_changed.bind(to_id))

	var dash_len_row := _make_labeled_row(body, "Dash Len")
	var dash_len_input := _make_spinbox(dash_len_row, 1, 100, 1, line_data.dash_length)
	dash_len_input.value_changed.connect(_on_dash_length_changed.bind(to_id))
	dash_len_row.visible = (line_data.line_style != BayterekLineData.LineStyle.SOLID)

	var dash_gap_row := _make_labeled_row(body, "Dash Gap")
	var dash_gap_input := _make_spinbox(dash_gap_row, 1, 100, 1, line_data.dash_gap)
	dash_gap_input.value_changed.connect(_on_dash_gap_changed.bind(to_id))
	dash_gap_row.visible = (line_data.line_style != BayterekLineData.LineStyle.SOLID)

	var curve_row := _make_labeled_row(body, "Curve")
	var curve_input := _make_spinbox(curve_row, 0, 500, 1, line_data.curve_height)
	curve_input.value_changed.connect(_on_curve_height_changed.bind(to_id))
	curve_row.visible = (line_data.line_type == BayterekLineData.LineType.BEZIER)

	var step_row := _make_labeled_row(body, "Step")
	var step_input := _make_spinbox(step_row, 8, 500, 1, line_data.step_distance)
	step_input.value_changed.connect(_on_step_distance_changed.bind(to_id))
	step_row.visible = (line_data.line_type == BayterekLineData.LineType.STEP)

	var seg_row := _make_labeled_row(body, "Segments")
	var seg_input := _make_spinbox(seg_row, 2, 64, 1, line_data.segments)
	seg_input.value_changed.connect(_on_segments_changed.bind(to_id))
	seg_row.visible = (
		line_data.line_type == BayterekLineData.LineType.BEZIER
		or line_data.line_type == BayterekLineData.LineType.ARC
	)

	var rev_row := _make_labeled_row(body, "Reversed")
	var rev_check := _make_checkbox(rev_row, line_data.reversed)
	rev_check.toggled.connect(_on_reversed_changed.bind(to_id))
	rev_row.visible = (
		line_data.line_type == BayterekLineData.LineType.BEZIER
		or line_data.line_type == BayterekLineData.LineType.ARC
	)

	_entries[to_id]["style_refs"] = {
		"dash_len_row": dash_len_row,
		"dash_gap_row": dash_gap_row,
		"curve_row": curve_row,
		"step_row": step_row,
		"seg_row": seg_row,
		"rev_row": rev_row,
	}

# ============================================================
# SECTION 2 — TEXTURE
# ============================================================

func _build_texture_section(body: VBoxContainer, to_id: int, line_data: BayterekLineData) -> void:
	var tex_input := BayterekInspectorTextureInput.new()
	tex_input.title = "Line Texture"
	body.add_child(tex_input)
	tex_input.set_texture(line_data.line_texture)
	tex_input.texture_dropped.connect(_on_line_texture_changed.bind(to_id))
	tex_input.cleared.connect(_on_line_texture_cleared.bind(to_id))

	var mode_row := _make_labeled_row(body, "Mode")
	var mode_dropdown := _make_dropdown(mode_row, ["None", "Tile", "Stretch", "Tile Fit Height"])
	mode_dropdown.select(int(line_data.texture_mode))
	mode_dropdown.item_selected.connect(_on_texture_mode_changed.bind(to_id))

	var filter_row := _make_labeled_row(body, "Filter")
	var filter_dd := _make_dropdown(filter_row, ["Inherit", "Linear", "Nearest"])
	var filter_idx: int = clampi(line_data.texture_filter_override, 0, 2)
	filter_dd.select(filter_idx)
	filter_dd.item_selected.connect(_on_texture_filter_changed.bind(to_id))

	var scale_row := _make_labeled_row(body, "Scale")
	var scale_x := _make_spinbox(scale_row, 0.05, 20.0, 0.05, line_data.texture_scale.x)
	scale_x.size_flags_horizontal = SIZE_EXPAND_FILL
	var scale_y := _make_spinbox(scale_row, 0.05, 20.0, 0.05, line_data.texture_scale.y)
	scale_y.size_flags_horizontal = SIZE_EXPAND_FILL
	scale_x.value_changed.connect(_on_texture_scale_pair_changed.bind(to_id, scale_x, scale_y))
	scale_y.value_changed.connect(_on_texture_scale_pair_changed.bind(to_id, scale_x, scale_y))

	var tint_row := _make_labeled_row(body, "Tint")
	var tint_picker := ColorPickerButton.new()
	tint_picker.size_flags_horizontal = SIZE_EXPAND_FILL
	tint_picker.custom_minimum_size = Vector2(0, 24)
	tint_picker.color = line_data.texture_tint
	tint_picker.color_changed.connect(_on_texture_tint_changed.bind(to_id))
	tint_row.add_child(tint_picker)

# ============================================================
# SECTION 3 — ARROWS
# ============================================================

func _build_arrows_section(body: VBoxContainer, to_id: int, line_data: BayterekLineData) -> void:
	var arrow_items: Array = ["None", "Arrow", "T-Bar", "Square", "Circle", "Diamond"]
	var anchor_items: Array = ["Edge (line touches edge)", "Center (line to center)"]

	# ============================================================
	# START ARROW
	# ============================================================
	var start_header := Label.new()
	start_header.text = "Start Arrow"
	start_header.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	body.add_child(start_header)

	var start_style_row := _make_labeled_row(body, "Style")
	var start_arrow_dd := _make_dropdown(start_style_row, arrow_items)
	start_arrow_dd.select(int(line_data.start_arrow))
	start_arrow_dd.item_selected.connect(_on_start_arrow_changed.bind(to_id))

	var start_anchor_row := _make_labeled_row(body, "Anchor")
	var start_anchor_dd := _make_dropdown(start_anchor_row, anchor_items)
	start_anchor_dd.select(int(line_data.start_arrow_anchor))
	start_anchor_dd.item_selected.connect(_on_start_anchor_changed.bind(to_id))

	var start_scale_row := _make_labeled_row(body, "Scale")
	var start_scale_input := _make_spinbox(start_scale_row, 0.05, 20.0, 0.05, line_data.start_arrow_scale)
	start_scale_input.tooltip_text = "Uniform scale for the START arrow (both X and Y)."
	start_scale_input.value_changed.connect(_on_start_arrow_scale_changed.bind(to_id))

	var start_dist_row := _make_labeled_row(body, "Distance")
	var start_dist_input := _make_spinbox(start_dist_row, 0.0, 500.0, 1.0, line_data.start_arrow_distance)
	start_dist_input.tooltip_text = "Gap between the source node edge and the START arrow's node-facing edge, in pixels."
	start_dist_input.value_changed.connect(_on_start_arrow_distance_changed.bind(to_id))

	var start_flip_row := _make_labeled_row(body, "Flip 180°")
	var start_flip_check := _make_checkbox(start_flip_row, line_data.start_arrow_flip)
	start_flip_check.tooltip_text = "Flip the START arrow 180° if the texture was authored pointing backwards."
	start_flip_check.toggled.connect(_on_start_arrow_flip_changed.bind(to_id))

	var start_tint_row := _make_labeled_row(body, "Tint")
	var start_tint_picker := ColorPickerButton.new()
	start_tint_picker.size_flags_horizontal = SIZE_EXPAND_FILL
	start_tint_picker.custom_minimum_size = Vector2(0, 24)
	start_tint_picker.color = line_data.start_arrow_tint
	start_tint_picker.color_changed.connect(_on_start_arrow_tint_changed.bind(to_id))
	start_tint_row.add_child(start_tint_picker)

	var start_tex := BayterekInspectorTextureInput.new()
	start_tex.title = "Start Tex"
	body.add_child(start_tex)
	start_tex.set_texture(line_data.arrow_texture_start)
	start_tex.texture_dropped.connect(_on_start_arrow_tex_changed.bind(to_id))
	start_tex.cleared.connect(_on_start_arrow_tex_cleared.bind(to_id))

	# ============================================================
	# END ARROW
	# ============================================================
	body.add_child(HSeparator.new())

	var end_header := Label.new()
	end_header.text = "End Arrow"
	end_header.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	body.add_child(end_header)

	var end_style_row := _make_labeled_row(body, "Style")
	var end_arrow_dd := _make_dropdown(end_style_row, arrow_items)
	end_arrow_dd.select(int(line_data.end_arrow))
	end_arrow_dd.item_selected.connect(_on_end_arrow_changed.bind(to_id))

	var end_anchor_row := _make_labeled_row(body, "Anchor")
	var end_anchor_dd := _make_dropdown(end_anchor_row, anchor_items)
	end_anchor_dd.select(int(line_data.end_arrow_anchor))
	end_anchor_dd.item_selected.connect(_on_end_anchor_changed.bind(to_id))

	var end_scale_row := _make_labeled_row(body, "Scale")
	var end_scale_input := _make_spinbox(end_scale_row, 0.05, 20.0, 0.05, line_data.end_arrow_scale)
	end_scale_input.tooltip_text = "Uniform scale for the END arrow (both X and Y)."
	end_scale_input.value_changed.connect(_on_end_arrow_scale_changed.bind(to_id))

	var end_dist_row := _make_labeled_row(body, "Distance")
	var end_dist_input := _make_spinbox(end_dist_row, 0.0, 500.0, 1.0, line_data.end_arrow_distance)
	end_dist_input.tooltip_text = "Gap between the target node edge and the END arrow's node-facing edge, in pixels."
	end_dist_input.value_changed.connect(_on_end_arrow_distance_changed.bind(to_id))

	var end_flip_row := _make_labeled_row(body, "Flip 180°")
	var end_flip_check := _make_checkbox(end_flip_row, line_data.end_arrow_flip)
	end_flip_check.tooltip_text = "Flip the END arrow 180° if the texture was authored pointing backwards."
	end_flip_check.toggled.connect(_on_end_arrow_flip_changed.bind(to_id))

	var end_tint_row := _make_labeled_row(body, "Tint")
	var end_tint_picker := ColorPickerButton.new()
	end_tint_picker.size_flags_horizontal = SIZE_EXPAND_FILL
	end_tint_picker.custom_minimum_size = Vector2(0, 24)
	end_tint_picker.color = line_data.end_arrow_tint
	end_tint_picker.color_changed.connect(_on_end_arrow_tint_changed.bind(to_id))
	end_tint_row.add_child(end_tint_picker)

	var end_tex := BayterekInspectorTextureInput.new()
	end_tex.title = "End Tex"
	body.add_child(end_tex)
	end_tex.set_texture(line_data.arrow_texture_end)
	end_tex.texture_dropped.connect(_on_end_arrow_tex_changed.bind(to_id))
	end_tex.cleared.connect(_on_end_arrow_tex_cleared.bind(to_id))

	# ============================================================
	# SHARED
	# ============================================================
	body.add_child(HSeparator.new())

	var afilter_row := _make_labeled_row(body, "Filter")
	var afilter_dd := _make_dropdown(afilter_row, ["Inherit", "Linear", "Nearest"])
	var afilter_idx: int = clampi(line_data.arrow_texture_filter_override, 0, 2)
	afilter_dd.select(afilter_idx)
	afilter_dd.item_selected.connect(_on_arrow_texture_filter_changed.bind(to_id))

# ============================================================
# SECTION 4 — ADVANCED
# ============================================================

func _build_advanced_section(body: VBoxContainer, to_id: int, line_data: BayterekLineData) -> void:
	var color_row := _make_labeled_row(body, "Line Color")
	var color_picker := ColorPickerButton.new()
	color_picker.size_flags_horizontal = SIZE_EXPAND_FILL
	color_picker.custom_minimum_size = Vector2(0, 24)
	color_picker.color = line_data.color
	color_picker.color_changed.connect(_on_color_changed.bind(to_id))
	color_row.add_child(color_picker)

	var thick_row := _make_labeled_row(body, "Thickness")
	var thick_input := _make_spinbox(thick_row, 0.5, 64.0, 0.5, line_data.thickness)
	thick_input.value_changed.connect(_on_thickness_changed.bind(to_id))

	var flat_row := _make_labeled_row(body, "Flat Mode")
	var flat_check := _make_checkbox(flat_row, line_data.flat_mode)
	flat_check.tooltip_text = "Draw lines with a hard single-color fill (no edge gradient)."
	flat_check.toggled.connect(_on_flat_mode_changed.bind(to_id))

	var aa_row := _make_labeled_row(body, "Antialiasing")
	var aa_check := _make_checkbox(aa_row, line_data.smooth_antialiasing)
	aa_check.tooltip_text = "Smooth the line edges. Ignored in flat mode."
	aa_check.toggled.connect(_on_antialiasing_changed.bind(to_id))

	if not _entries.has(to_id):
		_entries[to_id] = {}
	_entries[to_id]["advanced_refs"] = {
		"color_picker": color_picker,
		"thick_input": thick_input,
		"flat_check": flat_check,
		"aa_check": aa_check,
	}

	_update_advanced_enabled(to_id)

# ============================================================
# UI HELPERS
# ============================================================

func _make_labeled_row(parent: Control, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(110, 0)
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)

	return row

func _make_dropdown(parent: HBoxContainer, items: Array) -> OptionButton:
	var dd := OptionButton.new()
	dd.size_flags_horizontal = SIZE_EXPAND_FILL
	for i in items.size():
		dd.add_item(String(items[i]), i)
	parent.add_child(dd)
	return dd

func _make_spinbox(parent: HBoxContainer, min_v: float, max_v: float, step: float, value: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.size_flags_horizontal = SIZE_EXPAND_FILL
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.value = value
	if step >= 1.0 and is_equal_approx(step, floor(step)):
		spin.rounded = true
	parent.add_child(spin)
	return spin

func _make_checkbox(parent: HBoxContainer, checked: bool) -> CheckBox:
	var check := CheckBox.new()
	check.text = "On"
	check.button_pressed = checked
	check.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(check)
	return check

# ============================================================
# CONDITIONAL VISIBILITY
# ============================================================

func _update_entry_visibility(to_id: int) -> void:
	if not _entries.has(to_id):
		return
	var e: Dictionary = _entries[to_id]
	if not e.has("style_refs"):
		return

	var refs: Dictionary = e["style_refs"]
	var line_data = _get_line_data(to_id)
	if not line_data:
		return

	var line_type: int = int(line_data.line_type)
	var line_style: int = int(line_data.line_style)

	if refs.has("dash_len_row"):
		refs["dash_len_row"].visible = (line_style != BayterekLineData.LineStyle.SOLID)
	if refs.has("dash_gap_row"):
		refs["dash_gap_row"].visible = (line_style != BayterekLineData.LineStyle.SOLID)
	if refs.has("curve_row"):
		refs["curve_row"].visible = (line_type == BayterekLineData.LineType.BEZIER)
	if refs.has("step_row"):
		refs["step_row"].visible = (line_type == BayterekLineData.LineType.STEP)
	if refs.has("seg_row"):
		refs["seg_row"].visible = (
			line_type == BayterekLineData.LineType.BEZIER
			or line_type == BayterekLineData.LineType.ARC
		)
	if refs.has("rev_row"):
		refs["rev_row"].visible = (
			line_type == BayterekLineData.LineType.BEZIER
			or line_type == BayterekLineData.LineType.ARC
		)

# ============================================================
# ADVANCED ENABLED / DISABLED
# ============================================================

func _update_advanced_enabled(to_id: int) -> void:
	if not _entries.has(to_id):
		return
	var e: Dictionary = _entries[to_id]
	if not e.has("advanced_refs"):
		return

	var line_data = _get_line_data(to_id)
	if not line_data:
		return

	var refs: Dictionary = e["advanced_refs"]

	var is_textured: bool = (
		line_data.texture_mode != BayterekLineData.TextureMode.NONE
		and line_data.line_texture != null
	)

	var enabled: bool = not is_textured

	if refs.has("color_picker"):
		refs["color_picker"].disabled = not enabled
	if refs.has("thick_input"):
		refs["thick_input"].editable = enabled
	if refs.has("flat_check"):
		refs["flat_check"].disabled = not enabled
	if refs.has("aa_check"):
		refs["aa_check"].disabled = not enabled

# ============================================================
# HANDLERS
# ============================================================

func _get_line_data(to_id: int) -> BayterekLineData:
	if not inspector._current_node:
		return null
	return inspector._current_node.node_data.line_data.get(to_id, null)

func _refresh_line(to_id: int) -> void:
	if inspector.editor and inspector.editor.tree_view:
		inspector.editor.tree_view.connections_service.refresh_line(inspector._current_node.id, to_id)

func _notify_changed() -> void:
	if inspector.editor:
		inspector.editor.set_dirty(true)
	changed.emit()

func _on_line_type_changed(index: int, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.line_type = index as BayterekLineData.LineType
	_refresh_line(to_id)
	_update_entry_visibility(to_id)
	_notify_changed()

func _on_line_style_changed(index: int, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.line_style = index as BayterekLineData.LineStyle
	_refresh_line(to_id)
	_update_entry_visibility(to_id)
	_notify_changed()

func _on_dash_length_changed(value: float, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.dash_length = value
	_refresh_line(to_id)
	_notify_changed()

func _on_dash_gap_changed(value: float, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.dash_gap = value
	_refresh_line(to_id)
	_notify_changed()

func _on_curve_height_changed(value: float, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.curve_height = value
	_refresh_line(to_id)
	_notify_changed()

func _on_step_distance_changed(value: float, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.step_distance = value
	_refresh_line(to_id)
	_notify_changed()

func _on_segments_changed(value: float, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.segments = int(value)
	_refresh_line(to_id)
	_notify_changed()

func _on_reversed_changed(pressed: bool, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.reversed = pressed
	_refresh_line(to_id)
	_notify_changed()

func _on_line_texture_changed(path: String, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	if path.is_empty():
		return
	var tex: Texture2D = load(path) as Texture2D
	if not tex:
		return
	line_data.line_texture = tex
	if line_data.texture_mode == BayterekLineData.TextureMode.NONE:
		line_data.texture_mode = BayterekLineData.TextureMode.TILE
	_refresh_line(to_id)
	_update_advanced_enabled(to_id)
	_notify_changed()

func _on_line_texture_cleared(to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.line_texture = null
	line_data.texture_mode = BayterekLineData.TextureMode.NONE
	_refresh_line(to_id)
	_update_advanced_enabled(to_id)
	_notify_changed()

func _on_texture_mode_changed(index: int, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.texture_mode = index as BayterekLineData.TextureMode
	_refresh_line(to_id)
	_update_advanced_enabled(to_id)
	_notify_changed()

func _on_texture_filter_changed(index: int, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.texture_filter_override = index
	_refresh_line(to_id)
	_notify_changed()

func _on_texture_scale_pair_changed(_value: float, to_id: int, sx: SpinBox, sy: SpinBox) -> void:
	if _updating_ui: return
	if not is_instance_valid(sx) or not is_instance_valid(sy):
		return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.texture_scale = Vector2(sx.value, sy.value)
	_refresh_line(to_id)
	_notify_changed()

func _on_texture_tint_changed(color: Color, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.texture_tint = color
	_refresh_line(to_id)
	_notify_changed()

func _on_start_arrow_changed(index: int, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.start_arrow = index as BayterekLineData.ArrowStyle
	_refresh_line(to_id)
	_notify_changed()

func _on_end_arrow_changed(index: int, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.end_arrow = index as BayterekLineData.ArrowStyle
	_refresh_line(to_id)
	_notify_changed()

func _on_start_anchor_changed(index: int, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.start_arrow_anchor = index as BayterekLineData.ArrowAnchor
	_refresh_line(to_id)
	_notify_changed()

func _on_end_anchor_changed(index: int, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.end_arrow_anchor = index as BayterekLineData.ArrowAnchor
	_refresh_line(to_id)
	_notify_changed()

func _on_start_arrow_scale_changed(value: float, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.start_arrow_scale = value
	_refresh_line(to_id)
	_notify_changed()

func _on_end_arrow_scale_changed(value: float, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.end_arrow_scale = value
	_refresh_line(to_id)
	_notify_changed()

func _on_start_arrow_distance_changed(value: float, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.start_arrow_distance = value
	_refresh_line(to_id)
	_notify_changed()

func _on_end_arrow_distance_changed(value: float, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.end_arrow_distance = value
	_refresh_line(to_id)
	_notify_changed()

func _on_start_arrow_flip_changed(pressed: bool, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.start_arrow_flip = pressed
	_refresh_line(to_id)
	_notify_changed()

func _on_end_arrow_flip_changed(pressed: bool, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.end_arrow_flip = pressed
	_refresh_line(to_id)
	_notify_changed()

func _on_start_arrow_tint_changed(color: Color, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.start_arrow_tint = color
	_refresh_line(to_id)
	_notify_changed()

func _on_end_arrow_tint_changed(color: Color, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.end_arrow_tint = color
	_refresh_line(to_id)
	_notify_changed()

func _on_start_arrow_tex_changed(path: String, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	if path.is_empty():
		return
	var tex: Texture2D = load(path) as Texture2D
	if not tex:
		return
	line_data.arrow_texture_start = tex
	_refresh_line(to_id)
	_notify_changed()

func _on_start_arrow_tex_cleared(to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.arrow_texture_start = null
	_refresh_line(to_id)
	_notify_changed()

func _on_end_arrow_tex_changed(path: String, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	if path.is_empty():
		return
	var tex: Texture2D = load(path) as Texture2D
	if not tex:
		return
	line_data.arrow_texture_end = tex
	_refresh_line(to_id)
	_notify_changed()

func _on_end_arrow_tex_cleared(to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.arrow_texture_end = null
	_refresh_line(to_id)
	_notify_changed()

func _on_arrow_texture_filter_changed(index: int, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.arrow_texture_filter_override = index
	_refresh_line(to_id)
	_notify_changed()

func _on_color_changed(color: Color, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.color = color
	line_data.set_overridden("color", true)
	_refresh_line(to_id)
	_notify_changed()

func _on_thickness_changed(value: float, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.thickness = value
	_refresh_line(to_id)
	_notify_changed()

func _on_flat_mode_changed(pressed: bool, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.flat_mode = pressed
	_refresh_line(to_id)
	_notify_changed()

func _on_antialiasing_changed(pressed: bool, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.smooth_antialiasing = pressed
	_refresh_line(to_id)
	_notify_changed()

# --- Reset to Tree Defaults ---

func _on_reset_to_defaults(to_id: int) -> void:
	if not inspector._current_node: return
	if not inspector.editor: return
	if not inspector.editor.tree: return

	var line_data = _get_line_data(to_id)
	if not line_data:
		return

	var tree: BayterekTree = inspector.editor.tree

	line_data.clear_all_overrides()
	tree.apply_connection_defaults(line_data, true)

	_refresh_line(to_id)
	refresh()
	_notify_changed()

# --- Delete ---

func _on_delete_connection(to_id: int) -> void:
	if not inspector._current_node: return
	if not inspector.editor or not inspector.editor.tree_view: return
	inspector.editor.tree_view.connections_service.remove_connection(inspector._current_node.id, to_id)

	_expanded_ids.erase(to_id)
	_section_state.erase(to_id)
	refresh()
	_notify_changed()