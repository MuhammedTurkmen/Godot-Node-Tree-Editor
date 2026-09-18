@tool
class_name BayterekTreeEditorInspector
extends Control
## Node Inspector with Prefab mode support.

signal changed

var editor: BayterekEditor
var icon_selector: BayterekIconSelector

var _current_node: BayterekNodeButton
var _current_prefab: BayterekPrefab = null

var _empty_label: Label
var _content: VBoxContainer

# Mode banner (shown only in prefab mode)
var _mode_banner: PanelContainer
var _mode_banner_label: Label

# Reset All button
var _reset_all_btn: Button = null

var _root_panel: HBoxContainer
var _root_check: CheckBox

var _info_panel: VBoxContainer
var _id_input: LineEdit
var _name_input: LineEdit
var _description_input: TextEdit
var _max_alloc_panel: HBoxContainer
var _max_alloc_input: SpinBox
var _prereq_panel: HBoxContainer
var _prereq_dropdown: OptionButton
var _prereq_count_panel: HBoxContainer
var _prereq_count_input: SpinBox

var _transform_panel: VBoxContainer
var _pos_x_input: SpinBox
var _pos_y_input: SpinBox

var _visuals_panel: VBoxContainer
var _icon_input: BayterekInspectorTextureInput
var _border_normal_input: BayterekInspectorTextureInput
var _border_intermediate_input: BayterekInspectorTextureInput
var _border_active_input: BayterekInspectorTextureInput

# Attributes
var _attributes_panel: VBoxContainer
var _attributes_empty: Label
var _attributes_list: VBoxContainer
var _attr_checkboxes: Dictionary = {}
var _attr_value_inputs: Dictionary = {}

# Connections
var _connections_panel: VBoxContainer
var _connections_empty: Label
var _connections_list: VBoxContainer

var _updating_ui: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()
	_show_empty()

# ============================================================
# UI SETUP
# ============================================================

