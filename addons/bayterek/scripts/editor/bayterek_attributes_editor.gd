@tool
class_name BayterekAttributesEditor
extends VBoxContainer
## Attribute list editor — right panel 3rd tab.
##
## List shows NAME (col 0) + ID (col 1) side by side.
##
## LOCALIZATION:
##   Each attribute has two optional localization keys:
##     - name_key   → display name
##     - effect_key → effect text
##   The editor exposes both. Empty keys fall back to `name` / `effect`.
##
## CUMULATIVE:
##   Non-currency attributes can be marked as "cumulative". In
##   cumulative mode, every allocation level's value is ADDED on top
##   of the previous levels (both in the tooltip and at runtime).
##
##   Cumulative only makes sense for ADD and SUBTRACT operations:
##     - ADD:      level 1..N values are summed → bigger bonus
##     - SUBTRACT: level 1..N values are summed → bigger penalty
##   For SET / MULTIPLY / MIN / MAX it produces nonsensical results,
##   so the checkbox is automatically disabled and the flag is
##   force-cleared whenever one of those operations is selected.

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

var _detail_panel: VBoxContainer
var _detail_title: Label
var _detail_id_label: Label
var _name_input: LineEdit
var _name_key_input: LineEdit
var _effect_input: TextEdit
var _effect_key_input: LineEdit
var _value_count_input: SpinBox
var _is_currency_check: CheckBox
var _refund_differs_check: CheckBox
var _cumulative_check: CheckBox
var _operation_dropdown: OptionButton
var _icon_panel: HBoxContainer
var _icon_input: BayterekInspectorTextureInput

## Currently selected attribute's DICT KEY (not necessarily attr.id).
var _current_attr_id: String = ""
var _updating_ui: bool = false

## dict_key -> TreeItem
var _id_to_item: Dictionary = {}

const COLOR_CONFLICT := Color(1.0, 0.35, 0.35)
const COLOR_ID_OK := Color(0.85, 0.9, 1.0)
const COLOR_ID_IN_LIST := Color(0.55, 0.65, 0.75)
const COLOR_NAME_IN_LIST := Color(0.95, 0.95, 0.95)

const TEMP_KEY_PREFIX := "__conflict_"

## Operations for which the "Cumulative" flag is meaningful.
const CUMULATIVE_ALLOWED_OPS := [
	BayterekAttribute.Operation.ADD,
	BayterekAttribute.Operation.SUBTRACT,
]

func _ready() -> void:
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)

func init() -> void:
	_build_ui()
	_refresh()

# ============================================================
# HELPERS — cumulative compatibility
# ============================================================

## Returns true if `cumulative` is meaningful for the given operation.
static func is_cumulative_supported(op: BayterekAttribute.Operation) -> bool:
	return op in CUMULATIVE_ALLOWED_OPS

## Returns true if cumulative is meaningful for the given attribute
## (i.e. it's a non-currency attribute using ADD or SUBTRACT).
static func is_cumulative_available(attr: BayterekAttribute) -> bool:
	if not attr:
		return false
	if attr.is_currency:
		return false
	return is_cumulative_supported(attr.operation)

