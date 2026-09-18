@tool
class_name BayterekEditor
extends Control
## Graph editor + left hierarchy + right panel + bottom prefabs bar.

signal closed
signal dirty_changed(editor: BayterekEditor, dirty: bool)
signal node_root_changed(node: BayterekNodeButton)

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

const LEFT_PANEL_WIDTH := 200.0
const RIGHT_PANEL_WIDTH := 320.0
const MENU_HEIGHT := 28.0
const SAFETY_MARGIN := 40.0

# Context menu IDs
const CM_SAVE_PREFAB := 100
const CM_SAVE_COPY := 101
const CM_MAKE_UNIQUE := 102
const CM_DELETE := 103
const CM_MAKE_ROOT := 150
const CM_DUPLICATE := 151
const CM_ASSIGN_GROUP := 160
const CM_CLEANUP_ORPHANS := 200

# Group submenu IDs
const GROUP_SUBMENU_REMOVE := 200
const GROUP_SUBMENU_CREATE := 201
const GROUP_SUBMENU_BASE := 1000

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
var validator: BayterekValidator
var icon_selector: BayterekIconSelector
var rename_dialog: BayterekRenameDialog
var group_dialog: BayterekGroupDialog

# Tooltip menu reference
var _tooltip_menu: PopupMenu

# Prefab delete dialog (editor-level — like ContextMenu)
var delete_confirmation: ConfirmationDialog
var delete_option: OptionButton
var delete_title_label: Label
var delete_desc_label: Label
var _pending_delete_prefab: BayterekPrefab = null

var _last_click_pos: Vector2 = Vector2.ZERO
var _last_save_time: int = 0
var _resize_debounce: float = 0.0

# Group dialog state
var _group_dialog_mode: String = ""   # "create" | "edit"
var _group_dialog_target_id: String = ""

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _exit_tree() -> void:
	if context_menu and is_instance_valid(context_menu):
		context_menu.queue_free()
		context_menu = null

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
	_create_delete_dialog()
	_create_rename_dialog()
	_create_group_dialog()
	_create_icon_selector()
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

	# Sync the settings checkbox if it exists
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
		TOOLTIP_ID_NEAR_RIGHT:
			tree_view.set_tooltip_near_node_right()
		TOOLTIP_ID_NEAR_LEFT:
			tree_view.set_tooltip_near_node_left()
		TOOLTIP_ID_NEAR_TOP:
			tree_view.set_tooltip_near_node_top()
		TOOLTIP_ID_NEAR_BOTTOM:
			tree_view.set_tooltip_near_node_bottom()
		TOOLTIP_ID_CORNER_TL:
			tree_view.set_tooltip_corner_top_left()
		TOOLTIP_ID_CORNER_TR:
			tree_view.set_tooltip_corner_top_right()
		TOOLTIP_ID_CORNER_BL:
			tree_view.set_tooltip_corner_bottom_left()
		TOOLTIP_ID_CORNER_BR:
			tree_view.set_tooltip_corner_bottom_right()

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

		for node_type in tree.prefabs.keys():
			if node_type == BayterekNode.NodeType.DECORATION:
				continue
			var list: Array = tree.prefabs[node_type]
			for prefab in list:
				if prefab.reference_id.is_empty():
					continue
				_on_prefab_created(prefab)

	tree_view.gui_input.connect(_on_tree_view_input)
	tree_view.undo_redo_provider = self
	tree_view.changed.connect(_on_tree_view_changed)
	tree_view.selection_changed.connect(_on_selection_changed)
	tree_view.node_moved.connect(_on_node_moved)
	tree_view.prefab_dropped.connect(_on_prefab_dropped_from_canvas)
	tree_view.node_right_clicked.connect(_on_node_right_clicked)

	# Default tooltip position
	tree_view.set_tooltip_near_node_right()

	if hierarchy:
		hierarchy.editor = self
		hierarchy.init(tree_view)

	if inspector:
		inspector.editor = self
		inspector.icon_selector = icon_selector
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

	call_deferred("_refresh_prefabs_panels")

