@tool
class_name BayterekLocalizationEditor
extends MarginContainer
## Editor tab — key sidebar + Excel-like key table.

const Localization = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization.gd")
const Service = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization_service.gd")
const KeyRow = preload("res://addons/bayterek_localization/scripts/editor/ui/bayterek_localization_key_row.gd")

const SIDEBAR_EXPANDED := 220
const SIDEBAR_COLLAPSED := 28

var current_locale: String = ""
var original_locale: String = ""
var is_original_locale: bool = false

var translations: Dictionary = {}
var originals: Dictionary = {}
var dirty: bool = false

var _rows_by_key: Dictionary = {}

var _h_split: HSplitContainer
var _sidebar_root: VBoxContainer
var _sidebar_header: HBoxContainer
var _sidebar_toggle_btn: Button
var _sidebar_title: Label
var _sidebar_content: VBoxContainer
var _sidebar_search: LineEdit
var _sidebar_list: ItemList

var _toolbar: HBoxContainer
var _save_btn: Button
var _add_key_btn: Button
var _delete_key_btn: Button
var _search_input: LineEdit
var _missing_label: Label
var _locale_label: Label

var _main_panel: VBoxContainer
var _rows_scroll: ScrollContainer
var _rows_container: VBoxContainer
var _empty_label: Label

var _sidebar_collapsed: bool = false
var _suppress_sidebar_signal: bool = false

func _ready() -> void:
	add_theme_constant_override("margin_left", 4)
	add_theme_constant_override("margin_top", 4)
	add_theme_constant_override("margin_right", 4)
	add_theme_constant_override("margin_bottom", 4)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL

func init() -> void:
	_build_ui()
	_show_empty()
	print("[BayterekLocalizationEditor] ready.")

# ============================================================
# UI BUILD
# ============================================================

func _build_ui() -> void:
	if _h_split:
		return

	_h_split = HSplitContainer.new()
	_h_split.name = "HSplit"
	_h_split.size_flags_horizontal = SIZE_EXPAND_FILL
	_h_split.size_flags_vertical = SIZE_EXPAND_FILL
	_h_split.split_offset = SIDEBAR_EXPANDED
	add_child(_h_split)

	_build_sidebar()
	_build_main_panel()

func _build_sidebar() -> void:
	_sidebar_root = VBoxContainer.new()
	_sidebar_root.name = "SidebarRoot"
	_sidebar_root.custom_minimum_size = Vector2(SIDEBAR_COLLAPSED, 0)
	_sidebar_root.size_flags_vertical = SIZE_EXPAND_FILL
	_sidebar_root.add_theme_constant_override("separation", 2)
	_h_split.add_child(_sidebar_root)

	_sidebar_header = HBoxContainer.new()
	_sidebar_header.name = "SidebarHeader"
	_sidebar_header.add_theme_constant_override("separation", 2)
	_sidebar_root.add_child(_sidebar_header)

	_sidebar_toggle_btn = Button.new()
	_sidebar_toggle_btn.name = "SidebarToggle"
	_sidebar_toggle_btn.text = "◀"
	_sidebar_toggle_btn.tooltip_text = "Collapse / expand key list"
	_sidebar_toggle_btn.custom_minimum_size = Vector2(24, 24)
	_sidebar_toggle_btn.flat = true
	_sidebar_toggle_btn.pressed.connect(_on_sidebar_toggle)
	_sidebar_header.add_child(_sidebar_toggle_btn)

	_sidebar_title = Label.new()
	_sidebar_title.name = "SidebarTitle"
	_sidebar_title.text = "Keys"
	_sidebar_title.size_flags_horizontal = SIZE_EXPAND_FILL
	_sidebar_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_sidebar_header.add_child(_sidebar_title)

	_sidebar_content = VBoxContainer.new()
	_sidebar_content.name = "SidebarContent"
	_sidebar_content.size_flags_vertical = SIZE_EXPAND_FILL
	_sidebar_content.add_theme_constant_override("separation", 2)
	_sidebar_root.add_child(_sidebar_content)

	_sidebar_search = LineEdit.new()
	_sidebar_search.name = "SidebarSearch"
	_sidebar_search.placeholder_text = "Filter keys"
	_sidebar_search.clear_button_enabled = true
	_sidebar_search.text_changed.connect(_on_sidebar_search_changed)
	_sidebar_content.add_child(_sidebar_search)

	_sidebar_list = ItemList.new()
	_sidebar_list.name = "SidebarList"
	_sidebar_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_sidebar_list.size_flags_vertical = SIZE_EXPAND_FILL
	_sidebar_list.select_mode = ItemList.SELECT_SINGLE
	_sidebar_list.item_selected.connect(_on_sidebar_item_selected)
	_sidebar_content.add_child(_sidebar_list)

