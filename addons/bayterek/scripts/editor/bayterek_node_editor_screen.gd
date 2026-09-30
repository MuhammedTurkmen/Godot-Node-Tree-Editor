@tool
class_name BayterekNodeEditorScreen
extends MarginContainer
## Top-level "Node Editor" tab.

const DEFAULT_MAIN_SPLIT := 220
const DEFAULT_RIGHT_SPLIT := -280
const COLLAPSED_MAIN_SPLIT := 0

signal design_changed(design: BayterekNodeDesign)
signal design_category_changed
signal dirty_changed(dirty: bool)

const AUTOSAVE_DEBOUNCE_MS := 600
const MAX_UNDO_HISTORY := 100

const DEBUG_UNDO_SHORTCUTS := true
const DEBUG_AUTOSAVE := false

var _main_split: HSplitContainer
var _right_split: HSplitContainer
var _design_list: BayterekDesignListPanel
var _layer_editor: BayterekLayerEditor
var _preview_panel: BayterekLayerPreviewPanel
var _empty_label: Label
var _current_design: BayterekNodeDesign = null

var _last_expanded_offset: int = DEFAULT_MAIN_SPLIT

var _dirty: bool = false
var _autosave_countdown: float = 0.0

var _undo_redo: UndoRedo = null
var _undo_commit_count: int = 0
var _is_shutting_down: bool = false
var _loader: Node = null


func _ready() -> void:
	add_theme_constant_override("margin_left", 4)
	add_theme_constant_override("margin_top", 4)
	add_theme_constant_override("margin_right", 4)
	add_theme_constant_override("margin_bottom", 4)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL

	_undo_redo = UndoRedo.new()

	_build_ui()

	set_process(true)

	_loader = get_node_or_null("/root/BayterekLoader")
	if _loader and _loader.has_method("register_node_editor"):
		_loader.register_node_editor(self)


func _exit_tree() -> void:
	_is_shutting_down = true
	_autosave_countdown = 0.0
	set_process(false)

	if _loader and is_instance_valid(_loader) and _loader.has_method("unregister_node_editor"):
		_loader.unregister_node_editor(self)
	_loader = null

	_undo_redo = null


func _process(delta: float) -> void:
	if _is_shutting_down:
		return
	if _autosave_countdown <= 0.0:
		return

	_autosave_countdown -= delta
	if _autosave_countdown > 0.0:
		return

	_autosave_countdown = 0.0
	if DEBUG_AUTOSAVE:
		print("[Autosave] debounce elapsed → _flush_save()")
	_flush_save()


func _build_ui() -> void:
	_main_split = HSplitContainer.new()
	_main_split.size_flags_horizontal = SIZE_EXPAND_FILL
	_main_split.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(_main_split)

	_design_list = BayterekDesignListPanel.new()
	_design_list.custom_minimum_size = Vector2(220, 0)
	_design_list.size_flags_vertical = SIZE_EXPAND_FILL
	_design_list.design_selected.connect(_on_design_selected)
	_design_list.collapsed_changed.connect(_on_design_list_collapsed_changed)
	_design_list.design_category_changed.connect(_on_design_category_changed)
	_main_split.add_child(_design_list)

	_right_split = HSplitContainer.new()
	_right_split.size_flags_horizontal = SIZE_EXPAND_FILL
	_right_split.size_flags_vertical = SIZE_EXPAND_FILL
	_right_split.split_offset = DEFAULT_RIGHT_SPLIT
	_main_split.add_child(_right_split)

	var middle_stack := Control.new()
	middle_stack.size_flags_horizontal = SIZE_EXPAND_FILL
	middle_stack.size_flags_vertical = SIZE_EXPAND_FILL
	_right_split.add_child(middle_stack)

	_layer_editor = BayterekLayerEditor.new()
	_layer_editor.size_flags_horizontal = SIZE_EXPAND_FILL
	_layer_editor.size_flags_vertical = SIZE_EXPAND_FILL
	_layer_editor.visible = false
	_layer_editor.node_editor = self
	middle_stack.add_child(_layer_editor)
	_layer_editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer_editor.changed.connect(_on_layer_editor_changed)

	_empty_label = Label.new()
	_empty_label.text = "Select a design from the left, or create a new one."
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	middle_stack.add_child(_empty_label)
	_empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_preview_panel = BayterekLayerPreviewPanel.new()
	_preview_panel.custom_minimum_size = Vector2(220, 0)
	_preview_panel.size_flags_vertical = SIZE_EXPAND_FILL
	_right_split.add_child(_preview_panel)

	_main_split.split_offset = DEFAULT_MAIN_SPLIT