func _create_icon_selector() -> void:
	icon_selector = BayterekIconSelector.new()
	icon_selector.name = "IconSelector"
	icon_selector.editor = self
	icon_selector.init()

	if inspector:
		icon_selector.icon_selected.connect(inspector._on_icon_selected)

	add_child(icon_selector)

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

	tree_view.prefabs_service.delete_prefab(prefab_to_delete, mode)

	set_dirty(true)
	_refresh_prefabs_panels()

	var action_label: String = "Deleted prefab"
	match mode:
		0: action_label = "Orphaned nodes from prefab"
		1: action_label = "Deleted prefab and its nodes"
		2: action_label = "Made prefab nodes unique"
	BayterekToast.success(tree_view, action_label)

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

	var display_name: String = new_name
	if display_name.is_empty():
		display_name = "Node %d" % node.id

	if node.prefab:
		node.prefab.set_node_name(display_name)
		node.prefab.set_description(new_description)
	else:
		node.node_data.name = display_name
		node.node_data.description = new_description

	if hierarchy:
		hierarchy.refresh_node_display(node)

	if inspector and inspector._current_node == node:
		inspector.inspect(node)

	if node.has_method("refresh_visuals"):
		node.refresh_visuals()

	set_dirty(true)
	BayterekToast.success(tree_view, "Node updated")

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
		var group := BayterekNodeGroup.new()
		group.id = BayterekNodeGroup.generate_id()
		group.name = group_name
		group.color = group_color
		tree.node_groups.append(group)

		# Assign selected nodes to this new group
		if tree_view:
			for node in tree_view.selected_nodes:
				if is_instance_valid(node) and node.node_data:
					_assign_node_to_group(node, group.id)

		if hierarchy:
			hierarchy.refresh_all()

		BayterekToast.success(tree_view, "Group \"%s\" created" % group_name)
		set_dirty(true)

	elif _group_dialog_mode == "edit":
		var group: BayterekNodeGroup = tree.get_group_by_id(_group_dialog_target_id)
		if not group:
			return
		group.name = group_name
		group.color = group_color

		if hierarchy:
			hierarchy.refresh_all()

		set_dirty(true)

	_group_dialog_mode = ""
	_group_dialog_target_id = ""

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
		_do_delete_group(group_id, false)
		dialog.queue_free()
	)
	dialog.custom_action.connect(func(action: String) -> void:
		if action == "delete_nodes":
			_do_delete_group(group_id, true)
			dialog.hide()
			dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered(Vector2i(420, 200))

func _do_delete_group(group_id: String, delete_nodes: bool) -> void:
	if not tree:
		return
	var group: BayterekNodeGroup = tree.get_group_by_id(group_id)
	if not group:
		return

	if delete_nodes and tree_view:
		var members: Array = []
		for node in tree_view.nodes_service.get_all_nodes():
			if is_instance_valid(node) and node.node_data and node.node_data.group_id == group_id:
				members.append(node)

		for node in members:
			if is_instance_valid(node):
				tree_view.connections_service.remove_all_connections_of(node)
				tree_view.nodes_service.delete_node(node)
				tree_view.node_deleted.emit(node)
	else:
		for node_data in tree.nodes:
			if node_data.group_id == group_id:
				node_data.group_id = ""

	tree.remove_group(group)

	if hierarchy:
		hierarchy.refresh_all()

	set_dirty(true)

	BayterekToast.success(tree_view, "Group deleted")

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

func assign_selected_to_group(group_id: String) -> void:
	if not tree_view:
		return

	var count: int = 0
	for node in tree_view.selected_nodes:
		if is_instance_valid(node) and node.node_data:
			_assign_node_to_group(node, group_id)
			count += 1

	if hierarchy:
		hierarchy.refresh_all()

	if count > 0:
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
	if not prefab.icon_changed.is_connected(_on_prefab_icon_changed):
		prefab.icon_changed.connect(_on_prefab_icon_changed)
	if not prefab.border_changed.is_connected(_on_prefab_border_changed):
		prefab.border_changed.connect(_on_prefab_border_changed)
	if not prefab.attribute_changed.is_connected(_on_prefab_attribute_changed):
		prefab.attribute_changed.connect(_on_prefab_attribute_changed)
	if not prefab.max_allocations_changed.is_connected(_on_prefab_max_allocations_changed):
		prefab.max_allocations_changed.connect(_on_prefab_max_allocations_changed)
	call_deferred("_refresh_prefabs_panels")

func _on_prefab_name_changed(prefab: BayterekPrefab) -> void:
	var affected: Array = _get_nodes_of_prefab(prefab)
	for node in affected:
		node.node_data.name = prefab.node_name
		node.node_data.external_id = prefab.id
		if hierarchy:
			hierarchy.refresh_node_display(node)
	call_deferred("_refresh_prefabs_panels")
	set_dirty(true)

func _on_prefab_description_changed(prefab: BayterekPrefab) -> void:
	var affected: Array = _get_nodes_of_prefab(prefab)
	for node in affected:
		node.node_data.description = prefab.description
	call_deferred("_refresh_prefabs_panels")
	set_dirty(true)

func _on_prefab_icon_changed(prefab: BayterekPrefab) -> void:
	var affected: Array = _get_nodes_of_prefab(prefab)
	for node in affected:
		node.node_data.icon = prefab.icon
		if node.has_method("refresh_visuals"):
			node.refresh_visuals()
	call_deferred("_refresh_prefabs_panels")
	set_dirty(true)

func _on_prefab_border_changed(prefab: BayterekPrefab) -> void:
	var affected: Array = _get_nodes_of_prefab(prefab)
	for node in affected:
		node.node_data.border_normal = prefab.border_normal
		node.node_data.border_intermediate = prefab.border_intermediate
		node.node_data.border_active = prefab.border_active
		if node.has_method("refresh_visuals"):
			node.refresh_visuals()
	call_deferred("_refresh_prefabs_panels")
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
	call_deferred("_refresh_prefabs_panels")
	set_dirty(true)

func _on_prefab_max_allocations_changed(prefab: BayterekPrefab) -> void:
	var affected: Array = _get_nodes_of_prefab(prefab)
	for node in affected:
		node.node_data.max_allocations = prefab.max_allocations
		if inspector and inspector._current_node == node:
			inspector.refresh_attributes()
	call_deferred("_refresh_prefabs_panels")
	set_dirty(true)

func _refresh_prefabs_panels() -> void:
	if not prefabs_panel:
		return
	for i in prefabs_panel.get_child_count():
		var panel = prefabs_panel.get_child(i)
		if panel.has_method("refresh"):
			panel.refresh()

# ============================================================
# CONTEXT MENU
# ============================================================

func _create_context_menu() -> void:
	context_menu = PopupMenu.new()
	context_menu.name = "BayterekContextMenu"

	var submenu := PopupMenu.new()
	submenu.name = "NewNodeSubmenu"
	submenu.add_item("Small", 0)
	submenu.add_item("Medium", 1)
	submenu.add_item("Large", 2)
	submenu.id_pressed.connect(_on_new_node_type_selected)

	context_menu.add_child(submenu)
	context_menu.add_submenu_node_item("New Node", submenu, 0)

	context_menu.add_separator()
	context_menu.add_item("Make Root", CM_MAKE_ROOT)
	context_menu.add_item("Duplicate", CM_DUPLICATE)
	context_menu.add_separator()

	# Assign to Group submenu
	var group_submenu := PopupMenu.new()
	group_submenu.name = "GroupSubmenu"
	group_submenu.id_pressed.connect(_on_group_submenu_pressed)
	context_menu.add_child(group_submenu)
	context_menu.add_submenu_node_item("Assign to Group", group_submenu, CM_ASSIGN_GROUP)

	context_menu.add_separator()
	context_menu.add_item("Save as Prefab", CM_SAVE_PREFAB)
	context_menu.add_item("Save as Copy", CM_SAVE_COPY)
	context_menu.add_item("Make Unique", CM_MAKE_UNIQUE)
	context_menu.add_separator()
	context_menu.add_item("Delete", CM_DELETE)
	context_menu.add_separator()
	context_menu.add_item("Cleanup Orphan Prefabs", CM_CLEANUP_ORPHANS)

	context_menu.id_pressed.connect(_on_context_menu_pressed)

	var root: Window = get_tree().root
	if root:
		root.call_deferred("add_child", context_menu)
	else:
		add_child(context_menu)

# ============================================================
# INPUT
# ============================================================

func _on_node_right_clicked(node: BayterekNodeButton, screen_pos: Vector2) -> void:
	if not node or not node.node_data:
		return

	if not tree_view.selected_nodes.has(node):
		if not node.node_data.locked:
			tree_view.select_node(node)

	_last_click_pos = tree_view.screen_to_tree(screen_pos)
	_update_context_menu_state()

	context_menu.position = Vector2i(screen_pos)
	context_menu.popup()

func _on_tree_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var global_pos: Vector2 = tree_view.get_global_transform() * event.position

			_last_click_pos = event.position
			_update_context_menu_state()
			context_menu.position = Vector2i(global_pos)
			context_menu.popup()

func _update_context_menu_state() -> void:
	if not context_menu:
		return
	var has_selection: bool = not tree_view.selected_nodes.is_empty()

	_set_item_disabled_by_id(CM_SAVE_PREFAB, not has_selection)
	_set_item_disabled_by_id(CM_SAVE_COPY, not has_selection)
	_set_item_disabled_by_id(CM_MAKE_UNIQUE, not has_selection)
	_set_item_disabled_by_id(CM_DELETE, not has_selection)
	_set_item_disabled_by_id(CM_DUPLICATE, not has_selection)
	_set_item_disabled_by_id(CM_ASSIGN_GROUP, not has_selection)

	if has_selection:
		var any_prefab: bool = false
		var any_not_root: bool = false
		for n in tree_view.selected_nodes:
			if not is_instance_valid(n):
				continue
			if n.prefab:
				any_prefab = true
			if n.node_data and not n.node_data.is_root:
				any_not_root = true
		_set_item_disabled_by_id(CM_MAKE_UNIQUE, not any_prefab)
		_set_item_disabled_by_id(CM_MAKE_ROOT, not any_not_root)
	else:
		_set_item_disabled_by_id(CM_MAKE_ROOT, true)

	# Rebuild group submenu
	_rebuild_group_submenu()

func _set_item_disabled_by_id(item_id: int, disabled: bool) -> void:
	var idx: int = context_menu.get_item_index(item_id)
	if idx >= 0:
		context_menu.set_item_disabled(idx, disabled)

func _on_context_menu_pressed(id: int) -> void:
	match id:
		CM_SAVE_PREFAB: _save_selected_as_prefab(false)
		CM_SAVE_COPY: _save_selected_as_prefab(true)
		CM_MAKE_UNIQUE: _make_selected_unique()
		CM_DELETE: _delete_selected()
		CM_MAKE_ROOT: _make_selected_root()
		CM_DUPLICATE: duplicate_selected_nodes()
		CM_CLEANUP_ORPHANS: _cleanup_orphan_prefabs()

# ============================================================
# GROUP SUBMENU
# ============================================================

func _rebuild_group_submenu() -> void:
	# The Assign-to-Group submenu was created as a child of context_menu
	# with name "GroupSubmenu". Find it via get_node_or_null.
	var submenu_node: Node = context_menu.get_node_or_null("GroupSubmenu")
	if not submenu_node is PopupMenu:
		return
	var submenu: PopupMenu = submenu_node

	submenu.clear()

	var has_selection: bool = not tree_view.selected_nodes.is_empty()
	if not has_selection:
		return

	var groups: Array = tree.node_groups if tree else []
	for i in groups.size():
		var group = groups[i]
		if group:
			submenu.add_item(group.name, GROUP_SUBMENU_BASE + i)
			var idx: int = submenu.item_count - 1
			submenu.set_item_icon(idx, _make_color_icon(group.color))

	submenu.add_separator()
	submenu.add_item("New Group...", GROUP_SUBMENU_CREATE)
	submenu.add_separator()
	submenu.add_item("Remove from Group", GROUP_SUBMENU_REMOVE)

func _make_color_icon(c: Color) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(c)
	var border := Color(0, 0, 0, 0.6)
	for x in 16:
		img.set_pixel(x, 0, border)
		img.set_pixel(x, 15, border)
	for y in 16:
		img.set_pixel(0, y, border)
		img.set_pixel(15, y, border)
	return ImageTexture.create_from_image(img)

func _on_group_submenu_pressed(id: int) -> void:
	if id == GROUP_SUBMENU_REMOVE:
		assign_selected_to_group("")
		return
	if id == GROUP_SUBMENU_CREATE:
		open_group_create_dialog()
		return
	if id >= GROUP_SUBMENU_BASE:
		var groups: Array = tree.node_groups if tree else []
		var idx: int = id - GROUP_SUBMENU_BASE
		if idx >= 0 and idx < groups.size():
			var group: BayterekNodeGroup = groups[idx]
			if group:
				assign_selected_to_group(group.id)

# ============================================================
# PREFAB / ROOT OPERATIONS
# ============================================================

func _cleanup_orphan_prefabs() -> void:
	if not tree_view or not tree_view.prefabs_service:
		return
	var count: int = tree_view.prefabs_service.cleanup_orphan_prefabs()
	if count > 0:
		_refresh_prefabs_panels()
		set_dirty(true)
		BayterekToast.success(tree_view, "Cleaned up %d orphan prefab%s" % [count, "s" if count > 1 else ""])
		print("Bayterek: %d orphan prefab cleaned up." % count)
	else:
		BayterekToast.info(tree_view, "No orphan prefabs found")

func _save_selected_as_prefab(is_copy: bool) -> void:
	if not tree_view or not tree_view.prefabs_service:
		return
	if tree_view.selected_nodes.is_empty():
		return

	var count: int = 0
	for node in tree_view.selected_nodes:
		if not is_instance_valid(node):
			continue
		tree_view.prefabs_service.create_prefab(node, is_copy)
		count += 1

	_refresh_prefabs_panels()
	set_dirty(true)
	if prefabs_bar and not tree_view.selected_nodes.is_empty():
		var node = tree_view.selected_nodes[0]
		var tab_idx: int = _node_type_to_panel_index(node.node_data.type)
		prefabs_bar.current_tab = tab_idx

	if count > 0:
		var label: String = "copy" if is_copy else "prefab"
		var plural: String = "s" if count > 1 else ""
		BayterekToast.success(tree_view, "Saved %d %s%s" % [count, label, plural])

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

	var count: int = 0
	for node in tree_view.selected_nodes:
		if is_instance_valid(node):
			tree_view.prefabs_service.make_unique(node)
			count += 1

	_refresh_prefabs_panels()
	set_dirty(true)
	if count > 0:
		var plural: String = "s" if count > 1 else ""
		BayterekToast.success(tree_view, "Made %d node%s unique" % [count, plural])

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

	# Refresh hierarchy in case group membership changed
	if hierarchy:
		hierarchy.refresh_all()

func _make_selected_root() -> void:
	if not tree_view:
		return

	var count: int = 0
	for node in tree_view.selected_nodes:
		if not is_instance_valid(node) or not node.node_data:
			continue
		if node.node_data.locked:
			continue
		if node.node_data.is_root:
			continue

		node.node_data.is_root = true
		if node.has_method("refresh_visuals"):
			node.refresh_visuals()

		if has_method("notify_node_root_changed"):
			notify_node_root_changed(node)

		count += 1

	if count > 0:
		var plural: String = "s" if count > 1 else ""
		BayterekToast.success(tree_view, "Marked %d node%s as root" % [count, plural])
		set_dirty(true)

# ============================================================
# INPUT (keyboard)
# ============================================================

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
	elif ctrl and key == KEY_D:
		duplicate_selected_nodes()
		get_viewport().set_input_as_handled()
	elif ctrl and key == KEY_C:
		_copy_selected_nodes()
		get_viewport().set_input_as_handled()
	elif ctrl and key == KEY_V:
		_paste_nodes()
		get_viewport().set_input_as_handled()
	elif key == KEY_C and not ctrl and not shift:
		_toggle_chain_connection_mode()
		get_viewport().set_input_as_handled()
	elif key == KEY_F2:
		_open_rename_dialog()
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
		if n.type == BayterekNode.NodeType.DECORATION:
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
		"bayterek_version": 1,
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
	d["type"] = int(node_data.type)
	d["position"] = {"x": node_data.position.x, "y": node_data.position.y}
	d["max_allocations"] = node_data.max_allocations
	d["is_root"] = node_data.is_root
	d["locked"] = node_data.locked
	d["external_id"] = node_data.external_id
	d["reference_id"] = node_data.reference_id
	d["group_id"] = node_data.group_id
	d["prerequisite_group_id"] = node_data.prerequisite_group_id

	d["attributes"] = _deep_copy_json(node_data.attributes)
	d["overridden_attributes"] = _deep_copy_json(node_data.overridden_attributes)

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

	d["border_texture_locked"] = _tex_to_path(node_data.border_texture_locked)
	d["border_texture_normal"] = _tex_to_path(node_data.border_texture_normal)
	d["border_texture_hover"] = _tex_to_path(node_data.border_texture_hover)
	d["border_texture_max_level"] = _tex_to_path(node_data.border_texture_max_level)
	d["icon_texture_locked"] = _tex_to_path(node_data.icon_texture_locked)
	d["icon_texture_normal"] = _tex_to_path(node_data.icon_texture_normal)
	d["icon_texture_hover"] = _tex_to_path(node_data.icon_texture_hover)
	d["icon_texture_max_level"] = _tex_to_path(node_data.icon_texture_max_level)

	d["border_color_locked"] = _color_to_dict(node_data.border_color_locked)
	d["border_color_normal"] = _color_to_dict(node_data.border_color_normal)
	d["border_color_hover"] = _color_to_dict(node_data.border_color_hover)
	d["border_color_allocate"] = _color_to_dict(node_data.border_color_allocate)
	d["border_color_refund"] = _color_to_dict(node_data.border_color_refund)
	d["border_color_max_level"] = _color_to_dict(node_data.border_color_max_level)
	d["border_color_allocatable"] = _color_to_dict(node_data.border_color_allocatable)
	d["border_color_not_allocatable"] = _color_to_dict(node_data.border_color_not_allocatable)

	d["icon_color_locked"] = _color_to_dict(node_data.icon_color_locked)
	d["icon_color_normal"] = _color_to_dict(node_data.icon_color_normal)
	d["icon_color_hover"] = _color_to_dict(node_data.icon_color_hover)
	d["icon_color_allocate"] = _color_to_dict(node_data.icon_color_allocate)
	d["icon_color_refund"] = _color_to_dict(node_data.icon_color_refund)
	d["icon_color_max_level"] = _color_to_dict(node_data.icon_color_max_level)
	d["icon_color_allocatable"] = _color_to_dict(node_data.icon_color_allocatable)
	d["icon_color_not_allocatable"] = _color_to_dict(node_data.icon_color_not_allocatable)

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
	if payload.get("bayterek_version", 0) != 1:
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
	node_data.type = int(nd.get("type", 0)) as BayterekNode.NodeType

	var pos: Dictionary = nd.get("position", {})
	var px: float = float(pos.get("x", 0.0)) + offset.x
	var py: float = float(pos.get("y", 0.0)) + offset.y
	node_data.position = Vector2(px, py)

	node_data.max_allocations = int(nd.get("max_allocations", 1))
	node_data.is_root = bool(nd.get("is_root", false))
	node_data.locked = bool(nd.get("locked", false))
	node_data.external_id = nd.get("external_id", "")

	var old_ref: String = nd.get("reference_id", "")
	var prefab_exists: bool = false
	if not old_ref.is_empty() and tree_view and tree_view.prefabs_service:
		prefab_exists = tree_view.prefabs_service.get_prefab_by_reference_id(old_ref) != null

	if prefab_exists:
		node_data.reference_id = old_ref
	else:
		node_data.reference_id = ""

	# Group assignment: keep only if the group exists in this tree
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

	node_data.prerequisite_mode = int(nd.get("prerequisite_mode", 0)) as BayterekNode.PrerequisiteMode
	node_data.prerequisite_count = int(nd.get("prerequisite_count", 1))

	node_data.border_texture_locked = _path_to_tex(nd.get("border_texture_locked", ""))
	node_data.border_texture_normal = _path_to_tex(nd.get("border_texture_normal", ""))
	node_data.border_texture_hover = _path_to_tex(nd.get("border_texture_hover", ""))
	node_data.border_texture_max_level = _path_to_tex(nd.get("border_texture_max_level", ""))
	node_data.icon_texture_locked = _path_to_tex(nd.get("icon_texture_locked", ""))
	node_data.icon_texture_normal = _path_to_tex(nd.get("icon_texture_normal", ""))
	node_data.icon_texture_hover = _path_to_tex(nd.get("icon_texture_hover", ""))
	node_data.icon_texture_max_level = _path_to_tex(nd.get("icon_texture_max_level", ""))

	node_data.border_color_locked = _dict_to_color(nd.get("border_color_locked", {}), node_data.border_color_locked)
	node_data.border_color_normal = _dict_to_color(nd.get("border_color_normal", {}), node_data.border_color_normal)
	node_data.border_color_hover = _dict_to_color(nd.get("border_color_hover", {}), node_data.border_color_hover)
	node_data.border_color_allocate = _dict_to_color(nd.get("border_color_allocate", {}), node_data.border_color_allocate)
	node_data.border_color_refund = _dict_to_color(nd.get("border_color_refund", {}), node_data.border_color_refund)
	node_data.border_color_max_level = _dict_to_color(nd.get("border_color_max_level", {}), node_data.border_color_max_level)
	node_data.border_color_allocatable = _dict_to_color(nd.get("border_color_allocatable", {}), node_data.border_color_allocatable)
	node_data.border_color_not_allocatable = _dict_to_color(nd.get("border_color_not_allocatable", {}), node_data.border_color_not_allocatable)

	node_data.icon_color_locked = _dict_to_color(nd.get("icon_color_locked", {}), node_data.icon_color_locked)
	node_data.icon_color_normal = _dict_to_color(nd.get("icon_color_normal", {}), node_data.icon_color_normal)
	node_data.icon_color_hover = _dict_to_color(nd.get("icon_color_hover", {}), node_data.icon_color_hover)
	node_data.icon_color_allocate = _dict_to_color(nd.get("icon_color_allocate", {}), node_data.icon_color_allocate)
	node_data.icon_color_refund = _dict_to_color(nd.get("icon_color_refund", {}), node_data.icon_color_refund)
	node_data.icon_color_max_level = _dict_to_color(nd.get("icon_color_max_level", {}), node_data.icon_color_max_level)
	node_data.icon_color_allocatable = _dict_to_color(nd.get("icon_color_allocatable", {}), node_data.icon_color_allocatable)
	node_data.icon_color_not_allocatable = _dict_to_color(nd.get("icon_color_not_allocatable", {}), node_data.icon_color_not_allocatable)

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

func _on_settings_texture_filter_changed() -> void:
	if not tree_view or not tree:
		return

	for node in tree_view.nodes_service.get_all_nodes():
		if node.has_method("refresh_visuals"):
			node.refresh_visuals()

func _on_settings_chain_connection_changed() -> void:
	# Settings toggle already updated tree.chain_connection_mode.
	# Nothing more to do here, but keep the hook for consistency.
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
	var node: BayterekNodeButton = tree_view.nodes_service.create_node(pos_in_tree, node_type)
	set_dirty(true)
	if node and tree_view:
		var type_name: String = _node_type_to_string(node_type)
		BayterekToast.info(tree_view, "Created %s node" % type_name)

func _node_type_to_string(t: BayterekNode.NodeType) -> String:
	match t:
		BayterekNode.NodeType.SMALL: return "small"
		BayterekNode.NodeType.MEDIUM: return "medium"
		BayterekNode.NodeType.LARGE: return "large"
		BayterekNode.NodeType.DECORATION: return "decoration"
	return "node"

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
	if prefab and not prefab.node_name.is_empty():
		BayterekToast.info(tree_view, "Added prefab \"%s\"" % prefab.node_name)
	else:
		BayterekToast.info(tree_view, "Added prefab")

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
	var err: Error = ResourceSaver.save(tree, tree_path)
	if err != OK:
		push_error("Bayterek: Tree save failed (%d)" % err)
		if tree_view:
			BayterekToast.error(tree_view, "Save failed (err %d)" % err)
		return
	_last_save_time = Time.get_ticks_msec()
	set_dirty(false)
	if tree_view:
		BayterekToast.success(tree_view, "Tree saved")
	print("Bayterek: Tree saved: ", tree_path)

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