@tool
class_name BayterekTreeEditorInspector
extends Control
## Node Inspector with Prefab mode support.
##
## The three content panels (Exported Fields, Attributes, Connections)
## are separated into their own scripts. This file coordinates them and
## owns the top-level layout (mode banner, root toggle, info rows,
## design dropdown, transform, etc.).

signal changed

var editor: BayterekEditor

var _current_node: BayterekNodeButton
var _current_prefab: BayterekPrefab = null

var _empty_label: Label
var _content: VBoxContainer

var _mode_banner: PanelContainer
var _mode_banner_label: Label

var _reset_all_btn: Button = null

var _root_panel: HBoxContainer
var _root_check: CheckBox

var _info_panel: VBoxContainer
var _id_input: LineEdit
var _name_input: LineEdit
var _description_input: TextEdit
var _max_alloc_panel: HBoxContainer
var _max_alloc_input: SpinBox
var _group_display: Label

var _design_row: HBoxContainer
var _design_dropdown: OptionButton

var _design_size_row: HBoxContainer
var _design_size_label: Label
var _scale_row: HBoxContainer
var _scale_x_input: SpinBox
var _scale_y_input: SpinBox

var _prereq_panel: HBoxContainer
var _prereq_dropdown: OptionButton
var _prereq_count_panel: HBoxContainer
var _prereq_count_input: SpinBox
var _prereq_group_panel: HBoxContainer
var _prereq_group_dropdown: OptionButton

var _transform_panel: VBoxContainer
var _pos_x_input: SpinBox
var _pos_y_input: SpinBox

# --- Sub-panels (own scripts) ---
var _exported_fields: BayterekInspectorExportedFields
var _attributes: BayterekInspectorAttributes
var _connections: BayterekInspectorConnections

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

	# --- Mode Banner ---
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

	# Design selector
	_design_row = HBoxContainer.new()
	_info_panel.add_child(_design_row)

	var design_label := Label.new()
	design_label.text = "Design"
	design_label.size_flags_horizontal = SIZE_EXPAND_FILL
	design_label.tooltip_text = "Node design (visual layer stack)"
	design_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_design_row.add_child(design_label)

	_design_dropdown = OptionButton.new()
	_design_dropdown.size_flags_horizontal = SIZE_EXPAND_FILL
	_design_dropdown.item_selected.connect(_on_design_changed)
	_design_row.add_child(_design_dropdown)

	# Design Size (read-only)
	_design_size_row = HBoxContainer.new()
	_info_panel.add_child(_design_size_row)

	var dss_label := Label.new()
	dss_label.text = "Design Size"
	dss_label.size_flags_horizontal = SIZE_EXPAND_FILL
	dss_label.tooltip_text = "Base size (from design). Read-only."
	dss_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_design_size_row.add_child(dss_label)

	_design_size_label = Label.new()
	_design_size_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_design_size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_design_size_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	_design_size_row.add_child(_design_size_label)

	# Scale
	_scale_row = HBoxContainer.new()
	_info_panel.add_child(_scale_row)

	var scale_label := Label.new()
	scale_label.text = "Scale"
	scale_label.custom_minimum_size = Vector2(60, 0)
	scale_label.tooltip_text = "Multiplier applied to design_size. Final node size = design_size × scale."
	scale_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_scale_row.add_child(scale_label)

	var sx_label := Label.new()
	sx_label.text = "X"
	sx_label.custom_minimum_size = Vector2(20, 0)
	sx_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	_scale_row.add_child(sx_label)

	_scale_x_input = SpinBox.new()
	_scale_x_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_scale_x_input.min_value = 0.05
	_scale_x_input.max_value = 100.0
	_scale_x_input.step = 0.05
	_scale_x_input.rounded = false
	_scale_x_input.value = 1.0
	_scale_x_input.value_changed.connect(_on_scale_changed)
	_scale_row.add_child(_scale_x_input)

	var sy_label := Label.new()
	sy_label.text = "Y"
	sy_label.custom_minimum_size = Vector2(20, 0)
	sy_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.4))
	_scale_row.add_child(sy_label)

	_scale_y_input = SpinBox.new()
	_scale_y_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_scale_y_input.min_value = 0.05
	_scale_y_input.max_value = 100.0
	_scale_y_input.step = 0.05
	_scale_y_input.rounded = false
	_scale_y_input.value = 1.0
	_scale_y_input.value_changed.connect(_on_scale_changed)
	_scale_row.add_child(_scale_y_input)

	# Description
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

	# Max Allocations
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

	# Group
	var group_row := HBoxContainer.new()
	_info_panel.add_child(group_row)

	var group_label := Label.new()
	group_label.text = "Group"
	group_label.size_flags_horizontal = SIZE_EXPAND_FILL
	group_label.tooltip_text = "Node group"
	group_label.mouse_filter = Control.MOUSE_FILTER_PASS
	group_row.add_child(group_label)

	_group_display = Label.new()
	_group_display.size_flags_horizontal = SIZE_EXPAND_FILL
	_group_display.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	group_row.add_child(_group_display)

	# Prerequisite
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
	_prereq_dropdown.add_item("Group Complete", 3)
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

	_prereq_group_panel = HBoxContainer.new()
	_info_panel.add_child(_prereq_group_panel)
	var prereq_group_label := Label.new()
	prereq_group_label.text = "  Prereq Group"
	prereq_group_label.size_flags_horizontal = SIZE_EXPAND_FILL
	prereq_group_label.tooltip_text = "Which group must be complete?"
	prereq_group_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_prereq_group_panel.add_child(prereq_group_label)

	_prereq_group_dropdown = OptionButton.new()
	_prereq_group_dropdown.size_flags_horizontal = SIZE_EXPAND_FILL
	_prereq_group_dropdown.item_selected.connect(_on_prereq_group_changed)
	_prereq_group_panel.add_child(_prereq_group_dropdown)

	# Transform
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

	# --- Sub-panels ---
	_exported_fields = BayterekInspectorExportedFields.new()
	_exported_fields.inspector = self
	_exported_fields.changed.connect(_on_subpanel_changed)
	_content.add_child(_exported_fields)

	_attributes = BayterekInspectorAttributes.new()
	_attributes.inspector = self
	_attributes.changed.connect(_on_subpanel_changed)
	_content.add_child(_attributes)

	_connections = BayterekInspectorConnections.new()
	_connections.inspector = self
	_connections.changed.connect(_on_subpanel_changed)
	_content.add_child(_connections)