func refresh() -> void:
	if _design_list:
		_design_list.refresh()


# ============================================================
# PUBLIC — Undo/Redo API
# ============================================================

func get_undo_redo() -> UndoRedo:
	return _undo_redo


## Called from BayterekLoader's global _input hook. Returns true if we
## actually performed an undo (in which case the caller marks input as
## handled and prevents the editor's own undo from firing).
func try_handle_undo() -> bool:
	if _is_shutting_down:
		return false
	if _is_text_input_focused():
		return false
	if not _undo_redo:
		return false
	if not _undo_redo.has_undo():
		return false

	if DEBUG_UNDO_SHORTCUTS:
		print("[NodeEditor] try_handle_undo → OK")

	_undo_redo.undo()
	_post_undo_redo_refresh()
	mark_dirty()
	return true


## Called from BayterekLoader's global _input hook for redo.
func try_handle_redo() -> bool:
	if _is_shutting_down:
		return false
	if _is_text_input_focused():
		return false
	if not _undo_redo:
		return false
	if not _undo_redo.has_redo():
		return false

	if DEBUG_UNDO_SHORTCUTS:
		print("[NodeEditor] try_handle_redo → OK")

	_undo_redo.redo()
	_post_undo_redo_refresh()
	mark_dirty()
	return true


## Refreshes the whole Node Editor UI after an undo or redo.
##
## Undo/redo closures only mutate the underlying design data. They do
## NOT emit signals or refresh any widgets. After an undo/redo we need
## to tell every dependent UI to redraw:
##
##   1. design.layers_changed → layer editor rebuilds its list + detail
##      form (including the cached transform form's spinbox values).
##   2. preview panel refresh.
##   3. open tree editors rebuild any node using this design.
func _post_undo_redo_refresh() -> void:
	if _is_shutting_down:
		return
	if not _current_design:
		return

	_current_design.notify_layer_modified()

	if _preview_panel and _preview_panel.has_method("refresh"):
		_preview_panel.refresh()

	_refresh_tree_editor_nodes_for_design(_current_design)


## Walks every open BayterekEditor and tells nodes that reference the
## given design to rebuild their visuals.
func _refresh_tree_editor_nodes_for_design(design: BayterekNodeDesign) -> void:
	if not design:
		return

	var main_screen := _find_main_screen()
	if not main_screen:
		return

	var open_paths: Array = []
	if main_screen.has_method("get_open_tree_paths"):
		open_paths = main_screen.get_open_tree_paths()
	else:
		return

	for path in open_paths:
		var editor = null
		if main_screen.has_method("get_open_editor"):
			editor = main_screen.get_open_editor(path)
		else:
			# Fallback: access the private dict directly.
			var mp: Variant = main_screen.get("_open_editors")
			if mp is Dictionary:
				editor = mp.get(path, null)

		if not is_instance_valid(editor):
			continue
		if not editor.tree_view or not editor.tree_view.nodes_service:
			continue

		for node in editor.tree_view.nodes_service.get_all_nodes():
			if not is_instance_valid(node):
				continue
			if not node.node_data:
				continue
			if node.node_data.design_id != design.id:
				continue
			if node.has_method("rebuild_from_design"):
				node.rebuild_from_design()
			elif node.has_method("refresh_visuals"):
				node.refresh_visuals()


func _find_main_screen() -> Node:
	var n: Node = get_parent()
	while n:
		if n is BayterekMainScreen:
			return n
		n = n.get_parent()
	return null


