@tool
class_name BayterekLocalizationEditor
extends MarginContainer
## Editor tab — sidebar + key table + preview panel.
## DEBUG BUILD — TextEdit caret sorununu tespit için bol print.

const Localization = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization.gd")
const Service = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization_service.gd")
const Format = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization_format_string.gd")
const KeyRow = preload("res://addons/bayterek_localization/scripts/editor/ui/bayterek_localization_key_row.gd")
const PreviewPanel = preload("res://addons/bayterek_localization/scripts/editor/ui/bayterek_localization_preview_panel.gd")
const ImportExportDialog = preload("res://addons/bayterek_localization/scripts/editor/bayterek_localization_import_export_dialog.gd")
const UndoHelper = preload("res://addons/bayterek_localization/scripts/editor/bayterek_localization_undo_helper.gd")

const SIDEBAR_EXPANDED := 240
const SIDEBAR_COLLAPSED := 28
const PREVIEW_EXPANDED := 280
const PREVIEW_COLLAPSED := 28

var current_locale: String = ""
var original_locale: String = ""
var is_original_locale: bool = false

var translations: Dictionary = {}
var originals: Dictionary = {}
var dirty: bool = false

var _rows_by_key: Dictionary = {}

var _h_split: HSplitContainer
var _inner_split: HBoxContainer

var _sidebar_root: VBoxContainer
var _sidebar_header: HBoxContainer
var _sidebar_toggle_btn: Button
var _sidebar_title: Label
var _sidebar_content: VBoxContainer
var _sidebar_search: LineEdit
var _sidebar_list: ItemList

var _main_panel: VBoxContainer
var _toolbar: HBoxContainer
var _save_btn: Button
var _add_key_btn: Button
var _delete_key_btn: Button
var _import_btn: Button
var _export_btn: Button
var _search_input: LineEdit
var _missing_label: Label
var _locale_label: Label
var _rows_scroll: ScrollContainer
var _rows_container: VBoxContainer
var _empty_label: Label
var _h_key: Label
var _h_orig: Label
var _h_trans: Label

var _preview_root: VBoxContainer
var _preview_panel: BayterekLocalizationPreviewPanel
var _preview_toggle_btn: Button
var _preview_title: Label

var _csv_dialog: BayterekLocalizationImportExportDialog

var _sidebar_collapsed: bool = false
var _preview_collapsed: bool = false
var _suppress_sidebar_signal: bool = false
var _selected_key: String = ""

var _key_refs_cache: Dictionary = {}
var _undo_helper: BayterekLocalizationUndoHelper
var _field_edit_old_value: Dictionary = {}

# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	add_theme_constant_override("margin_left", 4)
	add_theme_constant_override("margin_top", 4)
	add_theme_constant_override("margin_right", 4)
	add_theme_constant_override("margin_bottom", 4)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL

func init() -> void:
	_build_ui()
	_undo_helper = UndoHelper.new(self)
	_show_empty()
	print("[BayterekLocalizationEditor] ready.")

# ============================================================
# UI BUILD
# ============================================================

func _build_ui() -> void:
	if _h_split:
		return

	_h_split = HSplitContainer.new()
	_h_split.name = "OuterSplit"
	_h_split.size_flags_horizontal = SIZE_EXPAND_FILL
	_h_split.size_flags_vertical = SIZE_EXPAND_FILL
	_h_split.split_offset = SIDEBAR_EXPANDED
	add_child(_h_split)

	_build_sidebar()
	_build_inner_split()

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

func _build_inner_split() -> void:
	_inner_split = HBoxContainer.new()
	_inner_split.name = "InnerSplit"
	_inner_split.size_flags_horizontal = SIZE_EXPAND_FILL
	_inner_split.size_flags_vertical = SIZE_EXPAND_FILL
	_inner_split.add_theme_constant_override("separation", 0)
	_h_split.add_child(_inner_split)

	_build_main_panel()
	_build_preview_panel()

