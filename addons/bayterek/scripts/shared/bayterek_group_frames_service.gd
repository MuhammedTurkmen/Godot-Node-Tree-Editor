@tool
class_name BayterekGroupFramesService
extends BayterekBaseService
## Canvas'taki grup frame'lerini yönetir.
##
## Frame'ler event almaz. Tıklama/drag tamamen manuel hit-test ile
## yönetilir: BayterekTreeView._handle_group_frame_input() bu servise
## mc_local pozisyonunu verir, servis hangi frame'in seçildiğini ve
## nasıl hareket ettiğini bilir.

signal frame_pressed(group_id: String, additive: bool)
signal frame_drag_started(group_id: String)
signal frame_dragged(group_id: String, delta: Vector2)
signal frame_drag_ended(group_id: String)

var _frames: Dictionary = {}   # group_id -> BayterekGroupFrame

## Frame'lerin eklendiği container. TreeView tarafından atanır.
var _frame_container: Control

## Drag state (mc_local coordinates — main_container local space)
var _drag_start_positions: Dictionary = {}   # BayterekNodeButton -> Vector2
var _drag_start_mc_local: Vector2 = Vector2.ZERO
var _dragging_group_id: String = ""

## Selection state
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
	print("[GROUP_FRAMES] rebuild()")
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

	print("[GROUP_FRAMES] create frame: ", group.name)

	var frame := BayterekGroupFrame.new()
	frame.name = "GroupFrame_%s" % group.id
	frame.group_id = group.id
	frame.group_name = group.name
	frame.group_color = group.color

	_frame_container.add_child(frame)
	_frames[group.id] = frame

	var members: Array = _collect_members(group.id)
	frame.fit_to_members(members)

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

	var members: Array = _collect_members(group_id)
	frame.fit_to_members(members)

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
func hit_test(mc_local_pos: Vector2) -> BayterekGroupFrame:
	print("[GROUP_FRAMES] hit_test at ", mc_local_pos, " frame count=", _frames.size())

	var keys: Array = _frames.keys()
	for i in range(keys.size() - 1, -1, -1):
		var gid: String = keys[i]
		var frame: BayterekGroupFrame = _frames[gid]
		if not is_instance_valid(frame) or not frame.visible:
			continue

		var rect: Rect2 = Rect2(frame.position, frame.size)
		var in_body: bool = rect.has_point(mc_local_pos)
		print("[GROUP_FRAMES]   frame ", frame.group_name, " rect=", rect, " in_body=", in_body)

		if not in_body:
			continue

		var title_rect := Rect2(frame.position, Vector2(frame.size.x, BayterekGroupFrame.TITLE_HEIGHT))
		var in_title: bool = title_rect.has_point(mc_local_pos)
		print("[GROUP_FRAMES]   title_rect=", title_rect, " in_title=", in_title)

		if in_title:
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
	print("[GROUP_FRAMES] start_drag frame=", frame.group_name if frame else "NULL", " mc_local=", mc_local)

	if not frame or not _tree_view:
		return

	_dragging_group_id = frame.group_id
	_drag_start_mc_local = mc_local
	_drag_start_positions.clear()

	var members: Array = _collect_members(frame.group_id)
	for node in members:
		if is_instance_valid(node):
			_drag_start_positions[node] = node.node_data.position

	print("[GROUP_FRAMES]   drag members=", _drag_start_positions.size())

	frame_drag_started.emit(frame.group_id)

func update_drag(frame: BayterekGroupFrame, mc_local: Vector2) -> void:
	print("[GROUP_FRAMES] update_drag mc_local=", mc_local, " dragging_id=", _dragging_group_id)

	if not _tree_view or _dragging_group_id.is_empty():
		print("[GROUP_FRAMES]   early return (no drag active)")
		return
	if not is_instance_valid(frame):
		return

	var delta: Vector2 = mc_local - _drag_start_mc_local
	print("[GROUP_FRAMES]   delta=", delta, " node count=", _drag_start_positions.size())

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
	print("[GROUP_FRAMES] end_drag dragging_id=", _dragging_group_id)

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