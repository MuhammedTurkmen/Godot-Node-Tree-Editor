@tool
class_name BayterekLocalizationBrowser
extends MarginContainer
## Browser tab — language / region tree with add/remove and context menu.

const Localization = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization.gd")
const Service = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization_service.gd")

enum LanguageMenuId { CREATE = 0, DELETE = 1 }
enum RegionMenuId   { CREATE = 0, DELETE = 1 }

enum ContextMenuId {
	CREATE_LANGUAGE = 10,
	CREATE_REGION = 11,
	RENAME = 20,
	DELETE = 30,
	OPEN_REGION = 40,
}

signal region_activated(locale: String)

var main_screen: BayterekLocalizationMainScreen = null

# --- UI refs ---
var _tree: Tree
var _search: LineEdit
var _lang_menu: MenuButton
var _region_menu: MenuButton
var _refresh_btn: Button
var _lang_count_label: Label
var _region_count_label: Label
var _locale_count_label: Label
var _original_label: Label
var _context_menu: PopupMenu

# --- Dialogs (lazily created) ---
var _language_dialog: BayterekLocalizationLanguageDialog
var _region_dialog: BayterekLocalizationRegionDialog
var _delete_dialog: ConfirmationDialog
var _delete_delete_files_check: CheckBox
var _pending_delete: Dictionary = {}

# --- State ---
var _suppress_selection: bool = false

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
	_connect_signals()
	_create_dialogs()
	_refresh()
	print("[BayterekLocalizationBrowser] ready.")

## Called by the MainScreen when the Browser tab becomes visible again.
## Reloads the registry from disk and rebuilds the tree.
func on_tab_shown() -> void:
	_reload_registry_from_disk()
	_refresh()

# ============================================================
# UI
# ============================================================

