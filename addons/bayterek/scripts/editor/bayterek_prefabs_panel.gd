@tool
class_name BayterekPrefabPanelEditor
extends VBoxContainer
## Single prefab type's list.

signal changed

var editor: BayterekEditor

var _filter: LineEdit
var _list: ItemList
var _context_menu: PopupMenu

func init() -> void:
	add_theme_constant_override("separation", 4)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL

	_filter = LineEdit.new()
	_filter.placeholder_text = "Filter"
	_filter.size_flags_horizontal = SIZE_EXPAND_FILL
	_filter.text_changed.connect(_on_filter_changed)
	add_child(_filter)

	_list = ItemList.new()
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_list.size_flags_vertical = SIZE_EXPAND_FILL
	_list.custom_minimum_size = Vector2(0, 80)
	_list.max_columns = 0
	_list.same_column_width = true
	_list.fixed_column_width = 100
	_list.icon_mode = ItemList.ICON_MODE_TOP
	_list.fixed_icon_size = Vector2i(64, 64)
	_list.set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)
	_list.item_activated.connect(_on_item_activated)
	_list.item_clicked.connect(_on_item_clicked)
	add_child(_list)

	_context_menu = PopupMenu.new()
	_context_menu.add_item("Inspect", 0)
	_context_menu.add_item("Rename", 1)
	_context_menu.add_item("Duplicate", 2)
	_context_menu.add_separator()
	_context_menu.add_item("Reset Nodes to Defaults", 3)
	_context_menu.add_separator()
	_context_menu.add_item("Delete Prefab...", 4)
	_context_menu.id_pressed.connect(_on_context_menu_pressed)
	add_child(_context_menu)

	visibility_changed.connect(_on_visibility_changed)

# ============================================================
# REFRESH
# ============================================================

func refresh() -> void:
	if not editor or not editor.tree:
		return
	_list.clear()
	var panel_index: int = get_index()
	var node_type: BayterekNode.NodeType = _index_to_type(panel_index)
	var prefabs_dict: Dictionary = editor.tree.prefabs
	if not prefabs_dict.has(node_type):
		return
	var prefabs_list: Array = prefabs_dict[node_type]
	var filter_text: String = _filter.text.strip_edges().to_lower()
	for prefab in prefabs_list:
		if not filter_text.is_empty():
			if not prefab.node_name.to_lower().contains(filter_text):
				continue
		_list.add_item(prefab.node_name, _make_icon(prefab), true)
		var idx: int = _list.item_count - 1
		_list.set_item_metadata(idx, prefab)
		if not prefab.reference_id.is_empty() and prefab.get_nodes().is_empty():
			_list.set_item_custom_fg_color(idx, Color(0.85, 0.6, 0.3))

func _on_visibility_changed() -> void:
	if visible:
		refresh()

# ============================================================
# ICON
# ============================================================

func _make_icon(prefab) -> Texture2D:
	if prefab.icon and prefab.icon is Texture2D:
		return prefab.icon
	return _make_fallback_icon(prefab.type)

func _make_fallback_icon(t: int) -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var color: Color = _type_color(t)
	img.fill(color)
	var border_color := Color(1, 1, 1, 0.6)
	for x in 64:
		img.set_pixel(x, 0, border_color)
		img.set_pixel(x, 63, border_color)
	for y in 64:
		img.set_pixel(0, y, border_color)
		img.set_pixel(63, y, border_color)
	return ImageTexture.create_from_image(img)

func _type_color(t: int) -> Color:
	match t:
		0: return Color(0.4, 0.7, 1.0, 0.85)
		1: return Color(0.4, 1.0, 0.5, 0.85)
		2: return Color(1.0, 0.7, 0.4, 0.85)
		3: return Color(0.7, 0.5, 1.0, 0.85)
	return Color.WHITE

func _index_to_type(idx: int) -> BayterekNode.NodeType:
	match idx:
		0: return BayterekNode.NodeType.SMALL
		1: return BayterekNode.NodeType.MEDIUM
		2: return BayterekNode.NodeType.LARGE
		3: return BayterekNode.NodeType.DECORATION
	return BayterekNode.NodeType.SMALL