func _build_ui() -> void:
	_empty_label = Label.new()
	_empty_label.text = "Select a node to inspect"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_empty_label)
	_empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.size_flags_horizontal = SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	scroll.add_child(_content)

	# --- Mode Banner (prefab mode only) ---
	_mode_banner = PanelContainer.new()
	_mode_banner.visible = false
	_content.add_child(_mode_banner)

	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = Color(0.2, 0.4, 0.7, 0.6)
	banner_style.corner_radius_top_left = 3
	banner_style.corner_radius_top_right = 3
	banner_style.corner_radius_bottom_left = 3
	banner_style.corner_radius_bottom_right = 3
	banner_style.content_margin_left = 6
	banner_style.content_margin_right = 6
	banner_style.content_margin_top = 4
	banner_style.content_margin_bottom = 4
	_mode_banner.add_theme_stylebox_override("panel", banner_style)

	var banner_hbox := HBoxContainer.new()
	_mode_banner.add_child(banner_hbox)

	_mode_banner_label = Label.new()
	_mode_banner_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_mode_banner_label.add_theme_color_override("font_color", Color(1, 1, 1))
	banner_hbox.add_child(_mode_banner_label)

	var back_btn := Button.new()
	back_btn.text = "Back to Node"
	back_btn.pressed.connect(_on_back_to_node_pressed)
	banner_hbox.add_child(back_btn)

	# --- Is Root ---
	_root_panel = HBoxContainer.new()
	_content.add_child(_root_panel)

	var root_label := Label.new()
	root_label.text = "Is Root"
	root_label.size_flags_horizontal = SIZE_EXPAND_FILL
	root_label.tooltip_text = "Is this node a starting node?"
	root_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_root_panel.add_child(root_label)

	_root_check = CheckBox.new()
	_root_check.text = "On"
	_root_check.size_flags_horizontal = SIZE_EXPAND_FILL
	_root_check.toggled.connect(_on_root_toggled)
	_root_panel.add_child(_root_check)

	# --- Info ---
	_info_panel = VBoxContainer.new()
	_content.add_child(_info_panel)

	_id_input = _add_line_row(_info_panel, "ID", "Auto-generated ID", true)
	_name_input = _add_line_row(_info_panel, "Name", "Node display name", false)
	_name_input.text_changed.connect(_on_name_changed)

	var desc_row := HBoxContainer.new()
	_info_panel.add_child(desc_row)
	var desc_label := Label.new()
	desc_label.text = "Description"
	desc_label.size_flags_horizontal = SIZE_EXPAND_FILL
	desc_label.tooltip_text = "Node description"
	desc_label.mouse_filter = Control.MOUSE_FILTER_PASS
	desc_row.add_child(desc_label)

	_description_input = TextEdit.new()
	_description_input.custom_minimum_size = Vector2(0, 60)
	_description_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_description_input.text_changed.connect(_on_description_changed)
	desc_row.add_child(_description_input)

	_max_alloc_panel = HBoxContainer.new()
	_info_panel.add_child(_max_alloc_panel)
	var max_alloc_label := Label.new()
	max_alloc_label.text = "Max Allocations"
	max_alloc_label.size_flags_horizontal = SIZE_EXPAND_FILL
	max_alloc_label.tooltip_text = "Max level for multi-allocation"
	max_alloc_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_max_alloc_panel.add_child(max_alloc_label)

	_max_alloc_input = SpinBox.new()
	_max_alloc_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_max_alloc_input.min_value = 1
	_max_alloc_input.value = 1
	_max_alloc_input.rounded = true
	_max_alloc_input.allow_greater = true
	_max_alloc_input.value_changed.connect(_on_max_alloc_changed)
	_max_alloc_panel.add_child(_max_alloc_input)

	# --- Prerequisite (non-root nodes only) ---
	_prereq_panel = HBoxContainer.new()
	_info_panel.add_child(_prereq_panel)
	var prereq_label := Label.new()
	prereq_label.text = "Prerequisite"
	prereq_label.size_flags_horizontal = SIZE_EXPAND_FILL
	prereq_label.tooltip_text = "How many incoming neighbors must be active for this node to be allocatable."
	prereq_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_prereq_panel.add_child(prereq_label)

	_prereq_dropdown = OptionButton.new()
	_prereq_dropdown.size_flags_horizontal = SIZE_EXPAND_FILL
	_prereq_dropdown.add_item("Any (1+)", 0)
	_prereq_dropdown.add_item("Count", 1)
	_prereq_dropdown.add_item("All", 2)
	_prereq_dropdown.select(0)
	_prereq_dropdown.item_selected.connect(_on_prereq_mode_changed)
	_prereq_panel.add_child(_prereq_dropdown)

	_prereq_count_panel = HBoxContainer.new()
	_info_panel.add_child(_prereq_count_panel)
	var prereq_count_label := Label.new()
	prereq_count_label.text = "  Required"
	prereq_count_label.size_flags_horizontal = SIZE_EXPAND_FILL
	prereq_count_label.tooltip_text = "Number of incoming neighbors that must be active (only used in Count mode)."
	prereq_count_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_prereq_count_panel.add_child(prereq_count_label)

	_prereq_count_input = SpinBox.new()
	_prereq_count_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_prereq_count_input.min_value = 1
	_prereq_count_input.max_value = 99
	_prereq_count_input.value = 1
	_prereq_count_input.rounded = true
	_prereq_count_input.allow_greater = true
	_prereq_count_input.value_changed.connect(_on_prereq_count_changed)
	_prereq_count_panel.add_child(_prereq_count_input)

	# --- Transform ---
	_transform_panel = VBoxContainer.new()
	_content.add_child(_transform_panel)

	var pos_row := HBoxContainer.new()
	_transform_panel.add_child(pos_row)
	var pos_label := Label.new()
	pos_label.text = "Position"
	pos_label.size_flags_horizontal = SIZE_EXPAND_FILL
	pos_label.mouse_filter = Control.MOUSE_FILTER_PASS
	pos_row.add_child(pos_label)

	var pos_vbox := VBoxContainer.new()
	pos_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	pos_vbox.add_theme_constant_override("separation", 2)
	pos_row.add_child(pos_vbox)

	var x_row := HBoxContainer.new()
	pos_vbox.add_child(x_row)
	var x_label := Label.new()
	x_label.text = "X"
	x_label.custom_minimum_size = Vector2(20, 0)
	x_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	x_row.add_child(x_label)
	_pos_x_input = SpinBox.new()
	_pos_x_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_pos_x_input.rounded = true
	_pos_x_input.allow_greater = true
	_pos_x_input.allow_lesser = true
	_pos_x_input.value_changed.connect(_on_position_changed)
	x_row.add_child(_pos_x_input)

	var y_row := HBoxContainer.new()
	pos_vbox.add_child(y_row)
	var y_label := Label.new()
	y_label.text = "Y"
	y_label.custom_minimum_size = Vector2(20, 0)
	y_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.4))
	y_row.add_child(y_label)
	_pos_y_input = SpinBox.new()
	_pos_y_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_pos_y_input.rounded = true
	_pos_y_input.allow_greater = true
	_pos_y_input.allow_lesser = true
	_pos_y_input.value_changed.connect(_on_position_changed)
	y_row.add_child(_pos_y_input)

	# --- Visuals ---
	_visuals_panel = VBoxContainer.new()
	_content.add_child(_visuals_panel)

	var vis_sep := HSeparator.new()
	_visuals_panel.add_child(vis_sep)

	var vis_title := Label.new()
	vis_title.text = "Visuals"
	vis_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_visuals_panel.add_child(vis_title)

	_icon_input = BayterekInspectorTextureInput.new()
	_icon_input.title = "Icon"
	_visuals_panel.add_child(_icon_input)

	_border_normal_input = BayterekInspectorTextureInput.new()
	_border_normal_input.title = "Border Normal"
	_visuals_panel.add_child(_border_normal_input)

	_border_intermediate_input = BayterekInspectorTextureInput.new()
	_border_intermediate_input.title = "Border Intermediate"
	_visuals_panel.add_child(_border_intermediate_input)

	_border_active_input = BayterekInspectorTextureInput.new()
	_border_active_input.title = "Border Active"
	_visuals_panel.add_child(_border_active_input)

	# --- Attributes ---
	_attributes_panel = VBoxContainer.new()
	_content.add_child(_attributes_panel)

	var attr_sep := HSeparator.new()
	_attributes_panel.add_child(attr_sep)

	var attr_title := Label.new()
	attr_title.text = "Attributes"
	attr_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_attributes_panel.add_child(attr_title)

	_attributes_empty = Label.new()
	_attributes_empty.text = "(No attributes defined in tree)"
	_attributes_empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_attributes_panel.add_child(_attributes_empty)

	_attributes_list = VBoxContainer.new()
	_attributes_list.add_theme_constant_override("separation", 4)
	_attributes_panel.add_child(_attributes_list)

	# --- Connections ---
	_connections_panel = VBoxContainer.new()
	_content.add_child(_connections_panel)

	var conn_sep := HSeparator.new()
	_connections_panel.add_child(conn_sep)

	var conn_title := Label.new()
	conn_title.text = "Connections"
	conn_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_connections_panel.add_child(conn_title)

	_connections_empty = Label.new()
	_connections_empty.text = "(No outgoing connections)"
	_connections_empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_connections_panel.add_child(_connections_empty)

	_connections_list = VBoxContainer.new()
	_connections_list.add_theme_constant_override("separation", 4)
	_connections_panel.add_child(_connections_list)

