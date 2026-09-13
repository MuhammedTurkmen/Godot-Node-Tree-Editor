@tool
class_name BayterekPrefabPanelEditor
extends VBoxContainer
## Single prefab type's list.

signal changed

var editor: BayterekEditor

var _filter: LineEdit
var _list: ItemList

func init() -> void:
	add_theme_constant_override("separation", 4)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL

	# Filter
	_filter = LineEdit.new()
	_filter.placeholder_text = "Filter"
	_filter.size_flags_horizontal = SIZE_EXPAND_FILL
	_filter.text_changed.connect(_on_filter_changed)
	add_child(_filter)

	# List
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
	add_child(_list)

func refresh() -> void:
	print("[PrefabPanel] refresh() index=", get_index(),
		" | editor=", editor,
		" | tree=", (editor.tree if editor else null),
		" | self.visible=", visible,
		" | list_size=", _list.size,
		" | item_count_before=", _list.item_count)

	if not editor or not editor.tree:
		print("    → SKIP: editor or tree is null")
		return

	_list.clear()

	var panel_index: int = get_index()
	var node_type: BayterekNode.NodeType = _index_to_type(panel_index)

	var prefabs_dict: Dictionary = editor.tree.prefabs
	print("    → prefabs_dict keys=", prefabs_dict.keys())
	if not prefabs_dict.has(node_type):
		print("    → no prefabs for node_type=", node_type)
		return

	var prefabs_list: Array = prefabs_dict[node_type]
	print("    → prefabs_list.size=", prefabs_list.size())

	var filter_text: String = _filter.text.strip_edges().to_lower()

	for prefab in prefabs_list:
		if not filter_text.is_empty():
			if not prefab.node_name.to_lower().contains(filter_text):
				continue

		_list.add_item(prefab.node_name, _make_icon(prefab), true)
		var idx: int = _list.item_count - 1
		_list.set_item_metadata(idx, prefab)
		print("    → added: ", prefab.node_name, " (items now=", _list.item_count, ")")

	print("    → refresh DONE, item_count_after=", _list.item_count)

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
		0: return Color(0.4, 0.7, 1.0, 0.85)      # SMALL
		1: return Color(0.4, 1.0, 0.5, 0.85)      # MEDIUM
		2: return Color(1.0, 0.7, 0.4, 0.85)      # LARGE
		3: return Color(0.7, 0.5, 1.0, 0.85)      # DECORATION
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
# ITEM ACTIVATED (double-click)
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