@tool
class_name BayterekLayerTransformForm
extends VBoxContainer
## Transform editor for a single BayterekLayerTransform.

signal changed

const PIVOT_GRID_SIZE := 3

var _transform: BayterekLayerTransform = null
var _design: BayterekNodeDesign = null
var _layer_id: String = ""
var _updating: bool = false

# --- Position ---
var _pos_x: SpinBox
var _pos_y: SpinBox
var _pos_row: HBoxContainer

# --- Size ---
var _size_x: SpinBox
var _size_y: SpinBox

# --- Scale ---
var _scale_x: SpinBox
var _scale_y: SpinBox
var _scale_row: HBoxContainer

# --- Flip ---
var _flip_x_check: CheckBox
var _flip_y_check: CheckBox
var _flip_row: HBoxContainer

# --- Rotation ---
var _rotation: SpinBox
var _rotation_row: HBoxContainer

# --- Skew ---
var _skew_x: SpinBox
var _skew_y: SpinBox

# --- Pivot ---
var _pivot_buttons: Array[Button] = []
var _pivot_custom_x: SpinBox
var _pivot_custom_y: SpinBox
var _pivot_custom_panel: HBoxContainer

# --- Scale from pivot ---
var _scale_from_pivot_check: CheckBox
var _scale_from_pivot_row: HBoxContainer

var _btn_group: ButtonGroup = null

var _ui_ready: bool = false
var _exports_bound: bool = false

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_build_ui()
	_ui_ready = true
	if _transform:
		_refresh_from_data()
		_bind_exports()

