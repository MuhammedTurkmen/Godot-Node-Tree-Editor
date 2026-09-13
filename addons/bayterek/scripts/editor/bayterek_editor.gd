@tool
class_name BayterekEditor
extends Control
## Graph editor + left hierarchy + right panel + bottom prefabs bar.

signal closed
signal dirty_changed(editor: BayterekEditor, dirty: bool)

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

const LEFT_PANEL_WIDTH := 200.0
const RIGHT_PANEL_WIDTH := 320.0
const MENU_HEIGHT := 28.0
const SAFETY_MARGIN := 40.0

var tree: BayterekTree
var tree_path: String
var dirty: bool = false

var undo_redo: UndoRedo

var h_split: HSplitContainer
var hierarchy: BayterekTreeHierarchy
var center_v_split: VSplitContainer
var left_container: VBoxContainer
var menu_bar: HBoxContainer
var tree_view: BayterekTreeView
var tab_container: TabContainer
var inspector: BayterekTreeEditorInspector
var settings_editor: BayterekSettingsEditor
var attributes_editor: BayterekAttributesEditor

var bottom_container: VBoxContainer
var prefabs_bar: BayterekPrefabsBar
var prefabs_panel: Control

var context_menu: PopupMenu

var _last_click_pos: Vector2 = Vector2.ZERO
var _last_save_time: int = 0
var _resize_debounce: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_on_editor_resized")

func _process(delta: float) -> void:
	if _resize_debounce > 0.0:
		_resize_debounce -= delta
		if _resize_debounce <= 0.0:
			_resize_debounce = 0.0
			_apply_min_size_to_tree()

func _on_editor_resized() -> void:
	_resize_debounce = 0.2

func _apply_min_size_to_tree() -> void:
	if not tree or not tree_view:
		return

	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var canvas_w: float = max(400.0, vp_size.x - LEFT_PANEL_WIDTH - RIGHT_PANEL_WIDTH - SAFETY_MARGIN)
	var canvas_h: float = max(300.0, vp_size.y - MENU_HEIGHT - SAFETY_MARGIN)

	var changed: bool = false

	if tree.size.x < canvas_w:
		tree.size.x = canvas_w
		changed = true
	if tree.size.y < canvas_h:
		tree.size.y = canvas_h
		changed = true

	if changed:
		_apply_size_to_view()
		set_dirty(true)

func load_tree(path: String) -> void:
	tree_path = path
	tree = Bayterek.get_editor_registry().get_tree_by_path(path)

	if not tree:
		push_error("Bayterek: Tree load failed: %s" % path)
		return

	if not tree.tree_state:
		tree.tree_state = BayterekTreeState.new()

	undo_redo = UndoRedo.new()

	_build_ui()
	_create_tree_view()
	_create_prefabs_bar()
	_create_context_menu()

	_restore_split_offsets()
	_connect_split_signals()

	call_deferred("_apply_min_size_to_tree")

	set_dirty(false)

func _restore_split_offsets() -> void:
	if h_split and tree:
		var v = tree.get("hierarchy_split_offset")
		if v == null or typeof(v) != TYPE_INT:
			v = 200
			tree.set("hierarchy_split_offset", 200)
		h_split.split_offset = int(v)

	if center_v_split and tree:
		var v2 = tree.get("prefabs_split_offset")
		if v2 == null or typeof(v2) != TYPE_INT:
			v2 = -180
			tree.set("prefabs_split_offset", -180)
		center_v_split.split_offset = int(v2)

func _connect_split_signals() -> void:
	if h_split:
		h_split.dragged.connect(_on_h_split_dragged)
	if center_v_split:
		center_v_split.dragged.connect(_on_bottom_split_dragged)

# ============================================================
# UI SETUP
# ============================================================