func _on_filter_changed(_text: String) -> void:
	refresh()

# ============================================================
# DRAG & DROP
# ============================================================

func _get_drag_data(_at_position: Vector2) -> Variant:
	var selected: PackedInt32Array = _list.get_selected_items()
	if selected.is_empty():
		return null
	var idx: int = selected[0]
	var prefab = _list.get_item_metadata(idx)
	if not prefab:
		return null
	var preview := Label.new()
	preview.text = prefab.node_name
	preview.add_theme_color_override("font_color", Color.WHITE)
	preview.add_theme_color_override("font_shadow_color", Color.BLACK)
	preview.add_theme_constant_override("shadow_offset_x", 1)
	preview.add_theme_constant_override("shadow_offset_y", 1)
	set_drag_preview(preview)
	return {"type": "prefab", "prefab": prefab}

func _can_drop_data(_at_position: Vector2, _data: Variant) -> bool:
	return false

func _drop_data(_at_position: Vector2, _data: Variant) -> void:
	pass

# ============================================================
# ITEM ACTIVATED
# ============================================================

func _on_item_activated(index: int) -> void:
	if not editor:
		return
	var prefab = _list.get_item_metadata(index)
	if not prefab is BayterekPrefab:
		return
	if editor.inspector:
		editor.inspector.inspect_prefab(prefab)
		if editor.tab_container:
			editor.tab_container.current_tab = 0

# ============================================================
# CONTEXT MENU
# ============================================================

func _on_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_RIGHT:
		return
	_list.select(index)
	_context_menu.popup_on_parent(Rect2i(
		_list.get_screen_position() + at_position,
		Vector2i.ZERO
	))

func _on_context_menu_pressed(id: int) -> void:
	var selected: PackedInt32Array = _list.get_selected_items()
	if selected.is_empty():
		return
	var idx: int = selected[0]
	var prefab = _list.get_item_metadata(idx)
	if not prefab is BayterekPrefab:
		return
	match id:
		0:
			if editor.inspector:
				editor.inspector.inspect_prefab(prefab)
				if editor.tab_container:
					editor.tab_container.current_tab = 0
		1: _rename_prefab(prefab)
		2: _duplicate_prefab(prefab)
		3: _reset_nodes_to_defaults(prefab)
		4: _request_delete(prefab)

func _rename_prefab(prefab: BayterekPrefab) -> void:
	prefab.set_node_name(prefab.node_name + " Renamed")
	refresh()
	if editor:
		editor.set_dirty(true)

func _duplicate_prefab(prefab: BayterekPrefab) -> void:
	if not editor or not editor.tree:
		return
	var copy := BayterekPrefab.new()
	copy.reference_id = ""
	copy.type = prefab.type
	copy.node_name = prefab.node_name + " Copy"
	copy.description = prefab.description
	copy.icon = prefab.icon
	copy.border_normal = prefab.border_normal
	copy.border_intermediate = prefab.border_intermediate
	copy.border_active = prefab.border_active
	copy.attributes = prefab.attributes.duplicate(true)
	copy.max_allocations = prefab.max_allocations
	var t: int = copy.type
	if not editor.tree.prefabs.has(t):
		editor.tree.prefabs[t] = []
	editor.tree.prefabs[t].append(copy)
	editor.set_dirty(true)
	refresh()

func _reset_nodes_to_defaults(prefab: BayterekPrefab) -> void:
	if not editor or not editor.tree_view or not editor.tree_view.prefabs_service:
		return
	var service = editor.tree_view.prefabs_service
	for node in prefab.get_nodes():
		if is_instance_valid(node):
			service.reset_node_to_prefab_defaults(node)
	editor.set_dirty(true)
	if editor.inspector:
		editor.inspector.refresh_attributes()

func _request_delete(prefab: BayterekPrefab) -> void:
	if editor:
		editor.request_delete_prefab(prefab)