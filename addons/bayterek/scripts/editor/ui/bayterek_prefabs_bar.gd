@tool
class_name BayterekPrefabsBar
extends VBoxContainer
## Bottom prefab bar.

signal card_rename_requested(prefab: BayterekPrefab)
signal card_duplicate_requested(prefab: BayterekPrefab)
signal card_delete_requested(prefab: BayterekPrefab)

const ALL_TAB_LABEL := "All"
const UNCATEGORIZED_LABEL := "Uncategorized"

const COLLAPSED_HEIGHT := 28
const EXPANDED_HEIGHT := 120

var editor: BayterekEditor = null

var _header: HBoxContainer
var _collapse_btn: Button
var _tab_bar: TabBar
var _scroll: ScrollContainer
var _cards_container: HBoxContainer

var _collapsed: bool = false

var _tab_meta: Dictionary = {}
var _next_tab_id: int = 0

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	_build_ui()

func _build_ui() -> void:
	# --- Header ---
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 4)
	add_child(_header)

	_collapse_btn = Button.new()
	_collapse_btn.text = "▾"
	_collapse_btn.tooltip_text = "Collapse / expand prefab bar"
	_collapse_btn.custom_minimum_size = Vector2(24, 22)
	_collapse_btn.flat = true
	_collapse_btn.pressed.connect(_on_collapse_pressed)
	_header.add_child(_collapse_btn)

	_tab_bar = TabBar.new()
	_tab_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_NEVER
	_tab_bar.tab_changed.connect(_on_tab_changed)
	_header.add_child(_tab_bar)

	# --- Scroll with cards ---
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, EXPANDED_HEIGHT - COLLAPSED_HEIGHT - 4)
	_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_cards_container = HBoxContainer.new()
	_cards_container.custom_minimum_size = Vector2(0, EXPANDED_HEIGHT - COLLAPSED_HEIGHT - 8)
	_cards_container.add_theme_constant_override("separation", 6)
	_cards_container.size_flags_vertical = SIZE_SHRINK_CENTER
	_scroll.add_child(_cards_container)

	custom_minimum_size = Vector2(0, EXPANDED_HEIGHT)

func init(ed: BayterekEditor) -> void:
	editor = ed

# ============================================================
# COLLAPSE / EXPAND
# ============================================================

func set_collapsed(value: bool, persist: bool = false) -> void:
	_collapsed = value
	_scroll.visible = not _collapsed

	var target_height: int = COLLAPSED_HEIGHT if _collapsed else EXPANDED_HEIGHT
	custom_minimum_size.y = target_height

	_collapse_btn.text = "▸" if _collapsed else "▾"

	# VSplit içindeki layout'u zorla güncelle.
	queue_sort()
	if get_parent() is SplitContainer:
		(get_parent() as SplitContainer).queue_sort()

	if persist and editor and editor.tree:
		editor.tree.prefabs_bar_visible = not _collapsed
		editor.set_dirty(true)

func is_collapsed() -> bool:
	return _collapsed

func _on_collapse_pressed() -> void:
	set_collapsed(not _collapsed, true)

# ============================================================
# REFRESH
# ============================================================

func refresh() -> void:
	if not editor or not editor.tree:
		_clear_cards()
		_tab_bar.clear_tabs()
		_tab_meta.clear()
		return

	_rebuild_tabs()
	_rebuild_cards_for_current_tab()

func refresh_categories() -> void:
	var current_category: String = _get_current_category()
	refresh()

	if not current_category.is_empty():
		for item_id in _tab_meta.keys():
			var meta: Dictionary = _tab_meta[item_id]
			if meta.get("type", "") == "category" and meta.get("category", "") == current_category:
				var idx: int = _find_tab_index_by_id(item_id)
				if idx >= 0:
					_tab_bar.current_tab = idx
					_on_tab_changed(idx)
				return