func _build_ui() -> void:
	# --- Position ---
	var pos_row_data := _make_pair_row_container("Position", "X", "Y",
		-99999.0, 99999.0, 1.0, true, 0.0, "")
	_pos_row = pos_row_data["row"]
	_pos_x = pos_row_data["a"]
	_pos_y = pos_row_data["b"]
	_pos_x.value_changed.connect(_on_pos_changed)
	_pos_y.value_changed.connect(_on_pos_changed)

	# --- Size ---
	var size_row_data := _make_pair_row_container("Size", "W", "H",
		0.0, 99999.0, 1.0, true, 0.0, "")
	_size_x = size_row_data["a"]
	_size_y = size_row_data["b"]
	_size_x.value_changed.connect(_on_size_changed)
	_size_y.value_changed.connect(_on_size_changed)

	# --- Scale ---
	var scale_row_data := _make_pair_row_container("Scale", "X", "Y",
		0.01, 100.0, 0.01, false, 1.0, "")
	_scale_row = scale_row_data["row"]
	_scale_x = scale_row_data["a"]
	_scale_y = scale_row_data["b"]
	_scale_x.value_changed.connect(_on_scale_changed)
	_scale_y.value_changed.connect(_on_scale_changed)

	# --- Flip ---
	_flip_row = HBoxContainer.new()
	_flip_row.add_theme_constant_override("separation", 4)
	add_child(_flip_row)

	var flip_label := Label.new()
	flip_label.text = "Flip"
	flip_label.custom_minimum_size = Vector2(80, 0)
	_flip_row.add_child(flip_label)

	_flip_x_check = CheckBox.new()
	_flip_x_check.text = "X"
	_flip_x_check.size_flags_horizontal = SIZE_EXPAND_FILL
	_flip_x_check.tooltip_text = "Mirror horizontally"
	_flip_x_check.toggled.connect(_on_flip_toggled)
	_flip_row.add_child(_flip_x_check)

	_flip_y_check = CheckBox.new()
	_flip_y_check.text = "Y"
	_flip_y_check.size_flags_horizontal = SIZE_EXPAND_FILL
	_flip_y_check.tooltip_text = "Mirror vertically"
	_flip_y_check.toggled.connect(_on_flip_toggled)
	_flip_row.add_child(_flip_y_check)

	# --- Rotation ---
	_rotation_row = HBoxContainer.new()
	add_child(_rotation_row)
	var rot_label := Label.new()
	rot_label.text = "Rotation"
	rot_label.custom_minimum_size = Vector2(80, 0)
	_rotation_row.add_child(rot_label)
	_rotation = SpinBox.new()
	_rotation.size_flags_horizontal = SIZE_EXPAND_FILL
	_rotation.min_value = -3600.0
	_rotation.max_value = 3600.0
	_rotation.step = 1.0
	_rotation.suffix = "°"
	_rotation.value_changed.connect(_on_rotation_changed)
	_rotation_row.add_child(_rotation)

	# --- Skew ---
	var skew_row_data := _make_pair_row_container("Skew", "X", "Y",
		-89.0, 89.0, 1.0, true, 0.0, "°")
	_skew_x = skew_row_data["a"]
	_skew_y = skew_row_data["b"]
	_skew_x.value_changed.connect(_on_skew_changed)
	_skew_y.value_changed.connect(_on_skew_changed)

	# --- Pivot ---
	var pivot_header := Label.new()
	pivot_header.text = "Pivot"
	pivot_header.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	add_child(pivot_header)

	var pivot_grid := GridContainer.new()
	pivot_grid.columns = PIVOT_GRID_SIZE
	pivot_grid.add_theme_constant_override("h_separation", 2)
	pivot_grid.add_theme_constant_override("v_separation", 2)
	add_child(pivot_grid)

	for i in 9:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(28, 28)
		btn.button_group = _get_or_make_group()
		btn.pressed.connect(_on_pivot_preset_pressed.bind(i))
		pivot_grid.add_child(btn)
		_pivot_buttons.append(btn)

	_pivot_custom_panel = HBoxContainer.new()
	add_child(_pivot_custom_panel)

	var custom_label := Label.new()
	custom_label.text = "Custom"
	custom_label.custom_minimum_size = Vector2(80, 0)
	_pivot_custom_panel.add_child(custom_label)

	var custom_btn := Button.new()
	custom_btn.text = "Custom"
	custom_btn.toggle_mode = true
	custom_btn.button_group = _get_or_make_group()
	custom_btn.pressed.connect(_on_pivot_custom_pressed)
	_pivot_custom_panel.add_child(custom_btn)
	_pivot_buttons.append(custom_btn)

	_pivot_custom_x = SpinBox.new()
	_pivot_custom_x.size_flags_horizontal = SIZE_EXPAND_FILL
	_pivot_custom_x.min_value = 0.0
	_pivot_custom_x.max_value = 1.0
	_pivot_custom_x.step = 0.01
	_pivot_custom_x.value_changed.connect(_on_custom_pivot_changed)
	_pivot_custom_panel.add_child(_pivot_custom_x)

	_pivot_custom_y = SpinBox.new()
	_pivot_custom_y.size_flags_horizontal = SIZE_EXPAND_FILL
	_pivot_custom_y.min_value = 0.0
	_pivot_custom_y.max_value = 1.0
	_pivot_custom_y.step = 0.01
	_pivot_custom_y.value_changed.connect(_on_custom_pivot_changed)
	_pivot_custom_panel.add_child(_pivot_custom_y)

	# --- Scale from pivot ---
	_scale_from_pivot_row = HBoxContainer.new()
	_scale_from_pivot_row.add_theme_constant_override("separation", 4)
	add_child(_scale_from_pivot_row)

	var sfp_label := Label.new()
	sfp_label.text = "Scale from Pivot"
	sfp_label.size_flags_horizontal = SIZE_EXPAND_FILL
	sfp_label.tooltip_text = "When ON, Position is the pivot point."
	sfp_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_scale_from_pivot_row.add_child(sfp_label)

	_scale_from_pivot_check = CheckBox.new()
	_scale_from_pivot_check.text = "On"
	_scale_from_pivot_check.toggled.connect(_on_scale_from_pivot_toggled)
	_scale_from_pivot_row.add_child(_scale_from_pivot_check)

