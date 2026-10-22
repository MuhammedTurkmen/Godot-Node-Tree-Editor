@tool
class_name BayterekInspectorExportedFields
extends VBoxContainer
## Exported Fields editor for the Node Inspector.
##
## Supports two kinds of exported fields:
##   1. Simple scalar fields — Value: layers.<id>.transform.scale, etc.
##   2. Dict config fields — a single export path represents an entire
##      state config dict like layers.<id>.tint_configs.normal. These
##      are split into two sub-editors:
##        - "Enabled" checkbox
##        - "Color" / "Texture" editor
##
## The export model change: the user only right-clicks ONCE on the row
## in the Node Editor. Both enabled and color/texture are exported
## together under a single field path.

signal changed

var inspector: BayterekTreeEditorInspector

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
	_list.add_theme_constant_override("separation", 8)
	add_child(_list)

# ============================================================
# PUBLIC API
# ============================================================

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

	_build_grouped_fields(prefab, design, true)

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

	_build_grouped_fields(prefab, design, false)

# ============================================================
# GROUPED BUILD
# ============================================================

func _build_grouped_fields(prefab: BayterekPrefab, design: BayterekNodeDesign, is_prefab: bool) -> void:
	var all_paths: Dictionary = {}
	if design:
		for p in design.exported_fields.keys():
			all_paths[p] = true
	if prefab:
		for p in prefab.exported_fields.keys():
			all_paths[p] = true

	if all_paths.is_empty():
		return

	var design_paths: Array = []
	var layer_paths: Dictionary = {}

	for path in all_paths.keys():
		if path == "design_size" or path == "scale":
			design_paths.append(path)
			continue

		var parts: Array = path.split(".")
		if parts.size() >= 2 and parts[0] == "layers":
			var layer_id: String = parts[1]
			if not layer_paths.has(layer_id):
				layer_paths[layer_id] = []
			layer_paths[layer_id].append(path)

	if not design_paths.is_empty():
		_build_layer_block("Design", design_paths, prefab, design, is_prefab)

	if design:
		for layer in design.layers:
			if not layer:
				continue
			if not layer_paths.has(layer.layer_id):
				continue
			var paths: Array = layer_paths[layer.layer_id]
			paths.sort_custom(func(a, b): return _field_sort_key(a) < _field_sort_key(b))
			_build_layer_block(layer.layer_name, paths, prefab, design, is_prefab)

		for layer_id in layer_paths.keys():
			var found: bool = false
			for layer in design.layers:
				if layer and layer.layer_id == layer_id:
					found = true
					break
			if not found:
				var paths: Array = layer_paths[layer_id]
				paths.sort_custom(func(a, b): return _field_sort_key(a) < _field_sort_key(b))
				_build_layer_block("Layer %s" % layer_id.substr(0, 8), paths, prefab, design, is_prefab)
	else:
		for layer_id in layer_paths.keys():
			var paths: Array = layer_paths[layer_id]
			paths.sort_custom(func(a, b): return _field_sort_key(a) < _field_sort_key(b))
			_build_layer_block("Layer %s" % layer_id.substr(0, 8), paths, prefab, design, is_prefab)

func _build_layer_block(layer_name: String, paths: Array, prefab: BayterekPrefab, design: BayterekNodeDesign, is_prefab: bool) -> void:
	if paths.is_empty():
		return

	var header := PanelContainer.new()
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(0.15, 0.22, 0.35, 0.6)
	header_style.corner_radius_top_left = 3
	header_style.corner_radius_top_right = 3
	header_style.corner_radius_bottom_left = 3
	header_style.corner_radius_bottom_right = 3
	header_style.content_margin_left = 8
	header_style.content_margin_right = 8
	header_style.content_margin_top = 4
	header_style.content_margin_bottom = 4
	header.add_theme_stylebox_override("panel", header_style)
	_list.add_child(header)

	var header_label := Label.new()
	header_label.text = layer_name
	header_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	header_label.add_theme_font_size_override("font_size", 12)
	header.add_child(header_label)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 3)
	_list.add_child(body)

	for path in paths:
		var is_override: bool = false
		if not is_prefab and inspector._current_node and inspector._current_node.node_data:
			is_override = inspector._current_node.node_data.has_exported_override(path)
		_build_field_row(body, prefab, path, design, is_prefab, is_override)