func init(tree_view: BayterekTreeView) -> void:
	# Connect icon picker — use internal button references
	if _icon_input:
		if not _icon_input._load_button.pressed.is_connected(_on_icon_picker_pressed):
			_icon_input._load_button.pressed.connect(_on_icon_picker_pressed)
		if not _icon_input._clear_button.pressed.is_connected(_on_icon_texture_cleared):
			_icon_input._clear_button.pressed.connect(_on_icon_texture_cleared)
		if not _icon_input.texture_dropped.is_connected(_on_icon_texture_changed):
			_icon_input.texture_dropped.connect(_on_icon_texture_changed)

	# Border inputs
	if _border_normal_input:
		if not _border_normal_input._load_button.pressed.is_connected(_on_border_normal_picker_pressed):
			_border_normal_input._load_button.pressed.connect(_on_border_normal_picker_pressed)
		if not _border_normal_input._clear_button.pressed.is_connected(_on_border_normal_cleared):
			_border_normal_input._clear_button.pressed.connect(_on_border_normal_cleared)
		if not _border_normal_input.texture_dropped.is_connected(_on_border_normal_changed):
			_border_normal_input.texture_dropped.connect(_on_border_normal_changed)

	if _border_intermediate_input:
		if not _border_intermediate_input._load_button.pressed.is_connected(_on_border_intermediate_picker_pressed):
			_border_intermediate_input._load_button.pressed.connect(_on_border_intermediate_picker_pressed)
		if not _border_intermediate_input._clear_button.pressed.is_connected(_on_border_intermediate_cleared):
			_border_intermediate_input._clear_button.pressed.connect(_on_border_intermediate_cleared)
		if not _border_intermediate_input.texture_dropped.is_connected(_on_border_intermediate_changed):
			_border_intermediate_input.texture_dropped.connect(_on_border_intermediate_changed)

	if _border_active_input:
		if not _border_active_input._load_button.pressed.is_connected(_on_border_active_picker_pressed):
			_border_active_input._load_button.pressed.connect(_on_border_active_picker_pressed)
		if not _border_active_input._clear_button.pressed.is_connected(_on_border_active_cleared):
			_border_active_input._clear_button.pressed.connect(_on_border_active_cleared)
		if not _border_active_input.texture_dropped.is_connected(_on_border_active_changed):
			_border_active_input.texture_dropped.connect(_on_border_active_changed)

# ============================================================
# PUBLIC
# ============================================================

func refresh_attributes() -> void:
	_rebuild_attributes_list()

func remove_attribute_from_node(attr_id: String) -> void:
	if _current_node:
		if _current_node.node_data.attributes.has(attr_id):
			_current_node.node_data.attributes.erase(attr_id)
	_rebuild_attributes_list()

# ============================================================
# VISIBILITY
# ============================================================

func _show_empty() -> void:
	_empty_label.visible = true
	_content.visible = false
	_current_prefab = null

func _show_content() -> void:
	_empty_label.visible = false
	_content.visible = true

# ============================================================
# INSPECT NODE
# ============================================================

func inspect(node: BayterekNodeButton) -> void:
	_current_prefab = null
	_mode_banner.visible = false
	_root_check.disabled = false

	_current_node = node

	if not node or not node.node_data:
		_show_empty()
		return

	_show_content()
	_update_reset_all_button(node)

	_root_panel.visible = true
	_transform_panel.visible = true
	_connections_panel.visible = true

	_updating_ui = true

	_id_input.text = node.node_data.external_id if not node.node_data.external_id.is_empty() else str(node.node_data.id)
	_name_input.text = node.node_data.name
	_description_input.text = node.node_data.description
	_root_check.button_pressed = node.node_data.is_root
	_max_alloc_input.set_value_no_signal(node.node_data.max_allocations)

	_pos_x_input.set_value_no_signal(node.node_data.position.x)
	_pos_y_input.set_value_no_signal(node.node_data.position.y)

	_set_input_texture(_icon_input, node.node_data.icon)
	_set_input_texture(_border_normal_input, node.node_data.border_normal)
	_set_input_texture(_border_intermediate_input, node.node_data.border_intermediate)
	_set_input_texture(_border_active_input, node.node_data.border_active)

	_max_alloc_panel.visible = editor and editor.tree and editor.tree.multiallocation

	# Prerequisite UI: shown only for non-root nodes
	var show_prereq: bool = not node.node_data.is_root
	_prereq_panel.visible = show_prereq
	_prereq_count_panel.visible = show_prereq and node.node_data.prerequisite_mode == BayterekNode.PrerequisiteMode.COUNT
	if show_prereq:
		_prereq_dropdown.select(int(node.node_data.prerequisite_mode))
		_prereq_count_input.set_value_no_signal(node.node_data.prerequisite_count)

	_updating_ui = false

	_rebuild_attributes_list()
	_rebuild_connections_list()

# ============================================================
# INSPECT PREFAB
# ============================================================

func inspect_prefab(prefab: BayterekPrefab) -> void:
	if not prefab:
		return

	_current_node = null
	_current_prefab = prefab

	_show_content()
	_update_reset_all_button(null)

	_mode_banner.visible = true
	_mode_banner_label.text = "Editing Prefab: %s" % prefab.node_name

	_root_panel.visible = false
	_transform_panel.visible = false
	_connections_panel.visible = false
	_max_alloc_panel.visible = false
	_prereq_panel.visible = false
	_prereq_count_panel.visible = false

	_updating_ui = true

	_id_input.text = prefab.reference_id if not prefab.reference_id.is_empty() else "(copy)"
	_name_input.text = prefab.node_name
	_description_input.text = prefab.description

	_set_input_texture(_icon_input, prefab.icon)
	_set_input_texture(_border_normal_input, prefab.border_normal)
	_set_input_texture(_border_intermediate_input, prefab.border_intermediate)
	_set_input_texture(_border_active_input, prefab.border_active)

	_updating_ui = false

	_rebuild_attributes_list()

func _on_back_to_node_pressed() -> void:
	_current_prefab = null
	_mode_banner.visible = false

	if _current_node:
		inspect(_current_node)
	else:
		_show_empty()