func _build_ui() -> void:
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

	_tree = Tree.new()
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.columns = 2
	_tree.set_column_title(0, "Name")
	_tree.set_column_title(1, "ID")
	_tree.set_column_expand(0, true)
	_tree.set_column_expand(1, true)
	_tree.set_column_custom_minimum_width(0, 100)
	_tree.set_column_custom_minimum_width(1, 100)
	_tree.size_flags_vertical = SIZE_EXPAND_FILL
	_tree.custom_minimum_size = Vector2(0, 180)
	_tree.item_selected.connect(_on_item_selected)
	_tree.button_clicked.connect(_on_item_button_clicked)
	add_child(_tree)

	_root_item = _tree.create_item()

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

	# ID row (read-only preview)
	var id_row := HBoxContainer.new()
	id_row.add_theme_constant_override("separation", 4)
	_detail_panel.add_child(id_row)

	var id_static := Label.new()
	id_static.text = "ID"
	id_static.custom_minimum_size = Vector2(60, 0)
	id_static.tooltip_text = "Auto-derived from Name. If it collides with another attribute, it turns red — rename to fix, or save to auto-suffix."
	id_row.add_child(id_static)

	_detail_id_label = Label.new()
	_detail_id_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_detail_id_label.add_theme_font_size_override("font_size", 12)
	_detail_id_label.add_theme_color_override("font_color", COLOR_ID_OK)
	id_row.add_child(_detail_id_label)

	# Name
	var name_row := HBoxContainer.new()
	_detail_panel.add_child(name_row)
	var name_label := Label.new()
	name_label.text = "Name"
	name_label.custom_minimum_size = Vector2(60, 0)
	name_row.add_child(name_label)
	_name_input = LineEdit.new()
	_name_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_name_input.text_changed.connect(_on_name_changed)
	name_row.add_child(_name_input)

	# Name Key (localization)
	var name_key_row := HBoxContainer.new()
	_detail_panel.add_child(name_key_row)
	var name_key_label := Label.new()
	name_key_label.text = "Name Key"
	name_key_label.custom_minimum_size = Vector2(60, 0)
	name_key_label.tooltip_text = "Optional localization key for the attribute's display name.\nLeave empty to use the Name field."
	name_key_row.add_child(name_key_label)
	_name_key_input = LineEdit.new()
	_name_key_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_name_key_input.placeholder_text = "(optional) e.g. attr_max_health_name"
	_name_key_input.text_changed.connect(_on_name_key_changed)
	name_key_row.add_child(_name_key_input)

	# Effect Key (localization)
	var effect_key_row := HBoxContainer.new()
	_detail_panel.add_child(effect_key_row)
	var effect_key_label := Label.new()
	effect_key_label.text = "Effect Key"
	effect_key_label.custom_minimum_size = Vector2(60, 0)
	effect_key_label.tooltip_text = "Optional localization key.\nIf set, the tooltip looks up this key in GameLocalization and uses the translated text as the base for {P}/{C}/{N} substitution.\nLeave empty to use the Effect field below."
	effect_key_row.add_child(effect_key_label)
	_effect_key_input = LineEdit.new()
	_effect_key_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_effect_key_input.placeholder_text = "(optional) e.g. attr_max_health_effect"
	_effect_key_input.text_changed.connect(_on_effect_key_changed)
	effect_key_row.add_child(_effect_key_input)

	# Effect
	var effect_row := HBoxContainer.new()
	_detail_panel.add_child(effect_row)
	var effect_label := Label.new()
	effect_label.text = "Effect"
	effect_label.custom_minimum_size = Vector2(60, 0)
	effect_label.size_flags_vertical = 0
	effect_label.tooltip_text = "Fallback text when no Effect Key is set.\nUse {P}, {C}, {N} for previous/current/next level values.\nUse {C0}, {C1} for specific value slots."
	effect_row.add_child(effect_label)
	_effect_input = TextEdit.new()
	_effect_input.custom_minimum_size = Vector2(0, 60)
	_effect_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_effect_input.text_changed.connect(_on_effect_changed)
	effect_row.add_child(_effect_input)

	# Is Currency
	var currency_row := HBoxContainer.new()
	currency_row.add_theme_constant_override("separation", 4)
	_detail_panel.add_child(currency_row)

	var currency_label := Label.new()
	currency_row.add_child(currency_label)
	currency_label.text = "Is Currency"
	currency_label.custom_minimum_size = Vector2(90, 0)
	currency_label.tooltip_text = "Mark this attribute as a purchase cost."
	currency_label.mouse_filter = Control.MOUSE_FILTER_PASS

	_is_currency_check = CheckBox.new()
	_is_currency_check.text = "On"
	_is_currency_check.size_flags_horizontal = SIZE_EXPAND_FILL
	_is_currency_check.toggled.connect(_on_is_currency_toggled)
	currency_row.add_child(_is_currency_check)

	# Refund Differs
	var refund_row := HBoxContainer.new()
	refund_row.add_theme_constant_override("separation", 4)
	_detail_panel.add_child(refund_row)

	var refund_label := Label.new()
	refund_row.add_child(refund_label)
	refund_label.text = "Refund Differs"
	refund_label.custom_minimum_size = Vector2(90, 0)
	refund_label.tooltip_text = "If ON, the attribute stores TWO values: [purchase, refund]."
	refund_label.mouse_filter = Control.MOUSE_FILTER_PASS

	_refund_differs_check = CheckBox.new()
	_refund_differs_check.text = "On"
	_refund_differs_check.size_flags_horizontal = SIZE_EXPAND_FILL
	_refund_differs_check.toggled.connect(_on_refund_differs_toggled)
	refund_row.add_child(_refund_differs_check)

	# Cumulative (non-currency, ADD/SUBTRACT only)
	var cumulative_row := HBoxContainer.new()
	cumulative_row.add_theme_constant_override("separation", 4)
	_detail_panel.add_child(cumulative_row)

	var cumulative_label := Label.new()
	cumulative_row.add_child(cumulative_label)
	cumulative_label.text = "Cumulative"
	cumulative_label.custom_minimum_size = Vector2(90, 0)
	cumulative_label.tooltip_text = "If ON, every allocation level's value is ADDED on top of the previous ones.\nTooltip's {C}/{N} show the running total instead of the raw per-level value.\n\nOnly meaningful for ADD and SUBTRACT operations. It is automatically disabled for SET / MULTIPLY / MIN / MAX."
	cumulative_label.mouse_filter = Control.MOUSE_FILTER_PASS

	_cumulative_check = CheckBox.new()
	_cumulative_check.text = "On"
	_cumulative_check.size_flags_horizontal = SIZE_EXPAND_FILL
	_cumulative_check.toggled.connect(_on_cumulative_toggled)
	cumulative_row.add_child(_cumulative_check)

	# Operation (non-currency only)
	var op_row := HBoxContainer.new()
	op_row.add_theme_constant_override("separation", 4)
	_detail_panel.add_child(op_row)

	var op_label := Label.new()
	op_row.add_child(op_label)
	op_label.text = "Operation"
	op_label.custom_minimum_size = Vector2(90, 0)
	op_label.tooltip_text = "How this attribute is applied to the total when a node is purchased.\nOnly used for non-currency attributes."
	op_label.mouse_filter = Control.MOUSE_FILTER_PASS

	_operation_dropdown = OptionButton.new()
	_operation_dropdown.size_flags_horizontal = SIZE_EXPAND_FILL
	for op in BayterekAttribute.all_operations():
		var label: String = BayterekAttribute.operation_label(op)
		_operation_dropdown.add_item(label, int(op))
	_operation_dropdown.item_selected.connect(_on_operation_changed)
	op_row.add_child(_operation_dropdown)

	# Icon row — only visible for currency attributes.
	_icon_panel = HBoxContainer.new()
	_icon_panel.add_theme_constant_override("separation", 4)
	_detail_panel.add_child(_icon_panel)

	var icon_label := Label.new()
	icon_label.text = "Icon"
	icon_label.custom_minimum_size = Vector2(90, 0)
	icon_label.tooltip_text = "Custom icon shown in the tooltip's currency row.\nLeave empty to use the default 💰 emoji."
	icon_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_icon_panel.add_child(icon_label)

	_icon_input = BayterekInspectorTextureInput.new()
	_icon_input.title = ""
	_icon_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_icon_input.texture_dropped.connect(_on_icon_changed)
	_icon_input.cleared.connect(_on_icon_cleared)
	_icon_panel.add_child(_icon_input)

	# Value Count
	var count_row := HBoxContainer.new()
	_detail_panel.add_child(count_row)
	var count_label := Label.new()
	count_label.text = "Value Count"
	count_label.custom_minimum_size = Vector2(90, 0)
	count_label.tooltip_text = "How many values (0-4). Only used for non-currency attributes."
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
	var keys: Array = attrs.keys()
	keys.sort()

	var filter: String = _filter_input.text.strip_edges()

	if filter.is_empty():
		for key in keys:
			var attr: BayterekAttribute = attrs[key]
			_add_attr_item(key, attr)
	else:
		var fuzzy := BayterekFuzzySearch.new()
		fuzzy.allow_subsequences = false

		for key in keys:
			var attr: BayterekAttribute = attrs[key]
			if fuzzy.matches(filter, attr.id) or fuzzy.matches(filter, attr.name):
				_add_attr_item(key, attr)

	_apply_visual_selection()