func _build_main_panel() -> void:
	_main_panel = VBoxContainer.new()
	_main_panel.name = "MainPanel"
	_main_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	_main_panel.size_flags_vertical = SIZE_EXPAND_FILL
	_main_panel.add_theme_constant_override("separation", 4)
	_h_split.add_child(_main_panel)

	_toolbar = HBoxContainer.new()
	_toolbar.name = "Toolbar"
	_toolbar.add_theme_constant_override("separation", 6)
	_main_panel.add_child(_toolbar)

	_locale_label = Label.new()
	_locale_label.name = "LocaleLabel"
	_locale_label.text = "—"
	_locale_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_locale_label.custom_minimum_size.x = 180
	_toolbar.add_child(_locale_label)

	_toolbar.add_child(VSeparator.new())

	_save_btn = Button.new()
	_save_btn.name = "SaveButton"
	_save_btn.text = "Save"
	_save_btn.tooltip_text = "Save changes (Ctrl+S)"
	_save_btn.pressed.connect(_on_save_pressed)
	_toolbar.add_child(_save_btn)

	_add_key_btn = Button.new()
	_add_key_btn.name = "AddKeyButton"
	_add_key_btn.text = "+ Add Key"
	_add_key_btn.tooltip_text = "Add new key (only original locale)"
	_add_key_btn.pressed.connect(_on_add_key_pressed)
	_toolbar.add_child(_add_key_btn)

	_delete_key_btn = Button.new()
	_delete_key_btn.name = "DeleteKeyButton"
	_delete_key_btn.text = "Delete Key"
	_delete_key_btn.tooltip_text = "Delete selected key (only original locale)"
	_delete_key_btn.pressed.connect(_on_delete_key_pressed)
	_toolbar.add_child(_delete_key_btn)

	_toolbar.add_child(VSeparator.new())

	_search_input = LineEdit.new()
	_search_input.name = "SearchInput"
	_search_input.placeholder_text = "Search key or value"
	_search_input.clear_button_enabled = true
	_search_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_search_input.text_changed.connect(_on_search_changed)
	_toolbar.add_child(_search_input)

	_missing_label = Label.new()
	_missing_label.name = "MissingLabel"
	_missing_label.text = "0 missing"
	_missing_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
	_toolbar.add_child(_missing_label)

	var header := HBoxContainer.new()
	header.name = "ColumnHeader"
	header.add_theme_constant_override("separation", 4)
	header.custom_minimum_size.y = 24
	_main_panel.add_child(header)

	var h_key := Label.new()
	h_key.text = "Key"
	h_key.custom_minimum_size.x = BayterekLocalizationKeyRow.KEY_COLUMN_WIDTH
	h_key.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	header.add_child(h_key)

	var h_orig := Label.new()
	h_orig.text = "Original"
	h_orig.size_flags_horizontal = SIZE_EXPAND_FILL
	h_orig.size_flags_stretch_ratio = 1.0
	h_orig.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	header.add_child(h_orig)

	var h_trans := Label.new()
	h_trans.text = "Translation"
	h_trans.size_flags_horizontal = SIZE_EXPAND_FILL
	h_trans.size_flags_stretch_ratio = 1.0
	h_trans.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	header.add_child(h_trans)

	_rows_scroll = ScrollContainer.new()
	_rows_scroll.name = "RowsScroll"
	_rows_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	_rows_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_main_panel.add_child(_rows_scroll)

	_rows_container = VBoxContainer.new()
	_rows_container.name = "RowsContainer"
	_rows_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_rows_container.add_theme_constant_override("separation", 1)
	_rows_scroll.add_child(_rows_container)

	_empty_label = Label.new()
	_empty_label.name = "EmptyLabel"
	_empty_label.text = "Double-click a region in the Browser tab to open its translation editor."
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	_main_panel.add_child(_empty_label)
	_empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_empty_label.visible = false