func update_position_only(pos: Vector2) -> void:
	if _updating_ui:
		return
	_updating_ui = true
	_pos_x_input.set_value_no_signal(pos.x)
	_pos_y_input.set_value_no_signal(pos.y)
	_updating_ui = false

# ============================================================
# HELPER — set/get texture input
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
# CHANGE HANDLERS
# ============================================================

func _on_root_toggled(pressed: bool) -> void:
	if _updating_ui or not _current_node:
		return
	if _current_prefab:
		return
	# Use the property setter so refresh_visuals() is triggered automatically.
	_current_node.is_root = pressed
	if editor and editor.has_method("notify_node_root_changed"):
		editor.notify_node_root_changed(_current_node)

	# Update prerequisite panel visibility based on new root status
	var show_prereq: bool = not _current_node.node_data.is_root
	_prereq_panel.visible = show_prereq
	_prereq_count_panel.visible = show_prereq and _current_node.node_data.prerequisite_mode == BayterekNode.PrerequisiteMode.COUNT

	changed.emit()
	_notify_editor_dirty()

func _on_name_changed(new_text: String) -> void:
	if _updating_ui:
		return

	if _current_prefab:
		_current_prefab.set_node_name(new_text)
		changed.emit()
		_notify_editor_dirty()
		return

	if not _current_node:
		return

	if _current_node.prefab:
		_current_node.prefab.set_node_name(new_text)
	else:
		_current_node.node_data.name = new_text

	changed.emit()
	_notify_editor_dirty()

func _on_description_changed() -> void:
	if _updating_ui:
		return

	if _current_prefab:
		_current_prefab.set_description(_description_input.text)
		changed.emit()
		_notify_editor_dirty()
		return

	if not _current_node:
		return

	if _current_node.prefab:
		_current_node.prefab.set_description(_description_input.text)
	else:
		_current_node.node_data.description = _description_input.text

	changed.emit()
	_notify_editor_dirty()

func _on_max_alloc_changed(value: float) -> void:
	if _updating_ui or _current_prefab or not _current_node:
		return

	var new_max: int = int(value)

	if _current_node.prefab:
		_current_node.prefab.set_max_allocations(new_max)
	else:
		_current_node.node_data.max_allocations = new_max
		if editor and editor.tree and editor.tree.multiallocation:
			for attr_id in _current_node.node_data.attributes.keys():
				var data = _current_node.node_data.attributes[attr_id]
				if not data is Array:
					continue
				if data.size() > 0 and not data[0] is Array:
					var single: Array = data.duplicate()
					var new_data: Array = []
					for l in new_max:
						new_data.append(single.duplicate())
					_current_node.node_data.attributes[attr_id] = new_data
					continue
				var sample: Array = []
				if data.size() > 0:
					for v in data[0]:
						sample.append(v)
				while data.size() < new_max:
					data.append(sample.duplicate())
				while data.size() > new_max:
					data.pop_back()

	_rebuild_attributes_list()
	changed.emit()
	_notify_editor_dirty()

func _on_position_changed(_value: float) -> void:
	if _updating_ui or _current_prefab or not _current_node:
		return

	var new_pos := Vector2(_pos_x_input.value, _pos_y_input.value)
	_current_node.node_data.position = new_pos

	if editor and editor.tree_view and editor.tree_view.nodes_service:
		editor.tree_view.nodes_service.update_position(_current_node, new_pos)
		editor.tree_view.connections_service.update_lines_of(_current_node)

	changed.emit()
	_notify_editor_dirty()

# ============================================================
# ICON PICKER (spritesheet-based)
# ============================================================

func _on_icon_picker_pressed() -> void:
	if not _selected_node_valid():
		return

	# Decorations use quick-open (no spritesheet)
	if _current_node and _current_node.type == BayterekNode.NodeType.DECORATION:
		call_deferred("_open_quick_open_for_icon")
		return

	# Regular nodes: open icon selector
	if icon_selector:
		var node_type: int = BayterekNode.NodeType.SMALL
		if _current_node:
			node_type = _current_node.type
		icon_selector.load_icons(node_type)
		icon_selector.popup_centered()
	else:
		# Fallback: deferred quick-open
		call_deferred("_open_quick_open_for_icon")

func _open_quick_open_for_icon() -> void:
	EditorInterface.popup_quick_open(_on_icon_texture_changed, ["Texture2D"])

func _selected_node_valid() -> bool:
	if _current_prefab:
		return true
	return _current_node != null

# ============================================================
# ICON — TEXTURE HANDLERS
# ============================================================

func _on_icon_texture_changed(path: String) -> void:
	if _updating_ui:
		return
	if path.is_empty():
		_on_icon_texture_cleared()
		return

	var tex: Texture2D = load(path) as Texture2D
	if not tex:
		return

	# Prefab mode
	if _current_prefab:
		_current_prefab.set_icon(tex)
		_set_input_texture(_icon_input, tex)
		changed.emit()
		_notify_editor_dirty()
		return

	if not _current_node:
		return

	if _current_node.prefab:
		_current_node.prefab.set_icon(tex)
	else:
		_current_node.node_data.icon = tex
		if _current_node.has_method("refresh_visuals"):
			_current_node.refresh_visuals()

	_set_input_texture(_icon_input, tex)
	changed.emit()
	_notify_editor_dirty()

func _on_icon_texture_cleared() -> void:
	if _updating_ui:
		return

	_set_input_texture(_icon_input, null)

	if _current_prefab:
		_current_prefab.set_icon(null)
		changed.emit()
		_notify_editor_dirty()
		return

	if not _current_node:
		return

	if _current_node.prefab:
		_current_node.prefab.set_icon(null)
	else:
		_current_node.node_data.icon = null
		if _current_node.has_method("refresh_visuals"):
			_current_node.refresh_visuals()

	changed.emit()
	_notify_editor_dirty()

