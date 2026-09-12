@tool
class_name BayterekTreeEditorInspector
extends Control
## Node Inspector.

signal changed

var editor: BayterekEditor

var _current_node: BayterekNodeButton

# UI referansları
var _empty_label: Label
var _content: VBoxContainer

# Is Root
var _root_panel: HBoxContainer
var _root_check: CheckBox

# Info
var _info_panel: VBoxContainer
var _id_input: LineEdit
var _name_input: LineEdit
var _description_input: TextEdit
var _max_alloc_panel: HBoxContainer
var _max_alloc_input: SpinBox

# Transform
var _transform_panel: VBoxContainer
var _pos_x_input: SpinBox
var _pos_y_input: SpinBox

var _updating_ui: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()
	_show_empty()

# ============================================================
# UI KURULUM
# ============================================================

func _build_ui() -> void:
	# Boş durum
	_empty_label = Label.new()
	_empty_label.text = "Select a node to inspect"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_empty_label)
	_empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# İçerik scroll
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

	# ID
	var id_row := HBoxContainer.new()
	_info_panel.add_child(id_row)

	var id_label := Label.new()
	id_label.text = "ID"
	id_label.size_flags_horizontal = SIZE_EXPAND_FILL
	id_label.tooltip_text = "Otomatik atanan ID (okunamaz)"
	id_label.mouse_filter = Control.MOUSE_FILTER_PASS
	id_row.add_child(id_label)

	_id_input = LineEdit.new()
	_id_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_id_input.editable = false
	id_row.add_child(_id_input)

	# Name
	var name_row := HBoxContainer.new()
	_info_panel.add_child(name_row)

	var name_label := Label.new()
	name_label.text = "Name"
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	name_label.tooltip_text = "Node'un görünen adı"
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	name_row.add_child(name_label)

	_name_input = LineEdit.new()
	_name_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_name_input.text_changed.connect(_on_name_changed)
	name_row.add_child(_name_input)

	# Description
	var desc_row := HBoxContainer.new()
	_info_panel.add_child(desc_row)

	var desc_label := Label.new()
	desc_label.text = "Description"
	desc_label.size_flags_horizontal = SIZE_EXPAND_FILL
	desc_label.size_flags_vertical = 0
	desc_label.tooltip_text = "Node açıklaması (tooltip'te gösterilir)"
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
	max_alloc_label.tooltip_text = "Multi-allocation aktifse maksimum seviye"
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
	pos_label.tooltip_text = "Node pozisyonu (tree merkezine göre)"
	pos_label.mouse_filter = Control.MOUSE_FILTER_PASS
	pos_row.add_child(pos_label)

	var pos_vbox := VBoxContainer.new()
	pos_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	pos_vbox.add_theme_constant_override("separation", 2)
	pos_row.add_child(pos_vbox)

	# X
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
	_pos_x_input.step = 1
	_pos_x_input.value_changed.connect(_on_position_changed)
	x_row.add_child(_pos_x_input)

	# Y
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
	_pos_y_input.step = 1
	_pos_y_input.value_changed.connect(_on_position_changed)
	y_row.add_child(_pos_y_input)

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

	_max_alloc_panel.visible = editor and editor.tree and editor.tree.multiallocation

	_updating_ui = false

# ============================================================
# POZİSYON GÜNCELLEME (dışarıdan çağrılır)
# ============================================================

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

# ============================================================
# YARDIMCI
# ============================================================

func _notify_editor_dirty() -> void:
	if editor and editor.has_method("set_dirty"):
		editor.set_dirty(true)