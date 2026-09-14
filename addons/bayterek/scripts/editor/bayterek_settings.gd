@tool
class_name BayterekSettingsEditor
extends Control
## Tree Settings editor.

signal changed
signal size_changed
signal border_scale_changed
signal background_changed
signal icon_size_changed
signal node_size_changed
signal line_texture_changed
signal revealed_changed
signal allocation_changed
signal preallocation_changed
signal multiallocation_changed
signal texture_filter_changed

var editor: BayterekEditor

var _content: VBoxContainer
var _updating_ui: bool = false

var _version_input: SpinBox
var _size_x_input: SpinBox
var _size_y_input: SpinBox
var _border_scale_input: SpinBox

# Texture filter
var _texture_filter_dropdown: OptionButton

var _bg_color_picker: ColorPickerButton
var _bg_texture_input: BayterekInspectorTextureInput

var _small_icon_x: SpinBox
var _small_icon_y: SpinBox
var _medium_icon_x: SpinBox
var _medium_icon_y: SpinBox
var _large_icon_x: SpinBox
var _large_icon_y: SpinBox

var _small_size_x: SpinBox
var _small_size_y: SpinBox
var _medium_size_x: SpinBox
var _medium_size_y: SpinBox
var _large_size_x: SpinBox
var _large_size_y: SpinBox

var _line_normal_input: BayterekInspectorTextureInput
var _line_intermediate_input: BayterekInspectorTextureInput
var _line_active_input: BayterekInspectorTextureInput

var _revealed_check: CheckBox
var _allocation_check: CheckBox
var _preallocation_check: CheckBox
var _multiallocation_check: CheckBox

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()

func init() -> void:
	_connect_texture_signals()

# ============================================================
# UI BUILD
# ============================================================

