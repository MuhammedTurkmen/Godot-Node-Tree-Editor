@tool
class_name BayterekTreeHierarchy
extends VBoxContainer
## Left panel hierarchy — node list.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

signal changed

var editor: BayterekEditor
var tree_view: BayterekTreeView

var _tree: Tree
var _root_item: TreeItem
var _nodes_item: TreeItem

# node_id -> TreeItem
var _id_to_item: Dictionary = {}

## Flag to prevent selection echo from canvas
var _updating_selection_from_canvas: bool = false

func _ready() -> void:
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 0)

func init(p_tree_view: BayterekTreeView) -> void:
	tree_view = p_tree_view

	var header := HBoxContainer.new()
	add_child(header)

	var title := Label.new()
	title.text = "Hierarchy"
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	header.add_child(title)

	_tree = Tree.new()
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.size_flags_horizontal = SIZE_EXPAND_FILL
	_tree.size_flags_vertical = SIZE_EXPAND_FILL
	_tree.custom_minimum_size = Vector2(0, 150)
	add_child(_tree)

	_root_item = _tree.create_item()

	_nodes_item = _root_item.create_child()
	_nodes_item.set_text(0, "Nodes")
	_nodes_item.set_selectable(0, false)

	_tree.item_selected.connect(_on_item_selected)
	_tree.item_activated.connect(_on_item_activated)
	_tree.button_clicked.connect(_on_item_button_clicked)

	if tree_view:
		tree_view.node_created.connect(_on_node_created)
		tree_view.node_deleted.connect(_on_node_deleted)
		tree_view.selection_changed.connect(_on_selection_changed)

	if editor:
		editor.node_root_changed.connect(_on_node_root_changed)

	_refresh()

func _refresh() -> void:
	_clear_items()
	if not tree_view or not tree_view.nodes_service:
		return

	for node in tree_view.nodes_service.get_all_nodes():
		_add_node_item(node)

	_update_header()

func _clear_items() -> void:
	if not _nodes_item:
		return

	while _nodes_item.get_child_count() > 0:
		var child: TreeItem = _nodes_item.get_child(0)
		_nodes_item.remove_child(child)
		child.free()

	_id_to_item.clear()

func _update_header() -> void:
	pass

# ============================================================
# DISPLAY HELPERS
# ============================================================

## Builds the display text for a node in the hierarchy.
## Format: "[★ ]<name>" where name falls back to "Node <id>".
func _build_node_label(node: BayterekNodeButton) -> String:
	if not node or not node.node_data:
		return "Node ?"

	var prefix: String = ""
	if node.node_data.is_root:
		prefix = "★  "

	var display_name: String = node.node_data.name.strip_edges()
	if display_name.is_empty():
		display_name = "Node %d" % node.id

	return "%s%s" % [prefix, display_name]

## Sets the tooltip text on a hierarchy item from the node's description.
## Falls back to the node name if description is empty.
func _apply_item_tooltip(item: TreeItem, node: BayterekNodeButton) -> void:
	if not item or not node or not node.node_data:
		return

	var tooltip: String = node.node_data.description.strip_edges()
	if tooltip.is_empty():
		item.set_tooltip_text(0, "")
	else:
		item.set_tooltip_text(0, tooltip)

## Refreshes text + color of an existing hierarchy item for a node.
func _update_item_visual(node: BayterekNodeButton) -> void:
	if not node or not _id_to_item.has(node.id):
		return

	var item: TreeItem = _id_to_item[node.id]
	if not item:
		return

	item.set_text(0, _build_node_label(node))

	if node.node_data and node.node_data.is_root:
		item.set_custom_color(0, Color(1.0, 0.85, 0.4))
	else:
		item.set_custom_color(0, Color(0.85, 0.85, 0.85))

	_apply_item_tooltip(item, node)

# ============================================================
# NODE ADD / REMOVE
# ============================================================

func _on_node_created(node: BayterekNodeButton) -> void:
	_add_node_item(node)
	_update_header()

func _on_node_deleted(node: BayterekNodeButton) -> void:
	if not node:
		return
	_remove_item_for_node(node.id)
	_update_header()