## Called by BayterekIconSelector when a region is selected
func _on_icon_selected(node_type: int, texture: Texture2D, region: Vector2) -> void:
	if not texture:
		return

	var icon_size: Vector2 = Vector2(64, 64)
	if editor and editor.tree:
		icon_size = editor.tree.icon_sizes.get(node_type, Vector2(64, 64))

	if icon_size == Vector2.ZERO:
		icon_size = Vector2(64, 64)

	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(region, icon_size)

	if _current_prefab:
		_current_prefab.set_icon(atlas)
		_set_input_texture(_icon_input, atlas)
		changed.emit()
		_notify_editor_dirty()
		return

	if not _current_node:
		return

	if _current_node.prefab:
		_current_node.prefab.set_icon(atlas)
	else:
		_current_node.node_data.icon = atlas
		if _current_node.has_method("refresh_visuals"):
			_current_node.refresh_visuals()

	_set_input_texture(_icon_input, atlas)
	changed.emit()
	_notify_editor_dirty()

# ============================================================
# BORDER — PICKER HANDLERS
# ============================================================

func _on_border_normal_picker_pressed() -> void:
	EditorInterface.popup_quick_open(_on_border_normal_changed, ["Texture2D"])

func _on_border_intermediate_picker_pressed() -> void:
	EditorInterface.popup_quick_open(_on_border_intermediate_changed, ["Texture2D"])

func _on_border_active_picker_pressed() -> void:
	EditorInterface.popup_quick_open(_on_border_active_changed, ["Texture2D"])

# ============================================================
# BORDER — TEXTURE HANDLERS
# ============================================================

func _on_border_normal_changed(path: String) -> void:
	if _updating_ui:
		return
	var tex: Texture2D = load(path) as Texture2D

	if _current_prefab:
		_current_prefab.set_border_normal(tex)
		_set_input_texture(_border_normal_input, tex)
		changed.emit()
		_notify_editor_dirty()
		return

	if not _current_node:
		return
	if _current_node.prefab:
		_current_node.prefab.set_border_normal(tex)
	else:
		_current_node.node_data.border_normal = tex
		if _current_node.has_method("refresh_visuals"):
			_current_node.refresh_visuals()
	_set_input_texture(_border_normal_input, tex)
	changed.emit()
	_notify_editor_dirty()

func _on_border_normal_cleared() -> void:
	if _updating_ui:
		return

	_set_input_texture(_border_normal_input, null)

	if _current_prefab:
		_current_prefab.set_border_normal(null)
		changed.emit()
		_notify_editor_dirty()
		return

	if not _current_node:
		return
	if _current_node.prefab:
		_current_node.prefab.set_border_normal(null)
	else:
		_current_node.node_data.border_normal = null
		if _current_node.has_method("refresh_visuals"):
			_current_node.refresh_visuals()
	changed.emit()
	_notify_editor_dirty()

func _on_border_intermediate_changed(path: String) -> void:
	if _updating_ui:
		return
	var tex: Texture2D = load(path) as Texture2D

	if _current_prefab:
		_current_prefab.set_border_intermediate(tex)
		_set_input_texture(_border_intermediate_input, tex)
		changed.emit()
		_notify_editor_dirty()
		return

	if not _current_node:
		return
	if _current_node.prefab:
		_current_node.prefab.set_border_intermediate(tex)
	else:
		_current_node.node_data.border_intermediate = tex
	_set_input_texture(_border_intermediate_input, tex)
	changed.emit()
	_notify_editor_dirty()

func _on_border_intermediate_cleared() -> void:
	if _updating_ui:
		return

	_set_input_texture(_border_intermediate_input, null)

	if _current_prefab:
		_current_prefab.set_border_intermediate(null)
		changed.emit()
		_notify_editor_dirty()
		return

	if not _current_node:
		return
	if _current_node.prefab:
		_current_node.prefab.set_border_intermediate(null)
	else:
		_current_node.node_data.border_intermediate = null
	changed.emit()
	_notify_editor_dirty()

func _on_border_active_changed(path: String) -> void:
	if _updating_ui:
		return
	var tex: Texture2D = load(path) as Texture2D

	if _current_prefab:
		_current_prefab.set_border_active(tex)
		_set_input_texture(_border_active_input, tex)
		changed.emit()
		_notify_editor_dirty()
		return

	if not _current_node:
		return
	if _current_node.prefab:
		_current_node.prefab.set_border_active(tex)
	else:
		_current_node.node_data.border_active = tex
	_set_input_texture(_border_active_input, tex)
	changed.emit()
	_notify_editor_dirty()

func _on_border_active_cleared() -> void:
	if _updating_ui:
		return

	_set_input_texture(_border_active_input, null)

	if _current_prefab:
		_current_prefab.set_border_active(null)
		changed.emit()
		_notify_editor_dirty()
		return

	if not _current_node:
		return
	if _current_node.prefab:
		_current_node.prefab.set_border_active(null)
	else:
		_current_node.node_data.border_active = null
	changed.emit()
	_notify_editor_dirty()

# ============================================================
# ATTRIBUTES
# ============================================================

