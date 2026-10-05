@tool
class_name BayterekSettingsEditor
extends Control
## Tree Settings editor.

signal changed
signal size_changed
signal border_scale_changed
signal background_changed
signal default_line_texture_changed
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

signal connection_style_changed
signal connection_state_color_changed
signal connection_offsets_changed
signal connection_wiggle_changed
signal connection_animation_tracking_changed

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

# --- Default line texture (single slot) ---
var _default_line_texture_input: BayterekInspectorTextureInput
var _default_line_texture_mode_dropdown: OptionButton
var _default_line_texture_filter_dropdown: OptionButton

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

var _conn_default_color: ColorPickerButton
var _conn_default_thickness: SpinBox
var _conn_antialiasing_check: CheckBox

var _conn_state_colors_check: CheckBox
var _conn_alloc_color: ColorPickerButton
var _conn_non_alloc_color: ColorPickerButton

var _conn_start_offset: SpinBox
var _conn_end_offset: SpinBox

var _conn_wiggle_enabled_check: CheckBox
var _conn_wiggle_hover_intensity_check: CheckBox
var _conn_wiggle_amplitude: SpinBox
var _conn_wiggle_frequency: SpinBox
var _conn_wiggle_speed: SpinBox
var _conn_wiggle_pattern_dropdown: OptionButton
var _conn_wiggle_direction_dropdown: OptionButton
var _conn_wiggle_active_boost: SpinBox
var _conn_follow_animation_check: CheckBox

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

	# ============================================================
	# DEFAULT LINE TEXTURE
	# ============================================================
	_add_separator(_content)
	_add_section_label(_content, "Default Line Texture")

	_default_line_texture_input = BayterekInspectorTextureInput.new()
	_default_line_texture_input.title = "Texture"
	_content.add_child(_default_line_texture_input)

	_default_line_texture_mode_dropdown = _make_dropdown_row(
		_content,
		"Mode",
		"How the texture is drawn along the line.",
		["None", "Tile", "Stretch", "Tile Fit Height"]
	)
	_default_line_texture_mode_dropdown.item_selected.connect(_on_default_line_texture_mode_changed)

	_default_line_texture_filter_dropdown = _make_dropdown_row(
		_content,
		"Filter",
		"Texture sampling: Inherit uses the tree's global filter.",
		["Inherit", "Linear", "Nearest"]
	)
	_default_line_texture_filter_dropdown.item_selected.connect(_on_default_line_texture_filter_changed)

	# ============================================================
	# CONNECTIONS (defaults)
	# ============================================================
	_add_separator(_content)
	_add_section_label(_content, "Connections — Default Style")

	_conn_default_color = _make_color_row(_content, "Default Color",
		"Color applied to newly-created connections.")
	_conn_default_color.color = Color(0.7, 0.7, 0.7, 0.9)
	_conn_default_color.color_changed.connect(_on_conn_default_color_changed)

	_conn_default_thickness = _make_float_row(_content, "Default Thickness",
		"Line thickness in pixels. Applied to new connections.")
	_conn_default_thickness.min_value = 0.5
	_conn_default_thickness.max_value = 64.0
	_conn_default_thickness.step = 0.5
	_conn_default_thickness.value = 4.0
	_conn_default_thickness.allow_greater = true
	_conn_default_thickness.value_changed.connect(_on_conn_thickness_changed)

	_conn_antialiasing_check = _make_check_row(_content, "Smooth (Antialiasing)",
		"When OFF, lines are drawn without antialiasing.")
	_conn_antialiasing_check.button_pressed = true
	_conn_antialiasing_check.toggled.connect(_on_conn_antialiasing_changed)

	# --- State Colors ---
	_add_separator(_content)
	_add_section_label(_content, "Connections — State Colors")

	_conn_state_colors_check = _make_check_row(_content, "Enable State Colors",
		"When ON, connection colors reflect the TARGET node's allocateable state.")
	_conn_state_colors_check.button_pressed = false
	_conn_state_colors_check.toggled.connect(_on_conn_state_colors_toggled)

	_conn_alloc_color = _make_color_row(_content, "Allocateable Color",
		"Color applied when the target node is allocateable.")
	_conn_alloc_color.color = Color(0.56, 0.96, 0.56)
	_conn_alloc_color.color_changed.connect(_on_conn_alloc_color_changed)

	_conn_non_alloc_color = _make_color_row(_content, "Non-Alloc Color",
		"Color applied when the target node is NOT allocateable.")
	_conn_non_alloc_color.color = Color(1.0, 0.4, 0.4)
	_conn_non_alloc_color.color_changed.connect(_on_conn_non_alloc_color_changed)

	# --- Offsets ---
	_add_separator(_content)
	_add_section_label(_content, "Connections — Offsets")

	_conn_start_offset = _make_float_row(_content, "Default Start Offset",
		"Pixels to push the line start away from the source node.")
	_conn_start_offset.min_value = 0.0
	_conn_start_offset.max_value = 200.0
	_conn_start_offset.step = 1.0
	_conn_start_offset.value = 8.0
	_conn_start_offset.allow_greater = true
	_conn_start_offset.value_changed.connect(_on_conn_start_offset_changed)

	_conn_end_offset = _make_float_row(_content, "Default End Offset",
		"Pixels to push the line end away from the target node.")
	_conn_end_offset.min_value = 0.0
	_conn_end_offset.max_value = 200.0
	_conn_end_offset.step = 1.0
	_conn_end_offset.value = 12.0
	_conn_end_offset.allow_greater = true
	_conn_end_offset.value_changed.connect(_on_conn_end_offset_changed)

	# --- Wiggle ---
	_add_separator(_content)
	_add_section_label(_content, "Connections — Wiggle")

	_conn_wiggle_enabled_check = _make_check_row(_content, "Enable Wiggle",
		"Master toggle for connection wiggle animation.")
	_conn_wiggle_enabled_check.button_pressed = false
	_conn_wiggle_enabled_check.toggled.connect(_on_conn_wiggle_enabled_changed)

	_conn_wiggle_hover_intensity_check = _make_check_row(_content, "Use Hover Intensity",
		"When ON, wiggle speed scales with the node's movement speed.")
	_conn_wiggle_hover_intensity_check.button_pressed = true
	_conn_wiggle_hover_intensity_check.toggled.connect(_on_conn_hover_intensity_changed)

	_conn_wiggle_amplitude = _make_float_row(_content, "Base Amplitude",
		"Maximum lateral displacement in pixels.")
	_conn_wiggle_amplitude.min_value = 0.0
	_conn_wiggle_amplitude.max_value = 64.0
	_conn_wiggle_amplitude.step = 0.5
	_conn_wiggle_amplitude.value = 2.0
	_conn_wiggle_amplitude.allow_greater = true
	_conn_wiggle_amplitude.value_changed.connect(_on_conn_wiggle_amplitude_changed)

	_conn_wiggle_frequency = _make_float_row(_content, "Frequency",
		"Oscillation frequency in Hz.")
	_conn_wiggle_frequency.min_value = 0.1
	_conn_wiggle_frequency.max_value = 20.0
	_conn_wiggle_frequency.step = 0.1
	_conn_wiggle_frequency.value = 2.0
	_conn_wiggle_frequency.allow_greater = true
	_conn_wiggle_frequency.value_changed.connect(_on_conn_wiggle_frequency_changed)

	_conn_wiggle_speed = _make_float_row(_content, "Speed",
		"Global speed multiplier for the wiggle clock.")
	_conn_wiggle_speed.min_value = 0.0
	_conn_wiggle_speed.max_value = 10.0
	_conn_wiggle_speed.step = 0.05
	_conn_wiggle_speed.value = 1.0
	_conn_wiggle_speed.allow_greater = true
	_conn_wiggle_speed.value_changed.connect(_on_conn_wiggle_speed_changed)

	_conn_wiggle_pattern_dropdown = _make_dropdown_row(
		_content,
		"Pattern",
		"Waveform shape used for the wiggle.",
		["Sine", "Perlin", "Random Jitter", "Triangle", "Bounce"]
	)
	_conn_wiggle_pattern_dropdown.item_selected.connect(_on_conn_wiggle_pattern_changed)

	_conn_wiggle_direction_dropdown = _make_dropdown_row(
		_content,
		"Direction",
		"How the wiggle direction is chosen.",
		["Perpendicular", "Follow Node Motion", "Axis Lock"]
	)
	_conn_wiggle_direction_dropdown.item_selected.connect(_on_conn_wiggle_direction_changed)

	_conn_wiggle_active_boost = _make_float_row(_content, "Active Boost",
		"Amplitude multiplier when the target node is allocated.")
	_conn_wiggle_active_boost.min_value = 1.0
	_conn_wiggle_active_boost.max_value = 5.0
	_conn_wiggle_active_boost.step = 0.1
	_conn_wiggle_active_boost.value = 1.5
	_conn_wiggle_active_boost.allow_greater = true
	_conn_wiggle_active_boost.value_changed.connect(_on_conn_wiggle_active_boost_changed)

	# --- Animation Tracking ---
	_add_separator(_content)
	_add_section_label(_content, "Connections — Animation Tracking")

	_conn_follow_animation_check = _make_check_row(_content, "Follow Node Animation",
		"When ON, connection lines move with the node during hover animations.")
	_conn_follow_animation_check.button_pressed = true
	_conn_follow_animation_check.toggled.connect(_on_conn_follow_animation_changed)

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
		"When ON, clicking a node preallocates it and requires the Confirm button."
	)
	_allocation_confirm_check.button_pressed = false
	_allocation_confirm_check.toggled.connect(_on_allocation_confirm_changed)

	_refund_confirm_check = _make_check_row(
		_content,
		"Require Confirm on Refund",
		"When ON, clicking a node in refund mode stages it and requires the Confirm button."
	)
	_refund_confirm_check.button_pressed = false
	_refund_confirm_check.toggled.connect(_on_refund_confirm_changed)

	# --- Group Frames ---
	_add_separator(_content)
	_add_section_label(_content, "Group Frames")

	_show_group_frames_check = _make_check_row(
		_content,
		"Show Frames",
		"Draw colored bounding boxes around node groups."
	)
	_show_group_frames_check.button_pressed = true
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
		"Horizontal alignment of the tooltip header.",
		["Left", "Center", "Right"]
	)
	_tooltip_header_align_dropdown.item_selected.connect(_on_tooltip_header_align_changed)

	_tooltip_body_align_dropdown = _make_dropdown_row(
		_content,
		"Body Align",
		"Horizontal alignment of the tooltip body.",
		["Left", "Center", "Right"]
	)
	_tooltip_body_align_dropdown.item_selected.connect(_on_tooltip_body_align_changed)

	_tooltip_footer_align_dropdown = _make_dropdown_row(
		_content,
		"Footer Align",
		"Horizontal alignment of the tooltip footer.",
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

	if _default_line_texture_input:
		if not _default_line_texture_input.texture_dropped.is_connected(_on_default_line_texture_changed):
			_default_line_texture_input.texture_dropped.connect(_on_default_line_texture_changed)
		if not _default_line_texture_input.cleared.is_connected(_on_default_line_texture_cleared):
			_default_line_texture_input.cleared.connect(_on_default_line_texture_cleared)

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

	# --- Default line texture ---
	_set_input_texture(_default_line_texture_input, tree_data.default_line_texture)
	if _default_line_texture_mode_dropdown:
		_default_line_texture_mode_dropdown.select(clampi(tree_data.default_line_texture_mode, 0, 3))
	if _default_line_texture_filter_dropdown:
		_default_line_texture_filter_dropdown.select(clampi(tree_data.default_line_texture_filter, 0, 2))

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

	# --- Connections ---
	_conn_default_color.color = tree_data.default_line_color
	_conn_default_thickness.set_value_no_signal(tree_data.default_line_thickness)
	_conn_antialiasing_check.button_pressed = tree_data.line_antialiasing

	_conn_state_colors_check.button_pressed = tree_data.state_color_enabled
	_conn_alloc_color.color = tree_data.line_alloc_color
	_conn_non_alloc_color.color = tree_data.line_non_alloc_color

	_conn_start_offset.set_value_no_signal(tree_data.default_start_offset)
	_conn_end_offset.set_value_no_signal(tree_data.default_end_offset)

	_conn_wiggle_enabled_check.button_pressed = tree_data.wiggle_enabled
	_conn_wiggle_hover_intensity_check.button_pressed = tree_data.wiggle_use_hover_intensity
	_conn_wiggle_amplitude.set_value_no_signal(tree_data.wiggle_base_amplitude)
	_conn_wiggle_frequency.set_value_no_signal(tree_data.wiggle_frequency)
	_conn_wiggle_speed.set_value_no_signal(tree_data.wiggle_speed)
	if _conn_wiggle_pattern_dropdown:
		_conn_wiggle_pattern_dropdown.select(tree_data.wiggle_pattern)
	if _conn_wiggle_direction_dropdown:
		_conn_wiggle_direction_dropdown.select(tree_data.wiggle_direction_mode)
	_conn_wiggle_active_boost.set_value_no_signal(tree_data.wiggle_active_boost)

	_conn_follow_animation_check.button_pressed = tree_data.wiggle_follow_node_animation

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
# EXISTING HANDLERS
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

# ============================================================
# DEFAULT LINE TEXTURE HANDLERS
# ============================================================

func _on_default_line_texture_changed(path: String) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	var tex: Texture2D = load(path) as Texture2D
	editor.tree.default_line_texture = tex
	_set_input_texture(_default_line_texture_input, tex)
	# Auto-enable TILE mode if it was set to NONE.
	if tex and editor.tree.default_line_texture_mode == 0:
		editor.tree.default_line_texture_mode = 1
		if _default_line_texture_mode_dropdown:
			_default_line_texture_mode_dropdown.select(1)
	default_line_texture_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_default_line_texture_cleared() -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.default_line_texture = null
	editor.tree.default_line_texture_mode = 0
	_set_input_texture(_default_line_texture_input, null)
	if _default_line_texture_mode_dropdown:
		_default_line_texture_mode_dropdown.select(0)
	default_line_texture_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_default_line_texture_mode_changed(index: int) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.default_line_texture_mode = index
	default_line_texture_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_default_line_texture_filter_changed(index: int) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.default_line_texture_filter = index
	default_line_texture_changed.emit()
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

	if editor.has_method("_set_show_group_frames"):
		editor._set_show_group_frames(pressed, false)
	else:
		editor.tree.show_group_frames = pressed
		if editor.tree_view and editor.tree_view.group_frames_service:
			editor.tree_view.group_frames_service.refresh_all()
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
# CONNECTION SETTINGS HANDLERS
# ============================================================

func _on_conn_default_color_changed(color: Color) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.default_line_color = color
	connection_style_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_conn_thickness_changed(value: float) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.default_line_thickness = value
	connection_style_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_conn_antialiasing_changed(pressed: bool) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.line_antialiasing = pressed
	connection_style_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_conn_state_colors_toggled(pressed: bool) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.state_color_enabled = pressed
	connection_state_color_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_conn_alloc_color_changed(color: Color) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.line_alloc_color = color
	connection_state_color_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_conn_non_alloc_color_changed(color: Color) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.line_non_alloc_color = color
	connection_state_color_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_conn_start_offset_changed(value: float) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.default_start_offset = value
	connection_offsets_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_conn_end_offset_changed(value: float) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.default_end_offset = value
	connection_offsets_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_conn_wiggle_enabled_changed(pressed: bool) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.wiggle_enabled = pressed
	connection_wiggle_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_conn_hover_intensity_changed(pressed: bool) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.wiggle_use_hover_intensity = pressed
	connection_wiggle_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_conn_wiggle_amplitude_changed(value: float) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.wiggle_base_amplitude = value
	connection_wiggle_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_conn_wiggle_frequency_changed(value: float) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.wiggle_frequency = value
	connection_wiggle_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_conn_wiggle_speed_changed(value: float) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.wiggle_speed = value
	connection_wiggle_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_conn_wiggle_pattern_changed(index: int) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.wiggle_pattern = index
	connection_wiggle_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_conn_wiggle_direction_changed(index: int) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.wiggle_direction_mode = index
	connection_wiggle_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_conn_wiggle_active_boost_changed(value: float) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.wiggle_active_boost = value
	connection_wiggle_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_conn_follow_animation_changed(pressed: bool) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.wiggle_follow_node_animation = pressed
	connection_animation_tracking_changed.emit()
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