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

var undo_redo: UndoRedo

var tree_view: BayterekTreeView
var context_menu: PopupMenu
var menu_bar: HBoxContainer

var _last_click_pos: Vector2 = Vector2.ZERO
var _last_save_time: int = 0

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

func load_tree(path: String) -> void:
	tree_path = path
	tree = Bayterek.get_editor_registry().get_tree_by_path(path)

	if not tree:
		push_error("Bayterek: Tree yüklenemedi: %s" % path)
		return

	# tree_state garanti altına al
	if not tree.tree_state:
		tree.tree_state = BayterekTreeState.new()

	undo_redo = UndoRedo.new()

	_build_ui()
	_create_tree_view()
	_create_context_menu()

	set_dirty(false)

func _build_ui() -> void:
	menu_bar = HBoxContainer.new()
	menu_bar.name = "MenuBar"
	menu_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(menu_bar)

	var file_btn := MenuButton.new()
	file_btn.text = "File"
	var file_popup: PopupMenu = file_btn.get_popup()
	file_popup.add_item("Save", 0)
	file_popup.add_item("Close", 1)
	file_popup.id_pressed.connect(_on_file_menu_pressed)
	menu_bar.add_child(file_btn)

	var edit_btn := MenuButton.new()
	edit_btn.text = "Edit"
	var edit_popup: PopupMenu = edit_btn.get_popup()
	edit_popup.add_item("Undo", 0)
	edit_popup.add_item("Redo", 1)
	edit_popup.id_pressed.connect(_on_edit_menu_pressed)
	menu_bar.add_child(edit_btn)

func _create_tree_view() -> void:
	tree_view = BayterekTreeView.new()
	tree_view.name = "TreeView"
	add_child(tree_view)
	tree_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree_view.offset_top = 28
	tree_view.load_tree(tree)
	tree_view.gui_input.connect(_on_tree_view_input)
	tree_view.undo_redo_provider = self
	tree_view.changed.connect(_on_tree_view_changed)

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

# ============================================================
# INPUT
# ============================================================

func _on_tree_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_last_click_pos = event.position
			context_menu.popup_on_parent(Rect2i(
				tree_view.get_screen_transform() * event.position,
				Vector2i.ZERO
			))

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	var key: int = event.keycode
	var ctrl: bool = event.ctrl_pressed or event.meta_pressed
	var shift: bool = event.shift_pressed

	if ctrl and key == KEY_S:
		save_tree()
		get_viewport().set_input_as_handled()
	elif ctrl and not shift and key == KEY_Z:
		do_undo()
		get_viewport().set_input_as_handled()
	elif ctrl and (key == KEY_Y or (shift and key == KEY_Z)):
		do_redo()
		get_viewport().set_input_as_handled()

# ============================================================
# NODE OLUŞTURMA
# ============================================================

func _on_new_node_type_selected(id: int) -> void:
	var node_type: BayterekNode.NodeType
	match id:
		0: node_type = BayterekNode.NodeType.SMALL
		1: node_type = BayterekNode.NodeType.MEDIUM
		2: node_type = BayterekNode.NodeType.LARGE
		_: return

	var pos_in_tree: Vector2 = tree_view.screen_to_tree(_last_click_pos)

	if not tree_view.nodes_service:
		return

	undo_redo.create_action("Create Node")
	undo_redo.add_do_method(_do_create_node.bind(pos_in_tree, node_type))
	undo_redo.add_undo_method(_undo_create_node)
	undo_redo.commit_action()

func _do_create_node(pos_in_tree: Vector2, node_type: BayterekNode.NodeType) -> void:
	tree_view.nodes_service.create_node(pos_in_tree, node_type)
	set_dirty(true)

func _undo_create_node() -> void:
	var all_nodes: Array = tree_view.nodes_service.get_all_nodes()
	if all_nodes.is_empty():
		return
	var last_node: BayterekNodeButton = all_nodes[all_nodes.size() - 1]
	tree_view.nodes_service.delete_node(last_node)
	set_dirty(true)

# ============================================================
# FILE MENU
# ============================================================

func _on_file_menu_pressed(id: int) -> void:
	match id:
		0: save_tree()
		1: request_close()

# ============================================================
# EDIT MENU
# ============================================================

func _on_edit_menu_pressed(id: int) -> void:
	match id:
		0: do_undo()
		1: do_redo()

func do_undo() -> void:
	if undo_redo and undo_redo.has_undo():
		undo_redo.undo()
		set_dirty(true)

func do_redo() -> void:
	if undo_redo and undo_redo.has_redo():
		undo_redo.redo()
		set_dirty(true)

# ============================================================
# KAYDETME
# ============================================================

func save_tree() -> void:
	if not tree:
		return

	# tree_state null ise oluştur
	if not tree.tree_state:
		tree.tree_state = BayterekTreeState.new()

	tree.tree_state.version = tree.version

	var err: Error = ResourceSaver.save(tree, tree_path)
	if err != OK:
		push_error("Bayterek: Tree kaydedilemedi (%d)" % err)
		return

	_last_save_time = Time.get_ticks_msec()
	set_dirty(false)
	print("Bayterek: Tree kaydedildi: ", tree_path)

# ============================================================
# DURUM
# ============================================================

func set_dirty(is_dirty: bool) -> void:
	if dirty != is_dirty:
		dirty = is_dirty
		dirty_changed.emit(self, dirty)

func get_last_modified_time() -> String:
	if _last_save_time == 0:
		return "hiç kaydedilmedi"

	var elapsed: int = Time.get_ticks_msec() - _last_save_time
	var seconds: int = elapsed / 1000
	var minutes: int = seconds / 60
	var hours: int = minutes / 60

	if hours > 0:
		return "%d saat önce" % hours
	elif minutes > 0:
		return "%d dakika önce" % minutes
	else:
		return "%d saniye önce" % seconds

func _on_tree_view_changed() -> void:
	set_dirty(true)

func request_close() -> void:
	closed.emit()