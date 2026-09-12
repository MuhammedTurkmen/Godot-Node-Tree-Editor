@tool
class_name BayterekTreeEditorInspector
extends Control
## Node Inspector.

signal changed

var editor: BayterekEditor

var _current_node: BayterekNodeButton

var _empty_label: Label
var _content: VBoxContainer

var _root_panel: HBoxContainer
var _root_check: CheckBox

var _info_panel: VBoxContainer
var _id_input: LineEdit
var _name_input: LineEdit
var _description_input: TextEdit
var _max_alloc_panel: HBoxContainer
var _max_alloc_input: SpinBox

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
var _attr_checkboxes: Dictionary = {}  # attr_id -> CheckBox

var _updating_ui: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()
	_show_empty()

# ============================================================
# UI KURULUM
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

	# --- Is Root ---
	_root_panel = HBoxContainer.new()
	_content.add_child(_root_panel)

	var root_label := Label.new()
	root_label.text = "Is Root"
	root_label.size_flags_horizontal = SIZE_EXPAND_FILL
	root_label.tooltip_text = "Bu node 'başlangıç node'u mu?"
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

	_id_input = _add_line_row(_info_panel, "ID", "Otomatik atanan ID", true)
	_name_input = _add_line_row(_info_panel, "Name", "Node'un görünen adı", false)
	_name_input.text_changed.connect(_on_name_changed)

	var desc_row := HBoxContainer.new()
	_info_panel.add_child(desc_row)
	var desc_label := Label.new()
	desc_label.text = "Description"
	desc_label.size_flags_horizontal = SIZE_EXPAND_FILL
	desc_label.tooltip_text = "Node açıklaması"
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
	max_alloc_label.tooltip_text = "Multi-allocation için maksimum seviye"
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
	_icon_input.texture_dropped.connect(_on_icon_changed)
	_icon_input.cleared.connect(_on_icon_cleared)
	_visuals_panel.add_child(_icon_input)

	_border_normal_input = BayterekInspectorTextureInput.new()
	_border_normal_input.title = "Border Normal"
	_border_normal_input.texture_dropped.connect(_on_border_normal_changed)
	_border_normal_input.cleared.connect(_on_border_normal_cleared)
	_visuals_panel.add_child(_border_normal_input)

	_border_intermediate_input = BayterekInspectorTextureInput.new()
	_border_intermediate_input.title = "Border Intermediate"
	_border_intermediate_input.texture_dropped.connect(_on_border_intermediate_changed)
	_border_intermediate_input.cleared.connect(_on_border_intermediate_cleared)
	_visuals_panel.add_child(_border_intermediate_input)

	_border_active_input = BayterekInspectorTextureInput.new()
	_border_active_input.title = "Border Active"
	_border_active_input.texture_dropped.connect(_on_border_active_changed)
	_border_active_input.cleared.connect(_on_border_active_cleared)
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
	_attributes_empty.text = "(Tree'de attribute tanımlı değil)"
	_attributes_empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_attributes_panel.add_child(_attributes_empty)

	_attributes_list = VBoxContainer.new()
	_attributes_list.add_theme_constant_override("separation", 2)
	_attributes_panel.add_child(_attributes_list)

func init(tree_view: BayterekTreeView) -> void:
	pass

# ============================================================
# GÖRÜNÜM
# ============================================================

func _show_empty() -> void:
	_empty_label.visible = true
	_content.visible = false

func _show_content() -> void:
	_empty_label.visible = false
	_content.visible = true

func inspect(node: BayterekNodeButton) -> void:
	_current_node = node

	if not node or not node.node_data:
		_show_empty()
		return

	_show_content()
	_updating_ui = true

	_id_input.text = node.node_data.external_id if not node.node_data.external_id.is_empty() else str(node.node_data.id)
	_name_input.text = node.node_data.name
	_description_input.text = node.node_data.description
	_root_check.button_pressed = node.node_data.is_root
	_max_alloc_input.set_value_no_signal(node.node_data.max_allocations)

	_pos_x_input.set_value_no_signal(node.node_data.position.x)
	_pos_y_input.set_value_no_signal(node.node_data.position.y)

	_icon_input.set_texture(node.node_data.icon)
	_border_normal_input.set_texture(node.node_data.border_normal)
	_border_intermediate_input.set_texture(node.node_data.border_intermediate)
	_border_active_input.set_texture(node.node_data.border_active)

	_max_alloc_panel.visible = editor and editor.tree and editor.tree.multiallocation

	_updating_ui = false

	# Attributes listesini yenile
	_rebuild_attributes_list()

func update_position_only(pos: Vector2) -> void:
	if _updating_ui:
		return
	_updating_ui = true
	_pos_x_input.set_value_no_signal(pos.x)
	_pos_y_input.set_value_no_signal(pos.y)
	_updating_ui = false