# ============================================================
# FIELD ROW
# ============================================================

func _build_field_row(
	parent: VBoxContainer,
	prefab: BayterekPrefab,
	field_path: String,
	design: BayterekNodeDesign,
	is_prefab: bool,
	is_override: bool
) -> void:
	# Detect if this field is a "config dict" — i.e. its last segment
	# is a state name (normal / hover / ...) and its root is one of
	# the config dict keys (tint_configs / icon_configs).
	var config_kind: String = _detect_config_kind(field_path)

	if config_kind != "":
		_build_config_dict_row(parent, prefab, field_path, design, is_prefab, is_override, config_kind)
	else:
		_build_scalar_field_row(parent, prefab, field_path, design, is_prefab, is_override)


## Returns "tint" / "icon" / "" depending on the field kind.
func _detect_config_kind(field_path: String) -> String:
	var parts: Array = field_path.split(".")
	if parts.size() < 4:
		return ""
	# Expect: layers.<layer_id>.<config_key>.<state>
	if parts[0] != "layers":
		return ""
	var config_key: String = parts[2]
	if config_key == "tint_configs":
		return "tint"
	if config_key == "icon_configs":
		return "icon"
	return ""


## Splits the state name off the export path so we can build the
## per-field humanized labels.
func _split_config_path(field_path: String) -> Dictionary:
	var parts: Array = field_path.split(".")
	if parts.size() < 4:
		return {}
	return {
		"layer_id": parts[1],
		"config_key": parts[2],
		"state": parts[3],
	}


# ------------------------------------------------------------
# CONFIG DICT ROW (tint / icon state)
# ------------------------------------------------------------

