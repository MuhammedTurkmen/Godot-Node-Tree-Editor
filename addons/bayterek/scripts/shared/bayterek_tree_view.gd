@tool
class_name BayterekTreeView
extends Control
## Editör canvas'ı.

signal node_created(node: BayterekNodeButton)
signal selection_changed(selected: Array)
signal node_moved(node: BayterekNodeButton)
signal changed

var main_container: Control
var background_container: Control
var grid: BayterekProceduralGrid
var decorations_container: Control
var lines_container: Control
var nodes_container: Control

var camera: BayterekCamera
var nodes_service: BayterekNodesService
var connections_service: BayterekConnectionsService
var selection_box: BayterekSelectionBox

var undo_redo_provider: Object = null

var selected_nodes: Array[BayterekNodeButton] = []

var _tree_data: BayterekTree

# --- Drag state ---
var _dragging: bool = false
var _drag_start_mouse_tree: Vector2 = Vector2.ZERO
var _drag_start_positions: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS

func load_tree(tree_data: BayterekTree) -> void:
	_tree_data = tree_data

	_create_containers()
	_create_background()
	_create_grid()
	_create_camera()
	_create_services()
	_create_selection_box()

# ============================================================
# INPUT
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if camera:
		camera.input(event)

	if selection_box:
		selection_box.handle_input(event)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DELETE:
			if not selected_nodes.is_empty():
				delete_selected()
				get_viewport().set_input_as_handled()

# ============================================================
# SEÇİM
# ============================================================

func select_node(node: BayterekNodeButton, additive: bool = false) -> void:
	if not node:
		return
	if node.node_data and node.node_data.locked:
		return

	if additive:
		if selected_nodes.has(node):
			selected_nodes.erase(node)
			node.set_selected(false)
		else:
			selected_nodes.append(node)
			node.set_selected(true)
	else:
		clear_selection()
		selected_nodes.append(node)
		node.set_selected(true)

	selection_changed.emit(selected_nodes)

func clear_selection() -> void:
	for node in selected_nodes:
		if is_instance_valid(node):
			node.set_selected(false)
	selected_nodes.clear()
	selection_changed.emit(selected_nodes)

func delete_selected() -> void:
	if selected_nodes.is_empty():
		return

	# Locked olanları ayıkla
	var to_delete: Array = []
	for n in selected_nodes:
		if is_instance_valid(n) and not n.node_data.locked:
			to_delete.append(n)

	if to_delete.is_empty():
		return

	clear_selection()

	if not undo_redo_provider or not undo_redo_provider.undo_redo:
		for node in to_delete:
			if is_instance_valid(node):
				connections_service.remove_all_connections_of(node)
				nodes_service.delete_node(node)
		changed.emit()
		return

	var undo_redo: UndoRedo = undo_redo_provider.undo_redo
	undo_redo.create_action("Delete Nodes")

	var connections_to_restore: Array = []
	for node in to_delete:
		if not is_instance_valid(node) or not node.node_data:
			continue
		for to_id in node.node_data.out_nodes:
			connections_to_restore.append({"from_id": node.id, "to_id": to_id})
		for from_id in node.node_data.in_nodes:
			connections_to_restore.append({"from_id": from_id, "to_id": node.id})

	var nodes_data: Array = []
	var nodes_indices: Array = []
	for node in to_delete:
		if is_instance_valid(node):
			nodes_data.append(node.node_data)
			nodes_indices.append(_tree_data.nodes.find(node.node_data))

	undo_redo.add_do_method(_do_delete_nodes.bind(to_delete))
	undo_redo.add_undo_method(_undo_delete_nodes.bind(to_delete, nodes_data, nodes_indices, connections_to_restore))

	undo_redo.commit_action()
	changed.emit()

func _do_delete_nodes(nodes: Array) -> void:
	for node in nodes:
		if is_instance_valid(node):
			connections_service.remove_all_connections_of(node)
			nodes_service.delete_node(node)

func _undo_delete_nodes(nodes: Array, nodes_data: Array, indices: Array, connections: Array) -> void:
	for i in range(nodes.size()):
		if i < nodes_data.size() and i < indices.size():
			nodes_service.restore_node(nodes[i], nodes_data[i], indices[i])

	for conn in connections:
		var from_node: BayterekNodeButton = nodes_service.get_node(conn["from_id"])
		var to_node: BayterekNodeButton = nodes_service.get_node(conn["to_id"])
		if from_node and to_node:
			connections_service.create_connection(from_node, to_node)

