@tool
class_name BayterekLayerEditor
extends VBoxContainer
## Middle-column layer editor.
## Top: layer list + toolbar.
## Bottom: detail form for the selected layer, grouped into foldable sections.

signal changed

var design: BayterekNodeDesign = null
var editor: BayterekEditor = null

var _layer_tree: Tree
var _layer_root: TreeItem
var _detail_scroll: ScrollContainer
var _detail_root: VBoxContainer

var _add_shape_btn: Button
var _add_texture_btn: Button
var _delete_btn: Button
var _up_btn: Button
var _down_btn: Button

var _context_menu: PopupMenu

var _selected_layer_index: int = -1
var _updating_ui: bool = false

# Context menu IDs
const CM_RENAME := 1
const CM_DUPLICATE := 2
const CM_DELETE := 3
const CM_MOVE_UP := 4
const CM_MOVE_DOWN := 5

func _ready() -> void:
	add_theme_constant_override("separation", 4)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	_build_ui()
	_build_context_menu()

func _build_ui() -> void:
	var top_box := VBoxContainer.new()
	top_box.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(top_box)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	top_box.add_child(toolbar)

	_add_shape_btn = Button.new()
	_add_shape_btn.text = "+ Shape"
	_add_shape_btn.tooltip_text = "Add a new shape layer"
	_add_shape_btn.pressed.connect(_on_add_shape_pressed)
	toolbar.add_child(_add_shape_btn)

	_add_texture_btn = Button.new()
	_add_texture_btn.text = "+ Texture"
	_add_texture_btn.tooltip_text = "Add a new texture layer"
	_add_texture_btn.pressed.connect(_on_add_texture_pressed)
	toolbar.add_child(_add_texture_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	_up_btn = Button.new()
	_up_btn.text = "▲"
	_up_btn.tooltip_text = "Move layer up"
	_up_btn.custom_minimum_size = Vector2(28, 0)
	_up_btn.pressed.connect(_on_up_pressed)
	toolbar.add_child(_up_btn)

	_down_btn = Button.new()
	_down_btn.text = "▼"
	_down_btn.tooltip_text = "Move layer down"
	_down_btn.custom_minimum_size = Vector2(28, 0)
	_down_btn.pressed.connect(_on_down_pressed)
	toolbar.add_child(_down_btn)

	_delete_btn = Button.new()
	_delete_btn.text = "✕"
	_delete_btn.tooltip_text = "Delete selected layer"
	_delete_btn.custom_minimum_size = Vector2(28, 0)
	_delete_btn.pressed.connect(_on_delete_pressed)
	toolbar.add_child(_delete_btn)

	_layer_tree = Tree.new()
	_layer_tree.hide_root = true
	_layer_tree.select_mode = Tree.SELECT_ROW
	_layer_tree.custom_minimum_size = Vector2(0, 165)
	_layer_tree.size_flags_horizontal = SIZE_EXPAND_FILL
	_layer_tree.item_selected.connect(_on_layer_selected)
	_layer_tree.button_clicked.connect(_on_layer_button_clicked)
	_layer_tree.gui_input.connect(_on_layer_gui_input)
	top_box.add_child(_layer_tree)
	_layer_root = _layer_tree.create_item()

	add_child(HSeparator.new())

	_detail_scroll = ScrollContainer.new()
	_detail_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(_detail_scroll)

	_detail_root = VBoxContainer.new()
	_detail_root.size_flags_horizontal = SIZE_EXPAND_FILL
	_detail_root.add_theme_constant_override("separation", 6)
	_detail_scroll.add_child(_detail_root)

func _build_context_menu() -> void:
	_context_menu = PopupMenu.new()
	_context_menu.add_item("Rename", CM_RENAME)
	_context_menu.add_item("Duplicate", CM_DUPLICATE)
	_context_menu.add_separator()
	_context_menu.add_item("Move Up", CM_MOVE_UP)
	_context_menu.add_item("Move Down", CM_MOVE_DOWN)
	_context_menu.add_separator()
	_context_menu.add_item("Delete", CM_DELETE)
	_context_menu.id_pressed.connect(_on_context_menu_pressed)
	add_child(_context_menu)

# ============================================================
# PUBLIC
# ============================================================

func set_design(d: BayterekNodeDesign) -> void:
	if design and design.layers_changed.is_connected(_on_design_layers_changed):
		design.layers_changed.disconnect(_on_design_layers_changed)

	design = d
	if design:
		design.layers_changed.connect(_on_design_layers_changed)

	_selected_layer_index = -1
	_rebuild_layer_list()
	_rebuild_detail_form()

func _on_design_layers_changed(_d: BayterekNodeDesign, _change: String) -> void:
	pass

# ============================================================
# LAYER LIST
# ============================================================

func _rebuild_layer_list() -> void:
	if not _layer_tree:
		return
	_layer_tree.clear()
	_layer_root = _layer_tree.create_item()

	if not design:
		_update_buttons_state()
		return

	var theme := EditorInterface.get_editor_theme()

	for i in design.layers.size():
		var layer: BayterekLayer = design.layers[i]
		if not layer:
			continue

		var item := _layer_root.create_child()
		item.set_text(0, layer.layer_name)
		item.set_metadata(0, i)
		item.set_selectable(0, true)

		var icon_name: String = "CircleShape2D" if layer is BayterekShapeLayer else "ImageTexture"
		if theme and theme.has_icon(icon_name, Bayterek.ICON_THEME):
			item.set_icon(0, theme.get_icon(icon_name, Bayterek.ICON_THEME))

		var vis_icon: String = "GuiVisibilityVisible" if layer.visible else "GuiVisibilityHidden"
		if theme and theme.has_icon(vis_icon, Bayterek.ICON_THEME):
			item.add_button(0, theme.get_icon(vis_icon, Bayterek.ICON_THEME), 0)

		if i == _selected_layer_index:
			item.select(0)

	_update_buttons_state()

func _on_layer_selected() -> void:
	var item: TreeItem = _layer_tree.get_selected()
	if not item:
		return

	var idx = item.get_metadata(0)
	if typeof(idx) != TYPE_INT:
		return

	if idx == _selected_layer_index:
		return

	_selected_layer_index = idx
	_rebuild_detail_form()
	_update_buttons_state()

func _on_layer_button_clicked(item: TreeItem, _column: int, id: int, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	if id != 0:
		return
	var idx = item.get_metadata(0)
	if typeof(idx) != TYPE_INT:
		return
	var layer: BayterekLayer = design.get_layer(idx)
	if not layer:
		return
	layer.visible = not layer.visible
	design.notify_layer_modified()
	_rebuild_layer_list()
	changed.emit()

func _on_layer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var item: TreeItem = _layer_tree.get_item_at_position(event.position)
			if item:
				item.select(0)
				_show_layer_context_menu(event.position)

# ============================================================
# CONTEXT MENU
# ============================================================

func _show_layer_context_menu(pos: Vector2) -> void:
	if not design or _selected_layer_index < 0:
		return

	var idx: int = _selected_layer_index
	var count: int = design.get_layer_count()

	var rename_i: int = _context_menu.get_item_index(CM_RENAME)
	var dup_i: int = _context_menu.get_item_index(CM_DUPLICATE)
	var del_i: int = _context_menu.get_item_index(CM_DELETE)
	var up_i: int = _context_menu.get_item_index(CM_MOVE_UP)
	var down_i: int = _context_menu.get_item_index(CM_MOVE_DOWN)

	_context_menu.set_item_disabled(rename_i, false)
	_context_menu.set_item_disabled(dup_i, false)
	_context_menu.set_item_disabled(del_i, false)
	_context_menu.set_item_disabled(up_i, idx <= 0)
	_context_menu.set_item_disabled(down_i, idx >= count - 1)

	_context_menu.position = Vector2i(_layer_tree.get_screen_position() + pos)
	_context_menu.popup()

func _on_context_menu_pressed(id: int) -> void:
	match id:
		CM_RENAME: _rename_layer_dialog()
		CM_DUPLICATE: _duplicate_selected_layer()
		CM_DELETE: _on_delete_pressed()
		CM_MOVE_UP: _on_up_pressed()
		CM_MOVE_DOWN: _on_down_pressed()

# ============================================================
# RENAME LAYER
# ============================================================

func _rename_layer_dialog() -> void:
	if not design or _selected_layer_index < 0:
		return
	var layer: BayterekLayer = design.get_layer(_selected_layer_index)
	if not layer:
		return

	var dialog := ConfirmationDialog.new()
	dialog.title = "Rename Layer"
	dialog.ok_button_text = "Rename"
	dialog.cancel_button_text = "Cancel"
	dialog.unresizable = true

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	dialog.add_child(vbox)

	var name_row := HBoxContainer.new()
	vbox.add_child(name_row)
	var lbl := Label.new()
	lbl.text = "Name:"
	lbl.custom_minimum_size = Vector2(60, 0)
	name_row.add_child(lbl)
	var name_input := LineEdit.new()
	name_input.text = layer.layer_name
	name_input.size_flags_horizontal = SIZE_EXPAND_FILL
	name_row.add_child(name_input)

	dialog.confirmed.connect(func():
		var new_name: String = name_input.text.strip_edges()
		if not new_name.is_empty():
			layer.layer_name = new_name
			design.notify_layer_modified()
			_rebuild_layer_list()
			_rebuild_detail_form()
			changed.emit()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())

	add_child(dialog)
	dialog.popup_centered(Vector2i(360, 140))
	name_input.call_deferred("grab_focus")
	name_input.call_deferred("select_all")

# ============================================================
# DUPLICATE LAYER
# ============================================================

func _duplicate_selected_layer() -> void:
	if not design or _selected_layer_index < 0:
		return
	if not design.can_add_layer():
		BayterekToast.warning(_layer_tree, "Maximum 6 layers")
		return

	var source: BayterekLayer = design.get_layer(_selected_layer_index)
	if not source:
		return

	var dup: BayterekLayer = source.duplicate_layer()
	if not dup:
		return
	dup.layer_name = "%s Copy" % source.layer_name

	var insert_at: int = _selected_layer_index + 1
	design.layers.insert(insert_at, dup)
	design.notify_layer_modified()

	_selected_layer_index = insert_at
	_rebuild_layer_list()
	_rebuild_detail_form()
	changed.emit()

# ============================================================
# ADD / DELETE / MOVE
# ============================================================

func _on_add_shape_pressed() -> void:
	if not design:
		return
	if not design.can_add_layer():
		BayterekToast.warning(_layer_tree, "Maximum 6 layers")
		return
	var layer := BayterekShapeLayer.new()
	layer.layer_name = "Shape %d" % (design.get_layer_count() + 1)
	layer.transform.size = design.design_size
	design.add_layer(layer)
	_selected_layer_index = design.get_layer_count() - 1
	_rebuild_layer_list()
	_rebuild_detail_form()
	changed.emit()

func _on_add_texture_pressed() -> void:
	if not design:
		return
	if not design.can_add_layer():
		BayterekToast.warning(_layer_tree, "Maximum 6 layers")
		return
	var layer := BayterekTextureLayer.new()
	layer.layer_name = "Texture %d" % (design.get_layer_count() + 1)
	layer.transform.size = design.design_size
	design.add_layer(layer)
	_selected_layer_index = design.get_layer_count() - 1
	_rebuild_layer_list()
	_rebuild_detail_form()
	changed.emit()

func _on_delete_pressed() -> void:
	if not design or _selected_layer_index < 0:
		return

	var removed_idx: int = _selected_layer_index
	design.remove_layer(removed_idx)

	# Prefer the previous layer; fall back to first remaining layer.
	var new_idx: int = -1
	var count: int = design.get_layer_count()
	if count > 0:
		new_idx = max(0, removed_idx - 1)

	_selected_layer_index = new_idx
	_rebuild_layer_list()
	_rebuild_detail_form()
	changed.emit()

func _on_up_pressed() -> void:
	if not design or _selected_layer_index <= 0:
		return
	if design.move_layer(_selected_layer_index, _selected_layer_index - 1):
		_selected_layer_index -= 1
		_rebuild_layer_list()
		changed.emit()

func _on_down_pressed() -> void:
	if not design:
		return
	var max_idx: int = design.get_layer_count() - 1
	if _selected_layer_index < 0 or _selected_layer_index >= max_idx:
		return
	if design.move_layer(_selected_layer_index, _selected_layer_index + 1):
		_selected_layer_index += 1
		_rebuild_layer_list()
		changed.emit()

func _update_buttons_state() -> void:
	var has_selection: bool = _selected_layer_index >= 0 and design != null
	var can_up: bool = has_selection and _selected_layer_index > 0
	var can_down: bool = has_selection and design and _selected_layer_index < design.get_layer_count() - 1
	var can_add: bool = design != null and design.can_add_layer()

	if _delete_btn: _delete_btn.disabled = not has_selection
	if _up_btn: _up_btn.disabled = not can_up
	if _down_btn: _down_btn.disabled = not can_down
	if _add_shape_btn: _add_shape_btn.disabled = not can_add
	if _add_texture_btn: _add_texture_btn.disabled = not can_add

# ============================================================
# DETAIL FORM
# ============================================================

func _rebuild_detail_form() -> void:
	for child in _detail_root.get_children():
		child.queue_free()

	if not design:
		return
	if _selected_layer_index < 0 or _selected_layer_index >= design.get_layer_count():
		var empty := Label.new()
		empty.text = "Select a layer to edit"
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_detail_root.add_child(empty)
		return

	var layer: BayterekLayer = design.get_layer(_selected_layer_index)
	if not layer:
		return

	# --- Name row ---
	var name_row := HBoxContainer.new()
	_detail_root.add_child(name_row)

	var name_label := Label.new()
	name_label.text = "Name"
	name_label.custom_minimum_size = Vector2(80, 0)
	name_row.add_child(name_label)

	var name_input := LineEdit.new()
	name_input.size_flags_horizontal = SIZE_EXPAND_FILL
	name_input.text = layer.layer_name
	name_input.text_changed.connect(func(t: String):
		layer.layer_name = t
		design.notify_layer_modified()
		_rebuild_layer_list()
		changed.emit()
	)
	name_row.add_child(name_input)

	# --- Transform fold ---
	var transform_fold := _make_fold("Transform")
	_detail_root.add_child(transform_fold)

	var transform_inner := VBoxContainer.new()
	transform_inner.add_theme_constant_override("separation", 6)
	transform_fold.add_child(transform_inner)

	var transform_form := BayterekLayerTransformForm.new()
	transform_form.set_transform(layer.transform)
	transform_form.changed.connect(func():
		design.notify_layer_modified()
		changed.emit()
	)
	transform_inner.add_child(transform_form)

	# --- Type-specific folds ---
	if layer is BayterekShapeLayer:
		_build_shape_detail(layer)
	elif layer is BayterekTextureLayer:
		_build_texture_detail(layer)

func _build_shape_detail(layer: BayterekShapeLayer) -> void:
	# --- Shape fold ---
	var shape_fold := _make_fold("Shape")
	_detail_root.add_child(shape_fold)

	var shape_inner := VBoxContainer.new()
	shape_inner.add_theme_constant_override("separation", 4)
	shape_fold.add_child(shape_inner)

	var type_row := HBoxContainer.new()
	shape_inner.add_child(type_row)

	var type_label := Label.new()
	type_label.text = "Type"
	type_label.custom_minimum_size = Vector2(80, 0)
	type_row.add_child(type_label)

	var type_dropdown := OptionButton.new()
	type_dropdown.size_flags_horizontal = SIZE_EXPAND_FILL
	type_dropdown.add_item("Circle", BayterekShapeLayer.ShapeType.CIRCLE)
	type_dropdown.add_item("Square", BayterekShapeLayer.ShapeType.SQUARE)
	type_dropdown.add_item("Triangle", BayterekShapeLayer.ShapeType.TRIANGLE)
	type_dropdown.add_item("Pentagon", BayterekShapeLayer.ShapeType.PENTAGON)
	type_dropdown.add_item("Hexagon", BayterekShapeLayer.ShapeType.HEXAGON)
	type_dropdown.select(int(layer.shape_type))
	type_dropdown.item_selected.connect(func(i: int):
		layer.shape_type = i as BayterekShapeLayer.ShapeType
		design.notify_layer_modified()
		changed.emit()
	)
	type_row.add_child(type_dropdown)

	# --- Fill fold ---
	var fill_fold := _make_fold("Fill")
	_detail_root.add_child(fill_fold)

	var fill_inner := VBoxContainer.new()
	fill_inner.add_theme_constant_override("separation", 4)
	fill_fold.add_child(fill_inner)

	var fill_check := CheckBox.new()
	fill_check.text = "Enabled"
	fill_check.button_pressed = layer.fill_enabled
	fill_check.toggled.connect(func(p: bool):
		layer.fill_enabled = p
		design.notify_layer_modified()
		changed.emit()
	)
	fill_inner.add_child(fill_check)

	var fill_colors := BayterekLayerStateColors.new()
	fill_colors.bind(layer, "fill_configs")
	fill_colors.changed.connect(func():
		design.notify_layer_modified()
		changed.emit()
	)
	fill_inner.add_child(fill_colors)

	# --- Border fold ---
	var border_fold := _make_fold("Border")
	_detail_root.add_child(border_fold)

	var border_inner := VBoxContainer.new()
	border_inner.add_theme_constant_override("separation", 4)
	border_fold.add_child(border_inner)

	var border_check := CheckBox.new()
	border_check.text = "Enabled"
	border_check.button_pressed = layer.border_enabled
	border_check.toggled.connect(func(p: bool):
		layer.border_enabled = p
		design.notify_layer_modified()
		changed.emit()
	)
	border_inner.add_child(border_check)

	var bw_row := HBoxContainer.new()
	border_inner.add_child(bw_row)
	var bw_label := Label.new()
	bw_label.text = "Width"
	bw_label.custom_minimum_size = Vector2(80, 0)
	bw_row.add_child(bw_label)
	var bw_input := SpinBox.new()
	bw_input.size_flags_horizontal = SIZE_EXPAND_FILL
	bw_input.min_value = 0.0
	bw_input.max_value = 100.0
	bw_input.step = 0.5
	bw_input.value = layer.border_width
	bw_input.value_changed.connect(func(v: float):
		layer.border_width = v
		design.notify_layer_modified()
		changed.emit()
	)
	bw_row.add_child(bw_input)

	var border_colors := BayterekLayerStateColors.new()
	border_colors.bind(layer, "border_configs")
	border_colors.changed.connect(func():
		design.notify_layer_modified()
		changed.emit()
	)
	border_inner.add_child(border_colors)

	# --- Shadow fold ---
	var shadow_fold := _make_fold("Shadow")
	_detail_root.add_child(shadow_fold)

	var shadow_inner := VBoxContainer.new()
	shadow_inner.add_theme_constant_override("separation", 4)
	shadow_fold.add_child(shadow_inner)

	var shadow_check := CheckBox.new()
	shadow_check.text = "Enabled"
	shadow_check.button_pressed = layer.shadow_enabled
	shadow_check.toggled.connect(func(p: bool):
		layer.shadow_enabled = p
		design.notify_layer_modified()
		changed.emit()
	)
	shadow_inner.add_child(shadow_check)

	var shadow_color_row := HBoxContainer.new()
	shadow_inner.add_child(shadow_color_row)
	var sc_label := Label.new()
	sc_label.text = "Color"
	sc_label.custom_minimum_size = Vector2(80, 0)
	shadow_color_row.add_child(sc_label)
	var sc_picker := ColorPickerButton.new()
	sc_picker.size_flags_horizontal = SIZE_EXPAND_FILL
	sc_picker.color = layer.shadow_color
	sc_picker.color_changed.connect(func(c: Color):
		layer.shadow_color = c
		design.notify_layer_modified()
		changed.emit()
	)
	shadow_color_row.add_child(sc_picker)

	var shadow_offset_row := HBoxContainer.new()
	shadow_inner.add_child(shadow_offset_row)
	var so_label := Label.new()
	so_label.text = "Offset"
	so_label.custom_minimum_size = Vector2(80, 0)
	shadow_offset_row.add_child(so_label)

	var so_x := SpinBox.new()
	so_x.size_flags_horizontal = SIZE_EXPAND_FILL
	so_x.min_value = -100
	so_x.max_value = 100
	so_x.step = 1
	so_x.value = layer.shadow_size.x
	so_x.value_changed.connect(func(v: float):
		layer.shadow_size.x = v
		design.notify_layer_modified()
		changed.emit()
	)
	shadow_offset_row.add_child(so_x)

	var so_y := SpinBox.new()
	so_y.size_flags_horizontal = SIZE_EXPAND_FILL
	so_y.min_value = -100
	so_y.max_value = 100
	so_y.step = 1
	so_y.value = layer.shadow_size.y
	so_y.value_changed.connect(func(v: float):
		layer.shadow_size.y = v
		design.notify_layer_modified()
		changed.emit()
	)
	shadow_offset_row.add_child(so_y)

	var shadow_blur_row := HBoxContainer.new()
	shadow_inner.add_child(shadow_blur_row)
	var sb_label := Label.new()
	sb_label.text = "Blur"
	sb_label.custom_minimum_size = Vector2(80, 0)
	sb_label.tooltip_text = "Soft shadow spread (0 = hard edge)"
	shadow_blur_row.add_child(sb_label)

	var sb_input := SpinBox.new()
	sb_input.size_flags_horizontal = SIZE_EXPAND_FILL
	sb_input.min_value = 0.0
	sb_input.max_value = 50.0
	sb_input.step = 0.5
	sb_input.value = layer.shadow_blur
	sb_input.value_changed.connect(func(v: float):
		layer.shadow_blur = v
		design.notify_layer_modified()
		changed.emit()
	)
	shadow_blur_row.add_child(sb_input)

func _build_texture_detail(layer: BayterekTextureLayer) -> void:
	# --- Icon fold ---
	var icon_fold := _make_fold("Icon")
	_detail_root.add_child(icon_fold)

	var icon_inner := VBoxContainer.new()
	icon_inner.add_theme_constant_override("separation", 4)
	icon_fold.add_child(icon_inner)

	var icon_check := CheckBox.new()
	icon_check.text = "Enabled"
	icon_check.button_pressed = layer.icon_enabled
	icon_check.toggled.connect(func(p: bool):
		layer.icon_enabled = p
		design.notify_layer_modified()
		changed.emit()
	)
	icon_inner.add_child(icon_check)

	var icon_editor := BayterekLayerStateTextures.new()
	icon_editor.bind(layer)
	icon_editor.changed.connect(func():
		design.notify_layer_modified()
		changed.emit()
	)
	icon_inner.add_child(icon_editor)

	# --- Tint fold ---
	var tint_fold := _make_fold("Tint")
	_detail_root.add_child(tint_fold)

	var tint_inner := VBoxContainer.new()
	tint_inner.add_theme_constant_override("separation", 4)
	tint_fold.add_child(tint_inner)

	var tint_check := CheckBox.new()
	tint_check.text = "Enabled"
	tint_check.button_pressed = layer.tint_enabled
	tint_check.toggled.connect(func(p: bool):
		layer.tint_enabled = p
		design.notify_layer_modified()
		changed.emit()
	)
	tint_inner.add_child(tint_check)

	var tint_editor := BayterekLayerStateColors.new()
	tint_editor.bind(layer, "tint_configs")
	tint_editor.changed.connect(func():
		design.notify_layer_modified()
		changed.emit()
	)
	tint_inner.add_child(tint_editor)

# ============================================================
# HELPERS
# ============================================================

func _make_fold(title: String) -> FoldableContainer:
	var fold := FoldableContainer.new()
	fold.title = title
	fold.folded = false
	return fold