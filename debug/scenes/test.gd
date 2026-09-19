extends Control
## Bayterek Runtime Test — two-screen flow.
##
## Screen 1 (Browser):  lists all groups/trees from the registry.
## Screen 2 (Tree View): renders the selected tree with runtime controls.
##
## The whole scene parses and runs safely even when the plugin is disabled;
## autoloads are resolved at runtime.
##
## HUD + Confirm button are event-driven: they update only when the
## allocation service emits a state-change signal (no per-frame polling).

var _loader: Node = null
var _serializer: Node = null

## --- Screen containers ------------------------------------------
var _browser_screen: Control
var _tree_screen: Control

## --- Browser UI -------------------------------------------------
var _browser_tree: Tree
var _browser_status: Label

## --- Tree View UI ----------------------------------------------
var _top_bar: HBoxContainer
var _tree_container: Control
var _tree_view: BayterekTreeView
var _refund_btn: Button
var _confirm_btn: Button

## --- HUD (selection counter toast) -----------------------------
var _hud_panel: PanelContainer
var _hud_label: RichTextLabel

## --- State -----------------------------------------------------
var _current_group_name: String = ""
var _current_tree_name: String = ""

# ============================================================
# READY
# ============================================================

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	_loader = get_node_or_null("/root/BayterekLoader")
	_serializer = get_node_or_null("/root/BayterekSerializer")

	if not _loader:
		push_warning("Bayterek runtime_test: 'BayterekLoader' autoload bulunamadı — plugin açık mı?")
		_show_placeholder("Bayterek plugin is disabled.\nEnable it in Project Settings → Plugins.")
		return

	_build_screens()
	_show_browser()

# ============================================================
# SCREEN SETUP
# ============================================================

func _show_placeholder(message: String) -> void:
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	label.add_theme_font_size_override("font_size", 16)
	add_child(label)
	label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

func _build_screens() -> void:
	_build_browser_screen()
	_build_tree_screen()

	# Start with the browser visible
	_browser_screen.visible = true
	_tree_screen.visible = false

# --- BROWSER SCREEN ---------------------------------------------

func _build_browser_screen() -> void:
	_browser_screen = Control.new()
	_browser_screen.name = "BrowserScreen"
	_browser_screen.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_browser_screen)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	vbox.offset_left = 20
	vbox.offset_top = 20
	vbox.offset_right = -20
	vbox.offset_bottom = -20
	_browser_screen.add_child(vbox)

	# Header
	var header := Label.new()
	header.text = "Bayterek Runtime Test — Tree Browser"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	vbox.add_child(header)

	# Hint
	var hint := Label.new()
	hint.text = "Double-click a tree to open it in the runtime view."
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hint.add_theme_font_size_override("font_size", 12)
	vbox.add_child(hint)

	# Refresh button
	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh List"
	refresh_btn.pressed.connect(_populate_browser_tree)
	vbox.add_child(refresh_btn)

	# Tree list
	_browser_tree = Tree.new()
	_browser_tree.hide_root = true
	_browser_tree.size_flags_vertical = SIZE_EXPAND_FILL
	_browser_tree.size_flags_horizontal = SIZE_EXPAND_FILL
	_browser_tree.select_mode = Tree.SELECT_ROW
	_browser_tree.item_activated.connect(_on_browser_item_activated)
	vbox.add_child(_browser_tree)

	# Status label
	_browser_status = Label.new()
	_browser_status.text = ""
	_browser_status.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	_browser_status.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_browser_status)

# --- TREE SCREEN ------------------------------------------------