func _build_config_dict_row(
	parent: VBoxContainer,
	prefab: BayterekPrefab,
	field_path: String,
	design: BayterekNodeDesign,
	is_prefab: bool,
	is_override: bool,
	kind: String
) -> void:
	var info: Dictionary = _split_config_path(field_path)
	if info.is_empty():
		return

	var state: String = info["state"]
	var state_label: String = _humanize_single(state)

	# Get the current dict value.
	var current_dict: Dictionary = {}
	var design_value: Variant = null
	if design:
		design_value = design.get_field_value(field_path)
	if design_value is Dictionary:
		current_dict = (design_value as Dictionary).duplicate(true)

	if not is_prefab:
		var node = inspector._current_node
		if node and node.node_data and node.node_data.exported_overrides.has(field_path):
			var override_value: Variant = node.node_data.exported_overrides[field_path]
			if override_value is Dictionary:
				current_dict = (override_value as Dictionary).duplicate(true)
		elif prefab and prefab.exported_values.has(field_path):
			var prefab_value: Variant = prefab.exported_values[field_path]
			if prefab_value is Dictionary:
				current_dict = (prefab_value as Dictionary).duplicate(true)
	else:
		if prefab and prefab.exported_values.has(field_path):
			var prefab_value: Variant = prefab.exported_values[field_path]
			if prefab_value is Dictionary:
				current_dict = (prefab_value as Dictionary).duplicate(true)

	# Outer block
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 3)
	parent.add_child(block)

	# Header row: label + reset button
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 4)
	block.add_child(header_row)

	var title := Label.new()
	title.text = state_label
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	title.add_theme_font_size_override("font_size", 12)
	header_row.add_child(title)

	if not is_prefab and is_override:
		var reset_btn := Button.new()
		reset_btn.text = "↺"
		reset_btn.tooltip_text = "Reset to default"
		reset_btn.custom_minimum_size = Vector2(28, 0)
		reset_btn.pressed.connect(_on_reset_override_pressed.bind(prefab, field_path))
		header_row.add_child(reset_btn)

	# Enabled sub-row
	var enabled_row := HBoxContainer.new()
	enabled_row.add_theme_constant_override("separation", 4)
	block.add_child(enabled_row)

	var enabled_label := Label.new()
	enabled_label.text = "Enabled"
	enabled_label.custom_minimum_size = Vector2(70, 0)
	enabled_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	enabled_row.add_child(enabled_label)

	var enabled_check := CheckBox.new()
	enabled_check.text = "On"
	enabled_check.size_flags_horizontal = SIZE_EXPAND_FILL
	enabled_check.button_pressed = bool(current_dict.get("enabled", false))
	enabled_check.toggled.connect(func(pressed: bool):
		var updated: Dictionary = current_dict.duplicate(true)
		updated["enabled"] = pressed
		_apply_config_value(field_path, updated, is_prefab, prefab)
	)
	enabled_row.add_child(enabled_check)

	# Value sub-row (color or texture)
	var value_row := HBoxContainer.new()
	value_row.add_theme_constant_override("separation", 4)
	block.add_child(value_row)

	if kind == "tint":
		var color_label := Label.new()
		color_label.text = "Color"
		color_label.custom_minimum_size = Vector2(70, 0)
		color_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
		value_row.add_child(color_label)

		var color_picker := ColorPickerButton.new()
		color_picker.size_flags_horizontal = SIZE_EXPAND_FILL
		color_picker.custom_minimum_size = Vector2(0, 24)
		var current_color: Color = current_dict.get("color", Color.WHITE)
		color_picker.color = current_color
		color_picker.color_changed.connect(func(c: Color):
			var updated: Dictionary = current_dict.duplicate(true)
			updated["color"] = c
			_apply_config_value(field_path, updated, is_prefab, prefab)
		)
		value_row.add_child(color_picker)

	elif kind == "icon":
		var tex_label := Label.new()
		tex_label.text = "Texture"
		tex_label.custom_minimum_size = Vector2(70, 0)
		tex_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
		value_row.add_child(tex_label)

		var tex_input := BayterekInspectorTextureInput.new()
		tex_input.title = ""
		tex_input.size_flags_horizontal = SIZE_EXPAND_FILL
		var current_tex: Texture2D = current_dict.get("texture", null)
		tex_input.set_texture(current_tex)
		tex_input.texture_dropped.connect(func(path: String):
			var updated: Dictionary = current_dict.duplicate(true)
			var tex: Texture2D = load(path) as Texture2D
			updated["texture"] = tex
			_apply_config_value(field_path, updated, is_prefab, prefab)
		)
		tex_input.cleared.connect(func():
			var updated: Dictionary = current_dict.duplicate(true)
			updated["texture"] = null
			_apply_config_value(field_path, updated, is_prefab, prefab)
		)
		value_row.add_child(tex_input)


## Applies a full config dict to the target (node override or prefab
## exported_values). This is the single entry point for both enabled
## and value changes.
func _apply_config_value(
	field_path: String,
	value: Dictionary,
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


# ------------------------------------------------------------
# SCALAR FIELD ROW (existing behavior)
# ------------------------------------------------------------

func _build_scalar_field_row(
	parent: VBoxContainer,
	prefab: BayterekPrefab,
	field_path: String,
	design: BayterekNodeDesign,
	is_prefab: bool,
	is_override: bool
) -> void:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	parent.add_child(block)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 4)
	block.add_child(header_row)

	var name_label := Label.new()
	name_label.text = _humanize_field_path(field_path)
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
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

# ============================================================
# HUMANIZE FIELD PATH
# ============================================================