func _clear_items() -> void:
	if not _root_item:
		return
	while _root_item.get_child_count() > 0:
		var child: TreeItem = _root_item.get_child(0)
		_root_item.remove_child(child)
		child.free()
	_id_to_item.clear()

func _add_attr_item(dict_key: String, attr: BayterekAttribute) -> void:
	var item := _root_item.create_child()

	var prefix: String = "💰 " if attr.is_currency else ""
	# Use the localized display name in the list (name_key if set,
	# otherwise fall back to `name`).
	var display: String = attr.get_display_name()
	item.set_text(0, "%s%s" % [prefix, display])
	item.set_text(1, attr.id)

	var conflict: bool = _attribute_has_conflict(attr)

	var name_color: Color = COLOR_CONFLICT if conflict else COLOR_NAME_IN_LIST
	var id_color: Color = COLOR_CONFLICT if conflict else COLOR_ID_IN_LIST
	item.set_custom_color(0, name_color)
	item.set_custom_color(1, id_color)

	var tip: String = "ID: %s" % attr.id
	if not attr.name_key.is_empty():
		tip += "\nName Key: %s" % attr.name_key
	if not attr.is_currency:
		tip += "\nOperation: %s" % BayterekAttribute.operation_label(attr.operation)
	if is_cumulative_available(attr) and attr.cumulative:
		tip += "\nMode: Cumulative (levels stack)"
	if not attr.effect_key.is_empty():
		tip += "\nEffect Key: %s" % attr.effect_key
	if conflict:
		tip += "\n[!] Conflicts with another attribute — rename or save to auto-suffix."
	item.set_tooltip_text(0, tip)
	item.set_tooltip_text(1, tip)

	item.set_metadata(0, dict_key)

	var theme := EditorInterface.get_editor_theme()
	item.add_button(1, theme.get_icon("Close", Bayterek.ICON_THEME), 0)
	item.set_button_tooltip_text(1, 0, "Delete attribute")

	_id_to_item[dict_key] = item