# ============================================================
# DEĞİŞİKLİK HANDLER'LARI
# ============================================================

func _on_root_toggled(pressed: bool) -> void:
	if _updating_ui or not _current_node:
		return
	_current_node.node_data.is_root = pressed
	changed.emit()
	_notify_editor_dirty()

func _on_name_changed(new_text: String) -> void:
	if _updating_ui or not _current_node:
		return
	_current_node.node_data.name = new_text
	changed.emit()
	_notify_editor_dirty()

func _on_description_changed() -> void:
	if _updating_ui or not _current_node:
		return
	_current_node.node_data.description = _description_input.text
	changed.emit()
	_notify_editor_dirty()

func _on_max_alloc_changed(value: float) -> void:
	if _updating_ui or not _current_node:
		return
	_current_node.node_data.max_allocations = int(value)
	changed.emit()
	_notify_editor_dirty()

func _on_position_changed(_value: float) -> void:
	if _updating_ui or not _current_node:
		return

	var new_pos := Vector2(_pos_x_input.value, _pos_y_input.value)
	_current_node.node_data.position = new_pos

	if editor and editor.tree_view and editor.tree_view.nodes_service:
		editor.tree_view.nodes_service.update_position(_current_node, new_pos)
		editor.tree_view.connections_service.update_lines_of(_current_node)

	changed.emit()
	_notify_editor_dirty()

# --- Texture handlers ---

func _on_icon_changed(path: String) -> void:
	if _updating_ui or not _current_node:
		return
	var tex: Texture2D = load(path) as Texture2D
	_current_node.node_data.icon = tex
	if _current_node.has_method("refresh_visuals"):
		_current_node.refresh_visuals()
	changed.emit()
	_notify_editor_dirty()

func _on_icon_cleared() -> void:
	if _updating_ui or not _current_node:
		return
	_current_node.node_data.icon = null
	if _current_node.has_method("refresh_visuals"):
		_current_node.refresh_visuals()
	changed.emit()
	_notify_editor_dirty()

func _on_border_normal_changed(path: String) -> void:
	if _updating_ui or not _current_node:
		return
	_current_node.node_data.border_normal = load(path) as Texture2D
	if _current_node.has_method("refresh_visuals"):
		_current_node.refresh_visuals()
	changed.emit()
	_notify_editor_dirty()

func _on_border_normal_cleared() -> void:
	if _updating_ui or not _current_node:
		return
	_current_node.node_data.border_normal = null
	if _current_node.has_method("refresh_visuals"):
		_current_node.refresh_visuals()
	changed.emit()
	_notify_editor_dirty()

func _on_border_intermediate_changed(path: String) -> void:
	if _updating_ui or not _current_node:
		return
	_current_node.node_data.border_intermediate = load(path) as Texture2D
	changed.emit()
	_notify_editor_dirty()

func _on_border_intermediate_cleared() -> void:
	if _updating_ui or not _current_node:
		return
	_current_node.node_data.border_intermediate = null
	changed.emit()
	_notify_editor_dirty()

func _on_border_active_changed(path: String) -> void:
	if _updating_ui or not _current_node:
		return
	_current_node.node_data.border_active = load(path) as Texture2D
	changed.emit()
	_notify_editor_dirty()

func _on_border_active_cleared() -> void:
	if _updating_ui or not _current_node:
		return
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

	if not editor or not editor.tree:
		_attributes_empty.visible = true
		return

	var tree_attrs: Dictionary = editor.tree.attributes
	if tree_attrs.is_empty():
		_attributes_empty.visible = true
		return

	_attributes_empty.visible = false

	var ids: Array = tree_attrs.keys()
	ids.sort()

	for attr_id in ids:
		var attr: BayterekAttribute = tree_attrs[attr_id]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_attributes_list.add_child(row)

		var check := CheckBox.new()
		check.text = "%s (%s)" % [attr.name, attr_id]
		check.size_flags_horizontal = SIZE_EXPAND_FILL
		check.button_pressed = _current_node and _current_node.node_data.attributes.has(attr_id)
		check.toggled.connect(_on_attr_toggled.bind(attr_id))
		row.add_child(check)

		_attr_checkboxes[attr_id] = check

func _on_attr_toggled(pressed: bool, attr_id: String) -> void:
	if _updating_ui or not _current_node:
		return
	if not editor or not editor.tree:
		return

	if not editor.tree.attributes.has(attr_id):
		return

	if pressed:
		var attr: BayterekAttribute = editor.tree.attributes[attr_id]
		var values: Array = []
		for i in attr.value_count:
			values.append(0)
		_current_node.node_data.attributes[attr_id] = values
	else:
		_current_node.node_data.attributes.erase(attr_id)

	editor.set_dirty(true)
	changed.emit()

# ============================================================
# YARDIMCI
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