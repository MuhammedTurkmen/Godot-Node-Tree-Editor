@tool
class_name BayterekDesignListPanel
extends VBoxContainer
## Left sidebar of the Node Editor — collapsible design list + CRUD.

signal design_selected(design: BayterekNodeDesign)
signal collapsed_changed(collapsed: bool)
signal design_category_changed

const COLLAPSED_WIDTH := 24
const EXPANDED_WIDTH := 220

var _search_input: LineEdit
var _tree: Tree
var _root_item: TreeItem
var _selected_design_id: String = ""

var _header_row: HBoxContainer
var _title_label: Label
var _toggle_btn: Button
var _content_root: VBoxContainer
var _bottom_box: HBoxContainer

var _collapsed: bool = false

var _id_to_item: Dictionary = {}

func _ready() -> void:
	add_theme_constant_override("separation", 4)
	size_flags_vertical = SIZE_EXPAND_FILL
	_build_ui()

func _build_ui() -> void:
	_header_row = HBoxContainer.new()
	_header_row.add_theme_constant_override("separation", 4)
	add_child(_header_row)

	_title_label = Label.new()
	_title_label.text = "Designs"
	_title_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_title_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_header_row.add_child(_title_label)

	_toggle_btn = Button.new()
	_toggle_btn.text = "◀"
	_toggle_btn.tooltip_text = "Collapse / expand"
	_toggle_btn.custom_minimum_size = Vector2(20, 20)
	_toggle_btn.pressed.connect(_on_toggle_pressed)
	_header_row.add_child(_toggle_btn)

	_content_root = VBoxContainer.new()
	_content_root.size_flags_horizontal = SIZE_EXPAND_FILL
	_content_root.size_flags_vertical = SIZE_EXPAND_FILL
	_content_root.add_theme_constant_override("separation", 4)
	add_child(_content_root)

	var top := HBoxContainer.new()
	_content_root.add_child(top)

	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Filter"
	_search_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_search_input.text_changed.connect(_on_filter_changed)
	top.add_child(_search_input)

	var add_btn := Button.new()
	add_btn.text = "+"
	add_btn.tooltip_text = "Create new design"
	add_btn.custom_minimum_size = Vector2(28, 0)
	add_btn.pressed.connect(_on_add_pressed)
	top.add_child(add_btn)

	_tree = Tree.new()
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.size_flags_horizontal = SIZE_EXPAND_FILL
	_tree.size_flags_vertical = SIZE_EXPAND_FILL
	_tree.custom_minimum_size = Vector2(180, 0)
	_tree.item_selected.connect(_on_item_selected)
	_tree.item_activated.connect(_on_item_activated)
	_tree.gui_input.connect(_on_tree_gui_input)
	_content_root.add_child(_tree)

	_root_item = _tree.create_item()

	_bottom_box = HBoxContainer.new()
	_content_root.add_child(_bottom_box)

	var dup_btn := Button.new()
	dup_btn.text = "Duplicate"
	dup_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	dup_btn.pressed.connect(_on_duplicate_pressed)
	_bottom_box.add_child(dup_btn)

	var del_btn := Button.new()
	del_btn.text = "Delete"
	del_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	del_btn.pressed.connect(_on_delete_pressed)
	_bottom_box.add_child(del_btn)

# ============================================================
# COLLAPSE / EXPAND
# ============================================================

func _on_toggle_pressed() -> void:
	_collapsed = not _collapsed
	_apply_collapsed()

func _apply_collapsed() -> void:
	if _content_root:
		_content_root.visible = not _collapsed
	if _title_label:
		_title_label.visible = not _collapsed
	if _toggle_btn:
		_toggle_btn.text = "▶" if _collapsed else "◀"

	if _collapsed:
		custom_minimum_size.x = COLLAPSED_WIDTH
	else:
		custom_minimum_size.x = EXPANDED_WIDTH

	collapsed_changed.emit(_collapsed)

func is_collapsed() -> bool:
	return _collapsed

func set_collapsed(value: bool) -> void:
	if _collapsed == value:
		return
	_collapsed = value
	_apply_collapsed()

# ============================================================
# REFRESH
# ============================================================

func refresh() -> void:
	_clear_items()
	_id_to_item.clear()

	var reg = Bayterek.get_designs_registry()
	if not reg:
		return

	var filter: String = _search_input.text.strip_edges() if _search_input else ""
	var fuzzy := BayterekFuzzySearch.new()
	fuzzy.allow_subsequences = false

	var designs: Array = reg.designs.duplicate()
	designs.sort_custom(func(a, b): return a.name.naturalnocasecmp_to(b.name) < 0)

	for design in designs:
		if not design:
			continue
		if not filter.is_empty():
			var match_name: bool = fuzzy.matches(filter, design.name)
			var match_cat: bool = not design.category.is_empty() and fuzzy.matches(filter, design.category)
			if not (match_name or match_cat):
				continue
		_add_design_item(design)

	if not _selected_design_id.is_empty() and _id_to_item.has(_selected_design_id):
		var item: TreeItem = _id_to_item[_selected_design_id]
		if item:
			item.select(0)

