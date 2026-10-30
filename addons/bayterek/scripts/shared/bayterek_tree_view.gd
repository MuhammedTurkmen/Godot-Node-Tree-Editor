@tool
class_name BayterekTreeView
extends Control
## Editor canvas AND runtime tree view.

signal node_created(node: BayterekNodeButton)
signal node_deleted(node: BayterekNodeButton)
signal selection_changed(selected: Array)
signal node_moved(node: BayterekNodeButton)
signal prefab_dropped(prefab: BayterekPrefab, at_tree_position: Vector2)
signal design_dropped(design: BayterekNodeDesign, at_tree_position: Vector2)
signal changed
signal node_right_clicked(node: BayterekNodeButton, screen_pos: Vector2)
signal canvas_right_clicked(global_pos: Vector2, tree_pos: Vector2)

signal tree_version_mismatch(tree: BayterekTree, saved_version: int)
signal node_allocated(node: BayterekNode)
signal node_deallocated(node: BayterekNode)
signal prefab_created(prefab: BayterekPrefab)
signal line_created(line: BayterekConnection, from_id: int, to_id: int)
signal line_clicked_for_delete(from_id: int, to_id: int)

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

@export var hover_animations_enabled: bool = true

@export var hover_enter_preset: String = "hover_enter"
@export var hover_exit_preset: String = "hover_exit"
@export var hover_enter_opts: Dictionary = {
	"lift": -8.0,
	"rot_peak": 5.0,
	"duration": 0.45,
	"easing": "smooth",
}
@export var hover_exit_opts: Dictionary = {
	"duration": 0.3,
	"easing": "smooth",
}

@export var wiggle_enabled: bool = false

var main_container: Control
var background_container: Control
var group_frames_container: Control
var grid: BayterekProceduralGrid
var decorations_container: Control
var lines_container: Control
var nodes_container: Control

var camera: BayterekCamera
var nodes_service: BayterekNodesService
var connections_service: BayterekConnectionsService
var prefabs_service: BayterekPrefabsService
var allocation_service: BayterekAllocationService
var group_frames_service: BayterekGroupFramesService
var selection_box: BayterekSelectionBox

var undo_redo_provider: Object = null

var selected_nodes: Array[BayterekNodeButton] = []

var _tree_data: BayterekTree

var _tooltip: BayterekTooltip
var _hovered_node: BayterekNodeButton = null

var _dragging: bool = false
var _drag_start_mouse_tree: Vector2 = Vector2.ZERO
var _drag_start_positions: Dictionary = {}

var _group_frame_dragging: BayterekGroupFrame = null
var _group_frame_drag_start_mc_local: Vector2 = Vector2.ZERO

# --- Purchase (hold) UI state ---
var _purchase_bar_root: Control = null
var _purchase_bar_fill: ColorRect = null
var _purchase_loop_handle = null
var _purchase_hold_node: BayterekNodeButton = null

# --- Right-click tracking (for context menu) ---
var _right_click_node: BayterekNodeButton = null
var _right_click_screen_pos: Vector2 = Vector2.ZERO

# --- Runtime pan + purchase state ---
## True while the user is dragging on empty canvas (runtime only).
var _runtime_panning: bool = false
## View-local position where the current runtime pan started.
var _runtime_pan_start: Vector2 = Vector2.ZERO
## True once the pointer has moved past the drag threshold.
var _runtime_pan_moved: bool = false
## The node the user pressed on (runtime). Null if the press started on
## empty canvas. Used to decide between "purchase" and "cancel".
var _runtime_pan_node: BayterekNodeButton = null

# ============================================================
# FONT BASE SIZES (tooltip)
# ============================================================

const TOOLTIP_BASE_FONT_SIZE := 14
const TOOLTIP_BASE_HEADER_FONT_SIZE := 16
const TOOLTIP_BASE_FOOTER_FONT_SIZE := 13

## Pixels the pointer must move before a press turns into a drag.
const RUNTIME_DRAG_THRESHOLD := 4.0

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS

	_create_tooltip()
	set_process(true)

func load_tree(tree_data: BayterekTree) -> void:
	_tree_data = tree_data

	hover_animations_enabled = tree_data.hover_animations_enabled
	wiggle_enabled = tree_data.wiggle_enabled

	if _tree_data.tree_state and _tree_data.tree_state.version != _tree_data.version:
		tree_version_mismatch.emit(_tree_data, _tree_data.tree_state.version)

	_create_containers()
	_create_background()
	_create_camera()
	_create_services()
	_create_selection_box()
	_create_purchase_bar()
	_apply_font_overrides()

	_group_frame_dragging = null

	call_deferred("center_camera_on_content")

# ============================================================
# LINE DELETE MODE
# ============================================================

func set_line_delete_mode(enabled: bool) -> void:
	if connections_service:
		connections_service.set_line_delete_mode(enabled)

# ============================================================
# CAMERA CENTERING
# ============================================================

func center_camera_on_content() -> void:
	if not camera or not nodes_service:
		return

	var nodes: Array = nodes_service.get_all_nodes()
	if nodes.is_empty():
		camera.focus_on(Vector2.ZERO, 1.0)
		return

	var sum: Vector2 = Vector2.ZERO
	var count: int = 0
	for node in nodes:
		if is_instance_valid(node) and node.node_data:
			sum += node.node_data.position
			count += 1

	if count == 0:
		camera.focus_on(Vector2.ZERO, 1.0)
		return

	var centroid: Vector2 = sum / float(count)
	camera.focus_on(centroid, 1.0)

