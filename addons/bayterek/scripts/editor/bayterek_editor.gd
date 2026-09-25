@tool
class_name BayterekEditor
extends Control
## Graph editor + left hierarchy + right panel.

signal closed
signal dirty_changed(editor: BayterekEditor, dirty: bool)
signal node_root_changed(node: BayterekNodeButton)

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
var v_split: VSplitContainer
var hierarchy: BayterekTreeHierarchy
var left_container: VBoxContainer
var menu_bar: HBoxContainer
var tree_view: BayterekTreeView
var tab_container: TabContainer
var inspector: BayterekTreeEditorInspector
var settings_editor: BayterekSettingsEditor
var attributes_editor: BayterekAttributesEditor
var prefabs_bar: BayterekPrefabsBar

var context_menu: BayterekEditorContext
var _shortcuts: BayterekShortcuts

var _node_search: BayterekNodeSearch

var validator: BayterekValidator
var rename_dialog: BayterekRenameDialog
var group_dialog: BayterekGroupDialog

var _tooltip_menu: PopupMenu

var delete_confirmation: ConfirmationDialog
var delete_option: OptionButton
var delete_title_label: Label
var delete_desc_label: Label
var _pending_delete_prefab: BayterekPrefab = null

var _last_click_pos: Vector2 = Vector2.ZERO
var _last_save_time: int = 0
var _resize_debounce: float = 0.0

var _group_dialog_mode: String = ""
var _group_dialog_target_id: String = ""

# ============================================================
# UNDO / REDO HELPERS
# ============================================================

func _commit_action(action_name: String, do_callable: Callable, undo_callable: Callable) -> void:
	if not undo_redo:
		return
	undo_redo.create_action(action_name)
	undo_redo.add_do_method(do_callable)
	undo_redo.add_undo_method(undo_callable)
	undo_redo.commit_action()

# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _exit_tree() -> void:
	if context_menu and is_instance_valid(context_menu):
		context_menu.queue_free()
		context_menu = null
	if _node_search and is_instance_valid(_node_search):
		_node_search.queue_free()
		_node_search = null

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
		BayterekLogger.error("Tree load failed: %s" % path, "editor")
		return

	if not tree.tree_state:
		tree.tree_state = BayterekTreeState.new()

	undo_redo = UndoRedo.new()
	_shortcuts = BayterekShortcuts.new(self)

	_build_ui()
	_create_tree_view()
	_create_context_menu()
	_create_node_search()
	_create_delete_dialog()
	_create_rename_dialog()
	_create_group_dialog()
	_create_validator()

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

func _connect_split_signals() -> void:
	if h_split:
		h_split.dragged.connect(_on_h_split_dragged)

# ============================================================
# CHAIN-CONNECTION MODE
# ============================================================

func get_chain_connection_mode() -> bool:
	if not tree:
		return true
	return tree.chain_connection_mode

func _toggle_chain_connection_mode() -> void:
	if not tree:
		return
	tree.chain_connection_mode = not tree.chain_connection_mode
	_show_chain_mode_notification()

	if settings_editor and settings_editor._chain_connection_check:
		settings_editor._updating_ui = true
		settings_editor._chain_connection_check.button_pressed = tree.chain_connection_mode
		settings_editor._updating_ui = false

	set_dirty(true)

func _show_chain_mode_notification() -> void:
	var enabled: bool = tree.chain_connection_mode if tree else false
	var status: String = "ON" if enabled else "OFF"
	var message: String = "Chain Mode: [b]%s[/b]" % status

	if enabled:
		BayterekToast.success(tree_view, message)
	else:
		BayterekToast.error(tree_view, message)

# ============================================================
# UI SETUP
# ============================================================

func _build_ui() -> void:
	v_split = VSplitContainer.new()
	v_split.name = "VSplit"
	v_split.size_flags_horizontal = SIZE_EXPAND_FILL
	v_split.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(v_split)
	v_split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v_split.split_offset = -120

	h_split = HSplitContainer.new()
	h_split.name = "HSplit"
	h_split.size_flags_horizontal = SIZE_EXPAND_FILL
	h_split.size_flags_vertical = SIZE_EXPAND_FILL
	v_split.add_child(h_split)
	h_split.split_offset = 200

	hierarchy = BayterekTreeHierarchy.new()
	hierarchy.name = "Hierarchy"
	hierarchy.custom_minimum_size = Vector2(180, 0)
	hierarchy.size_flags_vertical = SIZE_EXPAND_FILL
	h_split.add_child(hierarchy)

	left_container = VBoxContainer.new()
	left_container.name = "LeftContainer"
	left_container.size_flags_horizontal = SIZE_EXPAND_FILL
	left_container.size_flags_vertical = SIZE_EXPAND_FILL
	left_container.add_theme_constant_override("separation", 0)
	h_split.add_child(left_container)

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

	var view_btn := MenuButton.new()
	view_btn.text = "View"
	var view_popup: PopupMenu = view_btn.get_popup()
	view_popup.add_item("Center Camera", 0)
	view_popup.add_separator()
	_build_tooltip_submenu(view_popup)
	view_popup.id_pressed.connect(_on_view_menu_pressed)
	menu_bar.add_child(view_btn)

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

	prefabs_bar = BayterekPrefabsBar.new()
	prefabs_bar.name = "PrefabsBar"
	v_split.add_child(prefabs_bar)
	prefabs_bar.init(self)

	prefabs_bar.card_rename_requested.connect(_on_prefab_card_rename)
	prefabs_bar.card_duplicate_requested.connect(_on_prefab_card_duplicate)
	prefabs_bar.card_delete_requested.connect(_on_prefab_card_delete)

	var bar_visible: bool = tree.prefabs_bar_visible if tree else true
	prefabs_bar.set_collapsed(not bar_visible, false)

# ============================================================
# TOOLTIP POSITION MENU
# ============================================================

const TOOLTIP_ID_NEAR_RIGHT := 100
const TOOLTIP_ID_NEAR_LEFT := 101
const TOOLTIP_ID_NEAR_TOP := 102
const TOOLTIP_ID_NEAR_BOTTOM := 103
const TOOLTIP_ID_CORNER_TL := 110
const TOOLTIP_ID_CORNER_TR := 111
const TOOLTIP_ID_CORNER_BL := 112
const TOOLTIP_ID_CORNER_BR := 113

func _build_tooltip_submenu(view_popup: PopupMenu) -> void:
	_tooltip_menu = PopupMenu.new()
	_tooltip_menu.name = "TooltipMenu"

	_tooltip_menu.add_radio_check_item("Near Node — Right", TOOLTIP_ID_NEAR_RIGHT)
	_tooltip_menu.add_radio_check_item("Near Node — Left", TOOLTIP_ID_NEAR_LEFT)
	_tooltip_menu.add_radio_check_item("Near Node — Top", TOOLTIP_ID_NEAR_TOP)
	_tooltip_menu.add_radio_check_item("Near Node — Bottom", TOOLTIP_ID_NEAR_BOTTOM)
	_tooltip_menu.add_separator()
	_tooltip_menu.add_radio_check_item("Corner — Top Left", TOOLTIP_ID_CORNER_TL)
	_tooltip_menu.add_radio_check_item("Corner — Top Right", TOOLTIP_ID_CORNER_TR)
	_tooltip_menu.add_radio_check_item("Corner — Bottom Left", TOOLTIP_ID_CORNER_BL)
	_tooltip_menu.add_radio_check_item("Corner — Bottom Right", TOOLTIP_ID_CORNER_BR)

	_tooltip_menu.set_item_checked(_tooltip_menu.get_item_index(TOOLTIP_ID_NEAR_RIGHT), true)

	_tooltip_menu.id_pressed.connect(_on_tooltip_menu_pressed)

	view_popup.add_child(_tooltip_menu)
	view_popup.add_submenu_node_item("Tooltip Position", _tooltip_menu, 1)

func _on_tooltip_menu_pressed(id: int) -> void:
	if not tree_view:
		return

	for i in _tooltip_menu.item_count:
		_tooltip_menu.set_item_checked(i, false)

	var idx: int = _tooltip_menu.get_item_index(id)
	if idx >= 0:
		_tooltip_menu.set_item_checked(idx, true)

	match id:
		TOOLTIP_ID_NEAR_RIGHT:  tree_view.set_tooltip_near_node_right()
		TOOLTIP_ID_NEAR_LEFT:   tree_view.set_tooltip_near_node_left()
		TOOLTIP_ID_NEAR_TOP:    tree_view.set_tooltip_near_node_top()
		TOOLTIP_ID_NEAR_BOTTOM: tree_view.set_tooltip_near_node_bottom()
		TOOLTIP_ID_CORNER_TL:   tree_view.set_tooltip_corner_top_left()
		TOOLTIP_ID_CORNER_TR:   tree_view.set_tooltip_corner_top_right()
		TOOLTIP_ID_CORNER_BL:   tree_view.set_tooltip_corner_bottom_left()
		TOOLTIP_ID_CORNER_BR:   tree_view.set_tooltip_corner_bottom_right()

# ============================================================
# TREE VIEW
# ============================================================