func _build_tree_screen() -> void:
	_tree_screen = Control.new()
	_tree_screen.name = "TreeScreen"
	_tree_screen.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_tree_screen)

	# Toolbar
	_top_bar = HBoxContainer.new()
	_top_bar.name = "TopBar"
	_top_bar.position = Vector2(10, 10)
	_top_bar.add_theme_constant_override("separation", 8)
	_tree_screen.add_child(_top_bar)

	var back_btn := Button.new()
	back_btn.name = "BackButton"
	back_btn.text = "← Back to Browser"
	back_btn.pressed.connect(_show_browser)
	_top_bar.add_child(back_btn)

	var sep1 := VSeparator.new()
	_top_bar.add_child(sep1)

	_refund_btn = Button.new()
	_refund_btn.name = "RefundButton"
	_refund_btn.text = "Enter Refund Mode (R)"
	_refund_btn.toggle_mode = true
	_refund_btn.pressed.connect(_on_refund_button_pressed)
	_top_bar.add_child(_refund_btn)

	var refund_all_btn := Button.new()
	refund_all_btn.name = "RefundAllButton"
	refund_all_btn.text = "Refund All"
	refund_all_btn.pressed.connect(_on_refund_all_pressed)
	_top_bar.add_child(refund_all_btn)

	_confirm_btn = Button.new()
	_confirm_btn.name = "ConfirmButton"
	_confirm_btn.text = "Confirm (Enter)"
	_confirm_btn.disabled = true
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	_top_bar.add_child(_confirm_btn)

	var clear_btn := Button.new()
	clear_btn.name = "ClearButton"
	clear_btn.text = "Clear (Esc)"
	clear_btn.pressed.connect(_on_clear_pressed)
	_top_bar.add_child(clear_btn)

	var reset_save_btn := Button.new()
	reset_save_btn.name = "ResetSaveButton"
	reset_save_btn.text = "Reset Save"
	reset_save_btn.tooltip_text = "Delete the saved allocation state on disk and reset."
	reset_save_btn.pressed.connect(_on_reset_save_pressed)
	_top_bar.add_child(reset_save_btn)

	var sep2 := VSeparator.new()
	_top_bar.add_child(sep2)

	var center_btn := Button.new()
	center_btn.name = "CenterButton"
	center_btn.text = "Center Camera"
	center_btn.pressed.connect(_on_center_pressed)
	_top_bar.add_child(center_btn)

	var save_btn := Button.new()
	save_btn.name = "SaveButton"
	save_btn.text = "Save State"
	save_btn.pressed.connect(_on_save_pressed)
	_top_bar.add_child(save_btn)

	var load_btn := Button.new()
	load_btn.name = "LoadButton"
	load_btn.text = "Load State"
	load_btn.pressed.connect(_on_load_pressed)
	_top_bar.add_child(load_btn)

	var sep3 := VSeparator.new()
	_top_bar.add_child(sep3)

	var reload_btn := Button.new()
	reload_btn.name = "ReloadButton"
	reload_btn.text = "Reload Tree"
	reload_btn.pressed.connect(_on_reload_pressed)
	_top_bar.add_child(reload_btn)

	# Tree render container
	_tree_container = Control.new()
	_tree_container.name = "TreeContainer"
	_tree_container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_tree_container.offset_top = 50
	_tree_screen.add_child(_tree_container)

	# --- HUD (selection counter toast) ---
	_build_hud()

# --- HUD --------------------------------------------------------

