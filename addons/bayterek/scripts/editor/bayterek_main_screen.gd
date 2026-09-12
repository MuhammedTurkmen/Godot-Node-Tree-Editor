@tool
class_name BayterekMainScreen
extends MarginContainer
## Ana ekran. TabContainer + Browser + Editor sekmeleri.

signal update_available(version: String)
signal dirty_changed(editor: BayterekEditor, dirty: bool)
signal tree_closed(editor: BayterekEditor)

var initialized: bool = false

var tab_container: TabContainer
var browser: BayterekBrowser
var save_confirmation: ConfirmationDialog

var _open_editors: Dictionary = {}   # path -> BayterekEditor

func _ready() -> void:
	add_theme_constant_override("margin_left", 0)
	add_theme_constant_override("margin_top", 0)
	add_theme_constant_override("margin_right", 0)
	add_theme_constant_override("margin_bottom", 0)

	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL

# --- Görünürlük değişince layout'u yenile ---
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		# Görünür olduğumuz an layout pass atlanmış olabilir.
		# Bir frame sonra tüm zinciri yeniden hesapla.
		call_deferred("_force_layout_refresh")

func _force_layout_refresh() -> void:
	if not is_inside_tree():
		return

	# Parent'ın bize verdiği boyutu al ve iç zincire aktar
	if tab_container:
		tab_container.queue_sort()

	if browser:
		browser.queue_sort()
		# Browser'ın kendi iç container'ını da zorla
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

	# init sonrası layout'u tazele
	_force_layout_refresh()
	call_deferred("_force_layout_refresh")

	print("Bayterek: MainScreen hazır.")

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

	tab_container.tab_button_pressed.connect(_on_tab_button_pressed)

	browser = BayterekBrowser.new()
	browser.name = "Browser"
	browser.main_screen = self
	browser.size_flags_horizontal = SIZE_EXPAND_FILL
	browser.size_flags_vertical = SIZE_EXPAND_FILL
	tab_container.add_child(browser)
	tab_container.set_tab_title(0, "Browser")

	save_confirmation = ConfirmationDialog.new()
	save_confirmation.name = "SaveConfirmation"
	save_confirmation.ok_button_text = "Save & Close"
	add_child(save_confirmation)

# --- Public API ---

func open_tree(path: String) -> void:
	if _open_editors.has(path):
		var existing: BayterekEditor = _open_editors[path]
		tab_container.current_tab = tab_container.get_tab_idx_from_control(existing)
		return

	var editor: BayterekEditor = BayterekEditor.new()
	if not editor:
		push_error("Bayterek: Editor oluşturulamadı.")
		return

	editor.name = path.get_file().get_basename()
	editor.size_flags_horizontal = SIZE_EXPAND_FILL
	editor.size_flags_vertical = SIZE_EXPAND_FILL
	tab_container.add_child(editor)
	var idx: int = tab_container.get_tab_idx_from_control(editor)
	tab_container.set_tab_title(idx, editor.name)
	editor.closed.connect(_on_editor_closed.bind(editor))
	editor.load_tree(path)

	_open_editors[path] = editor
	tab_container.current_tab = idx

# --- Signals ---

func _on_tab_button_pressed(tab_index: int) -> void:
	var child: Node = tab_container.get_child(tab_index)
	if child is BayterekEditor:
		(child as BayterekEditor).request_close()

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