# ============================================================
# PUBLIC API
# ============================================================

func open_locale(locale: String) -> void:
	if locale.is_empty():
		return

	var loader: Node = get_node_or_null("/root/BayterekLocalizationLoader")
	if not loader:
		return
	var registry: LocalizationRegistry = loader.call("get_registry")
	if not registry:
		return

	current_locale = locale
	original_locale = registry.original_locale
	is_original_locale = (locale == original_locale)

	originals.clear()
	if not original_locale.is_empty():
		var orig_path: String = Service.get_locale_file_path(original_locale)
		originals = Service.read_json(orig_path)

	translations.clear()
	var trans_path: String = Service.get_locale_file_path(locale)
	translations = Service.read_json(trans_path)

	if is_original_locale:
		translations = originals.duplicate()

	dirty = false

	_rebuild_rows()
	_update_ui_state()
	_update_missing_count()
	_show_rows()

	print("[BayterekLocalizationEditor] opened locale: %s (original=%s, is_original=%s, %d keys)" % [
		locale, original_locale, str(is_original_locale), translations.size()
	])

# ============================================================
# ROW REBUILD
# ============================================================

func _rebuild_rows() -> void:
	_clear_rows()
	_rows_by_key.clear()

	var all_keys: Dictionary = {}
	for k in originals.keys():
		all_keys[k] = true
	for k in translations.keys():
		all_keys[k] = true

	var sorted_keys: Array = all_keys.keys()
	sorted_keys.sort()

	for key in sorted_keys:
		var orig_val: String = originals.get(key, "")
		var trans_val: String = translations.get(key, "")
		_add_row(key, orig_val, trans_val)

	_refresh_sidebar()

func _add_row(key: String, orig_val: String, trans_val: String) -> void:
	var row := KeyRow.new()
	row.name = "Row_%s" % key
	_rows_container.add_child(row)
	row.setup(key, orig_val, trans_val, is_original_locale)
	row.value_changed.connect(_on_row_value_changed)
	row.row_selected.connect(_on_row_selected)
	row.navigate_requested.connect(_on_row_navigate_requested)
	_rows_by_key[key] = row

func _clear_rows() -> void:
	for child in _rows_container.get_children():
		child.queue_free()
	_rows_by_key.clear()

# ============================================================
# UI STATE
# ============================================================

func _update_ui_state() -> void:
	_locale_label.text = "Locale: %s" % current_locale
	if is_original_locale:
		_locale_label.text += "  ★ original"

	_add_key_btn.disabled = not is_original_locale
	_delete_key_btn.disabled = not is_original_locale
	_save_btn.disabled = not dirty

func _show_empty() -> void:
	if _empty_label:
		_empty_label.visible = true
	if _rows_scroll:
		_rows_scroll.visible = false
	if _sidebar_list:
		_sidebar_list.clear()

func _show_rows() -> void:
	if _empty_label:
		_empty_label.visible = false
	if _rows_scroll:
		_rows_scroll.visible = true

# ============================================================
# SIDEBAR COLLAPSE
# ============================================================

func _refresh_sidebar() -> void:
	_sidebar_list.clear()
	var keys: Array = _rows_by_key.keys()
	keys.sort()
	for key in keys:
		_sidebar_list.add_item(key)

func _on_sidebar_toggle() -> void:
	_sidebar_collapsed = not _sidebar_collapsed

	_sidebar_content.visible = not _sidebar_collapsed
	_sidebar_title.visible = not _sidebar_collapsed

	if _sidebar_collapsed:
		_sidebar_root.custom_minimum_size.x = SIDEBAR_COLLAPSED
		_sidebar_toggle_btn.text = "▶"
		_h_split.split_offset = SIDEBAR_COLLAPSED
	else:
		_sidebar_root.custom_minimum_size.x = SIDEBAR_EXPANDED
		_sidebar_toggle_btn.text = "◀"
		_h_split.split_offset = SIDEBAR_EXPANDED

	_h_split.queue_sort()

func _on_sidebar_item_selected(index: int) -> void:
	if _suppress_sidebar_signal:
		return
	var key: String = _sidebar_list.get_item_text(index)
	_scroll_to_row(key)

func _on_sidebar_search_changed(_new_text: String) -> void:
	_apply_filter()

# ============================================================
# SEARCH / FILTER
# ============================================================

