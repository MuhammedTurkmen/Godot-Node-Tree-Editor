extends Control
## Bayterek Runtime Test — two-screen flow.
##
## Screen 1 (Browser):  lists all groups/trees from the registry.
## Screen 2 (Tree View): renders the selected tree with runtime controls.
##
## The whole scene parses and runs safely even when the plugin is disabled;
## autoloads are resolved at runtime.

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

## --- State -----------------------------------------------------
## Set when a tree is opened, cleared when returning to the browser.
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

	var confirm_btn := Button.new()
	confirm_btn.name = "ConfirmButton"
	confirm_btn.text = "Confirm (Enter)"
	confirm_btn.pressed.connect(_on_confirm_pressed)
	_top_bar.add_child(confirm_btn)

	var clear_btn := Button.new()
	clear_btn.name = "ClearButton"
	clear_btn.text = "Clear (Esc)"
	clear_btn.pressed.connect(_on_clear_pressed)
	_top_bar.add_child(clear_btn)

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

# ============================================================
# BROWSER LOGIC
# ============================================================

func _show_browser() -> void:
	# Cleanup current tree view
	if _tree_view:
		_tree_view.queue_free()
		_tree_view = null
	_current_group_name = ""
	_current_tree_name = ""

	# Clear render container children
	if _tree_container:
		for child in _tree_container.get_children():
			child.queue_free()

	# Update toolbar state
	if _refund_btn:
		_refund_btn.text = "Enter Refund Mode (R)"
		_refund_btn.button_pressed = false

	# Switch screens
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

	# Clear previous tree view
	if _tree_view:
		_tree_view.queue_free()
		_tree_view = null

	for child in _tree_container.get_children():
		child.queue_free()

	# Build runtime view
	_tree_view = BayterekBuilder.new(tree) \
		.set_parent(_tree_container) \
		.node_allocated_callback(_on_node_allocated) \
		.node_deallocated_callback(_on_node_deallocated) \
		.build()

	if not _tree_view:
		push_error("Test: Failed to build tree view for '%s'" % tree_path)
		return

	_tree_view.set_tooltip_near_node_right()

	print("Test: Opened tree '%s' (%d nodes)" % [tree_path, tree.nodes.size()])

	# Switch screens
	_browser_screen.visible = false
	_tree_screen.visible = true
	_update_refund_button_text()

# ============================================================
# CALLBACKS
# ============================================================

func _on_node_allocated(node: BayterekNode) -> void:
	print("Test: Node allocated → %s" % node.name)

func _on_node_deallocated(node: BayterekNode) -> void:
	print("Test: Node deallocated → %s" % node.name)

func _on_refund_button_pressed() -> void:
	print("[TEST] _on_refund_button_pressed called")
	if not _tree_view:
		print("[TEST] _tree_view is NULL")
		return
	if not _tree_view.allocation_service:
		print("[TEST] allocation_service is NULL")
		return

	print("[TEST] is_refund_mode before = ", _tree_view.allocation_service.is_refund_mode())
	if _tree_view.allocation_service.is_refund_mode():
		_tree_view.allocation_service.exit_refund_mode()
	else:
		_tree_view.allocation_service.enter_refund_mode()
	print("[TEST] is_refund_mode after = ", _tree_view.allocation_service.is_refund_mode())

	_update_refund_button_text()

func _on_refund_all_pressed() -> void:
	if not _tree_view or not _tree_view.allocation_service:
		return
	_tree_view.allocation_service.stage_all_for_refund()
	_update_refund_button_text()

func _on_confirm_pressed() -> void:
	if not _tree_view or not _tree_view.allocation_service:
		return

	if _tree_view.allocation_service.is_refund_mode():
		_tree_view.allocation_service.confirm_refund()
	else:
		_tree_view.allocation_service.confirm_preallocations()

	_update_refund_button_text()

func _on_clear_pressed() -> void:
	if not _tree_view or not _tree_view.allocation_service:
		return

	if _tree_view.allocation_service.is_refund_mode():
		_tree_view.allocation_service.exit_refund_mode()
	else:
		_tree_view.allocation_service.clear_preallocations()

	_update_refund_button_text()

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
# INPUT
# ============================================================

func _input(event: InputEvent) -> void:
	# Input only active on the tree screen
	if not _tree_screen or not _tree_screen.visible:
		return

	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if event.keycode == KEY_R:
		_on_refund_button_pressed()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_on_confirm_pressed()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE:
		_on_clear_pressed()
		get_viewport().set_input_as_handled()