func _get_or_make_group() -> ButtonGroup:
	if not _btn_group:
		_btn_group = ButtonGroup.new()
	return _btn_group

func _make_pair_row_container(
	label_text: String,
	axis_a: String,
	axis_b: String,
	min_v: float,
	max_v: float,
	step_v: float,
	rounded_v: bool,
	initial_v: float,
	suffix_v: String
) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(80, 0)
	row.add_child(label)

	var a_label := Label.new()
	a_label.text = axis_a
	a_label.custom_minimum_size = Vector2(20, 0)
	a_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	row.add_child(a_label)

	var spin_a := SpinBox.new()
	spin_a.size_flags_horizontal = SIZE_EXPAND_FILL
	spin_a.min_value = min_v
	spin_a.max_value = max_v
	spin_a.step = step_v
	spin_a.rounded = rounded_v
	spin_a.allow_lesser = true
	spin_a.allow_greater = true
	if not suffix_v.is_empty():
		spin_a.suffix = suffix_v
	spin_a.value = initial_v
	row.add_child(spin_a)

	var b_label := Label.new()
	b_label.text = axis_b
	b_label.custom_minimum_size = Vector2(20, 0)
	b_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.4))
	row.add_child(b_label)

	var spin_b := SpinBox.new()
	spin_b.size_flags_horizontal = SIZE_EXPAND_FILL
	spin_b.min_value = min_v
	spin_b.max_value = max_v
	spin_b.step = step_v
	spin_b.rounded = rounded_v
	spin_b.allow_lesser = true
	spin_b.allow_greater = true
	if not suffix_v.is_empty():
		spin_b.suffix = suffix_v
	spin_b.value = initial_v
	row.add_child(spin_b)

	return {"row": row, "a": spin_a, "b": spin_b}

func set_transform(t: BayterekLayerTransform, design: BayterekNodeDesign = null, layer_id: String = "") -> void:
	_transform = t
	_design = design

	if _layer_id != layer_id:
		_exports_bound = false
	_layer_id = layer_id

	if _ui_ready:
		_refresh_from_data()
		_bind_exports()

func _bind_exports() -> void:
	if _exports_bound:
		return
	if _layer_id.is_empty():
		return
	if not _design:
		return

	BayterekExportHelper.make_exportable(_pos_row,
		"layers.%s.transform.position" % _layer_id, _design, _on_export_changed)
	BayterekExportHelper.make_exportable(_scale_row,
		"layers.%s.transform.scale" % _layer_id, _design, _on_export_changed)
	BayterekExportHelper.make_exportable(_flip_row,
		"layers.%s.transform.flip_x" % _layer_id, _design, _on_export_changed)
	BayterekExportHelper.make_exportable(_rotation_row,
		"layers.%s.transform.rotation" % _layer_id, _design, _on_export_changed)
	BayterekExportHelper.make_exportable(_scale_from_pivot_row,
		"layers.%s.transform.scale_from_pivot" % _layer_id, _design, _on_export_changed)

	_exports_bound = true

func _refresh_export_markers() -> void:
	if not _design or _layer_id.is_empty():
		return
	for child in get_children():
		if child is Control:
			BayterekExportHelper.refresh_row(child)