func _rebuild_attributes_list() -> void:
	for child in _attributes_list.get_children():
		child.queue_free()
	_attr_checkboxes.clear()
	_attr_value_inputs.clear()

	if not editor or not editor.tree:
		_attributes_empty.visible = true
		return

	var tree_attrs: Dictionary = editor.tree.attributes
	if tree_attrs.is_empty():
		_attributes_empty.visible = true
		return

	_attributes_empty.visible = false

	var multi: bool = editor.tree.multiallocation
	var ids: Array = tree_attrs.keys()
	ids.sort()

	# ===== PREFAB MODE =====
	if _current_prefab:
		for attr_id in ids:
			var attr: BayterekAttribute = tree_attrs[attr_id]

			var block := VBoxContainer.new()
			block.add_theme_constant_override("separation", 2)
			_attributes_list.add_child(block)

			var check := CheckBox.new()
			check.text = "%s (%s)" % [attr.name, attr_id]
			check.button_pressed = _current_prefab.attributes.has(attr_id)
			check.toggled.connect(_on_attr_toggled_prefab.bind(attr_id))
			block.add_child(check)

			_attr_checkboxes[attr_id] = check

			if _current_prefab.attributes.has(attr_id):
				var raw = _current_prefab.attributes[attr_id]
				var info := Label.new()
				info.text = "  (default: %s)" % str(raw)
				info.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
				block.add_child(info)
		return

	# ===== NODE MODE =====
	for attr_id in ids:
		var attr: BayterekAttribute = tree_attrs[attr_id]

		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 2)
		_attributes_list.add_child(block)

		var header_row := HBoxContainer.new()
		header_row.add_theme_constant_override("separation", 2)
		block.add_child(header_row)

		var check := CheckBox.new()
		check.text = "%s (%s)" % [attr.name, attr_id]
		check.size_flags_horizontal = SIZE_EXPAND_FILL
		check.button_pressed = _current_node and _current_node.node_data.attributes.has(attr_id)
		check.toggled.connect(_on_attr_toggled.bind(attr_id))
		header_row.add_child(check)

		_attr_checkboxes[attr_id] = check

		if _current_node and _current_node.prefab and _current_node.node_data.has_attribute_override(attr_id):
			var reset_btn := Button.new()
			reset_btn.text = "↺"
			reset_btn.tooltip_text = "Reset to prefab default"
			reset_btn.custom_minimum_size = Vector2(28, 0)
			reset_btn.pressed.connect(_on_reset_attr_pressed.bind(attr_id))
			header_row.add_child(reset_btn)

		var has_attr: bool = _current_node and _current_node.node_data.attributes.has(attr_id)
		var attr_inputs: Dictionary = {}

		if multi and has_attr:
			var max_alloc: int = _current_node.node_data.max_allocations
			var raw_data = _current_node.node_data.attributes[attr_id]

			if not raw_data is Array:
				raw_data = []
				_current_node.node_data.attributes[attr_id] = raw_data
			if raw_data.size() > 0 and not raw_data[0] is Array:
				var single: Array = raw_data.duplicate()
				var new_data: Array = []
				for l in max_alloc:
					new_data.append(single.duplicate())
				raw_data = new_data
				_current_node.node_data.attributes[attr_id] = raw_data

			var levels_data: Array = raw_data

			for level in max_alloc:
				var level_box := VBoxContainer.new()
				level_box.add_theme_constant_override("separation", 1)
				block.add_child(level_box)

				var level_label := Label.new()
				level_label.text = "Level %d" % (level + 1)
				level_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.6))
				level_box.add_child(level_label)

				var inputs: Array = []
				var level_vals: Array = levels_data[level] if level < levels_data.size() else []

				for i in attr.value_count:
					var row := HBoxContainer.new()
					level_box.add_child(row)

					var vlabel := Label.new()
					vlabel.text = "Value %d" % (i + 1)
					vlabel.custom_minimum_size = Vector2(70, 0)
					row.add_child(vlabel)

					var spin := SpinBox.new()
					spin.size_flags_horizontal = SIZE_EXPAND_FILL
					spin.min_value = -999999999
					spin.max_value = 999999999
					spin.allow_greater = true
					spin.allow_lesser = true
					spin.rounded = true
					spin.step = 1

					if i < level_vals.size():
						spin.set_value_no_signal(level_vals[i])
					spin.editable = true

					spin.value_changed.connect(_on_attr_value_changed.bind(attr_id, i, level))
					row.add_child(spin)

					inputs.append(spin)

				attr_inputs[level] = inputs

		else:
			var values_row := VBoxContainer.new()
			values_row.add_theme_constant_override("separation", 1)
			block.add_child(values_row)

			var inputs: Array = []
			for i in attr.value_count:
				var row := HBoxContainer.new()
				values_row.add_child(row)

				var vlabel := Label.new()
				vlabel.text = "Value %d" % (i + 1)
				vlabel.custom_minimum_size = Vector2(70, 0)
				row.add_child(vlabel)

				var spin := SpinBox.new()
				spin.size_flags_horizontal = SIZE_EXPAND_FILL
				spin.min_value = -999999999
				spin.max_value = 999999999
				spin.allow_greater = true
				spin.allow_lesser = true
				spin.rounded = true
				spin.step = 1

				if has_attr:
					var vals = _current_node.node_data.attributes[attr_id]
					if vals is Array and i < vals.size() and not vals[i] is Array:
						spin.set_value_no_signal(vals[i])
					spin.editable = true
				else:
					spin.set_value_no_signal(0)
					spin.editable = false

				spin.value_changed.connect(_on_attr_value_changed.bind(attr_id, i, -1))
				row.add_child(spin)

				inputs.append(spin)

			attr_inputs[-1] = inputs

		_attr_value_inputs[attr_id] = attr_inputs

func _on_attr_toggled_prefab(pressed: bool, attr_id: String) -> void:
	if _updating_ui or not _current_prefab:
		return
	if not editor or not editor.tree:
		return
	if not editor.tree.attributes.has(attr_id):
		return

	var attr: BayterekAttribute = editor.tree.attributes[attr_id]
	var multi: bool = editor.tree.multiallocation

	if pressed:
		var new_values: Variant
		if multi:
			var levels: Array = []
			for level in _current_prefab.max_allocations:
				var values: Array = []
				for i in attr.value_count:
					values.append(0)
				levels.append(values)
			new_values = levels
		else:
			var values: Array = []
			for i in attr.value_count:
				values.append(0)
			new_values = values

		_current_prefab.set_attribute(attr_id, new_values)
	else:
		_current_prefab.remove_attribute(attr_id)

	_rebuild_attributes_list()
	editor.set_dirty(true)
	changed.emit()