func _build_main_panel() -> void:
	_main_panel = VBoxContainer.new()
	_main_panel.name = "MainPanel"
	_main_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	_main_panel.size_flags_vertical = SIZE_EXPAND_FILL
	_main_panel.add_theme_constant_override("separation", 4)
	_inner_split.add_child(_main_panel)

	_toolbar = HBoxContainer.new()
	_toolbar.name = "Toolbar"
	_toolbar.add_theme_constant_override("separation", 6)
	_main_panel.add_child(_toolbar)

	_locale_label = Label.new()
	_locale_label.name = "LocaleLabel"
	_locale_label.text = "—"
	_locale_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_locale_label.custom_minimum_size.x = 160
	_toolbar.add_child(_locale_label)

	_toolbar.add_child(VSeparator.new())

	_save_btn = Button.new()
	_save_btn.name = "SaveButton"
	_save_btn.text = "Save"
	_save_btn.pressed.connect(_on_save_pressed)
	_toolbar.add_child(_save_btn)

	_add_key_btn = Button.new()
	_add_key_btn.name = "AddKeyButton"
	_add_key_btn.text = "+ Add Key"
	_add_key_btn.pressed.connect(_on_add_key_pressed)
	_toolbar.add_child(_add_key_btn)

	_delete_key_btn = Button.new()
	_delete_key_btn.name = "DeleteKeyButton"
	_delete_key_btn.text = "Delete Key"
	_delete_key_btn.pressed.connect(_on_delete_key_pressed)
	_toolbar.add_child(_delete_key_btn)

	_toolbar.add_child(VSeparator.new())

	_import_btn = Button.new()
	_import_btn.name = "ImportButton"
	_import_btn.text = "Import CSV"
	_import_btn.tooltip_text = "Import translations from a CSV file"
	_import_btn.pressed.connect(_on_import_pressed)
	_toolbar.add_child(_import_btn)

	_export_btn = Button.new()
	_export_btn.name = "ExportButton"
	_export_btn.text = "Export CSV"
	_export_btn.tooltip_text = "Export all locales to a CSV file"
	_export_btn.pressed.connect(_on_export_pressed)
	_toolbar.add_child(_export_btn)

	_toolbar.add_child(VSeparator.new())

	_search_input = LineEdit.new()
	_search_input.name = "SearchInput"
	_search_input.placeholder_text = "Search key or value"
	_search_input.clear_button_enabled = true
	_search_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_search_input.custom_minimum_size.x = 140
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

	_h_key = Label.new()
	_h_key.text = "Key"
	_h_key.custom_minimum_size.x = BayterekLocalizationKeyRow.KEY_COLUMN_WIDTH
	_h_key.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	header.add_child(_h_key)

	_h_orig = Label.new()
	_h_orig.text = "Original"
	_h_orig.size_flags_horizontal = SIZE_EXPAND_FILL
	_h_orig.size_flags_stretch_ratio = 1.0
	_h_orig.custom_minimum_size.x = BayterekLocalizationKeyRow.MIN_ORIGINAL_COL
	_h_orig.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	header.add_child(_h_orig)

	_h_trans = Label.new()
	_h_trans.text = "Translation"
	_h_trans.size_flags_horizontal = SIZE_EXPAND_FILL
	_h_trans.size_flags_stretch_ratio = 1.0
	_h_trans.custom_minimum_size.x = BayterekLocalizationKeyRow.MIN_TRANSLATION_COL
	_h_trans.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	header.add_child(_h_trans)

	_rows_scroll = ScrollContainer.new()
	_rows_scroll.name = "RowsScroll"
	_rows_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	_rows_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_rows_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
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

