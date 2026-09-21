@tool
class_name BayterekSettingsEditor
extends Control
## Tree Settings editor.

signal changed
signal size_changed
signal border_scale_changed
signal background_changed
signal line_texture_changed
signal revealed_changed
signal allocation_changed
signal preallocation_changed
signal multiallocation_changed
signal chain_connection_mode_changed
signal allocation_confirm_changed
signal refund_confirm_changed
signal show_group_frames_changed
signal frame_title_align_changed
signal texture_filter_changed
signal default_design_changed

var editor: BayterekEditor

var _content: VBoxContainer
var _updating_ui: bool = false

var _version_input: SpinBox
var _size_x_input: SpinBox
var _size_y_input: SpinBox
var _border_scale_input: SpinBox

var _texture_filter_dropdown: OptionButton

var _bg_color_picker: ColorPickerButton
var _bg_texture_input: BayterekInspectorTextureInput

var _line_normal_input: BayterekInspectorTextureInput
var _line_intermediate_input: BayterekInspectorTextureInput
var _line_active_input: BayterekInspectorTextureInput

var _revealed_check: CheckBox
var _allocation_check: CheckBox
var _preallocation_check: CheckBox
var _multiallocation_check: CheckBox
var _chain_connection_check: CheckBox
var _allocation_confirm_check: CheckBox
var _refund_confirm_check: CheckBox

var _show_group_frames_check: CheckBox
var _frame_title_align_dropdown: OptionButton

var _tooltip_header_align_dropdown: OptionButton
var _tooltip_body_align_dropdown: OptionButton
var _tooltip_footer_align_dropdown: OptionButton

var _default_design_dropdown: OptionButton

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

	# --- Default Design ---
	_add_separator(_content)
	_add_section_label(_content, "Default Node Design")

	_default_design_dropdown = _make_design_dropdown_row(_content)
	_default_design_dropdown.item_selected.connect(_on_default_design_changed)

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

	_chain_connection_check = _make_check_row(
		_content,
		"Chain Connection Mode",
		"After connecting, keep the target node selected so the next shift+click continues from there. Toggle anytime with C."
	)
	_chain_connection_check.button_pressed = true
	_chain_connection_check.toggled.connect(_on_chain_connection_mode_changed)

	_allocation_confirm_check = _make_check_row(
		_content,
		"Require Confirm on Allocate",
		"When ON, clicking a node preallocates it and requires the Confirm button. When OFF (default), clicking allocates immediately."
	)
	_allocation_confirm_check.button_pressed = false
	_allocation_confirm_check.toggled.connect(_on_allocation_confirm_changed)

	_refund_confirm_check = _make_check_row(
		_content,
		"Require Confirm on Refund",
		"When ON, clicking a node in refund mode stages it and requires the Confirm button. When OFF (default), clicking refunds immediately."
	)
	_refund_confirm_check.button_pressed = false
	_refund_confirm_check.toggled.connect(_on_refund_confirm_changed)

	# --- Group Frames ---
	_add_separator(_content)
	_add_section_label(_content, "Group Frames")

	_show_group_frames_check = _make_check_row(
		_content,
		"Show Frames in Runtime",
		"Whether group frames are drawn at runtime (in-game). In the editor they are always visible."
	)
	_show_group_frames_check.button_pressed = false
	_show_group_frames_check.toggled.connect(_on_show_group_frames_changed)

	_frame_title_align_dropdown = _make_dropdown_row(
		_content,
		"Title Align",
		"Horizontal alignment of the group frame's title text.",
		["Left (Normal)", "Centered"]
	)
	_frame_title_align_dropdown.item_selected.connect(_on_frame_title_align_changed)

	# --- Tooltip ---
	_add_separator(_content)
	_add_section_label(_content, "Tooltip")

	_tooltip_header_align_dropdown = _make_dropdown_row(
		_content,
		"Header Align",
		"Horizontal alignment of the tooltip header (node name).",
		["Left", "Center", "Right"]
	)
	_tooltip_header_align_dropdown.item_selected.connect(_on_tooltip_header_align_changed)

	_tooltip_body_align_dropdown = _make_dropdown_row(
		_content,
		"Body Align",
		"Horizontal alignment of the tooltip body (attributes, description).",
		["Left", "Center", "Right"]
	)
	_tooltip_body_align_dropdown.item_selected.connect(_on_tooltip_body_align_changed)

	_tooltip_footer_align_dropdown = _make_dropdown_row(
		_content,
		"Footer Align",
		"Horizontal alignment of the tooltip footer (level).",
		["Left", "Center", "Right"]
	)
	_tooltip_footer_align_dropdown.item_selected.connect(_on_tooltip_footer_align_changed)

# ============================================================
# SIGNAL CONNECTIONS
# ============================================================

