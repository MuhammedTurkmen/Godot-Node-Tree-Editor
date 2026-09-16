@tool
class_name BayterekBrowser
extends MarginContainer
## Grup / tree listeleme, oluşturma, silme, yeniden adlandırma, sürükle-bırak.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

enum GroupMenuId { CREATE = 0, DELETE = 1, DUPLICATE = 2 }
enum TreeMenuId  { CREATE = 0, DELETE = 1, DUPLICATE = 2 }

enum ContextMenuId {
	CREATE_GROUP = 0,
	CREATE_TREE = 10,
	RENAME = 20,
	DUPLICATE = 21,
	DELETE = 30,
	OPEN_TREE = 40,
}

@export var main_screen: BayterekMainScreen

var _tree: Tree
var _search: LineEdit
var _group_menu: MenuButton
var _tree_menu: MenuButton
var _load_time_label: Label
var _groups_count_label: Label
var _trees_count_label: Label
var _version_label: Label
var _docs_button: Button
var _delete_dialog: ConfirmationDialog
var _delete_checkbox: CheckBox
var _tree_context_menu: PopupMenu

var _pending_delete: Dictionary = {}

## Suppresses _on_item_selected when we programmatically change selection.
var _suppress_selection: bool = false

## Set to the item being currently renamed (so we can restore on failure).
var _renaming_item: TreeItem = null

# ============================================================
# KURULUM
# ============================================================

func _ready() -> void:
	add_theme_constant_override("margin_left", 4)
	add_theme_constant_override("margin_top", 4)
	add_theme_constant_override("margin_right", 4)
	add_theme_constant_override("margin_bottom", 4)

	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL

func init() -> void:
	_build_ui()
	_connect_signals()
	_refresh()
	print("Bayterek: Browser hazır.")