func _on_subpanel_changed() -> void:
	changed.emit()

# ============================================================
# INIT
# ============================================================

func init(_tree_view: BayterekTreeView) -> void:
	pass

func refresh_attributes() -> void:
	if _attributes:
		_attributes.refresh()

func remove_attribute_from_node(attr_id: String) -> void:
	if _current_node:
		if _current_node.node_data.attributes.has(attr_id):
			_current_node.node_data.attributes.erase(attr_id)
	refresh_attributes()

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
	_design_row.visible = true
	_design_size_row.visible = true
	_scale_row.visible = true

	_updating_ui = true

	_id_input.text = node.node_data.external_id if not node.node_data.external_id.is_empty() else str(node.node_data.id)
	_name_input.text = node.node_data.name
	_description_input.text = node.node_data.description
	_root_check.button_pressed = node.node_data.is_root
	_max_alloc_input.set_value_no_signal(node.node_data.max_allocations)

	_pos_x_input.set_value_no_signal(node.node_data.position.x)
	_pos_y_input.set_value_no_signal(node.node_data.position.y)

	_scale_x_input.set_value_no_signal(node.node_data.scale.x)
	_scale_y_input.set_value_no_signal(node.node_data.scale.y)

	_refresh_design_size_label()

	_max_alloc_panel.visible = editor and editor.tree and editor.tree.multiallocation

	_update_group_display(node.node_data.group_id)
	_rebuild_design_dropdown(node.node_data.design_id)

	var show_prereq: bool = not node.node_data.is_root
	_prereq_panel.visible = show_prereq
	_prereq_count_panel.visible = show_prereq and node.node_data.prerequisite_mode == BayterekNode.PrerequisiteMode.COUNT
	_prereq_group_panel.visible = show_prereq and node.node_data.prerequisite_mode == BayterekNode.PrerequisiteMode.GROUP_COMPLETE
	if show_prereq:
		_prereq_dropdown.select(int(node.node_data.prerequisite_mode))
		_prereq_count_input.set_value_no_signal(node.node_data.prerequisite_count)
		if _prereq_group_panel.visible:
			_rebuild_prereq_group_dropdown()
			_select_prereq_group(node.node_data.prerequisite_group_id)

	_updating_ui = false

	_exported_fields.refresh()
	_attributes.refresh()
	_connections.refresh()

