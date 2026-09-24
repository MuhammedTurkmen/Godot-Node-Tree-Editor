@tool
class_name BayterekInspectorAttributes
extends VBoxContainer
## Attributes editor for the Node Inspector.
##
## Renders the list of tree-defined attributes and lets the user enable,
## disable and edit per-node / per-prefab attribute values. Supports
## multi-allocation levels when the tree has `multiallocation = true`.
##
## Owned by BayterekTreeEditorInspector.

signal changed

var inspector: BayterekTreeEditorInspector

# UI
var _sep: HSeparator
var _title: Label
var _empty_label: Label
var _list: VBoxContainer

# Per-attribute state
var _attr_checkboxes: Dictionary = {}      # attr_id -> CheckBox
var _attr_value_inputs: Dictionary = {}    # attr_id -> Dictionary[level -> Array[SpinBox]]

var _updating_ui: bool = false

func _ready() -> void:
	add_theme_constant_override("separation", 4)
	_build_ui()

func _build_ui() -> void:
	_sep = HSeparator.new()
	add_child(_sep)

	_title = Label.new()
	_title.text = "Attributes"
	_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	add_child(_title)

	_empty_label = Label.new()
	_empty_label.text = "(No attributes defined in tree)"
	_empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	add_child(_empty_label)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	add_child(_list)

# ============================================================
# PUBLIC API
# ============================================================

func refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	_attr_checkboxes.clear()
	_attr_value_inputs.clear()

	if not inspector or not inspector.editor or not inspector.editor.tree:
		visible = false
		return

	var tree_attrs: Dictionary = inspector.editor.tree.attributes
	if tree_attrs.is_empty():
		visible = true
		_empty_label.visible = true
		return

	visible = true
	_empty_label.visible = false

	var multi: bool = inspector.editor.tree.multiallocation
	var ids: Array = tree_attrs.keys()
	ids.sort()

	if inspector._current_prefab:
		for attr_id in ids:
			_build_prefab_row(attr_id, tree_attrs[attr_id])
		return

	if not inspector._current_node or not inspector._current_node.node_data:
		visible = false
		return

	for attr_id in ids:
		_build_node_row(attr_id, tree_attrs[attr_id], multi)

# ============================================================
# PREFAB MODE
# ============================================================

func _build_prefab_row(attr_id: String, attr: BayterekAttribute) -> void:
	var prefab: BayterekPrefab = inspector._current_prefab

	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	_list.add_child(block)

	var check := CheckBox.new()
	check.text = "%s (%s)" % [attr.name, attr_id]
	check.button_pressed = prefab.attributes.has(attr_id)
	check.toggled.connect(_on_attr_toggled_prefab.bind(attr_id))
	block.add_child(check)

	_attr_checkboxes[attr_id] = check

	if prefab.attributes.has(attr_id):
		var raw = prefab.attributes[attr_id]
		var info := Label.new()
		info.text = "  (default: %s)" % str(raw)
		info.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		block.add_child(info)

# ============================================================
# NODE MODE
# ============================================================

func _build_node_row(attr_id: String, attr: BayterekAttribute, multi: bool) -> void:
	var node: BayterekNodeButton = inspector._current_node

	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	_list.add_child(block)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 2)
	block.add_child(header_row)

	var check := CheckBox.new()
	check.text = "%s (%s)" % [attr.name, attr_id]
	check.size_flags_horizontal = SIZE_EXPAND_FILL
	check.button_pressed = node.node_data.attributes.has(attr_id)
	check.toggled.connect(_on_attr_toggled.bind(attr_id))
	header_row.add_child(check)

	_attr_checkboxes[attr_id] = check

	if node.prefab and node.node_data.has_attribute_override(attr_id):
		var reset_btn := Button.new()
		reset_btn.text = "↺"
		reset_btn.tooltip_text = "Reset to prefab default"
		reset_btn.custom_minimum_size = Vector2(28, 0)
		reset_btn.pressed.connect(_on_reset_attr_pressed.bind(attr_id))
		header_row.add_child(reset_btn)

	var has_attr: bool = node.node_data.attributes.has(attr_id)
	var attr_inputs: Dictionary = {}

	if multi and has_attr:
		var max_alloc: int = node.node_data.max_allocations
		var raw_data = node.node_data.attributes[attr_id]

		if not raw_data is Array:
			raw_data = []
			node.node_data.attributes[attr_id] = raw_data
		if raw_data.size() > 0 and not raw_data[0] is Array:
			var single: Array = raw_data.duplicate()
			var new_data: Array = []
			for l in max_alloc:
				new_data.append(single.duplicate())
			raw_data = new_data
			node.node_data.attributes[attr_id] = raw_data

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
				var vals = node.node_data.attributes[attr_id]
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