func _build_ui() -> void:
	if _tree:
		return

	var vbox := VBoxContainer.new()
	vbox.name = "Root"
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(vbox)

	# --- Top bar ---
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	vbox.add_child(top)

	_lang_menu = MenuButton.new()
	_lang_menu.text = "Language"
	_lang_menu.get_popup().add_item("Add Language...", LanguageMenuId.CREATE)
	_lang_menu.get_popup().add_item("Delete Selected", LanguageMenuId.DELETE)
	_lang_menu.get_popup().set_item_disabled(LanguageMenuId.DELETE, true)
	top.add_child(_lang_menu)

	_region_menu = MenuButton.new()
	_region_menu.text = "Region"
	_region_menu.get_popup().add_item("Add Region...", RegionMenuId.CREATE)
	_region_menu.get_popup().add_item("Delete Selected", RegionMenuId.DELETE)
	_region_menu.get_popup().set_item_disabled(RegionMenuId.CREATE, true)
	_region_menu.get_popup().set_item_disabled(RegionMenuId.DELETE, true)
	top.add_child(_region_menu)

	_search = LineEdit.new()
	_search.placeholder_text = "Search language or region"
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(_search)

	_refresh_btn = Button.new()
	_refresh_btn.name = "RefreshButton"
	_refresh_btn.text = "⟳"
	_refresh_btn.tooltip_text = "Reload registry from disk"
	_refresh_btn.custom_minimum_size = Vector2(32, 0)
	_refresh_btn.pressed.connect(_on_refresh_pressed)
	top.add_child(_refresh_btn)

	# --- Tree ---
	_tree = Tree.new()
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.size_flags_horizontal = SIZE_EXPAND_FILL
	_tree.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(_tree)
	_tree.create_item()

	_tree.item_selected.connect(_on_item_selected)
	_tree.item_activated.connect(_on_item_activated)
	_tree.gui_input.connect(_on_tree_gui_input)

	# --- Bottom stats bar ---
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	vbox.add_child(bottom)

	_lang_count_label = Label.new()
	_lang_count_label.text = "Languages: 0"
	bottom.add_child(_lang_count_label)

	bottom.add_child(VSeparator.new())

	_region_count_label = Label.new()
	_region_count_label.text = "Regions: 0"
	bottom.add_child(_region_count_label)

	bottom.add_child(VSeparator.new())

	_locale_count_label = Label.new()
	_locale_count_label.text = "Locales: 0"
	bottom.add_child(_locale_count_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	bottom.add_child(spacer)

	_original_label = Label.new()
	_original_label.text = "Original: —"
	_original_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	bottom.add_child(_original_label)

	# --- Context menu ---
	_context_menu = PopupMenu.new()
	_context_menu.name = "BrowserContextMenu"
	add_child(_context_menu)

	queue_sort()

func _connect_signals() -> void:
	_lang_menu.get_popup().id_pressed.connect(_on_lang_menu_pressed)
	_region_menu.get_popup().id_pressed.connect(_on_region_menu_pressed)
	_search.text_changed.connect(_on_search_changed)
	_context_menu.id_pressed.connect(_on_context_menu_pressed)

func _create_dialogs() -> void:
	if not _language_dialog:
		_language_dialog = BayterekLocalizationLanguageDialog.new()
		_language_dialog.applied.connect(_on_language_dialog_applied)
		add_child(_language_dialog)

	if not _region_dialog:
		_region_dialog = BayterekLocalizationRegionDialog.new()
		_region_dialog.applied.connect(_on_region_dialog_applied)
		add_child(_region_dialog)

# ============================================================
# REFRESH
# ============================================================

## Reloads the registry from disk (bypassing the cached instance).
func _reload_registry_from_disk() -> void:
	var loader: Node = get_node_or_null("/root/BayterekLocalizationLoader")
	if loader and loader.has_method("reload_registry"):
		loader.call("reload_registry")

func _on_refresh_pressed() -> void:
	_reload_registry_from_disk()
	_refresh()

func _refresh() -> void:
	_refresh_ui.call_deferred()

func _refresh_ui() -> void:
	if not is_inside_tree():
		return
	if not _tree or not is_instance_valid(_tree) or not _tree.is_inside_tree():
		return

	var loader: Node = get_node_or_null("/root/BayterekLocalizationLoader")
	if not loader:
		return

	var registry: LocalizationRegistry = loader.call("get_registry")
	if not registry:
		_tree.clear()
		_tree.create_item()
		return

	_rebuild_tree(registry)
	_update_stats(registry)
	_apply_filter(_search.text if _search else "")

func _rebuild_tree(registry: LocalizationRegistry) -> void:
	_tree.clear()
	_tree.create_item()

	var root: TreeItem = _tree.get_root()
	if not root:
		return

	var theme: Theme = EditorInterface.get_editor_theme()

	for lang in registry.languages:
		if not lang:
			continue

		var l_item := root.create_child()
		l_item.set_text(0, "%s  (%s)" % [lang.name, lang.code])
		l_item.set_metadata(0, {"type": "language", "code": lang.code, "name": lang.name})
		l_item.set_icon(0, theme.get_icon(Localization.LANGUAGE_ICON, Localization.ICON_THEME))
		l_item.set_collapsed(false)

		if lang.regions.is_empty() and registry.is_original(lang.code):
			l_item.set_custom_color(0, Color(1.0, 0.85, 0.4))

		for region in lang.regions:
			if not region:
				continue
			var r_item := l_item.create_child()
			var locale: String = region.get_locale()
			r_item.set_text(0, "%s  (%s)" % [region.name, locale])
			r_item.set_metadata(0, {
				"type": "region",
				"locale": locale,
				"language_code": lang.code,
				"region_code": region.code,
				"file_path": region.file_path,
			})
			r_item.set_icon(0, theme.get_icon(Localization.REGION_ICON, Localization.ICON_THEME))

			if registry.is_original(locale):
				r_item.set_custom_color(0, Color(1.0, 0.85, 0.4))

	_tree.hide()
	_tree.show()

func _update_stats(registry: LocalizationRegistry) -> void:
	var lang_count: int = registry.get_language_count()
	var region_count: int = registry.get_region_count()
	var locale_count: int = registry.get_all_locales().size()

	_lang_count_label.text = "Languages: %d" % lang_count
	_region_count_label.text = "Regions: %d" % region_count
	_locale_count_label.text = "Locales: %d" % locale_count

	if registry.original_locale.is_empty():
		_original_label.text = "Original: —"
	else:
		_original_label.text = "Original: %s" % registry.original_locale

# ============================================================
# SELECTION
# ============================================================

func _on_item_selected() -> void:
	if _suppress_selection:
		return

	var selected: TreeItem = _tree.get_selected()
	if not selected:
		_update_menu_state(null)
		return

	var meta: Dictionary = selected.get_metadata(0)
	_update_menu_state(meta)

func _update_menu_state(meta: Variant) -> void:
	var is_language: bool = false
	var is_region: bool = false

	if meta is Dictionary and not meta.is_empty():
		var t: String = meta.get("type", "")
		is_language = t == "language"
		is_region = t == "region"

	_lang_menu.get_popup().set_item_disabled(LanguageMenuId.DELETE, not is_language)
	_region_menu.get_popup().set_item_disabled(RegionMenuId.CREATE, not is_language)
	_region_menu.get_popup().set_item_disabled(RegionMenuId.DELETE, not is_region)

func _on_item_activated() -> void:
	var selected: TreeItem = _tree.get_selected()
	if not selected:
		return

	var meta: Dictionary = selected.get_metadata(0)
	if meta.is_empty():
		return

	var t: String = meta.get("type", "")

	if t == "language":
		selected.collapsed = not selected.collapsed
		return

	if t == "region":
		var locale: String = meta.get("locale", "")
		if not locale.is_empty():
			region_activated.emit(locale)

# ============================================================
# LANGUAGE MENU
# ============================================================

func _on_lang_menu_pressed(id: int) -> void:
	match id:
		LanguageMenuId.CREATE: _open_add_language()
		LanguageMenuId.DELETE: _request_delete_selected()

func _open_add_language() -> void:
	var loader: Node = get_node_or_null("/root/BayterekLocalizationLoader")
	if not loader:
		return
	var registry: LocalizationRegistry = loader.call("get_registry")
	if not registry:
		return

	var existing: PackedStringArray = []
	for lang in registry.languages:
		if lang:
			existing.append(lang.code)

	_language_dialog.open(existing)

func _on_language_dialog_applied(language_code: String, region_code: String) -> void:
	var loader: Node = get_node_or_null("/root/BayterekLocalizationLoader")
	if not loader:
		return
	var registry: LocalizationRegistry = loader.call("get_registry")
	if not registry:
		return

	var result = Service.add_language(registry, language_code, region_code)
	if not result:
		return

	loader.call("save_registry")
	EditorInterface.get_resource_filesystem().scan()
	_refresh()

# ============================================================
# REGION MENU
# ============================================================

func _on_region_menu_pressed(id: int) -> void:
	match id:
		RegionMenuId.CREATE: _open_add_region()
		RegionMenuId.DELETE: _request_delete_selected()

func _open_add_region() -> void:
	var selected: TreeItem = _tree.get_selected()
	if not selected:
		return
	var meta: Dictionary = selected.get_metadata(0)
	if meta.get("type", "") != "language":
		return

	var language_code: String = meta.get("code", "")
	if language_code.is_empty():
		return

	var loader: Node = get_node_or_null("/root/BayterekLocalizationLoader")
	if not loader:
		return
	var registry: LocalizationRegistry = loader.call("get_registry")
	if not registry:
		return

	var lang = registry.get_language(language_code)
	if not lang:
		return

	var existing: PackedStringArray = []
	for region in lang.regions:
		if region:
			existing.append(region.code)

	_region_dialog.open(language_code, existing)

func _on_region_dialog_applied(language_code: String, region_code: String) -> void:
	var loader: Node = get_node_or_null("/root/BayterekLocalizationLoader")
	if not loader:
		return
	var registry: LocalizationRegistry = loader.call("get_registry")
	if not registry:
		return

	var result = Service.add_region(registry, language_code, region_code)
	if not result:
		return

	loader.call("save_registry")
	EditorInterface.get_resource_filesystem().scan()
	_refresh()

# ============================================================
# CONTEXT MENU (right-click)
# ============================================================

func _on_tree_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var item: TreeItem = _tree.get_item_at_position(event.position)
			if item:
				item.select(0)
			_show_context_menu(event.position)

func _show_context_menu(mouse_pos: Vector2) -> void:
	var item: TreeItem = _tree.get_selected()

	_context_menu.clear()

	if not item:
		_context_menu.add_item("Add Language...", ContextMenuId.CREATE_LANGUAGE)
		_context_menu.add_separator()
		_context_menu.add_item("Refresh", ContextMenuId.CREATE_LANGUAGE + 1000)
	else:
		var meta: Dictionary = item.get_metadata(0)
		var t: String = meta.get("type", "")

		if t == "language":
			_context_menu.add_item("Add Region...", ContextMenuId.CREATE_REGION)
			_context_menu.add_separator()
			_context_menu.add_item("Delete Language", ContextMenuId.DELETE)
		elif t == "region":
			_context_menu.add_item("Open in Editor", ContextMenuId.OPEN_REGION)
			_context_menu.add_separator()
			_context_menu.add_item("Delete Region", ContextMenuId.DELETE)

	_context_menu.popup_on_parent(Rect2i(
		_tree.get_screen_transform() * mouse_pos,
		Vector2i.ZERO
	))

func _on_context_menu_pressed(id: int) -> void:
	# Magic id for "Refresh"
	if id == ContextMenuId.CREATE_LANGUAGE + 1000:
		_on_refresh_pressed()
		return

	match id:
		ContextMenuId.CREATE_LANGUAGE: _open_add_language()
		ContextMenuId.CREATE_REGION: _open_add_region()
		ContextMenuId.DELETE: _request_delete_selected()
		ContextMenuId.OPEN_REGION: _on_item_activated()

# ============================================================
# DELETE
# ============================================================

func _request_delete_selected() -> void:
	var selected: TreeItem = _tree.get_selected()
	if not selected:
		return
	var meta: Dictionary = selected.get_metadata(0)
	if meta.is_empty():
		return

	_pending_delete = meta
	var t: String = meta.get("type", "")

	var message: String = ""
	if t == "language":
		message = "Delete language \"%s\"?\nAll its regions and JSON files will be removed." % meta.get("name", "")
	elif t == "region":
		message = "Delete region \"%s\"?\nIts JSON file will be removed." % meta.get("locale", "")
	else:
		return

	_open_delete_dialog(message)

func _open_delete_dialog(message: String) -> void:
	if is_instance_valid(_delete_dialog):
		_delete_dialog.queue_free()
		_delete_dialog = null

	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.name = "DeleteLocalizationDialog"
	_delete_dialog.title = "Confirm Delete"
	_delete_dialog.ok_button_text = "Delete"
	_delete_dialog.cancel_button_text = "Cancel"
	_delete_dialog.dialog_text = ""
	_delete_dialog.min_size = Vector2i.ZERO
	_delete_dialog.unresizable = true

	var vbox := VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.custom_minimum_size = Vector2(440, 110)
	vbox.add_theme_constant_override("separation", 12)
	_delete_dialog.add_child(vbox)

	var info := Label.new()
	info.text = message
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(440, 0)
	info.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	info.add_theme_font_size_override("font_size", 13)
	vbox.add_child(info)

	vbox.add_child(HSeparator.new())

	_delete_delete_files_check = CheckBox.new()
	_delete_delete_files_check.text = "Also delete JSON file(s) from disk"
	_delete_delete_files_check.button_pressed = true
	vbox.add_child(_delete_delete_files_check)

	_delete_dialog.confirmed.connect(_on_delete_confirmed)
	_delete_dialog.canceled.connect(_cleanup_delete_dialog)
	_delete_dialog.close_requested.connect(_cleanup_delete_dialog)

	add_child(_delete_dialog)

	if not _delete_dialog.visible:
		await get_tree().process_frame

	_delete_dialog.reset_size()
	_delete_dialog.size = Vector2i(500, 240)
	_delete_dialog.popup_centered()

func _cleanup_delete_dialog() -> void:
	_pending_delete = {}
	if is_instance_valid(_delete_dialog):
		_delete_dialog.queue_free()
	_delete_dialog = null
	_delete_delete_files_check = null

func _on_delete_confirmed() -> void:
	if _pending_delete.is_empty():
		_cleanup_delete_dialog()
		return

	var delete_files: bool = _delete_delete_files_check.button_pressed if _delete_delete_files_check else true
	var pending: Dictionary = _pending_delete
	_pending_delete = {}

	var loader: Node = get_node_or_null("/root/BayterekLocalizationLoader")
	if not loader:
		_cleanup_delete_dialog()
		return
	var registry: LocalizationRegistry = loader.call("get_registry")
	if not registry:
		_cleanup_delete_dialog()
		return

	var t: String = pending.get("type", "")

	if t == "language":
		var lang_code: String = pending.get("code", "")
		if not delete_files:
			var lang = registry.get_language(lang_code)
			if lang:
				for region in lang.regions:
					if region:
						region.file_path = ""
		Service.remove_language(registry, lang_code)

	elif t == "region":
		var lc: String = pending.get("language_code", "")
		var rc: String = pending.get("region_code", "")
		if not delete_files:
			var lang2 = registry.get_language(lc)
			if lang2:
				var reg = lang2.get_region(rc)
				if reg:
					reg.file_path = ""
		Service.remove_region(registry, lc, rc)

	loader.call("save_registry")
	EditorInterface.get_resource_filesystem().scan()
	_cleanup_delete_dialog()
	_refresh()

# ============================================================
# SEARCH FILTER
# ============================================================

func _on_search_changed(_text: String) -> void:
	_apply_filter(_search.text)

func _apply_filter(query: String) -> void:
	var q: String = query.strip_edges().to_lower()
	var root: TreeItem = _tree.get_root()
	if not root:
		return

	for lang_item in root.get_children():
		var lang_text: String = lang_item.get_text(0).to_lower()
		var lang_matches: bool = q.is_empty() or lang_text.find(q) != -1

		var any_region_visible: bool = false
		for region_item in lang_item.get_children():
			var region_text: String = region_item.get_text(0).to_lower()
			var region_matches: bool = q.is_empty() or region_text.find(q) != -1
			var show_region: bool = lang_matches or region_matches
			region_item.visible = show_region
			if show_region:
				any_region_visible = true

		if lang_matches:
			lang_item.visible = true
			for region_item in lang_item.get_children():
				region_item.visible = true
		else:
			lang_item.visible = any_region_visible
			if any_region_visible:
				lang_item.collapsed = false