## Returns true if `target_attr` shares its id with another attribute.
func _attribute_has_conflict(target_attr: BayterekAttribute) -> bool:
	if not target_attr or target_attr.id.is_empty():
		return false
	if not editor or not editor.tree:
		return false
	var count: int = 0
	for key in editor.tree.attributes.keys():
		var other: BayterekAttribute = editor.tree.attributes[key]
		if other and other.id == target_attr.id:
			count += 1
			if count > 1:
				return true
	return false

func _apply_visual_selection() -> void:
	var was_updating: bool = _updating_ui
	_updating_ui = true

	_tree.deselect_all()

	if not _current_attr_id.is_empty() and _id_to_item.has(_current_attr_id):
		var item: TreeItem = _id_to_item[_current_attr_id]
		if item:
			item.select(0)

	_updating_ui = was_updating

# ============================================================
# DETAIL PANEL
# ============================================================

func _show_detail(visible_state: bool) -> void:
	_detail_panel.visible = visible_state

func _load_detail(dict_key: String) -> void:
	if not editor or not editor.tree:
		return
	if not editor.tree.attributes.has(dict_key):
		_show_detail(false)
		return

	var attr: BayterekAttribute = editor.tree.attributes[dict_key]
	_current_attr_id = dict_key

	var conflict: bool = _attribute_has_conflict(attr)

	_updating_ui = true
	_detail_title.text = "Attribute"
	_detail_id_label.text = attr.id

	if conflict:
		_detail_id_label.add_theme_color_override("font_color", COLOR_CONFLICT)
		_detail_id_label.tooltip_text = (
			"An attribute with id '%s' already exists.\n" % attr.id +
			"Rename to fix, or save the tree to auto-suffix the colliding ids."
		)
	else:
		_detail_id_label.add_theme_color_override("font_color", COLOR_ID_OK)
		_detail_id_label.tooltip_text = ""

	_name_input.text = attr.name
	_name_key_input.text = attr.name_key
	_effect_input.text = attr.effect
	_effect_key_input.text = attr.effect_key
	_is_currency_check.button_pressed = attr.is_currency
	_refund_differs_check.button_pressed = attr.refund_differs
	_cumulative_check.button_pressed = attr.cumulative
	_value_count_input.set_value_no_signal(attr.value_count)

	if _operation_dropdown:
		var idx: int = _operation_dropdown.get_item_index(int(attr.operation))
		if idx >= 0:
			_operation_dropdown.select(idx)
		_operation_dropdown.disabled = attr.is_currency

	if _icon_panel:
		_icon_panel.visible = attr.is_currency
	if _icon_input and attr.is_currency:
		_icon_input.set_texture(attr.icon)

	_update_currency_ui_state(attr)
	_updating_ui = false

	_show_detail(true)

