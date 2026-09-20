@tool
class_name BayterekDesignListPanel
extends VBoxContainer
## Left sidebar of the Node Editor — collapsible design list + CRUD.
## Behaves like a website sidebar: toggle button collapses to a thin strip.

signal design_selected(design: BayterekNodeDesign)
signal collapsed_changed(collapsed: bool)

const COLLAPSED_WIDTH := 32

var _search_input: LineEdit
var _tree: Tree
var _root_item: TreeItem
var _selected_design_id: String = ""

var _content_root: VBoxContainer
var _toggle_btn: Button
var _bottom_box: HBoxContainer

var _collapsed: bool = false

# id -> TreeItem
var _id_to_item: Dictionary = {}

func _ready() -> void:
	add_theme_constant_override("separation", 4)
	size_flags_vertical = SIZE_EXPAND_FILL
	_build_ui()

func _build_ui() -> void:
	# --- Header row: title + toggle ---
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 4)
	add_child(header_row)

	var title := Label.new()
	title.text = "Designs"
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header_row.add_child(title)

	_toggle_btn = Button.new()
	_toggle_btn.text = "◀"
	_toggle_btn.tooltip_text = "Collapse / expand"
	_toggle_btn.custom_minimum_size = Vector2(24, 24)
	_toggle_btn.pressed.connect(_on_toggle_pressed)
	header_row.add_child(_toggle_btn)

	# --- Collapsible content ---
	_content_root = VBoxContainer.new()
	_content_root.size_flags_horizontal = SIZE_EXPAND_FILL
	_content_root.size_flags_vertical = SIZE_EXPAND_FILL
	_content_root.add_theme_constant_override("separation", 4)
	add_child(_content_root)

	# --- Toolbar: search + add ---
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

	# --- List ---
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

	# --- Bottom actions ---
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
	if _toggle_btn:
		_toggle_btn.text = "▶" if _collapsed else "◀"
	if _collapsed:
		custom_minimum_size.x = COLLAPSED_WIDTH
	else:
		custom_minimum_size.x = 220
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
	vbox.add_theme_constant_override("separation", 6)
	dialog.add_child(vbox)

	var name_row := HBoxContainer.new()
	vbox.add_child(name_row)
	var name_lbl := Label.new()
	name_lbl.text = "Name:"
	name_lbl.custom_minimum_size = Vector2(60, 0)
	name_row.add_child(name_lbl)
	var name_input := LineEdit.new()
	name_input.text = design.name
	name_input.size_flags_horizontal = SIZE_EXPAND_FILL
	name_row.add_child(name_input)

	var cat_row := HBoxContainer.new()
	vbox.add_child(cat_row)
	var cat_lbl := Label.new()
	cat_lbl.text = "Category:"
	cat_lbl.custom_minimum_size = Vector2(60, 0)
	cat_row.add_child(cat_lbl)
	var cat_input := LineEdit.new()
	cat_input.text = design.category
	cat_input.size_flags_horizontal = SIZE_EXPAND_FILL
	cat_row.add_child(cat_input)

	dialog.confirmed.connect(func():
		var new_name: String = name_input.text.strip_edges()
		var new_cat: String = cat_input.text.strip_edges()
		if not new_name.is_empty() and new_name != design.name:
			BayterekDesignService.rename_design(design, new_name)
		design.category = new_cat
		BayterekDesignService.save_design(design)
		refresh()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())

	add_child(dialog)
	dialog.popup_centered(Vector2i(380, 180))
	name_input.call_deferred("grab_focus")
	name_input.call_deferred("select_all")