func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.size_flags_horizontal = SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)

	# --- Version ---
	_version_input = _make_int_row(_content, "Version", "Tree version")
	_version_input.min_value = 1
	_version_input.value = 1
	_version_input.allow_greater = true
	_version_input.value_changed.connect(_on_version_changed)

	# --- Size ---
	_size_x_input = _make_int_row(_content, "Size X", "Tree width")
	_size_x_input.min_value = 100
	_size_x_input.value = 5000
	_size_x_input.allow_greater = true
	_size_x_input.value_changed.connect(_on_size_changed)

	_size_y_input = _make_int_row(_content, "Size Y", "Tree height")
	_size_y_input.min_value = 100
	_size_y_input.value = 5000
	_size_y_input.allow_greater = true
	_size_y_input.value_changed.connect(_on_size_changed)

	# --- Border Scale ---
	_border_scale_input = _make_float_row(_content, "Border Scale", "Border scale multiplier")
	_border_scale_input.min_value = 0.1
	_border_scale_input.max_value = 10.0
	_border_scale_input.step = 0.1
	_border_scale_input.value = 1.5
	_border_scale_input.allow_greater = true
	_border_scale_input.value_changed.connect(_on_border_scale_changed)

	# --- Texture Filter ---
	_texture_filter_dropdown = _make_dropdown_row(
		_content,
		"Texture Filter",
		"Filtering mode for icons, borders, and sprites",
		["Linear (smooth)", "Nearest (pixel art)"]
	)
	_texture_filter_dropdown.item_selected.connect(_on_texture_filter_changed)

	# --- Background ---
	_bg_color_picker = _make_color_row(_content, "Background Color", "Background color")
	_bg_color_picker.color = Color(0.1, 0.1, 0.1)
	_bg_color_picker.color_changed.connect(_on_bg_color_changed)

	_bg_texture_input = BayterekInspectorTextureInput.new()
	_bg_texture_input.title = "Background Texture"
	_content.add_child(_bg_texture_input)

	# --- Icon Sizes ---
	_add_separator(_content)
	_add_section_label(_content, "Icon Sizes")

	_small_icon_x = _make_int_pair_row(_content, "Small", "X")
	_small_icon_x.value_changed.connect(_on_small_icon_changed)
	_small_icon_y = _make_int_pair_row_end("Y")
	_small_icon_y.value_changed.connect(_on_small_icon_changed)

	_medium_icon_x = _make_int_pair_row(_content, "Medium", "X")
	_medium_icon_x.value_changed.connect(_on_medium_icon_changed)
	_medium_icon_y = _make_int_pair_row_end("Y")
	_medium_icon_y.value_changed.connect(_on_medium_icon_changed)

	_large_icon_x = _make_int_pair_row(_content, "Large", "X")
	_large_icon_x.value_changed.connect(_on_large_icon_changed)
	_large_icon_y = _make_int_pair_row_end("Y")
	_large_icon_y.value_changed.connect(_on_large_icon_changed)

	# --- Node Sizes ---
	_add_separator(_content)
	_add_section_label(_content, "Node Sizes")

	_small_size_x = _make_int_pair_row(_content, "Small", "X")
	_small_size_x.value = 27
	_small_size_x.value_changed.connect(_on_small_size_changed)
	_small_size_y = _make_int_pair_row_end("Y")
	_small_size_y.value = 27
	_small_size_y.value_changed.connect(_on_small_size_changed)

	_medium_size_x = _make_int_pair_row(_content, "Medium", "X")
	_medium_size_x.value = 48
	_medium_size_x.value_changed.connect(_on_medium_size_changed)
	_medium_size_y = _make_int_pair_row_end("Y")
	_medium_size_y.value = 48
	_medium_size_y.value_changed.connect(_on_medium_size_changed)

	_large_size_x = _make_int_pair_row(_content, "Large", "X")
	_large_size_x.value = 64
	_large_size_x.value_changed.connect(_on_large_size_changed)
	_large_size_y = _make_int_pair_row_end("Y")
	_large_size_y.value = 64
	_large_size_y.value_changed.connect(_on_large_size_changed)

	# --- Line Textures ---
	_add_separator(_content)
	_add_section_label(_content, "Line Textures")

	_line_normal_input = BayterekInspectorTextureInput.new()
	_line_normal_input.title = "Normal"
	_content.add_child(_line_normal_input)

	_line_intermediate_input = BayterekInspectorTextureInput.new()
	_line_intermediate_input.title = "Intermediate"
	_content.add_child(_line_intermediate_input)

	_line_active_input = BayterekInspectorTextureInput.new()
	_line_active_input.title = "Active"
	_content.add_child(_line_active_input)

	# --- Interaction ---
	_add_separator(_content)
	_add_section_label(_content, "Interaction")

	_revealed_check = _make_check_row(_content, "Revealed", "Entire tree is visible")
	_revealed_check.button_pressed = true
	_revealed_check.toggled.connect(_on_revealed_changed)

	_allocation_check = _make_check_row(_content, "Allocation", "Nodes can be allocated")
	_allocation_check.button_pressed = true
	_allocation_check.toggled.connect(_on_allocation_changed)

	_preallocation_check = _make_check_row(_content, "Preallocation", "Confirm before allocating")
	_preallocation_check.button_pressed = true
	_preallocation_check.toggled.connect(_on_preallocation_changed)

	_multiallocation_check = _make_check_row(_content, "Multi-allocation", "Level-based allocation")
	_multiallocation_check.toggled.connect(_on_multiallocation_changed)

# ============================================================
# TEXTURE SIGNALS (called after init)
# ============================================================