# ============================================================
# BAĞLANTI OLUŞTURMA (Shift + Tık)
# ============================================================

func _on_node_pressed_internal(node: BayterekNodeButton, additive: bool) -> void:
	if not node or not node.node_data:
		return
	# Locked node'a tıklanırsa hiçbir şey yapma
	if node.node_data.locked:
		return

	var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)

	if shift_pressed and not selected_nodes.is_empty():
		var created_connections: Array = []
		for from_node in selected_nodes:
			if from_node == node:
				continue
			if from_node.node_data.locked:
				continue
			if connections_service.has_line(from_node.id, node.id):
				continue

			if undo_redo_provider and undo_redo_provider.undo_redo:
				var undo_redo: UndoRedo = undo_redo_provider.undo_redo
				undo_redo.create_action("Create Connection")
				undo_redo.add_do_method(_do_create_connection.bind(from_node, node))
				undo_redo.add_undo_method(_do_remove_connection.bind(from_node.id, node.id))
				undo_redo.commit_action()
			else:
				connections_service.create_connection(from_node, node)

			created_connections.append([from_node.id, node.id])

		if not created_connections.is_empty():
			changed.emit()
		return

	select_node(node, additive)

func _do_create_connection(from_node: BayterekNodeButton, to_node: BayterekNodeButton) -> void:
	connections_service.create_connection(from_node, to_node)

func _do_remove_connection(from_id: int, to_id: int) -> void:
	connections_service.remove_connection(from_id, to_id)

# ============================================================
# TAŞIMA
# ============================================================

func _on_node_drag_started(node: BayterekNodeButton, mouse_screen_pos: Vector2) -> void:
	if not node or not node.node_data:
		return
	if node.node_data.locked:
		return

	if not selected_nodes.has(node):
		if not Input.is_key_pressed(KEY_CTRL):
			select_node(node)

	_dragging = true
	_drag_start_mouse_tree = screen_to_tree(mouse_screen_pos)
	_drag_start_positions.clear()

	for n in selected_nodes:
		if is_instance_valid(n):
			_drag_start_positions[n] = n.node_data.position

func _on_node_dragged(node: BayterekNodeButton, mouse_screen_pos: Vector2) -> void:
	if not _dragging:
		return

	var current_mouse_tree: Vector2 = screen_to_tree(mouse_screen_pos)
	var delta: Vector2 = current_mouse_tree - _drag_start_mouse_tree

	var snap_enabled: bool = Input.is_key_pressed(KEY_SHIFT)
	var grid_size: Vector2 = Bayterek.GRID_CELL_SIZE

	for n in _drag_start_positions.keys():
		if not is_instance_valid(n):
			continue
		var start_pos: Vector2 = _drag_start_positions[n]
		var new_pos: Vector2 = start_pos + delta

		if snap_enabled:
			new_pos = Vector2(
				round(new_pos.x / grid_size.x) * grid_size.x,
				round(new_pos.y / grid_size.y) * grid_size.y
			)

		nodes_service.update_position(n, new_pos)
		connections_service.update_lines_of(n)

	if not selected_nodes.is_empty():
		if selected_nodes.size() == 1:
			node_moved.emit(selected_nodes[0])
		elif selected_nodes.has(node):
			node_moved.emit(node)

func _on_node_drag_ended(node: BayterekNodeButton) -> void:
	if not _dragging:
		return

	_dragging = false

	var start_positions: Dictionary = {}
	var end_positions: Dictionary = {}

	for n in _drag_start_positions.keys():
		if not is_instance_valid(n):
			continue
		start_positions[n] = _drag_start_positions[n]
		end_positions[n] = n.node_data.position

	_drag_start_positions.clear()

	var any_moved := false
	for n in start_positions.keys():
		if start_positions[n] != end_positions[n]:
			any_moved = true
			break

	if not any_moved:
		return

	if not undo_redo_provider or not undo_redo_provider.undo_redo:
		changed.emit()
		return

	var undo_redo: UndoRedo = undo_redo_provider.undo_redo
	undo_redo.create_action("Move Nodes")

	undo_redo.add_do_method(_apply_positions.bind(end_positions))
	undo_redo.add_undo_method(_apply_positions.bind(start_positions))

	undo_redo.commit_action()
	changed.emit()

func _apply_positions(positions: Dictionary) -> void:
	for n in positions.keys():
		if is_instance_valid(n):
			nodes_service.update_position(n, positions[n])
			connections_service.update_lines_of(n)

	if not selected_nodes.is_empty():
		if selected_nodes.size() == 1:
			node_moved.emit(selected_nodes[0])

