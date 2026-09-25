@tool
class_name BayterekShortcuts
extends RefCounted
## Central keyboard shortcut handler for the Bayterek editor.

var editor: BayterekEditor
var _grid_visible: bool = true

func _init(p_editor: BayterekEditor) -> void:
	editor = p_editor

func handle_input(event: InputEvent) -> bool:
	if not editor:
		return false
	if not editor.is_visible_in_tree():
		return false
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false

	var key: int = event.keycode
	var ctrl: bool = event.ctrl_pressed or event.meta_pressed
	var shift: bool = event.shift_pressed

	# --- Ctrl combinations ---
	if ctrl:
		if key == KEY_S:
			editor.save_tree()
			return true
		if key == KEY_P or key == KEY_F:
			if editor and editor.has_method("open_node_search"):
				editor.open_node_search()
				return true
		if key == KEY_A and shift:
			_deselect_all()
			return true
		if key == KEY_A:
			_select_all()
			return true
		if key == KEY_Z and not shift:
			editor.do_undo()
			return true
		if key == KEY_Y or (key == KEY_Z and shift):
			editor.do_redo()
			return true
		if key == KEY_D:
			editor.duplicate_selected_nodes()
			return true
		if key == KEY_C:
			editor._copy_selected_nodes()
			return true
		if key == KEY_V:
			editor._paste_nodes()
			return true
		if key == KEY_G and shift:
			editor.ungroup_selected()
			return true
		if key == KEY_G:
			editor.open_group_create_dialog()
			return true
		if key == KEY_L and shift:
			editor.unlock_all_nodes()
			return true
		if key == KEY_L:
			editor.toggle_lock_selected()
			return true
		if key == KEY_R:
			_reset_camera()
			return true

	# --- Plain keys ---
	if not ctrl:
		if key == KEY_G:
			_toggle_grid()
			return true
		if key == KEY_F:
			_focus_selected()
			return true
		if key == KEY_C and not shift:
			editor._toggle_chain_connection_mode()
			return true
		if key == KEY_F2:
			editor._open_rename_dialog()
			return true
		if key == KEY_DELETE:
			_handle_delete()
			return true
		if key == KEY_HOME:
			_center_camera()
			return true
		if key == KEY_TAB:
			if shift:
				_select_previous()
			else:
				_select_next()
			return true

	return false

# ============================================================
# ACTIONS
# ============================================================

func _toggle_grid() -> void:
	if not editor.tree_view or not editor.tree_view.grid:
		return
	_grid_visible = not editor.tree_view.grid.visible
	editor.tree_view.grid.visible = _grid_visible
	var status: String = "ON" if _grid_visible else "OFF"
	BayterekToast.info(editor.tree_view, "Grid: [b]%s[/b]" % status)

func _focus_selected() -> void:
	if not editor.tree_view:
		return
	var selected: Array = editor.tree_view.selected_nodes
	if selected.is_empty():
		BayterekToast.info(editor.tree_view, "No node selected")
		return
	var sum: Vector2 = Vector2.ZERO
	var count: int = 0
	for n in selected:
		if is_instance_valid(n) and n.node_data:
			sum += n.node_data.position
			count += 1
	if count == 0:
		return
	var centroid: Vector2 = sum / float(count)
	if editor.tree_view.camera:
		editor.tree_view.camera.focus_on(centroid, 1.5)
		BayterekToast.success(editor.tree_view, "Focused on %d node%s" % [count, "s" if count > 1 else ""])

func _select_all() -> void:
	if not editor.tree_view or not editor.tree_view.nodes_service:
		return
	editor.tree_view.clear_selection()
	var count: int = 0
	for node in editor.tree_view.nodes_service.get_all_nodes():
		if not is_instance_valid(node):
			continue
		if node.node_data and node.node_data.locked:
			continue
		editor.tree_view.select_node(node, true)
		count += 1
	if count > 0:
		BayterekToast.info(editor.tree_view, "Selected %d node%s" % [count, "s" if count > 1 else ""])

func _deselect_all() -> void:
	if not editor.tree_view:
		return
	editor.tree_view.clear_selection()
	BayterekToast.info(editor.tree_view, "Selection cleared")

func _reset_camera() -> void:
	if not editor.tree_view or not editor.tree_view.camera:
		return
	editor.tree_view.camera.set_zoom(1.0)
	editor.tree_view.camera.focus_on(Vector2.ZERO, 1.0)
	BayterekToast.info(editor.tree_view, "View reset")

func _center_camera() -> void:
	if not editor.tree_view:
		return
	editor.tree_view.center_camera_on_content()
	BayterekToast.info(editor.tree_view, "Camera centered")

func _handle_delete() -> void:
	if not editor.tree_view:
		return
	if editor.tree_view.selected_nodes.is_empty():
		return
	editor._delete_selected()

# ============================================================
# TAB NAVIGATION
# ============================================================

func _select_next() -> void:
	_cycle_selection(1)

func _select_previous() -> void:
	_cycle_selection(-1)

func _cycle_selection(direction: int) -> void:
	if not editor.tree_view or not editor.tree_view.nodes_service:
		return
	var all_nodes: Array = editor.tree_view.nodes_service.get_all_nodes()
	if all_nodes.is_empty():
		return
	all_nodes.sort_custom(func(a, b): return a.id < b.id)
	var candidates: Array = []
	for n in all_nodes:
		if not is_instance_valid(n):
			continue
		if n.node_data and n.node_data.locked:
			continue
		candidates.append(n)
	if candidates.is_empty():
		return
	var current_idx: int = -1
	if not editor.tree_view.selected_nodes.is_empty():
		var current = editor.tree_view.selected_nodes[0]
		for i in candidates.size():
			if candidates[i] == current:
				current_idx = i
				break
	var next_idx: int = 0
	if current_idx >= 0:
		next_idx = (current_idx + direction + candidates.size()) % candidates.size()
	var next_node = candidates[next_idx]
	editor.tree_view.clear_selection()
	editor.tree_view.select_node(next_node)
	editor.tree_view.scroll_to_node(next_node)
	if editor.tree_view.camera and next_node.node_data:
		editor.tree_view.camera.focus_on(next_node.node_data.position, editor.tree_view.camera.get_zoom())