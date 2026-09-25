@tool
class_name BayterekNodeSearch
extends Popup
## Quick node search popup.
##
## Fuzzy-searches all nodes in the current tree by name, id, or
## description. Selecting a result selects the node and focuses the
## camera on it.

signal node_chosen(node: BayterekNodeButton)

var tree_view: BayterekTreeView = null

var _search_input: LineEdit
var _result_list: ItemList
var _hint_label: Label

# list_index -> BayterekNodeButton
var _id_to_node: Dictionary = {}

func _init() -> void:
	title = "Search Node"
	size = Vector2i(420, 320)
	unresizable = false
	transient = true
	exclusive = false
	popup_hide.connect(_on_popup_hide)

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Type to search nodes..."
	_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_input.text_changed.connect(_on_search_changed)
	_search_input.text_submitted.connect(_on_submit)
	vbox.add_child(_search_input)

	_result_list = ItemList.new()
	_result_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_list.item_activated.connect(_on_item_activated)
	_result_list.gui_input.connect(_on_list_input)
	vbox.add_child(_result_list)

	_hint_label = Label.new()
	_hint_label.text = "Enter to jump • Esc to close"
	_hint_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_hint_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_hint_label)

# ============================================================
# PUBLIC API
# ============================================================

func open_for(tree_view_ref: BayterekTreeView) -> void:
	tree_view = tree_view_ref
	_search_input.text = ""
	_populate("")
	popup_centered(Vector2i(420, 320))
	_search_input.call_deferred("grab_focus")

# ============================================================
# SEARCH
# ============================================================

func _on_search_changed(new_text: String) -> void:
	_populate(new_text)

func _populate(query: String) -> void:
	_result_list.clear()
	_id_to_node.clear()

	if not tree_view or not tree_view.nodes_service:
		_hint_label.text = "No tree loaded"
		return

	var all_nodes: Array = tree_view.nodes_service.get_all_nodes()
	var q: String = query.strip_edges()

	# Build a lightweight entry list.
	var entries: Array = []
	for node in all_nodes:
		if not is_instance_valid(node) or not node.node_data:
			continue
		var display_name: String = node.node_data.name.strip_edges()
		if display_name.is_empty():
			display_name = "Node %d" % node.id
		var description: String = node.node_data.description.strip_edges()
		entries.append({
			"node": node,
			"name": display_name,
			"desc": description,
		})

	# If no query, show everything.
	if q.is_empty():
		entries.sort_custom(func(a, b): return a["name"].naturalnocasecmp_to(b["name"]) < 0)
		for entry in entries:
			_add_result_item(entry)
		_hint_label.text = "%d node%s • Enter to jump • Esc to close" % [
			entries.size(), "s" if entries.size() != 1 else ""]
		if _result_list.item_count > 0:
			_result_list.select(0)
		return

	# Fuzzy match against name + description.
	var fuzzy := BayterekFuzzySearch.new()
	fuzzy.allow_subsequences = true

	var matched: Array = []
	for entry in entries:
		var score_name: int = fuzzy.score(q, entry["name"])
		var score_desc: int = 0
		if not entry["desc"].is_empty():
			score_desc = fuzzy.score(q, entry["desc"]) / 2  # weaker weight
		var best: int = maxi(score_name, score_desc)
		if best > 0:
			matched.append({"entry": entry, "score": best})

	matched.sort_custom(func(a, b): return a["score"] > b["score"])

	for m in matched:
		_add_result_item(m["entry"])

	_hint_label.text = "%d result%s • Enter to jump • Esc to close" % [
		matched.size(), "s" if matched.size() != 1 else ""]

	if _result_list.item_count > 0:
		_result_list.select(0)

func _add_result_item(entry: Dictionary) -> void:
	var node: BayterekNodeButton = entry["node"]
	var label: String = entry["name"]
	if not entry["desc"].is_empty():
		var short_desc: String = entry["desc"]
		if short_desc.length() > 40:
			short_desc = short_desc.substr(0, 40) + "…"
		label += "  —  " + short_desc

	label += "    [%d]" % node.id

	var idx: int = _result_list.add_item(label)
	_id_to_node[idx] = node

# ============================================================
# SELECTION
# ============================================================

func _on_submit(_text: String) -> void:
	_activate_selected()

func _on_item_activated(_index: int) -> void:
	_activate_selected()

func _activate_selected() -> void:
	var selected: PackedInt32Array = _result_list.get_selected_items()
	if selected.is_empty():
		return
	var node: BayterekNodeButton = _id_to_node.get(selected[0], null)
	if not is_instance_valid(node):
		return
	node_chosen.emit(node)
	hide()

func _on_list_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			hide()
			get_viewport().set_input_as_handled()

func _on_popup_hide() -> void:
	_search_input.text = ""