func _build_ui() -> void:
	h_split = HSplitContainer.new()
	h_split.name = "HSplit"
	h_split.size_flags_horizontal = SIZE_EXPAND_FILL
	h_split.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(h_split)
	h_split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h_split.split_offset = 200

	hierarchy = BayterekTreeHierarchy.new()
	hierarchy.name = "Hierarchy"
	hierarchy.custom_minimum_size = Vector2(180, 0)
	hierarchy.size_flags_vertical = SIZE_EXPAND_FILL
	h_split.add_child(hierarchy)

	center_v_split = VSplitContainer.new()
	center_v_split.name = "CenterVSplit"
	center_v_split.size_flags_horizontal = SIZE_EXPAND_FILL
	center_v_split.size_flags_vertical = SIZE_EXPAND_FILL
	center_v_split.split_offset = -180
	h_split.add_child(center_v_split)

	left_container = VBoxContainer.new()
	left_container.name = "LeftContainer"
	left_container.size_flags_horizontal = SIZE_EXPAND_FILL
	left_container.size_flags_vertical = SIZE_EXPAND_FILL
	left_container.add_theme_constant_override("separation", 0)
	center_v_split.add_child(left_container)

	menu_bar = HBoxContainer.new()
	menu_bar.name = "MenuBar"
	menu_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	left_container.add_child(menu_bar)

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

	tab_container = TabContainer.new()
	tab_container.name = "TabContainer"
	tab_container.custom_minimum_size = Vector2(320, 0)
	tab_container.size_flags_vertical = SIZE_EXPAND_FILL
	h_split.add_child(tab_container)

	inspector = BayterekTreeEditorInspector.new()
	inspector.name = "Inspector"
	inspector.size_flags_horizontal = SIZE_EXPAND_FILL
	inspector.size_flags_vertical = SIZE_EXPAND_FILL
	tab_container.add_child(inspector)
	tab_container.set_tab_title(0, "Inspector")

	settings_editor = BayterekSettingsEditor.new()
	settings_editor.name = "Settings"
	settings_editor.size_flags_horizontal = SIZE_EXPAND_FILL
	settings_editor.size_flags_vertical = SIZE_EXPAND_FILL
	tab_container.add_child(settings_editor)
	tab_container.set_tab_title(1, "Settings")

	attributes_editor = BayterekAttributesEditor.new()
	attributes_editor.name = "Attributes"
	attributes_editor.size_flags_horizontal = SIZE_EXPAND_FILL
	attributes_editor.size_flags_vertical = SIZE_EXPAND_FILL
	tab_container.add_child(attributes_editor)
	tab_container.set_tab_title(2, "Attributes")

func _create_tree_view() -> void:
	tree_view = BayterekTreeView.new()
	tree_view.name = "TreeView"
	tree_view.size_flags_horizontal = SIZE_EXPAND_FILL
	tree_view.size_flags_vertical = SIZE_EXPAND_FILL
	left_container.add_child(tree_view)
	tree_view.load_tree(tree)
	tree_view.gui_input.connect(_on_tree_view_input)
	tree_view.undo_redo_provider = self
	tree_view.changed.connect(_on_tree_view_changed)
	tree_view.selection_changed.connect(_on_selection_changed)
	tree_view.node_moved.connect(_on_node_moved)
	tree_view.prefab_dropped.connect(_on_prefab_dropped_from_canvas)

	if hierarchy:
		hierarchy.editor = self
		hierarchy.init(tree_view)

	if inspector:
		inspector.editor = self
		inspector.init(tree_view)

	if settings_editor:
		settings_editor.editor = self
		settings_editor.init()
		settings_editor.load_tree(tree)
		settings_editor.size_changed.connect(_on_settings_size_changed)
		settings_editor.background_changed.connect(_on_settings_background_changed)
		settings_editor.border_scale_changed.connect(_on_settings_border_scale_changed)

	if attributes_editor:
		attributes_editor.editor = self
		attributes_editor.init()
		attributes_editor.attribute_changed.connect(_on_attr_changed)
		attributes_editor.attribute_removed.connect(_on_attr_removed)
		attributes_editor.attributes_list_changed.connect(_on_attrs_list_changed)

func _create_prefabs_bar() -> void:
	bottom_container = VBoxContainer.new()
	bottom_container.name = "BottomContainer"
	bottom_container.custom_minimum_size = Vector2(0, 180)
	bottom_container.size_flags_horizontal = SIZE_EXPAND_FILL
	bottom_container.size_flags_vertical = SIZE_EXPAND_FILL
	bottom_container.add_theme_constant_override("separation", 0)
	center_v_split.add_child(bottom_container)

	prefabs_bar = BayterekPrefabsBar.new()
	prefabs_bar.name = "PrefabsBar"
	prefabs_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	prefabs_bar.editor = self
	bottom_container.add_child(prefabs_bar)

	prefabs_panel = VBoxContainer.new()
	prefabs_panel.name = "PrefabsPanel"
	prefabs_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	prefabs_panel.size_flags_vertical = SIZE_EXPAND_FILL
	bottom_container.add_child(prefabs_panel)

	prefabs_bar.init(null, bottom_container, prefabs_panel)

	if tree_view and tree_view.prefabs_service:
		tree_view.prefabs_service.prefab_created.connect(_on_prefab_created)