func _build_preview_panel() -> void:
	_preview_root = VBoxContainer.new()
	_preview_root.name = "PreviewRoot"
	_preview_root.custom_minimum_size = Vector2(PREVIEW_COLLAPSED, 0)
	_preview_root.size_flags_horizontal = Control.SIZE_FILL
	_preview_root.size_flags_vertical = SIZE_EXPAND_FILL
	_preview_root.add_theme_constant_override("separation", 2)
	_inner_split.add_child(_preview_root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 2)
	_preview_root.add_child(header)

	_preview_toggle_btn = Button.new()
	_preview_toggle_btn.text = "▶"
	_preview_toggle_btn.tooltip_text = "Collapse / expand preview"
	_preview_toggle_btn.custom_minimum_size = Vector2(24, 24)
	_preview_toggle_btn.flat = true
	_preview_toggle_btn.pressed.connect(_on_preview_toggle)
	header.add_child(_preview_toggle_btn)

	_preview_title = Label.new()
	_preview_title.text = "Preview"
	_preview_title.size_flags_horizontal = SIZE_EXPAND_FILL
	_preview_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	header.add_child(_preview_title)

	_preview_panel = PreviewPanel.new()
	_preview_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	_preview_panel.size_flags_vertical = SIZE_EXPAND_FILL
	_preview_panel.set_lookup(_preview_lookup)
	_preview_root.add_child(_preview_panel)

	_preview_toggle_btn.text = "◀"
	_preview_title.visible = false
	_preview_collapsed = true
	_preview_root.custom_minimum_size.x = PREVIEW_COLLAPSED
	_preview_panel.modulate.a = 0.0
	_preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _preview_lookup(key: String) -> String:
	if translations.has(key):
		return String(translations[key])
	if originals.has(key):
		return String(originals[key])
	return ""

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
	_selected_key = ""
	_field_edit_old_value.clear()
	if _undo_helper:
		_undo_helper.reset_batch()
	_preview_panel.clear()

	_rebuild_rows()
	_update_ui_state()
	_update_header_visibility()
	_update_missing_count()
	_show_rows()

	print("[BayterekLocalizationEditor] opened locale: %s (original=%s, is_original=%s, %d keys)" % [
		locale, original_locale, str(is_original_locale), translations.size()
	])

func _update_header_visibility() -> void:
	if not _h_orig or not _h_trans:
		return
	if is_original_locale:
		_h_orig.visible = false
		_h_trans.text = "Value (editable)"
	else:
		_h_orig.visible = true
		_h_trans.text = "Translation"

# ============================================================
# REFERENCE + CYCLE DETECTION
# ============================================================

func _rebuild_refs_cache() -> void:
	_key_refs_cache.clear()
	for key in translations.keys():
		var val: String = String(translations[key])
		var refs: PackedStringArray = Format.extract_key_references(val)
		_key_refs_cache[key] = refs

func _has_broken_reference(key: String) -> bool:
	if not _key_refs_cache.has(key):
		return false
	var refs: PackedStringArray = _key_refs_cache[key]
	for ref in refs:
		if not _lookup_anywhere(ref):
			return true
	return false

func _has_cycle(key: String) -> bool:
	if not _key_refs_cache.has(key):
		return false
	var visiting: Dictionary = {}
	return _dfs_has_cycle(key, visiting)

func _dfs_has_cycle(start: String, visiting: Dictionary) -> bool:
	if visiting.has(start):
		return true
	if not _key_refs_cache.has(start):
		return false
	visiting[start] = true
	var refs: PackedStringArray = _key_refs_cache[start]
	for ref in refs:
		if _dfs_has_cycle(ref, visiting):
			return true
	visiting.erase(start)
	return false

func _get_cycle_path(key: String) -> Array[String]:
	var path: Array[String] = []
	var stack: Array[String] = []
	if _dfs_find_cycle(key, stack, path):
		return path
	return []

func _dfs_find_cycle(node: String, stack: Array[String], out_path: Array[String]) -> bool:
	if stack.has(node):
		var start_idx: int = stack.find(node)
		for i in range(start_idx, stack.size()):
			out_path.append(stack[i])
		out_path.append(node)
		return true

	if not _key_refs_cache.has(node):
		return false

	stack.append(node)
	var refs: PackedStringArray = _key_refs_cache[node]
	for ref in refs:
		if _dfs_find_cycle(ref, stack, out_path):
			return true
	stack.pop_back()
	return false

func _lookup_anywhere(key: String) -> bool:
	return translations.has(key) or originals.has(key)

# ============================================================
# ROW REBUILD
# ============================================================

func _rebuild_rows() -> void:
	_clear_rows()
	_rows_by_key.clear()
	_rebuild_refs_cache()

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
	_update_validation_flags()

func _update_validation_flags() -> void:
	_rebuild_refs_cache()
	for key in _rows_by_key.keys():
		var row: BayterekLocalizationKeyRow = _rows_by_key[key]
		if not is_instance_valid(row):
			continue
		var broken: bool = _has_broken_reference(key)
		var cyclic: bool = _has_cycle(key)
		var cycle_path: Array[String] = []
		if cyclic:
			cycle_path = _get_cycle_path(key)
		row.set_validation_flags(broken, cyclic, cycle_path)