func _create_tree_view() -> void:
	tree_view = BayterekTreeView.new()
	tree_view.name = "TreeView"
	tree_view.size_flags_horizontal = SIZE_EXPAND_FILL
	tree_view.size_flags_vertical = SIZE_EXPAND_FILL
	left_container.add_child(tree_view)

	tree_view.load_tree(tree)

	if tree_view.prefabs_service:
		tree_view.prefabs_service.prefab_created.connect(_on_prefab_created)
		tree_view.prefabs_service.prefab_removed.connect(_on_prefab_removed)
		tree_view.prefabs_service.prefab_changed.connect(_on_prefab_changed)

		for prefab in tree.prefabs:
			if prefab and not prefab.reference_id.is_empty():
				_on_prefab_created(prefab)

	tree_view.gui_input.connect(_on_tree_view_input)
	tree_view.undo_redo_provider = self
	tree_view.changed.connect(_on_tree_view_changed)
	tree_view.selection_changed.connect(_on_selection_changed)
	tree_view.node_moved.connect(_on_node_moved)
	tree_view.prefab_dropped.connect(_on_prefab_dropped_from_canvas)
	tree_view.design_dropped.connect(_on_design_dropped_from_canvas)
	tree_view.node_right_clicked.connect(_on_node_right_clicked)

	tree_view.set_tooltip_near_node_right()

	if hierarchy:
		hierarchy.editor = self
		hierarchy.init(tree_view)

	if inspector:
		inspector.editor = self
		inspector.init(tree_view)

	if settings_editor:
		settings_editor.editor = self
		settings_editor.load_tree(tree)
		settings_editor.init()
		settings_editor.size_changed.connect(_on_settings_size_changed)
		settings_editor.background_changed.connect(_on_settings_background_changed)
		settings_editor.border_scale_changed.connect(_on_settings_border_scale_changed)
		settings_editor.texture_filter_changed.connect(_on_settings_texture_filter_changed)
		settings_editor.chain_connection_mode_changed.connect(_on_settings_chain_connection_changed)

	if attributes_editor:
		attributes_editor.editor = self
		attributes_editor.init()
		attributes_editor.attribute_changed.connect(_on_attr_changed)
		attributes_editor.attribute_removed.connect(_on_attr_removed)
		attributes_editor.attributes_list_changed.connect(_on_attrs_list_changed)

	if prefabs_bar:
		prefabs_bar.refresh()

func _create_validator() -> void:
	validator = BayterekValidator.new()
	validator.name = "Validator"
	validator.editor = self
	validator.init()

	if left_container:
		left_container.add_child(validator)

	validator.validate()

# ============================================================
# DELETE DIALOG (prefab)
# ============================================================

func _create_delete_dialog() -> void:
	delete_confirmation = ConfirmationDialog.new()
	delete_confirmation.name = "DeletePrefabDialog"
	delete_confirmation.title = "Delete Prefab"
	delete_confirmation.ok_button_text = "Delete"
	delete_confirmation.cancel_button_text = "Cancel"
	delete_confirmation.dialog_text = ""
	delete_confirmation.min_size = Vector2i.ZERO
	delete_confirmation.unresizable = true

	var vbox := VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.custom_minimum_size = Vector2(460, 0)
	vbox.add_theme_constant_override("separation", 12)
	delete_confirmation.add_child(vbox)

	delete_title_label = Label.new()
	delete_title_label.custom_minimum_size = Vector2(440, 0)
	delete_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	delete_title_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(delete_title_label)

	vbox.add_child(HSeparator.new())

	var action_label := Label.new()
	action_label.text = "Action:"
	action_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	vbox.add_child(action_label)

	delete_option = OptionButton.new()
	delete_option.custom_minimum_size = Vector2(440, 0)
	delete_option.add_item("Orphan nodes (keep them, break reference)", 0)
	delete_option.add_item("Delete nodes too", 1)
	delete_option.add_item("Make nodes unique (keep values)", 2)
	delete_option.select(0)
	delete_option.item_selected.connect(_on_delete_option_changed)
	vbox.add_child(delete_option)

	delete_desc_label = Label.new()
	delete_desc_label.custom_minimum_size = Vector2(440, 36)
	delete_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	delete_desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	delete_desc_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(delete_desc_label)

	_update_delete_description(0)

	delete_confirmation.confirmed.connect(_on_delete_confirmed)
	delete_confirmation.canceled.connect(_on_delete_canceled)
	delete_confirmation.close_requested.connect(_on_delete_canceled)

	add_child(delete_confirmation)

func request_delete_prefab(prefab: BayterekPrefab) -> void:
	_pending_delete_prefab = prefab

	delete_title_label.text = "Delete prefab \"%s\"?\nNodes using this prefab: %d" % [
		prefab.node_name,
		prefab.get_nodes().size()
	]

	delete_confirmation.reset_size()
	delete_confirmation.size = Vector2i(500, 280)
	delete_confirmation.popup_centered()

func _on_delete_canceled() -> void:
	_pending_delete_prefab = null

func _on_delete_confirmed() -> void:
	if not _pending_delete_prefab:
		return
	if not tree_view or not tree_view.prefabs_service:
		return

	var mode: int = delete_option.selected
	var prefab_to_delete = _pending_delete_prefab
	_pending_delete_prefab = null

	var affected_nodes: Array = prefab_to_delete.get_nodes().duplicate()

	var do_callable := func():
		tree_view.prefabs_service.delete_prefab(prefab_to_delete, mode)
		set_dirty(true)
	var undo_callable := func():
		_restore_prefab_snapshot(prefab_to_delete, affected_nodes)
		set_dirty(true)

	_commit_action("Delete Prefab", do_callable, undo_callable)

	var action_label: String = "Deleted prefab"
	match mode:
		0: action_label = "Orphaned nodes from prefab"
		1: action_label = "Deleted prefab and its nodes"
		2: action_label = "Made prefab nodes unique"
	BayterekToast.success(tree_view, action_label)

func _restore_prefab_snapshot(prefab: BayterekPrefab, affected_nodes: Array) -> void:
	if not prefab or not tree or not tree_view:
		return
	if not tree.prefabs.has(prefab):
		tree.prefabs.append(prefab)
	if not tree_view.prefabs_service._ref_id_to_prefab.has(prefab.reference_id):
		tree_view.prefabs_service._ref_id_to_prefab[prefab.reference_id] = prefab

	for node in affected_nodes:
		if not is_instance_valid(node):
			continue
		node.prefab = prefab
		if node.node_data:
			node.node_data.reference_id = prefab.reference_id
		prefab.add_node(node)

	tree_view.prefabs_service.prefab_created.emit(prefab)
	if prefabs_bar:
		prefabs_bar.refresh()

func _on_delete_option_changed(index: int) -> void:
	_update_delete_description(index)

func _update_delete_description(index: int) -> void:
	if not delete_desc_label or not is_instance_valid(delete_desc_label):
		return
	match index:
		0:
			delete_desc_label.text = "Nodes will stay on the canvas but lose their connection to this prefab."
		1:
			delete_desc_label.text = "⚠ All nodes using this prefab will be deleted from the canvas."
		2:
			delete_desc_label.text = "Nodes will stay on the canvas and keep their current values as independent copies."

# ============================================================
# RENAME DIALOG
# ============================================================

func _create_rename_dialog() -> void:
	rename_dialog = BayterekRenameDialog.new()
	rename_dialog.name = "RenameDialog"
	rename_dialog.applied.connect(_on_rename_applied)
	add_child(rename_dialog)

func _on_rename_applied(new_name: String, new_description: String) -> void:
	if not tree_view:
		return
	if tree_view.selected_nodes.is_empty():
		return

	var node: BayterekNodeButton = tree_view.selected_nodes[0]
	if not is_instance_valid(node) or not node.node_data:
		return

	if node.node_data.locked:
		BayterekToast.warning(tree_view, "Node is locked. Unlock it first.")
		return

	var old_name: String = node.node_data.name
	var old_desc: String = node.node_data.description
	var target_prefab: BayterekPrefab = node.prefab

	var do_callable := func():
		_apply_node_rename(node, target_prefab, new_name, new_description)
	var undo_callable := func():
		_apply_node_rename(node, target_prefab, old_name, old_desc)

	_commit_action("Rename Node", do_callable, undo_callable)

func _apply_node_rename(node: BayterekNodeButton, prefab: BayterekPrefab, new_name: String, new_desc: String) -> void:
	if not is_instance_valid(node) or not node.node_data:
		return

	var display_name: String = new_name
	if display_name.is_empty():
		display_name = "Node %d" % node.id

	if prefab:
		prefab.set_node_name(display_name)
		prefab.set_description(new_desc)
	else:
		node.node_data.name = display_name
		node.node_data.description = new_desc

	if hierarchy:
		hierarchy.refresh_node_display(node)

	if inspector and inspector._current_node == node:
		inspector.inspect(node)

	if node.has_method("refresh_visuals"):
		node.refresh_visuals()

	set_dirty(true)

func _open_rename_dialog() -> void:
	if not tree_view or tree_view.selected_nodes.is_empty():
		BayterekToast.info(tree_view, "Select a node first")
		return

	var node: BayterekNodeButton = tree_view.selected_nodes[0]
	if not is_instance_valid(node) or not node.node_data:
		return

	if node.node_data.locked:
		BayterekToast.warning(tree_view, "Node is locked. Unlock it first.")
		return

	if not rename_dialog:
		return

	rename_dialog.open_for(node.node_data.name, node.node_data.description)

# ============================================================
# GROUP DIALOG
# ============================================================

func _create_group_dialog() -> void:
	group_dialog = BayterekGroupDialog.new()
	group_dialog.name = "GroupDialog"
	group_dialog.applied.connect(_on_group_dialog_applied)
	add_child(group_dialog)

