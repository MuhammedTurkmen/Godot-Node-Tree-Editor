@tool
class_name BayterekLayerEditor
extends VBoxContainer
## Middle-column layer editor.

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

# Button IDs on each layer row
const BTN_VISIBILITY := 0
const BTN_MOVE_UP := 1
const BTN_MOVE_DOWN := 2
const BTN_DELETE := 3

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
	_up_btn.tooltip_text = "Move selected layer up"
	_up_btn.custom_minimum_size = Vector2(28, 0)
	_up_btn.pressed.connect(_on_up_pressed)
	toolbar.add_child(_up_btn)

	_down_btn = Button.new()
	_down_btn.text = "▼"
	_down_btn.tooltip_text = "Move selected layer down"
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
	_layer_tree.custom_minimum_size = Vector2(0, 220)
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

		# 1) Visibility (eye)
		var vis_icon: String = "GuiVisibilityVisible" if layer.visible else "GuiVisibilityHidden"
		if theme and theme.has_icon(vis_icon, Bayterek.ICON_THEME):
			item.add_button(0, theme.get_icon(vis_icon, Bayterek.ICON_THEME), BTN_VISIBILITY)
			item.set_button_tooltip_text(0, item.get_button_count(0) - 1, "Toggle visibility")

		# 2) Move up
		var up_icon_name: String = "ArrowUp" if theme and theme.has_icon("ArrowUp", Bayterek.ICON_THEME) else ""
		if up_icon_name.is_empty():
			item.add_button(0, _make_text_icon("▲"), BTN_MOVE_UP)
		else:
			item.add_button(0, theme.get_icon(up_icon_name, Bayterek.ICON_THEME), BTN_MOVE_UP)
		item.set_button_tooltip_text(0, item.get_button_count(0) - 1, "Move up")
		item.set_button_disabled(0, item.get_button_count(0) - 1, i == 0)

		# 3) Move down
		var down_icon_name: String = "ArrowDown" if theme and theme.has_icon("ArrowDown", Bayterek.ICON_THEME) else ""
		if down_icon_name.is_empty():
			item.add_button(0, _make_text_icon("▼"), BTN_MOVE_DOWN)
		else:
			item.add_button(0, theme.get_icon(down_icon_name, Bayterek.ICON_THEME), BTN_MOVE_DOWN)
		item.set_button_tooltip_text(0, item.get_button_count(0) - 1, "Move down")
		item.set_button_disabled(0, item.get_button_count(0) - 1, i == design.layers.size() - 1)

		# 4) Delete
		if theme and theme.has_icon("Close", Bayterek.ICON_THEME):
			item.add_button(0, theme.get_icon("Close", Bayterek.ICON_THEME), BTN_DELETE)
			item.set_button_tooltip_text(0, item.get_button_count(0) - 1, "Delete layer")

		if i == _selected_layer_index:
			item.select(0)

	_update_buttons_state()

func _make_text_icon(_text: String) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var tex := ImageTexture.create_from_image(img)
	return tex

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

	var idx = item.get_metadata(0)
	if typeof(idx) != TYPE_INT:
		return

	if idx != _selected_layer_index:
		item.select(0)

	match id:
		BTN_VISIBILITY:
			_toggle_layer_visibility(idx)
		BTN_MOVE_UP:
			_move_layer_by_index(idx, -1)
		BTN_MOVE_DOWN:
			_move_layer_by_index(idx, +1)
		BTN_DELETE:
			_delete_layer_by_index(idx)

func _toggle_layer_visibility(idx: int) -> void:
	if not design:
		return
	var layer: BayterekLayer = design.get_layer(idx)
	if not layer:
		return
	layer.visible = not layer.visible
	design.notify_layer_modified()
	_rebuild_layer_list()
	changed.emit()

func _move_layer_by_index(idx: int, direction: int) -> void:
	if not design:
		return
	if direction < 0 and idx <= 0:
		return
	if direction > 0 and idx >= design.get_layer_count() - 1:
		return

	var target: int = idx + direction
	if not design.move_layer(idx, target):
		return

	_selected_layer_index = target
	design.notify_layer_modified()
	_rebuild_layer_list()
	_rebuild_detail_form()
	changed.emit()