func _build_hud() -> void:
	_hud_panel = PanelContainer.new()
	_hud_panel.name = "HUD"
	_hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_panel.visible = false

	_hud_panel.anchor_left = 0.0
	_hud_panel.anchor_top = 0.0
	_hud_panel.anchor_right = 0.0
	_hud_panel.anchor_bottom = 0.0
	_hud_panel.offset_left = 12
	_hud_panel.offset_top = 56
	_hud_panel.offset_right = 12
	_hud_panel.offset_bottom = 56
	_hud_panel.grow_horizontal = Control.GROW_DIRECTION_END
	_hud_panel.grow_vertical = Control.GROW_DIRECTION_END
	_tree_screen.add_child(_hud_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.10, 0.92)
	style.border_color = Color(0.4, 0.7, 1.0, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	_hud_panel.add_theme_stylebox_override("panel", style)

	_hud_label = RichTextLabel.new()
	_hud_label.bbcode_enabled = true
	_hud_label.fit_content = true
	_hud_label.scroll_active = false
	_hud_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_label.custom_minimum_size = Vector2(180, 0)
	_hud_panel.add_child(_hud_label)

# ============================================================
# HUD UPDATE (event-driven)
# ============================================================

func _update_hud() -> void:
	if not _hud_panel or not _tree_screen or not _tree_screen.visible:
		return

	if not _tree_view or not _tree_view.allocation_service:
		_hud_panel.visible = false
		return

	var svc = _tree_view.allocation_service
	var refund_count: int = svc.get_refund_count()
	var pre_count: int = svc.get_preallocated_count()

	var text: String = ""
	var visible_state: bool = false

	if svc.is_refund_mode() and refund_count > 0:
		text = "[color=#ff8080]Refund selected: [b]%d[/b][/color]" % refund_count
		visible_state = true
	elif not svc.is_refund_mode() and pre_count > 0:
		text = "[color=#ffdd66]Preallocated: [b]%d[/b][/color]" % pre_count
		visible_state = true

	_hud_panel.visible = visible_state
	if visible_state:
		_hud_label.text = text

# ============================================================
# BROWSER LOGIC
# ============================================================

func _show_browser() -> void:
	_disconnect_allocation_signals()

	if _tree_view:
		_tree_view.queue_free()
		_tree_view = null
	_current_group_name = ""
	_current_tree_name = ""

	if _tree_container:
		for child in _tree_container.get_children():
			child.queue_free()

	if _refund_btn:
		_refund_btn.text = "Enter Refund Mode (R)"
		_refund_btn.button_pressed = false
	if _confirm_btn:
		_confirm_btn.disabled = true
		_confirm_btn.visible = true
	if _hud_panel:
		_hud_panel.visible = false

	_browser_screen.visible = true
	_tree_screen.visible = false

	_populate_browser_tree()

func _populate_browser_tree() -> void:
	if not _browser_tree:
		return

	_browser_tree.clear()
	_browser_tree.create_item()

	var registry: BayterekRegistry = _loader.call("get_registry") if _loader else null
	if not registry:
		_browser_status.text = "Registry yüklenemedi."
		return

	var root: TreeItem = _browser_tree.get_root()
	var total_groups: int = 0
	var total_trees: int = 0

	for group: BayterekGroup in registry.groups:
		total_groups += 1
		var g_item := root.create_child()
		g_item.set_text(0, "📁 %s" % group.name)
		g_item.set_metadata(0, {"type": "group", "name": group.name})
		g_item.set_collapsed(false)

		for tree: BayterekTree in group.trees:
			total_trees += 1
			var t_item := g_item.create_child()
			t_item.set_text(0, "🌳 %s" % tree.name)
			t_item.set_metadata(0, {
				"type": "tree",
				"name": tree.name,
				"group_name": group.name,
				"path": "%s/%s" % [group.name, tree.name],
			})

	if total_groups == 0:
		_browser_status.text = "Registry boş. Browser'dan grup/tree oluştur."
	elif total_trees == 0:
		_browser_status.text = "%d grup var ama hiç tree yok." % total_groups
	else:
		_browser_status.text = "%d grup, %d tree." % [total_groups, total_trees]

func _on_browser_item_activated() -> void:
	var item: TreeItem = _browser_tree.get_selected()
	if not item:
		return

	var meta: Dictionary = item.get_metadata(0)
	if meta.get("type", "") == "group":
		item.collapsed = not item.collapsed
		return

	if meta.get("type", "") == "tree":
		var group_name: String = meta.get("group_name", "")
		var tree_name: String = meta.get("name", "")
		_show_tree_view(group_name, tree_name)

# ============================================================
# TREE VIEW LOGIC
# ============================================================

func _show_tree_view(group_name: String, tree_name: String) -> void:
	if not _loader:
		return

	var tree_path: String = "%s/%s" % [group_name, tree_name]
	var tree = _loader.call("load_tree", tree_path)
	if not tree:
		push_warning("Test: '%s' yüklenemedi." % tree_path)
		_browser_status.text = "'%s' yüklenemedi." % tree_path
		return

	_current_group_name = group_name
	_current_tree_name = tree_name

	_disconnect_allocation_signals()
	if _tree_view:
		_tree_view.queue_free()
		_tree_view = null

	for child in _tree_container.get_children():
		child.queue_free()

	_tree_view = BayterekBuilder.new(tree) \
		.set_parent(_tree_container) \
		.node_allocated_callback(_on_node_allocated) \
		.node_deallocated_callback(_on_node_deallocated) \
		.build()

	if not _tree_view:
		push_error("Test: Failed to build tree view for '%s'" % tree_path)
		return

	_tree_view.set_tooltip_near_node_right()

	_connect_allocation_signals()

	print("Test: Opened tree '%s' (%d nodes)" % [tree_path, tree.nodes.size()])

	_browser_screen.visible = false
	_tree_screen.visible = true

	_update_refund_button_text()
	_update_hud()
	_update_confirm_button_state()

# ============================================================
# ALLOCATION SIGNAL WIRING (event-driven HUD + confirm)
# ============================================================

func _connect_allocation_signals() -> void:
	if not _tree_view or not _tree_view.allocation_service:
		return

	var svc = _tree_view.allocation_service

	if not svc.node_preallocated.is_connected(_on_allocation_state_changed):
		svc.node_preallocated.connect(_on_allocation_state_changed)
	if not svc.node_unpreallocated.is_connected(_on_allocation_state_changed):
		svc.node_unpreallocated.connect(_on_allocation_state_changed)
	if not svc.node_refund_added.is_connected(_on_allocation_state_changed):
		svc.node_refund_added.connect(_on_allocation_state_changed)
	if not svc.node_refund_removed.is_connected(_on_allocation_state_changed):
		svc.node_refund_removed.connect(_on_allocation_state_changed)
	if not svc.refund_mode_entered.is_connected(_on_refund_mode_changed):
		svc.refund_mode_entered.connect(_on_refund_mode_changed)
	if not svc.refund_mode_exited.is_connected(_on_refund_mode_changed):
		svc.refund_mode_exited.connect(_on_refund_mode_changed)
	if not svc.node_allocated.is_connected(_on_allocation_state_changed):
		svc.node_allocated.connect(_on_allocation_state_changed)
	if not svc.node_deallocated.is_connected(_on_allocation_state_changed):
		svc.node_deallocated.connect(_on_allocation_state_changed)

func _disconnect_allocation_signals() -> void:
	if not _tree_view or not is_instance_valid(_tree_view):
		return
	if not _tree_view.allocation_service:
		return

	var svc = _tree_view.allocation_service

	if svc.node_preallocated.is_connected(_on_allocation_state_changed):
		svc.node_preallocated.disconnect(_on_allocation_state_changed)
	if svc.node_unpreallocated.is_connected(_on_allocation_state_changed):
			svc.node_unpreallocated.disconnect(_on_allocation_state_changed)
	if svc.node_refund_added.is_connected(_on_allocation_state_changed):
		svc.node_refund_added.disconnect(_on_allocation_state_changed)
	if svc.node_refund_removed.is_connected(_on_allocation_state_changed):
		svc.node_refund_removed.disconnect(_on_allocation_state_changed)
	if svc.refund_mode_entered.is_connected(_on_refund_mode_changed):
		svc.refund_mode_entered.disconnect(_on_refund_mode_changed)
	if svc.refund_mode_exited.is_connected(_on_refund_mode_changed):
		svc.refund_mode_exited.disconnect(_on_refund_mode_changed)
	if svc.node_allocated.is_connected(_on_allocation_state_changed):
		svc.node_allocated.disconnect(_on_allocation_state_changed)
	if svc.node_deallocated.is_connected(_on_allocation_state_changed):
		svc.node_deallocated.disconnect(_on_allocation_state_changed)

func _on_allocation_state_changed(_node: BayterekNodeButton = null) -> void:
	_update_hud()
	_update_confirm_button_state()

func _on_refund_mode_changed() -> void:
	_update_refund_button_text()
	_update_hud()
	_update_confirm_button_state()

# ============================================================
# CALLBACKS
# ============================================================

func _on_node_allocated(node: BayterekNode) -> void:
	print("Test: Node allocated → %s" % node.name)

func _on_node_deallocated(node: BayterekNode) -> void:
	print("Test: Node deallocated → %s" % node.name)

func _on_refund_button_pressed() -> void:
	if not _tree_view or not _tree_view.allocation_service:
		return

	if _tree_view.allocation_service.is_refund_mode():
		_tree_view.allocation_service.exit_refund_mode()
	else:
		_tree_view.allocation_service.enter_refund_mode()

func _on_refund_all_pressed() -> void:
	if not _tree_view or not _tree_view.allocation_service:
		return
	_tree_view.allocation_service.stage_all_for_refund()

func _on_confirm_pressed() -> void:
	if not _tree_view or not _tree_view.allocation_service:
		return

	if _tree_view.allocation_service.is_refund_mode():
		_tree_view.allocation_service.confirm_refund()
	else:
		_tree_view.allocation_service.confirm_preallocations()

# ============================================================
# CLEAR — clears EVERYTHING (allocations + preallocations + refunds)
# ============================================================

func _on_clear_pressed() -> void:
	if not _tree_view:
		return

	# 1) Full allocation reset
	if _tree_view.allocation_service:
		_tree_view.allocation_service.clear_all_allocations()

	# 2) UI selection state
	_tree_view.clear_selection()
	if _tree_view.group_frames_service:
		_tree_view.group_frames_service.clear_selection()

	# 3) Reset toolbar button visuals
	if _refund_btn:
		_refund_btn.button_pressed = false
		_refund_btn.text = "Enter Refund Mode (R)"

	# 4) Refresh HUD + confirm
	_update_hud()
	_update_confirm_button_state()

func _on_center_pressed() -> void:
	if _tree_view:
		_tree_view.center_camera_on_content()

func _on_save_pressed() -> void:
	if not _serializer:
		push_warning("Test: BayterekSerializer yok — plugin açık mı?")
		return
	if not _tree_view or not _tree_view._tree_data:
		return
	var tree = _tree_view._tree_data
	if not tree.tree_state:
		tree.tree_state = BayterekTreeState.new()
	_serializer.call("save_tree_state", tree)
	print("Test: Tree state saved")

func _on_load_pressed() -> void:
	if not _serializer:
		push_warning("Test: BayterekSerializer yok — plugin açık mı?")
		return
	if not _tree_view or not _tree_view._tree_data:
		return
	var tree = _tree_view._tree_data
	_serializer.call("load_tree_state", tree)
	if _tree_view.allocation_service:
		_tree_view.allocation_service.reload_from_state()
	print("Test: Tree state loaded")
	_update_hud()
	_update_confirm_button_state()

func _on_reset_save_pressed() -> void:
	if not _tree_view or not _tree_view._tree_data:
		return

	var tree = _tree_view._tree_data

	if _serializer:
		_serializer.call("delete_tree_state", tree)

	if not tree.tree_state:
		tree.tree_state = BayterekTreeState.new()
	tree.tree_state.allocated_nodes.clear()
	tree.tree_state.allocation_level.clear()

	if _tree_view.allocation_service:
		_tree_view.allocation_service.reload_from_state()

	if _refund_btn:
		_refund_btn.button_pressed = false
		_refund_btn.text = "Enter Refund Mode (R)"

	_update_hud()
	_update_confirm_button_state()

	print("Test: Save state reset")

func _on_reload_pressed() -> void:
	if _current_group_name.is_empty() or _current_tree_name.is_empty():
		return
	_show_tree_view(_current_group_name, _current_tree_name)

func _update_refund_button_text() -> void:
	if not _refund_btn:
		return

	if _tree_view and _tree_view.allocation_service and _tree_view.allocation_service.is_refund_mode():
		_refund_btn.text = "Exit Refund Mode (R)"
	else:
		_refund_btn.text = "Enter Refund Mode (R)"

# ============================================================
# CONFIRM BUTTON VISIBILITY
# ============================================================

## Returns true if the current tree requires the Confirm button for the
## active mode (allocation or refund). Returns false when both confirms
## are disabled, meaning clicks act immediately.
func _is_confirm_required() -> bool:
	if not _tree_view or not _tree_view._tree_data:
		return false

	var tree = _tree_view._tree_data

	# Refund mode → check refund_confirm
	if _tree_view.allocation_service and _tree_view.allocation_service.is_refund_mode():
		return tree.refund_confirm

	# Normal allocation → check allocation_confirm
	return tree.allocation_confirm

func _update_confirm_button_state() -> void:
	if not _confirm_btn:
		return

	# Hide the Confirm button entirely when the current mode doesn't
	# require confirmation (immediate-click mode).
	if not _is_confirm_required():
		_confirm_btn.visible = false
		_confirm_btn.disabled = true
		return

	_confirm_btn.visible = true

	if not _tree_view or not _tree_view.allocation_service:
		_confirm_btn.disabled = true
		return

	var svc = _tree_view.allocation_service

	if svc.is_refund_mode():
		_confirm_btn.disabled = svc.get_refund_count() == 0
	else:
		_confirm_btn.disabled = svc.get_preallocated_count() == 0

# ============================================================
# INPUT
# ============================================================

func _input(event: InputEvent) -> void:
	if not _tree_screen or not _tree_screen.visible:
		return

	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if event.keycode == KEY_R:
		_on_refund_button_pressed()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		if _confirm_btn.visible and not _confirm_btn.disabled:
			_on_confirm_pressed()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE:
		_on_clear_pressed()
		get_viewport().set_input_as_handled()