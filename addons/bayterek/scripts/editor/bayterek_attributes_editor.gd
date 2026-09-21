@tool
class_name BayterekAttributesEditor
extends VBoxContainer
## Attribute list editor — right panel 3rd tab.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

signal changed
signal attribute_changed(attr_id: String)
signal attribute_removed(attr_id: String)
signal attributes_list_changed

var editor: BayterekEditor

var _tree: Tree
var _root_item: TreeItem
var _filter_input: LineEdit
var _add_button: Button

# Detail panel
var _detail_panel: VBoxContainer
var _detail_title: Label
var _name_input: LineEdit
var _effect_input: TextEdit
var _value_count_input: SpinBox

var _current_attr_id: String = ""
var _updating_ui: bool = false

var _id_to_item: Dictionary = {}

func _ready() -> void:
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)

func init() -> void:
	_build_ui()
	_refresh()

func _build_ui() -> void:
	# --- Top toolbar: Filter + Add ---
	var top := HBoxContainer.new()
	add_child(top)

	_filter_input = LineEdit.new()
	_filter_input.placeholder_text = "Filter attributes"
	_filter_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_filter_input.text_changed.connect(_on_filter_changed)
	top.add_child(_filter_input)

	_add_button = Button.new()
	_add_button.text = "+"
	_add_button.tooltip_text = "Add new attribute"
	_add_button.custom_minimum_size = Vector2(28, 0)
	_add_button.pressed.connect(_on_add_pressed)
	top.add_child(_add_button)

	# --- Attribute list ---
	_tree = Tree.new()
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.size_flags_vertical = SIZE_EXPAND_FILL
	_tree.custom_minimum_size = Vector2(0, 180)
	_tree.item_selected.connect(_on_item_selected)
	_tree.button_clicked.connect(_on_item_button_clicked)
	add_child(_tree)

	_root_item = _tree.create_item()

	# --- Detail panel ---
	var sep := HSeparator.new()
	add_child(sep)

	_detail_panel = VBoxContainer.new()
	_detail_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	_detail_panel.add_theme_constant_override("separation", 4)
	add_child(_detail_panel)

	_detail_title = Label.new()
	_detail_title.text = "— Select an attribute —"
	_detail_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_detail_panel.add_child(_detail_title)

	# Name
	var name_row := HBoxContainer.new()
	_detail_panel.add_child(name_row)
	var name_label := Label.new()
	name_label.text = "Name"
	name_label.custom_minimum_size = Vector2(90, 0)
	name_row.add_child(name_label)
	_name_input = LineEdit.new()
	_name_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_name_input.text_changed.connect(_on_name_changed)
	name_row.add_child(_name_input)

	# Effect
	var effect_row := HBoxContainer.new()
	_detail_panel.add_child(effect_row)
	var effect_label := Label.new()
	effect_label.text = "Effect"
	effect_label.custom_minimum_size = Vector2(90, 0)
	effect_label.size_flags_vertical = 0
	effect_label.tooltip_text = "Use # placeholder for values"
	effect_row.add_child(effect_label)
	_effect_input = TextEdit.new()
	_effect_input.custom_minimum_size = Vector2(0, 60)
	_effect_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_effect_input.text_changed.connect(_on_effect_changed)
	effect_row.add_child(_effect_input)

	# Value Count
	var count_row := HBoxContainer.new()
	_detail_panel.add_child(count_row)
	var count_label := Label.new()
	count_label.text = "Value Count"
	count_label.custom_minimum_size = Vector2(90, 0)
	count_label.tooltip_text = "How many values (0-4)"
	count_row.add_child(count_label)
	_value_count_input = SpinBox.new()
	_value_count_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_value_count_input.min_value = 0
	_value_count_input.max_value = 4
	_value_count_input.value = 0
	_value_count_input.rounded = true
	_value_count_input.value_changed.connect(_on_value_count_changed)
	count_row.add_child(_value_count_input)

	_show_detail(false)

# ============================================================
# REFRESH
# ============================================================

func _refresh() -> void:
	if not editor or not editor.tree:
		return

	_clear_items()

	var attrs: Dictionary = editor.tree.attributes
	var ids: Array = attrs.keys()
	ids.sort()

	var filter: String = _filter_input.text.strip_edges()

	if filter.is_empty():
		for id in ids:
			var attr: BayterekAttribute = attrs[id]
			_add_attr_item(attr)
		return

	var fuzzy := BayterekFuzzySearch.new()
	fuzzy.allow_subsequences = false

	for id in ids:
		var attr: BayterekAttribute = attrs[id]
		if fuzzy.matches(filter, id) or fuzzy.matches(filter, attr.name):
			_add_attr_item(attr)

func _clear_items() -> void:
	if not _root_item:
		return
	while _root_item.get_child_count() > 0:
		var child: TreeItem = _root_item.get_child(0)
		_root_item.remove_child(child)
		child.free()
	_id_to_item.clear()

func _add_attr_item(attr: BayterekAttribute) -> void:
	var item := _root_item.create_child()
	item.set_text(0, "%s (%s)" % [attr.name, attr.id])
	item.set_metadata(0, attr.id)

	var theme := EditorInterface.get_editor_theme()
	item.add_button(0, theme.get_icon("Close", Bayterek.ICON_THEME), 0)
	item.set_button_tooltip_text(0, 0, "Delete attribute")

	_id_to_item[attr.id] = item

	if attr.id == _current_attr_id:
		item.select(0)