func _on_group_dialog_applied(group_name: String, group_color: Color) -> void:
	if not tree:
		return

	if _group_dialog_mode == "create":
		_create_group_undoable(group_name, group_color)
	elif _group_dialog_mode == "edit":
		_edit_group_undoable(_group_dialog_target_id, group_name, group_color)

	_group_dialog_mode = ""
	_group_dialog_target_id = ""

func _create_group_undoable(group_name: String, group_color: Color) -> void:
	var new_group := BayterekNodeGroup.new()
	new_group.id = BayterekNodeGroup.generate_id()
	new_group.name = group_name
	new_group.color = group_color

	var member_ids: Array = []
	if tree_view:
		for node in tree_view.selected_nodes:
			if is_instance_valid(node) and node.node_data:
				member_ids.append(node.id)

	for nid in member_ids:
		new_group.add_node_id(nid)

	var do_callable := func():
		_do_apply_group_create(new_group)
	var undo_callable := func():
		_do_undo_group_create(new_group)

	_commit_action("Create Group", do_callable, undo_callable)

func _do_apply_group_create(group: BayterekNodeGroup) -> void:
	if not tree:
		return
	if not tree.node_groups.has(group):
		tree.node_groups.append(group)

	for nid in group.node_ids:
		if not tree_view or not tree_view.nodes_service:
			continue
		var node = tree_view.nodes_service.get_node(nid)
		if not is_instance_valid(node) or not node.node_data:
			continue
		node.node_data.group_id = group.id

	if hierarchy:
		hierarchy.refresh_all()
	if tree_view and tree_view.group_frames_service:
		tree_view.group_frames_service.rebuild()

	set_dirty(true)
	BayterekToast.success(tree_view, "Group \"%s\" created" % group.name)

func _do_undo_group_create(group: BayterekNodeGroup) -> void:
	if not tree:
		return
	for nid in group.node_ids:
		if not tree_view or not tree_view.nodes_service:
			continue
		var node = tree_view.nodes_service.get_node(nid)
		if not is_instance_valid(node) or not node.node_data:
			continue
		node.node_data.group_id = ""

	tree.remove_group(group)

	if hierarchy:
		hierarchy.refresh_all()
	if tree_view and tree_view.group_frames_service:
		tree_view.group_frames_service.rebuild()
	set_dirty(true)

func _edit_group_undoable(group_id: String, new_name: String, new_color: Color) -> void:
	if not tree:
		return
	var group: BayterekNodeGroup = tree.get_group_by_id(group_id)
	if not group:
		return

	var old_name: String = group.name
	var old_color: Color = group.color

	var do_callable := func():
		_do_apply_group_edit(group_id, new_name, new_color)
	var undo_callable := func():
		_do_apply_group_edit(group_id, old_name, old_color)

	_commit_action("Edit Group", do_callable, undo_callable)

func _do_apply_group_edit(group_id: String, new_name: String, new_color: Color) -> void:
	if not tree:
		return
	var group: BayterekNodeGroup = tree.get_group_by_id(group_id)
	if not group:
		return
	group.name = new_name
	group.color = new_color

	if hierarchy:
		hierarchy.refresh_all()
	if tree_view and tree_view.group_frames_service:
		tree_view.group_frames_service.refresh_group(group_id)
	set_dirty(true)

func open_group_create_dialog() -> void:
	if not group_dialog:
		return
	_group_dialog_mode = "create"
	_group_dialog_target_id = ""
	group_dialog.open_for("New Group", Color(0.4, 0.7, 1.0))

func open_group_edit_dialog(group_id: String, rename_only: bool) -> void:
	if not group_dialog or not tree:
		return
	var group: BayterekNodeGroup = tree.get_group_by_id(group_id)
	if not group:
		return
	_group_dialog_mode = "edit"
	_group_dialog_target_id = group_id
	group_dialog.open_for(group.name, group.color)

func select_group_members(group_id: String) -> void:
	if not tree or not tree_view:
		return

	tree_view.clear_selection()

	for node in tree_view.nodes_service.get_all_nodes():
		if is_instance_valid(node) and node.node_data:
			if node.node_data.group_id == group_id:
				tree_view.select_node(node, true)