func _connect_texture_signals() -> void:
	if _bg_texture_input:
		if not _bg_texture_input.texture_dropped.is_connected(_on_bg_texture_changed):
			_bg_texture_input.texture_dropped.connect(_on_bg_texture_changed)
		if not _bg_texture_input.cleared.is_connected(_on_bg_texture_cleared):
			_bg_texture_input.cleared.connect(_on_bg_texture_cleared)

	if _line_normal_input:
		if not _line_normal_input.texture_dropped.is_connected(_on_line_normal_changed):
			_line_normal_input.texture_dropped.connect(_on_line_normal_changed)
		if not _line_normal_input.cleared.is_connected(_on_line_normal_cleared):
			_line_normal_input.cleared.connect(_on_line_normal_cleared)

	if _line_intermediate_input:
		if not _line_intermediate_input.texture_dropped.is_connected(_on_line_intermediate_changed):
			_line_intermediate_input.texture_dropped.connect(_on_line_intermediate_changed)
		if not _line_intermediate_input.cleared.is_connected(_on_line_intermediate_cleared):
			_line_intermediate_input.cleared.connect(_on_line_intermediate_cleared)

	if _line_active_input:
		if not _line_active_input.texture_dropped.is_connected(_on_line_active_changed):
			_line_active_input.texture_dropped.connect(_on_line_active_changed)
		if not _line_active_input.cleared.is_connected(_on_line_active_cleared):
			_line_active_input.cleared.connect(_on_line_active_cleared)

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

	if _texture_filter_dropdown:
		_texture_filter_dropdown.select(tree_data.texture_filter)

	_set_input_texture(_bg_texture_input, tree_data.bg_texture)

	_set_input_texture(_line_normal_input, tree_data.line_texture_normal)
	_set_input_texture(_line_intermediate_input, tree_data.line_texture_intermediate)
	_set_input_texture(_line_active_input, tree_data.line_texture_active)

	_revealed_check.button_pressed = tree_data.revealed
	_allocation_check.button_pressed = tree_data.allocation
	_preallocation_check.button_pressed = tree_data.preallocation
	_multiallocation_check.button_pressed = tree_data.multiallocation
	_chain_connection_check.button_pressed = tree_data.chain_connection_mode
	_allocation_confirm_check.button_pressed = tree_data.allocation_confirm
	_refund_confirm_check.button_pressed = tree_data.refund_confirm
	_show_group_frames_check.button_pressed = tree_data.show_group_frames
	_frame_title_align_dropdown.select(tree_data.group_frame_title_align)

	_tooltip_header_align_dropdown.select(tree_data.tooltip_header_align)
	_tooltip_body_align_dropdown.select(tree_data.tooltip_body_align)
	_tooltip_footer_align_dropdown.select(tree_data.tooltip_footer_align)

	_rebuild_default_design_dropdown(tree_data.default_design_id)

	_updating_ui = false

# ============================================================
# DEFAULT DESIGN DROPDOWN
# ============================================================

func _make_design_dropdown_row(parent: Control) -> OptionButton:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = "Default Design"
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.tooltip_text = "Design applied to newly created nodes."
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(label)

	var dropdown := OptionButton.new()
	dropdown.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(dropdown)

	return dropdown

func _rebuild_default_design_dropdown(selected_id: String) -> void:
	if not _default_design_dropdown:
		return

	_default_design_dropdown.clear()
	_default_design_dropdown.add_item("(none)", 0)
	_default_design_dropdown.set_item_metadata(0, "")

	var reg = Bayterek.get_designs_registry()
	if not reg:
		_default_design_dropdown.select(0)
		return

	var idx: int = 1
	var found_idx: int = 0
	for design in reg.designs:
		if not design:
			continue
		var label: String = design.name
		if not design.category.is_empty():
			label = "[%s] %s" % [design.category, design.name]
		_default_design_dropdown.add_item(label, idx)
		_default_design_dropdown.set_item_metadata(idx, design.id)
		if design.id == selected_id:
			found_idx = idx
		idx += 1

	_default_design_dropdown.select(found_idx)

func _on_default_design_changed(index: int) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	var meta = _default_design_dropdown.get_item_metadata(index)
	var design_id: String = "" if meta == null else String(meta)
	editor.tree.default_design_id = design_id
	default_design_changed.emit()
	changed.emit()
	_notify_dirty()

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

# ============================================================
# INTERACTION HANDLERS
# ============================================================

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

func _on_chain_connection_mode_changed(pressed: bool) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.chain_connection_mode = pressed
	chain_connection_mode_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_allocation_confirm_changed(pressed: bool) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.allocation_confirm = pressed
	allocation_confirm_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_refund_confirm_changed(pressed: bool) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.refund_confirm = pressed
	refund_confirm_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_show_group_frames_changed(pressed: bool) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.show_group_frames = pressed
	show_group_frames_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_frame_title_align_changed(index: int) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.group_frame_title_align = index
	frame_title_align_changed.emit()

	if editor.tree_view and editor.tree_view.group_frames_service:
		editor.tree_view.group_frames_service.refresh_all()

	changed.emit()
	_notify_dirty()

func _on_tooltip_header_align_changed(index: int) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.tooltip_header_align = index
	changed.emit()
	_notify_dirty()

func _on_tooltip_body_align_changed(index: int) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.tooltip_body_align = index
	changed.emit()
	_notify_dirty()

func _on_tooltip_footer_align_changed(index: int) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.tooltip_footer_align = index
	changed.emit()
	_notify_dirty()

# ============================================================
# HELPERS
# ============================================================

func _notify_dirty() -> void:
	if editor and editor.has_method("set_dirty"):
		editor.set_dirty(true)

func _set_input_texture(input: BayterekInspectorTextureInput, tex: Texture2D) -> void:
	if not input:
		return
	input.set_texture(tex)

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