func _update_currency_ui_state(attr: BayterekAttribute) -> void:
	if not attr:
		return

	_refund_differs_check.disabled = not attr.is_currency

	# Cumulative only makes sense for non-currency ADD/SUBTRACT.
	if _cumulative_check:
		var available: bool = is_cumulative_available(attr)
		_cumulative_check.disabled = not available
		if not available and attr.cumulative:
			# Force-clear: the selected operation doesn't support
			# cumulative mode. This keeps the data consistent and
			# avoids nonsensical runtime results.
			attr.cumulative = false
			_cumulative_check.button_pressed = false

	if _operation_dropdown:
		_operation_dropdown.disabled = attr.is_currency

	if _icon_panel:
		_icon_panel.visible = attr.is_currency

	if attr.is_currency:
		var effective: int = attr.get_effective_value_count()
		_value_count_input.set_value_no_signal(effective)
		_value_count_input.editable = false
		_value_count_input.modulate = Color(0.6, 0.6, 0.6)
	else:
		_value_count_input.editable = true
		_value_count_input.modulate = Color.WHITE

# ============================================================
# ID DERIVATION + CONFLICT
# ============================================================

## Returns true if any OTHER attribute already uses `candidate` as
## its id.  Compares against attr.id, not dict key.
func _id_conflicts(candidate: String) -> bool:
	if candidate.is_empty():
		return false
	if not editor or not editor.tree:
		return false
	for other_key in editor.tree.attributes.keys():
		if other_key == _current_attr_id:
			continue
		var other: BayterekAttribute = editor.tree.attributes[other_key]
		if other and other.id == candidate:
			return true
	return false

func _is_temp_key(key: String) -> bool:
	return key.begins_with(TEMP_KEY_PREFIX)

func _make_temp_key(attr: BayterekAttribute) -> String:
	return "%s%d" % [TEMP_KEY_PREFIX, attr.get_instance_id()]

static func migrate_references(tree: BayterekTree, old_id: String, new_id: String) -> void:
	if old_id == new_id or not tree:
		return

	for node_data in tree.nodes:
		if not node_data:
			continue
		if node_data.attributes.has(old_id):
			node_data.attributes[new_id] = node_data.attributes[old_id]
			node_data.attributes.erase(old_id)
		if node_data.overridden_attributes.has(old_id):
			node_data.overridden_attributes[new_id] = node_data.overridden_attributes[old_id]
			node_data.overridden_attributes.erase(old_id)

	for prefab in tree.prefabs:
		if not prefab:
			continue
		if prefab.attributes.has(old_id):
			prefab.attributes[new_id] = prefab.attributes[old_id]
			prefab.attributes.erase(old_id)

# ============================================================
# SIGNAL HANDLERS
# ============================================================

func _on_filter_changed(_text: String) -> void:
	_refresh()

func _on_add_pressed() -> void:
	if not editor or not editor.tree:
		return

	var base_name: String = "New Attribute"
	var base_id: String = Bayterek.to_snake_case(base_name)

	var attr_id: String = base_id
	var display_name: String = base_name
	var counter: int = 2

	while _tree_has_id(attr_id):
		display_name = "%s %d" % [base_name, counter]
		attr_id = Bayterek.to_snake_case(display_name)
		counter += 1

	var attr := BayterekAttribute.new()
	attr.id = attr_id
	attr.name = display_name
	attr.name_key = ""
	attr.effect = "Effect {C}"
	attr.effect_key = ""
	attr.value_count = 1
	attr.operation = BayterekAttribute.Operation.ADD
	attr.cumulative = false
	attr.icon = null

	editor.tree.attributes[attr_id] = attr

	editor.set_dirty(true)
	changed.emit()
	attributes_list_changed.emit()
	_refresh()
	_load_detail(attr_id)
	_name_input.grab_focus()
	_name_input.select_all()

