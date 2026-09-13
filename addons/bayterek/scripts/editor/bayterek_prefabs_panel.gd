@tool
class_name BayterekPrefabPanelEditor
extends VBoxContainer
## Tek bir prefab tipinin listesi.

signal changed

var editor: BayterekEditor

var _filter: LineEdit
var _list: ItemList

func init() -> void:
	add_theme_constant_override("separation", 4)

	# Filter
	_filter = LineEdit.new()
	_filter.placeholder_text = "Filter"
	_filter.size_flags_horizontal = SIZE_EXPAND_FILL
	_filter.text_changed.connect(_on_filter_changed)
	add_child(_filter)

	# Liste
	_list = ItemList.new()
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_list.size_flags_vertical = SIZE_EXPAND_FILL
	_list.max_columns = 0
	_list.same_column_width = true
	_list.fixed_column_width = 100
	_list.icon_mode = ItemList.ICON_MODE_TOP
	_list.fixed_icon_size = Vector2i(64, 64)
	add_child(_list)

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

func _make_icon(prefab) -> Texture2D:
	if prefab.icon and prefab.icon is Texture2D:
		return prefab.icon
	return null

func _index_to_type(idx: int) -> BayterekNode.NodeType:
	match idx:
		0: return BayterekNode.NodeType.SMALL
		1: return BayterekNode.NodeType.MEDIUM
		2: return BayterekNode.NodeType.LARGE
		3: return BayterekNode.NodeType.DECORATION
	return BayterekNode.NodeType.SMALL

func _on_filter_changed(_text: String) -> void:
	refresh()