# ============================================================
# SELECTION BOX
# ============================================================

func _on_selection_box_selected(rect: Rect2) -> void:
	if rect.size.x < 1.0 and rect.size.y < 1.0:
		clear_selection()
		return

	var additive: bool = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
	if not additive:
		clear_selection()

	for node in nodes_service.get_all_nodes():
		if not is_instance_valid(node):
			continue
		if node.node_data and node.node_data.locked:
			continue
		var node_rect := Rect2(node.node_data.position - (node.size * 0.5), node.size)
		if rect.intersects(node_rect):
			select_node(node, true)

# ============================================================
# CONTAINERS
# ============================================================

func _create_containers() -> void:
	main_container = Control.new()
	main_container.name = "MainContainer"
	main_container.mouse_filter = Control.MOUSE_FILTER_PASS
	main_container.anchor_left = 0.5
	main_container.anchor_top = 0.5
	main_container.anchor_right = 0.5
	main_container.anchor_bottom = 0.5
	main_container.offset_left = -_tree_data.size.x / 2.0
	main_container.offset_top = -_tree_data.size.y / 2.0
	main_container.offset_right = _tree_data.size.x / 2.0
	main_container.offset_bottom = _tree_data.size.y / 2.0
	main_container.pivot_offset = _tree_data.size / 2.0
	main_container.offset_transform_enabled = true
	main_container.offset_transform_visual_only = false
	main_container.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
	add_child(main_container)

	background_container = Control.new()
	background_container.name = "BackgroundContainer"
	background_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_child(background_container)

	decorations_container = Control.new()
	decorations_container.name = "DecorationsContainer"
	decorations_container.mouse_filter = Control.MOUSE_FILTER_PASS
	decorations_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_child(decorations_container)

	lines_container = Control.new()
	lines_container.name = "LinesContainer"
	lines_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_child(lines_container)

	nodes_container = Control.new()
	nodes_container.name = "NodesContainer"
	nodes_container.mouse_filter = Control.MOUSE_FILTER_PASS
	nodes_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_child(nodes_container)

func _create_background() -> void:
	var color_rect := ColorRect.new()
	color_rect.name = "BackgroundColor"
	color_rect.color = _tree_data.bg_color
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_container.add_child(color_rect)

	var texture_rect := TextureRect.new()
	texture_rect.name = "BackgroundTexture"
	texture_rect.texture = _tree_data.bg_texture
	texture_rect.stretch_mode = TextureRect.STRETCH_TILE
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_rect.visible = _tree_data.bg_texture != null
	background_container.add_child(texture_rect)

func _create_grid() -> void:
	grid = BayterekProceduralGrid.new()
	grid.name = "Grid"
	grid.target = main_container
	grid.cell_size = Bayterek.GRID_CELL_SIZE
	grid.primary_line_step = Bayterek.GRID_PRIMARY_STEP
	grid.line_color = Bayterek.GRID_LINE_COLOR
	grid.line_width = Bayterek.GRID_LINE_WIDTH
	add_child(grid)
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _create_camera() -> void:
	camera = BayterekCamera.new()
	camera.set_viewport(main_container)
	var half_size: Vector2 = _tree_data.size / 2.0
	camera.set_bounds(Rect2(-half_size, _tree_data.size))

func _create_services() -> void:
	nodes_service = BayterekNodesService.new(self)
	nodes_service.load_tree(_tree_data)
	nodes_service.node_created.connect(_on_nodes_service_node_created)
	nodes_service.node_pressed.connect(_on_node_pressed_internal)
	nodes_service.node_drag_started.connect(_on_node_drag_started)
	nodes_service.node_dragged.connect(_on_node_dragged)
	nodes_service.node_drag_ended.connect(_on_node_drag_ended)

	connections_service = BayterekConnectionsService.new(self)
	connections_service.load_tree(_tree_data)

func _create_selection_box() -> void:
	selection_box = BayterekSelectionBox.new()
	selection_box.set_view(self)
	selection_box.selected.connect(_on_selection_box_selected)
	add_child(selection_box)

# ============================================================
# KOORDİNAT
# ============================================================

func screen_to_tree(screen_pos: Vector2) -> Vector2:
	var local: Vector2 = main_container.get_global_transform().affine_inverse() * (get_global_transform() * screen_pos)
	return local - (_tree_data.size * 0.5)

# ============================================================
# SIGNAL FORWARDING
# ============================================================

func _on_nodes_service_node_created(node: BayterekNodeButton) -> void:
	node_created.emit(node)