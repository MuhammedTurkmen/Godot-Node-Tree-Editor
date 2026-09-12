@tool
class_name BayterekEditor
extends Control
## Graph editörü.

signal closed
signal dirty_changed(editor: BayterekEditor, dirty: bool)

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

var tree: BayterekTree
var tree_path: String
var dirty: bool = false

var tree_view: BayterekTreeView
var context_menu: PopupMenu

var _last_click_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

func load_tree(path: String) -> void:
	tree_path = path
	tree = Bayterek.get_editor_registry().get_tree_by_path(path)

	if not tree:
		push_error("Bayterek: Tree yüklenemedi: %s" % path)
		return

	_create_tree_view()
	_create_context_menu()

func _create_tree_view() -> void:
	tree_view = BayterekTreeView.new()
	tree_view.name = "TreeView"
	add_child(tree_view)
	tree_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree_view.load_tree(tree)
	tree_view.gui_input.connect(_on_tree_view_input)

func _create_context_menu() -> void:
	context_menu = PopupMenu.new()
	context_menu.name = "ContextMenu"

	var submenu := PopupMenu.new()
	submenu.name = "NewNodeSubmenu"
	submenu.add_item("Small", 0)
	submenu.add_item("Medium", 1)
	submenu.add_item("Large", 2)
	submenu.id_pressed.connect(_on_new_node_type_selected)

	context_menu.add_child(submenu)
	context_menu.add_submenu_node_item("New Node", submenu, 0)

	add_child(context_menu)

func _on_tree_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_last_click_pos = event.position
			context_menu.popup_on_parent(Rect2i(
				tree_view.get_screen_transform() * event.position,
				Vector2i.ZERO
			))

func _on_new_node_type_selected(id: int) -> void:
	var node_type: BayterekNode.NodeType
	match id:
		0: node_type = BayterekNode.NodeType.SMALL
		1: node_type = BayterekNode.NodeType.MEDIUM
		2: node_type = BayterekNode.NodeType.LARGE
		_: return

	var pos_in_tree: Vector2 = tree_view.screen_to_tree(_last_click_pos)

	if tree_view.nodes_service:
		tree_view.nodes_service.create_node(pos_in_tree, node_type)
		set_dirty(true)

func set_dirty(is_dirty: bool) -> void:
	if dirty != is_dirty:
		dirty = is_dirty
		dirty_changed.emit(self, dirty)

func request_close() -> void:
	closed.emit()