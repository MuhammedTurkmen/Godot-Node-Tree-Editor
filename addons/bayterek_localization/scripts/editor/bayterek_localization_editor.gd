@tool
class_name BayterekLocalizationEditor
extends MarginContainer
## Editor tab — sidebar + key table + preview panel.

const Localization = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization.gd")
const Service = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization_service.gd")
const Format = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization_format_string.gd")
const KeyRow = preload("res://addons/bayterek_localization/scripts/editor/ui/bayterek_localization_key_row.gd")
const PreviewPanel = preload("res://addons/bayterek_localization/scripts/editor/ui/bayterek_localization_preview_panel.gd")
const ImportExportDialog = preload("res://addons/bayterek_localization/scripts/editor/bayterek_localization_import_export_dialog.gd")
const UndoHelper = preload("res://addons/bayterek_localization/scripts/editor/bayterek_localization_undo_helper.gd")
const Fuzzy = preload("res://addons/bayterek_localization/scripts/editor/bayterek_localization_fuzzy.gd")

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

var _outer_split: HSplitContainer
var _inner_split: HSplitContainer

var _sidebar_root: VBoxContainer
var _sidebar_header: HBoxContainer
var _sidebar_toggle_btn: Button
var _sidebar_title: Label
var _sidebar_content: VBoxContainer
var _sidebar_search: LineEdit
var _sidebar_list: ItemList

var _main_panel: VBoxContainer
var _toolbar: HBoxContainer
var _locale_dropdown: OptionButton
var _locale_label: Label
var _save_btn: Button
var _add_key_btn: Button
var _delete_key_btn: Button
var _sync_missing_btn: Button
var _import_btn: Button
var _export_btn: Button
var _search_input: LineEdit
var _missing_label: Label

var _table_split: HSplitContainer
var _mid_split: HSplitContainer
var _key_column: ScrollContainer
var _original_column: ScrollContainer
var _translation_column: ScrollContainer
var _key_content: VBoxContainer
var _original_content: VBoxContainer
var _translation_content: VBoxContainer
var _rows_scroll: ScrollContainer
var _rows_container: VBoxContainer
var _empty_label: Label
var _h_key: Label
var _h_orig: Label
var _h_trans: Label
var _header_split: HBoxContainer

var _stats_panel: HBoxContainer
var _stats_label: Label

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

	_preview_collapsed = true
	_preview_root.custom_minimum_size.x = PREVIEW_COLLAPSED
	_preview_panel.visible = false
	_preview_title.visible = false
	_preview_toggle_btn.text = "◀"
	_inner_split.split_offset = -PREVIEW_COLLAPSED
	_inner_split.queue_sort()

	print("[BayterekLocalizationEditor] ready.")

# ============================================================
# UI BUILD
# ============================================================

func _build_ui() -> void:
	if _outer_split:
		return

	_outer_split = HSplitContainer.new()
	_outer_split.name = "OuterSplit"
	_outer_split.size_flags_horizontal = SIZE_EXPAND_FILL
	_outer_split.size_flags_vertical = SIZE_EXPAND_FILL
	_outer_split.split_offset = SIDEBAR_EXPANDED
	add_child(_outer_split)

	_build_sidebar()

	_inner_split = HSplitContainer.new()
	_inner_split.name = "InnerSplit"
	_inner_split.size_flags_horizontal = SIZE_EXPAND_FILL
	_inner_split.size_flags_vertical = SIZE_EXPAND_FILL
	_inner_split.split_offset = -PREVIEW_COLLAPSED
	_outer_split.add_child(_inner_split)

	_build_main_panel()
	_build_preview_panel()