func _refresh_from_data() -> void:
	if not _transform:
		return
	if not _ui_ready:
		return
	if not _pos_x or not _pos_y or not _size_x or not _size_y or not _rotation:
		return
	if not _scale_x or not _scale_y:
		return
	if not _flip_x_check or not _flip_y_check:
		return
	if not _skew_x or not _skew_y:
		return
	if not _pivot_custom_x or not _pivot_custom_y:
		return
	if _pivot_buttons.size() < 10:
		return
	if not _scale_from_pivot_check:
		return

	_updating = true

	_pos_x.set_value_no_signal(_transform.position.x)
	_pos_y.set_value_no_signal(_transform.position.y)
	_size_x.set_value_no_signal(_transform.size.x)
	_size_y.set_value_no_signal(_transform.size.y)
	_scale_x.set_value_no_signal(_transform.scale.x)
	_scale_y.set_value_no_signal(_transform.scale.y)
	_flip_x_check.button_pressed = _transform.flip_x
	_flip_y_check.button_pressed = _transform.flip_y
	_rotation.set_value_no_signal(_transform.rotation)
	_skew_x.set_value_no_signal(_transform.skew.x)
	_skew_y.set_value_no_signal(_transform.skew.y)
	_scale_from_pivot_check.button_pressed = _transform.scale_from_pivot

	var idx: int = int(_transform.pivot_mode)
	if idx >= 0 and idx < 9:
		if _pivot_buttons[idx]:
			_pivot_buttons[idx].button_pressed = true
	elif _pivot_buttons.size() > 9:
		if _pivot_buttons[9]:
			_pivot_buttons[9].button_pressed = true

	var custom_visible: bool = (_transform.pivot_mode == BayterekLayerTransform.PivotMode.CUSTOM)
	_pivot_custom_x.visible = custom_visible
	_pivot_custom_y.visible = custom_visible
	_pivot_custom_x.set_value_no_signal(_transform.pivot.x)
	_pivot_custom_y.set_value_no_signal(_transform.pivot.y)

	_updating = false

func _on_pos_changed(_v: float) -> void:
	if _updating or not _transform: return
	_transform.position = Vector2(_pos_x.value, _pos_y.value)
	changed.emit()

func _on_size_changed(_v: float) -> void:
	if _updating or not _transform: return
	_transform.size = Vector2(_size_x.value, _size_y.value)
	changed.emit()

func _on_scale_changed(_v: float) -> void:
	if _updating or not _transform: return
	var new_scale := Vector2(_scale_x.value, _scale_y.value)
	if new_scale.x <= 0.0:
		new_scale.x = 0.01
	if new_scale.y <= 0.0:
		new_scale.y = 0.01
	_transform.scale = new_scale
	changed.emit()

func _on_flip_toggled(_pressed: bool) -> void:
	if _updating or not _transform: return
	_transform.flip_x = _flip_x_check.button_pressed
	_transform.flip_y = _flip_y_check.button_pressed
	changed.emit()

func _on_rotation_changed(v: float) -> void:
	if _updating or not _transform: return
	_transform.rotation = v
	changed.emit()

func _on_skew_changed(_v: float) -> void:
	if _updating or not _transform: return
	_transform.skew = Vector2(_skew_x.value, _skew_y.value)
	changed.emit()

func _on_pivot_preset_pressed(index: int) -> void:
	if _updating or not _transform: return
	_transform.pivot_mode = index as BayterekLayerTransform.PivotMode
	var custom_visible: bool = (index == BayterekLayerTransform.PivotMode.CUSTOM)
	_pivot_custom_x.visible = custom_visible
	_pivot_custom_y.visible = custom_visible
	changed.emit()

func _on_pivot_custom_pressed() -> void:
	if _updating or not _transform: return
	_transform.pivot_mode = BayterekLayerTransform.PivotMode.CUSTOM
	_pivot_custom_x.visible = true
	_pivot_custom_y.visible = true
	_pivot_custom_x.set_value_no_signal(_transform.pivot.x)
	_pivot_custom_y.set_value_no_signal(_transform.pivot.y)
	changed.emit()

func _on_custom_pivot_changed(_v: float) -> void:
	if _updating or not _transform: return
	_transform.pivot = Vector2(_pivot_custom_x.value, _pivot_custom_y.value)
	changed.emit()

func _on_scale_from_pivot_toggled(pressed: bool) -> void:
	if _updating or not _transform: return
	_transform.scale_from_pivot = pressed
	changed.emit()

func _on_export_changed(_field_path: String) -> void:
	if _design:
		BayterekDesignService.save_design(_design)
	changed.emit()