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


## Called when this screen leaves the tree. This can happen during plugin
## hot-reload or when the editor is torn down. We clear the initialized
## flag and any cached editor references so a future init() can rebuild
## everything cleanly, and so stale child screens (which may still have
## signals wired) don't try to touch a dead screen.
func _exit_tree() -> void:
	initialized = false
	_open_editors.clear()
	tab_container = null
	browser = null
	node_editor = null
	save_confirmation = null


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


## Closes the editor tab for the given tree path, if it's open.
## Returns true if a tab was actually closed.
##
## This is used by the browser's delete flow: if a tree is open and the
## user confirms "Close & Delete", the browser calls this method to close
## the tab BEFORE deleting the underlying files. This avoids Godot's
## "Failed loading resource: ...json" errors caused by deleting files
## that are still referenced by a live resource in the editor cache.
func close_tree(path: String) -> bool:
	if not _open_editors.has(path):
		return false
	var editor: BayterekEditor = _open_editors[path]
	if not editor or not is_instance_valid(editor):
		return false

	# Unregister from the tracking dict BEFORE we call request_close(),
	# so the editor's `closed` signal callback doesn't double-remove.
	_open_editors.erase(path)

	# request_close() emits `closed` → _on_editor_closed() cleans up
	# the tab UI. Since we already erased the dict entry, the handler
	# just skips the dict cleanup step and does the UI teardown.
	editor.request_close()
	return true


## Returns true if the given tree path is currently open in a tab.
func has_open_tree(path: String) -> bool:
	return _open_editors.has(path)

## Returns all open tree paths.
func get_open_tree_paths() -> Array:
	return _open_editors.keys()


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


# ============================================================
# EDITOR DIRTY → TAB TITLE
# ============================================================

## Called when a tree editor's `dirty_changed` signal fires.
##
## IMPORTANT: The signal is declared as
##     signal dirty_changed(editor: BayterekEditor, dirty: bool)
## but we intentionally use UNTYPED parameters here.
##
## Godot 4.7 has a quirk: when a signal declares typed parameters and
## the handler function declares typed parameters of the SAME type,
## Godot sometimes fails to call the handler with "Error calling from
## signal". Using untyped params in the handler avoids that ambiguity
## while still giving us the values we need.
func _on_editor_dirty_changed(p_editor, p_dirty) -> void:
	if not tab_container:
		return
	if not is_instance_valid(p_editor):
		return

	var idx: int = tab_container.get_tab_idx_from_control(p_editor)
	if idx < 0:
		return

	var title: String = "Untitled"
	if p_editor.tree:
		title = p_editor.tree.name
	elif not p_editor.name.is_empty():
		title = p_editor.name

	if p_dirty:
		title = title + " (*)"
	tab_container.set_tab_title(idx, title)

	dirty_changed.emit(p_editor, p_dirty)