func _build_sidebar() -> void:
	_sidebar_root = VBoxContainer.new()
	_sidebar_root.name = "SidebarRoot"
	_sidebar_root.custom_minimum_size = Vector2(SIDEBAR_COLLAPSED, 0)
	_sidebar_root.size_flags_vertical = SIZE_EXPAND_FILL
	_sidebar_root.add_theme_constant_override("separation", 2)
	_outer_split.add_child(_sidebar_root)

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
	_inner_split.add_child(_main_panel)

	# ============================================================
	# TOOLBAR
	# ============================================================
	_toolbar = HBoxContainer.new()
	_toolbar.name = "Toolbar"
	_toolbar.add_theme_constant_override("separation", 6)
	_main_panel.add_child(_toolbar)

	_locale_dropdown = OptionButton.new()
	_locale_dropdown.name = "LocaleDropdown"
	_locale_dropdown.tooltip_text = "Switch active locale"
	_locale_dropdown.custom_minimum_size.x = 180
	_locale_dropdown.item_selected.connect(_on_locale_dropdown_selected)
	_toolbar.add_child(_locale_dropdown)

	_locale_label = Label.new()
	_locale_label.name = "LocaleLabel"
	_locale_label.text = ""
	_locale_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_locale_label.custom_minimum_size.x = 70
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

	_sync_missing_btn = Button.new()
	_sync_missing_btn.name = "SyncMissingButton"
	_sync_missing_btn.text = "Sync Missing"
	_sync_missing_btn.tooltip_text = "Copy all keys from the original locale that are missing here (empty values)"
	_sync_missing_btn.pressed.connect(_on_sync_missing_pressed)
	_toolbar.add_child(_sync_missing_btn)

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

	# ============================================================
	# STATS
	# ============================================================
	_stats_panel = HBoxContainer.new()
	_stats_panel.name = "StatsPanel"
	_stats_panel.add_theme_constant_override("separation", 6)
	_main_panel.add_child(_stats_panel)

	_stats_label = Label.new()
	_stats_label.name = "StatsLabel"
	_stats_label.text = "—"
	_stats_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	_stats_label.add_theme_font_size_override("font_size", 11)
	_stats_panel.add_child(_stats_label)

	# ============================================================
	# TABLE HOLDER (header + 3-column table)
	# ============================================================
	# The table fills the remaining vertical space and hugs the top
	# under the header. It stretches to the bottom of the panel.
	var table_holder := VBoxContainer.new()
	table_holder.name = "TableHolder"
	table_holder.size_flags_horizontal = SIZE_EXPAND_FILL
	table_holder.size_flags_vertical = SIZE_EXPAND_FILL
	table_holder.add_theme_constant_override("separation", 0)
	_main_panel.add_child(table_holder)

	# --- Header row (mirrors table split) ---
	_header_split = HBoxContainer.new()
	_header_split.name = "ColumnHeader"
	_header_split.add_theme_constant_override("separation", 0)
	_header_split.custom_minimum_size.y = 24
	table_holder.add_child(_header_split)

	_h_key = Label.new()
	_h_key.text = "Key"
	_h_key.custom_minimum_size.x = 120
	_h_key.size_flags_horizontal = SIZE_EXPAND_FILL
	_h_key.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_header_split.add_child(_h_key)

	_h_orig = Label.new()
	_h_orig.text = "Original"
	_h_orig.custom_minimum_size.x = 120
	_h_orig.size_flags_horizontal = SIZE_EXPAND_FILL
	_h_orig.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	_header_split.add_child(_h_orig)

	_h_trans = Label.new()
	_h_trans.text = "Translation"
	_h_trans.custom_minimum_size.x = 120
	_h_trans.size_flags_horizontal = SIZE_EXPAND_FILL
	_h_trans.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_header_split.add_child(_h_trans)

	# --- 3-column HSplitContainer ---
	_table_split = HSplitContainer.new()
	_table_split.name = "TableSplit"
	_table_split.size_flags_horizontal = SIZE_EXPAND_FILL
	_table_split.size_flags_vertical = SIZE_EXPAND_FILL
	_table_split.split_offset = 200
	table_holder.add_child(_table_split)

	# Left: key column (scroll-wrapped)
	_key_column = _make_scroll_column("KeyColumn", 80)
	_table_split.add_child(_key_column)

	# Right: nested split for original + translation
	_mid_split = HSplitContainer.new()
	_mid_split.name = "MidSplit"
	_mid_split.size_flags_horizontal = SIZE_EXPAND_FILL
	_mid_split.size_flags_vertical = SIZE_EXPAND_FILL
	_mid_split.split_offset = 300
	_table_split.add_child(_mid_split)

	_original_column = _make_scroll_column("OriginalColumn", 80)
	_mid_split.add_child(_original_column)

	_translation_column = _make_scroll_column("TranslationColumn", 80)
	_mid_split.add_child(_translation_column)

	# Cache the inner VBox of each scroll column.
	_key_content = _key_column.get_node("Content") as VBoxContainer
	_original_content = _original_column.get_node("Content") as VBoxContainer
	_translation_content = _translation_column.get_node("Content") as VBoxContainer

	# Sync header column widths when the split is dragged.
	_table_split.dragged.connect(func(_offset: int): _sync_header_to_table())
	_mid_split.dragged.connect(func(_offset: int): _sync_header_to_table())

	# Sync vertical scroll between the 3 columns.
	for sc in [_key_column, _original_column, _translation_column]:
		var scroll := sc as ScrollContainer
		if scroll:
			scroll.get_v_scroll_bar().value_changed.connect(
				func(_v): _sync_scrolls(scroll)
			)

	# ============================================================
	# EMPTY LABEL
	# ============================================================
	_empty_label = Label.new()
	_empty_label.name = "EmptyLabel"
	_empty_label.text = "Double-click a region in the Browser tab to open its translation editor."
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	_main_panel.add_child(_empty_label)
	_empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_empty_label.visible = false