func _rebuild_tabs() -> void:
	_tab_bar.clear_tabs()
	_tab_meta.clear()
	_next_tab_id = 0

	var used_categories: Dictionary = {}
	var has_uncategorized: bool = false

	for prefab in editor.tree.prefabs:
		if not prefab:
			continue
		var cat: String = ""
		if not prefab.design_id.is_empty():
			var design: BayterekNodeDesign = Bayterek.get_designs_registry().get_design_by_id(prefab.design_id)
			if design:
				cat = design.category.strip_edges()
		if cat.is_empty():
			has_uncategorized = true
		else:
			used_categories[cat] = true

	# All tab
	_add_tab(ALL_TAB_LABEL, {"type": "all"})

	# Category tabs (alphabetical)
	var cat_names: Array = used_categories.keys()
	cat_names.sort()
	for cat in cat_names:
		_add_tab(cat, {"type": "category", "category": cat})

	# Uncategorized (last)
	if has_uncategorized:
		_add_tab(UNCATEGORIZED_LABEL, {"type": "category", "category": ""})

	if _tab_bar.tab_count > 0:
		_tab_bar.current_tab = 0

func _add_tab(label: String, meta: Dictionary) -> void:
	_tab_bar.add_tab(label)
	var idx: int = _tab_bar.tab_count - 1
	_tab_bar.set_tab_metadata(idx, _next_tab_id)
	_tab_meta[_next_tab_id] = meta
	_next_tab_id += 1

func _find_tab_index_by_id(meta_id: int) -> int:
	for i in _tab_bar.tab_count:
		var md = _tab_bar.get_tab_metadata(i)
		if typeof(md) == TYPE_INT and md == meta_id:
			return i
	return -1

func _get_current_meta_id() -> int:
	var idx: int = _tab_bar.current_tab
	if idx < 0 or idx >= _tab_bar.tab_count:
		return -1
	var md = _tab_bar.get_tab_metadata(idx)
	return md if typeof(md) == TYPE_INT else -1

func _get_current_category() -> String:
	var meta_id: int = _get_current_meta_id()
	if meta_id < 0:
		return ""
	var meta: Dictionary = _tab_meta.get(meta_id, {})
	if meta.get("type", "") == "category":
		return meta.get("category", "")
	return ""

func _on_tab_changed(_tab_index: int) -> void:
	_rebuild_cards_for_current_tab()

func _clear_cards() -> void:
	for child in _cards_container.get_children():
		child.queue_free()

func _rebuild_cards_for_current_tab() -> void:
	_clear_cards()

	if not editor or not editor.tree:
		return

	var meta_id: int = _get_current_meta_id()
	if meta_id < 0:
		return

	var meta: Dictionary = _tab_meta.get(meta_id, {})
	var meta_type: String = meta.get("type", "all")
	var filter_category: String = meta.get("category", "")

	for prefab in editor.tree.prefabs:
		if not prefab:
			continue
		if not _prefab_matches_tab(prefab, meta_type, filter_category):
			continue
		_add_card(prefab)

func _prefab_matches_tab(prefab: BayterekPrefab, meta_type: String, filter_category: String) -> bool:
	if meta_type == "all":
		return true

	var design_category: String = ""
	if not prefab.design_id.is_empty():
		var design: BayterekNodeDesign = Bayterek.get_designs_registry().get_design_by_id(prefab.design_id)
		if design:
			design_category = design.category.strip_edges()

	if meta_type == "category":
		return design_category == filter_category

	return true

func _add_card(prefab: BayterekPrefab) -> void:
	var card := BayterekPrefabCard.new()
	_cards_container.add_child(card)
	card.set_prefab(prefab, editor)
	card.rename_requested.connect(_on_card_rename)
	card.duplicate_requested.connect(_on_card_duplicate)
	card.delete_requested.connect(_on_card_delete)

# ============================================================
# CARD SIGNAL HANDLERS
# ============================================================

func _on_card_rename(prefab: BayterekPrefab) -> void:
	card_rename_requested.emit(prefab)

func _on_card_duplicate(prefab: BayterekPrefab) -> void:
	card_duplicate_requested.emit(prefab)

func _on_card_delete(prefab: BayterekPrefab) -> void:
	card_delete_requested.emit(prefab)