func _on_attr_toggled(pressed: bool, attr_id: String) -> void:
	if _updating_ui or not _current_node:
		return
	if not editor or not editor.tree:
		return

	if not editor.tree.attributes.has(attr_id):
		return

	var attr: BayterekAttribute = editor.tree.attributes[attr_id]
	var multi: bool = editor.tree.multiallocation

	var new_values: Variant

	if pressed:
		if multi:
			var levels: Array = []
			for level in _current_node.node_data.max_allocations:
				var values: Array = []
				for i in attr.value_count:
					values.append(0)
				levels.append(values)
			new_values = levels
		else:
			var values: Array = []
			for i in attr.value_count:
				values.append(0)
			new_values = values

		if _current_node.prefab:
			_current_node.prefab.set_attribute(attr_id, new_values)
		else:
			_current_node.node_data.attributes[attr_id] = new_values
	else:
		if _current_node.prefab:
			_current_node.prefab.remove_attribute(attr_id)
		else:
			_current_node.node_data.attributes.erase(attr_id)

	if _attr_value_inputs.has(attr_id):
		var attr_inputs: Dictionary = _attr_value_inputs[attr_id]
		for level_key in attr_inputs.keys():
			var inputs: Array = attr_inputs[level_key]
			for spin in inputs:
				if is_instance_valid(spin):
					spin.editable = pressed

	editor.set_dirty(true)
	changed.emit()

	if multi:
		call_deferred("_rebuild_attributes_list")

func _on_attr_value_changed(value: float, attr_id: String, index: int, level: int) -> void:
	if _updating_ui or not _current_node:
		return
	if not _current_node.node_data.attributes.has(attr_id):
		return

	var v: Variant = value
	if typeof(value) == TYPE_FLOAT and value == floor(value):
		v = int(value)

	if level >= 0:
		var levels = _current_node.node_data.attributes[attr_id]
		if not levels is Array:
			return
		if level >= levels.size():
			return
		var level_vals = levels[level]
		if not level_vals is Array:
			return
		if index < 0 or index >= level_vals.size():
			return
		level_vals[index] = v
	else:
		var vals = _current_node.node_data.attributes[attr_id]
		if not vals is Array:
			return
		if vals.size() > 0 and vals[0] is Array:
			if index < 0 or index >= vals[0].size():
				return
			vals[0][index] = v
		else:
			if index < 0 or index >= vals.size():
				return
			vals[index] = v

	if _current_node.prefab:
		_current_node.node_data.mark_attribute_override(attr_id)

	editor.set_dirty(true)
	changed.emit()

# ============================================================
# CONNECTIONS
# ============================================================

func _rebuild_connections_list() -> void:
	for child in _connections_list.get_children():
		child.queue_free()

	if not _current_node:
		_connections_empty.visible = true
		return

	var out_ids: Array = _current_node.node_data.out_nodes
	if out_ids.is_empty():
		_connections_empty.visible = true
		return

	_connections_empty.visible = false

	for to_id in out_ids:
		_create_connection_entry(to_id)

func _create_connection_entry(to_id: int) -> void:
	var line_data = _current_node.node_data.line_data.get(to_id, null)
	if not line_data:
		line_data = BayterekLineData.new()
		_current_node.node_data.line_data[to_id] = line_data

	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	_connections_list.add_child(block)

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

	# --- Line Type ---
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

	# --- Line Style (Solid / Dashed / Dotted / Dash-Dot) ---
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

	# --- Dash Length (Dashed / Dotted / Dash-Dot) ---
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

	# --- Dash Gap (Dashed / Dotted / Dash-Dot) ---
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

	# --- Curve Height (Bezier only) ---
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

	# --- Step Distance (STEP only) ---
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

	# --- Segments (Bezier / Arc only) ---
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

	# --- Reversed (Bezier / Arc only) ---
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

	# --- Start Arrow ---
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

	# --- End Arrow ---
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

	# --- Arrow Size ---
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

	# --- Delete Button ---
	var del_row := HBoxContainer.new()
	content_box.add_child(del_row)
	var del_spacer := Control.new()
	del_spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	del_row.add_child(del_spacer)

	var del_btn := Button.new()
	del_btn.text = "Delete Connection"
	del_btn.pressed.connect(_on_delete_connection.bind(to_id))
	del_row.add_child(del_btn)

func _on_line_type_changed(index: int, to_id: int) -> void:
	if _updating_ui or not _current_node:
		return
	var line_data = _current_node.node_data.line_data.get(to_id, null)
	if not line_data:
		return

	line_data.line_type = index as BayterekLineData.LineType

	if editor and editor.tree_view:
		editor.tree_view.connections_service.refresh_line(_current_node.id, to_id)

	_rebuild_connections_list()
	editor.set_dirty(true)
	changed.emit()

func _on_line_style_changed(index: int, to_id: int) -> void:
	if _updating_ui or not _current_node:
		return
	var line_data = _current_node.node_data.line_data.get(to_id, null)
	if not line_data:
		return

	line_data.line_style = index as BayterekLineData.LineStyle

	if editor and editor.tree_view:
		editor.tree_view.connections_service.refresh_line(_current_node.id, to_id)

	_rebuild_connections_list()
	editor.set_dirty(true)
	changed.emit()

func _on_dash_length_changed(value: float, to_id: int) -> void:
	if _updating_ui or not _current_node:
		return
	var line_data = _current_node.node_data.line_data.get(to_id, null)
	if not line_data:
		return
	line_data.dash_length = value

	if editor and editor.tree_view:
		editor.tree_view.connections_service.refresh_line(_current_node.id, to_id)

	editor.set_dirty(true)
	changed.emit()

func _on_dash_gap_changed(value: float, to_id: int) -> void:
	if _updating_ui or not _current_node:
		return
	var line_data = _current_node.node_data.line_data.get(to_id, null)
	if not line_data:
		return
	line_data.dash_gap = value

	if editor and editor.tree_view:
		editor.tree_view.connections_service.refresh_line(_current_node.id, to_id)

	editor.set_dirty(true)
	changed.emit()