func _delete_layer_by_index(idx: int) -> void:
	if not design:
		return
	if idx < 0 or idx >= design.get_layer_count():
		return

	design.remove_layer(idx)

	var new_idx: int = -1
	var count: int = design.get_layer_count()
	if count > 0:
		new_idx = max(0, idx - 1)

	_selected_layer_index = new_idx
	_rebuild_layer_list()
	_rebuild_detail_form()
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
# ADD / DELETE / MOVE (toolbar handlers)
# ============================================================

func _on_add_shape_pressed() -> void:
	if not design:
		return
	if not design.can_add_layer():
		BayterekToast.warning(_layer_tree, "Maximum 6 layers")
		return
	var layer := BayterekShapeLayer.new()
	layer.layer_name = "Shape %d" % (design.get_layer_count() + 1)
	layer.transform.size = design.get_computed_size()
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
	layer.transform.size = design.get_computed_size()
	design.add_layer(layer)
	_selected_layer_index = design.get_layer_count() - 1
	_rebuild_layer_list()
	_rebuild_detail_form()
	changed.emit()

func _on_delete_pressed() -> void:
	if not design or _selected_layer_index < 0:
		return
	_delete_layer_by_index(_selected_layer_index)

func _on_up_pressed() -> void:
	if not design or _selected_layer_index <= 0:
		return
	_move_layer_by_index(_selected_layer_index, -1)

func _on_down_pressed() -> void:
	if not design:
		return
	var max_idx: int = design.get_layer_count() - 1
	if _selected_layer_index < 0 or _selected_layer_index >= max_idx:
		return
	_move_layer_by_index(_selected_layer_index, +1)

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
		_detail_root.remove_child(child)
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

	# --- Visibility checkbox in detail panel ---
	var vis_row := HBoxContainer.new()
	_detail_root.add_child(vis_row)

	var vis_label := Label.new()
	vis_label.text = "Visible"
	vis_label.custom_minimum_size = Vector2(80, 0)
	vis_label.tooltip_text = "Toggle this layer's visibility. Same as the eye button on the layer list."
	vis_label.mouse_filter = Control.MOUSE_FILTER_PASS
	vis_row.add_child(vis_label)

	var vis_check := CheckBox.new()
	vis_check.text = "On"
	vis_check.button_pressed = layer.visible
	vis_check.toggled.connect(func(p: bool):
		layer.visible = p
		design.notify_layer_modified()
		_rebuild_layer_list()
		changed.emit()
	)
	vis_row.add_child(vis_check)

	# --- Render Mode override ---
	var rmode_row := HBoxContainer.new()
	rmode_row.add_theme_constant_override("separation", 4)
	_detail_root.add_child(rmode_row)

	var rmode_label := Label.new()
	rmode_label.text = "Render Mode"
	rmode_label.custom_minimum_size = Vector2(80, 0)
	rmode_label.tooltip_text = "Inherit uses the design's mode. Override per layer."
	rmode_label.mouse_filter = Control.MOUSE_FILTER_PASS
	rmode_row.add_child(rmode_label)

	var rmode_dropdown := OptionButton.new()
	rmode_dropdown.size_flags_horizontal = SIZE_EXPAND_FILL
	rmode_dropdown.tooltip_text = rmode_label.tooltip_text
	rmode_dropdown.add_item("Inherit", BayterekLayer.RenderModeOverride.INHERIT)
	rmode_dropdown.add_item("Vector", BayterekLayer.RenderModeOverride.VECTOR)
	rmode_dropdown.add_item("Pixel", BayterekLayer.RenderModeOverride.PIXEL)
	var rmode_idx: int = rmode_dropdown.get_item_index(int(layer.render_mode_override))
	if rmode_idx >= 0:
		rmode_dropdown.select(rmode_idx)
	rmode_dropdown.item_selected.connect(func(idx: int):
		var new_mode_int = rmode_dropdown.get_item_id(idx)
		if typeof(new_mode_int) != TYPE_INT:
			return
		layer.render_mode_override = new_mode_int as BayterekLayer.RenderModeOverride
		design.notify_layer_modified()
		changed.emit()
	)
	rmode_row.add_child(rmode_dropdown)

	var field_rmode: String = "layers.%s.render_mode_override" % layer.layer_id
	BayterekExportHelper.make_exportable(rmode_row, field_rmode, design, _on_export_changed)

	# --- Texture Filter override ---
	var tfilter_row := HBoxContainer.new()
	tfilter_row.add_theme_constant_override("separation", 4)
	_detail_root.add_child(tfilter_row)

	var tfilter_label := Label.new()
	tfilter_label.text = "Texture Filter"
	tfilter_label.custom_minimum_size = Vector2(80, 0)
	tfilter_label.tooltip_text = "Inherit uses the design's filter. Override per layer for pixel-perfect textures."
	tfilter_label.mouse_filter = Control.MOUSE_FILTER_PASS
	tfilter_row.add_child(tfilter_label)

	var tfilter_dropdown := OptionButton.new()
	tfilter_dropdown.size_flags_horizontal = SIZE_EXPAND_FILL
	tfilter_dropdown.tooltip_text = tfilter_label.tooltip_text
	tfilter_dropdown.add_item("Inherit", BayterekLayer.TextureFilterOverride.INHERIT)
	tfilter_dropdown.add_item("Linear (smooth)", BayterekLayer.TextureFilterOverride.LINEAR)
	tfilter_dropdown.add_item("Nearest (pixel art)", BayterekLayer.TextureFilterOverride.NEAREST)
	var tf_idx: int = tfilter_dropdown.get_item_index(int(layer.texture_filter_override))
	if tf_idx >= 0:
		tfilter_dropdown.select(tf_idx)
	tfilter_dropdown.item_selected.connect(func(idx: int):
		var new_filter_int = tfilter_dropdown.get_item_id(idx)
		if typeof(new_filter_int) != TYPE_INT:
			return
		layer.texture_filter_override = new_filter_int as BayterekLayer.TextureFilterOverride
		design.notify_layer_modified()
		changed.emit()
	)
	tfilter_row.add_child(tfilter_dropdown)

	var field_tfilter: String = "layers.%s.texture_filter_override" % layer.layer_id
	BayterekExportHelper.make_exportable(tfilter_row, field_tfilter, design, _on_export_changed)

	var transform_fold := _make_fold("Transform")
	_detail_root.add_child(transform_fold)

	var transform_inner := VBoxContainer.new()
	transform_inner.add_theme_constant_override("separation", 6)
	transform_fold.add_child(transform_inner)

	var transform_form := BayterekLayerTransformForm.new()
	transform_inner.add_child(transform_form)
	transform_form.set_transform(layer.transform, design, layer.layer_id)
	transform_form.changed.connect(func():
		design.notify_layer_modified()
		changed.emit()
	)

	if layer is BayterekShapeLayer:
		_build_shape_detail(layer)
	elif layer is BayterekTextureLayer:
		_build_texture_detail(layer)