func _clear_items() -> void:
	if not _root_item:
		return
	while _root_item.get_child_count() > 0:
		var child: TreeItem = _root_item.get_child(0)
		_root_item.remove_child(child)
		child.free()

func _add_design_item(design: BayterekNodeDesign) -> void:
	var item := _root_item.create_child()
	var label: String = design.name
	if not design.category.is_empty():
		label = "[%s] %s" % [design.category, design.name]
	item.set_text(0, label)
	item.set_metadata(0, design.id)

	var theme := EditorInterface.get_editor_theme()
	if theme and theme.has_icon(Bayterek.DESIGN_ICON, Bayterek.ICON_THEME):
		item.set_icon(0, theme.get_icon(Bayterek.DESIGN_ICON, Bayterek.ICON_THEME))

	_id_to_item[design.id] = item

# ============================================================
# PUBLIC
# ============================================================

func get_selected_design() -> BayterekNodeDesign:
	if _selected_design_id.is_empty():
		return null
	return Bayterek.get_designs_registry().get_design_by_id(_selected_design_id)

func select_design(design: BayterekNodeDesign) -> void:
	if not design:
		return
	_selected_design_id = design.id
	if _id_to_item.has(design.id):
		var item: TreeItem = _id_to_item[design.id]
		if item:
			item.select(0)

# ============================================================
# SIGNAL HANDLERS
# ============================================================

func _on_filter_changed(_text: String) -> void:
	refresh()

func _on_item_selected() -> void:
	var selected := _tree.get_selected()
	if not selected:
		return
	var id = selected.get_metadata(0)
	if typeof(id) != TYPE_STRING:
		return
	_selected_design_id = id
	var design: BayterekNodeDesign = Bayterek.get_designs_registry().get_design_by_id(id)
	if design:
		design_selected.emit(design)

func _on_item_activated() -> void:
	_on_item_selected()

func _on_tree_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var item: TreeItem = _tree.get_item_at_position(event.position)
			if item:
				item.select(0)
				_show_context_menu(event.position)

# ============================================================
# CRUD
# ============================================================

func _on_add_pressed() -> void:
	var new_design: BayterekNodeDesign = BayterekDesignService.create_design("New Design")
	if not new_design:
		return
	refresh()
	select_design(new_design)
	design_selected.emit(new_design)

func _on_duplicate_pressed() -> void:
	var design: BayterekNodeDesign = get_selected_design()
	if not design:
		BayterekToast.info(_tree, "Select a design first")
		return
	var copy: BayterekNodeDesign = BayterekDesignService.duplicate_design(design)
	if not copy:
		return
	refresh()
	select_design(copy)
	design_selected.emit(copy)

func _on_delete_pressed() -> void:
	var design: BayterekNodeDesign = get_selected_design()
	if not design:
		BayterekToast.info(_tree, "Select a design first")
		return

	var dialog := ConfirmationDialog.new()
	dialog.title = "Delete Design"
	dialog.dialog_text = "Delete design \"%s\"?\n\nThis will remove the .tres file from disk." % design.name
	dialog.ok_button_text = "Delete"
	dialog.cancel_button_text = "Cancel"
	dialog.unresizable = true

	dialog.confirmed.connect(func():
		BayterekDesignService.delete_design(design)
		_selected_design_id = ""
		refresh()
		design_selected.emit(null)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())

	add_child(dialog)
	dialog.popup_centered(Vector2i(380, 160))

# ============================================================
# CONTEXT MENU
# ============================================================

func _show_context_menu(pos: Vector2) -> void:
	var menu := PopupMenu.new()
	menu.add_item("Rename...", 0)
	menu.add_item("Duplicate", 1)
	menu.add_separator()
	menu.add_item("Delete", 2)

	menu.id_pressed.connect(func(id: int):
		match id:
			0: _rename_selected()
			1: _on_duplicate_pressed()
			2: _on_delete_pressed()
		menu.queue_free()
	)
	add_child(menu)
	menu.position = Vector2i(_tree.get_screen_position() + pos)
	menu.popup()

# ============================================================
# RENAME DIALOG
# ============================================================