func _connect_texture_signals() -> void:
	if _bg_texture_input:
		if not _bg_texture_input._load_button.pressed.is_connected(_on_bg_texture_picker):
			_bg_texture_input._load_button.pressed.connect(_on_bg_texture_picker)
		if not _bg_texture_input._clear_button.pressed.is_connected(_on_bg_texture_cleared):
			_bg_texture_input._clear_button.pressed.connect(_on_bg_texture_cleared)
		if not _bg_texture_input.texture_dropped.is_connected(_on_bg_texture_changed):
			_bg_texture_input.texture_dropped.connect(_on_bg_texture_changed)

	if _line_normal_input:
		if not _line_normal_input._load_button.pressed.is_connected(_on_line_normal_picker):
			_line_normal_input._load_button.pressed.connect(_on_line_normal_picker)
		if not _line_normal_input._clear_button.pressed.is_connected(_on_line_normal_cleared):
			_line_normal_input._clear_button.pressed.connect(_on_line_normal_cleared)
		if not _line_normal_input.texture_dropped.is_connected(_on_line_normal_changed):
			_line_normal_input.texture_dropped.connect(_on_line_normal_changed)

	if _line_intermediate_input:
		if not _line_intermediate_input._load_button.pressed.is_connected(_on_line_intermediate_picker):
			_line_intermediate_input._load_button.pressed.connect(_on_line_intermediate_picker)
		if not _line_intermediate_input._clear_button.pressed.is_connected(_on_line_intermediate_cleared):
			_line_intermediate_input._clear_button.pressed.connect(_on_line_intermediate_cleared)
		if not _line_intermediate_input.texture_dropped.is_connected(_on_line_intermediate_changed):
			_line_intermediate_input.texture_dropped.connect(_on_line_intermediate_changed)

	if _line_active_input:
		if not _line_active_input._load_button.pressed.is_connected(_on_line_active_picker):
			_line_active_input._load_button.pressed.connect(_on_line_active_picker)
		if not _line_active_input._clear_button.pressed.is_connected(_on_line_active_cleared):
			_line_active_input._clear_button.pressed.connect(_on_line_active_cleared)
		if not _line_active_input.texture_dropped.is_connected(_on_line_active_changed):
			_line_active_input.texture_dropped.connect(_on_line_active_changed)

# ============================================================
# TREE LOAD
# ============================================================

func load_tree(tree_data: BayterekTree) -> void:
	if not tree_data:
		return
	if not _content:
		return

	_updating_ui = true

	_version_input.set_value_no_signal(tree_data.version)
	_size_x_input.set_value_no_signal(tree_data.size.x)
	_size_y_input.set_value_no_signal(tree_data.size.y)
	_border_scale_input.set_value_no_signal(tree_data.border_scale)
	_bg_color_picker.color = tree_data.bg_color

	# Texture filter
	if _texture_filter_dropdown:
		_texture_filter_dropdown.select(tree_data.texture_filter)

	# Background texture
	_set_input_texture(_bg_texture_input, tree_data.bg_texture)

	# Icon sizes
	var small_icon: Vector2 = tree_data.icon_sizes.get(BayterekNode.NodeType.SMALL, Vector2.ZERO)
	var medium_icon: Vector2 = tree_data.icon_sizes.get(BayterekNode.NodeType.MEDIUM, Vector2.ZERO)
	var large_icon: Vector2 = tree_data.icon_sizes.get(BayterekNode.NodeType.LARGE, Vector2.ZERO)
	_small_icon_x.set_value_no_signal(small_icon.x)
	_small_icon_y.set_value_no_signal(small_icon.y)
	_medium_icon_x.set_value_no_signal(medium_icon.x)
	_medium_icon_y.set_value_no_signal(medium_icon.y)
	_large_icon_x.set_value_no_signal(large_icon.x)
	_large_icon_y.set_value_no_signal(large_icon.y)

	# Node sizes
	var small_size: Vector2 = tree_data.node_size.get(BayterekNode.NodeType.SMALL, Vector2(27, 27))
	var medium_size: Vector2 = tree_data.node_size.get(BayterekNode.NodeType.MEDIUM, Vector2(48, 48))
	var large_size: Vector2 = tree_data.node_size.get(BayterekNode.NodeType.LARGE, Vector2(64, 64))
	_small_size_x.set_value_no_signal(small_size.x)
	_small_size_y.set_value_no_signal(small_size.y)
	_medium_size_x.set_value_no_signal(medium_size.x)
	_medium_size_y.set_value_no_signal(medium_size.y)
	_large_size_x.set_value_no_signal(large_size.x)
	_large_size_y.set_value_no_signal(large_size.y)

	# Line textures
	_set_input_texture(_line_normal_input, tree_data.line_texture_normal)
	_set_input_texture(_line_intermediate_input, tree_data.line_texture_intermediate)
	_set_input_texture(_line_active_input, tree_data.line_texture_active)

	# Interaction
	_revealed_check.button_pressed = tree_data.revealed
	_allocation_check.button_pressed = tree_data.allocation
	_preallocation_check.button_pressed = tree_data.preallocation
	_multiallocation_check.button_pressed = tree_data.multiallocation

	_updating_ui = false

