@tool
class_name BayterekInspectorExportedFields
extends VBoxContainer
## Exported Fields editor for the Node Inspector.
##
## Renders the list of fields exported by a node's design (or prefab),
## with per-field value editors that write back to the node or prefab
## depending on the current inspector mode.
##
## Owned by BayterekTreeEditorInspector.

signal changed

## The inspector that owns this panel.
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
	_title.text = "Exported Fields"
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	add_child(_title)

	_empty_label = Label.new()
	_empty_label.text = "(No fields exported from this design)"
	_empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	add_child(_empty_label)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	add_child(_list)

# ============================================================
# PUBLIC API
# ============================================================

## Rebuilds the panel from the inspector's current context.
func refresh() -> void:
	_clear_list()

	if not inspector:
		visible = false
		return

	if inspector._current_prefab:
		_build_for_prefab()
		return

	if not inspector._current_node or not inspector._current_node.node_data:
		visible = false
		return

	_build_for_node()

# ============================================================
# BUILD — PREFAB MODE
# ============================================================

func _build_for_prefab() -> void:
	var prefab: BayterekPrefab = inspector._current_prefab
	if not prefab or prefab.exported_fields.is_empty():
		visible = true
		_empty_label.text = "(No fields exported from this design)"
		_empty_label.visible = true
		return

	visible = true
	_empty_label.visible = false

	var design: BayterekNodeDesign = null
	if not prefab.design_id.is_empty():
		design = Bayterek.get_designs_registry().get_design_by_id(prefab.design_id)

	var paths: Array = prefab.exported_fields.keys()
	paths.sort()

	for field_path in paths:
		_build_field_row(prefab, field_path, design, true, false)

# ============================================================
# BUILD — NODE MODE
# ============================================================

func _build_for_node() -> void:
	var node: BayterekNodeButton = inspector._current_node
	if not node or not node.node_data:
		visible = false
		return

	var design_id: String = node.node_data.design_id
	var design: BayterekNodeDesign = null
	if not design_id.is_empty():
		design = Bayterek.get_designs_registry().get_design_by_id(design_id)

	var prefab: BayterekPrefab = node.prefab

	var paths: Array = []
	if prefab and not prefab.exported_fields.is_empty():
		paths = prefab.exported_fields.keys()
	elif design and not design.exported_fields.is_empty():
		paths = design.exported_fields.keys()

	if paths.is_empty():
		visible = true
		_empty_label.text = "(No fields exported on this design)"
		_empty_label.visible = true
		return

	visible = true
	_empty_label.visible = false
	paths.sort()

	for field_path in paths:
		var is_override: bool = node.node_data.has_exported_override(field_path)
		_build_field_row(prefab, field_path, design, false, is_override)

# ============================================================
# FIELD ROW
# ============================================================

func _build_field_row(
	prefab: BayterekPrefab,
	field_path: String,
	design: BayterekNodeDesign,
	is_prefab: bool,
	is_override: bool
) -> void:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	_list.add_child(block)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 4)
	block.add_child(header_row)

	var name_label := Label.new()
	name_label.text = _humanize_field_path(field_path)
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	name_label.add_theme_font_size_override("font_size", 12)
	header_row.add_child(name_label)

	if not is_prefab and is_override:
		var reset_btn := Button.new()
		reset_btn.text = "↺"
		reset_btn.tooltip_text = "Reset to default"
		reset_btn.custom_minimum_size = Vector2(28, 0)
		reset_btn.pressed.connect(_on_reset_override_pressed.bind(prefab, field_path))
		header_row.add_child(reset_btn)

	var value_row := HBoxContainer.new()
	value_row.add_theme_constant_override("separation", 4)
	block.add_child(value_row)

	var design_value: Variant = null
	if design:
		design_value = design.get_field_value(field_path)

	var current_value: Variant = design_value
	if is_prefab:
		if prefab and prefab.exported_values.has(field_path):
			current_value = prefab.exported_values[field_path]
	else:
		var node = inspector._current_node
		if node and node.node_data and node.node_data.exported_overrides.has(field_path):
			current_value = node.node_data.exported_overrides[field_path]
		elif prefab and prefab.exported_values.has(field_path):
			current_value = prefab.exported_values[field_path]

	_build_value_editor(value_row, field_path, current_value, is_prefab, prefab)

func _humanize_field_path(field_path: String) -> String:
	var parts: Array = field_path.split(".")
	if parts.size() <= 1:
		return field_path

	var out: Array[String] = []
	for i in parts.size():
		var p: String = parts[i]
		if p == "layers":
			continue
		if i == 1:
			var short_id: String = p.substr(0, 6) + "…" if p.length() > 6 else p
			out.append("Layer %s" % short_id)
			continue
		out.append(p)

	return " › ".join(out)