func _humanize_field_path(field_path: String) -> String:
	var parts: Array = field_path.split(".")
	if parts.size() < 3:
		return field_path

	var sub: Array = []
	for i in range(2, parts.size()):
		sub.append(parts[i])

	if sub.size() == 1:
		return _humanize_single(sub[0])

	if sub.size() == 2 and sub[0] == "transform":
		return _humanize_single(sub[1])

	var out: Array[String] = []
	for s in sub:
		out.append(_humanize_single(String(s)))
	return " › ".join(out)

func _humanize_single(s: String) -> String:
	match s:
		"scale": return "Scale"
		"position": return "Position"
		"size": return "Size"
		"rotation": return "Rotation"
		"skew": return "Skew"
		"flip_x": return "Flip X"
		"flip_y": return "Flip Y"
		"pivot": return "Pivot"
		"pivot_mode": return "Pivot Mode"
		"scale_from_pivot": return "Scale From Pivot"
		"visible": return "Visible"
		"layer_name": return "Name"
		"render_mode_override": return "Render Mode"
		"texture_filter_override": return "Texture Filter"
		"icon_enabled": return "Icon Enabled"
		"tint_enabled": return "Tint Enabled"
		"stretch_mode": return "Stretch Mode"
		"nine_patch_draw_center": return "9-Patch Draw Center"
		"icon_configs": return "Icon"
		"tint_configs": return "Tint"
		"normal": return "Normal"
		"hover": return "Hover"
		"clicked": return "Clicked"
		"locked": return "Locked"
		"preallocated": return "Preallocated"
		"prerefund": return "Pre-Refund"
		"max_level": return "Max Level"
		"allocateable": return "Allocateable"
		"not_allocateable": return "Not Allocateable"
		"enabled": return "Enabled"
		"color": return "Color"
		"texture": return "Texture"
		_:
			return s.capitalize()

# ============================================================
# SORTING
# ============================================================

func _field_sort_key(path: String) -> int:
	if path.ends_with(".transform.scale"): return 10
	if path.ends_with(".transform.position"): return 20
	if path.ends_with(".transform.size"): return 30
	if path.ends_with(".transform.rotation"): return 40
	if path.ends_with(".transform.skew"): return 50
	if path.ends_with(".transform.flip_x"): return 60
	if path.ends_with(".transform.flip_y"): return 61
	if path.ends_with(".transform.pivot"): return 70
	if path.ends_with(".transform.pivot_mode"): return 71
	if path.ends_with(".transform.scale_from_pivot"): return 72
	if path.ends_with(".visible"): return 100
	if path.ends_with(".layer_name"): return 101
	if path.ends_with(".render_mode_override"): return 110
	if path.ends_with(".texture_filter_override"): return 111
	return 500

# ============================================================
# SCALAR VALUE EDITORS
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

			var x_lbl := Label.new()
			x_lbl.text = "X"
			x_lbl.custom_minimum_size = Vector2(16, 0)
			x_lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
			parent.add_child(x_lbl)

			var sx := SpinBox.new()
			sx.size_flags_horizontal = SIZE_EXPAND_FILL
			sx.min_value = -99999
			sx.max_value = 99999
			sx.allow_lesser = true
			sx.allow_greater = true
			sx.step = 0.01
			sx.value = v2.x
			sx.value_changed.connect(func(v: float):
				v2.x = v
				_on_value_changed(field_path, v2, is_prefab, prefab)
			)
			parent.add_child(sx)

			var y_lbl := Label.new()
			y_lbl.text = "Y"
			y_lbl.custom_minimum_size = Vector2(16, 0)
			y_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 0.4))
			parent.add_child(y_lbl)

			var sy := SpinBox.new()
			sy.size_flags_horizontal = SIZE_EXPAND_FILL
			sy.min_value = -99999
			sy.max_value = 99999
			sy.allow_lesser = true
			sy.allow_greater = true
			sy.step = 0.01
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