func _on_curve_height_changed(value: float, to_id: int) -> void:
	if _updating_ui or not _current_node:
		return
	var line_data = _current_node.node_data.line_data.get(to_id, null)
	if not line_data:
		return
	line_data.curve_height = value

	if editor and editor.tree_view:
		editor.tree_view.connections_service.refresh_line(_current_node.id, to_id)

	editor.set_dirty(true)
	changed.emit()

func _on_step_distance_changed(value: float, to_id: int) -> void:
	if _updating_ui or not _current_node:
		return
	var line_data = _current_node.node_data.line_data.get(to_id, null)
	if not line_data:
		return
	line_data.step_distance = value

	if editor and editor.tree_view:
		editor.tree_view.connections_service.refresh_line(_current_node.id, to_id)

	editor.set_dirty(true)
	changed.emit()

func _on_segments_changed(value: float, to_id: int) -> void:
	if _updating_ui or not _current_node:
		return
	var line_data = _current_node.node_data.line_data.get(to_id, null)
	if not line_data:
		return
	line_data.segments = int(value)

	if editor and editor.tree_view:
		editor.tree_view.connections_service.refresh_line(_current_node.id, to_id)

	editor.set_dirty(true)
	changed.emit()

func _on_reversed_changed(pressed: bool, to_id: int) -> void:
	if _updating_ui or not _current_node:
		return
	var line_data = _current_node.node_data.line_data.get(to_id, null)
	if not line_data:
		return
	line_data.reversed = pressed

	if editor and editor.tree_view:
		editor.tree_view.connections_service.refresh_line(_current_node.id, to_id)

	editor.set_dirty(true)
	changed.emit()

func _on_start_arrow_changed(index: int, to_id: int) -> void:
	if _updating_ui or not _current_node:
		return
	var line_data = _current_node.node_data.line_data.get(to_id, null)
	if not line_data:
		return
	line_data.start_arrow = index as BayterekLineData.ArrowStyle

	if editor and editor.tree_view:
		editor.tree_view.connections_service.refresh_line(_current_node.id, to_id)

	_rebuild_connections_list()
	editor.set_dirty(true)
	changed.emit()

func _on_end_arrow_changed(index: int, to_id: int) -> void:
	if _updating_ui or not _current_node:
		return
	var line_data = _current_node.node_data.line_data.get(to_id, null)
	if not line_data:
		return
	line_data.end_arrow = index as BayterekLineData.ArrowStyle

	if editor and editor.tree_view:
		editor.tree_view.connections_service.refresh_line(_current_node.id, to_id)

	_rebuild_connections_list()
	editor.set_dirty(true)
	changed.emit()

func _on_arrow_size_changed(value: float, to_id: int) -> void:
	if _updating_ui or not _current_node:
		return
	var line_data = _current_node.node_data.line_data.get(to_id, null)
	if not line_data:
		return
	line_data.arrow_size = value

	if editor and editor.tree_view:
		editor.tree_view.connections_service.refresh_line(_current_node.id, to_id)

	editor.set_dirty(true)
	changed.emit()

func _on_delete_connection(to_id: int) -> void:
	if not _current_node:
		return
	if not editor or not editor.tree_view:
		return

	editor.tree_view.connections_service.remove_connection(_current_node.id, to_id)
	_rebuild_connections_list()
	editor.set_dirty(true)
	changed.emit()

# ============================================================
# HELPERS
# ============================================================

func _add_line_row(parent: Control, label_text: String, tooltip: String, readonly: bool) -> LineEdit:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	if not tooltip.is_empty():
		label.tooltip_text = tooltip
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(label)

	var edit := LineEdit.new()
	edit.size_flags_horizontal = SIZE_EXPAND_FILL
	edit.editable = not readonly
	row.add_child(edit)

	return edit

func _notify_editor_dirty() -> void:
	if editor and editor.has_method("set_dirty"):
		editor.set_dirty(true)

# ============================================================
# RESET TO PREFAB
# ============================================================

func _update_reset_all_button(node: BayterekNodeButton) -> void:
	if _reset_all_btn and is_instance_valid(_reset_all_btn):
		_reset_all_btn.queue_free()
		_reset_all_btn = null

	if not node or not node.prefab:
		return

	_reset_all_btn = Button.new()
	_reset_all_btn.text = "↺ Reset All to Prefab Defaults"
	_reset_all_btn.tooltip_text = "Clear all overrides, restore prefab defaults"
	_reset_all_btn.pressed.connect(_on_reset_all_pressed)
	_content.add_child(_reset_all_btn)
	_content.move_child(_reset_all_btn, 1)

func _on_reset_all_pressed() -> void:
	if not _current_node or not _current_node.prefab:
		return
	if not editor or not editor.tree_view or not editor.tree_view.prefabs_service:
		return

	editor.tree_view.prefabs_service.reset_node_to_prefab_defaults(_current_node)
	inspect(_current_node)
	editor.set_dirty(true)
	changed.emit()

func _on_reset_attr_pressed(attr_id: String) -> void:
	if not _current_node or not _current_node.prefab:
		return
	if not editor or not editor.tree_view or not editor.tree_view.prefabs_service:
		return

	editor.tree_view.prefabs_service.reset_attribute_to_prefab_default(_current_node, attr_id)
	_rebuild_attributes_list()
	editor.set_dirty(true)
	changed.emit()

func _on_prereq_mode_changed(index: int) -> void:
	if _updating_ui or not _current_node:
		return
	if _current_prefab:
		return
	_current_node.node_data.prerequisite_mode = index as BayterekNode.PrerequisiteMode
	_prereq_count_panel.visible = (index == BayterekNode.PrerequisiteMode.COUNT)
	changed.emit()
	_notify_editor_dirty()

func _on_prereq_count_changed(value: float) -> void:
	if _updating_ui or not _current_node:
		return
	if _current_prefab:
		return
	_current_node.node_data.prerequisite_count = int(value)
	changed.emit()
	_notify_editor_dirty()