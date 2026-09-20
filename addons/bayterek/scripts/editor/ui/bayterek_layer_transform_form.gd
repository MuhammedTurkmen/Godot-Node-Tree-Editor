@tool
class_name BayterekLayerTransformForm
extends VBoxContainer
## Transform editor for a single BayterekLayerTransform.

signal changed

const PIVOT_GRID_SIZE := 3

var _transform: BayterekLayerTransform = null
var _updating: bool = false

# --- Position ---
var _pos_x: SpinBox
var _pos_y: SpinBox

# --- Size ---
var _size_x: SpinBox
var _size_y: SpinBox

# --- Rotation ---
var _rotation: SpinBox

# --- Skew ---
var _skew_x: SpinBox
var _skew_y: SpinBox

# --- Pivot ---
var _pivot_buttons: Array[Button] = []
var _pivot_custom_x: SpinBox
var _pivot_custom_y: SpinBox
var _pivot_custom_panel: HBoxContainer

var _btn_group: ButtonGroup = null

## True when _build_ui() has fully completed.
var _ui_ready: bool = false

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_build_ui()
	_ui_ready = true
	# In case set_transform was called before _ready
	if _transform:
		_refresh_from_data()

func _build_ui() -> void:
	# --- Position ---
	var pos_row := _make_pair_row("Position", "X", "Y", true)
	_pos_x = pos_row[0]
	_pos_y = pos_row[1]
	_pos_x.value_changed.connect(_on_pos_changed)
	_pos_y.value_changed.connect(_on_pos_changed)

	# --- Size ---
	var size_row := _make_pair_row("Size", "W", "H", false)
	_size_x = size_row[0]
	_size_y = size_row[1]
	_size_x.value_changed.connect(_on_size_changed)
	_size_y.value_changed.connect(_on_size_changed)

	# --- Rotation ---
	var rot_row := HBoxContainer.new()
	add_child(rot_row)
	var rot_label := Label.new()
	rot_label.text = "Rotation"
	rot_label.custom_minimum_size = Vector2(80, 0)
	rot_row.add_child(rot_label)
	_rotation = SpinBox.new()
	_rotation.size_flags_horizontal = SIZE_EXPAND_FILL
	_rotation.min_value = -3600.0
	_rotation.max_value = 3600.0
	_rotation.step = 1.0
	_rotation.suffix = "°"
	_rotation.value_changed.connect(_on_rotation_changed)
	rot_row.add_child(_rotation)

	# --- Skew ---
	var skew_row := _make_pair_row("Skew", "X", "Y", true)
	_skew_x = skew_row[0]
	_skew_y = skew_row[1]
	_skew_x.min_value = -89.0
	_skew_x.max_value = 89.0
	_skew_x.suffix = "°"
	_skew_y.min_value = -89.0
	_skew_y.max_value = 89.0
	_skew_y.suffix = "°"
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

	# Custom pivot row
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

func _get_or_make_group() -> ButtonGroup:
	if not _btn_group:
		_btn_group = ButtonGroup.new()
	return _btn_group

func _make_pair_row(label_text: String, axis_a: String, axis_b: String, allow_negative: bool) -> Array:
	var row := HBoxContainer.new()
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
	spin_a.min_value = -99999 if allow_negative else 0
	spin_a.max_value = 99999
	spin_a.allow_lesser = allow_negative
	spin_a.step = 1.0
	row.add_child(spin_a)

	var b_label := Label.new()
	b_label.text = axis_b
	b_label.custom_minimum_size = Vector2(20, 0)
	b_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.4))
	row.add_child(b_label)

	var spin_b := SpinBox.new()
	spin_b.size_flags_horizontal = SIZE_EXPAND_FILL
	spin_b.min_value = -99999 if allow_negative else 0
	spin_b.max_value = 99999
	spin_b.allow_lesser = allow_negative
	spin_b.step = 1.0
	row.add_child(spin_b)

	return [spin_a, spin_b]

# ============================================================
# PUBLIC
# ============================================================

func set_transform(t: BayterekLayerTransform) -> void:
	_transform = t
	if _ui_ready:
		_refresh_from_data()

func _refresh_from_data() -> void:
	if not _transform:
		return

	# Guard: UI not built yet
	if not _ui_ready:
		return
	if not _pos_x or not _pos_y or not _size_x or not _size_y or not _rotation:
		return
	if not _skew_x or not _skew_y:
		return
	if not _pivot_custom_x or not _pivot_custom_y:
		return
	if _pivot_buttons.size() < 10:
		return

	_updating = true

	_pos_x.set_value_no_signal(_transform.position.x)
	_pos_y.set_value_no_signal(_transform.position.y)
	_size_x.set_value_no_signal(_transform.size.x)
	_size_y.set_value_no_signal(_transform.size.y)
	_rotation.set_value_no_signal(_transform.rotation)
	_skew_x.set_value_no_signal(_transform.skew.x)
	_skew_y.set_value_no_signal(_transform.skew.y)

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

# ============================================================
# HANDLERS
# ============================================================

func _on_pos_changed(_v: float) -> void:
	if _updating or not _transform: return
	_transform.position = Vector2(_pos_x.value, _pos_y.value)
	changed.emit()

func _on_size_changed(_v: float) -> void:
	if _updating or not _transform: return
	_transform.size = Vector2(_size_x.value, _size_y.value)
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