func _on_prefab_created(_prefab: BayterekPrefab) -> void:
	call_deferred("_refresh_prefabs_panels")

func _refresh_prefabs_panels() -> void:
	if not prefabs_panel:
		return
	for i in prefabs_panel.get_child_count():
		var panel = prefabs_panel.get_child(i)
		if panel.has_method("refresh"):
			panel.refresh()

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

	context_menu.add_separator()
	context_menu.add_item("Save as Prefab", 100)
	context_menu.add_item("Save as Copy", 101)
	context_menu.add_item("Make Unique", 102)
	context_menu.add_separator()
	context_menu.add_item("Delete", 103)

	context_menu.id_pressed.connect(_on_context_menu_pressed)

	add_child(context_menu)

# ============================================================
# INPUT
# ============================================================

func _on_tree_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_last_click_pos = event.position
			_update_context_menu_state()
			context_menu.popup_on_parent(Rect2i(
				tree_view.get_screen_transform() * event.position,
				Vector2i.ZERO
			))

func _update_context_menu_state() -> void:
	if not context_menu:
		return
	var has_selection: bool = not tree_view.selected_nodes.is_empty()

	_set_item_disabled_by_id(100, not has_selection)
	_set_item_disabled_by_id(101, not has_selection)
	_set_item_disabled_by_id(102, not has_selection)
	_set_item_disabled_by_id(103, not has_selection)

	if has_selection:
		var any_prefab: bool = false
		for n in tree_view.selected_nodes:
			if is_instance_valid(n) and n.prefab:
				any_prefab = true
				break
		_set_item_disabled_by_id(102, not any_prefab)

func _set_item_disabled_by_id(item_id: int, disabled: bool) -> void:
	var idx: int = context_menu.get_item_index(item_id)
	if idx >= 0:
		context_menu.set_item_disabled(idx, disabled)

func _on_context_menu_pressed(id: int) -> void:
	match id:
		100: _save_selected_as_prefab(false)
		101: _save_selected_as_prefab(true)
		102: _make_selected_unique()
		103: _delete_selected()

func _save_selected_as_prefab(is_copy: bool) -> void:
	if not tree_view or not tree_view.prefabs_service:
		return
	if tree_view.selected_nodes.is_empty():
		return

	for node in tree_view.selected_nodes:
		if not is_instance_valid(node):
			continue
		tree_view.prefabs_service.create_prefab(node, is_copy)

	_refresh_prefabs_panels()
	set_dirty(true)

	if prefabs_bar and not tree_view.selected_nodes.is_empty():
		var node = tree_view.selected_nodes[0]
		var tab_idx: int = _node_type_to_panel_index(node.node_data.type)
		prefabs_bar.current_tab = tab_idx

func _node_type_to_panel_index(t: BayterekNode.NodeType) -> int:
	match t:
		BayterekNode.NodeType.SMALL: return 0
		BayterekNode.NodeType.MEDIUM: return 1
		BayterekNode.NodeType.LARGE: return 2
		BayterekNode.NodeType.DECORATION: return 3
	return 0

func _make_selected_unique() -> void:
	if not tree_view or not tree_view.prefabs_service:
		return
	for node in tree_view.selected_nodes:
		if is_instance_valid(node):
			tree_view.prefabs_service.make_unique(node)
	_refresh_prefabs_panels()
	set_dirty(true)

func _delete_selected() -> void:
	if tree_view:
		tree_view.delete_selected()

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
# SELECTION
# ============================================================

func _on_selection_changed(selected: Array) -> void:
	if not inspector:
		return
	if selected.size() == 1:
		inspector.inspect(selected[0])
	else:
		inspector.inspect(null)

func _on_node_moved(node: BayterekNodeButton) -> void:
	if not inspector or not node:
		return
	if inspector._current_node != node:
		return
	inspector.update_position_only(node.node_data.position)

# ============================================================
# ATTRIBUTES HANDLERS
# ============================================================