func _add_node_item(node: BayterekNodeButton) -> void:
	if not _nodes_item or not node:
		return
	if _id_to_item.has(node.id):
		return

	var item := _nodes_item.create_child()
	item.set_text(0, _build_node_label(node))
	item.set_metadata(0, node.id)

	if node.node_data and node.node_data.is_root:
		item.set_custom_color(0, Color(1.0, 0.85, 0.4))
	else:
		item.set_custom_color(0, Color(0.85, 0.85, 0.85))

	_apply_item_tooltip(item, node)

	var theme := EditorInterface.get_editor_theme()
	var lock_icon_name: String = "Lock" if node.node_data.locked else "Unlock"
	item.add_button(0, theme.get_icon(lock_icon_name, Bayterek.ICON_THEME), 0)
	item.set_button_tooltip_text(0, 0, "Lock/Unlock")

	item.add_button(0, theme.get_icon("Close", Bayterek.ICON_THEME), 1)
	item.set_button_tooltip_text(0, 1, "Delete")

	_id_to_item[node.id] = item

func _remove_item_for_node(node_id: int) -> void:
	if not _id_to_item.has(node_id):
		return
	var item: TreeItem = _id_to_item[node_id]
	if item:
		if _nodes_item and item.get_parent() == _nodes_item:
			_nodes_item.remove_child(item)
		item.free()
	_id_to_item.erase(node_id)
	_update_header()

# ============================================================
# PUBLIC REFRESH API
# ============================================================

## Called by the editor when a node's name or other display-affecting
## property changes.
func refresh_node_display(node: BayterekNodeButton) -> void:
	_update_item_visual(node)

## Called by the editor when the whole hierarchy needs to rebuild
## (e.g. after a large structural change).
func refresh_all() -> void:
	_refresh()

# ============================================================
# SELECTION SYNC
# ============================================================

func _on_item_selected() -> void:
	# Skip if this is an echo from canvas selection
	if _updating_selection_from_canvas:
		return

	if not tree_view:
		return
	var selected := _tree.get_selected()
	if not selected:
		return

	var meta = selected.get_metadata(0)
	if typeof(meta) != TYPE_INT:
		return

	var node_id: int = meta
	var node: BayterekNodeButton = tree_view.nodes_service.get_node(node_id)
	if not node:
		return

	if tree_view.selected_nodes.size() == 1 and tree_view.selected_nodes[0] == node:
		return

	var ctrl: bool = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
	tree_view.select_node(node, ctrl)

func _on_item_activated() -> void:
	# Selection
	_on_item_selected()

	# Camera focus
	var selected := _tree.get_selected()
	if not selected:
		return

	var meta = selected.get_metadata(0)
	if typeof(meta) != TYPE_INT:
		return

	var node_id: int = meta
	if not tree_view or not tree_view.nodes_service:
		return

	var node: BayterekNodeButton = tree_view.nodes_service.get_node(node_id)
	if not node:
		return

	if tree_view.camera:
		tree_view.camera.focus_on(node.node_data.position, 1.0)

func _on_selection_changed(selected: Array) -> void:
	# Came from canvas — suppress echo
	_updating_selection_from_canvas = true

	_tree.deselect_all()

	if not selected.is_empty():
		for node in selected:
			if not is_instance_valid(node):
				continue
			if _id_to_item.has(node.id):
				var item: TreeItem = _id_to_item[node.id]
				if item:
					item.select(0)

	_updating_selection_from_canvas = false

# ============================================================
# BUTTON ACTIONS
# ============================================================

func _on_item_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return

	var meta = item.get_metadata(0)
	if typeof(meta) != TYPE_INT:
		return

	var node_id: int = meta
	var node: BayterekNodeButton = tree_view.nodes_service.get_node(node_id)
	if not node:
		return

	if id == 0:
		node.node_data.locked = not node.node_data.locked
		var icon_name: String = "Lock" if node.node_data.locked else "Unlock"
		item.set_button(0, 0, EditorInterface.get_editor_theme().get_icon(icon_name, Bayterek.ICON_THEME))

		if node.has_method("refresh_visuals"):
			node.refresh_visuals()

		if node.node_data.locked and tree_view:
			if tree_view.selected_nodes.has(node):
				tree_view.selected_nodes.erase(node)
				node.set_selected(false)
				tree_view.selection_changed.emit(tree_view.selected_nodes)

		changed.emit()
	elif id == 1:
		_do_delete_node(node)

func _do_delete_node(node: BayterekNodeButton) -> void:
	if not tree_view or not node:
		return

	if node.node_data and node.node_data.locked:
		return

	if tree_view.undo_redo_provider and tree_view.undo_redo_provider.undo_redo:
		tree_view.select_node(node)
		tree_view.delete_selected()
	else:
		tree_view.connections_service.remove_all_connections_of(node)
		tree_view.nodes_service.delete_node(node)
		tree_view.node_deleted.emit(node)

	_remove_item_for_node(node.id)
	changed.emit()

# ============================================================
# ROOT VISUAL SYNC
# ============================================================

func _on_node_root_changed(node: BayterekNodeButton) -> void:
	_update_item_visual(node)