func _make_scroll_column(column_name: String, min_width: int) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = column_name
	scroll.custom_minimum_size.x = min_width
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	var content := VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 0)
	scroll.add_child(content)

	return scroll

func _sync_scrolls(source: ScrollContainer) -> void:
	var src_v: int = int(source.scroll_vertical)
	for sc in [_key_column, _original_column, _translation_column]:
		if sc == source:
			continue
		var scroll := sc as ScrollContainer
		if scroll:
			scroll.scroll_vertical = src_v

func _sync_header_to_table() -> void:
	if not _h_key:
		return

	var total_w: float = _table_split.size.x
	var key_w: float = _key_column.size.x
	var orig_w: float = _original_column.size.x
	var trans_w: float = _translation_column.size.x

	if key_w <= 0.0 or orig_w <= 0.0 or trans_w <= 0.0:
		return

	_h_key.custom_minimum_size.x = key_w
	_h_orig.custom_minimum_size.x = orig_w
	_h_trans.custom_minimum_size.x = trans_w

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
	_preview_toggle_btn.text = "◀"
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

	# Start collapsed — only toggle button + title visible.
	_preview_collapsed = true
	_preview_root.custom_minimum_size.x = PREVIEW_COLLAPSED
	_preview_panel.visible = false
	_preview_title.visible = false

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
	_update_stats_panel()
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
# LOCALE DROPDOWN
# ============================================================

## Rebuilds the locale dropdown from the registry.
func _refresh_locale_dropdown() -> void:
	if not _locale_dropdown:
		return

	var loader: Node = get_node_or_null("/root/BayterekLocalizationLoader")
	if not loader:
		return
	var registry: LocalizationRegistry = loader.call("get_registry")
	if not registry:
		return

	_locale_dropdown.clear()

	var all_locales: PackedStringArray = registry.get_all_locales()
	var orig: String = registry.original_locale

	# Build items: original first, then others alphabetically.
	var sorted_locales: Array[String] = []
	var others: Array[String] = []

	for loc in all_locales:
		if loc == orig:
			sorted_locales.append(loc)
		else:
			others.append(loc)
	others.sort()
	sorted_locales.append_array(others)

	var selected_idx: int = -1
	var idx: int = 0

	for loc in sorted_locales:
		var label: String = loc
		if loc == orig:
			label = "%s  (Original)" % loc
		_locale_dropdown.add_item(label, idx)
		_locale_dropdown.set_item_metadata(idx, loc)

		if loc == current_locale:
			selected_idx = idx

		idx += 1

	# Placeholder if current_locale isn't in the list.
	if selected_idx == -1 and not current_locale.is_empty():
		_locale_dropdown.add_separator()
		_locale_dropdown.add_item("(unknown: %s)" % current_locale, idx)
		_locale_dropdown.set_item_metadata(idx, current_locale)
		selected_idx = idx

	if selected_idx >= 0:
		_locale_dropdown.select(selected_idx)

## Called when the user picks a different locale from the dropdown.
func _on_locale_dropdown_selected(index: int) -> void:
	var meta = _locale_dropdown.get_item_metadata(index)
	if meta == null:
		return
	var loc: String = String(meta)

	if loc.is_empty() or loc == current_locale:
		return

	if dirty:
		_confirm_switch_locale(loc)
	else:
		open_locale(loc)