func _on_attr_changed(_attr_id: String) -> void:
	if inspector:
		inspector.refresh_attributes()

func _on_attr_removed(attr_id: String) -> void:
	if inspector:
		inspector.remove_attribute_from_node(attr_id)
	if tree and tree.nodes:
		for node_data in tree.nodes:
			if node_data.attributes.has(attr_id):
				node_data.attributes.erase(attr_id)
	if tree_view and tree_view.nodes_service:
		for node in tree_view.nodes_service.get_all_nodes():
			if node.node_data.attributes.has(attr_id):
				node.node_data.attributes.erase(attr_id)

func _on_attrs_list_changed() -> void:
	if inspector:
		inspector.refresh_attributes()

# ============================================================
# SPLIT HANDLERS
# ============================================================

func _on_h_split_dragged(offset: int) -> void:
	if tree:
		tree.hierarchy_split_offset = offset
		set_dirty(true)

func _on_bottom_split_dragged(offset: int) -> void:
	if tree:
		tree.prefabs_split_offset = offset
		set_dirty(true)

# ============================================================
# SETTINGS HANDLERS
# ============================================================

func _on_settings_size_changed() -> void:
	_apply_size_to_view()

func _apply_size_to_view() -> void:
	if not tree_view or not tree:
		return
	var half: Vector2 = tree.size / 2.0
	if tree_view.main_container:
		tree_view.main_container.offset_left = -half.x
		tree_view.main_container.offset_top = -half.y
		tree_view.main_container.offset_right = half.x
		tree_view.main_container.offset_bottom = half.y
		tree_view.main_container.pivot_offset = half
	if tree_view.camera:
		tree_view.camera.set_bounds(Rect2(-half, tree.size))

func _on_settings_background_changed() -> void:
	if not tree_view or not tree:
		return

	var color_rect: ColorRect = tree_view.background_container.get_node_or_null("BackgroundColor")
	if color_rect:
		color_rect.color = tree.bg_color

	var tex_rect: TextureRect = tree_view.background_container.get_node_or_null("BackgroundTexture")
	if tex_rect:
		tex_rect.texture = tree.bg_texture
		tex_rect.visible = tree.bg_texture != null

func _on_settings_border_scale_changed() -> void:
	pass

# ============================================================
# NODE CREATION
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

func _on_prefab_dropped_from_canvas(prefab: BayterekPrefab, tree_pos: Vector2) -> void:
	if not tree_view or not tree_view.nodes_service:
		return

	undo_redo.create_action("Create Node From Prefab")
	undo_redo.add_do_method(_do_create_node_from_prefab.bind(prefab, tree_pos))
	undo_redo.add_undo_method(_undo_create_node)
	undo_redo.commit_action()

func _do_create_node_from_prefab(prefab: BayterekPrefab, pos_in_tree: Vector2) -> void:
	if not tree_view or not tree_view.nodes_service:
		return
	tree_view.nodes_service.create_from_prefab(pos_in_tree, prefab)
	set_dirty(true)

# ============================================================
# MENU
# ============================================================

func _on_file_menu_pressed(id: int) -> void:
	match id:
		0: save_tree()
		1: request_close()

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
# SAVE / STATE
# ============================================================

func save_tree() -> void:
	if not tree:
		return

	if not tree.tree_state:
		tree.tree_state = BayterekTreeState.new()

	tree.tree_state.version = tree.version

	var err: Error = ResourceSaver.save(tree, tree_path)
	if err != OK:
		push_error("Bayterek: Tree save failed (%d)" % err)
		return

	_last_save_time = Time.get_ticks_msec()
	set_dirty(false)
	print("Bayterek: Tree saved: ", tree_path)

func set_dirty(is_dirty: bool) -> void:
	if dirty != is_dirty:
		dirty = is_dirty
		dirty_changed.emit(self, dirty)

func get_last_modified_time() -> String:
	if _last_save_time == 0:
		return "never saved"

	var elapsed: int = Time.get_ticks_msec() - _last_save_time
	var seconds: int = elapsed / 1000
	var minutes: int = seconds / 60
	var hours: int = minutes / 60

	if hours > 0:
		return "%d hours ago" % hours
	elif minutes > 0:
		return "%d minutes ago" % minutes
	else:
		return "%d seconds ago" % seconds

func _on_tree_view_changed() -> void:
	set_dirty(true)

func request_close() -> void:
	closed.emit()