func commit_undoable(action_name: String, do_callable: Callable, undo_callable: Callable) -> bool:
	if _is_shutting_down:
		return false
	if not _current_design:
		return false
	if not _undo_redo:
		return false

	_undo_redo.create_action(action_name)
	_undo_redo.add_do_method(do_callable)
	_undo_redo.add_undo_method(undo_callable)
	_undo_redo.commit_action()

	if DEBUG_UNDO_SHORTCUTS:
		print("[NodeEditor] commit_undoable: '%s'" % action_name)

	mark_dirty()

	_undo_commit_count += 1
	_trim_undo_history()

	return true


func perform_undo() -> bool:
	return try_handle_undo()


func perform_redo() -> bool:
	return try_handle_redo()


func _trim_undo_history() -> void:
	if not _undo_redo:
		return
	if _undo_commit_count < MAX_UNDO_HISTORY:
		return
	_undo_redo.clear_history()
	_undo_commit_count = 0


# ============================================================
# TEXT INPUT FOCUS GUARD
# ============================================================

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
# DIRTY / AUTOSAVE
# ============================================================

func _on_layer_editor_changed() -> void:
	if _is_shutting_down:
		return
	if not _current_design:
		return
	mark_dirty()


func mark_dirty() -> void:
	if _is_shutting_down:
		return
	if not _dirty:
		_dirty = true
		dirty_changed.emit(true)

	_autosave_countdown = AUTOSAVE_DEBOUNCE_MS / 1000.0
	if DEBUG_AUTOSAVE:
		print("[Autosave] countdown reset (%.2fs)" % _autosave_countdown)


func is_dirty() -> bool:
	return _dirty


func get_current_design() -> BayterekNodeDesign:
	return _current_design


func save_now() -> bool:
	if _is_shutting_down:
		return true
	_autosave_countdown = 0.0
	return _flush_save()


func _flush_save() -> bool:
	if _is_shutting_down:
		return true
	if not _dirty:
		return true

	if not _current_design:
		_dirty = false
		dirty_changed.emit(false)
		return true

	if DEBUG_AUTOSAVE:
		print("[Autosave] saving '%s'..." % _current_design.name)

	var err: Error = BayterekDesignService.save_design(_current_design)
	if err != OK:
		push_warning("[Bayterek] Autosave failed for design '%s' (err=%d)" % [_current_design.name, err])
		_autosave_countdown = AUTOSAVE_DEBOUNCE_MS / 1000.0
		return false

	_dirty = false
	dirty_changed.emit(false)
	if DEBUG_AUTOSAVE:
		print("[Autosave] saved OK")
	return true


# ============================================================
# CALLBACKS
# ============================================================

func _on_design_selected(design: BayterekNodeDesign) -> void:
	if _is_shutting_down:
		return

	if _dirty and _current_design and _current_design != design:
		var saved_ok: bool = save_now()
		if not saved_ok:
			push_warning("[Bayterek] Could not save '%s' before switching designs." % _current_design.name)

	if _undo_redo:
		_undo_redo.clear_history()
		_undo_commit_count = 0

	_current_design = design
	design_changed.emit(design)

	if design:
		_layer_editor.visible = true
		_empty_label.visible = false
		_layer_editor.set_design(design)
		_preview_panel.set_design(design)
	else:
		_layer_editor.visible = false
		_empty_label.visible = true
		_layer_editor.set_design(null)
		_preview_panel.set_design(null)

	_dirty = false
	dirty_changed.emit(false)


func _on_design_list_collapsed_changed(collapsed: bool) -> void:
	if _is_shutting_down:
		return
	if not _main_split:
		return

	if collapsed:
		if _main_split.split_offset > 0:
			_last_expanded_offset = _main_split.split_offset
		_main_split.split_offset = COLLAPSED_MAIN_SPLIT
	else:
		_main_split.split_offset = max(_last_expanded_offset, DEFAULT_MAIN_SPLIT)

	_main_split.queue_sort()


func _on_design_category_changed() -> void:
	if _is_shutting_down:
		return
	design_category_changed.emit()