func _build_ui() -> void:
	if _tree:
		return

	var vbox := VBoxContainer.new()
	vbox.name = "Root"
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(vbox)

	# --- Üst satır: Group / Tree menüleri + arama ---
	var top := HBoxContainer.new()
	vbox.add_child(top)

	_group_menu = MenuButton.new()
	_group_menu.text = "Group"
	_group_menu.get_popup().add_item("Create", GroupMenuId.CREATE)
	_group_menu.get_popup().add_item("Delete", GroupMenuId.DELETE)
	_group_menu.get_popup().add_item("Duplicate", GroupMenuId.DUPLICATE)
	_group_menu.get_popup().set_item_disabled(GroupMenuId.DELETE, true)
	_group_menu.get_popup().set_item_disabled(GroupMenuId.DUPLICATE, true)
	top.add_child(_group_menu)

	_tree_menu = MenuButton.new()
	_tree_menu.text = "Tree"
	_tree_menu.get_popup().add_item("Create", TreeMenuId.CREATE)
	_tree_menu.get_popup().add_item("Delete", TreeMenuId.DELETE)
	_tree_menu.get_popup().add_item("Duplicate", TreeMenuId.DUPLICATE)
	_tree_menu.get_popup().set_item_disabled(TreeMenuId.CREATE, true)
	_tree_menu.get_popup().set_item_disabled(TreeMenuId.DELETE, true)
	_tree_menu.get_popup().set_item_disabled(TreeMenuId.DUPLICATE, true)
	top.add_child(_tree_menu)

	_search = LineEdit.new()
	_search.placeholder_text = "Search"
	_search.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(_search)

	# --- Orta: Tree ---
	_tree = Tree.new()
	_tree.hide_root = true
	_tree.size_flags_vertical = SIZE_EXPAND_FILL
	_tree.size_flags_horizontal = SIZE_EXPAND_FILL
	_tree.select_mode = Tree.SELECT_ROW
	vbox.add_child(_tree)
	_tree.create_item()
	vbox.move_child(_tree, 1)

	_tree.item_selected.connect(_on_item_selected)
	_tree.item_activated.connect(_on_item_activated)
	_tree.item_edited.connect(_on_item_edited)
	_tree.gui_input.connect(_on_tree_gui_input)

	# --- Alt satır ---
	var bottom := HBoxContainer.new()
	vbox.add_child(bottom)

	_load_time_label = Label.new()
	_load_time_label.text = "Load time: 0.00s"
	bottom.add_child(_load_time_label)

	bottom.add_child(VSeparator.new())

	_groups_count_label = Label.new()
	_groups_count_label.text = "Total groups: 0"
	bottom.add_child(_groups_count_label)

	bottom.add_child(VSeparator.new())

	_trees_count_label = Label.new()
	_trees_count_label.text = "Total trees: 0"
	bottom.add_child(_trees_count_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	bottom.add_child(spacer)

	_docs_button = Button.new()
	_docs_button.text = "Online Docs"
	_docs_button.flat = true
	bottom.add_child(_docs_button)

	bottom.add_child(VSeparator.new())

	_version_label = Label.new()
	_version_label.text = "v%s" % Bayterek.VERSION
	bottom.add_child(_version_label)

	# --- Context Menu (right-click) ---
	_tree_context_menu = PopupMenu.new()
	_tree_context_menu.name = "TreeContextMenu"
	add_child(_tree_context_menu)

	queue_sort()

func _connect_signals() -> void:
	_group_menu.get_popup().id_pressed.connect(_on_group_menu_pressed)
	_tree_menu.get_popup().id_pressed.connect(_on_tree_menu_pressed)
	_search.text_changed.connect(_on_search_changed)
	_docs_button.pressed.connect(_on_docs_pressed)
	_tree_context_menu.id_pressed.connect(_on_tree_context_menu_pressed)

	# Enable drag-drop for tree items
	_tree.set_drag_forwarding(_tree_get_drag_data, _tree_can_drop_data, _tree_drop_data)

# ============================================================
# REFRESH
# ============================================================

## Full refresh: reloads registry from disk, then rebuilds the UI.
func _refresh() -> void:
	var registry_path: String = Bayterek.get_registry_path()
	if FileAccess.file_exists(registry_path):
		Bayterek.reload_editor_registry()
	else:
		Bayterek.clear_editor_registry()

	_refresh_ui_only()

## UI-only refresh: schedules a rebuild of the Tree content.
## Uses call_deferred to avoid "!is_inside_tree()" errors caused by
## manipulating the Tree control during a viewport pass.
func _refresh_ui_only() -> void:
	_do_refresh_ui.call_deferred()

func _do_refresh_ui() -> void:
	if not is_inside_tree():
		return
	if not _tree or not is_instance_valid(_tree) or not _tree.is_inside_tree():
		return

	var start_time := Time.get_ticks_usec()
	var registry: BayterekRegistry = Bayterek.get_editor_registry()

	_rebuild_tree_contents(registry)

	if not registry:
		return

	_groups_count_label.text = "Total groups: %d" % registry.groups.size()
	var total_trees: int = 0
	for g: BayterekGroup in registry.groups:
		total_trees += g.trees.size()
	_trees_count_label.text = "Total trees: %d" % total_trees

	var elapsed: float = (Time.get_ticks_usec() - start_time) / 1_000_000.0
	_load_time_label.text = "Load time: %.2fs" % elapsed

## Rebuilds Tree content in place without destroying the Tree control.
func _rebuild_tree_contents(registry: BayterekRegistry) -> void:
	if not is_instance_valid(_tree):
		return

	_tree.clear()
	_tree.create_item()

	if not registry:
		_tree.hide()
		_tree.show()
		return

	var root: TreeItem = _tree.get_root()
	if not root:
		return

	for group: BayterekGroup in registry.groups:
		var g_item := root.create_child()
		g_item.set_text(0, group.name)
		g_item.set_icon(0, EditorInterface.get_editor_theme().get_icon(Bayterek.GROUP_ICON, Bayterek.ICON_THEME))
		g_item.set_metadata(0, {"type": "group", "path": group.resource_path})

		for tree: BayterekTree in group.trees:
			var t_item := g_item.create_child()
			t_item.set_text(0, tree.name)
			t_item.set_icon(0, EditorInterface.get_editor_theme().get_icon(Bayterek.TREE_ICON, Bayterek.ICON_THEME))
			t_item.set_metadata(0, {"type": "tree", "path": tree.resource_path, "group_path": group.resource_path})

	# Godot's Tree doesn't always reflect clear() + create_child() until
	# the next frame. Toggling visibility forces a full re-render.
	_tree.hide()
	_tree.show()

# ============================================================
# SEÇİM
# ============================================================

func _on_item_selected() -> void:
	if _suppress_selection:
		return

	var selected := _tree.get_selected()
	if not selected:
		return

	var is_group: bool = selected.get_parent() == _tree.get_root()
	var is_tree: bool = not is_group

	_group_menu.get_popup().set_item_disabled(GroupMenuId.DELETE, not is_group)
	_group_menu.get_popup().set_item_disabled(GroupMenuId.DUPLICATE, not is_group)
	_tree_menu.get_popup().set_item_disabled(TreeMenuId.CREATE, false)
	_tree_menu.get_popup().set_item_disabled(TreeMenuId.DELETE, not is_tree)
	_tree_menu.get_popup().set_item_disabled(TreeMenuId.DUPLICATE, not is_tree)

func _on_item_activated() -> void:
	var selected := _tree.get_selected()
	if not selected:
		return

	if selected.get_parent() == _tree.get_root():
		selected.collapsed = not selected.collapsed
		return

	var meta: Dictionary = selected.get_metadata(0)
	if meta.get("type", "") != "tree":
		return

	if main_screen:
		main_screen.open_tree(meta["path"])

# ============================================================
# CONTEXT MENU (right-click)
# ============================================================

func _on_tree_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_show_tree_context_menu(event.position)

func _show_tree_context_menu(mouse_pos: Vector2) -> void:
	var item: TreeItem = _tree.get_item_at_position(mouse_pos)

	if item:
		item.select(0)

	_tree_context_menu.clear()

	if not item:
		_tree_context_menu.add_item("Create Group", ContextMenuId.CREATE_GROUP)
	else:
		var is_group: bool = item.get_parent() == _tree.get_root()

		if is_group:
			_tree_context_menu.add_item("Create Tree", ContextMenuId.CREATE_TREE)
			_tree_context_menu.add_separator()
			_tree_context_menu.add_item("Rename", ContextMenuId.RENAME)
			_tree_context_menu.add_item("Duplicate", ContextMenuId.DUPLICATE)
			_tree_context_menu.add_separator()
			_tree_context_menu.add_item("Delete", ContextMenuId.DELETE)
		else:
			_tree_context_menu.add_item("Open Tree", ContextMenuId.OPEN_TREE)
			_tree_context_menu.add_separator()
			_tree_context_menu.add_item("Rename", ContextMenuId.RENAME)
			_tree_context_menu.add_item("Duplicate", ContextMenuId.DUPLICATE)
			_tree_context_menu.add_separator()
			_tree_context_menu.add_item("Delete", ContextMenuId.DELETE)

	_tree_context_menu.popup_on_parent(Rect2i(
		_tree.get_screen_transform() * mouse_pos,
		Vector2i.ZERO
	))

func _on_tree_context_menu_pressed(id: int) -> void:
	match id:
		ContextMenuId.CREATE_GROUP:
			_create_group()
		ContextMenuId.CREATE_TREE:
			_create_tree()
		ContextMenuId.RENAME:
			_start_rename_selected()
		ContextMenuId.DUPLICATE:
			_duplicate_selected_item()
		ContextMenuId.DELETE:
			_delete_selected_item()
		ContextMenuId.OPEN_TREE:
			_open_selected_tree()

func _duplicate_selected_item() -> void:
	var selected := _tree.get_selected()
	if not selected:
		return

	var is_group: bool = selected.get_parent() == _tree.get_root()

	if is_group:
		_duplicate_selected_group()
	else:
		_duplicate_selected_tree()

func _delete_selected_item() -> void:
	var selected := _tree.get_selected()
	if not selected:
		return

	var is_group: bool = selected.get_parent() == _tree.get_root()

	if is_group:
		_request_delete_group()
	else:
		_request_delete_tree()

func _open_selected_tree() -> void:
	var selected := _tree.get_selected()
	if not selected:
		return
	if selected.get_parent() == _tree.get_root():
		return

	var meta: Dictionary = selected.get_metadata(0)
	if meta.get("type", "") != "tree":
		return

	if main_screen:
		main_screen.open_tree(meta["path"])

# ============================================================
# GROUP MENU
# ============================================================

func _on_group_menu_pressed(id: int) -> void:
	match id:
		GroupMenuId.CREATE: _create_group()
		GroupMenuId.DELETE: _request_delete_group()
		GroupMenuId.DUPLICATE: _duplicate_selected_group()

func _create_group() -> void:
	var registry: BayterekRegistry = Bayterek.get_editor_registry()
	if not registry:
		return

	var root_path: String = Bayterek.get_root_path()
	DirAccess.make_dir_recursive_absolute(root_path)

	var counter: int = 1
	var group_name: String = "Group %d" % counter
	var snake: String = Bayterek.to_snake_case(group_name)
	var group_dir: String = "%s/%s" % [root_path, snake]
	var group_file: String = "%s/%s.tres" % [group_dir, snake]

	while DirAccess.dir_exists_absolute(group_dir) or FileAccess.file_exists(group_file):
		counter += 1
		group_name = "Group %d" % counter
		snake = Bayterek.to_snake_case(group_name)
		group_dir = "%s/%s" % [root_path, snake]
		group_file = "%s/%s.tres" % [group_dir, snake]

	var mk_err: Error = DirAccess.make_dir_recursive_absolute(group_dir)
	if mk_err != OK:
		push_error("Bayterek: Grup klasörü oluşturulamadı (%d)" % mk_err)
		return

	var group := BayterekGroup.new()
	group.name = group_name
	group.trees = []

	var save_err: Error = ResourceSaver.save(group, group_file)
	if save_err != OK:
		push_error("Bayterek: Grup kaydedilemedi (%d)" % save_err)
		return

	var saved: BayterekGroup = ResourceLoader.load(group_file, "BayterekGroup", ResourceLoader.CACHE_MODE_IGNORE) as BayterekGroup
	if saved:
		saved.resource_path = group_file
		registry.groups.append(saved)

	ResourceSaver.save(registry, Bayterek.get_registry_path())

	EditorInterface.get_resource_filesystem().scan()
	_refresh_ui_only()

	print("Bayterek: Grup oluşturuldu: ", group_name)

# ============================================================
# TREE MENU
# ============================================================

func _on_tree_menu_pressed(id: int) -> void:
	match id:
		TreeMenuId.CREATE: _create_tree()
		TreeMenuId.DELETE: _request_delete_tree()
		TreeMenuId.DUPLICATE: _duplicate_selected_tree()

func _create_tree() -> void:
	var selected := _tree.get_selected()
	if not selected:
		return

	var group_path: String = ""
	if selected.get_parent() == _tree.get_root():
		group_path = selected.get_metadata(0).get("path", "")
	else:
		group_path = selected.get_metadata(0).get("group_path", "")

	if group_path.is_empty():
		return

	var registry: BayterekRegistry = Bayterek.get_editor_registry()
	var group: BayterekGroup = registry.find_group_by_path(group_path)
	if not group:
		push_error("Bayterek: Grup bulunamadı: %s" % group_path)
		return

	var base_dir: String = group_path.get_base_dir()

	var counter := 1
	var tree_name := "Tree %d" % counter
	var snake: String = Bayterek.to_snake_case(tree_name)
	var tree_file := "%s/%s.tres" % [base_dir, snake]

	while FileAccess.file_exists(tree_file):
		counter += 1
		tree_name = "Tree %d" % counter
		snake = Bayterek.to_snake_case(tree_name)
		tree_file = "%s/%s.tres" % [base_dir, snake]

	var tree := BayterekTree.new()
	tree.id = snake
	tree.name = tree_name
	tree.tree_state = BayterekTreeState.new()

	var save_err: Error = ResourceSaver.save(tree, tree_file)
	if save_err != OK:
		push_error("Bayterek: Tree kaydedilemedi (%d)" % save_err)
		return

	var saved: BayterekTree = ResourceLoader.load(tree_file, "BayterekTree", ResourceLoader.CACHE_MODE_IGNORE) as BayterekTree
	if saved:
		saved.resource_path = tree_file
		group.trees.append(saved)

	var group_save_err: Error = ResourceSaver.save(group, group.resource_path)
	if group_save_err != OK:
		push_error("Bayterek: Grup güncellenemedi (%d)" % group_save_err)

	ResourceSaver.save(registry, Bayterek.get_registry_path())

	EditorInterface.get_resource_filesystem().scan()
	_refresh_ui_only()

	print("Bayterek: Tree oluşturuldu: ", tree_name)

# ============================================================
# RENAME
# ============================================================

func _start_rename_selected() -> void:
	var selected := _tree.get_selected()
	if not selected:
		return
	_start_rename(selected)

func _start_rename(item: TreeItem) -> void:
	if not item:
		return
	if item == _tree.get_root():
		return

	_renaming_item = item
	item.select(0)
	_tree.edit_selected(true)
	_tree.grab_focus()

func _shortcut_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if not _tree.has_focus():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if event.keycode == KEY_F2:
		_start_rename_selected()
		get_viewport().set_input_as_handled()

func _on_item_edited() -> void:
	var item: TreeItem = _tree.get_edited()
	if not item:
		return
	_commit_rename(item)

func _commit_rename(item: TreeItem) -> void:
	var meta: Dictionary = item.get_metadata(0)
	if meta.is_empty():
		return

	var item_type: String = meta.get("type", "")
	var old_name: String = ""

	if item_type == "group":
		var grp: BayterekGroup = ResourceLoader.load(meta["path"])
		if grp:
			old_name = grp.name
		else:
			old_name = item.get_text(0)
	elif item_type == "tree":
		var tree_res: BayterekTree = ResourceLoader.load(meta["path"])
		if tree_res:
			old_name = tree_res.name
		else:
			old_name = item.get_text(0)
	else:
		return

	var new_name: String = item.get_text(0).strip_edges()

	if new_name.is_empty():
		_refresh_ui_only()
		_renaming_item = null
		return

	if new_name == old_name:
		_refresh_ui_only()
		_renaming_item = null
		return

	if item_type == "group":
		_rename_group(item, meta, old_name, new_name)
	elif item_type == "tree":
		_rename_tree(item, meta, old_name, new_name)

	_renaming_item = null

func _rename_group(item: TreeItem, meta: Dictionary, old_name: String, new_name: String) -> void:
	var registry: BayterekRegistry = Bayterek.get_editor_registry()
	if not registry:
		_refresh_ui_only()
		return

	var old_path: String = meta["path"]
	var old_group: BayterekGroup = ResourceLoader.load(old_path, "BayterekGroup", ResourceLoader.CACHE_MODE_IGNORE)
	if not old_group:
		_refresh_ui_only()
		return

	for g: BayterekGroup in registry.groups:
		if g == old_group:
			continue
		if g.name == new_name:
			push_warning("Bayterek: Grup zaten var: %s" % new_name)
			_refresh_ui_only()
			return

	if main_screen:
		for t: BayterekTree in old_group.trees:
			if main_screen.has_open_tree(t.resource_path):
				push_warning("Bayterek: Açık tree'ler varken grup ismi değiştirilemez: %s" % t.name)
				_refresh_ui_only()
				return

	var root_path: String = Bayterek.get_root_path()
	var new_snake: String = Bayterek.to_snake_case(new_name)
	var new_dir: String = "%s/%s" % [root_path, new_snake]
	var new_file: String = "%s/%s.tres" % [new_dir, new_snake]

	if DirAccess.dir_exists_absolute(new_dir) or FileAccess.file_exists(new_file):
		push_warning("Bayterek: Hedef klasör/dosya zaten var: %s" % new_dir)
		_refresh_ui_only()
		return

	var old_dir: String = old_path.get_base_dir()

	var rename_dir_err: Error = DirAccess.rename_absolute(old_dir, new_dir)
	if rename_dir_err != OK:
		push_error("Bayterek: Grup klasörü taşınamadı (%d)" % rename_dir_err)
		_refresh_ui_only()
		return

	var old_file_name: String = old_path.get_file()
	var new_file_name: String = "%s.tres" % new_snake
	var moved_file_path: String = "%s/%s" % [new_dir, old_file_name]

	if old_file_name != new_file_name:
		var inner_rename_err: Error = DirAccess.rename_absolute(moved_file_path, new_file)
		if inner_rename_err != OK:
			push_error("Bayterek: Grup dosyası yeniden adlandırılamadı (%d)" % inner_rename_err)
			DirAccess.rename_absolute(new_dir, old_dir)
			_refresh_ui_only()
			return
		moved_file_path = new_file

	_move_uid_sidecar(old_path, moved_file_path)

	for i in range(old_group.trees.size()):
		var t: BayterekTree = old_group.trees[i]
		if not t:
			continue
		var old_tree_path: String = t.resource_path
		var tree_file_name: String = old_tree_path.get_file()
		var new_tree_path: String = "%s/%s" % [new_dir, tree_file_name]
		t.resource_path = new_tree_path
		_move_uid_sidecar(old_tree_path, new_tree_path)

	old_group.name = new_name
	old_group.resource_path = moved_file_path

	var save_err: Error = ResourceSaver.save(old_group, moved_file_path, ResourceSaver.FLAG_CHANGE_PATH)
	if save_err != OK:
		push_error("Bayterek: Grup kaydedilemedi (%d)" % save_err)
		_refresh_ui_only()
		return

	ResourceSaver.save(registry, Bayterek.get_registry_path())

	EditorInterface.get_resource_filesystem().scan()
	_refresh_ui_only()

	print("Bayterek: Grup yeniden adlandırıldı: %s → %s" % [old_name, new_name])

func _rename_tree(item: TreeItem, meta: Dictionary, old_name: String, new_name: String) -> void:
	var old_path: String = meta["path"]
	var group_path: String = meta.get("group_path", "")
	if group_path.is_empty():
		_refresh_ui_only()
		return

	var tree_res: BayterekTree = ResourceLoader.load(old_path, "BayterekTree", ResourceLoader.CACHE_MODE_IGNORE)
	if not tree_res:
		_refresh_ui_only()
		return

	if main_screen and main_screen.has_open_tree(old_path):
		push_warning("Bayterek: Açık tree'ler varken ismi değiştirilemez.")
		_refresh_ui_only()
		return

	var registry: BayterekRegistry = Bayterek.get_editor_registry()
	if not registry:
		_refresh_ui_only()
		return

	var group: BayterekGroup = registry.find_group_by_path(group_path)
	if not group:
		_refresh_ui_only()
		return

	for t: BayterekTree in group.trees:
		if t == tree_res:
			continue
		if t.name == new_name:
			push_warning("Bayterek: Bu grupta aynı isimde tree var: %s" % new_name)
			_refresh_ui_only()
			return

	var base_dir: String = group.resource_path.get_base_dir()
	var new_snake: String = Bayterek.to_snake_case(new_name)
	var new_file: String = "%s/%s.tres" % [base_dir, new_snake]

	if FileAccess.file_exists(new_file) and new_file != old_path:
		push_warning("Bayterek: Hedef dosya zaten var: %s" % new_file)
		_refresh_ui_only()
		return

	if new_file != old_path:
		var rename_err: Error = DirAccess.rename_absolute(old_path, new_file)
		if rename_err != OK:
			push_error("Bayterek: Tree dosyası taşınamadı (%d)" % rename_err)
			_refresh_ui_only()
			return

	_move_uid_sidecar(old_path, new_file)

	tree_res.name = new_name
	tree_res.id = new_snake
	tree_res.resource_path = new_file

	var save_err: Error = ResourceSaver.save(tree_res, new_file, ResourceSaver.FLAG_CHANGE_PATH)
	if save_err != OK:
		push_error("Bayterek: Tree kaydedilemedi (%d)" % save_err)
		_refresh_ui_only()
		return

	ResourceSaver.save(group, group.resource_path)
	ResourceSaver.save(registry, Bayterek.get_registry_path())

	EditorInterface.get_resource_filesystem().scan()
	_refresh_ui_only()

	print("Bayterek: Tree yeniden adlandırıldı: %s → %s" % [old_name, new_name])

func _move_uid_sidecar(old_path: String, new_path: String) -> void:
	var old_uid_file: String = old_path + ".uid"
	var new_uid_file: String = new_path + ".uid"
	if FileAccess.file_exists(old_uid_file):
		if FileAccess.file_exists(new_uid_file):
			DirAccess.remove_absolute(new_uid_file)
		DirAccess.rename_absolute(old_uid_file, new_uid_file)

# ============================================================
# DRAG & DROP — Move trees between groups
# ============================================================

## Called when the user starts dragging from the Tree.
## Returns the dragged TreeItem (must be a tree, not a group).
func _tree_get_drag_data(at_position: Vector2) -> Variant:
	var item: TreeItem = _tree.get_item_at_position(at_position)
	if not item:
		return null
	if item.get_parent() == _tree.get_root():
		return null  # Group items are not draggable

	var meta: Dictionary = item.get_metadata(0)
	if meta.get("type", "") != "tree":
		return null

	# Build a small preview
	var preview := HBoxContainer.new()
	preview.add_theme_constant_override("separation", 4)

	var icon := TextureRect.new()
	icon.texture = item.get_icon(0)
	icon.custom_minimum_size = Vector2(16, 16)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.add_child(icon)

	var label := Label.new()
	label.text = item.get_text(0)
	preview.add_child(label)

	set_drag_preview(preview)

	return item

## Called every frame while dragging over the Tree.
## Returns true if `data` (the dragged TreeItem) can be dropped at `at_position`.
func _tree_can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is TreeItem:
		return false

	var dragged: TreeItem = data
	var dragged_meta: Dictionary = dragged.get_metadata(0)
	if dragged_meta.get("type", "") != "tree":
		return false

	var dragged_path: String = dragged_meta.get("path", "")

	# Cannot move trees that are currently open in an editor
	if main_screen and main_screen.has_open_tree(dragged_path):
		return false

	var drop_item: TreeItem = _tree.get_item_at_position(at_position)
	if not drop_item:
		return false

	# Drop target must be a group (top-level), not another tree
	if drop_item.get_parent() != _tree.get_root():
		return false

	# Cannot drop into the same group it came from
	var source_group: TreeItem = dragged.get_parent()
	if source_group == drop_item:
		return false

	return true

## Called when the user releases the drag over a valid drop target.
func _tree_drop_data(at_position: Vector2, data: Variant) -> void:
	if not data is TreeItem:
		return

	var dragged: TreeItem = data
	var dragged_meta: Dictionary = dragged.get_metadata(0)
	if dragged_meta.get("type", "") != "tree":
		return

	var drop_item: TreeItem = _tree.get_item_at_position(at_position)
	if not drop_item or drop_item.get_parent() != _tree.get_root():
		return

	var source_group_item: TreeItem = dragged.get_parent()
	if source_group_item == drop_item:
		return

	# Resolve groups from registry by resource_path
	var registry: BayterekRegistry = Bayterek.get_editor_registry()
	if not registry:
		return

	var source_group_path: String = source_group_item.get_metadata(0).get("path", "")
	var target_group_path: String = drop_item.get_metadata(0).get("path", "")
	if source_group_path.is_empty() or target_group_path.is_empty():
		return

	var source_group: BayterekGroup = registry.find_group_by_path(source_group_path)
	var target_group: BayterekGroup = registry.find_group_by_path(target_group_path)
	if not source_group or not target_group:
		return

	var old_path: String = dragged_meta.get("path", "")
	if old_path.is_empty():
		return

	# Find the BayterekTree in the source group matching the old path
	var tree_res: BayterekTree = null
	for t: BayterekTree in source_group.trees:
		if t.resource_path == old_path:
			tree_res = t
			break
	if not tree_res:
		push_warning("Bayterek: Drag-drop — tree bulunamadı: %s" % old_path)
		return

	# Compute new path inside the target group's folder
	var target_dir: String = target_group.resource_path.get_base_dir()
	var old_file_name: String = old_path.get_file()
	var new_path: String = "%s/%s" % [target_dir, old_file_name]

	# If a file with the same name already exists, find a unique name
	if FileAccess.file_exists(new_path) and new_path != old_path:
		var base_name: String = old_file_name.get_basename()
		var counter: int = 1
		while FileAccess.file_exists(new_path):
			new_path = "%s/%s_%d.tres" % [target_dir, base_name, counter]
			counter += 1

	# Physical move: file + .uid sidecar
	var rename_err: Error = DirAccess.rename_absolute(old_path, new_path)
	if rename_err != OK:
		push_error("Bayterek: Tree taşınamadı (%d)" % rename_err)
		return

	_move_uid_sidecar(old_path, new_path)

	# Update resource_path and re-save the tree at the new location
	tree_res.resource_path = new_path
	ResourceSaver.save(tree_res, new_path, ResourceSaver.FLAG_CHANGE_PATH)

	# Move the tree between the group arrays
	source_group.trees.erase(tree_res)
	target_group.trees.append(tree_res)

	ResourceSaver.save(source_group, source_group.resource_path)
	ResourceSaver.save(target_group, target_group.resource_path)
	ResourceSaver.save(registry, Bayterek.get_registry_path())

	EditorInterface.get_resource_filesystem().scan()
	_refresh_ui_only()

	print("Bayterek: Tree taşındı: %s → %s (%s → %s)" % [
		tree_res.name, target_group.name, old_path, new_path
	])

# ============================================================
# DUPLICATE
# ============================================================

func _duplicate_selected_group() -> void:
	var selected := _tree.get_selected()
	if not selected or selected.get_parent() != _tree.get_root():
		return

	var meta: Dictionary = selected.get_metadata(0)
	if meta.get("type", "") != "group":
		return

	var source_group_path: String = meta["path"]
	var source_group: BayterekGroup = ResourceLoader.load(source_group_path)
	if not source_group:
		push_error("Bayterek: Duplicate group could not be loaded: %s" % source_group_path)
		return

	var registry: BayterekRegistry = Bayterek.get_editor_registry()
	if not registry:
		return

	var base_name: String = source_group.name + " Copy"
	var root_path: String = Bayterek.get_root_path()

	var counter: int = 0
	var new_name: String = base_name
	var snake: String = Bayterek.to_snake_case(new_name)
	var new_dir: String = "%s/%s" % [root_path, snake]
	var new_file: String = "%s/%s.tres" % [new_dir, snake]

	while DirAccess.dir_exists_absolute(new_dir) or FileAccess.file_exists(new_file):
		counter += 1
		new_name = "%s %d" % [base_name, counter]
		snake = Bayterek.to_snake_case(new_name)
		new_dir = "%s/%s" % [root_path, snake]
		new_file = "%s/%s.tres" % [new_dir, snake]

	var mk_err: Error = DirAccess.make_dir_recursive_absolute(new_dir)
	if mk_err != OK:
		push_error("Bayterek: Could not create duplicate group folder (%d)" % mk_err)
		return

	var new_group := BayterekGroup.new()
	new_group.name = new_name
	new_group.trees = []

	var save_err: Error = ResourceSaver.save(new_group, new_file)
	if save_err != OK:
		push_error("Bayterek: Could not save duplicate group (%d)" % save_err)
		return

	var saved_group: BayterekGroup = ResourceLoader.load(new_file, "BayterekGroup", ResourceLoader.CACHE_MODE_IGNORE)
	if saved_group:
		saved_group.resource_path = new_file

	for tree_data: BayterekTree in source_group.trees:
		_duplicate_tree_into_group(tree_data, saved_group, new_dir)

	ResourceSaver.save(saved_group, new_file)

	registry.groups.append(saved_group)
	ResourceSaver.save(registry, Bayterek.get_registry_path())

	EditorInterface.get_resource_filesystem().scan()
	_refresh()

	print("Bayterek: Group duplicated: %s" % new_name)

func _duplicate_selected_tree() -> void:
	var selected := _tree.get_selected()
	if not selected or selected.get_parent() == _tree.get_root():
		return

	var meta: Dictionary = selected.get_metadata(0)
	if meta.get("type", "") != "tree":
		return

	var source_tree_path: String = meta["path"]
	var group_path: String = meta.get("group_path", "")
	if group_path.is_empty():
		return

	var registry: BayterekRegistry = Bayterek.get_editor_registry()
	if not registry:
		return

	var group: BayterekGroup = registry.find_group_by_path(group_path)
	if not group:
		return

	var source_tree: BayterekTree = ResourceLoader.load(source_tree_path, "BayterekTree", ResourceLoader.CACHE_MODE_IGNORE)
	if not source_tree:
		return

	_duplicate_tree_into_group(source_tree, group, group.resource_path.get_base_dir(), source_tree.name + " Copy")
	ResourceSaver.save(group, group.resource_path)
	ResourceSaver.save(registry, Bayterek.get_registry_path())

	EditorInterface.get_resource_filesystem().scan()
	_refresh()

func _duplicate_tree_into_group(
	source_tree: BayterekTree,
	target_group: BayterekGroup,
	target_dir: String,
	base_name: String = ""
) -> void:
	if base_name.is_empty():
		base_name = source_tree.name + " Copy"

	var counter: int = 0
	var new_name: String = base_name
	var snake: String = Bayterek.to_snake_case(new_name)
	var new_file: String = "%s/%s.tres" % [target_dir, snake]

	while FileAccess.file_exists(new_file):
		counter += 1
		new_name = "%s %d" % [base_name, counter]
		snake = Bayterek.to_snake_case(new_name)
		new_file = "%s/%s.tres" % [target_dir, snake]

	var duplicate: BayterekTree = source_tree.duplicate(true) as BayterekTree
	if not duplicate:
		push_error("Bayterek: Tree duplicate failed for %s" % source_tree.name)
		return

	duplicate.name = new_name
	duplicate.id = snake

	var save_err: Error = ResourceSaver.save(duplicate, new_file)
	if save_err != OK:
		push_error("Bayterek: Could not save duplicate tree (%d)" % save_err)
		return

	var saved_tree: BayterekTree = ResourceLoader.load(new_file, "BayterekTree", ResourceLoader.CACHE_MODE_IGNORE)
	if saved_tree:
		saved_tree.resource_path = new_file
		target_group.trees.append(saved_tree)

	print("Bayterek: Tree duplicated: %s" % new_name)

# ============================================================
# DELETE
# ============================================================

func _request_delete_group() -> void:
	var selected := _tree.get_selected()
	if not selected:
		return
	var meta: Dictionary = selected.get_metadata(0)
	if meta.get("type", "") != "group":
		return

	_pending_delete = {"type": "group", "path": meta["path"], "name": selected.get_text(0)}
	_open_delete_dialog(
		"Do you want to remove \"%s\" group?" % selected.get_text(0),
		"Delete tree files too"
	)

func _request_delete_tree() -> void:
	var selected := _tree.get_selected()
	if not selected:
		return
	var meta: Dictionary = selected.get_metadata(0)
	if meta.get("type", "") != "tree":
		return

	_pending_delete = {"type": "tree", "path": meta["path"], "name": selected.get_text(0), "group_path": meta.get("group_path", "")}
	_open_delete_dialog(
		"Do you want to remove \"%s\" tree?" % selected.get_text(0),
		"Delete tree file"
	)

func _open_delete_dialog(message: String, checkbox_text: String) -> void:
	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "Confirm Delete"
	_delete_dialog.ok_button_text = "Remove"
	_delete_dialog.cancel_button_text = "Cancel"
	_delete_dialog.dialog_text = ""
	_delete_dialog.min_size = Vector2i.ZERO
	_delete_dialog.unresizable = true

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_delete_dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var info_label := Label.new()
	info_label.name = "InfoLabel"
	info_label.text = message
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	info_label.add_theme_font_size_override("font_size", 13)
	info_label.custom_minimum_size = Vector2(360, 0)
	vbox.add_child(info_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_delete_checkbox = CheckBox.new()
	_delete_checkbox.text = checkbox_text
	_delete_checkbox.button_pressed = true
	vbox.add_child(_delete_checkbox)

	_delete_dialog.confirmed.connect(_on_delete_confirmed)
	_delete_dialog.canceled.connect(_cleanup_delete_dialog)
	_delete_dialog.close_requested.connect(_cleanup_delete_dialog)

	add_child(_delete_dialog)

	if not _delete_dialog.visible:
		await get_tree().process_frame

	_delete_dialog.popup_centered(Vector2i(420, 180))

func _cleanup_delete_dialog() -> void:
	_pending_delete = {}
	if is_instance_valid(_delete_dialog):
		_delete_dialog.queue_free()
	_delete_dialog = null
	_delete_checkbox = null

func _on_delete_confirmed() -> void:
	if _pending_delete.is_empty():
		_cleanup_delete_dialog()
		return

	var delete_files: bool = _delete_checkbox.button_pressed if _delete_checkbox else false

	var pending = _pending_delete
	_pending_delete = {}

	if pending["type"] == "group":
		_do_delete_group(pending, delete_files)
	elif pending["type"] == "tree":
		_do_delete_tree(pending, delete_files)

	_cleanup_delete_dialog()

	EditorInterface.get_resource_filesystem().scan()
	_refresh()

func _do_delete_group(info: Dictionary, delete_files: bool) -> void:
	var registry: BayterekRegistry = Bayterek.get_editor_registry()
	var group: BayterekGroup = registry.find_group_by_path(info["path"])
	if not group:
		return

	registry.groups.erase(group)
	ResourceSaver.save(registry, Bayterek.get_registry_path())

	if delete_files:
		for tree: BayterekTree in group.trees:
			if not tree.resource_path.is_empty():
				_delete_with_sidecar(tree.resource_path)
		if not group.resource_path.is_empty():
			_delete_with_sidecar(group.resource_path)

	print("Bayterek: Grup silindi: ", info["name"])

func _do_delete_tree(info: Dictionary, delete_file: bool) -> void:
	var registry: BayterekRegistry = Bayterek.get_editor_registry()
	var group: BayterekGroup = registry.find_group_by_path(info.get("group_path", ""))
	if not group:
		return

	var target: BayterekTree = null
	for t: BayterekTree in group.trees:
		if t.resource_path == info["path"]:
			target = t
			break

	if not target:
		return

	group.trees.erase(target)
	ResourceSaver.save(group, group.resource_path)
	ResourceSaver.save(registry, Bayterek.get_registry_path())

	if delete_file:
		_delete_with_sidecar(info["path"])

	print("Bayterek: Tree silindi: ", info["name"])

func _delete_with_sidecar(path: String) -> void:
	var uid_path: String = path + ".uid"
	if FileAccess.file_exists(uid_path):
		DirAccess.remove_absolute(uid_path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

# ============================================================
# ARAMA / DOCS
# ============================================================

func _on_search_changed(new_text: String) -> void:
	var q: String = new_text.strip_edges()
	var root: TreeItem = _tree.get_root()

	if not root:
		return

	if q.is_empty():
		for g in root.get_children():
			g.visible = true
			for t in g.get_children():
				t.visible = true
		return

	var fuzzy := BayterekFuzzySearch.new()
	fuzzy.allow_subsequences = false

	for g in root.get_children():
		var group_visible := false
		var group_name: String = g.get_text(0)
		var group_matches := fuzzy.matches(q, group_name)

		for t in g.get_children():
			var tree_name: String = t.get_text(0)
			var tree_matches := fuzzy.matches(q, tree_name)
			t.visible = group_matches or tree_matches
			if t.visible:
				group_visible = true

		g.visible = group_matches or group_visible

func _on_docs_pressed() -> void:
	OS.shell_open("https://github.com/")