func _refresh_design_size_label() -> void:
	if not _design_size_label or not _current_node:
		return
	var ds: Vector2 = _current_node.node_data.design_size
	_design_size_label.text = "%d × %d" % [int(ds.x), int(ds.y)]

func _update_group_display(group_id: String) -> void:
	if not _group_display:
		return
	if group_id.is_empty():
		_group_display.text = "(none)"
		_group_display.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		return
	var grp: BayterekNodeGroup = editor.tree.get_group_by_id(group_id) if editor and editor.tree else null
	if grp:
		_group_display.text = grp.name
		_group_display.add_theme_color_override("font_color", grp.color)
	else:
		_group_display.text = "(missing)"
		_group_display.add_theme_color_override("font_color", Color(1, 0.4, 0.4))

# ============================================================
# DESIGN DROPDOWN
# ============================================================

func _rebuild_design_dropdown(selected_id: String) -> void:
	if not _design_dropdown:
		return
	_design_dropdown.clear()
	_design_dropdown.add_item("(none)", 0)
	_design_dropdown.set_item_metadata(0, "")

	var reg = Bayterek.get_designs_registry()
	if not reg:
		return

	var idx: int = 1
	var found_idx: int = 0
	for design in reg.designs:
		if not design:
			continue
		var label: String = design.name
		if not design.category.is_empty():
			label = "[%s] %s" % [design.category, design.name]
		_design_dropdown.add_item(label, idx)
		_design_dropdown.set_item_metadata(idx, design.id)
		if design.id == selected_id:
			found_idx = idx
		idx += 1

	_design_dropdown.select(found_idx)

func _on_design_changed(index: int) -> void:
	if _updating_ui or _current_prefab or not _current_node:
		return
	var meta = _design_dropdown.get_item_metadata(index)
	var design_id: String = "" if meta == null else String(meta)

	if design_id.is_empty():
		_current_node.node_data.design_id = ""
	else:
		var design: BayterekNodeDesign = Bayterek.get_designs_registry().get_design_by_id(design_id)
		if design:
			_current_node.node_data.apply_design(design)

	_current_node.rebuild_from_design()
	_refresh_design_size_label()
	_exported_fields.refresh()

	if editor and editor.tree_view and editor.tree_view.connections_service:
		editor.tree_view.connections_service.update_lines_of(_current_node)

	changed.emit()
	_notify_editor_dirty()

# ============================================================
# SCALE
# ============================================================

func _on_scale_changed(_value: float) -> void:
	if _updating_ui or _current_prefab or not _current_node:
		return

	var new_scale := Vector2(_scale_x_input.value, _scale_y_input.value)
	if new_scale.x <= 0.0:
		new_scale.x = 0.05
	if new_scale.y <= 0.0:
		new_scale.y = 0.05

	_current_node.node_data.scale = new_scale
	_current_node.refresh_visuals()

	if editor and editor.tree_view and editor.tree_view.connections_service:
		editor.tree_view.connections_service.update_lines_of(_current_node)

	changed.emit()
	_notify_editor_dirty()

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
	_prereq_panel.visible = false
	_prereq_count_panel.visible = false
	_prereq_group_panel.visible = false
	_design_row.visible = false
	_design_size_row.visible = false
	_scale_row.visible = false

	_max_alloc_panel.visible = editor and editor.tree and editor.tree.multiallocation

	_updating_ui = true
	_id_input.text = prefab.reference_id if not prefab.reference_id.is_empty() else "(copy)"
	_name_input.text = prefab.node_name
	_description_input.text = prefab.description
	_max_alloc_input.set_value_no_signal(prefab.max_allocations)
	_updating_ui = false

	_exported_fields.refresh()
	_attributes.refresh()
	_connections.refresh()

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
# CHANGE HANDLERS
# ============================================================