func _tree_has_id(candidate: String) -> bool:
	if not editor or not editor.tree:
		return false
	for key in editor.tree.attributes.keys():
		var attr: BayterekAttribute = editor.tree.attributes[key]
		if attr and attr.id == candidate:
			return true
	return false

func _on_item_selected() -> void:
	if _updating_ui:
		return

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

	var dict_key: String = meta
	_delete_attribute(dict_key)

func _delete_attribute(dict_key: String) -> void:
	if not editor or not editor.tree:
		return
	if not editor.tree.attributes.has(dict_key):
		return

	editor.tree.attributes.erase(dict_key)

	if _current_attr_id == dict_key:
		_current_attr_id = ""
		_show_detail(false)

	editor.set_dirty(true)
	changed.emit()
	attribute_removed.emit(dict_key)
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

	var desired: String = Bayterek.to_snake_case(new_text)

	# --- Empty name: keep placeholder state. ---
	if desired.is_empty():
		attr.id = desired
		_detail_id_label.text = "(waiting for a name...)"
		_detail_id_label.add_theme_color_override("font_color", COLOR_ID_OK)
		_detail_id_label.tooltip_text = ""
		_update_list_item(_current_attr_id, attr, false)
		editor.set_dirty(true)
		changed.emit()
		attribute_changed.emit(_current_attr_id)
		return

	# --- attr.id ALWAYS mirrors the desired id, even on conflict. ---
	attr.id = desired
	_detail_id_label.text = desired

	var conflict: bool = _id_conflicts(desired)
	var old_key: String = _current_attr_id

	if conflict:
		_detail_id_label.add_theme_color_override("font_color", COLOR_CONFLICT)
		_detail_id_label.tooltip_text = (
			"An attribute with id '%s' already exists.\n" % desired +
			"Rename to fix, or save the tree to auto-suffix the colliding ids."
		)

		if not _is_temp_key(old_key):
			var new_key: String = _make_temp_key(attr)
			editor.tree.attributes.erase(old_key)
			editor.tree.attributes[new_key] = attr
			_current_attr_id = new_key
	else:
		_detail_id_label.add_theme_color_override("font_color", COLOR_ID_OK)
		_detail_id_label.tooltip_text = ""

		if old_key != desired:
			editor.tree.attributes.erase(old_key)
			editor.tree.attributes[desired] = attr

			if not _is_temp_key(old_key):
				migrate_references(editor.tree, old_key, desired)

			_current_attr_id = desired

	_update_list_item(_current_attr_id, attr, conflict)

	editor.set_dirty(true)
	changed.emit()
	attribute_changed.emit(_current_attr_id)

func _update_list_item(dict_key: String, attr: BayterekAttribute, conflict: bool) -> void:
	if not _id_to_item.has(dict_key):
		call_deferred("_refresh")
		return

	var item: TreeItem = _id_to_item[dict_key]
	if not item:
		return

	var prefix: String = "💰 " if attr.is_currency else ""
	item.set_text(0, "%s%s" % [prefix, attr.get_display_name()])
	item.set_text(1, attr.id)

	var name_color: Color = COLOR_CONFLICT if conflict else COLOR_NAME_IN_LIST
	var id_color: Color = COLOR_CONFLICT if conflict else COLOR_ID_IN_LIST
	item.set_custom_color(0, name_color)
	item.set_custom_color(1, id_color)

	var tip: String = "ID: %s" % attr.id
	if not attr.name_key.is_empty():
		tip += "\nName Key: %s" % attr.name_key
	if not attr.is_currency:
		tip += "\nOperation: %s" % BayterekAttribute.operation_label(attr.operation)
	if is_cumulative_available(attr) and attr.cumulative:
		tip += "\nMode: Cumulative (levels stack)"
	if not attr.effect_key.is_empty():
		tip += "\nEffect Key: %s" % attr.effect_key
	if conflict:
		tip += "\n[!] Conflicts with another attribute — rename or save to auto-suffix."
	item.set_tooltip_text(0, tip)
	item.set_tooltip_text(1, tip)

