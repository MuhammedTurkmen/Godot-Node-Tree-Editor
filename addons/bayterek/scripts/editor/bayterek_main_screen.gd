@tool
class_name BayterekMainScreen
extends MarginContainer
## Main screen.

signal update_available(version: String)
signal dirty_changed(editor: BayterekEditor, dirty: bool)
signal tree_closed(editor: BayterekEditor)

var initialized: bool = false

var tab_container: TabContainer
var browser: BayterekBrowser
var node_editor: BayterekNodeEditorScreen
var save_confirmation: ConfirmationDialog

var _open_editors: Dictionary = {}

func _ready() -> void:
	add_theme_constant_override("margin_left", 0)
	add_theme_constant_override("margin_top", 0)
	add_theme_constant_override("margin_right", 0)
	add_theme_constant_override("margin_bottom", 0)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		call_deferred("_force_layout_refresh")

func _force_layout_refresh() -> void:
	if not is_inside_tree():
		return
	if tab_container:
		tab_container.queue_sort()
	if browser:
		browser.queue_sort()
		var vbox := browser.get_node_or_null("Root")
		if vbox:
			vbox.queue_sort()

func init() -> void:
	if initialized:
		return
	initialized = true

	_build_ui()
	if browser:
		browser.init()
	if node_editor:
		node_editor.refresh()

	_force_layout_refresh()
	call_deferred("_force_layout_refresh")
	print("Bayterek: MainScreen ready.")

func _build_ui() -> void:
	if tab_container:
		return

	tab_container = TabContainer.new()
	tab_container.name = "TabContainer"
	tab_container.size_flags_horizontal = SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(tab_container)

	var tab_bar: TabBar = tab_container.get_tab_bar()
	if tab_bar:
		tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ACTIVE_ONLY
		tab_bar.tab_close_pressed.connect(_on_tab_close_pressed)

	# --- Tab 0: Browser ---
	browser = BayterekBrowser.new()
	browser.name = "Browser"
	browser.main_screen = self
	browser.size_flags_horizontal = SIZE_EXPAND_FILL
	browser.size_flags_vertical = SIZE_EXPAND_FILL
	tab_container.add_child(browser)
	tab_container.set_tab_title(0, "Browser")

	# --- Tab 1: Node Editor ---
	node_editor = BayterekNodeEditorScreen.new()
	node_editor.name = "NodeEditor"
	node_editor.size_flags_horizontal = SIZE_EXPAND_FILL
	node_editor.size_flags_vertical = SIZE_EXPAND_FILL
	tab_container.add_child(node_editor)
	tab_container.set_tab_title(1, "Node Editor")
	node_editor.design_category_changed.connect(_on_design_category_changed)
	node_editor.dirty_changed.connect(_on_node_editor_dirty_changed)

	save_confirmation = ConfirmationDialog.new()
	save_confirmation.name = "SaveConfirmation"
	save_confirmation.ok_button_text = "Save & Close"
	save_confirmation.add_button("Don't Save", true, "no_save")
	save_confirmation.confirmed.connect(_on_save_confirmed)
	save_confirmation.custom_action.connect(_on_save_custom_action)
	add_child(save_confirmation)

# ============================================================
# DESIGN CATEGORY CHANGE → REFRESH ALL OPEN EDITORS' PREFAB BARS
# ============================================================

func _on_design_category_changed() -> void:
	for path in _open_editors.keys():
		var editor = _open_editors[path]
		if not is_instance_valid(editor):
			continue
		if not editor.prefabs_bar:
			continue
		editor.prefabs_bar.refresh_categories()

# ============================================================
# NODE EDITOR DIRTY → TAB TITLE
# ============================================================

func _on_node_editor_dirty_changed(dirty: bool) -> void:
	if not tab_container or not node_editor:
		return

	var idx: int = tab_container.get_tab_idx_from_control(node_editor)
	if idx < 0:
		return

	var title: String = "Node Editor"
	if dirty:
		title = title + " (*)"
	tab_container.set_tab_title(idx, title)

# ============================================================
# TAB SWITCHING
# ============================================================