func _rename_selected() -> void:
	var design: BayterekNodeDesign = get_selected_design()
	if not design:
		return

	var dialog := ConfirmationDialog.new()
	dialog.title = "Rename Design"
	dialog.ok_button_text = "Rename"
	dialog.cancel_button_text = "Cancel"
	dialog.unresizable = true

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.custom_minimum_size = Vector2(400, 0)
	dialog.add_child(vbox)

	# --- Name ---
	var name_row := HBoxContainer.new()
	vbox.add_child(name_row)
	var name_lbl := Label.new()
	name_lbl.text = "Name:"
	name_lbl.custom_minimum_size = Vector2(80, 0)
	name_row.add_child(name_lbl)
	var name_input := LineEdit.new()
	name_input.text = design.name
	name_input.size_flags_horizontal = SIZE_EXPAND_FILL
	name_row.add_child(name_input)

	# --- Category ---
	var cat_row := HBoxContainer.new()
	vbox.add_child(cat_row)
	var cat_lbl := Label.new()
	cat_lbl.text = "Category:"
	cat_lbl.custom_minimum_size = Vector2(80, 0)
	cat_row.add_child(cat_lbl)

	var cat_dropdown := OptionButton.new()
	cat_dropdown.size_flags_horizontal = SIZE_EXPAND_FILL
	cat_row.add_child(cat_dropdown)

	var new_cat_btn := Button.new()
	new_cat_btn.text = "+"
	new_cat_btn.tooltip_text = "Create new category"
	new_cat_btn.custom_minimum_size = Vector2(28, 0)
	cat_row.add_child(new_cat_btn)

	_rebuild_category_dropdown(cat_dropdown, design.category)

	new_cat_btn.pressed.connect(func():
		_open_new_category_dialog(cat_dropdown, dialog)
	)

	dialog.confirmed.connect(func():
		var new_name: String = name_input.text.strip_edges()
		if new_name.is_empty():
			dialog.queue_free()
			return

		var selected_category: String = ""
		var meta = cat_dropdown.get_item_metadata(cat_dropdown.selected)
		if typeof(meta) == TYPE_STRING:
			selected_category = meta

		if new_name != design.name:
			BayterekDesignService.rename_design(design, new_name)

		var old_category: String = design.category
		if selected_category != old_category:
			design.category = selected_category
			BayterekDesignService.save_design(design)
			design_category_changed.emit()

		refresh()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())

	add_child(dialog)
	dialog.popup_centered(Vector2i(440, 200))
	name_input.call_deferred("grab_focus")
	name_input.call_deferred("select_all")

func _rebuild_category_dropdown(dropdown: OptionButton, current_category: String) -> void:
	dropdown.clear()

	dropdown.add_item("(None)", 0)
	dropdown.set_item_metadata(0, "")

	var cats: Array = BayterekDesignService.get_all_categories()

	var idx: int = 1
	var found_idx: int = 0
	for cat in cats:
		var cat_str: String = String(cat)
		dropdown.add_item(cat_str, idx)
		dropdown.set_item_metadata(idx, cat_str)
		if cat_str == current_category:
			found_idx = idx
		idx += 1

	dropdown.select(found_idx)

# ============================================================
# NEW CATEGORY DIALOG
# ============================================================

## Opens a small dialog to enter a new category name.
## Non-exclusive — parent rename dialog stays visible underneath.
func _open_new_category_dialog(dropdown: OptionButton, _parent_dialog: ConfirmationDialog) -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "New Category"
	dlg.ok_button_text = "Create"
	dlg.unresizable = true
	dlg.exclusive = false

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.custom_minimum_size = Vector2(320, 0)
	dlg.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "Category name:"
	vbox.add_child(lbl)

	var input := LineEdit.new()
	input.placeholder_text = "e.g. Combat, Passive, Utility"
	vbox.add_child(input)

	var error_lbl := Label.new()
	error_lbl.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	error_lbl.visible = false
	error_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(error_lbl)

	dlg.confirmed.connect(func():
		var new_cat: String = input.text.strip_edges()

		if new_cat.is_empty():
			error_lbl.text = "Category name cannot be empty."
			error_lbl.visible = true
			# AcceptDialog auto-closes on confirm; reopen to show error.
			dlg.popup_centered(Vector2i(360, 200))
			return

		var existing: Array = BayterekDesignService.get_all_categories()
		for cat in existing:
			if String(cat) == new_cat:
				error_lbl.text = "Category \"%s\" already exists." % new_cat
				error_lbl.visible = true
				dlg.popup_centered(Vector2i(360, 200))
				return

		var next_idx: int = dropdown.item_count
		dropdown.add_item(new_cat, next_idx)
		dropdown.set_item_metadata(next_idx, new_cat)
		dropdown.select(next_idx)

		dlg.queue_free()
	)

	add_child(dlg)
	dlg.popup_centered(Vector2i(360, 200))
	input.call_deferred("grab_focus")