# ============================================================
# DETAIL PANEL
# ============================================================

func _show_detail(visible_state: bool) -> void:
	_detail_panel.visible = visible_state

func _load_detail(attr_id: String) -> void:
	if not editor or not editor.tree:
		return
	if not editor.tree.attributes.has(attr_id):
		_show_detail(false)
		return

	var attr: BayterekAttribute = editor.tree.attributes[attr_id]
	_current_attr_id = attr_id

	_updating_ui = true
	_detail_title.text = "Attribute: %s" % attr.id
	_name_input.text = attr.name
	_effect_input.text = attr.effect
	_value_count_input.set_value_no_signal(attr.value_count)
	_updating_ui = false

	_show_detail(true)

# ============================================================
# SIGNAL HANDLERS
# ============================================================

func _on_filter_changed(_text: String) -> void:
	_refresh()

func _on_add_pressed() -> void:
	if not editor or not editor.tree:
		return

	var base_id := "new_attribute"
	var new_id := base_id
	var counter := 1
	while editor.tree.attributes.has(new_id):
		counter += 1
		new_id = "%s_%d" % [base_id, counter]

	var attr := BayterekAttribute.new()
	attr.id = new_id
	attr.name = "New Attribute"
	attr.effect = "Effect #"
	attr.value_count = 1

	editor.tree.attributes[new_id] = attr

	editor.set_dirty(true)
	changed.emit()
	attributes_list_changed.emit()
	_refresh()
	_load_detail(new_id)

func _on_item_selected() -> void:
	var selected := _tree.get_selected()
	if not selected:
		return

	var meta = selected.get_metadata(0)
	if typeof(meta) != TYPE_STRING:
		return

	_load_detail(meta)

func _on_item_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return

	var meta = item.get_metadata(0)
	if typeof(meta) != TYPE_STRING:
		return

	var attr_id: String = meta
	_delete_attribute(attr_id)

func _delete_attribute(attr_id: String) -> void:
	if not editor or not editor.tree:
		return
	if not editor.tree.attributes.has(attr_id):
		return

	editor.tree.attributes.erase(attr_id)

	if _current_attr_id == attr_id:
		_current_attr_id = ""
		_show_detail(false)

	editor.set_dirty(true)
	changed.emit()
	attribute_removed.emit(attr_id)
	_refresh()

# ============================================================
# DETAIL CHANGES
# ============================================================

func _on_name_changed(new_text: String) -> void:
	if _updating_ui or _current_attr_id.is_empty():
		return
	if not editor or not editor.tree:
		return
	var attr: BayterekAttribute = editor.tree.attributes.get(_current_attr_id, null)
	if not attr:
		return
	attr.name = new_text

	if _id_to_item.has(_current_attr_id):
		var item: TreeItem = _id_to_item[_current_attr_id]
		if item:
			item.set_text(0, "%s (%s)" % [new_text, _current_attr_id])

	editor.set_dirty(true)
	changed.emit()
	attribute_changed.emit(_current_attr_id)

func _on_effect_changed() -> void:
	if _updating_ui or _current_attr_id.is_empty():
		return
	if not editor or not editor.tree:
		return
	var attr: BayterekAttribute = editor.tree.attributes.get(_current_attr_id, null)
	if not attr:
		return
	attr.effect = _effect_input.text
	editor.set_dirty(true)
	changed.emit()
	attribute_changed.emit(_current_attr_id)

func _on_value_count_changed(value: float) -> void:
	if _updating_ui or _current_attr_id.is_empty():
		return
	if not editor or not editor.tree:
		return
	var attr: BayterekAttribute = editor.tree.attributes.get(_current_attr_id, null)
	if not attr:
		return

	var old_count: int = attr.value_count
	var new_count: int = int(value)
	attr.value_count = new_count

	if old_count != new_count:
		_resize_nodes_arrays(_current_attr_id, new_count)

	editor.set_dirty(true)
	changed.emit()
	attribute_changed.emit(_current_attr_id)

func _resize_nodes_arrays(attr_id: String, new_count: int) -> void:
	if not editor or not editor.tree:
		return

	# Resize each node
	for node_data in editor.tree.nodes:
		if not node_data.attributes.has(attr_id):
			continue
		var values = node_data.attributes[attr_id]
		_resize_value_array(values, new_count)

	# Resize each prefab (artık Array)
	for prefab in editor.tree.prefabs:
		if not prefab:
			continue
		if not prefab.attributes.has(attr_id):
			continue
		var values = prefab.attributes[attr_id]
		_resize_value_array(values, new_count)

func _resize_value_array(values: Variant, new_count: int) -> void:
	if not values is Array:
		return

	if values.size() > 0 and values[0] is Array:
		for level in values.size():
			var level_values: Array = values[level]
			while level_values.size() < new_count:
				level_values.append(0)
			while level_values.size() > new_count:
				level_values.pop_back()
	else:
		while values.size() < new_count:
			values.append(0)
		while values.size() > new_count:
			values.pop_back()