# ============================================================
# HELPER — set texture input
# ============================================================

func _set_input_texture(input: BayterekInspectorTextureInput, tex: Texture2D) -> void:
	if not input:
		return
	if input._texture_rect:
		input._texture_rect.texture = tex
	if tex:
		if input._empty_label:
			input._empty_label.visible = false
		if input._clear_button:
			input._clear_button.visible = true
	else:
		if input._empty_label:
			input._empty_label.visible = true
		if input._clear_button:
			input._clear_button.visible = false

# ============================================================
# HANDLERS
# ============================================================

func _on_version_changed(value: float) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.version = int(value)
	changed.emit()
	_notify_dirty()

func _on_size_changed(_value: float) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.size = Vector2(_size_x_input.value, _size_y_input.value)
	size_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_border_scale_changed(value: float) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.border_scale = value
	border_scale_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_texture_filter_changed(index: int) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.texture_filter = index
	texture_filter_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_bg_color_changed(color: Color) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.bg_color = color
	background_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_bg_texture_picker() -> void:
	EditorInterface.popup_quick_open(_on_bg_texture_changed, ["Texture2D"])

func _on_bg_texture_changed(path: String) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	var tex: Texture2D = load(path) as Texture2D
	editor.tree.bg_texture = tex
	_set_input_texture(_bg_texture_input, tex)
	background_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_bg_texture_cleared() -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.bg_texture = null
	_set_input_texture(_bg_texture_input, null)
	background_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_small_icon_changed(_value: float) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.icon_sizes[BayterekNode.NodeType.SMALL] = Vector2(_small_icon_x.value, _small_icon_y.value)
	icon_size_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_medium_icon_changed(_value: float) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.icon_sizes[BayterekNode.NodeType.MEDIUM] = Vector2(_medium_icon_x.value, _medium_icon_y.value)
	icon_size_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_large_icon_changed(_value: float) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.icon_sizes[BayterekNode.NodeType.LARGE] = Vector2(_large_icon_x.value, _large_icon_y.value)
	icon_size_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_small_size_changed(_value: float) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.node_size[BayterekNode.NodeType.SMALL] = Vector2(_small_size_x.value, _small_size_y.value)
	node_size_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_medium_size_changed(_value: float) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.node_size[BayterekNode.NodeType.MEDIUM] = Vector2(_medium_size_x.value, _medium_size_y.value)
	node_size_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_large_size_changed(_value: float) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.node_size[BayterekNode.NodeType.LARGE] = Vector2(_large_size_x.value, _large_size_y.value)
	node_size_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_line_normal_picker() -> void:
	EditorInterface.popup_quick_open(_on_line_normal_changed, ["Texture2D"])

func _on_line_normal_changed(path: String) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	var tex: Texture2D = load(path) as Texture2D
	editor.tree.line_texture_normal = tex
	_set_input_texture(_line_normal_input, tex)
	line_texture_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_line_normal_cleared() -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.line_texture_normal = null
	_set_input_texture(_line_normal_input, null)
	line_texture_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_line_intermediate_picker() -> void:
	EditorInterface.popup_quick_open(_on_line_intermediate_changed, ["Texture2D"])

func _on_line_intermediate_changed(path: String) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	var tex: Texture2D = load(path) as Texture2D
	editor.tree.line_texture_intermediate = tex
	_set_input_texture(_line_intermediate_input, tex)
	line_texture_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_line_intermediate_cleared() -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.line_texture_intermediate = null
	_set_input_texture(_line_intermediate_input, null)
	line_texture_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_line_active_picker() -> void:
	EditorInterface.popup_quick_open(_on_line_active_changed, ["Texture2D"])