func _on_name_key_changed(new_text: String) -> void:
	if _updating_ui or _current_attr_id.is_empty():
		return
	if not editor or not editor.tree:
		return
	var attr: BayterekAttribute = editor.tree.attributes.get(_current_attr_id, null)
	if not attr:
		return
	attr.name_key = new_text.strip_edges()
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

func _on_effect_key_changed(new_text: String) -> void:
	if _updating_ui or _current_attr_id.is_empty():
		return
	if not editor or not editor.tree:
		return
	var attr: BayterekAttribute = editor.tree.attributes.get(_current_attr_id, null)
	if not attr:
		return
	attr.effect_key = new_text.strip_edges()
	editor.set_dirty(true)
	changed.emit()
	attribute_changed.emit(_current_attr_id)

func _on_is_currency_toggled(pressed: bool) -> void:
	if _updating_ui or _current_attr_id.is_empty():
		return
	if not editor or not editor.tree:
		return
	var attr: BayterekAttribute = editor.tree.attributes.get(_current_attr_id, null)
	if not attr:
		return

	attr.is_currency = pressed
	attr.sync_value_count()
	_update_currency_ui_state(attr)

	if _id_to_item.has(_current_attr_id):
		var item: TreeItem = _id_to_item[_current_attr_id]
		if item:
			var prefix: String = "💰 " if attr.is_currency else ""
			item.set_text(0, "%s%s" % [prefix, attr.get_display_name()])

	editor.set_dirty(true)
	changed.emit()
	attribute_changed.emit(_current_attr_id)

func _on_refund_differs_toggled(pressed: bool) -> void:
	if _updating_ui or _current_attr_id.is_empty():
		return
	if not editor or not editor.tree:
		return
	var attr: BayterekAttribute = editor.tree.attributes.get(_current_attr_id, null)
	if not attr:
		return
	if not attr.is_currency:
		return

	attr.refund_differs = pressed
	attr.sync_value_count()
	_update_currency_ui_state(attr)

	editor.set_dirty(true)
	changed.emit()
	attribute_changed.emit(_current_attr_id)

func _on_cumulative_toggled(pressed: bool) -> void:
	if _updating_ui or _current_attr_id.is_empty():
		return
	if not editor or not editor.tree:
		return
	var attr: BayterekAttribute = editor.tree.attributes.get(_current_attr_id, null)
	if not attr:
		return
	if not is_cumulative_available(attr):
		if _cumulative_check:
			_cumulative_check.button_pressed = false
		return

	attr.cumulative = pressed

	if _id_to_item.has(_current_attr_id):
		_update_list_item(_current_attr_id, attr, _attribute_has_conflict(attr))

	editor.set_dirty(true)
	changed.emit()
	attribute_changed.emit(_current_attr_id)

func _on_operation_changed(index: int) -> void:
	if _updating_ui or _current_attr_id.is_empty():
		return
	if not editor or not editor.tree:
		return
	var attr: BayterekAttribute = editor.tree.attributes.get(_current_attr_id, null)
	if not attr:
		return
	if attr.is_currency:
		return

	var item_id = _operation_dropdown.get_item_id(index)
	if typeof(item_id) != TYPE_INT:
		return

	var new_op: int = int(item_id)
	if not new_op in [
		int(BayterekAttribute.Operation.ADD),
		int(BayterekAttribute.Operation.SUBTRACT),
		int(BayterekAttribute.Operation.SET),
		int(BayterekAttribute.Operation.MULTIPLY),
		int(BayterekAttribute.Operation.MIN),
		int(BayterekAttribute.Operation.MAX),
	]:
		return

	var old_op: int = int(attr.operation)
	if old_op == new_op:
		return

	attr.operation = new_op as BayterekAttribute.Operation

	if not is_cumulative_available(attr) and attr.cumulative:
		attr.cumulative = false
		if _cumulative_check:
			_cumulative_check.button_pressed = false

	_update_currency_ui_state(attr)

	if _id_to_item.has(_current_attr_id):
		_update_list_item(_current_attr_id, attr, _attribute_has_conflict(attr))

	editor.set_dirty(true)
	changed.emit()
	attribute_changed.emit(_current_attr_id)