func _on_search_changed(_new_text: String) -> void:
	_apply_filter()

func _apply_filter() -> void:
	var q: String = ""
	if _search_input:
		q = _search_input.text.strip_edges().to_lower()

	var sq: String = ""
	if _sidebar_search:
		sq = _sidebar_search.text.strip_edges().to_lower()

	for key in _rows_by_key.keys():
		var row: BayterekLocalizationKeyRow = _rows_by_key[key]
		if not is_instance_valid(row):
			continue

		var matches: bool = q.is_empty()
		if not matches:
			matches = key.to_lower().find(q) != -1
		if not matches:
			matches = row.original_value.to_lower().find(q) != -1
		if not matches:
			matches = row.get_translation().to_lower().find(q) != -1

		row.visible = matches

	for i in _sidebar_list.item_count:
		var key_text: String = _sidebar_list.get_item_text(i)
		var matches_sidebar: bool = sq.is_empty() or key_text.to_lower().find(sq) != -1
		_sidebar_list.set_item_disabled(i, not matches_sidebar)

# ============================================================
# ROW INTERACTION
# ============================================================

func _on_row_value_changed(key: String, new_value: String) -> void:
	translations[key] = new_value
	_set_dirty(true)
	_update_missing_count()

func _on_row_selected(key: String) -> void:
	for i in _sidebar_list.item_count:
		if _sidebar_list.get_item_text(i) == key:
			_suppress_sidebar_signal = true
			_sidebar_list.select(i)
			_suppress_sidebar_signal = false
			break

func _scroll_to_row(key: String) -> void:
	if not _rows_by_key.has(key):
		return
	var row: BayterekLocalizationKeyRow = _rows_by_key[key]
	if not is_instance_valid(row):
		return

	_rows_scroll.ensure_control_visible(row)

	for k in _rows_by_key.keys():
		var r: BayterekLocalizationKeyRow = _rows_by_key[k]
		if is_instance_valid(r):
			r.set_row_selected(k == key)

func _on_row_navigate_requested(key: String, direction: int) -> void:
	if direction == 0:
		return

	var visible_keys: Array = []
	var sorted: Array = _rows_by_key.keys()
	sorted.sort()
	for k in sorted:
		var r: BayterekLocalizationKeyRow = _rows_by_key[k]
		if is_instance_valid(r) and r.visible:
			visible_keys.append(k)

	if visible_keys.is_empty():
		return

	var idx: int = visible_keys.find(key)
	if idx == -1:
		return

	var next_idx: int = idx + direction
	if next_idx < 0 or next_idx >= visible_keys.size():
		return

	var next_key: String = visible_keys[next_idx]
	_scroll_to_row(next_key)

	var next_row: BayterekLocalizationKeyRow = _rows_by_key[next_key]
	if is_instance_valid(next_row):
		next_row.focus_translation()

# ============================================================
# ADD / DELETE KEY
# ============================================================

func _on_add_key_pressed() -> void:
	if not is_original_locale:
		return

	var dialog := ConfirmationDialog.new()
	dialog.name = "AddKeyDialog"
	dialog.title = "Add Key"
	dialog.ok_button_text = "Add"
	dialog.cancel_button_text = "Cancel"
	dialog.dialog_text = ""
	dialog.min_size = Vector2i.ZERO
	dialog.unresizable = true

	var vbox := VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.custom_minimum_size = Vector2(360, 60)
	vbox.add_theme_constant_override("separation", 8)
	dialog.add_child(vbox)

	var label := Label.new()
	label.text = "Key name:"
	vbox.add_child(label)

	var key_input := LineEdit.new()
	key_input.placeholder_text = "e.g. menu_play"
	key_input.custom_minimum_size = Vector2(340, 0)
	vbox.add_child(key_input)

	var err_label := Label.new()
	err_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	err_label.visible = false
	vbox.add_child(err_label)

	dialog.confirmed.connect(func():
		var new_key: String = key_input.text.strip_edges()
		if new_key.is_empty():
			err_label.text = "Key cannot be empty."
			err_label.visible = true
			return
		if originals.has(new_key) or translations.has(new_key):
			err_label.text = "Key already exists."
			err_label.visible = true
			return

		originals[new_key] = ""
		translations[new_key] = ""
		_add_row(new_key, "", "")
		_refresh_sidebar()
		_set_dirty(true)
		_update_missing_count()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())

	add_child(dialog)
	dialog.reset_size()
	dialog.size = Vector2i(400, 180)
	dialog.popup_centered()

	key_input.call_deferred("grab_focus")

