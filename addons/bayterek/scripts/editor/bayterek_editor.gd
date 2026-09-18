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

## Chain-connection mode.
## When enabled, shift+click connection creation moves selection to the
## target node, so the next shift+click continues from there (A→B→C→D...).
## Toggled with the "C" key.
var chain_connection_mode: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _exit_tree() -> void:
	# Context menu lives under the scene-tree root, not under this editor.
	# Clean it up when the editor goes away.
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

## Public getter — read by BayterekTreeView without knowing internals.
func get_chain_connection_mode() -> bool:
	return chain_connection_mode

## Toggles chain mode on/off and shows a fade-out notification.
func _toggle_chain_connection_mode() -> void:
	chain_connection_mode = not chain_connection_mode
	_show_chain_mode_notification()

func _show_chain_mode_notification() -> void:
	var status: String = "ON" if chain_connection_mode else "OFF"
	var message: String = "Chain Mode: [b]%s[/b]" % status

	if chain_connection_mode:
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
# DELETE DIALOG (editor-level)
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

	# Only edit the first selected node (multi-select is ambiguous here).
	var node: BayterekNodeButton = tree_view.selected_nodes[0]
	if not is_instance_valid(node) or not node.node_data:
		return

	# Locked nodes cannot be edited.
	if node.node_data.locked:
		BayterekToast.warning(tree_view, "Node is locked. Unlock it first.")
		return

	# If the node is a prefab reference, edit the prefab (so all its
	# linked nodes get the change). Otherwise edit the node directly.
	var display_name: String = new_name
	if display_name.is_empty():
		display_name = "Node %d" % node.id

	if node.prefab:
		node.prefab.set_node_name(display_name)
		node.prefab.set_description(new_description)
	else:
		node.node_data.name = display_name
		node.node_data.description = new_description

	# Refresh hierarchy display + inspector + visuals.
	if hierarchy:
		hierarchy.refresh_node_display(node)

	if inspector and inspector._current_node == node:
		inspector.inspect(node)

	if node.has_method("refresh_visuals"):
		node.refresh_visuals()

	set_dirty(true)
	BayterekToast.success(tree_view, "Node updated")

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
	context_menu.add_item("Make Root", 150)
	context_menu.add_separator()
	context_menu.add_item("Duplicate", 151)
	context_menu.add_separator()
	context_menu.add_item("Save as Prefab", 100)
	context_menu.add_item("Save as Copy", 101)
	context_menu.add_item("Make Unique", 102)
	context_menu.add_separator()
	context_menu.add_item("Delete", 103)
	context_menu.add_separator()
	context_menu.add_item("Cleanup Orphan Prefabs", 200)

	context_menu.id_pressed.connect(_on_context_menu_pressed)

	# Add the popup to the scene-tree root so its `position` property is
	# interpreted in GLOBAL screen coordinates. This makes the top-left
	# corner land exactly under the mouse cursor.
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

	# If the right-clicked node isn't already selected, select it.
	if not tree_view.selected_nodes.has(node):
		if not node.node_data.locked:
			tree_view.select_node(node)

	_last_click_pos = tree_view.screen_to_tree(screen_pos)
	_update_context_menu_state()

	# context_menu is a child of the scene-tree root, so `position` is a
	# global (screen) coordinate. screen_pos already IS global.
	context_menu.position = Vector2i(screen_pos)
	context_menu.popup()

func _on_tree_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Global position of the click on the tree view.
			var global_pos: Vector2 = tree_view.get_global_transform() * event.position

			_last_click_pos = event.position
			_update_context_menu_state()
			context_menu.position = Vector2i(global_pos)
			context_menu.popup()

func _update_context_menu_state() -> void:
	if not context_menu:
		return
	var has_selection: bool = not tree_view.selected_nodes.is_empty()

	_set_item_disabled_by_id(100, not has_selection)
	_set_item_disabled_by_id(101, not has_selection)
	_set_item_disabled_by_id(102, not has_selection)
	_set_item_disabled_by_id(103, not has_selection)
	_set_item_disabled_by_id(151, not has_selection)

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
		_set_item_disabled_by_id(102, not any_prefab)
		_set_item_disabled_by_id(150, not any_not_root)
	else:
		_set_item_disabled_by_id(150, true)

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
		150: _make_selected_root()
		151: duplicate_selected_nodes()
		200: _cleanup_orphan_prefabs()

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
		# Check if the tree still has a root AFTER deletion. If not,
		# show a warning instead of the usual info toast.
		if not _tree_has_root():
			BayterekToast.warning(tree_view, "Root node deleted. Tree has no root now.")
		else:
			var plural: String = "s" if count > 1 else ""
			BayterekToast.info(tree_view, "Deleted %d node%s" % [count, plural])

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

	var display_name: String = node.node_data.name
	var display_desc: String = node.node_data.description
	rename_dialog.open_for(display_name, display_desc)

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
	elif key == KEY_C and not ctrl and not shift:
		_toggle_chain_connection_mode()
		get_viewport().set_input_as_handled()
	elif key == KEY_F2:
		_open_rename_dialog()
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

## Called by the inspector when a node's "is_root" flag is toggled.
func notify_node_root_changed(node: BayterekNodeButton) -> void:
	if node:
		node_root_changed.emit(node)

## Called by the inspector when a node's name or other display-affecting
## property changes. Refreshes the hierarchy item's label.
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

	# Refresh all nodes to apply the new filter
	for node in tree_view.nodes_service.get_all_nodes():
		if node.has_method("refresh_visuals"):
			node.refresh_visuals()

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

	# Check root before saving.
	if not _tree_has_root():
		_show_no_root_save_dialog()
		return

	_perform_save()

## Returns true if the tree contains at least one root node.
func _tree_has_root() -> bool:
	if not tree or not tree.nodes:
		return false
	for n in tree.nodes:
		if n and n.is_root:
			return true
	return false

## Shows a confirmation dialog when trying to save a tree without a root.
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

## Actual save logic — called directly or via confirmation dialog.
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

		# Create a duplicate via nodes_service.
		# NOTE: duplicate_node() does NOT register the node in tree.nodes.
		# That registration happens via _do_restore_duplicate() below,
		# which runs immediately when commit_action() executes.
		var duplicate: BayterekNodeButton = tree_view.nodes_service.duplicate_node(original, offset)
		if not duplicate:
			continue

		created_nodes.append(duplicate)

		undo_redo.add_do_method(_do_restore_duplicate.bind(duplicate))
		undo_redo.add_undo_method(_do_remove_duplicate.bind(duplicate))

	undo_redo.commit_action()

	# Select only the new duplicates
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