## Shows a confirmation dialog if there are unsaved changes.
func _confirm_switch_locale(target_locale: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.name = "SwitchLocaleConfirmDialog"
	dialog.title = "Unsaved Changes"
	dialog.ok_button_text = "Discard & Switch"
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
	info.text = "Current locale \"%s\" has unsaved changes.\nSwitch to \"%s\" anyway?" % [
		current_locale, target_locale
	]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(400, 0)
	vbox.add_child(info)

	dialog.confirmed.connect(func():
		open_locale(target_locale)
		dialog.queue_free()
	)
	dialog.canceled.connect(func():
		_update_ui_state()
		dialog.queue_free()
	)
	dialog.close_requested.connect(func():
		_update_ui_state()
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.reset_size()
	dialog.size = Vector2i(440, 180)
	dialog.popup_centered()

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
		var trans_cell: BayterekLocalizationKeyRow = _get_trans_cell(key)
		if not trans_cell:
			continue
		var broken: bool = _has_broken_reference(key)
		var cyclic: bool = _has_cycle(key)
		var cycle_path: Array[String] = []
		if cyclic:
			cycle_path = _get_cycle_path(key)
		trans_cell.set_validation_flags(broken, cyclic, cycle_path)

	_update_stats_panel()

func _add_row(key: String, orig_val: String, trans_val: String) -> void:
	if not _key_content or not _original_content or not _translation_content:
		return

	var row_id: String = key

	# --- Key cell ---
	var key_cell := BayterekLocalizationKeyRow.new()
	key_cell.name = "KeyCell_%s" % row_id
	key_cell.size_flags_horizontal = SIZE_EXPAND_FILL
	_key_content.add_child(key_cell)
	key_cell.setup_as_key(key, is_original_locale, row_id)
	key_cell.row_selected.connect(_on_row_selected)
	key_cell.key_rename_requested.connect(_on_row_key_rename_requested)
	key_cell.set_key_provider_callback(_provide_all_keys)

	# --- Original cell ---
	var orig_cell := BayterekLocalizationKeyRow.new()
	orig_cell.name = "OrigCell_%s" % row_id
	orig_cell.size_flags_horizontal = SIZE_EXPAND_FILL
	_original_content.add_child(orig_cell)
	orig_cell.setup_as_original(key, orig_val, row_id)
	orig_cell.row_selected.connect(_on_row_selected)

	# --- Translation cell ---
	var trans_cell := BayterekLocalizationKeyRow.new()
	trans_cell.name = "TransCell_%s" % row_id
	trans_cell.size_flags_horizontal = SIZE_EXPAND_FILL
	_translation_content.add_child(trans_cell)
	trans_cell.setup_as_translation(key, orig_val, trans_val, is_original_locale, row_id)
	trans_cell.value_changed.connect(_on_row_value_changed)
	trans_cell.row_selected.connect(_on_row_selected)
	trans_cell.navigate_requested.connect(_on_row_navigate_requested)
	trans_cell.value_edit_started.connect(_on_row_value_edit_started)
	trans_cell.value_edit_committed.connect(_on_row_value_edit_committed)
	trans_cell.set_key_provider_callback(_provide_all_keys)

	# Store all 3 cells for later access by key.
	# `_rows_by_key[key]` was previously a single row; now it's a dict
	# with the 3 cells so functions like `_update_validation_flags()`,
	# `_apply_filter()`, `_scroll_to_row()` etc. still work.
	_rows_by_key[key] = {
		"key": key_cell,
		"original": orig_cell,
		"translation": trans_cell,
	}

	# Sync row heights after both cells are laid out.
	_sync_row_heights.call_deferred(row_id)

## Returns the translation cell for a given key, or null.
func _get_trans_cell(key: String) -> BayterekLocalizationKeyRow:
	if not _rows_by_key.has(key):
		return null
	var entry: Dictionary = _rows_by_key[key]
	var cell = entry.get("translation", null)
	if cell is BayterekLocalizationKeyRow and is_instance_valid(cell):
		return cell
	return null

## Returns the key cell for a given key, or null.
func _get_key_cell(key: String) -> BayterekLocalizationKeyRow:
	if not _rows_by_key.has(key):
		return null
	var entry: Dictionary = _rows_by_key[key]
	var cell = entry.get("key", null)
	if cell is BayterekLocalizationKeyRow and is_instance_valid(cell):
		return cell
	return null

## Returns the original cell for a given key, or null.
func _get_orig_cell(key: String) -> BayterekLocalizationKeyRow:
	if not _rows_by_key.has(key):
		return null
	var entry: Dictionary = _rows_by_key[key]
	var cell = entry.get("original", null)
	if cell is BayterekLocalizationKeyRow and is_instance_valid(cell):
		return cell
	return null

func _clear_rows() -> void:
	if _key_content:
		for child in _key_content.get_children():
			child.queue_free()
	if _original_content:
		for child in _original_content.get_children():
			child.queue_free()
	if _translation_content:
		for child in _translation_content.get_children():
			child.queue_free()
	_rows_by_key.clear()

## Synchronises the minimum height of all 3 cells of a logical row.
## The tallest cell (usually whichever TextEdit has wrapped to most
## lines) dictates the row height so all columns stay aligned.
func _sync_row_heights(row_id: String) -> void:
	if not _rows_by_key.has(row_id):
		return
	var entry: Dictionary = _rows_by_key[row_id]

	var key_cell = entry.get("key", null)
	var orig_cell = entry.get("original", null)
	var trans_cell = entry.get("translation", null)

	var max_h: float = 0.0
	for c in [key_cell, orig_cell, trans_cell]:
		if c is BayterekLocalizationKeyRow and is_instance_valid(c):
			var h: float = c.get_combined_minimum_size().y
			if h > max_h:
				max_h = h

	if max_h <= 0.0:
		max_h = 30.0

	for c in [key_cell, orig_cell, trans_cell]:
		if c is BayterekLocalizationKeyRow and is_instance_valid(c):
			c.custom_minimum_size.y = max_h

	if _key_content:
		_key_content.queue_sort()
	if _original_content:
		_original_content.queue_sort()
	if _translation_content:
		_translation_content.queue_sort()

# ============================================================
# AUTO-COMPLETE KEY PROVIDER
# ============================================================

## Returns all keys in the current editor (used for auto-complete).
func _provide_all_keys() -> PackedStringArray:
	var keys: PackedStringArray = []
	var all: Array = _rows_by_key.keys()
	all.sort()
	for k in all:
		keys.append(k)
	return keys

# ============================================================
# UI STATE
# ============================================================

func _update_ui_state() -> void:
	# Refresh dropdown items.
	_refresh_locale_dropdown()

	# Locale label shows only the "★ original" marker (dropdown shows the name).
	if is_original_locale:
		_locale_label.text = "★ original"
	else:
		_locale_label.text = ""

	_add_key_btn.disabled = not is_original_locale
	_delete_key_btn.disabled = not is_original_locale
	_sync_missing_btn.disabled = is_original_locale
	_save_btn.disabled = not dirty

func _show_empty() -> void:
	if _empty_label:
		_empty_label.visible = true
	if _rows_scroll:
		_rows_scroll.visible = false
	if _sidebar_list:
		_sidebar_list.clear()
	if _stats_label:
		_stats_label.text = "—"

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

	if _sidebar_collapsed:
		# Tamamen kapat: sadece toggle butonu görünsün
		_sidebar_content.visible = false
		_sidebar_title.visible = false
		_sidebar_root.custom_minimum_size.x = SIDEBAR_COLLAPSED
		_sidebar_toggle_btn.text = "▶"
		_outer_split.split_offset = SIDEBAR_COLLAPSED
	else:
		_sidebar_content.visible = true
		_sidebar_title.visible = true
		_sidebar_root.custom_minimum_size.x = SIDEBAR_EXPANDED
		_sidebar_toggle_btn.text = "◀"
		_outer_split.split_offset = SIDEBAR_EXPANDED

	_outer_split.queue_sort()

# ============================================================
# PREVIEW PANEL TOGGLE
# ============================================================

func _on_preview_toggle() -> void:
	_preview_collapsed = not _preview_collapsed

	if _preview_collapsed:
		# Tamamen kapat: sadece toggle butonu görünsün
		_preview_toggle_btn.text = "◀"
		_preview_title.visible = false
		_preview_panel.visible = false
		_preview_root.custom_minimum_size.x = PREVIEW_COLLAPSED
		_inner_split.split_offset = -PREVIEW_COLLAPSED
	else:
		_preview_toggle_btn.text = "▶"
		_preview_title.visible = true
		_preview_panel.visible = true
		_preview_root.custom_minimum_size.x = PREVIEW_EXPANDED
		_inner_split.split_offset = -PREVIEW_EXPANDED

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
		q = _search_input.text.strip_edges()

	var sq: String = ""
	if _sidebar_search:
		sq = _sidebar_search.text.strip_edges()

	for key in _rows_by_key.keys():
		var key_cell: BayterekLocalizationKeyRow = _get_key_cell(key)
		var orig_cell: BayterekLocalizationKeyRow = _get_orig_cell(key)
		var trans_cell: BayterekLocalizationKeyRow = _get_trans_cell(key)

		var matches: bool = q.is_empty()
		if not matches:
			matches = Fuzzy.matches(q, key)
		if not matches and orig_cell:
			matches = Fuzzy.matches(q, orig_cell.original_value)
		if not matches and trans_cell:
			matches = Fuzzy.matches(q, trans_cell.get_translation())

		if key_cell:
			key_cell.visible = matches
		if orig_cell:
			orig_cell.visible = matches
		if trans_cell:
			trans_cell.visible = matches

	for i in _sidebar_list.item_count:
		var key_text: String = _sidebar_list.get_item_text(i)
		var matches_sidebar: bool = sq.is_empty() or Fuzzy.matches(sq, key_text)
		_sidebar_list.set_item_disabled(i, not matches_sidebar)

# ============================================================
# ROW INTERACTION
# ============================================================

func _on_row_value_edit_started(key: String, current_value: String) -> void:
	_field_edit_old_value[key] = current_value

func _on_row_value_changed(key: String, new_value: String) -> void:
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

	# Re-sync row heights because the translation cell may have grown.
	_sync_row_heights.call_deferred(key)

func _on_row_value_edit_committed(key: String, _new_value: String) -> void:
	_update_validation_flags()
	_update_stats_panel()
	_sync_row_heights.call_deferred(key)
	if key == _selected_key:
		_update_preview_for(key)

func _apply_value_from_undo(key: String, value: String) -> void:
	if not _rows_by_key.has(key):
		return
	translations[key] = value
	_field_edit_old_value[key] = value
	_set_dirty(true)
	_update_missing_count()
	_update_validation_flags()
	_sync_row_heights.call_deferred(key)
	if key == _selected_key:
		_update_preview_for(key)

func _on_row_selected(key: String) -> void:
	if key.is_empty():
		return
	_selected_key = key

	for i in _sidebar_list.item_count:
		if _sidebar_list.get_item_text(i) == key:
			_suppress_sidebar_signal = true
			_sidebar_list.select(i)
			_suppress_sidebar_signal = false
			break

	# Highlight all 3 cells of this row, deselect others.
	for k in _rows_by_key.keys():
		var is_sel: bool = (k == key)
		var kc: BayterekLocalizationKeyRow = _get_key_cell(k)
		var oc: BayterekLocalizationKeyRow = _get_orig_cell(k)
		var tc: BayterekLocalizationKeyRow = _get_trans_cell(k)
		if kc:
			kc.set_row_selected(is_sel)
		if oc:
			oc.set_row_selected(is_sel)
		if tc:
			tc.set_row_selected(is_sel)

	_update_preview_for(key)

func _update_preview_for(key: String) -> void:
	if not _preview_panel:
		return
	var trans_cell: BayterekLocalizationKeyRow = _get_trans_cell(key)
	if not trans_cell:
		_preview_panel.clear()
		return

	var orig_cell: BayterekLocalizationKeyRow = _get_orig_cell(key)
	var orig_val: String = orig_cell.original_value if orig_cell else ""

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
		orig_val,
		trans_cell.get_translation(),
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
	var trans_cell: BayterekLocalizationKeyRow = _get_trans_cell(key)
	if not trans_cell:
		return

	# Scroll all three columns to the same vertical offset.
	_translation_column.ensure_control_visible(trans_cell)
	var key_cell: BayterekLocalizationKeyRow = _get_key_cell(key)
	if key_cell:
		_key_column.ensure_control_visible(key_cell)
	var orig_cell: BayterekLocalizationKeyRow = _get_orig_cell(key)
	if orig_cell:
		_original_column.ensure_control_visible(orig_cell)

	_on_row_selected(key)

func _on_row_navigate_requested(key: String, direction: int) -> void:
	if direction == 0:
		return

	var visible_keys: Array = []
	var sorted: Array = _rows_by_key.keys()
	sorted.sort()
	for k in sorted:
		var tc: BayterekLocalizationKeyRow = _get_trans_cell(k)
		if tc and tc.visible:
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

	var next_trans: BayterekLocalizationKeyRow = _get_trans_cell(next_key)
	if next_trans:
		next_trans.focus_translation()

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
		var key_cell: BayterekLocalizationKeyRow = _get_key_cell(old_key)
		if key_cell and key_cell.has_method("_apply_values"):
			key_cell._apply_values()
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
# ADD / DELETE / SYNC MISSING
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
		var entry: Dictionary = _rows_by_key[key]
		for cell_name in ["key", "original", "translation"]:
			var cell = entry.get(cell_name, null)
			if cell is BayterekLocalizationKeyRow and is_instance_valid(cell):
				cell.queue_free()
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
		var entry: Dictionary = _rows_by_key[target_key]
		for cell_name in ["key", "original", "translation"]:
			var cell = entry.get(cell_name, null)
			if cell is BayterekLocalizationKeyRow and is_instance_valid(cell):
				cell.queue_free()
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
# SYNC MISSING KEYS
# ============================================================

func _on_sync_missing_pressed() -> void:
	if is_original_locale:
		return
	if current_locale.is_empty() or original_locale.is_empty():
		return

	var missing: Array[String] = []
	for key in originals.keys():
		if not translations.has(key):
			missing.append(key)

	if missing.is_empty():
		_show_info_toast("No missing keys — this locale is up to date.")
		return

	var dialog := ConfirmationDialog.new()
	dialog.name = "SyncMissingDialog"
	dialog.title = "Sync Missing Keys"
	dialog.ok_button_text = "Sync"
	dialog.cancel_button_text = "Cancel"
	dialog.dialog_text = ""
	dialog.min_size = Vector2i.ZERO
	dialog.unresizable = true

	var vbox := VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.custom_minimum_size = Vector2(440, 60)
	vbox.add_theme_constant_override("separation", 10)
	dialog.add_child(vbox)

	var info := Label.new()
	info.text = "Add %d missing key(s) from \"%s\" into \"%s\"?\nThey will be added with empty values." % [
		missing.size(), original_locale, current_locale
	]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(440, 0)
	vbox.add_child(info)

	var list_label := Label.new()
	var preview_count: int = mini(8, missing.size())
	var preview_list: Array = missing.slice(0, preview_count)
	list_label.text = "Keys to add: " + ", ".join(preview_list)
	if missing.size() > preview_count:
		list_label.text += "… (+%d more)" % (missing.size() - preview_count)
	list_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list_label.add_theme_font_size_override("font_size", 11)
	list_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	list_label.custom_minimum_size = Vector2(440, 0)
	vbox.add_child(list_label)

	dialog.confirmed.connect(func():
		_apply_sync_missing(missing)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())

	add_child(dialog)
	dialog.reset_size()
	dialog.size = Vector2i(480, 220)
	dialog.popup_centered()

## Applies the missing-key sync — adds each key with an empty value.
func _apply_sync_missing(missing: Array[String]) -> void:
	for key in missing:
		if translations.has(key):
			continue
		translations[key] = ""
		_add_row(key, originals.get(key, ""), "")

	_refresh_sidebar()
	_set_dirty(true)
	_update_missing_count()
	_update_validation_flags()
	_update_stats_panel()

	print("[BayterekLocalizationEditor] synced %d missing key(s) from %s to %s" % [
		missing.size(), original_locale, current_locale
	])

## Shows a temporary info toast near the top of the editor.
func _show_info_toast(message: String) -> void:
	var toast := Label.new()
	toast.text = message
	toast.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	toast.add_theme_font_size_override("font_size", 11)
	toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	toast.add_theme_constant_override("outline_size", 2)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast)
	toast.position = Vector2(20, 8)

	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(toast, "modulate:a", 0.0, 0.5)
	tween.tween_callback(toast.queue_free)

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

	var default_path: String = _make_export_default_path()
	_csv_dialog.open_export(registry, default_path)

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

	var default_path: String = _make_export_default_path()
	_csv_dialog.open_import(registry, default_path)

## Default CSV path: user://localization/<locale>_<timestamp>.csv
func _make_export_default_path() -> String:
	var locale_part: String = current_locale
	if locale_part.is_empty():
		locale_part = "all"

	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var timestamp: String = "%04d-%02d-%02d_%02d-%02d" % [
		dt.get("year", 0),
		dt.get("month", 0),
		dt.get("day", 0),
		dt.get("hour", 0),
		dt.get("minute", 0),
	]

	var filename: String = "%s_%s.csv" % [locale_part, timestamp]
	return "user://localization/%s" % filename

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
# DIRTY / MISSING / STATS
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
		var trans_cell: BayterekLocalizationKeyRow = _get_trans_cell(key)
		if not trans_cell:
			continue
		var t: String = trans_cell.get_translation().strip_edges()
		var orig_cell: BayterekLocalizationKeyRow = _get_orig_cell(key)
		var o: String = orig_cell.original_value if orig_cell else ""
		if t.is_empty() or t == o:
			missing += 1

	_missing_label.text = "%d missing" % missing

## Refreshes the statistics row (counts + completion percentage).
func _update_stats_panel() -> void:
	if not _stats_label:
		return
	if current_locale.is_empty():
		_stats_label.text = "—"
		return

	if is_original_locale:
		var total_keys: int = translations.size()
		_stats_label.text = "Original locale · %d keys · all source of truth" % total_keys
		return

	var total: int = 0
	var translated: int = 0
	var empty_count: int = 0
	var same_count: int = 0
	var broken_count: int = 0
	var cycle_count: int = 0

	for key in _rows_by_key.keys():
		var trans_cell: BayterekLocalizationKeyRow = _get_trans_cell(key)
		if not trans_cell:
			continue

		total += 1
		var cur: String = trans_cell.get_translation().strip_edges()
		var orig_cell: BayterekLocalizationKeyRow = _get_orig_cell(key)
		var orig: String = orig_cell.original_value if orig_cell else ""

		if cur.is_empty():
			empty_count += 1
		elif cur == orig:
			same_count += 1
		else:
			translated += 1

		if _has_broken_reference(key):
			broken_count += 1
		if _has_cycle(key):
			cycle_count += 1

	var pct: float = 0.0
	if total > 0:
		pct = (float(translated) / float(total)) * 100.0

	var parts: Array[String] = []
	parts.append("Translated: %d / %d" % [translated, total])
	parts.append("(%.0f%%)" % pct)
	parts.append("·")
	parts.append("Missing: %d" % (empty_count + same_count))

	if empty_count > 0:
		parts.append("· Empty: %d" % empty_count)
	if same_count > 0:
		parts.append("· Same: %d" % same_count)
	if broken_count > 0:
		parts.append("· Broken refs: %d" % broken_count)
	if cycle_count > 0:
		parts.append("· Cycles: %d" % cycle_count)

	_stats_label.text = "  ".join(parts)

	if pct >= 100.0:
		_stats_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	elif pct >= 75.0:
		_stats_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	elif pct >= 50.0:
		_stats_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	else:
		_stats_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4))

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
		var tc: BayterekLocalizationKeyRow = _get_trans_cell(k)
		if tc and tc.has_field_focus():
			current_key = k
			break
		var kc: BayterekLocalizationKeyRow = _get_key_cell(k)
		if kc and kc.has_field_focus():
			current_key = k
			break

	if current_key.is_empty():
		var sorted: Array = _rows_by_key.keys()
		sorted.sort()
		for k in sorted:
			var tc: BayterekLocalizationKeyRow = _get_trans_cell(k)
			if tc and tc.visible:
				_scroll_to_row(k)
				tc.focus_translation()
				return
		return

	_on_row_navigate_requested(current_key, direction)