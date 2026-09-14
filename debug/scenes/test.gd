extends Control
## Runtime allocation test scene.
## Loads a tree from the registry and builds a runtime view.

const TREE_PATH := "group 1/tree 1"

var _tree_view: BayterekTreeView

func _ready() -> void:
	_build_ui()
	_load_and_build_tree()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	# --- Top bar ---
	var top_bar := HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.position = Vector2(10, 10)
	top_bar.add_theme_constant_override("separation", 8)
	add_child(top_bar)

	# Refund mode toggle button
	var refund_btn := Button.new()
	refund_btn.name = "RefundButton"
	refund_btn.text = "Enter Refund Mode (R)"
	refund_btn.toggle_mode = true
	refund_btn.pressed.connect(_on_refund_button_pressed)
	top_bar.add_child(refund_btn)

	# Refund All button
	var refund_all_btn := Button.new()
	refund_all_btn.name = "RefundAllButton"
	refund_all_btn.text = "Refund All"
	refund_all_btn.pressed.connect(_on_refund_all_pressed)
	top_bar.add_child(refund_all_btn)

	# Confirm button
	var confirm_btn := Button.new()
	confirm_btn.name = "ConfirmButton"
	confirm_btn.text = "Confirm (Enter)"
	confirm_btn.pressed.connect(_on_confirm_pressed)
	top_bar.add_child(confirm_btn)

	# Clear button
	var clear_btn := Button.new()
	clear_btn.name = "ClearButton"
	clear_btn.text = "Clear (Esc)"
	clear_btn.pressed.connect(_on_clear_pressed)
	top_bar.add_child(clear_btn)

	# --- Tree container ---
	var tree_container := Control.new()
	tree_container.name = "TreeContainer"
	tree_container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	tree_container.offset_top = 50
	add_child(tree_container)

func _load_and_build_tree() -> void:
	var tree_container: Control = get_node_or_null("TreeContainer")
	if not tree_container:
		push_error("Test: TreeContainer not found")
		return

	# Load tree from registry
	var tree: BayterekTree = BayterekLoader.load_tree(TREE_PATH)
	if not tree:
		push_error("Test: Could not load tree '%s'" % TREE_PATH)
		return

	print("Test: Loaded tree '%s' (%d nodes)" % [tree.name, tree.nodes.size()])

	# Build runtime view
	_tree_view = BayterekBuilder.new(tree) \
		.set_parent(tree_container) \
		.node_allocated_callback(_on_node_allocated) \
		.node_deallocated_callback(_on_node_deallocated) \
		.build()

	if not _tree_view:
		push_error("Test: Failed to build tree view")
		return

	print("Test: Tree view built successfully")

	# Center camera on tree origin (deferred so layout is ready)
	call_deferred("_center_camera")

func _center_camera() -> void:
	if not _tree_view or not _tree_view.camera:
		return
	if not _tree_view.nodes_service:
		return

	var nodes: Array = _tree_view.nodes_service.get_all_nodes()
	if nodes.is_empty():
		_tree_view.camera.focus_on(Vector2.ZERO, 1.0)
		return

	# Calculate centroid of all nodes
	var sum: Vector2 = Vector2.ZERO
	var count: int = 0
	for node in nodes:
		if is_instance_valid(node) and node.node_data:
			sum += node.node_data.position
			count += 1

	if count == 0:
		_tree_view.camera.focus_on(Vector2.ZERO, 1.0)
		return

	var centroid: Vector2 = sum / float(count)
	print("Test: Camera centroid = ", centroid)
	_tree_view.camera.focus_on(centroid, 1.0)

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

func _update_refund_button_text() -> void:
	var btn: Button = get_node_or_null("TopBar/RefundButton")
	if not btn:
		return

	if _tree_view and _tree_view.allocation_service and _tree_view.allocation_service.is_refund_mode():
		btn.text = "Exit Refund Mode (R)"
	else:
		btn.text = "Enter Refund Mode (R)"

# ============================================================
# INPUT
# ============================================================

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	# R → toggle refund mode
	if event.keycode == KEY_R:
		_on_refund_button_pressed()
		get_viewport().set_input_as_handled()
	# Enter → confirm (refund or preallocation)
	elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_on_confirm_pressed()
		get_viewport().set_input_as_handled()
	# Escape → clear / exit refund
	elif event.keycode == KEY_ESCAPE:
		_on_clear_pressed()
		get_viewport().set_input_as_handled()