func _add_row(key: String, orig_val: String, trans_val: String) -> void:
	var row := KeyRow.new()
	row.name = "Row_%s" % key
	row.size_flags_horizontal = SIZE_EXPAND_FILL
	_rows_container.add_child(row)
	row.setup(key, orig_val, trans_val, is_original_locale)
	row.value_changed.connect(_on_row_value_changed)
	row.row_selected.connect(_on_row_selected)
	row.navigate_requested.connect(_on_row_navigate_requested)
	row.key_rename_requested.connect(_on_row_key_rename_requested)
	row.value_edit_started.connect(_on_row_value_edit_started)
	row.value_edit_committed.connect(_on_row_value_edit_committed)
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
# SIDEBAR
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

# ============================================================
# PREVIEW PANEL TOGGLE
# ============================================================

func _on_preview_toggle() -> void:
	_preview_collapsed = not _preview_collapsed

	if _preview_collapsed:
		_preview_toggle_btn.text = "◀"
		_preview_title.visible = false
		_preview_root.custom_minimum_size.x = PREVIEW_COLLAPSED
		_preview_panel.modulate.a = 0.0
		_preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		_preview_toggle_btn.text = "▶"
		_preview_title.visible = true
		_preview_root.custom_minimum_size.x = PREVIEW_EXPANDED
		_preview_panel.modulate.a = 1.0
		_preview_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	_inner_split.queue_sort()
	_push_preview_after_layout.call_deferred()

func _push_preview_after_layout() -> void:
	if _selected_key.is_empty():
		return
	await get_tree().process_frame
	if not is_instance_valid(self) or _selected_key.is_empty():
		return
	_update_preview_for(_selected_key)

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

func _on_row_value_edit_started(key: String, current_value: String) -> void:
	print("[EDITOR] _on_row_value_edit_started('", key, "', '", current_value, "')")
	_field_edit_old_value[key] = current_value

func _on_row_value_changed(key: String, new_value: String) -> void:
	print("[EDITOR] _on_row_value_changed('", key, "', '", new_value, "')")

	if _undo_helper and _field_edit_old_value.has(key):
		var old_value: String = _field_edit_old_value[key]
		if old_value != new_value:
			_undo_helper.push_value_change(
				key,
				old_value,
				new_value,
				current_locale,
				_apply_value_from_undo
			)
			_field_edit_old_value[key] = new_value

	translations[key] = new_value
	_set_dirty(true)
	_update_missing_count()
	# YAZMA SIRASINDA VALIDATION VE PREVIEW ÇAĞRILMIYOR.

func _on_row_value_edit_committed(key: String, _new_value: String) -> void:
	print("[EDITOR] _on_row_value_edit_committed('", key, "')")
	_update_validation_flags()
	if key == _selected_key:
		_update_preview_for(key)

func _apply_value_from_undo(key: String, value: String) -> void:
	print("[EDITOR] _apply_value_from_undo('", key, "', '", value, "')")
	if not _rows_by_key.has(key):
		return
	# NOT: row.set_translation() ÇAĞIRMA! Field zaten kullanıcı tarafından
	# güncellendi (kullanıcı yazdı/sildi). Bu callback commit_action()
	# anında HEMEN çalışır, field'a dokunursa caret 0'a atlar.
	# Sadece translations dictionary'sini güncelle.
	translations[key] = value
	_field_edit_old_value[key] = value
	_set_dirty(true)
	_update_missing_count()
	_update_validation_flags()
	if key == _selected_key:
		_update_preview_for(key)

func _on_row_selected(key: String) -> void:
	print("[EDITOR] _on_row_selected('", key, "')")
	if key.is_empty():
		return
	_selected_key = key

	for i in _sidebar_list.item_count:
		if _sidebar_list.get_item_text(i) == key:
			_suppress_sidebar_signal = true
			_sidebar_list.select(i)
			_suppress_sidebar_signal = false
			break

	_update_preview_for(key)

func _update_preview_for(key: String) -> void:
	print("[EDITOR] _update_preview_for('", key, "')")
	if not _preview_panel:
		return
	if not _rows_by_key.has(key):
		_preview_panel.clear()
		return
	var row: BayterekLocalizationKeyRow = _rows_by_key[key]
	if not is_instance_valid(row):
		_preview_panel.clear()
		return

	var broken: bool = _has_broken_reference(key)
	var cyclic: bool = _has_cycle(key)
	var cycle_path: Array[String] = []
	if cyclic:
		cycle_path = _get_cycle_path(key)

	var lookup_for_preview: Callable = _preview_lookup
	if cyclic:
		lookup_for_preview = _make_cycle_safe_lookup(key)

	_preview_panel.show_row(
		key,
		row.original_value,
		row.get_translation(),
		current_locale,
		broken,
		cyclic,
		cycle_path,
		lookup_for_preview
	)