func _build_shape_detail(layer: BayterekShapeLayer) -> void:
	var shape_fold := _make_fold("Shape")
	_detail_root.add_child(shape_fold)

	var shape_inner := VBoxContainer.new()
	shape_inner.add_theme_constant_override("separation", 4)
	shape_fold.add_child(shape_inner)

	var type_row := HBoxContainer.new()
	type_row.add_theme_constant_override("separation", 4)
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
		_rebuild_detail_form_deferred()
		changed.emit()
	)
	type_row.add_child(type_dropdown)

	var field_st: String = "layers.%s.shape_type" % layer.layer_id
	BayterekExportHelper.make_exportable(type_row, field_st, design, _on_export_changed)

	var cr_row := HBoxContainer.new()
	cr_row.add_theme_constant_override("separation", 4)
	shape_inner.add_child(cr_row)

	var cr_label := Label.new()
	cr_label.text = "Corner R"
	cr_label.custom_minimum_size = Vector2(80, 0)
	cr_row.add_child(cr_label)

	var cr_input := SpinBox.new()
	cr_input.size_flags_horizontal = SIZE_EXPAND_FILL
	cr_input.min_value = 0.0
	cr_input.max_value = 9999.0
	cr_input.step = 0.5
	cr_input.value = layer.corner_radius
	cr_input.value_changed.connect(func(v: float):
		layer.corner_radius = v
		design.notify_layer_modified()
		changed.emit()
		_sync_corner_radius_ui(layer, cr_input, cr_label)
	)
	cr_row.add_child(cr_input)

	_update_corner_radius_tooltip(layer, cr_label, cr_input)
	_sync_corner_radius_ui(layer, cr_input, cr_label)

	var field_cr: String = "layers.%s.corner_radius" % layer.layer_id
	BayterekExportHelper.make_exportable(cr_row, field_cr, design, _on_export_changed)

	var fill_fold := _make_fold("Fill")
	_detail_root.add_child(fill_fold)

	var fill_inner := VBoxContainer.new()
	fill_inner.add_theme_constant_override("separation", 4)
	fill_fold.add_child(fill_inner)

	var fill_check_row := HBoxContainer.new()
	fill_check_row.add_theme_constant_override("separation", 4)
	fill_inner.add_child(fill_check_row)

	var fill_check := CheckBox.new()
	fill_check.text = "Enabled"
	fill_check.size_flags_horizontal = SIZE_EXPAND_FILL
	fill_check.button_pressed = layer.fill_enabled
	fill_check.toggled.connect(func(p: bool):
		layer.fill_enabled = p
		design.notify_layer_modified()
		changed.emit()
	)
	fill_check_row.add_child(fill_check)

	var field_fe: String = "layers.%s.fill_enabled" % layer.layer_id
	BayterekExportHelper.make_exportable(fill_check_row, field_fe, design, _on_export_changed)

	var fill_colors := BayterekLayerStateColors.new()
	fill_inner.add_child(fill_colors)
	fill_colors.bind(layer, "fill_configs")
	fill_colors.bind_export(design, layer.layer_id, "fill_configs", _on_export_changed)
	fill_colors.changed.connect(func():
		design.notify_layer_modified()
		changed.emit()
	)

	var border_fold := _make_fold("Border")
	_detail_root.add_child(border_fold)

	var border_inner := VBoxContainer.new()
	border_inner.add_theme_constant_override("separation", 4)
	border_fold.add_child(border_inner)

	var border_check_row := HBoxContainer.new()
	border_check_row.add_theme_constant_override("separation", 4)
	border_inner.add_child(border_check_row)

	var border_check := CheckBox.new()
	border_check.text = "Enabled"
	border_check.size_flags_horizontal = SIZE_EXPAND_FILL
	border_check.button_pressed = layer.border_enabled
	border_check.toggled.connect(func(p: bool):
		layer.border_enabled = p
		design.notify_layer_modified()
		changed.emit()
	)
	border_check_row.add_child(border_check)

	var field_be: String = "layers.%s.border_enabled" % layer.layer_id
	BayterekExportHelper.make_exportable(border_check_row, field_be, design, _on_export_changed)

	var bw_row := HBoxContainer.new()
	bw_row.add_theme_constant_override("separation", 4)
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

	var field_bw: String = "layers.%s.border_width" % layer.layer_id
	BayterekExportHelper.make_exportable(bw_row, field_bw, design, _on_export_changed)

	var gap_row := HBoxContainer.new()
	gap_row.add_theme_constant_override("separation", 4)
	border_inner.add_child(gap_row)

	var gap_label := Label.new()
	gap_label.text = "Corner Gap"
	gap_label.custom_minimum_size = Vector2(80, 0)
	gap_label.tooltip_text = "Skip corner segments — only straight edges are drawn. Useful for pixel art frames."
	gap_row.add_child(gap_label)

	var gap_check := CheckBox.new()
	gap_check.text = "On"
	gap_check.size_flags_horizontal = SIZE_EXPAND_FILL
	gap_check.button_pressed = layer.border_corner_gap
	gap_check.toggled.connect(func(p: bool):
		layer.border_corner_gap = p
		design.notify_layer_modified()
		changed.emit()
	)
	gap_row.add_child(gap_check)

	var field_gap: String = "layers.%s.border_corner_gap" % layer.layer_id
	BayterekExportHelper.make_exportable(gap_row, field_gap, design, _on_export_changed)

	var edges_label := Label.new()
	edges_label.text = "Edges"
	edges_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	border_inner.add_child(edges_label)

	if layer.shape_type == BayterekShapeLayer.ShapeType.CIRCLE:
		var note := Label.new()
		note.text = "  (Circle always draws a full ring)"
		note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		note.add_theme_font_size_override("font_size", 11)
		border_inner.add_child(note)

	_build_edge_checkbox(border_inner, layer, "Top", "border_top_enabled")
	_build_edge_checkbox(border_inner, layer, "Right", "border_right_enabled")
	_build_edge_checkbox(border_inner, layer, "Bottom", "border_bottom_enabled")
	_build_edge_checkbox(border_inner, layer, "Left", "border_left_enabled")

	var border_colors := BayterekLayerStateColors.new()
	border_inner.add_child(border_colors)
	border_colors.bind(layer, "border_configs")
	border_colors.bind_export(design, layer.layer_id, "border_configs", _on_export_changed)
	border_colors.changed.connect(func():
		design.notify_layer_modified()
		changed.emit()
	)

	var shadow_fold := _make_fold("Shadow")
	_detail_root.add_child(shadow_fold)

	var shadow_inner := VBoxContainer.new()
	shadow_inner.add_theme_constant_override("separation", 4)
	shadow_fold.add_child(shadow_inner)

	var shadow_check_row := HBoxContainer.new()
	shadow_check_row.add_theme_constant_override("separation", 4)
	shadow_inner.add_child(shadow_check_row)

	var shadow_check := CheckBox.new()
	shadow_check.text = "Enabled"
	shadow_check.size_flags_horizontal = SIZE_EXPAND_FILL
	shadow_check.button_pressed = layer.shadow_enabled
	shadow_check.toggled.connect(func(p: bool):
		layer.shadow_enabled = p
		design.notify_layer_modified()
		changed.emit()
	)
	shadow_check_row.add_child(shadow_check)

	var field_se: String = "layers.%s.shadow_enabled" % layer.layer_id
	BayterekExportHelper.make_exportable(shadow_check_row, field_se, design, _on_export_changed)

	var shadow_color_row := HBoxContainer.new()
	shadow_color_row.add_theme_constant_override("separation", 4)
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

	var field_sc: String = "layers.%s.shadow_color" % layer.layer_id
	BayterekExportHelper.make_exportable(shadow_color_row, field_sc, design, _on_export_changed)

	var shadow_offset_row := HBoxContainer.new()
	shadow_offset_row.add_theme_constant_override("separation", 4)
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

	var field_ss: String = "layers.%s.shadow_size" % layer.layer_id
	BayterekExportHelper.make_exportable(shadow_offset_row, field_ss, design, _on_export_changed)

	var shadow_blur_row := HBoxContainer.new()
	shadow_blur_row.add_theme_constant_override("separation", 4)
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

	var field_sb: String = "layers.%s.shadow_blur" % layer.layer_id
	BayterekExportHelper.make_exportable(shadow_blur_row, field_sb, design, _on_export_changed)

