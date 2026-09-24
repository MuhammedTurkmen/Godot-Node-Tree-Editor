@tool
class_name BayterekInspectorConnections
extends VBoxContainer
## Connections editor for the Node Inspector.
##
## Renders the outgoing connections of the current node and lets the
## user edit each one's `BayterekLineData`: type, style, curve, dash
## pattern, arrows, etc.
##
## Owned by BayterekTreeEditorInspector.

signal changed

var inspector: BayterekTreeEditorInspector

# UI
var _sep: HSeparator
var _title: Label
var _empty_label: Label
var _list: VBoxContainer

var _updating_ui: bool = false

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
	block.add_theme_constant_override("separation", 2)
	_list.add_child(block)

	var header_btn := Button.new()
	header_btn.text = "▶ Node %d" % to_id
	header_btn.toggle_mode = true
	header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header_btn.custom_minimum_size = Vector2(0, 24)
	block.add_child(header_btn)

	var content_box := VBoxContainer.new()
	content_box.visible = false
	content_box.add_theme_constant_override("separation", 2)
	block.add_child(content_box)

	var tid_capture: int = to_id
	var header_capture: Button = header_btn
	var content_capture: VBoxContainer = content_box
	header_btn.toggled.connect(func(pressed: bool):
		content_capture.visible = pressed
		header_capture.text = ("▼ Node %d" % tid_capture) if pressed else ("▶ Node %d" % tid_capture)
	)

	# Line type
	var type_row := HBoxContainer.new()
	content_box.add_child(type_row)
	var type_label := Label.new()
	type_label.text = "Line Type"
	type_label.custom_minimum_size = Vector2(90, 0)
	type_row.add_child(type_label)

	var type_dropdown := OptionButton.new()
	type_dropdown.size_flags_horizontal = SIZE_EXPAND_FILL
	type_dropdown.add_item("Straight", 0)
	type_dropdown.add_item("Bezier", 1)
	type_dropdown.add_item("Arc", 2)
	type_dropdown.add_item("Step", 3)
	type_dropdown.select(int(line_data.line_type))
	type_dropdown.item_selected.connect(_on_line_type_changed.bind(to_id))
	type_row.add_child(type_dropdown)

	# Line style
	var style_row := HBoxContainer.new()
	content_box.add_child(style_row)
	var style_label := Label.new()
	style_label.text = "Line Style"
	style_label.custom_minimum_size = Vector2(90, 0)
	style_row.add_child(style_label)

	var style_dropdown := OptionButton.new()
	style_dropdown.size_flags_horizontal = SIZE_EXPAND_FILL
	style_dropdown.add_item("Solid", 0)
	style_dropdown.add_item("Dashed", 1)
	style_dropdown.add_item("Dotted", 2)
	style_dropdown.add_item("Dash-Dot", 3)
	style_dropdown.select(int(line_data.line_style))
	style_dropdown.item_selected.connect(_on_line_style_changed.bind(to_id))
	style_row.add_child(style_dropdown)

	# Dash length
	var dash_len_row := HBoxContainer.new()
	content_box.add_child(dash_len_row)
	var dash_len_label := Label.new()
	dash_len_label.text = "Dash Len"
	dash_len_label.custom_minimum_size = Vector2(90, 0)
	dash_len_row.add_child(dash_len_label)

	var dash_len_input := SpinBox.new()
	dash_len_input.size_flags_horizontal = SIZE_EXPAND_FILL
	dash_len_input.min_value = 1
	dash_len_input.max_value = 100
	dash_len_input.step = 1
	dash_len_input.value = line_data.dash_length
	dash_len_input.value_changed.connect(_on_dash_length_changed.bind(to_id))
	dash_len_row.add_child(dash_len_input)
	dash_len_row.visible = (line_data.line_style != BayterekLineData.LineStyle.SOLID)

	# Dash gap
	var dash_gap_row := HBoxContainer.new()
	content_box.add_child(dash_gap_row)
	var dash_gap_label := Label.new()
	dash_gap_label.text = "Dash Gap"
	dash_gap_label.custom_minimum_size = Vector2(90, 0)
	dash_gap_row.add_child(dash_gap_label)

	var dash_gap_input := SpinBox.new()
	dash_gap_input.size_flags_horizontal = SIZE_EXPAND_FILL
	dash_gap_input.min_value = 1
	dash_gap_input.max_value = 100
	dash_gap_input.step = 1
	dash_gap_input.value = line_data.dash_gap
	dash_gap_input.value_changed.connect(_on_dash_gap_changed.bind(to_id))
	dash_gap_row.add_child(dash_gap_input)
	dash_gap_row.visible = (line_data.line_style != BayterekLineData.LineStyle.SOLID)

	# Curve
	var curve_row := HBoxContainer.new()
	content_box.add_child(curve_row)
	var curve_label := Label.new()
	curve_label.text = "Curve"
	curve_label.custom_minimum_size = Vector2(90, 0)
	curve_row.add_child(curve_label)

	var curve_input := SpinBox.new()
	curve_input.size_flags_horizontal = SIZE_EXPAND_FILL
	curve_input.min_value = 0
	curve_input.max_value = 500
	curve_input.step = 1
	curve_input.value = line_data.curve_height
	curve_input.value_changed.connect(_on_curve_height_changed.bind(to_id))
	curve_row.add_child(curve_input)
	curve_row.visible = (line_data.line_type == BayterekLineData.LineType.BEZIER)

	# Step distance
	var step_row := HBoxContainer.new()
	content_box.add_child(step_row)
	var step_label := Label.new()
	step_label.text = "Step"
	step_label.custom_minimum_size = Vector2(90, 0)
	step_row.add_child(step_label)

	var step_input := SpinBox.new()
	step_input.size_flags_horizontal = SIZE_EXPAND_FILL
	step_input.min_value = 8
	step_input.max_value = 500
	step_input.step = 1
	step_input.value = line_data.step_distance
	step_input.value_changed.connect(_on_step_distance_changed.bind(to_id))
	step_row.add_child(step_input)
	step_row.visible = (line_data.line_type == BayterekLineData.LineType.STEP)

	# Segments
	var seg_row := HBoxContainer.new()
	content_box.add_child(seg_row)
	var seg_label := Label.new()
	seg_label.text = "Segments"
	seg_label.custom_minimum_size = Vector2(90, 0)
	seg_row.add_child(seg_label)

	var seg_input := SpinBox.new()
	seg_input.size_flags_horizontal = SIZE_EXPAND_FILL
	seg_input.min_value = 2
	seg_input.max_value = 64
	seg_input.step = 1
	seg_input.value = line_data.segments
	seg_input.value_changed.connect(_on_segments_changed.bind(to_id))
	seg_row.add_child(seg_input)
	seg_row.visible = (line_data.line_type == BayterekLineData.LineType.BEZIER or line_data.line_type == BayterekLineData.LineType.ARC)

	# Reversed
	var rev_row := HBoxContainer.new()
	content_box.add_child(rev_row)
	var rev_label := Label.new()
	rev_label.text = "Reversed"
	rev_label.custom_minimum_size = Vector2(90, 0)
	rev_row.add_child(rev_label)

	var rev_check := CheckBox.new()
	rev_check.text = "On"
	rev_check.button_pressed = line_data.reversed
	rev_check.toggled.connect(_on_reversed_changed.bind(to_id))
	rev_row.add_child(rev_check)
	rev_row.visible = (line_data.line_type == BayterekLineData.LineType.BEZIER or line_data.line_type == BayterekLineData.LineType.ARC)

	# Start arrow
	var start_arrow_row := HBoxContainer.new()
	content_box.add_child(start_arrow_row)
	var start_arrow_label := Label.new()
	start_arrow_label.text = "Start Arrow"
	start_arrow_label.custom_minimum_size = Vector2(90, 0)
	start_arrow_row.add_child(start_arrow_label)

	var start_arrow_dropdown := OptionButton.new()
	start_arrow_dropdown.size_flags_horizontal = SIZE_EXPAND_FILL
	start_arrow_dropdown.add_item("None", 0)
	start_arrow_dropdown.add_item("Arrow", 1)
	start_arrow_dropdown.add_item("T-Bar", 2)
	start_arrow_dropdown.add_item("Square", 3)
	start_arrow_dropdown.add_item("Circle", 4)
	start_arrow_dropdown.add_item("Diamond", 5)
	start_arrow_dropdown.select(int(line_data.start_arrow))
	start_arrow_dropdown.item_selected.connect(_on_start_arrow_changed.bind(to_id))
	start_arrow_row.add_child(start_arrow_dropdown)

	# End arrow
	var end_arrow_row := HBoxContainer.new()
	content_box.add_child(end_arrow_row)
	var end_arrow_label := Label.new()
	end_arrow_label.text = "End Arrow"
	end_arrow_label.custom_minimum_size = Vector2(90, 0)
	end_arrow_row.add_child(end_arrow_label)

	var end_arrow_dropdown := OptionButton.new()
	end_arrow_dropdown.size_flags_horizontal = SIZE_EXPAND_FILL
	end_arrow_dropdown.add_item("None", 0)
	end_arrow_dropdown.add_item("Arrow", 1)
	end_arrow_dropdown.add_item("T-Bar", 2)
	end_arrow_dropdown.add_item("Square", 3)
	end_arrow_dropdown.add_item("Circle", 4)
	end_arrow_dropdown.add_item("Diamond", 5)
	end_arrow_dropdown.select(int(line_data.end_arrow))
	end_arrow_dropdown.item_selected.connect(_on_end_arrow_changed.bind(to_id))
	end_arrow_row.add_child(end_arrow_dropdown)

	# Arrow size
	var arrow_size_row := HBoxContainer.new()
	content_box.add_child(arrow_size_row)
	var arrow_size_label := Label.new()
	arrow_size_label.text = "Arrow Size"
	arrow_size_label.custom_minimum_size = Vector2(90, 0)
	arrow_size_row.add_child(arrow_size_label)

	var arrow_size_input := SpinBox.new()
	arrow_size_input.size_flags_horizontal = SIZE_EXPAND_FILL
	arrow_size_input.min_value = 2
	arrow_size_input.max_value = 100
	arrow_size_input.step = 1
	arrow_size_input.value = line_data.arrow_size
	arrow_size_input.value_changed.connect(_on_arrow_size_changed.bind(to_id))
	arrow_size_row.add_child(arrow_size_input)
	arrow_size_row.visible = (line_data.start_arrow != BayterekLineData.ArrowStyle.NONE or line_data.end_arrow != BayterekLineData.ArrowStyle.NONE)

	# Delete
	var del_row := HBoxContainer.new()
	content_box.add_child(del_row)
	var del_spacer := Control.new()
	del_spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	del_row.add_child(del_spacer)

	var del_btn := Button.new()
	del_btn.text = "Delete Connection"
	del_btn.pressed.connect(_on_delete_connection.bind(to_id))
	del_row.add_child(del_btn)

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
	refresh()
	_notify_changed()

func _on_line_style_changed(index: int, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.line_style = index as BayterekLineData.LineStyle
	_refresh_line(to_id)
	refresh()
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

func _on_start_arrow_changed(index: int, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.start_arrow = index as BayterekLineData.ArrowStyle
	_refresh_line(to_id)
	refresh()
	_notify_changed()

func _on_end_arrow_changed(index: int, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.end_arrow = index as BayterekLineData.ArrowStyle
	_refresh_line(to_id)
	refresh()
	_notify_changed()

func _on_arrow_size_changed(value: float, to_id: int) -> void:
	if _updating_ui: return
	var line_data = _get_line_data(to_id)
	if not line_data: return
	line_data.arrow_size = value
	_refresh_line(to_id)
	_notify_changed()

func _on_delete_connection(to_id: int) -> void:
	if not inspector._current_node: return
	if not inspector.editor or not inspector.editor.tree_view: return
	inspector.editor.tree_view.connections_service.remove_connection(inspector._current_node.id, to_id)
	refresh()
	_notify_changed()