func switch_to_node_editor() -> void:
	if not tab_container or not node_editor:
		return
	var idx: int = tab_container.get_tab_idx_from_control(node_editor)
	if idx >= 0:
		tab_container.current_tab = idx

# ============================================================
# TREE EDITOR MANAGEMENT
# ============================================================

func open_tree(path: String) -> void:
	if _open_editors.has(path):
		var existing: BayterekEditor = _open_editors[path]
		tab_container.current_tab = tab_container.get_tab_idx_from_control(existing)
		return

	var editor_script = load("res://addons/bayterek/scripts/editor/bayterek_editor.gd")
	if not editor_script:
		push_error("Bayterek: bayterek_editor.gd failed to load.")
		return

	if not editor_script is GDScript:
		push_error("Bayterek: bayterek_editor.gd is not a GDScript.")
		return

	if not editor_script.can_instantiate():
		push_error("Bayterek: bayterek_editor.gd failed to parse.")
		return

	var editor: Control = editor_script.new()
	if not editor:
		push_error("Bayterek: could not instantiate BayterekEditor.")
		return

	if not editor is BayterekEditor:
		push_error("Bayterek: instantiated object is not BayterekEditor.")
		return

	editor.name = path.get_file().get_basename()
	editor.size_flags_horizontal = SIZE_EXPAND_FILL
	editor.size_flags_vertical = SIZE_EXPAND_FILL
	tab_container.add_child(editor)
	var idx: int = tab_container.get_tab_idx_from_control(editor)
	tab_container.set_tab_title(idx, editor.name)
	editor.closed.connect(_on_editor_closed.bind(editor))
	editor.dirty_changed.connect(_on_editor_dirty_changed)
	editor.load_tree(path)

	_open_editors[path] = editor
	tab_container.current_tab = idx

func _on_tab_close_pressed(tab_index: int) -> void:
	if tab_index <= 1:
		# Browser (0) and Node Editor (1) tabs are not closeable.
		# For Node Editor, check dirty and prompt if needed.
		var child: Node = tab_container.get_child(tab_index)
		if child is BayterekNodeEditorScreen:
			_handle_node_editor_close(child)
		return

	var child: Node = tab_container.get_child(tab_index)
	if child is BayterekEditor:
		var editor: BayterekEditor = child
		if editor.dirty:
			save_confirmation.dialog_text = "Tree \"%s\" has unsaved changes.\nLast saved: %s\n\nSave before closing?" % [editor.tree.name, editor.get_last_modified_time()]
			save_confirmation.set_meta("editor", editor)
			save_confirmation.popup_centered()
		else:
			editor.request_close()

func _handle_node_editor_close(editor: BayterekNodeEditorScreen) -> void:
	if not editor:
		return
	if not editor.is_dirty():
		return
	# Autosave already handles persistence, but show a "saved" confirmation.
	editor.save_now()
	print("[Bayterek] Node Editor: autosaved current design on close.")

func _on_save_confirmed() -> void:
	var editor: BayterekEditor = save_confirmation.get_meta("editor")
	if editor:
		editor.save_tree()
		editor.request_close()

func _on_save_custom_action(action: String) -> void:
	if action == "no_save":
		var editor: BayterekEditor = save_confirmation.get_meta("editor")
		if editor:
			editor.request_close()
		save_confirmation.hide()

func _on_editor_closed(editor: BayterekEditor) -> void:
	var path: String = ""
	for k in _open_editors.keys():
		if _open_editors[k] == editor:
			path = k
			break
	if path != "":
		_open_editors.erase(path)

	tab_container.remove_child(editor)
	editor.queue_free()
	tree_closed.emit(editor)

func _on_editor_dirty_changed(editor: BayterekEditor, dirty: bool) -> void:
	var idx: int = tab_container.get_tab_idx_from_control(editor)
	if idx < 0:
		return

	var title: String = editor.tree.name if editor.tree else editor.name
	if dirty:
		title = title + " (*)"
	tab_container.set_tab_title(idx, title)

	dirty_changed.emit(editor, dirty)

# ============================================================
# RENAME SUPPORT
# ============================================================

func has_open_tree(path: String) -> bool:
	return _open_editors.has(path)

func get_open_tree_paths() -> Array:
	return _open_editors.keys()