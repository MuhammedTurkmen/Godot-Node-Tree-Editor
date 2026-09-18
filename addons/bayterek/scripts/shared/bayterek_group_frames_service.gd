@tool
class_name BayterekGroupFramesService
extends BayterekBaseService
## Canvas'taki grup frame'lerini yönetir.
##
## Her grup için bir BayterekGroupFrame oluşturur, konumunu günceller,
## seçim ve sürükleme olaylarını tree_view'a yönlendirir.

signal frame_pressed(group_id: String, additive: bool)
signal frame_drag_started(group_id: String)
signal frame_dragged(group_id: String, delta: Vector2)
signal frame_drag_ended(group_id: String)

var _frames: Dictionary = {}   # group_id -> BayterekGroupFrame

## Frame'lerin eklendiği container. TreeView tarafından atanır.
var _frame_container: Control

## Drag state
var _drag_start_positions: Dictionary = {}   # BayterekNodeButton -> Vector2
var _drag_start_mouse_tree: Vector2 = Vector2.ZERO
var _dragging_group_id: String = ""

func set_container(container: Control) -> void:
	_frame_container = container

# ============================================================
# LOAD / REBUILD
# ============================================================

func load_tree(tree_data: BayterekTree) -> void:
	_tree_data = tree_data
	rebuild()

## Tüm frame'leri sıfırdan oluşturur. Grup eklenince/silinince çağrılır.
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

func _create_frame(group: BayterekNodeGroup) -> void:
	if not _frame_container:
		push_warning("BayterekGroupFramesService: _frame_container is null!")
		return

	print("[FramesService] creating frame, container=", _frame_container.name, " filter=", _frame_container.mouse_filter)

	var frame := BayterekGroupFrame.new()
	frame.name = "GroupFrame_%s" % group.id
	frame.group_id = group.id
	frame.group_name = group.name
	frame.group_color = group.color
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

	frame.frame_pressed.connect(_on_frame_pressed)
	frame.frame_drag_started.connect(_on_frame_drag_started)
	frame.frame_dragged.connect(_on_frame_dragged)
	frame.frame_drag_ended.connect(_on_frame_drag_ended)

	_frame_container.add_child(frame)
	_frames[group.id] = frame

	# Immediately compute the bounding box from members so the frame
	# isn't left at size (0, 0).
	var members: Array = _collect_members(group.id)
	frame.fit_to_members(members)

	# Defer a debug report so we see the real size after layout.
	frame.call_deferred("_debug_report")

# ============================================================
# UPDATE
# ============================================================

## Tek bir frame'i günceller.
func refresh_group(group_id: String) -> void:
	if not _frames.has(group_id):
		return
	var frame: BayterekGroupFrame = _frames[group_id]
	if not is_instance_valid(frame):
		return

	# Grup bilgisini güncelle (isim/renk değişmiş olabilir)
	var group: BayterekNodeGroup = _tree_data.get_group_by_id(group_id) if _tree_data else null
	if group:
		frame.group_name = group.name
		frame.group_color = group.color

	# Üyeleri topla
	var members: Array = _collect_members(group_id)
	frame.fit_to_members(members)

## Tüm frame'leri günceller.
func refresh_all() -> void:
	for group_id in _frames.keys():
		refresh_group(group_id)

## Node'un bulunduğu grubun frame'ini günceller.
func on_node_moved(node: BayterekNodeButton) -> void:
	if not node or not node.node_data:
		return
	var gid: String = node.node_data.group_id
	if gid.is_empty():
		return
	refresh_group(gid)

## Node'un grubu değiştiğinde (assign/remove) eski ve yeni frame'i güncelle.
func on_node_group_changed(node: BayterekNodeButton, old_group_id: String, new_group_id: String) -> void:
	if not old_group_id.is_empty():
		refresh_group(old_group_id)
	if not new_group_id.is_empty():
		refresh_group(new_group_id)

# ============================================================
# SELECTION
# ============================================================

## Tree view, seçim değiştiğinde hangi frame'lerin seçili olduğunu bildirir.
func set_selected_groups(group_ids: Array) -> void:
	for gid in _frames.keys():
		var frame: BayterekGroupFrame = _frames[gid]
		if is_instance_valid(frame):
			frame.selected = gid in group_ids
			frame.queue_redraw()

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
# DRAG HANDLING
# ============================================================

func _on_frame_pressed(frame: BayterekGroupFrame, additive: bool) -> void:
	print("[FramesService] frame_pressed: ", frame.group_name)
	frame_pressed.emit(frame.group_id, additive)

func _on_frame_drag_started(frame: BayterekGroupFrame, screen_pos: Vector2) -> void:
	print("[FramesService] frame_drag_started: ", frame.group_name)
	if not _tree_view:
		return

	_dragging_group_id = frame.group_id
	_drag_start_positions.clear()

	var members: Array = _collect_members(frame.group_id)
	for node in members:
		if is_instance_valid(node):
			_drag_start_positions[node] = node.node_data.position

	_drag_start_mouse_tree = _tree_view.screen_to_tree(screen_pos)

	frame_drag_started.emit(frame.group_id)

func _on_frame_dragged(frame: BayterekGroupFrame, screen_pos: Vector2) -> void:
	if not _tree_view or _dragging_group_id.is_empty():
		return

	var current_mouse_tree: Vector2 = _tree_view.screen_to_tree(screen_pos)
	var delta: Vector2 = current_mouse_tree - _drag_start_mouse_tree

	for node in _drag_start_positions.keys():
		if not is_instance_valid(node):
			continue
		var start_pos: Vector2 = _drag_start_positions[node]
		var new_pos: Vector2 = start_pos + delta
		_tree_view.nodes_service.update_position(node, new_pos)
		_tree_view.connections_service.update_lines_of(node)

	# Update this frame's rect (bulk update happens on release)
	refresh_group(_dragging_group_id)

	frame_dragged.emit(frame.group_id, delta)

func _on_frame_drag_ended(frame: BayterekGroupFrame) -> void:
	if _dragging_group_id.is_empty():
		return

	# Build start/end position maps for undo_redo
	var start_positions: Dictionary = {}
	var end_positions: Dictionary = {}

	for node in _drag_start_positions.keys():
		if is_instance_valid(node):
			start_positions[node] = _drag_start_positions[node]
			end_positions[node] = node.node_data.position

	_drag_start_positions.clear()

	var group_id: String = _dragging_group_id
	_dragging_group_id = ""

	# Emit signal so editor can push an undo action
	frame_drag_ended.emit(group_id)

	# If tree_view has an undo provider, push the action
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