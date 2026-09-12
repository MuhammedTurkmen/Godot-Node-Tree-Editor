@tool
class_name BayterekBrowser
extends MarginContainer
## Grup / tree listeleme, oluşturma, silme.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

enum GroupMenuId { CREATE = 0, DELETE = 1, DUPLICATE = 2 }
enum TreeMenuId  { CREATE = 0, DELETE = 1, DUPLICATE = 2 }

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

var _pending_delete: Dictionary = {}

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
	_group_menu.get_popup().set_item_disabled(GroupMenuId.DELETE, true)
	top.add_child(_group_menu)

	_tree_menu = MenuButton.new()
	_tree_menu.text = "Tree"
	_tree_menu.get_popup().add_item("Create", TreeMenuId.CREATE)
	_tree_menu.get_popup().add_item("Delete", TreeMenuId.DELETE)
	_tree_menu.get_popup().set_item_disabled(TreeMenuId.CREATE, true)
	_tree_menu.get_popup().set_item_disabled(TreeMenuId.DELETE, true)
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

	# --- Silme dialogu ---
	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.ok_button_text = "Remove"
	add_child(_delete_dialog)

	_delete_checkbox = CheckBox.new()
	_delete_checkbox.text = "Delete related files"
	_delete_checkbox.button_pressed = true
	_delete_dialog.add_child(_delete_checkbox)

	# Layout'u şimdi hesapla
	queue_sort()

func _connect_signals() -> void:
	_group_menu.get_popup().id_pressed.connect(_on_group_menu_pressed)
	_tree_menu.get_popup().id_pressed.connect(_on_tree_menu_pressed)
	_tree.item_selected.connect(_on_item_selected)
	_tree.item_activated.connect(_on_item_activated)
	_search.text_changed.connect(_on_search_changed)
	_docs_button.pressed.connect(_on_docs_pressed)
	_delete_dialog.confirmed.connect(_on_delete_confirmed)

# ============================================================
# REFRESH
# ============================================================

func _refresh() -> void:
	var start_time := Time.get_ticks_usec()

	Bayterek.reload_editor_registry()
	var registry: BayterekRegistry = Bayterek.get_editor_registry()

	_tree.clear()
	_tree.create_item()

	if not registry:
		return

	var root: TreeItem = _tree.get_root()
	var total_trees: int = 0

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
			total_trees += 1

	_groups_count_label.text = "Total groups: %d" % registry.groups.size()
	_trees_count_label.text = "Total trees: %d" % total_trees

	var elapsed: float = (Time.get_ticks_usec() - start_time) / 1_000_000.0
	_load_time_label.text = "Load time: %.2fs" % elapsed

# ============================================================
# SEÇİM
# ============================================================

func _on_item_selected() -> void:
	var selected := _tree.get_selected()
	if not selected:
		return

	var is_group: bool = selected.get_parent() == _tree.get_root()

	_group_menu.get_popup().set_item_disabled(GroupMenuId.DELETE, not is_group)
	_tree_menu.get_popup().set_item_disabled(TreeMenuId.CREATE, false)
	_tree_menu.get_popup().set_item_disabled(TreeMenuId.DELETE, is_group)

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
# GROUP MENU
# ============================================================

func _on_group_menu_pressed(id: int) -> void:
	match id:
		GroupMenuId.CREATE: _create_group()
		GroupMenuId.DELETE: _request_delete_group()

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
	registry.groups.append(saved)
	Bayterek.save_editor_registry()

	EditorInterface.get_resource_filesystem().scan()
	_refresh()

	print("Bayterek: Grup oluşturuldu: ", group_name)

# ============================================================
# TREE MENU
# ============================================================

func _on_tree_menu_pressed(id: int) -> void:
	match id:
		TreeMenuId.CREATE: _create_tree()
		TreeMenuId.DELETE: _request_delete_tree()

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
	group.trees.append(saved)

	var group_save_err: Error = ResourceSaver.save(group, group.resource_path)
	if group_save_err != OK:
		push_error("Bayterek: Grup güncellenemedi (%d)" % group_save_err)

	EditorInterface.get_resource_filesystem().scan()
	_refresh()

	print("Bayterek: Tree oluşturuldu: ", tree_name)

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
	_delete_checkbox.visible = true
	_delete_checkbox.text = "Delete tree files too"
	_delete_dialog.dialog_text = "\"%s\" grubunu silmek istiyor musun?" % selected.get_text(0)
	_delete_dialog.popup_centered()

func _request_delete_tree() -> void:
	var selected := _tree.get_selected()
	if not selected:
		return
	var meta: Dictionary = selected.get_metadata(0)
	if meta.get("type", "") != "tree":
		return

	_pending_delete = {"type": "tree", "path": meta["path"], "name": selected.get_text(0), "group_path": meta.get("group_path", "")}
	_delete_checkbox.visible = true
	_delete_checkbox.text = "Delete tree file"
	_delete_dialog.dialog_text = "\"%s\" ağacını silmek istiyor musun?" % selected.get_text(0)
	_delete_dialog.popup_centered()

func _on_delete_confirmed() -> void:
	if _pending_delete.is_empty():
		return

	var delete_files: bool = _delete_checkbox.button_pressed

	if _pending_delete["type"] == "group":
		_do_delete_group(_pending_delete, delete_files)
	elif _pending_delete["type"] == "tree":
		_do_delete_tree(_pending_delete, delete_files)

	_pending_delete = {}
	EditorInterface.get_resource_filesystem().scan()
	_refresh()

func _do_delete_group(info: Dictionary, delete_files: bool) -> void:
	var registry: BayterekRegistry = Bayterek.get_editor_registry()
	var group: BayterekGroup = registry.find_group_by_path(info["path"])
	if not group:
		return

	registry.groups.erase(group)
	Bayterek.save_editor_registry()

	if delete_files:
		for tree: BayterekTree in group.trees:
			if not tree.resource_path.is_empty():
				DirAccess.remove_absolute(tree.resource_path)
		if not group.resource_path.is_empty():
			DirAccess.remove_absolute(group.resource_path)

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

	if delete_file:
		DirAccess.remove_absolute(info["path"])

	print("Bayterek: Tree silindi: ", info["name"])

# ============================================================
# ARAMA / DOCS
# ============================================================

func _on_search_changed(new_text: String) -> void:
	var q: String = new_text.strip_edges().to_lower()
	var root: TreeItem = _tree.get_root()

	for g in root.get_children():
		var group_visible := false
		var group_name: String = g.get_text(0).to_lower()
		var group_matches := q.is_empty() or group_name.contains(q)

		for t in g.get_children():
			var tree_name: String = t.get_text(0).to_lower()
			var tree_matches := q.is_empty() or tree_name.contains(q)
			t.visible = group_matches or tree_matches
			if t.visible:
				group_visible = true

		g.visible = group_matches or group_visible

func _on_docs_pressed() -> void:
	OS.shell_open("https://github.com/")