@tool
class_name BayterekGroupFramesService
extends BayterekBaseService
## Canvas'taki grup frame'lerini yönetir.

signal frame_pressed(group_id: String, additive: bool)
signal frame_drag_started(group_id: String)
signal frame_dragged(group_id: String, delta: Vector2)
signal frame_drag_ended(group_id: String)

## When true, group frames become draggable at runtime as well. Editor
## frames are always draggable regardless of this flag.
@export var runtime_draggable: bool = false

var _frames: Dictionary = {}   # group_id -> BayterekGroupFrame

var _frame_container: Control

var _drag_start_positions: Dictionary = {}
var _drag_start_mc_local: Vector2 = Vector2.ZERO
var _dragging_group_id: String = ""

var selected_group_id: String = ""

func set_container(container: Control) -> void:
	_frame_container = container

# ============================================================
# LOAD / REBUILD
# ============================================================

func load_tree(tree_data: BayterekTree) -> void:
	_tree_data = tree_data
	rebuild()

func rebuild() -> void:
	_clear_all_frames()

	if not _tree_data:
		return

	for group in _tree_data.node_groups:
		if group:
			_create_frame(group)

	refresh_all()

func _clear_all_frames() -> void:
	for frame in _frames.values():
		if is_instance_valid(frame):
			frame.queue_free()
	_frames.clear()
	selected_group_id = ""
	_dragging_group_id = ""
	_drag_start_positions.clear()

func _create_frame(group: BayterekNodeGroup) -> void:
	if not _frame_container:
		push_warning("BayterekGroupFramesService: _frame_container is null!")
		return

	var frame := BayterekGroupFrame.new()
	frame.name = "GroupFrame_%s" % group.id
	frame.group_id = group.id
	frame.group_name = group.name
	frame.group_color = group.color
	frame.title_align = _tree_data.group_frame_title_align if _tree_data else 0

	_frame_container.add_child(frame)
	_frames[group.id] = frame

	var members: Array = _collect_members(group.id)
	frame.fit_to_members(members)
	_apply_visibility(frame)

# ============================================================
# UPDATE
# ============================================================

func refresh_group(group_id: String) -> void:
	if not _frames.has(group_id):
		return
	var frame: BayterekGroupFrame = _frames[group_id]
	if not is_instance_valid(frame):
		return

	var group: BayterekNodeGroup = _tree_data.get_group_by_id(group_id) if _tree_data else null
	if group:
		frame.group_name = group.name
		frame.group_color = group.color

	if _tree_data:
		frame.title_align = _tree_data.group_frame_title_align

	var members: Array = _collect_members(group_id)
	frame.fit_to_members(members)
	_apply_visibility(frame)

func refresh_all() -> void:
	for group_id in _frames.keys():
		refresh_group(group_id)

func on_node_moved(node: BayterekNodeButton) -> void:
	if not node or not node.node_data:
		return
	var gid: String = node.node_data.group_id
	if gid.is_empty():
		return
	refresh_group(gid)

func on_node_group_changed(node: BayterekNodeButton, old_group_id: String, new_group_id: String) -> void:
	if not old_group_id.is_empty():
		refresh_group(old_group_id)
	if not new_group_id.is_empty():
		refresh_group(new_group_id)

## Applies runtime visibility. In editor: always visible (fit_to_members
## already controls visibility based on member count). At runtime: only
## visible if tree.show_group_frames is true.
func _apply_visibility(frame: BayterekGroupFrame) -> void:
	if not frame:
		return
	if Engine.is_editor_hint():
		return
	if _tree_data and not _tree_data.show_group_frames:
		frame.visible = false

# ============================================================
# MEMBER COLLECTION
# ============================================================

func _collect_members(group_id: String) -> Array:
	if not _tree_view or not _tree_view.nodes_service:
		return []

	var result: Array = []
	for node in _tree_view.nodes_service.get_all_nodes():
		if not is_instance_valid(node) or not node.node_data:
			continue
		if node.node_data.group_id == group_id:
			result.append(node)
	return result