func _on_line_active_changed(path: String) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	var tex: Texture2D = load(path) as Texture2D
	editor.tree.line_texture_active = tex
	_set_input_texture(_line_active_input, tex)
	line_texture_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_line_active_cleared() -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.line_texture_active = null
	_set_input_texture(_line_active_input, null)
	line_texture_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_revealed_changed(pressed: bool) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.revealed = pressed
	revealed_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_allocation_changed(pressed: bool) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.allocation = pressed
	allocation_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_preallocation_changed(pressed: bool) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.preallocation = pressed
	preallocation_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_multiallocation_changed(pressed: bool) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.multiallocation = pressed
	multiallocation_changed.emit()
	changed.emit()
	_notify_dirty()

# ============================================================
# HELPERS
# ============================================================

func _notify_dirty() -> void:
	if editor and editor.has_method("set_dirty"):
		editor.set_dirty(true)

func _make_int_row(parent: Control, label_text: String, tooltip: String = "") -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	if not tooltip.is_empty():
		label.tooltip_text = tooltip
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(label)

	var spin := SpinBox.new()
	spin.size_flags_horizontal = SIZE_EXPAND_FILL
	spin.rounded = true
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.min_value = 0
	spin.max_value = 999999
	row.add_child(spin)

	return spin

func _make_float_row(parent: Control, label_text: String, tooltip: String = "") -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	if not tooltip.is_empty():
		label.tooltip_text = tooltip
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(label)

	var spin := SpinBox.new()
	spin.size_flags_horizontal = SIZE_EXPAND_FILL
	spin.rounded = false
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.step = 0.01
	row.add_child(spin)

	return spin

func _make_dropdown_row(parent: Control, label_text: String, tooltip: String, items: Array) -> OptionButton:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	if not tooltip.is_empty():
		label.tooltip_text = tooltip
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(label)

	var dropdown := OptionButton.new()
	dropdown.size_flags_horizontal = SIZE_EXPAND_FILL
	for i in items.size():
		dropdown.add_item(str(items[i]), i)
	dropdown.select(0)
	row.add_child(dropdown)

	return dropdown

func _make_color_row(parent: Control, label_text: String, tooltip: String = "") -> ColorPickerButton:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	if not tooltip.is_empty():
		label.tooltip_text = tooltip
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(label)

	var picker := ColorPickerButton.new()
	picker.size_flags_horizontal = SIZE_EXPAND_FILL
	picker.custom_minimum_size = Vector2(0, 24)
	row.add_child(picker)

	return picker

func _make_check_row(parent: Control, label_text: String, tooltip: String = "") -> CheckBox:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	if not tooltip.is_empty():
		label.tooltip_text = tooltip
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(label)

	var check := CheckBox.new()
	check.text = "On"
	check.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(check)

	return check

func _add_separator(parent: Control) -> void:
	var sep := HSeparator.new()
	parent.add_child(sep)

func _add_section_label(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	parent.add_child(label)

func _make_int_pair_row(parent: Control, label_text: String, axis: String) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(70, 0)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(label)

	var x_label := Label.new()
	x_label.text = "X"
	x_label.custom_minimum_size = Vector2(20, 0)
	x_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	row.add_child(x_label)

	var spin := SpinBox.new()
	spin.size_flags_horizontal = SIZE_EXPAND_FILL
	spin.rounded = true
	spin.allow_greater = true
	spin.allow_lesser = false
	spin.min_value = 0
	spin.max_value = 999999
	row.add_child(spin)

	return spin

func _make_int_pair_row_end(axis: String) -> SpinBox:
	var parent := _content
	var row := HBoxContainer.new()
	parent.add_child(row)

	var spacer := Label.new()
	spacer.text = ""
	spacer.custom_minimum_size = Vector2(70, 0)
	row.add_child(spacer)

	var y_label := Label.new()
	y_label.text = "Y"
	y_label.custom_minimum_size = Vector2(20, 0)
	y_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.4))
	row.add_child(y_label)

	var spin := SpinBox.new()
	spin.size_flags_horizontal = SIZE_EXPAND_FILL
	spin.rounded = true
	spin.allow_greater = true
	spin.allow_lesser = false
	spin.min_value = 0
	spin.max_value = 999999
	row.add_child(spin)

	return spin