func _on_icon_changed(path: String) -> void:
	if _updating_ui or _current_attr_id.is_empty():
		return
	if not editor or not editor.tree:
		return
	var attr: BayterekAttribute = editor.tree.attributes.get(_current_attr_id, null)
	if not attr:
		return
	if not attr.is_currency:
		return
	if path.is_empty():
		return

	var tex: Texture2D = load(path) as Texture2D
	if not tex:
		return

	attr.icon = tex
	if _icon_input:
		_icon_input.set_texture(tex)

	editor.set_dirty(true)
	changed.emit()
	attribute_changed.emit(_current_attr_id)

func _on_icon_cleared() -> void:
	if _updating_ui or _current_attr_id.is_empty():
		return
	if not editor or not editor.tree:
		return
	var attr: BayterekAttribute = editor.tree.attributes.get(_current_attr_id, null)
	if not attr:
		return
	if not attr.is_currency:
		return

	attr.icon = null
	if _icon_input:
		_icon_input.set_texture(null)

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
	if attr.is_currency:
		return

	var old_count: int = attr.value_count
	var new_count: int = int(value)
	if old_count == new_count:
		return

	var node_count: int = 0
	for node_data in editor.tree.nodes:
		if node_data and node_data.attributes.has(_current_attr_id):
			node_count += 1

	var prefab_count: int = 0
	for prefab in editor.tree.prefabs:
		if prefab and prefab.attributes.has(_current_attr_id):
			prefab_count += 1

	if node_count == 0 and prefab_count == 0:
		_apply_value_count_change(_current_attr_id, old_count, new_count)
		return

	_confirm_value_count_change(_current_attr_id, old_count, new_count, node_count, prefab_count)

func _apply_value_count_change(attr_id: String, old_count: int, new_count: int) -> void:
	if not editor or not editor.tree:
		return
	var attr: BayterekAttribute = editor.tree.attributes.get(attr_id, null)
	if not attr:
		return

	var do_callable := func():
		_do_set_value_count(attr_id, new_count)
	var undo_callable := func():
		_do_set_value_count(attr_id, old_count)

	if editor.undo_redo:
		editor.undo_redo.create_action("Change Attribute Value Count")
		editor.undo_redo.add_do_method(do_callable)
		editor.undo_redo.add_undo_method(undo_callable)
		editor.undo_redo.commit_action()
	else:
		do_callable.call()

func _do_set_value_count(attr_id: String, new_count: int) -> void:
	if not editor or not editor.tree:
		return
	var attr: BayterekAttribute = editor.tree.attributes.get(attr_id, null)
	if not attr:
		return

	attr.value_count = new_count
	_resize_nodes_arrays(attr_id, new_count)

	if _current_attr_id == attr_id:
		_updating_ui = true
		_value_count_input.set_value_no_signal(new_count)
		_updating_ui = false

	editor.set_dirty(true)
	changed.emit()
	attribute_changed.emit(attr_id)

func _confirm_value_count_change(attr_id: String, old_count: int, new_count: int, node_count: int, prefab_count: int) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Change Value Count"
	dialog.dialog_text = (
		"Changing value count from %d to %d will affect:\n\n" % [old_count, new_count] +
		"  • %d node(s)\n" % node_count +
		"  • %d prefab(s)\n\n" % prefab_count +
		"Existing values will be kept where possible; new slots default to 0.\n\nContinue?"
	)
	dialog.ok_button_text = "Change"
	dialog.cancel_button_text = "Cancel"
	dialog.unresizable = true

	dialog.confirmed.connect(func() -> void:
		_apply_value_count_change(attr_id, old_count, new_count)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		_updating_ui = true
		_value_count_input.set_value_no_signal(old_count)
		_updating_ui = false
		dialog.queue_free()
	)
	dialog.close_requested.connect(func() -> void:
		_updating_ui = true
		_value_count_input.set_value_no_signal(old_count)
		_updating_ui = false
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered(Vector2i(440, 240))

# ============================================================
# ARRAY RESIZE HELPERS
# ============================================================

func _resize_nodes_arrays(attr_id: String, new_count: int) -> void:
	if not editor or not editor.tree:
		return

	for node_data in editor.tree.nodes:
		if not node_data.attributes.has(attr_id):
			continue
		var values = node_data.attributes[attr_id]
		_resize_value_array(values, new_count)

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