# ============================================================
# HIT TESTING
# ============================================================

## Returns the topmost group frame whose TITLE BAR contains `mc_local_pos`.
##
## Editor: always enabled.
## Runtime: only when `runtime_draggable` is true.
func hit_test(mc_local_pos: Vector2) -> BayterekGroupFrame:
	if not Engine.is_editor_hint() and not runtime_draggable:
		return null

	var keys: Array = _frames.keys()
	for i in range(keys.size() - 1, -1, -1):
		var gid: String = keys[i]
		var frame: BayterekGroupFrame = _frames[gid]
		if not is_instance_valid(frame) or not frame.visible:
			continue

		var rect: Rect2 = Rect2(frame.position, frame.size)
		if not rect.has_point(mc_local_pos):
			continue

		var title_rect := Rect2(frame.position, Vector2(frame.size.x, BayterekGroupFrame.TITLE_HEIGHT))
		if title_rect.has_point(mc_local_pos):
			return frame
		return null

	return null

# ============================================================
# SELECTION
# ============================================================

func set_selected(group_id: String) -> void:
	selected_group_id = group_id
	for gid in _frames.keys():
		var frame: BayterekGroupFrame = _frames[gid]
		if is_instance_valid(frame):
			frame.selected = (gid == group_id)
			frame.queue_redraw()

func clear_selection() -> void:
	set_selected("")

# ============================================================
# DRAG
# ============================================================

func start_drag(frame: BayterekGroupFrame, mc_local: Vector2) -> void:
	if not frame or not _tree_view:
		return

	_dragging_group_id = frame.group_id
	_drag_start_mc_local = mc_local
	_drag_start_positions.clear()

	var members: Array = _collect_members(frame.group_id)
	for node in members:
		if is_instance_valid(node):
			_drag_start_positions[node] = node.node_data.position

	frame_drag_started.emit(frame.group_id)

func update_drag(frame: BayterekGroupFrame, mc_local: Vector2) -> void:
	if not _tree_view or _dragging_group_id.is_empty():
		return
	if not is_instance_valid(frame):
		return

	var delta: Vector2 = mc_local - _drag_start_mc_local

	for node in _drag_start_positions.keys():
		if not is_instance_valid(node):
			continue
		var start_pos: Vector2 = _drag_start_positions[node]
		var new_pos: Vector2 = start_pos + delta
		_tree_view.nodes_service.update_position(node, new_pos)
		_tree_view.connections_service.update_lines_of(node)

	refresh_group(_dragging_group_id)

	frame_dragged.emit(frame.group_id, delta)

func end_drag(frame: BayterekGroupFrame) -> void:
	if _dragging_group_id.is_empty():
		return

	var start_positions: Dictionary = {}
	var end_positions: Dictionary = {}

	for node in _drag_start_positions.keys():
		if is_instance_valid(node):
			start_positions[node] = _drag_start_positions[node]
			end_positions[node] = node.node_data.position

	_drag_start_positions.clear()

	var group_id: String = _dragging_group_id
	_dragging_group_id = ""

	frame_drag_ended.emit(group_id)

	if _tree_view.undo_redo_provider and _tree_view.undo_redo_provider.undo_redo:
		var undo_redo: UndoRedo = _tree_view.undo_redo_provider.undo_redo
		undo_redo.create_action("Move Group")
		undo_redo.add_do_method(_apply_group_positions.bind(end_positions, group_id))
		undo_redo.add_undo_method(_apply_group_positions.bind(start_positions, group_id))
		undo_redo.commit_action()

func _apply_group_positions(positions: Dictionary, group_id: String) -> void:
	for node in positions.keys():
		if is_instance_valid(node):
			_tree_view.nodes_service.update_position(node, positions[node])
			_tree_view.connections_service.update_lines_of(node)
	refresh_group(group_id)