func _on_root_toggled(pressed: bool) -> void:
	if _updating_ui or not _current_node:
		return
	if _current_prefab:
		return
	_current_node.is_root = pressed
	if editor and editor.has_method("notify_node_root_changed"):
		editor.notify_node_root_changed(_current_node)

	var show_prereq: bool = not _current_node.node_data.is_root
	_prereq_panel.visible = show_prereq
	_prereq_count_panel.visible = show_prereq and _current_node.node_data.prerequisite_mode == BayterekNode.PrerequisiteMode.COUNT
	_prereq_group_panel.visible = show_prereq and _current_node.node_data.prerequisite_mode == BayterekNode.PrerequisiteMode.GROUP_COMPLETE

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

	if editor and editor.has_method("notify_node_display_changed"):
		editor.notify_node_display_changed(_current_node)

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

	if editor and editor.has_method("notify_node_display_changed"):
		editor.notify_node_display_changed(_current_node)

	changed.emit()
	_notify_editor_dirty()

func _on_max_alloc_changed(value: float) -> void:
	if _updating_ui:
		return

	var new_max: int = int(value)

	if _current_prefab:
		_current_prefab.set_max_allocations(new_max)
		_reshape_prefab_attribute_arrays(_current_prefab, new_max)
		_attributes.refresh()
		changed.emit()
		_notify_editor_dirty()
		return

	if not _current_node:
		return

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

	_attributes.refresh()
	changed.emit()
	_notify_editor_dirty()

func _reshape_prefab_attribute_arrays(prefab: BayterekPrefab, new_max: int) -> void:
	if not prefab:
		return
	if not editor or not editor.tree or not editor.tree.multiallocation:
		return

	for attr_id in prefab.attributes.keys():
		var data = prefab.attributes[attr_id]
		if not data is Array:
			continue

		if data.size() > 0 and not data[0] is Array:
			var single: Array = data.duplicate()
			var new_data: Array = []
			for l in new_max:
				new_data.append(single.duplicate())
			prefab.attributes[attr_id] = new_data
			continue

		var sample: Array = []
		if data.size() > 0:
			for v in data[0]:
				sample.append(v)
		while data.size() < new_max:
			data.append(sample.duplicate())
		while data.size() > new_max:
			data.pop_back()

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

func _on_prereq_mode_changed(index: int) -> void:
	if _updating_ui or not _current_node:
		return
	if _current_prefab:
		return
	_current_node.node_data.prerequisite_mode = index as BayterekNode.PrerequisiteMode
	_prereq_count_panel.visible = (index == BayterekNode.PrerequisiteMode.COUNT)
	_prereq_group_panel.visible = (index == BayterekNode.PrerequisiteMode.GROUP_COMPLETE)

	if _prereq_group_panel.visible:
		_rebuild_prereq_group_dropdown()
		_select_prereq_group(_current_node.node_data.prerequisite_group_id)

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

func _rebuild_prereq_group_dropdown() -> void:
	_prereq_group_dropdown.clear()
	if not editor or not editor.tree:
		return

	_prereq_group_dropdown.add_item("(none)", 0)

	var idx: int = 1
	for group in editor.tree.node_groups:
		if group:
			_prereq_group_dropdown.add_item(group.name, idx)
			_prereq_group_dropdown.set_item_metadata(idx, group.id)
			idx += 1

func _select_prereq_group(group_id: String) -> void:
	for i in _prereq_group_dropdown.item_count:
		var meta = _prereq_group_dropdown.get_item_metadata(i)
		if i == 0 and group_id.is_empty():
			_prereq_group_dropdown.select(0)
			return
		if meta == group_id:
			_prereq_group_dropdown.select(i)
			return
	_prereq_group_dropdown.select(0)

func _on_prereq_group_changed(index: int) -> void:
	if _updating_ui or not _current_node:
		return
	if _current_prefab:
		return
	var gid: String = ""
	if index > 0:
		var meta = _prereq_group_dropdown.get_item_metadata(index)
		if typeof(meta) == TYPE_STRING:
			gid = meta
	_current_node.node_data.prerequisite_group_id = gid
	changed.emit()
	_notify_editor_dirty()

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