func _on_delete_key_pressed() -> void:
	if not is_original_locale:
		return

	var selected_key: String = ""
	var sel_items: PackedInt32Array = _sidebar_list.get_selected_items()
	if sel_items.size() > 0:
		selected_key = _sidebar_list.get_item_text(sel_items[0])

	if selected_key.is_empty():
		push_warning("[Editor] No key selected for deletion.")
		return

	var dialog := ConfirmationDialog.new()
	dialog.name = "DeleteKeyDialog"
	dialog.title = "Delete Key"
	dialog.ok_button_text = "Delete"
	dialog.cancel_button_text = "Cancel"
	dialog.dialog_text = ""
	dialog.min_size = Vector2i.ZERO
	dialog.unresizable = true

	var vbox := VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.custom_minimum_size = Vector2(400, 60)
	vbox.add_theme_constant_override("separation", 10)
	dialog.add_child(vbox)

	var info := Label.new()
	info.text = "Delete key \"%s\"?\nThis will remove it from the original file." % selected_key
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(400, 0)
	vbox.add_child(info)

	dialog.confirmed.connect(func():
		originals.erase(selected_key)
		translations.erase(selected_key)

		if _rows_by_key.has(selected_key):
			var row: BayterekLocalizationKeyRow = _rows_by_key[selected_key]
			if is_instance_valid(row):
				row.queue_free()
			_rows_by_key.erase(selected_key)

		_refresh_sidebar()
		_set_dirty(true)
		_update_missing_count()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())

	add_child(dialog)
	dialog.reset_size()
	dialog.size = Vector2i(440, 180)
	dialog.popup_centered()

# ============================================================
# SAVE
# ============================================================

func _on_save_pressed() -> void:
	if current_locale.is_empty():
		return

	var data: Dictionary = {}
	for k in translations.keys():
		data[k] = translations[k]

	var path: String = Service.get_locale_file_path(current_locale)
	var err: Error = Service.write_json(path, data)
	if err != OK:
		push_error("[Editor] Save failed: %s (err=%d)" % [path, err])
		return

	if is_original_locale:
		originals = translations.duplicate()

	_set_dirty(false)
	EditorInterface.get_resource_filesystem().scan()
	print("[BayterekLocalizationEditor] saved %s (%d keys)" % [current_locale, data.size()])

# ============================================================
# DIRTY / MISSING
# ============================================================

func _set_dirty(value: bool) -> void:
	dirty = value
	if _save_btn:
		_save_btn.disabled = not dirty

func _update_missing_count() -> void:
	if is_original_locale:
		_missing_label.text = "%d keys" % translations.size()
		return

	var missing: int = 0
	for key in _rows_by_key.keys():
		var row: BayterekLocalizationKeyRow = _rows_by_key[key]
		if not is_instance_valid(row):
			continue
		var t: String = row.get_translation().strip_edges()
		if t.is_empty() or t == row.original_value:
			missing += 1

	_missing_label.text = "%d missing" % missing

# ============================================================
# KEYBOARD
# ============================================================

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	var key: int = event.keycode
	var ctrl: bool = event.ctrl_pressed or event.meta_pressed

	if ctrl and key == KEY_S:
		if dirty:
			_on_save_pressed()
		get_viewport().set_input_as_handled()
		return

	if key == KEY_UP or key == KEY_DOWN:
		var dir: int = -1 if key == KEY_UP else 1
		_navigate_from_focused(dir)
		get_viewport().set_input_as_handled()
		return

func _navigate_from_focused(direction: int) -> void:
	var current_key: String = ""
	for k in _rows_by_key.keys():
		var r: BayterekLocalizationKeyRow = _rows_by_key[k]
		if is_instance_valid(r) and r.has_field_focus():
			current_key = k
			break

	if current_key.is_empty():
		var sorted: Array = _rows_by_key.keys()
		sorted.sort()
		for k in sorted:
			var r: BayterekLocalizationKeyRow = _rows_by_key[k]
			if is_instance_valid(r) and r.visible:
				_scroll_to_row(k)
				r.focus_translation()
				return
		return

	_on_row_navigate_requested(current_key, direction)