func _make_cycle_safe_lookup(root_key: String) -> Callable:
	var cycle_members: Dictionary = {}
	var path: Array[String] = _get_cycle_path(root_key)
	for k in path:
		cycle_members[k] = true

	return func(k: String) -> String:
		if cycle_members.has(k) and k != root_key:
			return "{@%s}" % k
		if translations.has(k):
			return String(translations[k])
		if originals.has(k):
			return String(originals[k])
		return ""

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

	_selected_key = key
	_update_preview_for(key)

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
# KEY RENAME
# ============================================================

func _on_row_key_rename_requested(old_key: String, new_key: String) -> void:
	if not is_original_locale:
		return
	if old_key.is_empty() or new_key.is_empty() or old_key == new_key:
		return

	var loader: Node = get_node_or_null("/root/BayterekLocalizationLoader")
	if not loader:
		return
	var registry: LocalizationRegistry = loader.call("get_registry")
	if not registry:
		return

	if _row_key_exists_anywhere(registry, new_key):
		push_warning("[Editor] Rename failed: key '%s' already exists." % new_key)
		if _rows_by_key.has(old_key):
			var r: BayterekLocalizationKeyRow = _rows_by_key[old_key]
			if is_instance_valid(r):
				r._apply_values()
		return

	if _undo_helper:
		_undo_helper.push_rename_key(
			old_key,
			new_key,
			_apply_rename_key,
			_apply_rename_key_undo
		)
	else:
		_apply_rename_key(old_key, new_key)

func _apply_rename_key(old_key: String, new_key: String) -> void:
	var loader: Node = get_node_or_null("/root/BayterekLocalizationLoader")
	if not loader:
		return
	var registry: LocalizationRegistry = loader.call("get_registry")
	if not registry:
		return

	for locale in registry.get_all_locales():
		var path: String = Service.get_locale_file_path(locale)
		var data: Dictionary = Service.read_json(path)
		if data.has(old_key):
			data[new_key] = data[old_key]
			data.erase(old_key)
			Service.write_json(path, data)

	_selected_key = ""
	open_locale(current_locale)
	EditorInterface.get_resource_filesystem().scan()

func _apply_rename_key_undo(old_key: String, new_key: String) -> void:
	_apply_rename_key(new_key, old_key)

func _row_key_exists_anywhere(registry: LocalizationRegistry, candidate: String) -> bool:
	for locale in registry.get_all_locales():
		var path: String = Service.get_locale_file_path(locale)
		var data: Dictionary = Service.read_json(path)
		if data.has(candidate):
			return true
	return false

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

		if _undo_helper:
			_undo_helper.push_add_key(
				new_key,
				_apply_add_key.bind(new_key),
				_apply_remove_key.bind(new_key)
			)
		else:
			_apply_add_key(new_key)

		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())

	add_child(dialog)
	dialog.reset_size()
	dialog.size = Vector2i(400, 180)
	dialog.popup_centered()

	key_input.call_deferred("grab_focus")

func _apply_add_key(key: String) -> void:
	if originals.has(key) or translations.has(key):
		return
	originals[key] = ""
	translations[key] = ""
	_add_row(key, "", "")
	_refresh_sidebar()
	_set_dirty(true)
	_update_missing_count()
	_update_validation_flags()

func _apply_remove_key(key: String) -> void:
	if not originals.has(key) and not translations.has(key):
		return
	originals.erase(key)
	translations.erase(key)
	if _rows_by_key.has(key):
		var row: BayterekLocalizationKeyRow = _rows_by_key[key]
		if is_instance_valid(row):
			row.queue_free()
		_rows_by_key.erase(key)
	if key == _selected_key:
		_selected_key = ""
		_preview_panel.clear()
	_refresh_sidebar()
	_set_dirty(true)
	_update_missing_count()
	_update_validation_flags()