# ============================================================
# VALUE EDITORS
# ============================================================

func _build_value_editor(
	parent: HBoxContainer,
	field_path: String,
	value: Variant,
	is_prefab: bool,
	prefab: BayterekPrefab
) -> void:
	match typeof(value):
		TYPE_BOOL:
			var check := CheckBox.new()
			check.text = "On"
			check.button_pressed = value
			check.size_flags_horizontal = SIZE_EXPAND_FILL
			check.toggled.connect(func(v: bool):
				_on_value_changed(field_path, v, is_prefab, prefab)
			)
			parent.add_child(check)

		TYPE_INT:
			var spin := SpinBox.new()
			spin.size_flags_horizontal = SIZE_EXPAND_FILL
			spin.min_value = -999999999
			spin.max_value = 999999999
			spin.allow_greater = true
			spin.allow_lesser = true
			spin.rounded = true
			spin.value = int(value)
			spin.value_changed.connect(func(v: float):
				_on_value_changed(field_path, int(v), is_prefab, prefab)
			)
			parent.add_child(spin)

		TYPE_FLOAT:
			var spin := SpinBox.new()
			spin.size_flags_horizontal = SIZE_EXPAND_FILL
			spin.min_value = -999999999.0
			spin.max_value = 999999999.0
			spin.step = 0.1
			spin.allow_greater = true
			spin.allow_lesser = true
			spin.value = float(value)
			spin.value_changed.connect(func(v: float):
				_on_value_changed(field_path, v, is_prefab, prefab)
			)
			parent.add_child(spin)

		TYPE_COLOR:
			var picker := ColorPickerButton.new()
			picker.size_flags_horizontal = SIZE_EXPAND_FILL
			picker.custom_minimum_size = Vector2(0, 22)
			picker.color = value
			picker.color_changed.connect(func(c: Color):
				_on_value_changed(field_path, c, is_prefab, prefab)
			)
			parent.add_child(picker)

		TYPE_VECTOR2:
			var v2: Vector2 = value
			var sx := SpinBox.new()
			sx.size_flags_horizontal = SIZE_EXPAND_FILL
			sx.min_value = -99999
			sx.max_value = 99999
			sx.allow_lesser = true
			sx.allow_greater = true
			sx.value = v2.x
			sx.value_changed.connect(func(v: float):
				v2.x = v
				_on_value_changed(field_path, v2, is_prefab, prefab)
			)
			parent.add_child(sx)

			var sy := SpinBox.new()
			sy.size_flags_horizontal = SIZE_EXPAND_FILL
			sy.min_value = -99999
			sy.max_value = 99999
			sy.allow_lesser = true
			sy.allow_greater = true
			sy.value = v2.y
			sy.value_changed.connect(func(v: float):
				v2.y = v
				_on_value_changed(field_path, v2, is_prefab, prefab)
			)
			parent.add_child(sy)

		TYPE_STRING:
			var edit := LineEdit.new()
			edit.size_flags_horizontal = SIZE_EXPAND_FILL
			edit.text = String(value)
			edit.text_changed.connect(func(t: String):
				_on_value_changed(field_path, t, is_prefab, prefab)
			)
			parent.add_child(edit)

		_:
			var lbl := Label.new()
			lbl.text = str(value)
			lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			parent.add_child(lbl)

# ============================================================
# HANDLERS
# ============================================================

func _on_value_changed(
	field_path: String,
	value: Variant,
	is_prefab: bool,
	prefab: BayterekPrefab
) -> void:
	if _updating_ui:
		return

	if is_prefab:
		if not prefab:
			return
		prefab.exported_values[field_path] = value
		prefab.exported_values_changed.emit(prefab)

		if inspector.editor and inspector.editor.tree_view and inspector.editor.tree_view.prefabs_service:
			inspector.editor.tree_view.prefabs_service.notify_exported_values_changed(prefab)
	else:
		if not inspector._current_node or not inspector._current_node.node_data:
			return
		inspector._current_node.node_data.set_exported_override(field_path, value)
		inspector._current_node.rebuild_from_design()

	changed.emit()
	if inspector.editor and inspector.editor.has_method("set_dirty"):
		inspector.editor.set_dirty(true)

func _on_reset_override_pressed(_prefab: BayterekPrefab, field_path: String) -> void:
	if not inspector._current_node or not inspector._current_node.node_data:
		return
	inspector._current_node.node_data.clear_exported_override(field_path)
	inspector._current_node.rebuild_from_design()
	refresh()
	changed.emit()
	if inspector.editor and inspector.editor.has_method("set_dirty"):
		inspector.editor.set_dirty(true)

# ============================================================
# CLEANUP
# ============================================================

func _clear_list() -> void:
	for child in _list.get_children():
		child.queue_free()