func _build_edge_checkbox(parent: Control, layer: BayterekShapeLayer, label_text: String, prop_name: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(20, 0)
	row.add_child(spacer)

	var check := CheckBox.new()
	check.text = label_text
	check.size_flags_horizontal = SIZE_EXPAND_FILL
	check.button_pressed = layer.get(prop_name)

	if layer.shape_type == BayterekShapeLayer.ShapeType.CIRCLE:
		check.disabled = true

	check.toggled.connect(func(p: bool):
		layer.set(prop_name, p)
		design.notify_layer_modified()
		changed.emit()
	)
	row.add_child(check)

	var field_path: String = "layers.%s.%s" % [layer.layer_id, prop_name]
	BayterekExportHelper.make_exportable(row, field_path, design, _on_export_changed)

func _update_corner_radius_tooltip(
	layer: BayterekShapeLayer,
	label: Label,
	input: SpinBox
) -> void:
	var effective_size: Vector2 = design.get_computed_size() if design else Vector2(100, 100)
	var limit: float = layer._corner_radius_limit(effective_size)
	var effective: float = layer.get_clamped_corner_radius(effective_size)

	var text: String = (
		"Corner rounding radius in pixels.\n" +
		"Auto-clamped to min(w,h)/2 * 0.99 = %.2f for this shape.\n" % limit +
		"Effective value: %.2f" % effective
	)

	if label:
		label.tooltip_text = text
	if input:
		input.tooltip_text = text

func _sync_corner_radius_ui(
	layer: BayterekShapeLayer,
	input: SpinBox,
	label: Label
) -> void:
	if not layer or not input:
		return

	var effective_size: Vector2 = design.get_computed_size() if design else Vector2(100, 100)
	var effective: float = layer.get_clamped_corner_radius(effective_size)

	if not is_equal_approx(input.value, effective):
		input.set_value_no_signal(effective)

	_update_corner_radius_tooltip(layer, label, input)

func _build_texture_detail(layer: BayterekTextureLayer) -> void:
	var icon_fold := _make_fold("Icon")
	_detail_root.add_child(icon_fold)

	var icon_inner := VBoxContainer.new()
	icon_inner.add_theme_constant_override("separation", 4)
	icon_fold.add_child(icon_inner)

	var icon_check_row := HBoxContainer.new()
	icon_check_row.add_theme_constant_override("separation", 4)
	icon_inner.add_child(icon_check_row)

	var icon_check := CheckBox.new()
	icon_check.text = "Enabled"
	icon_check.size_flags_horizontal = SIZE_EXPAND_FILL
	icon_check.button_pressed = layer.icon_enabled
	icon_check.toggled.connect(func(p: bool):
		layer.icon_enabled = p
		design.notify_layer_modified()
		changed.emit()
	)
	icon_check_row.add_child(icon_check)

	var field_ie: String = "layers.%s.icon_enabled" % layer.layer_id
	BayterekExportHelper.make_exportable(icon_check_row, field_ie, design, _on_export_changed)

	var icon_editor := BayterekLayerStateTextures.new()
	icon_inner.add_child(icon_editor)
	icon_editor.bind(layer)
	icon_editor.bind_export(design, layer.layer_id, _on_export_changed)
	icon_editor.changed.connect(func():
		design.notify_layer_modified()
		changed.emit()
	)

	var stretch_fold := _make_fold("Stretch Mode")
	_detail_root.add_child(stretch_fold)

	var stretch_inner := VBoxContainer.new()
	stretch_inner.add_theme_constant_override("separation", 4)
	stretch_fold.add_child(stretch_inner)

	var sm_row := HBoxContainer.new()
	sm_row.add_theme_constant_override("separation", 4)
	stretch_inner.add_child(sm_row)

	var sm_label := Label.new()
	sm_label.text = "Mode"
	sm_label.custom_minimum_size = Vector2(80, 0)
	sm_row.add_child(sm_label)

	var sm_dropdown := OptionButton.new()
	sm_dropdown.size_flags_horizontal = SIZE_EXPAND_FILL
	sm_dropdown.add_item("Stretch", BayterekTextureLayer.StretchMode.STRETCH)
	sm_dropdown.add_item("Keep Aspect", BayterekTextureLayer.StretchMode.KEEP_ASPECT)
	sm_dropdown.add_item("Tile", BayterekTextureLayer.StretchMode.TILE)
	sm_dropdown.add_item("Nine Patch", BayterekTextureLayer.StretchMode.NINE_PATCH)
	var sm_idx: int = sm_dropdown.get_item_index(int(layer.stretch_mode))
	if sm_idx >= 0:
		sm_dropdown.select(sm_idx)
	sm_dropdown.item_selected.connect(func(idx: int):
		var mode_int = sm_dropdown.get_item_id(idx)
		if typeof(mode_int) != TYPE_INT:
			return
		layer.stretch_mode = mode_int as BayterekTextureLayer.StretchMode
		design.notify_layer_modified()
		_rebuild_detail_form_deferred()
		changed.emit()
	)
	sm_row.add_child(sm_dropdown)

	var field_sm: String = "layers.%s.stretch_mode" % layer.layer_id
	BayterekExportHelper.make_exportable(sm_row, field_sm, design, _on_export_changed)

	if layer.stretch_mode == BayterekTextureLayer.StretchMode.NINE_PATCH:
		var np_label := Label.new()
		np_label.text = "Nine Patch Margins (px)"
		np_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		stretch_inner.add_child(np_label)

		var lt_row := HBoxContainer.new()
		lt_row.add_theme_constant_override("separation", 4)
		stretch_inner.add_child(lt_row)

		_add_nine_patch_spin(lt_row, layer, "Left", "nine_patch_margin_left")
		_add_nine_patch_spin(lt_row, layer, "Top", "nine_patch_margin_top")

		var rb_row := HBoxContainer.new()
		rb_row.add_theme_constant_override("separation", 4)
		stretch_inner.add_child(rb_row)

		_add_nine_patch_spin(rb_row, layer, "Right", "nine_patch_margin_right")
		_add_nine_patch_spin(rb_row, layer, "Bottom", "nine_patch_margin_bottom")

		var center_row := HBoxContainer.new()
		center_row.add_theme_constant_override("separation", 4)
		stretch_inner.add_child(center_row)

		var center_label := Label.new()
		center_label.text = "Draw Center"
		center_label.size_flags_horizontal = SIZE_EXPAND_FILL
		center_label.tooltip_text = "If off, the middle region is left transparent (useful for frames/panels)."
		center_label.mouse_filter = Control.MOUSE_FILTER_PASS
		center_row.add_child(center_label)

		var center_check := CheckBox.new()
		center_check.text = "On"
		center_check.button_pressed = layer.nine_patch_draw_center
		center_check.toggled.connect(func(p: bool):
			layer.nine_patch_draw_center = p
			design.notify_layer_modified()
			changed.emit()
		)
		center_row.add_child(center_check)

		var field_dc: String = "layers.%s.nine_patch_draw_center" % layer.layer_id
		BayterekExportHelper.make_exportable(center_row, field_dc, design, _on_export_changed)

	var tint_fold := _make_fold("Tint")
	_detail_root.add_child(tint_fold)

	var tint_inner := VBoxContainer.new()
	tint_inner.add_theme_constant_override("separation", 4)
	tint_fold.add_child(tint_inner)

	var tint_check_row := HBoxContainer.new()
	tint_check_row.add_theme_constant_override("separation", 4)
	tint_inner.add_child(tint_check_row)

	var tint_check := CheckBox.new()
	tint_check.text = "Enabled"
	tint_check.size_flags_horizontal = SIZE_EXPAND_FILL
	tint_check.button_pressed = layer.tint_enabled
	tint_check.toggled.connect(func(p: bool):
		layer.tint_enabled = p
		design.notify_layer_modified()
		changed.emit()
	)
	tint_check_row.add_child(tint_check)

	var field_te: String = "layers.%s.tint_enabled" % layer.layer_id
	BayterekExportHelper.make_exportable(tint_check_row, field_te, design, _on_export_changed)

	var tint_editor := BayterekLayerStateColors.new()
	tint_inner.add_child(tint_editor)
	tint_editor.bind(layer, "tint_configs")
	tint_editor.bind_export(design, layer.layer_id, "tint_configs", _on_export_changed)
	tint_editor.changed.connect(func():
		design.notify_layer_modified()
		changed.emit()
	)

# ============================================================
# HELPERS
# ============================================================

func _make_fold(title: String) -> FoldableContainer:
	var fold := FoldableContainer.new()
	fold.title = title
	fold.folded = false
	return fold

func _add_nine_patch_spin(parent: HBoxContainer, layer: BayterekTextureLayer, label_text: String, prop_name: String) -> void:
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(60, 0)
	parent.add_child(label)

	var spin := SpinBox.new()
	spin.size_flags_horizontal = SIZE_EXPAND_FILL
	spin.min_value = 0
	spin.max_value = 999
	spin.step = 1
	spin.rounded = true
	spin.value = int(layer.get(prop_name))
	spin.value_changed.connect(func(v: float):
		layer.set(prop_name, int(v))
		design.notify_layer_modified()
		changed.emit()
	)
	parent.add_child(spin)

	var field_path: String = "layers.%s.%s" % [layer.layer_id, prop_name]
	BayterekExportHelper.make_exportable(parent, field_path, design, _on_export_changed)

# ============================================================
# DEFERRED REBUILD
# ============================================================

func _rebuild_detail_form_deferred() -> void:
	call_deferred("_rebuild_detail_form")

# ============================================================
# EXPORT CALLBACK
# ============================================================

func _on_export_changed(_field_path: String) -> void:
	if not design:
		return
	BayterekDesignService.save_design(design)
	changed.emit()