func _on_delete_key_pressed() -> void:
	if not is_original_locale:
		return

	var selected_key: String = _selected_key
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
	info.text = "Delete key \"%s\"?\nThis will remove it from all locale files." % selected_key
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(400, 0)
	vbox.add_child(info)

	dialog.confirmed.connect(func():
		_delete_key_across_locales(selected_key)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())

	add_child(dialog)
	dialog.reset_size()
	dialog.size = Vector2i(440, 180)
	dialog.popup_centered()

func _delete_key_across_locales(target_key: String) -> void:
	var loader: Node = get_node_or_null("/root/BayterekLocalizationLoader")
	if not loader:
		return
	var registry: LocalizationRegistry = loader.call("get_registry")
	if not registry:
		return

	var deleted_values: Dictionary = {}
	for locale in registry.get_all_locales():
		var path: String = Service.get_locale_file_path(locale)
		var data: Dictionary = Service.read_json(path)
		if data.has(target_key):
			deleted_values[locale] = data[target_key]

	if _undo_helper:
		_undo_helper.push_delete_key(
			target_key,
			deleted_values,
			_apply_delete_key,
			_apply_restore_key
		)
	else:
		_apply_delete_key(target_key)

func _apply_delete_key(target_key: String) -> void:
	var loader: Node = get_node_or_null("/root/BayterekLocalizationLoader")
	if not loader:
		return
	var registry: LocalizationRegistry = loader.call("get_registry")
	if not registry:
		return

	for locale in registry.get_all_locales():
		var path: String = Service.get_locale_file_path(locale)
		var data: Dictionary = Service.read_json(path)
		if data.has(target_key):
			data.erase(target_key)
			Service.write_json(path, data)

	originals.erase(target_key)
	translations.erase(target_key)

	if _rows_by_key.has(target_key):
		var row: BayterekLocalizationKeyRow = _rows_by_key[target_key]
		if is_instance_valid(row):
			row.queue_free()
		_rows_by_key.erase(target_key)

	if target_key == _selected_key:
		_selected_key = ""
		_preview_panel.clear()

	_refresh_sidebar()
	_set_dirty(true)
	_update_missing_count()
	_update_validation_flags()
	EditorInterface.get_resource_filesystem().scan()

func _apply_restore_key(target_key: String, values: Dictionary) -> void:
	for locale in values.keys():
		var path: String = Service.get_locale_file_path(locale)
		var data: Dictionary = Service.read_json(path)
		data[target_key] = values[locale]
		Service.write_json(path, data)

	open_locale(current_locale)
	EditorInterface.get_resource_filesystem().scan()

# ============================================================
# IMPORT / EXPORT
# ============================================================

func _on_export_pressed() -> void:
	var loader: Node = get_node_or_null("/root/BayterekLocalizationLoader")
	if not loader:
		return
	var registry: LocalizationRegistry = loader.call("get_registry")
	if not registry:
		return

	if not _csv_dialog:
		_csv_dialog = ImportExportDialog.new()
		_csv_dialog.export_completed.connect(_on_csv_export_completed)
		_csv_dialog.import_completed.connect(_on_csv_import_completed)
		add_child(_csv_dialog)

	_csv_dialog.open_export(registry, "")

func _on_import_pressed() -> void:
	var loader: Node = get_node_or_null("/root/BayterekLocalizationLoader")
	if not loader:
		return
	var registry: LocalizationRegistry = loader.call("get_registry")
	if not registry:
		return

	if not _csv_dialog:
		_csv_dialog = ImportExportDialog.new()
		_csv_dialog.export_completed.connect(_on_csv_export_completed)
		_csv_dialog.import_completed.connect(_on_csv_import_completed)
		add_child(_csv_dialog)

	_csv_dialog.open_import(registry, "")

func _on_csv_export_completed(path: String) -> void:
	print("[Editor] CSV exported: ", path)

func _on_csv_import_completed(imported_count: int) -> void:
	print("[Editor] CSV imported: %d keys" % imported_count)
	if not current_locale.is_empty():
		open_locale(current_locale)

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
	var shift: bool = event.shift_pressed

	if ctrl and key == KEY_S:
		if dirty:
			_on_save_pressed()
		get_viewport().set_input_as_handled()
		return

	if ctrl and not shift and key == KEY_Z:
		if _undo_helper:
			_undo_helper.undo()
		get_viewport().set_input_as_handled()
		return

	if (ctrl and key == KEY_Y) or (ctrl and shift and key == KEY_Z):
		if _undo_helper:
			_undo_helper.redo()
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