# ============================================================
# SCROLL / FOCUS HELPERS
# ============================================================

func scroll_to_node(node: BayterekNodeButton) -> void:
	if not node or not node.node_data or not camera:
		return

	var viewport_size: Vector2 = size
	var node_pos: Vector2 = node.node_data.position

	var zoom: float = camera.get_zoom()
	var centered_offset: Vector2 = node_pos * zoom

	var safe_margin: Vector2 = viewport_size * 0.15
	var half: Vector2 = viewport_size * 0.5
	var screen_pos: Vector2 = half + centered_offset

	var inside_x: bool = screen_pos.x > safe_margin.x and screen_pos.x < viewport_size.x - safe_margin.x
	var inside_y: bool = screen_pos.y > safe_margin.y and screen_pos.y < viewport_size.y - safe_margin.y
	if inside_x and inside_y:
		return

	camera.focus_on(node_pos, zoom)

# ============================================================
# TOOLTIP
# ============================================================

func _create_tooltip() -> void:
	_tooltip = BayterekTooltip.new()
	_tooltip.name = "BayterekTooltip"
	_tooltip.tree_view = self
	_tooltip.position_mode = BayterekTooltip.PositionMode.NEAR_NODE
	_tooltip.corner = Bayterek.TooltipCorner.BOTTOM_RIGHT
	_tooltip.z_index = 100
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(_tooltip)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.border_color = Color(0.3, 0.3, 0.3, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_tooltip.add_theme_stylebox_override("panel", style)

# ============================================================
# TOOLTIP CONFIGURATION
# ============================================================

func set_tooltip_near_node_right() -> void:
	if _tooltip:
		_tooltip.tree_view = self
		_tooltip.set_position_right()

func set_tooltip_near_node_left() -> void:
	if _tooltip:
		_tooltip.tree_view = self
		_tooltip.set_position_left()

func set_tooltip_near_node_top() -> void:
	if _tooltip:
		_tooltip.tree_view = self
		_tooltip.set_position_top()

func set_tooltip_near_node_bottom() -> void:
	if _tooltip:
		_tooltip.tree_view = self
		_tooltip.set_position_bottom()

func set_tooltip_near_node_offset(offset: Vector2) -> void:
	if _tooltip:
		_tooltip.tree_view = self
		_tooltip.position_mode = BayterekTooltip.PositionMode.NEAR_NODE
		_tooltip.node_offset = offset

func set_tooltip_corner_top_left() -> void:
	if _tooltip:
		_tooltip.tree_view = self
		_tooltip.set_corner_top_left()

func set_tooltip_corner_top_right() -> void:
	if _tooltip:
		_tooltip.tree_view = self
		_tooltip.set_corner_top_right()

func set_tooltip_corner_bottom_left() -> void:
	if _tooltip:
		_tooltip.tree_view = self
		_tooltip.set_corner_bottom_left()

func set_tooltip_corner_bottom_right() -> void:
	if _tooltip:
		_tooltip.tree_view = self
		_tooltip.set_corner_bottom_right()

func set_tooltip_fixed_corner(corner: int, margin: Vector2 = Vector2(20, 20)) -> void:
	if _tooltip:
		_tooltip.tree_view = self
		_tooltip.position_mode = BayterekTooltip.PositionMode.FIXED_CORNER
		_tooltip.corner = corner
		_tooltip.corner_margin = margin

# ============================================================
# NODE HOVER HANDLERS
# ============================================================

func _on_node_hovered(node: BayterekNodeButton, is_hovered: bool) -> void:
	if not _tooltip:
		return

	if node and node.node_data and node.node_data.is_decoration:
		return

	if not hover_animations_enabled:
		if is_hovered:
			_hovered_node = node
			_tooltip.inspect(node)
		else:
			if _hovered_node == node:
				_hovered_node = null
			_tooltip.reset()
		return

	if is_hovered:
		_hovered_node = node
		_tooltip.inspect(node)

		if not hover_enter_preset.is_empty() and node.has_method("play_animation"):
			node.play_animation(hover_enter_preset, hover_enter_opts)
	else:
		if _hovered_node == node:
			_hovered_node = null
		_tooltip.reset()

		if not hover_exit_preset.is_empty() and node.has_method("play_animation"):
			node.play_animation(hover_exit_preset, hover_exit_opts)
		elif node.has_method("stop_animation"):
			node.stop_animation()

func refresh_tooltip_position() -> void:
	if _tooltip and _tooltip.visible and _hovered_node:
		_tooltip.update_position_for(_hovered_node)

func refresh_tooltip_content() -> void:
	if not _tooltip or not _tooltip.visible:
		return
	if not _hovered_node or not is_instance_valid(_hovered_node):
		return
	_tooltip.inspect(_hovered_node)

# ============================================================
# INPUT
# ============================================================

## Global input hook. Runs BEFORE any `_gui_input()`.
##
## This is where runtime pan + purchase live. The reason we use
## `_input()` instead of `_gui_input()` is that nodes have their own
## `_gui_input()` and consume mouse events before they bubble up to
## the tree view. `_input()` sees every event first, so we can always
## decide what to do with a left-click — regardless of which Control
## is under the mouse.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if _is_text_input_focused():
		return

	# RUNTIME: left-click pan + purchase captured here.
	if not Engine.is_editor_hint():
		if _handle_runtime_input_global(event):
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DELETE:
			if not selected_nodes.is_empty():
				delete_selected()
				get_viewport().set_input_as_handled()

## Handles runtime left-click pan + node purchase in global input space.
##
## Returns `true` if the event was fully consumed and the viewport
## should mark it as handled.
##
## IMPORTANT: We must NOT consume clicks that land on OTHER Controls
## (toolbar buttons, HUD panels, overlays). `_input()` runs before any
## `_gui_input()`, so consuming here would starve every sibling UI.
## To prevent that, we only capture a left-click if it actually lands
## inside this TreeView's rect AND no higher-z Control is on top of it.
func _handle_runtime_input_global(event: InputEvent) -> bool:
	if not _tree_data:
		return false

	var local_pos: Vector2

	if event is InputEventMouseButton or event is InputEventMouseMotion:
		local_pos = get_global_transform().affine_inverse() * (event as InputEventMouse).global_position
	else:
		return false

	# --- LEFT PRESS ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# If the click landed on another Control (toolbar, HUD, overlay),
		# let that Control handle it — do not capture.
		if _is_pointer_over_other_control(local_pos):
			return false

		var hit: BayterekNodeButton = _find_node_under_screen_pos(local_pos)

		var allocation_active: bool = _tree_data.allocation
		var can_interact_with_node: bool = (
			hit != null
			and is_instance_valid(hit)
			and hit.node_data != null
			and not hit.node_data.locked
			and allocation_active
		)

		if can_interact_with_node:
			_runtime_pan_node = hit
			_runtime_panning = false
			_runtime_pan_moved = false
			_runtime_pan_start = local_pos

			if allocation_service:
				allocation_service.on_node_press_start(hit)
			return true

		_runtime_pan_node = null
		_runtime_panning = true
		_runtime_pan_moved = false
		_runtime_pan_start = local_pos
		return true

	# --- LEFT RELEASE ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _runtime_pan_node and is_instance_valid(_runtime_pan_node):
			var node: BayterekNodeButton = _runtime_pan_node
			_runtime_pan_node = null

			if allocation_service:
				allocation_service.on_node_press_end(node)
			return true

		if _runtime_panning:
			_runtime_panning = false
			_runtime_pan_moved = false
			return true

		return false

	# --- MOUSE MOTION ---
	if event is InputEventMouseMotion:
		if _runtime_pan_node and is_instance_valid(_runtime_pan_node):
			if not _runtime_pan_moved and local_pos.distance_to(_runtime_pan_start) > RUNTIME_DRAG_THRESHOLD:
				_runtime_pan_moved = true

				if _tree_data.is_hold_purchase_mode():
					if allocation_service:
						allocation_service.on_node_press_end(_runtime_pan_node)
					_runtime_pan_node = null
			return false  # motion should still reach hover/tooltip handlers

		if _runtime_panning:
			var delta: Vector2 = local_pos - _runtime_pan_start
			_runtime_pan_start = local_pos
			_runtime_pan_moved = true
			if camera:
				camera.pan(delta)
			return true

	return false

## Returns true if `view_local_pos` (TreeView-local coordinates) is
## covered by another Control that is NOT a descendant of this TreeView.
##
## We walk the viewport's GUI tree from top (highest z / last child) to
## bottom, looking for the first Control under the pointer. If that
## Control is outside our own subtree, the click belongs to someone
## else (toolbar, HUD, overlay) and we must not intercept it.
func _is_pointer_over_other_control(view_local_pos: Vector2) -> bool:
	var vp: Viewport = get_viewport()
	if not vp:
		return false

	var global_pos: Vector2 = get_global_transform() * view_local_pos

	# `gui_get_hovered_control()` returns the deepest Control under the
	# mouse. It respects z_index, mouse_filter = STOP/PASS, and clipping.
	# This is the single most reliable way to know whether another
	# widget is above us — no manual tree walking needed.
	var hovered: Control = vp.gui_get_hovered_control()
	if not hovered:
		return false
	if hovered == self:
		return false

	# Is `hovered` inside our own subtree? If so, it's a child of this
	# TreeView (e.g. the tooltip, selection box) — that's fine, we own it.
	if is_ancestor_of(hovered):
		return false

	# A foreign Control is on top of us → don't intercept.
	return true

func _gui_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	var editor_mode: bool = Engine.is_editor_hint()

	# 1. Line-delete mode takes priority (editor only).
	if connections_service and connections_service.is_line_delete_mode_active():
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				if _try_delete_line_at(event.position):
					accept_event()
					return

	# 2. Group-frame input (editor only; frames are hidden by default
	#    in runtime, so this is a no-op there anyway).
	if _handle_group_frame_input(event):
		return

	# --- Capture right-drag state BEFORE the camera processes the release.
	var right_was_dragging: bool = false
	if editor_mode and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		right_was_dragging = camera != null and camera.is_right_drag_active()

	# --- Camera input (right-drag pan + wheel zoom; runtime sadece wheel) ---
	if camera:
		if editor_mode:
			camera.input(event)
		else:
			if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
				camera.input(event)

	# --- Selection box (sadece editor + sol tık) ---
	if editor_mode and selection_box:
		selection_box.handle_input(event)

	# --- Editor: sağ tık context menu (sadece boşluk) ---
	if editor_mode and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			var hit: BayterekNodeButton = _find_node_under_screen_pos(event.position)
			_right_click_node = hit
			_right_click_screen_pos = event.position
		else:
			if not right_was_dragging:
				var screen_pos: Vector2 = event.position
				var node_hit: BayterekNodeButton = _right_click_node

				if not (node_hit and is_instance_valid(node_hit)):
					var global_pos2: Vector2 = get_global_transform() * screen_pos
					var tree_pos: Vector2 = screen_to_tree(screen_pos)
					canvas_right_clicked.emit(global_pos2, tree_pos)

			_right_click_node = null
			_right_click_screen_pos = Vector2.ZERO

## Finds the topmost node under a given TREE-VIEW-LOCAL position.
func _find_node_under_screen_pos(view_local_pos: Vector2) -> BayterekNodeButton:
	if not nodes_service:
		return null
	var mc_pos: Vector2 = screen_to_mc_local(view_local_pos)
	var nodes: Array = nodes_service.get_all_nodes()
	# Iterate in reverse so the topmost (last added) node wins.
	for i in range(nodes.size() - 1, -1, -1):
		var node: BayterekNodeButton = nodes[i]
		if not is_instance_valid(node) or not node.is_visible_in_tree():
			continue
		var local_rect := Rect2(node.position, node.size)
		if local_rect.has_point(mc_pos):
			return node
	return null


func _try_delete_line_at(screen_pos: Vector2) -> bool:
	if not connections_service:
		return false

	var mc_pos: Vector2 = screen_to_mc_local(screen_pos)

	var best_from: int = -1
	var best_to: int = -1
	var best_dist_sq: float = INF

	for conn in connections_service._lines.values():
		if not is_instance_valid(conn):
			continue
		var data: BayterekLineData = conn.line_data
		if not data:
			continue
		var ln: BayterekLine2D = conn.line
		if not ln or ln.points.size() < 2:
			continue

		var threshold: float = maxf(12.0, data.thickness * 2.0)
		var threshold_sq: float = threshold * threshold

		for i in range(ln.points.size() - 1):
			var a: Vector2 = ln.points[i]
			var b: Vector2 = ln.points[i + 1]
			var dist_sq: float = _dist_sq_to_segment(mc_pos, a, b)
			if dist_sq <= threshold_sq and dist_sq < best_dist_sq:
				best_dist_sq = dist_sq
				best_from = conn.from_id
				best_to = conn.to_id

	if best_from < 0:
		return false

	connections_service.line_clicked_for_delete.emit(best_from, best_to)
	return true


func _dist_sq_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var ab_len_sq: float = ab.length_squared()
	if ab_len_sq < 0.0001:
		return (p - a).length_squared()
	var t: float = clampf((p - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	var closest: Vector2 = a + ab * t
	return (p - closest).length_squared()


func _is_text_input_focused() -> bool:
	var vp: Viewport = get_viewport()
	if not vp:
		return false

	var focused: Control = vp.gui_get_focus_owner()
	if not focused:
		return false

	if focused is LineEdit or focused is TextEdit or focused is CodeEdit:
		return true

	var node: Node = focused
	var depth: int = 0
	while node and depth < 4:
		if node is LineEdit or node is TextEdit or node is CodeEdit:
			return true
		node = node.get_parent()
		depth += 1

	return false

# ============================================================
# SELECTION
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
				node_deleted.emit(node)
		_refresh_all_allocatable_flags()
		if group_frames_service:
			group_frames_service.refresh_all()
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
			node_deleted.emit(node)
	_refresh_all_allocatable_flags()
	if group_frames_service:
		group_frames_service.refresh_all()

func _undo_delete_nodes(nodes: Array, nodes_data: Array, indices: Array, connections: Array) -> void:
	for i in range(nodes.size()):
		if i < nodes_data.size() and i < indices.size():
			nodes_service.restore_node(nodes[i], nodes_data[i], indices[i])

	for conn in connections:
		var from_node: BayterekNodeButton = nodes_service.get_node(conn["from_id"])
		var to_node: BayterekNodeButton = nodes_service.get_node(conn["to_id"])
		if from_node and to_node:
			connections_service.create_connection(from_node, to_node)

	_refresh_all_allocatable_flags()
	if group_frames_service:
		group_frames_service.refresh_all()

# ============================================================
# CONNECTION CREATION + ALLOCATION/SELECTION
# ============================================================

func _on_node_pressed_internal(node: BayterekNodeButton, additive: bool) -> void:
	if not node or not node.node_data:
		return
	if node.node_data.locked:
		return

	if connections_service and connections_service.is_line_delete_mode_active():
		return

	var ctrl_held: bool = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
	if _is_allocation_active() and not ctrl_held:
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
			if _is_chain_mode_active():
				clear_selection()
				select_node(node)
			changed.emit()
		return

	select_node(node, additive)

func _is_chain_mode_active() -> bool:
	if undo_redo_provider and undo_redo_provider.has_method("get_chain_connection_mode"):
		return undo_redo_provider.get_chain_connection_mode()
	return false

func _is_allocation_active() -> bool:
	return _tree_data != null and _tree_data.allocation and not Engine.is_editor_hint()

func _do_create_connection(from_node: BayterekNodeButton, to_node: BayterekNodeButton) -> void:
	connections_service.create_connection(from_node, to_node)
	_refresh_all_allocatable_flags()

func _do_remove_connection(from_id: int, to_id: int) -> void:
	connections_service.remove_connection(from_id, to_id)
	_refresh_all_allocatable_flags()

# ============================================================
# HOLD TICK
# ============================================================

func _process(delta: float) -> void:
	if not allocation_service or not _tree_data:
		return
	if not allocation_service.is_holding():
		return

	var t: float = allocation_service.tick_hold(delta)
	_update_purchase_visuals(t)

# ============================================================
# PURCHASE VISUALS
# ============================================================

func _create_purchase_bar() -> void:
	if not _tree_data:
		return

	_purchase_bar_root = Control.new()
	_purchase_bar_root.name = "PurchaseBar"
	_purchase_bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_purchase_bar_root.visible = false
	_purchase_bar_root.z_index = 200
	add_child(_purchase_bar_root)

	var track := Panel.new()
	track.name = "Track"
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var track_style := StyleBoxFlat.new()
	track_style.bg_color = Color(0.08, 0.08, 0.10, 0.85)
	track_style.border_color = Color(0.35, 0.35, 0.40, 0.9)
	track_style.set_border_width_all(1)
	track_style.set_corner_radius_all(4)
	track.add_theme_stylebox_override("panel", track_style)
	_purchase_bar_root.add_child(track)

	_purchase_bar_fill = ColorRect.new()
	_purchase_bar_fill.name = "Fill"
	_purchase_bar_fill.color = Color(0.56, 0.96, 0.56, 0.95)
	_purchase_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_purchase_bar_root.add_child(_purchase_bar_fill)

	_layout_purchase_bar()


func _layout_purchase_bar() -> void:
	if not _purchase_bar_root:
		return

	var length: float = _tree_data.purchase_bar_length
	var margin: float = _tree_data.purchase_bar_margin
	var thickness: float = 8.0
	var view_size: Vector2 = size

	var track: Panel = _purchase_bar_root.get_node_or_null("Track")
	if not track:
		return

	var bar_rect: Rect2
	match _tree_data.purchase_bar_placement:
		0:
			bar_rect = Rect2(
				Vector2((view_size.x - length) * 0.5, margin),
				Vector2(length, thickness)
			)
		1:
			bar_rect = Rect2(
				Vector2((view_size.x - length) * 0.5, view_size.y - margin - thickness),
				Vector2(length, thickness)
			)
		2:
			bar_rect = Rect2(
				Vector2(margin, (view_size.y - length) * 0.5),
				Vector2(thickness, length)
			)
		3:
			bar_rect = Rect2(
				Vector2(view_size.x - margin - thickness, (view_size.y - length) * 0.5),
				Vector2(thickness, length)
			)
		_:
			bar_rect = Rect2(
				Vector2((view_size.x - length) * 0.5, view_size.y - margin - thickness),
				Vector2(length, thickness)
			)

	_purchase_bar_root.position = bar_rect.position
	_purchase_bar_root.size = bar_rect.size
	track.position = Vector2.ZERO
	track.size = bar_rect.size

	if _purchase_bar_fill:
		_purchase_bar_fill.position = Vector2(2, 2)


func _update_purchase_visuals(t: float) -> void:
	if not _tree_data:
		return

	if _tree_data.purchase_visual_mode == 1:
		_show_purchase_bar(t)
	else:
		_hide_purchase_bar()

	if _tree_data.purchase_visual_mode == 2:
		var node: BayterekNodeButton = allocation_service._hold_node
		if node and is_instance_valid(node):
			_purchase_hold_node = node
			node.set_purchase_progress(t)

	_update_purchase_sound(t)


func _show_purchase_bar(t: float) -> void:
	if not _purchase_bar_root or not _purchase_bar_fill:
		return
	_purchase_bar_root.visible = true

	var bar_size: Vector2 = _purchase_bar_root.size
	var horizontal: bool = _tree_data.purchase_bar_placement == 0 or _tree_data.purchase_bar_placement == 1

	if horizontal:
		_purchase_bar_fill.position = Vector2(2, 2)
		_purchase_bar_fill.size = Vector2(maxf(0.0, (bar_size.x - 4.0) * t), maxf(0.0, bar_size.y - 4.0))
	else:
		var inner_h: float = maxf(0.0, bar_size.y - 4.0)
		var inner_w: float = maxf(0.0, bar_size.x - 4.0)
		var fill_h: float = inner_h * t
		_purchase_bar_fill.position = Vector2(2, 2 + (inner_h - fill_h))
		_purchase_bar_fill.size = Vector2(inner_w, fill_h)


func _hide_purchase_bar() -> void:
	if _purchase_bar_root:
		_purchase_bar_root.visible = false

# ============================================================
# PURCHASE SOUND
# ============================================================

func _update_purchase_sound(t: float) -> void:
	var audio := _get_audio_manager()

	if allocation_service and allocation_service.is_holding():
		if not _purchase_loop_handle or not _purchase_loop_handle.is_playing():
			var stream: AudioStream = _tree_data.purchase_hold_sound if _tree_data else null
			if stream and audio:
				_purchase_loop_handle = audio.play_loop(
					stream,
					_tree_data.purchase_hold_sound_volume_db,
					_tree_data.purchase_sound_pitch_min
				)
		if _purchase_loop_handle:
			var pitch: float = lerpf(
				_tree_data.purchase_sound_pitch_min,
				_tree_data.purchase_sound_pitch_max,
				clampf(t, 0.0, 1.0)
			)
			_purchase_loop_handle.set_pitch(pitch)
	else:
		if _purchase_loop_handle:
			_purchase_loop_handle.stop(0.08)
			_purchase_loop_handle = null


func _on_purchase_hold_started(node: BayterekNodeButton) -> void:
	_purchase_hold_node = node

func _on_purchase_hold_cancelled(node: BayterekNodeButton) -> void:
	_cleanup_purchase_state(false)
	var audio := _get_audio_manager()
	if _tree_data and _tree_data.purchase_cancel_sound and audio:
		audio.play_sfx(_tree_data.purchase_cancel_sound, -6.0)

func _on_purchase_hold_completed(node: BayterekNodeButton) -> void:
	_cleanup_purchase_state(true)
	var audio := _get_audio_manager()
	if _tree_data and _tree_data.purchase_success_sound and audio:
		audio.play_sfx(_tree_data.purchase_success_sound, -6.0)


func _cleanup_purchase_state(completed: bool) -> void:
	_hide_purchase_bar()
	if _purchase_hold_node and is_instance_valid(_purchase_hold_node):
		_purchase_hold_node.clear_purchase_progress(completed)
	_purchase_hold_node = null
	if _purchase_loop_handle:
		_purchase_loop_handle.stop(0.08)
		_purchase_loop_handle = null


func _get_audio_manager() -> Node:
	var root := get_tree().root
	if not root:
		return null
	return root.get_node_or_null("BayterekAudioManager")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_purchase_bar()

# ============================================================
# MOVEMENT (EDITOR ONLY)
# ============================================================

func _on_node_drag_started(node: BayterekNodeButton, mouse_screen_pos: Vector2) -> void:
	if not node or not node.node_data:
		return
	if node.node_data.locked:
		return

	# RUNTIME: node drag YOK. Editor'de serbest.
	if not Engine.is_editor_hint():
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

	if group_frames_service:
		for n in _drag_start_positions.keys():
			if is_instance_valid(n):
				group_frames_service.on_node_moved(n)

	refresh_tooltip_position()

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
		if group_frames_service:
			for n in start_positions.keys():
				if is_instance_valid(n):
					group_frames_service.on_node_moved(n)
		changed.emit()
		return

	var undo_redo: UndoRedo = undo_redo_provider.undo_redo
	undo_redo.create_action("Move Nodes")

	undo_redo.add_do_method(_apply_positions.bind(end_positions))
	undo_redo.add_undo_method(_apply_positions.bind(start_positions))

	undo_redo.commit_action()

	if group_frames_service:
		for n in start_positions.keys():
			if is_instance_valid(n):
				group_frames_service.on_node_moved(n)

	changed.emit()

func _apply_positions(positions: Dictionary) -> void:
	for n in positions.keys():
		if is_instance_valid(n):
			nodes_service.update_position(n, positions[n])
			connections_service.update_lines_of(n)

	if group_frames_service:
		for n in positions.keys():
			if is_instance_valid(n):
				group_frames_service.on_node_moved(n)

	if not selected_nodes.is_empty():
		if selected_nodes.size() == 1:
			node_moved.emit(selected_nodes[0])

# ============================================================
# SELECTION BOX
# ============================================================

func _on_selection_box_selected(rect: Rect2) -> void:
	if _is_allocation_active():
		return
	if connections_service and connections_service.is_line_delete_mode_active():
		return

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

	group_frames_container = Control.new()
	group_frames_container.name = "GroupFramesContainer"
	group_frames_container.mouse_filter = Control.MOUSE_FILTER_PASS
	group_frames_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_child(group_frames_container)

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

	nodes_container.set_drag_forwarding(_drag_get_data, _drag_can_drop, _drag_drop_data)

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

	grid = BayterekProceduralGrid.new()
	grid.name = "Grid"
	grid.target = main_container
	grid.cell_size = Bayterek.GRID_CELL_SIZE
	grid.primary_line_step = Bayterek.GRID_PRIMARY_STEP
	grid.line_color = Bayterek.GRID_LINE_COLOR
	grid.line_width = Bayterek.GRID_LINE_WIDTH
	background_container.add_child(grid)
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if not Engine.is_editor_hint():
		grid.visible = false

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
	nodes_service.node_hovered.connect(_on_node_hovered)
	nodes_service.node_drag_started.connect(_on_node_drag_started)
	nodes_service.node_dragged.connect(_on_node_dragged)
	nodes_service.node_drag_ended.connect(_on_node_drag_ended)
	nodes_service.node_right_clicked.connect(_on_nodes_service_right_clicked)

	connections_service = BayterekConnectionsService.new(self)
	connections_service.load_tree(_tree_data)
	connections_service.line_clicked_for_delete.connect(_on_line_clicked_for_delete)

	prefabs_service = BayterekPrefabsService.new(self)
	prefabs_service.load_tree(_tree_data)

	group_frames_service = BayterekGroupFramesService.new(self)
	group_frames_service.set_container(group_frames_container)
	group_frames_service.load_tree(_tree_data)
	group_frames_service.refresh_all()

	allocation_service = BayterekAllocationService.new(self)

	allocation_service.node_preallocated.connect(nodes_service.on_node_preallocated)
	allocation_service.node_unpreallocated.connect(nodes_service.on_node_unpreallocated)
	allocation_service.node_allocated.connect(nodes_service.on_node_allocated)
	allocation_service.node_deallocated.connect(nodes_service.on_node_deallocated)
	allocation_service.node_refund_added.connect(nodes_service.on_node_refund_added)
	allocation_service.node_refund_removed.connect(nodes_service.on_node_refund_removed)

	allocation_service.node_preallocated.connect(connections_service.on_node_allocation_changed)
	allocation_service.node_unpreallocated.connect(connections_service.on_node_allocation_changed)
	allocation_service.node_allocated.connect(connections_service.on_node_allocation_changed)
	allocation_service.node_deallocated.connect(connections_service.on_node_allocation_changed)
	allocation_service.node_refund_added.connect(connections_service.on_node_allocation_changed)
	allocation_service.node_refund_removed.connect(connections_service.on_node_allocation_changed)

	allocation_service.node_allocated.connect(func(n): node_allocated.emit(n.node_data))
	allocation_service.node_deallocated.connect(func(n): node_deallocated.emit(n.node_data))

	allocation_service.hold_started.connect(_on_purchase_hold_started)
	allocation_service.hold_cancelled.connect(_on_purchase_hold_cancelled)
	allocation_service.hold_completed.connect(_on_purchase_hold_completed)

	prefabs_service.prefab_created.connect(func(p): prefab_created.emit(p))
	connections_service.line_created.connect(func(l, f, t): line_created.emit(l, f, t))

	allocation_service.load_tree(_tree_data)

	_refresh_all_allocatable_flags()

	allocation_service.node_allocated.connect(func(_n): _refresh_all_allocatable_flags())
	allocation_service.node_deallocated.connect(func(_n): _refresh_all_allocatable_flags())
	allocation_service.node_preallocated.connect(func(_n): _refresh_all_allocatable_flags())
	allocation_service.node_unpreallocated.connect(func(_n): _refresh_all_allocatable_flags())
	allocation_service.node_refund_added.connect(func(_n): _refresh_all_allocatable_flags())
	allocation_service.node_refund_removed.connect(func(_n): _refresh_all_allocatable_flags())

func _create_selection_box() -> void:
	if not Engine.is_editor_hint():
		return

	selection_box = BayterekSelectionBox.new()
	selection_box.set_view(self)
	selection_box.selected.connect(_on_selection_box_selected)
	add_child(selection_box)

# ============================================================
# ALLOCATABLE FLAGS + TOOLTIP SYNC
# ============================================================

func _refresh_all_allocatable_flags() -> void:
	if not nodes_service or not _tree_data:
		return

	var active_ids: Array = []
	if _tree_data.tree_state:
		active_ids = _tree_data.tree_state.allocated_nodes.duplicate()

	if allocation_service:
		for nid in allocation_service._preallocated_nodes:
			if not active_ids.has(nid):
				active_ids.append(nid)

	nodes_service.refresh_allocatable_flags(active_ids)
	refresh_tooltip_content()

# ============================================================
# FONT OVERRIDES
# ============================================================

func _apply_font_overrides() -> void:
	if not _tree_data or not _tooltip:
		return

	var family: String = _tree_data.font_family
	var scale: float = _tree_data.font_size_scale
	if scale <= 0.0:
		scale = 1.0

	_reset_tooltip_font_overrides()

	if family.is_empty() and is_equal_approx(scale, 1.0):
		return

	_apply_label_font_size(_tooltip._header_label, TOOLTIP_BASE_HEADER_FONT_SIZE, scale)
	_apply_label_font_size(_tooltip._body_label, TOOLTIP_BASE_FONT_SIZE, scale)
	_apply_label_font_size(_tooltip._footer_label, TOOLTIP_BASE_FOOTER_FONT_SIZE, scale)

	if not family.is_empty():
		var font := _load_theme_font(family)
		if font:
			_apply_label_font_family(_tooltip._header_label, font)
			_apply_label_font_family(_tooltip._body_label, font)
			_apply_label_font_family(_tooltip._footer_label, font)


func _apply_label_font_size(lbl: RichTextLabel, base_size: int, scale: float) -> void:
	if not is_instance_valid(lbl):
		return
	var final_size: int = max(6, int(round(float(base_size) * scale)))
	lbl.add_theme_font_size_override("normal_font_size", final_size)
	lbl.add_theme_font_size_override("bold_font_size", final_size)
	lbl.add_theme_font_size_override("italics_font_size", final_size)
	lbl.add_theme_font_size_override("mono_font_size", final_size)


func _apply_label_font_family(lbl: RichTextLabel, font: Font) -> void:
	if not is_instance_valid(lbl) or not font:
		return
	lbl.add_theme_font_override("normal_font", font)
	lbl.add_theme_font_override("bold_font", font)
	lbl.add_theme_font_override("italics_font", font)
	lbl.add_theme_font_override("mono_font", font)


func _reset_tooltip_font_overrides() -> void:
	if not _tooltip:
		return

	var labels: Array = [
		_tooltip._header_label,
		_tooltip._body_label,
		_tooltip._footer_label,
	]

	for lbl in labels:
		if not is_instance_valid(lbl):
			continue
		lbl.remove_theme_font_size_override("normal_font_size")
		lbl.remove_theme_font_size_override("bold_font_size")
		lbl.remove_theme_font_size_override("italics_font_size")
		lbl.remove_theme_font_size_override("mono_font_size")
		lbl.remove_theme_font_override("normal_font")
		lbl.remove_theme_font_override("bold_font")
		lbl.remove_theme_font_override("italics_font")
		lbl.remove_theme_font_override("mono_font")


func _load_theme_font(family: String) -> Font:
	var sys_fonts: Array = OS.get_system_fonts()
	for fname in sys_fonts:
		var lname: String = String(fname).to_lower()
		if family == "monospace" and ("mono" in lname or "code" in lname or "courier" in lname):
			var f := SystemFont.new()
			f.font_names = PackedStringArray([fname])
			return f
		if family == "serif" and ("serif" in lname or "times" in lname or "georgia" in lname):
			var f := SystemFont.new()
			f.font_names = PackedStringArray([fname])
			return f
		if family == "sans" and ("sans" in lname or "arial" in lname or "helvetica" in lname):
			var f := SystemFont.new()
			f.font_names = PackedStringArray([fname])
			return f
	var fallback := SystemFont.new()
	fallback.font_names = PackedStringArray([family])
	return fallback

# ============================================================
# COORDINATE HELPERS
# ============================================================

func screen_to_tree(screen_pos: Vector2) -> Vector2:
	var local: Vector2 = main_container.get_global_transform().affine_inverse() * (get_global_transform() * screen_pos)
	return local - (_tree_data.size * 0.5)

func screen_to_mc_local(screen_pos: Vector2) -> Vector2:
	return main_container.get_global_transform().affine_inverse() * (get_global_transform() * screen_pos)

func tree_to_view_local(tree_pos: Vector2) -> Vector2:
	var local_in_mc: Vector2 = tree_pos + (_tree_data.size * 0.5)
	var global_pos: Vector2 = main_container.get_global_transform() * local_in_mc
	return get_global_transform().affine_inverse() * global_pos

# ============================================================
# DRAG & DROP (prefab + design)
# ============================================================

func _drag_get_data(_at_position: Vector2) -> Variant:
	return null

func _drag_can_drop(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var t: String = data.get("type", "")
	return t == "prefab" or t == "design"

func _drag_drop_data(at_position: Vector2, data: Variant) -> void:
	if not data is Dictionary:
		return

	var t: String = data.get("type", "")

	if t == "design":
		var design = data.get("design", null)
		if design is BayterekNodeDesign:
			var mc_global: Vector2 = nodes_container.get_global_transform() * at_position
			var view_local: Vector2 = get_global_transform().affine_inverse() * mc_global
			var tree_pos: Vector2 = screen_to_tree(view_local)
			design_dropped.emit(design, tree_pos)
		return

	if t == "prefab":
		var prefab = data.get("prefab", null)
		if prefab is BayterekPrefab:
			var mc_global2: Vector2 = nodes_container.get_global_transform() * at_position
			var view_local2: Vector2 = get_global_transform().affine_inverse() * mc_global2
			var tree_pos2: Vector2 = screen_to_tree(view_local2)
			prefab_dropped.emit(prefab, tree_pos2)

# ============================================================
# GROUP FRAME INPUT
# ============================================================

func _handle_group_frame_input(event: InputEvent) -> bool:
	if not group_frames_service:
		return false

	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return false

		var mc_local: Vector2 = screen_to_mc_local(event.position)

		if event.pressed:
			var hit: BayterekGroupFrame = group_frames_service.hit_test(mc_local)
			if hit:
				_group_frame_dragging = hit
				_group_frame_drag_start_mc_local = mc_local

				group_frames_service.start_drag(hit, mc_local)
				group_frames_service.set_selected(hit.group_id)

				var additive: bool = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
				if not additive:
					clear_selection()
				for node in nodes_service.get_all_nodes():
					if is_instance_valid(node) and node.node_data and node.node_data.group_id == hit.group_id:
						select_node(node, true)

				return true

		else:
			if _group_frame_dragging:
				group_frames_service.end_drag(_group_frame_dragging)
				_group_frame_dragging = null
				changed.emit()
				return true

	elif event is InputEventMouseMotion:
		if _group_frame_dragging and is_instance_valid(_group_frame_dragging):
			var mc_local: Vector2 = screen_to_mc_local(event.position)
			group_frames_service.update_drag(_group_frame_dragging, mc_local)
			return true

	return false

# ============================================================
# SIGNAL FORWARDING
# ============================================================

func _on_nodes_service_node_created(node: BayterekNodeButton) -> void:
	node_created.emit(node)

func _on_nodes_service_right_clicked(node: BayterekNodeButton, screen_pos: Vector2) -> void:
	# Runtime'da sağ tık yok.
	if not Engine.is_editor_hint():
		return

	if not is_instance_valid(node):
		return

	# Pan sırasında menü açma.
	if camera and camera.is_right_drag_active():
		return

	node_right_clicked.emit(node, screen_pos)

func _on_line_clicked_for_delete(from_id: int, to_id: int) -> void:
	line_clicked_for_delete.emit(from_id, to_id)