# ============================================================
# HANDLERS
# ============================================================

func _on_attr_toggled_prefab(pressed: bool, attr_id: String) -> void:
	if _updating_ui or not inspector._current_prefab:
		return
	if not inspector.editor or not inspector.editor.tree:
		return
	if not inspector.editor.tree.attributes.has(attr_id):
		return

	var attr: BayterekAttribute = inspector.editor.tree.attributes[attr_id]
	var multi: bool = inspector.editor.tree.multiallocation

	if pressed:
		var new_values: Variant
		if multi:
			var levels: Array = []
			for level in inspector._current_prefab.max_allocations:
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

		inspector._current_prefab.set_attribute(attr_id, new_values)
	else:
		inspector._current_prefab.remove_attribute(attr_id)

	refresh()
	if inspector.editor:
		inspector.editor.set_dirty(true)
	changed.emit()

func _on_attr_toggled(pressed: bool, attr_id: String) -> void:
	if _updating_ui or not inspector._current_node:
		return
	if not inspector.editor or not inspector.editor.tree:
		return
	if not inspector.editor.tree.attributes.has(attr_id):
		return

	var attr: BayterekAttribute = inspector.editor.tree.attributes[attr_id]
	var multi: bool = inspector.editor.tree.multiallocation

	if pressed:
		var new_values: Variant
		if multi:
			var levels: Array = []
			for level in inspector._current_node.node_data.max_allocations:
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

		if inspector._current_node.prefab:
			inspector._current_node.prefab.set_attribute(attr_id, new_values)
		else:
			inspector._current_node.node_data.attributes[attr_id] = new_values
	else:
		if inspector._current_node.prefab:
			inspector._current_node.prefab.remove_attribute(attr_id)
		else:
			inspector._current_node.node_data.attributes.erase(attr_id)

	if _attr_value_inputs.has(attr_id):
		var attr_inputs: Dictionary = _attr_value_inputs[attr_id]
		for level_key in attr_inputs.keys():
			var inputs: Array = attr_inputs[level_key]
			for spin in inputs:
				if is_instance_valid(spin):
					spin.editable = pressed

	if inspector.editor:
		inspector.editor.set_dirty(true)
	changed.emit()

	if multi:
		refresh.call_deferred()

func _on_attr_value_changed(value: float, attr_id: String, index: int, level: int) -> void:
	if _updating_ui or not inspector._current_node:
		return
	if not inspector._current_node.node_data.attributes.has(attr_id):
		return

	var v: Variant = value
	if typeof(value) == TYPE_FLOAT and value == floor(value):
		v = int(value)

	if level >= 0:
		var levels = inspector._current_node.node_data.attributes[attr_id]
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
		var vals = inspector._current_node.node_data.attributes[attr_id]
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

	if inspector._current_node.prefab:
		inspector._current_node.node_data.mark_attribute_override(attr_id)

	if inspector.editor:
		inspector.editor.set_dirty(true)
	changed.emit()

func _on_reset_attr_pressed(attr_id: String) -> void:
	if not inspector._current_node or not inspector._current_node.prefab:
		return
	if not inspector.editor or not inspector.editor.tree_view or not inspector.editor.tree_view.prefabs_service:
		return
	inspector.editor.tree_view.prefabs_service.reset_attribute_to_prefab_default(
		inspector._current_node, attr_id)
	refresh()
	if inspector.editor:
		inspector.editor.set_dirty(true)
	changed.emit()