func request_delete_group(group_id: String) -> void:
	if not tree:
		return
	var group: BayterekNodeGroup = tree.get_group_by_id(group_id)
	if not group:
		return

	var dialog := ConfirmationDialog.new()
	dialog.title = "Delete Group"
	dialog.dialog_text = "Delete group \"%s\"?\n\nWhat about the %d node(s) inside?" % [group.name, group.node_ids.size()]
	dialog.ok_button_text = "Delete Group Only"
	dialog.add_button("Delete Nodes Too", true, "delete_nodes")
	dialog.cancel_button_text = "Cancel"
	dialog.unresizable = true

	dialog.confirmed.connect(func() -> void:
		_delete_group_undoable(group_id, false)
		dialog.queue_free()
	)
	dialog.custom_action.connect(func(action: String) -> void:
		if action == "delete_nodes":
			_delete_group_undoable(group_id, true)
			dialog.hide()
			dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered(Vector2i(420, 200))

func _delete_group_undoable(group_id: String, delete_nodes: bool) -> void:
	if not tree:
		return
	var group: BayterekNodeGroup = tree.get_group_by_id(group_id)
	if not group:
		return

	var group_snapshot := group.duplicate() as BayterekNodeGroup
	var node_snapshots: Array = []
	var node_indices: Array = []
	if tree_view and tree_view.nodes_service:
		for node in tree_view.nodes_service.get_all_nodes():
			if is_instance_valid(node) and node.node_data and node.node_data.group_id == group_id:
				node_snapshots.append(node)
				node_indices.append(tree.nodes.find(node.node_data))

	var do_callable := func():
		_do_apply_group_delete(group_id, delete_nodes, group_snapshot, node_snapshots)
	var undo_callable := func():
		_do_undo_group_delete(group_snapshot, node_snapshots, node_indices)

	_commit_action("Delete Group", do_callable, undo_callable)

func _do_apply_group_delete(group_id: String, delete_nodes: bool, group_snapshot: BayterekNodeGroup, member_nodes: Array) -> void:
	if not tree:
		return

	if delete_nodes and tree_view:
		for node in member_nodes:
			if is_instance_valid(node):
				tree_view.connections_service.remove_all_connections_of(node)
				tree_view.nodes_service.delete_node(node)
				tree_view.node_deleted.emit(node)
	else:
		for node_data in tree.nodes:
			if node_data.group_id == group_id:
				node_data.group_id = ""

	var group: BayterekNodeGroup = tree.get_group_by_id(group_id)
	if group:
		tree.remove_group(group)

	if hierarchy:
		hierarchy.refresh_all()
	if tree_view and tree_view.group_frames_service:
		tree_view.group_frames_service.rebuild()
	set_dirty(true)
	BayterekToast.success(tree_view, "Group deleted")

func _do_undo_group_delete(group_snapshot: BayterekNodeGroup, member_nodes: Array, node_indices: Array) -> void:
	if not tree:
		return

	if not tree.get_group_by_id(group_snapshot.id):
		tree.node_groups.append(group_snapshot)

	if tree_view and tree_view.nodes_service:
		for i in range(member_nodes.size()):
			var node = member_nodes[i]
			if not is_instance_valid(node) or not node.node_data:
				continue
			var idx: int = node_indices[i] if i < node_indices.size() else -1
			node.node_data.group_id = group_snapshot.id
			if not tree.nodes.has(node.node_data):
				if idx >= 0 and idx <= tree.nodes.size():
					tree.nodes.insert(idx, node.node_data)
				else:
					tree.nodes.append(node.node_data)
			tree_view.nodes_service.restore_node(node, node.node_data, idx)

	if hierarchy:
		hierarchy.refresh_all()
	if tree_view and tree_view.group_frames_service:
		tree_view.group_frames_service.rebuild()
	set_dirty(true)

# ============================================================
# GROUP ASSIGN / UNASSIGN (UNDOABLE)
# ============================================================

func _assign_node_to_group(node: BayterekNodeButton, group_id: String) -> void:
	if not node or not node.node_data or not tree:
		return

	var old_group_id: String = node.node_data.group_id

	if not old_group_id.is_empty():
		var old_group: BayterekNodeGroup = tree.get_group_by_id(old_group_id)
		if old_group:
			old_group.remove_node_id(node.id)

	node.node_data.group_id = group_id

	if not group_id.is_empty():
		var new_group: BayterekNodeGroup = tree.get_group_by_id(group_id)
		if new_group:
			new_group.add_node_id(node.id)

	if tree_view and tree_view.group_frames_service:
		if not old_group_id.is_empty():
			tree_view.group_frames_service.refresh_group(old_group_id)
		if not group_id.is_empty():
			tree_view.group_frames_service.refresh_group(group_id)

func assign_selected_to_group(group_id: String) -> void:
	if not tree_view:
		return

	var node_ids: Array = []
	var old_ids: Array = []
	for node in tree_view.selected_nodes:
		if is_instance_valid(node) and node.node_data:
			node_ids.append(node.id)
			old_ids.append(node.node_data.group_id)

	if node_ids.is_empty():
		return

	var new_ids: Array = []
	for _i in node_ids.size():
		new_ids.append(group_id)

	var do_callable := func():
		_do_assign_nodes_to_group(node_ids, new_ids)
	var undo_callable := func():
		_do_assign_nodes_to_group(node_ids, old_ids)

	var action_name: String = "Unassign from Group" if group_id.is_empty() else "Assign to Group"
	_commit_action(action_name, do_callable, undo_callable)

func _do_assign_nodes_to_group(node_ids: Array, group_ids: Array) -> void:
	if not tree_view or not tree_view.nodes_service or not tree:
		return

	for i in node_ids.size():
		var nid: int = node_ids[i]
		var gid: String = group_ids[i]
		var node = tree_view.nodes_service.get_node(nid)
		if not is_instance_valid(node) or not node.node_data:
			continue
		_assign_node_to_group(node, gid)

	if hierarchy:
		hierarchy.refresh_all()
	if tree_view.group_frames_service:
		tree_view.group_frames_service.refresh_all()
	set_dirty(true)

func ungroup_selected() -> void:
	if not tree_view:
		return
	var node_ids: Array = []
	var old_ids: Array = []
	for node in tree_view.selected_nodes:
		if is_instance_valid(node) and node.node_data:
			if node.node_data.group_id.is_empty():
				continue
			node_ids.append(node.id)
			old_ids.append(node.node_data.group_id)

	if node_ids.is_empty():
		BayterekToast.info(tree_view, "No grouped nodes in selection")
		return

	var new_ids: Array = []
	for _i in node_ids.size():
		new_ids.append("")

	var do_callable := func():
		_do_assign_nodes_to_group(node_ids, new_ids)
	var undo_callable := func():
		_do_assign_nodes_to_group(node_ids, old_ids)

	_commit_action("Ungroup Nodes", do_callable, undo_callable)
	BayterekToast.success(tree_view, "Removed %d node%s from group%s" % [
		node_ids.size(),
		"s" if node_ids.size() > 1 else "",
		"s" if node_ids.size() > 1 else ""
	])

# ============================================================
# NODE LOCK / ROOT TOGGLE (UNDOABLE)
# ============================================================

func toggle_lock_selected() -> void:
	if not tree_view:
		return

	var node_ids: Array = []
	var old_locks: Array = []
	for node in tree_view.selected_nodes:
		if is_instance_valid(node) and node.node_data:
			node_ids.append(node.id)
			old_locks.append(node.node_data.locked)

	if node_ids.is_empty():
		return

	var new_locks: Array = []
	for old in old_locks:
		new_locks.append(not old)

	var do_callable := func():
		_do_set_node_locked(node_ids, new_locks)
	var undo_callable := func():
		_do_set_node_locked(node_ids, old_locks)

	_commit_action("Toggle Lock", do_callable, undo_callable)

	var locked_count: int = 0
	var unlocked_count: int = 0
	for nv in new_locks:
		if nv: locked_count += 1
		else: unlocked_count += 1

	if locked_count > 0 and unlocked_count == 0:
		BayterekToast.info(tree_view, "Locked %d node%s" % [locked_count, "s" if locked_count > 1 else ""])
	elif unlocked_count > 0 and locked_count == 0:
		BayterekToast.info(tree_view, "Unlocked %d node%s" % [unlocked_count, "s" if unlocked_count > 1 else ""])
	else:
		BayterekToast.info(tree_view, "Locked %d, unlocked %d" % [locked_count, unlocked_count])

func unlock_all_nodes() -> void:
	if not tree_view or not tree_view.nodes_service:
		return

	var node_ids: Array = []
	var old_locks: Array = []
	for node in tree_view.nodes_service.get_all_nodes():
		if is_instance_valid(node) and node.node_data and node.node_data.locked:
			node_ids.append(node.id)
			old_locks.append(true)

	if node_ids.is_empty():
		BayterekToast.info(tree_view, "No locked nodes")
		return

	var new_locks: Array = []
	for _i in node_ids.size():
		new_locks.append(false)

	var do_callable := func():
		_do_set_node_locked(node_ids, new_locks)
	var undo_callable := func():
		_do_set_node_locked(node_ids, old_locks)

	_commit_action("Unlock All", do_callable, undo_callable)
	BayterekToast.success(tree_view, "Unlocked %d node%s" % [node_ids.size(), "s" if node_ids.size() > 1 else ""])

func _do_set_node_locked(node_ids: Array, locked_flags: Array) -> void:
	if not tree_view or not tree_view.nodes_service:
		return
	for i in node_ids.size():
		var node = tree_view.nodes_service.get_node(node_ids[i])
		if not is_instance_valid(node) or not node.node_data:
			continue
		node.node_data.locked = locked_flags[i]
		if node.has_method("refresh_visuals"):
			node.refresh_visuals()

	if hierarchy:
		hierarchy.refresh_all()
	set_dirty(true)

# ============================================================
# PREFAB SIGNAL HANDLERS
# ============================================================

func _get_nodes_of_prefab(prefab: BayterekPrefab) -> Array:
	var result: Array = []
	for node in prefab.nodes:
		if is_instance_valid(node):
			result.append(node)
	if result.is_empty() and tree_view and tree_view.nodes_service:
		for node in tree_view.nodes_service.get_all_nodes():
			if not is_instance_valid(node):
				continue
			if node.prefab == prefab:
				result.append(node)
	return result

func _on_prefab_created(prefab: BayterekPrefab) -> void:
	if not prefab:
		return
	if not prefab.name_changed.is_connected(_on_prefab_name_changed):
		prefab.name_changed.connect(_on_prefab_name_changed)
	if not prefab.description_changed.is_connected(_on_prefab_description_changed):
		prefab.description_changed.connect(_on_prefab_description_changed)
	if not prefab.attribute_changed.is_connected(_on_prefab_attribute_changed):
		prefab.attribute_changed.connect(_on_prefab_attribute_changed)
	if not prefab.max_allocations_changed.is_connected(_on_prefab_max_allocations_changed):
		prefab.max_allocations_changed.connect(_on_prefab_max_allocations_changed)
	if not prefab.exported_values_changed.is_connected(_on_prefab_exported_values_changed):
		prefab.exported_values_changed.connect(_on_prefab_exported_values_changed)

	if prefabs_bar:
		prefabs_bar.refresh()

func _on_prefab_removed(_prefab: BayterekPrefab) -> void:
	if prefabs_bar:
		prefabs_bar.refresh()

func _on_prefab_changed(_prefab: BayterekPrefab) -> void:
	if prefabs_bar:
		prefabs_bar.refresh()

func _on_prefab_name_changed(prefab: BayterekPrefab) -> void:
	var affected: Array = _get_nodes_of_prefab(prefab)
	for node in affected:
		node.node_data.name = prefab.node_name
		node.node_data.external_id = prefab.id
		if hierarchy:
			hierarchy.refresh_node_display(node)
	if prefabs_bar:
		prefabs_bar.refresh()
	set_dirty(true)

func _on_prefab_description_changed(prefab: BayterekPrefab) -> void:
	var affected: Array = _get_nodes_of_prefab(prefab)
	for node in affected:
		node.node_data.description = prefab.description
	set_dirty(true)

func _on_prefab_attribute_changed(prefab: BayterekPrefab, attribute_id: String, removed: bool) -> void:
	var affected: Array = _get_nodes_of_prefab(prefab)
	for node in affected:
		if removed:
			node.node_data.attributes.erase(attribute_id)
		else:
			node.node_data.attributes[attribute_id] = prefab.attributes[attribute_id].duplicate(true)
		if inspector and inspector._current_node == node:
			inspector.refresh_attributes()
	set_dirty(true)

func _on_prefab_max_allocations_changed(prefab: BayterekPrefab) -> void:
	var affected: Array = _get_nodes_of_prefab(prefab)
	for node in affected:
		node.node_data.max_allocations = prefab.max_allocations
		if inspector and inspector._current_node == node:
			inspector.refresh_attributes()
	set_dirty(true)

func _on_prefab_exported_values_changed(prefab: BayterekPrefab) -> void:
	var affected: Array = _get_nodes_of_prefab(prefab)
	for node in affected:
		if not is_instance_valid(node):
			continue
		if node.has_method("rebuild_from_design"):
			node.rebuild_from_design()
	set_dirty(true)

# ============================================================
# PREFAB BAR CARD HANDLERS
# ============================================================

func _on_prefab_card_rename(prefab: BayterekPrefab) -> void:
	if not prefab:
		return
	_show_prefab_rename_dialog(prefab)

func _on_prefab_card_duplicate(prefab: BayterekPrefab) -> void:
	if not prefab or not tree_view or not tree_view.prefabs_service:
		return

	var copy: BayterekPrefab = tree_view.prefabs_service.duplicate_prefab(prefab)
	if not copy:
		return

	var do_callable := func():
		set_dirty(true)
		BayterekToast.success(tree_view, "Prefab duplicated: %s" % copy.node_name)
	var undo_callable := func():
		if tree_view and tree_view.prefabs_service:
			tree_view.prefabs_service.delete_prefab(copy, BayterekPrefabsService.DeleteMode.ORPHAN_NODES)
		set_dirty(true)

	_commit_action("Duplicate Prefab", do_callable, undo_callable)

func _on_prefab_card_delete(prefab: BayterekPrefab) -> void:
	if not prefab:
		return
	request_delete_prefab(prefab)

func _show_prefab_rename_dialog(prefab: BayterekPrefab) -> void:
	if not prefab:
		return

	var old_name: String = prefab.node_name

	var dialog := ConfirmationDialog.new()
	dialog.title = "Rename Prefab"
	dialog.ok_button_text = "Rename"
	dialog.cancel_button_text = "Cancel"
	dialog.unresizable = true

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.custom_minimum_size = Vector2(360, 0)
	dialog.add_child(vbox)

	var row := HBoxContainer.new()
	vbox.add_child(row)

	var lbl := Label.new()
	lbl.text = "Name:"
	lbl.custom_minimum_size = Vector2(60, 0)
	row.add_child(lbl)

	var name_input := LineEdit.new()
	name_input.text = prefab.node_name
	name_input.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(name_input)

	dialog.confirmed.connect(func():
		var new_name: String = name_input.text.strip_edges()
		if new_name.is_empty():
			dialog.queue_free()
			return

		var do_callable := func():
			if tree_view and tree_view.prefabs_service:
				tree_view.prefabs_service.rename_prefab(prefab, new_name)
				set_dirty(true)
		var undo_callable := func():
			if tree_view and tree_view.prefabs_service:
				tree_view.prefabs_service.rename_prefab(prefab, old_name)
				set_dirty(true)

		_commit_action("Rename Prefab", do_callable, undo_callable)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())

	add_child(dialog)
	dialog.popup_centered(Vector2i(400, 140))
	name_input.call_deferred("grab_focus")
	name_input.call_deferred("select_all")

# ============================================================
# CONTEXT MENU
# ============================================================

func _create_context_menu() -> void:
	context_menu = BayterekEditorContext.new()
	context_menu.setup(self)

	context_menu.new_node_requested.connect(_on_new_node_from_context)
	context_menu.make_root_requested.connect(_make_selected_root)
	context_menu.duplicate_requested.connect(duplicate_selected_nodes)
	context_menu.save_as_prefab_requested.connect(_save_selected_as_prefab)
	context_menu.make_unique_requested.connect(_make_selected_unique)
	context_menu.assign_group_requested.connect(assign_selected_to_group)
	context_menu.remove_group_requested.connect(func(): assign_selected_to_group(""))
	context_menu.create_group_requested.connect(open_group_create_dialog)
	context_menu.delete_requested.connect(_delete_selected)
	context_menu.cleanup_orphans_requested.connect(_cleanup_orphan_prefabs)

	var root: Window = get_tree().root
	if root:
		root.call_deferred("add_child", context_menu)
	else:
		add_child(context_menu)

# ============================================================
# NODE SEARCH
# ============================================================

func _create_node_search() -> void:
	_node_search = BayterekNodeSearch.new()
	_node_search.node_chosen.connect(_on_node_search_chosen)

	var root: Window = get_tree().root
	if root:
		root.call_deferred("add_child", _node_search)
	else:
		add_child(_node_search)

func open_node_search() -> void:
	if not _node_search or not tree_view:
		return
	_node_search.open_for(tree_view)

func _on_node_search_chosen(node: BayterekNodeButton) -> void:
	if not is_instance_valid(node) or not tree_view:
		return
	tree_view.clear_selection()
	tree_view.select_node(node)
	if node.node_data and tree_view.camera:
		tree_view.camera.focus_on(node.node_data.position, tree_view.camera.get_zoom())

func _on_new_node_from_context(design_id: String, tree_pos: Vector2) -> void:
	var design: BayterekNodeDesign = Bayterek.get_designs_registry().get_design_by_id(design_id)
	if not design:
		BayterekToast.error(tree_view, "Design not found: %s" % design_id)
		return
	if not tree_view or not tree_view.nodes_service:
		return

	undo_redo.create_action("Create Node")
	undo_redo.add_do_method(_do_create_node_from_design.bind(design, tree_pos))
	undo_redo.add_undo_method(_undo_create_node)
	undo_redo.commit_action()

# ============================================================
# INPUT
# ============================================================

func _on_node_right_clicked(node: BayterekNodeButton, screen_pos: Vector2) -> void:
	if not node or not node.node_data or not context_menu:
		return

	if not tree_view.selected_nodes.has(node):
		if not node.node_data.locked:
			tree_view.select_node(node)

	_last_click_pos = tree_view.screen_to_tree(screen_pos)
	context_menu.open_at(screen_pos, _last_click_pos)

func _on_tree_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if not context_menu:
				return
			var global_pos: Vector2 = tree_view.get_global_transform() * event.position
			_last_click_pos = tree_view.screen_to_tree(event.position)
			context_menu.open_at(global_pos, _last_click_pos)

# ============================================================
# NODE CREATION (design-based)
# ============================================================

func _show_no_designs_dialog() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "No Designs Available"
	dialog.dialog_text = "No node designs are defined yet.\n\nDesigns are created in the Node Editor tab.\n\nOpen Node Editor now?"
	dialog.ok_button_text = "Open Node Editor"
	dialog.cancel_button_text = "Cancel"
	dialog.unresizable = true

	dialog.confirmed.connect(func() -> void:
		var main_screen := _find_main_screen()
		if main_screen and main_screen.has_method("switch_to_node_editor"):
			main_screen.switch_to_node_editor()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())

	add_child(dialog)
	dialog.popup_centered(Vector2i(420, 200))

func _find_main_screen() -> Node:
	var node: Node = get_parent()
	while node:
		if node is BayterekMainScreen:
			return node
		node = node.get_parent()
	return null

# ============================================================
# PREFAB / ROOT OPERATIONS
# ============================================================

func _cleanup_orphan_prefabs() -> void:
	if not tree_view or not tree_view.prefabs_service:
		return
	var count: int = tree_view.prefabs_service.cleanup_orphan_prefabs()
	if count > 0:
		set_dirty(true)
		BayterekToast.success(tree_view, "Cleaned up %d orphan prefab%s" % [count, "s" if count > 1 else ""])
		BayterekLogger.info("%d orphan prefab cleaned up." % count, "prefabs")
	else:
		BayterekToast.info(tree_view, "No orphan prefabs found")

func _save_selected_as_prefab() -> void:
	if not tree_view or not tree_view.prefabs_service:
		return
	if tree_view.selected_nodes.is_empty():
		return

	var node: BayterekNodeButton = tree_view.selected_nodes[0]
	if not is_instance_valid(node) or not node.node_data:
		return

	var dialog := ConfirmationDialog.new()
	dialog.title = "Save as Prefab"
	dialog.ok_button_text = "Create"
	dialog.cancel_button_text = "Cancel"
	dialog.unresizable = true

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.custom_minimum_size = Vector2(360, 0)
	dialog.add_child(vbox)

	var row := HBoxContainer.new()
	vbox.add_child(row)

	var lbl := Label.new()
	lbl.text = "Name:"
	lbl.custom_minimum_size = Vector2(60, 0)
	row.add_child(lbl)

	var name_input := LineEdit.new()
	name_input.text = node.node_data.name
	name_input.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(name_input)

	dialog.confirmed.connect(func():
		var prefab_name: String = name_input.text.strip_edges()
		if prefab_name.is_empty():
			prefab_name = node.node_data.name

		var created_prefab: BayterekPrefab = null
		var do_callable := func():
			created_prefab = tree_view.prefabs_service.create_prefab(node, prefab_name)
			set_dirty(true)
			BayterekToast.success(tree_view, "Prefab \"%s\" created" % prefab_name)
		var undo_callable := func():
			if created_prefab:
				tree_view.prefabs_service.delete_prefab(created_prefab, BayterekPrefabsService.DeleteMode.ORPHAN_NODES)
			set_dirty(true)

		_commit_action("Create Prefab", do_callable, undo_callable)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())

	add_child(dialog)
	dialog.popup_centered(Vector2i(400, 140))
	name_input.call_deferred("grab_focus")
	name_input.call_deferred("select_all")

func _make_selected_unique() -> void:
	if not tree_view or not tree_view.prefabs_service:
		return

	var entries: Array = []
	for node in tree_view.selected_nodes:
		if not is_instance_valid(node) or not node.prefab:
			continue
		entries.append({
			"node": node,
			"prefab": node.prefab,
		})

	if entries.is_empty():
		return

	var do_callable := func():
		for entry in entries:
			tree_view.prefabs_service.make_unique(entry["node"])
		set_dirty(true)
		BayterekToast.success(tree_view, "Made %d node%s unique" % [entries.size(), "s" if entries.size() > 1 else ""])
	var undo_callable := func():
		for entry in entries:
			var node = entry["node"]
			var prefab = entry["prefab"]
			if is_instance_valid(node) and prefab:
				node.prefab = prefab
				if node.node_data:
					node.node_data.reference_id = prefab.reference_id
				prefab.add_node(node)
		set_dirty(true)

	_commit_action("Make Unique", do_callable, undo_callable)

func _delete_selected() -> void:
	if not tree_view:
		return

	var count: int = 0
	for n in tree_view.selected_nodes:
		if not is_instance_valid(n) or n.node_data.locked:
			continue
		count += 1

	tree_view.delete_selected()

	if count > 0:
		if not _tree_has_root():
			BayterekToast.warning(tree_view, "Root node deleted. Tree has no root now.")
		else:
			var plural: String = "s" if count > 1 else ""
			BayterekToast.info(tree_view, "Deleted %d node%s" % [count, plural])

	if hierarchy:
		hierarchy.refresh_all()

	if tree_view and tree_view.group_frames_service:
		tree_view.group_frames_service.refresh_all()

func _make_selected_root() -> void:
	if not tree_view:
		return

	var node_ids: Array = []
	var old_roots: Array = []
	for node in tree_view.selected_nodes:
		if not is_instance_valid(node) or not node.node_data:
			continue
		if node.node_data.locked:
			continue
		if node.node_data.is_root:
			continue
		node_ids.append(node.id)
		old_roots.append(false)

	if node_ids.is_empty():
		return

	var new_roots: Array = []
	for _i in node_ids.size():
		new_roots.append(true)

	var do_callable := func():
		_do_set_node_root(node_ids, new_roots)
	var undo_callable := func():
		_do_set_node_root(node_ids, old_roots)

	_commit_action("Make Root", do_callable, undo_callable)
	BayterekToast.success(tree_view, "Marked %d node%s as root" % [node_ids.size(), "s" if node_ids.size() > 1 else ""])

func _do_set_node_root(node_ids: Array, root_flags: Array) -> void:
	if not tree_view or not tree_view.nodes_service:
		return
	for i in node_ids.size():
		var node = tree_view.nodes_service.get_node(node_ids[i])
		if not is_instance_valid(node) or not node.node_data:
			continue
		node.node_data.is_root = root_flags[i]
		if node.has_method("refresh_visuals"):
			node.refresh_visuals()
		if root_flags[i]:
			notify_node_root_changed(node)
	set_dirty(true)

# ============================================================
# INPUT (keyboard)
# ============================================================

func _input(event: InputEvent) -> void:
	if not _shortcuts:
		return
	if _shortcuts.handle_input(event):
		get_viewport().set_input_as_handled()

# ============================================================
# COPY / PASTE
# ============================================================

func _copy_selected_nodes() -> void:
	if not tree_view or tree_view.selected_nodes.is_empty():
		BayterekToast.info(tree_view, "Nothing to copy")
		return

	var selected: Array = []
	for n in tree_view.selected_nodes:
		if not is_instance_valid(n) or not n.node_data:
			continue
		if n.node_data.is_decoration:
			continue
		selected.append(n)

	if selected.is_empty():
		BayterekToast.warning(tree_view, "Decorations cannot be copied")
		return

	var copied_ids: Array = []
	var nodes_data: Array = []

	for node in selected:
		copied_ids.append(node.id)
		nodes_data.append(_node_to_dict(node.node_data))

	var payload: Dictionary = {
		"bayterek_version": 2,
		"source_tree_path": tree_path,
		"copied_ids": copied_ids,
		"nodes": nodes_data,
	}

	var json: String = JSON.stringify(payload)
	DisplayServer.clipboard_set(json)

	var plural: String = "s" if selected.size() > 1 else ""
	BayterekToast.success(tree_view, "Copied %d node%s" % [selected.size(), plural])

func _node_to_dict(node_data: BayterekNode) -> Dictionary:
	var d: Dictionary = {}

	d["name"] = node_data.name
	d["description"] = node_data.description
	d["is_decoration"] = node_data.is_decoration
	d["position"] = {"x": node_data.position.x, "y": node_data.position.y}
	d["max_allocations"] = node_data.max_allocations
	d["is_root"] = node_data.is_root
	d["locked"] = node_data.locked
	d["external_id"] = node_data.external_id
	d["reference_id"] = node_data.reference_id
	d["design_id"] = node_data.design_id
	d["group_id"] = node_data.group_id
	d["prerequisite_group_id"] = node_data.prerequisite_group_id

	d["attributes"] = _deep_copy_json(node_data.attributes)
	d["overridden_attributes"] = _deep_copy_json(node_data.overridden_attributes)
	d["exported_overrides"] = _deep_copy_json(node_data.exported_overrides)

	d["out_nodes"] = node_data.out_nodes.duplicate()
	d["in_nodes"] = node_data.in_nodes.duplicate()

	var line_data_dict: Dictionary = {}
	for to_id in node_data.line_data.keys():
		var ld = node_data.line_data[to_id]
		if ld is BayterekLineData:
			line_data_dict[str(to_id)] = _line_data_to_dict(ld)
	d["line_data"] = line_data_dict

	d["prerequisite_mode"] = int(node_data.prerequisite_mode)
	d["prerequisite_count"] = node_data.prerequisite_count

	d["design_size"] = {"x": node_data.design_size.x, "y": node_data.design_size.y}
	d["scale"] = {"x": node_data.scale.x, "y": node_data.scale.y}
	d["layers"] = _layers_to_dicts(node_data.layers)

	return d

func _line_data_to_dict(ld: BayterekLineData) -> Dictionary:
	return {
		"line_type": int(ld.line_type),
		"line_style": int(ld.line_style),
		"curve_height": ld.curve_height,
		"segments": ld.segments,
		"reversed": ld.reversed,
		"step_distance": ld.step_distance,
		"dash_length": ld.dash_length,
		"dash_gap": ld.dash_gap,
		"start_arrow": int(ld.start_arrow),
		"end_arrow": int(ld.end_arrow),
		"arrow_size": ld.arrow_size,
	}

func _paste_nodes() -> void:
	if not tree_view or not tree_view.nodes_service:
		return

	var clipboard_text: String = DisplayServer.clipboard_get()
	if clipboard_text.is_empty():
		BayterekToast.info(tree_view, "Clipboard is empty")
		return

	var parsed = JSON.parse_string(clipboard_text)
	if parsed == null or not parsed is Dictionary:
		BayterekToast.error(tree_view, "Clipboard does not contain Bayterek nodes")
		return

	var payload: Dictionary = parsed
	if payload.get("bayterek_version", 0) != 2:
		BayterekToast.error(tree_view, "Unsupported clipboard version")
		return

	var nodes_data: Array = payload.get("nodes", [])
	var copied_ids: Array = payload.get("copied_ids", [])

	if nodes_data.is_empty() or copied_ids.size() != nodes_data.size():
		BayterekToast.error(tree_view, "Invalid clipboard data")
		return

	var mouse_local: Vector2 = tree_view.get_local_mouse_position()
	var mouse_tree: Vector2 = tree_view.screen_to_tree(mouse_local)

	var min_x: float = INF
	var min_y: float = INF
	for nd in nodes_data:
		var pos: Dictionary = nd.get("position", {})
		var px: float = float(pos.get("x", 0.0))
		var py: float = float(pos.get("y", 0.0))
		min_x = minf(min_x, px)
		min_y = minf(min_y, py)

	var anchor: Vector2 = Vector2(min_x, min_y)
	var paste_offset: Vector2 = mouse_tree - anchor

	var id_map: Dictionary = {}
	for i in range(nodes_data.size()):
		var old_id: int = int(copied_ids[i])
		var new_id: int = tree_view._tree_data.get_next_id()
		id_map[old_id] = new_id

	var created: Array = []
	undo_redo.create_action("Paste Nodes")

	for i in range(nodes_data.size()):
		var nd: Dictionary = nodes_data[i]
		var old_id: int = int(copied_ids[i])
		var new_id: int = id_map[old_id]

		var node_data: BayterekNode = _dict_to_node(nd, new_id, id_map, paste_offset)

		var node: BayterekNodeButton = tree_view.nodes_service.create_node_from_data_paste(node_data)
		if not node:
			continue

		created.append(node)
		undo_redo.add_do_method(_do_restore_duplicate.bind(node))
		undo_redo.add_undo_method(_do_remove_duplicate.bind(node))

	for i in range(nodes_data.size()):
		var nd: Dictionary = nodes_data[i]
		var old_id: int = int(copied_ids[i])
		var new_from_id: int = id_map[old_id]

		var out_list: Array = nd.get("out_nodes", [])
		for old_to_id_v in out_list:
			var old_to_id: int = int(old_to_id_v)
			if not id_map.has(old_to_id):
				continue
			var new_to_id: int = id_map[old_to_id]
			undo_redo.add_do_method(_do_paste_connection.bind(new_from_id, new_to_id))

	undo_redo.commit_action()

	tree_view.clear_selection()
	for n in created:
		if is_instance_valid(n):
			tree_view.select_node(n, true)

	if created.size() > 0:
		var plural: String = "s" if created.size() > 1 else ""
		BayterekToast.success(tree_view, "Pasted %d node%s" % [created.size(), plural])

	if tree_view.group_frames_service:
		tree_view.group_frames_service.refresh_all()

	set_dirty(true)

func _do_paste_connection(from_id: int, to_id: int) -> void:
	if not tree_view or not tree_view.connections_service:
		return
	var from_node: BayterekNodeButton = tree_view.nodes_service.get_node(from_id)
	var to_node: BayterekNodeButton = tree_view.nodes_service.get_node(to_id)
	if from_node and to_node:
		tree_view.connections_service.create_connection(from_node, to_node)

func _dict_to_node(nd: Dictionary, new_id: int, id_map: Dictionary, offset: Vector2) -> BayterekNode:
	var node_data: BayterekNode = BayterekNode.new()

	node_data.id = new_id
	node_data.name = nd.get("name", "")
	node_data.description = nd.get("description", "")
	node_data.is_decoration = bool(nd.get("is_decoration", false))

	var pos: Dictionary = nd.get("position", {})
	var px: float = float(pos.get("x", 0.0)) + offset.x
	var py: float = float(pos.get("y", 0.0)) + offset.y
	node_data.position = Vector2(px, py)

	node_data.max_allocations = int(nd.get("max_allocations", 1))
	node_data.is_root = bool(nd.get("is_root", false))
	node_data.locked = bool(nd.get("locked", false))
	node_data.external_id = nd.get("external_id", "")
	node_data.design_id = nd.get("design_id", "")

	var old_ref: String = nd.get("reference_id", "")
	var prefab_exists: bool = false
	if not old_ref.is_empty() and tree_view and tree_view.prefabs_service:
		prefab_exists = tree_view.prefabs_service.get_prefab_by_reference_id(old_ref) != null

	if prefab_exists:
		node_data.reference_id = old_ref
	else:
		node_data.reference_id = ""

	var old_group_id: String = nd.get("group_id", "")
	if not old_group_id.is_empty() and tree:
		var grp: BayterekNodeGroup = tree.get_group_by_id(old_group_id)
		if grp:
			node_data.group_id = old_group_id
			grp.add_node_id(new_id)

	var old_prereq_gid: String = nd.get("prerequisite_group_id", "")
	if not old_prereq_gid.is_empty() and tree:
		var grp2: BayterekNodeGroup = tree.get_group_by_id(old_prereq_gid)
		if grp2:
			node_data.prerequisite_group_id = old_prereq_gid

	node_data.attributes = _deep_copy_json(nd.get("attributes", {}))
	node_data.overridden_attributes = _deep_copy_json(nd.get("overridden_attributes", {}))
	node_data.exported_overrides = _deep_copy_json(nd.get("exported_overrides", {}))

	node_data.prerequisite_mode = int(nd.get("prerequisite_mode", 0)) as BayterekNode.PrerequisiteMode
	node_data.prerequisite_count = int(nd.get("prerequisite_count", 1))

	node_data.design_size = _dict_to_vector2(nd.get("design_size", {}), Vector2(100, 100))
	node_data.scale = _dict_to_vector2(nd.get("scale", {}), Vector2.ONE)

	var layers_data: Array = nd.get("layers", [])
	for ld in layers_data:
		var layer = _dict_to_layer(ld)
		if layer:
			node_data.layers.append(layer)

	var line_data_dict: Dictionary = nd.get("line_data", {})
	for old_to_id_str in line_data_dict.keys():
		var old_to_id: int = int(old_to_id_str)
		if not id_map.has(old_to_id):
			continue
		var new_to_id: int = id_map[old_to_id]
		var ld_dict: Dictionary = line_data_dict[old_to_id_str]
		node_data.line_data[new_to_id] = _dict_to_line_data(ld_dict)

	return node_data

func _dict_to_line_data(d: Dictionary) -> BayterekLineData:
	var ld := BayterekLineData.new()
	ld.line_type = int(d.get("line_type", 0)) as BayterekLineData.LineType
	ld.line_style = int(d.get("line_style", 0)) as BayterekLineData.LineStyle
	ld.curve_height = float(d.get("curve_height", 48.0))
	ld.segments = int(d.get("segments", 16))
	ld.reversed = bool(d.get("reversed", false))
	ld.step_distance = float(d.get("step_distance", 48.0))
	ld.dash_length = float(d.get("dash_length", 12.0))
	ld.dash_gap = float(d.get("dash_gap", 6.0))
	ld.start_arrow = int(d.get("start_arrow", 0)) as BayterekLineData.ArrowStyle
	ld.end_arrow = int(d.get("end_arrow", 0)) as BayterekLineData.ArrowStyle
	ld.arrow_size = float(d.get("arrow_size", 12.0))
	return ld

func _deep_copy_json(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for k in value.keys():
				out[str(k)] = _deep_copy_json(value[k])
			return out
		TYPE_ARRAY:
			var out_arr: Array = []
			for v in value:
				out_arr.append(_deep_copy_json(v))
			return out_arr
		TYPE_VECTOR2:
			return {"x": value.x, "y": value.y}
		TYPE_COLOR:
			return _color_to_dict(value)
		TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL:
			return value
		TYPE_NIL:
			return null
		_:
			return str(value)

func _tex_to_path(tex: Texture2D) -> String:
	if tex == null:
		return ""
	return tex.resource_path

func _path_to_tex(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _color_to_dict(c: Color) -> Dictionary:
	return {"r": c.r, "g": c.g, "b": c.b, "a": c.a}

func _dict_to_color(d: Variant, fallback: Color) -> Color:
	if not d is Dictionary:
		return fallback
	return Color(
		float(d.get("r", fallback.r)),
		float(d.get("g", fallback.g)),
		float(d.get("b", fallback.b)),
		float(d.get("a", fallback.a))
	)

func _dict_to_vector2(d: Variant, fallback: Vector2) -> Vector2:
	if not d is Dictionary:
		return fallback
	return Vector2(
		float(d.get("x", fallback.x)),
		float(d.get("y", fallback.y))
	)

# ============================================================
# LAYER SERIALIZATION
# ============================================================

func _layers_to_dicts(layers: Array) -> Array:
	var result: Array = []
	for layer in layers:
		if layer is BayterekLayer:
			result.append(_layer_to_dict(layer))
	return result

func _layer_to_dict(layer: BayterekLayer) -> Dictionary:
	var d: Dictionary = {}
	d["layer_id"] = layer.layer_id
	d["layer_name"] = layer.layer_name
	d["visible"] = layer.visible
	d["animation_id"] = layer.animation_id
	d["animated"] = layer.animated
	d["render_mode_override"] = int(layer.render_mode_override)
	d["texture_filter_override"] = int(layer.texture_filter_override)
	d["transform"] = _transform_to_dict(layer.transform)

	if layer is BayterekShapeLayer:
		d["_type"] = "shape"
		d["shape_type"] = int(layer.shape_type)
		d["corner_radius"] = layer.corner_radius
		d["fill_enabled"] = layer.fill_enabled
		d["fill_configs"] = _configs_to_dict(layer.fill_configs)
		d["border_enabled"] = layer.border_enabled
		d["border_width"] = layer.border_width
		d["border_corner_gap"] = layer.border_corner_gap
		d["border_top_enabled"] = layer.border_top_enabled
		d["border_right_enabled"] = layer.border_right_enabled
		d["border_bottom_enabled"] = layer.border_bottom_enabled
		d["border_left_enabled"] = layer.border_left_enabled
		d["border_configs"] = _configs_to_dict(layer.border_configs)
		d["shadow_enabled"] = layer.shadow_enabled
		d["shadow_color"] = _color_to_dict(layer.shadow_color)
		d["shadow_size"] = {"x": layer.shadow_size.x, "y": layer.shadow_size.y}
		d["shadow_blur"] = layer.shadow_blur

	elif layer is BayterekTextureLayer:
		d["_type"] = "texture"
		d["icon_enabled"] = layer.icon_enabled
		d["icon_configs"] = _icon_configs_to_dict(layer.icon_configs)
		d["tint_enabled"] = layer.tint_enabled
		d["tint_configs"] = _configs_to_dict(layer.tint_configs)
		d["stretch_mode"] = int(layer.stretch_mode)
		d["nine_patch_margin_left"] = layer.nine_patch_margin_left
		d["nine_patch_margin_top"] = layer.nine_patch_margin_top
		d["nine_patch_margin_right"] = layer.nine_patch_margin_right
		d["nine_patch_margin_bottom"] = layer.nine_patch_margin_bottom
		d["nine_patch_draw_center"] = layer.nine_patch_draw_center

	return d

func _transform_to_dict(t: BayterekLayerTransform) -> Dictionary:
	if not t:
		return {}
	return {
		"position": {"x": t.position.x, "y": t.position.y},
		"size": {"x": t.size.x, "y": t.size.y},
		"scale": {"x": t.scale.x, "y": t.scale.y},
		"flip_x": t.flip_x,
		"flip_y": t.flip_y,
		"rotation": t.rotation,
		"skew": {"x": t.skew.x, "y": t.skew.y},
		"pivot": {"x": t.pivot.x, "y": t.pivot.y},
		"pivot_mode": int(t.pivot_mode),
		"scale_from_pivot": t.scale_from_pivot,
	}

func _configs_to_dict(configs: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for state in configs.keys():
		var entry = configs[state]
		if not entry is Dictionary:
			continue
		out[str(state)] = {
			"enabled": entry.get("enabled", false),
			"color": _color_to_dict(entry.get("color", Color.WHITE)),
		}
	return out

func _icon_configs_to_dict(configs: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for state in configs.keys():
		var entry = configs[state]
		if not entry is Dictionary:
			continue
		out[str(state)] = {
			"enabled": entry.get("enabled", false),
			"texture": _tex_to_path(entry.get("texture", null)),
		}
	return out

func _dict_to_layer(d: Dictionary) -> BayterekLayer:
	var type_str: String = d.get("_type", "")

	var layer: BayterekLayer = null
	if type_str == "shape":
		layer = BayterekShapeLayer.new()
	elif type_str == "texture":
		layer = BayterekTextureLayer.new()
	else:
		return null

	var stored_id: String = d.get("layer_id", "")
	if not stored_id.is_empty():
		layer.layer_id = stored_id

	layer.layer_name = d.get("layer_name", "Layer")
	layer.visible = d.get("visible", true)
	layer.animation_id = d.get("animation_id", "")
	layer.animated = d.get("animated", false)
	var rmo = d.get("render_mode_override", int(BayterekLayer.RenderModeOverride.INHERIT))
	if typeof(rmo) == TYPE_INT or typeof(rmo) == TYPE_FLOAT:
		layer.render_mode_override = int(rmo) as BayterekLayer.RenderModeOverride
	var tfo = d.get("texture_filter_override", int(BayterekLayer.TextureFilterOverride.INHERIT))
	if typeof(tfo) == TYPE_INT or typeof(tfo) == TYPE_FLOAT:
		layer.texture_filter_override = int(tfo) as BayterekLayer.TextureFilterOverride

	layer.transform = _dict_to_transform(d.get("transform", {}))

	if layer is BayterekShapeLayer:
		layer.shape_type = int(d.get("shape_type", 0)) as BayterekShapeLayer.ShapeType
		layer.corner_radius = float(d.get("corner_radius", 0.0))
		layer.fill_enabled = d.get("fill_enabled", true)
		layer.fill_configs = _dict_to_configs(d.get("fill_configs", {}))
		layer.border_enabled = d.get("border_enabled", false)
		layer.border_width = float(d.get("border_width", 2.0))
		layer.border_corner_gap = bool(d.get("border_corner_gap", false))
		layer.border_top_enabled = bool(d.get("border_top_enabled", true))
		layer.border_right_enabled = bool(d.get("border_right_enabled", true))
		layer.border_bottom_enabled = bool(d.get("border_bottom_enabled", true))
		layer.border_left_enabled = bool(d.get("border_left_enabled", true))
		layer.border_configs = _dict_to_configs(d.get("border_configs", {}))
		layer.shadow_enabled = d.get("shadow_enabled", false)
		layer.shadow_color = _dict_to_color(d.get("shadow_color", {}), Color(0, 0, 0, 0.5))
		layer.shadow_size = _dict_to_vector2(d.get("shadow_size", {}), Vector2(4, 4))
		layer.shadow_blur = float(d.get("shadow_blur", 0.0))

	elif layer is BayterekTextureLayer:
		layer.icon_enabled = d.get("icon_enabled", true)
		layer.icon_configs = _dict_to_icon_configs(d.get("icon_configs", {}))
		layer.tint_enabled = d.get("tint_enabled", false)
		layer.tint_configs = _dict_to_configs(d.get("tint_configs", {}))
		layer.stretch_mode = int(d.get("stretch_mode", 0)) as BayterekTextureLayer.StretchMode
		layer.nine_patch_margin_left = int(d.get("nine_patch_margin_left", 8))
		layer.nine_patch_margin_top = int(d.get("nine_patch_margin_top", 8))
		layer.nine_patch_margin_right = int(d.get("nine_patch_margin_right", 8))
		layer.nine_patch_margin_bottom = int(d.get("nine_patch_margin_bottom", 8))
		layer.nine_patch_draw_center = bool(d.get("nine_patch_draw_center", true))

	return layer

func _dict_to_transform(d: Dictionary) -> BayterekLayerTransform:
	var t := BayterekLayerTransform.new()
	t.position = _dict_to_vector2(d.get("position", {}), Vector2.ZERO)
	t.size = _dict_to_vector2(d.get("size", {}), Vector2.ZERO)
	t.scale = _dict_to_vector2(d.get("scale", {}), Vector2.ONE)
	t.flip_x = bool(d.get("flip_x", false))
	t.flip_y = bool(d.get("flip_y", false))
	t.rotation = float(d.get("rotation", 0.0))
	t.skew = _dict_to_vector2(d.get("skew", {}), Vector2.ZERO)
	t.pivot = _dict_to_vector2(d.get("pivot", {}), Vector2(0.5, 0.5))
	t.pivot_mode = int(d.get("pivot_mode", BayterekLayerTransform.PivotMode.CENTER)) as BayterekLayerTransform.PivotMode
	t.scale_from_pivot = bool(d.get("scale_from_pivot", false))
	return t

func _dict_to_configs(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for state in d.keys():
		var entry = d[state]
		if not entry is Dictionary:
			continue
		out[String(state)] = {
			"enabled": entry.get("enabled", false),
			"color": _dict_to_color(entry.get("color", {}), Color.WHITE),
		}
	return out

func _dict_to_icon_configs(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for state in d.keys():
		var entry = d[state]
		if not entry is Dictionary:
			continue
		out[String(state)] = {
			"enabled": entry.get("enabled", false),
			"texture": _path_to_tex(entry.get("texture", "")),
		}
	return out

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

func notify_node_root_changed(node: BayterekNodeButton) -> void:
	if node:
		node_root_changed.emit(node)

func notify_node_display_changed(node: BayterekNodeButton) -> void:
	if not node or not hierarchy:
		return
	hierarchy.refresh_node_display(node)

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

func _on_settings_texture_filter_changed() -> void:
	if not tree_view or not tree:
		return
	for node in tree_view.nodes_service.get_all_nodes():
		if node.has_method("refresh_visuals"):
			node.refresh_visuals()

func _on_settings_chain_connection_changed() -> void:
	pass

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
	if prefab and not prefab.node_name.is_empty():
		BayterekToast.info(tree_view, "Added prefab \"%s\"" % prefab.node_name)
	else:
		BayterekToast.info(tree_view, "Added prefab")

func _on_design_dropped_from_canvas(design: BayterekNodeDesign, tree_pos: Vector2) -> void:
	if not tree_view or not tree_view.nodes_service:
		return
	if not design:
		return
	undo_redo.create_action("Create Node From Design")
	undo_redo.add_do_method(_do_create_node_from_design.bind(design, tree_pos))
	undo_redo.add_undo_method(_undo_create_node)
	undo_redo.commit_action()

func _do_create_node_from_design(design: BayterekNodeDesign, pos_in_tree: Vector2) -> void:
	if not tree_view or not tree_view.nodes_service:
		return
	var node: BayterekNodeButton = tree_view.nodes_service.create_node(pos_in_tree, design)
	set_dirty(true)
	BayterekToast.info(tree_view, "Added design \"%s\"" % design.name)

func _undo_create_node() -> void:
	var all_nodes: Array = tree_view.nodes_service.get_all_nodes()
	if all_nodes.is_empty():
		return
	var last_node: BayterekNodeButton = all_nodes[all_nodes.size() - 1]
	tree_view.nodes_service.delete_node(last_node)
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

func _on_view_menu_pressed(id: int) -> void:
	match id:
		0:
			if tree_view:
				tree_view.center_camera_on_content()

func do_undo() -> void:
	if undo_redo and undo_redo.has_undo():
		undo_redo.undo()
		set_dirty(true)
		if tree_view:
			BayterekToast.info(tree_view, "Undo")

func do_redo() -> void:
	if undo_redo and undo_redo.has_redo():
		undo_redo.redo()
		set_dirty(true)
		if tree_view:
			BayterekToast.info(tree_view, "Redo")

# ============================================================
# SAVE / STATE
# ============================================================

func save_tree() -> void:
	if not tree:
		return

	if not _tree_has_root():
		_show_no_root_save_dialog()
		return

	_perform_save()

func _tree_has_root() -> bool:
	if not tree or not tree.nodes:
		return false
	for n in tree.nodes:
		if n and n.is_root:
			return true
	return false

func _show_no_root_save_dialog() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "No Root Node"
	dialog.dialog_text = "This tree has no root node. Trees without a root won't work at runtime.\n\nSave anyway?"
	dialog.ok_button_text = "Save Anyway"
	dialog.cancel_button_text = "Cancel"
	dialog.unresizable = true

	dialog.confirmed.connect(func() -> void:
		_perform_save()
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)
	dialog.close_requested.connect(func() -> void:
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered(Vector2i(400, 180))

func _perform_save() -> void:
	if not tree.tree_state:
		tree.tree_state = BayterekTreeState.new()
	tree.tree_state.version = tree.version

	var err: Error = Bayterek.safe_save(tree, tree_path)
	if err != OK:
		BayterekLogger.error("Tree save failed (%d): %s" % [err, tree_path], "editor")
		if tree_view:
			BayterekToast.error(tree_view, "Save failed (err %d)" % err)
		return
	_last_save_time = Time.get_ticks_msec()
	set_dirty(false)
	if tree_view:
		BayterekToast.success(tree_view, "Tree saved")
	BayterekLogger.info("Tree saved: %s" % tree_path, "editor")

func set_dirty(is_dirty: bool) -> void:
	if dirty != is_dirty:
		dirty = is_dirty
		dirty_changed.emit(self, dirty)

	if validator:
		validator.validate()

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

# ============================================================
# DUPLICATE NODES
# ============================================================

func duplicate_selected_nodes() -> void:
	if not tree_view:
		return
	if tree_view.selected_nodes.is_empty():
		return

	var originals: Array = tree_view.selected_nodes.duplicate()
	undo_redo.create_action("Duplicate Nodes")

	var created_nodes: Array = []
	var offset := Vector2(20, 20)

	for original in originals:
		if not is_instance_valid(original):
			continue
		if original.node_data and original.node_data.locked:
			continue

		var duplicate: BayterekNodeButton = tree_view.nodes_service.duplicate_node(original, offset)
		if not duplicate:
			continue

		created_nodes.append(duplicate)

		undo_redo.add_do_method(_do_restore_duplicate.bind(duplicate))
		undo_redo.add_undo_method(_do_remove_duplicate.bind(duplicate))

	undo_redo.commit_action()

	tree_view.clear_selection()
	for node in created_nodes:
		if is_instance_valid(node):
			tree_view.select_node(node, true)

	if created_nodes.size() > 0:
		var plural: String = "s" if created_nodes.size() > 1 else ""
		BayterekToast.success(tree_view, "Duplicated %d node%s" % [created_nodes.size(), plural])

	set_dirty(true)

func _do_restore_duplicate(node: BayterekNodeButton) -> void:
	if not node or not node.node_data:
		return
	tree_view.nodes_service.restore_node(node, node.node_data)
	set_dirty(true)

func _do_remove_duplicate(node: BayterekNodeButton) -> void:
	if not node or not node.node_data:
		return
	if tree_view.connections_service:
		tree_view.connections_service.remove_all_connections_of(node)
	tree_view.nodes_service.delete_node(node)
	set_dirty(true)
	if tree_view:
		BayterekToast.info(tree_view, "Undo: removed node")