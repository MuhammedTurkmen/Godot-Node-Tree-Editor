@tool
class_name BayterekEditorContext
extends PopupMenu
## Canvas / node sağ tık context menüsü.
##
## İki mod:
##   - CANVAS modu → boşluğa sağ tık. Tüm seçenekler görünür (New Node dahil).
##   - NODE modu   → bir node üzerine sağ tık. New Node öğesi TAMAMEN kaldırılır.
##
## Godot 4.7'de `set_item_visible` API'si olmadığı için menüyü her
## açılışta moda göre sıfırdan kuruyoruz. Bu sayede node modunda
## "New Node" öğesi ve onu takip eden separator hiç görünmez.

signal new_node_requested(design_id: String, tree_pos: Vector2)
signal make_root_requested
signal duplicate_requested
signal save_as_prefab_requested
signal make_unique_requested
signal assign_group_requested(group_id: String)
signal remove_group_requested
signal create_group_requested
signal delete_requested
signal cleanup_orphans_requested

# Context menu item IDs
const CM_NEW_NODE := 10
const CM_SAVE_PREFAB := 100
const CM_MAKE_UNIQUE := 102
const CM_DELETE := 103
const CM_MAKE_ROOT := 150
const CM_DUPLICATE := 151
const CM_ASSIGN_GROUP := 160
const CM_CLEANUP_ORPHANS := 200

const GROUP_SUBMENU_REMOVE := 200
const GROUP_SUBMENU_CREATE := 201
const GROUP_SUBMENU_BASE := 1000

const DESIGN_SUBMENU_BASE := 5000

var editor: BayterekEditor

var _new_node_submenu: PopupMenu
var _group_submenu: PopupMenu
var _design_menu_id_to_design_id: Dictionary = {}

var _last_tree_pos: Vector2 = Vector2.ZERO

## True → bu açılış bir node üzerine sağ tık.
var _node_mode: bool = false

# ============================================================
# SETUP
# ============================================================

func setup(p_editor: BayterekEditor) -> void:
	editor = p_editor
	name = "BayterekContextMenu"

	# Submenüleri bir kere oluştur. Menü açılışında ana menüyü
	# clear() + yeniden kuracağız ama submenu node'larını koruyacağız.
	_new_node_submenu = PopupMenu.new()
	_new_node_submenu.name = "NewNodeSubmenu"
	_new_node_submenu.id_pressed.connect(_on_new_node_design_selected)
	_new_node_submenu.about_to_popup.connect(_rebuild_new_node_submenu)
	add_child(_new_node_submenu)

	_group_submenu = PopupMenu.new()
	_group_submenu.name = "GroupSubmenu"
	_group_submenu.id_pressed.connect(_on_group_submenu_pressed)
	add_child(_group_submenu)

	id_pressed.connect(_on_id_pressed)

# ============================================================
# OPEN — MOD'A GÖRE MENÜYÜ YENİDEN KUR
# ============================================================

## Boşluğa sağ tık — tüm seçenekler (New Node dahil).
func open_for_canvas(screen_pos: Vector2, tree_pos: Vector2) -> void:
	_node_mode = false
	_last_tree_pos = tree_pos
	_build_menu()
	_update_enabled_state()

	position = Vector2i(screen_pos)
	popup()


## Node üzerine sağ tık — New Node ve onu takip eden separator YOK.
func open_for_node(screen_pos: Vector2, tree_pos: Vector2) -> void:
	_node_mode = true
	_last_tree_pos = tree_pos
	_build_menu()
	_update_enabled_state()

	position = Vector2i(screen_pos)
	popup()


## Geriye dönük uyumluluk — canvas modu gibi davranır.
func open_at(screen_pos: Vector2, tree_pos: Vector2) -> void:
	open_for_canvas(screen_pos, tree_pos)

# ============================================================
# MENÜ KURULUMU — MOD'A GÖRE
# ============================================================

func _build_menu() -> void:
	clear()

	if _node_mode:
		_build_node_menu()
	else:
		_build_canvas_menu()

func _build_canvas_menu() -> void:
	# New Node (submenu)
	add_submenu_node_item("New Node", _new_node_submenu, CM_NEW_NODE)

	add_separator()

	add_item("Make Root", CM_MAKE_ROOT)
	add_item("Duplicate", CM_DUPLICATE)
	add_separator()

	add_submenu_node_item("Assign to Group", _group_submenu, CM_ASSIGN_GROUP)

	add_separator()
	add_item("Save as Prefab", CM_SAVE_PREFAB)
	add_item("Make Unique", CM_MAKE_UNIQUE)
	add_separator()
	add_item("Delete", CM_DELETE)
	add_separator()
	add_item("Cleanup Orphan Prefabs", CM_CLEANUP_ORPHANS)

func _build_node_menu() -> void:
	# NOT: New Node ve onu takip eden separator YOK.
	add_item("Make Root", CM_MAKE_ROOT)
	add_item("Duplicate", CM_DUPLICATE)
	add_separator()

	add_submenu_node_item("Assign to Group", _group_submenu, CM_ASSIGN_GROUP)

	add_separator()
	add_item("Save as Prefab", CM_SAVE_PREFAB)
	add_item("Make Unique", CM_MAKE_UNIQUE)
	add_separator()
	add_item("Delete", CM_DELETE)
	add_separator()
	add_item("Cleanup Orphan Prefabs", CM_CLEANUP_ORPHANS)

# ============================================================
# ENABLED STATE
# ============================================================

func _update_enabled_state() -> void:
	if not editor or not editor.tree_view:
		return

	var has_selection: bool = not editor.tree_view.selected_nodes.is_empty()

	_set_disabled(CM_SAVE_PREFAB, not has_selection)
	_set_disabled(CM_MAKE_UNIQUE, not has_selection)
	_set_disabled(CM_DELETE, not has_selection)
	_set_disabled(CM_DUPLICATE, not has_selection)
	_set_disabled(CM_ASSIGN_GROUP, not has_selection)

	if has_selection:
		var any_prefab := false
		var any_not_root := false
		for n in editor.tree_view.selected_nodes:
			if not is_instance_valid(n):
				continue
			if n.prefab:
				any_prefab = true
			if n.node_data and not n.node_data.is_root:
				any_not_root = true
		_set_disabled(CM_MAKE_UNIQUE, not any_prefab)
		_set_disabled(CM_MAKE_ROOT, not any_not_root)
	else:
		_set_disabled(CM_MAKE_ROOT, true)

	# Group submenu'sini (varsa) güncelle.
	_rebuild_group_submenu()

func _set_disabled(item_id: int, disabled: bool) -> void:
	var idx := get_item_index(item_id)
	if idx >= 0:
		set_item_disabled(idx, disabled)

# ============================================================
# NEW NODE SUBMENU
# ============================================================

func _rebuild_new_node_submenu() -> void:
	if not _new_node_submenu:
		return

	# Node modunda New Node submenu hiç açılmaz (menüde yok zaten).
	if _node_mode:
		return

	_new_node_submenu.clear()
	_design_menu_id_to_design_id.clear()

	for child in _new_node_submenu.get_children():
		if child is PopupMenu:
			child.queue_free()

	var grouped := BayterekDesignService.get_designs_grouped_by_category()
	if grouped.is_empty():
		_new_node_submenu.add_item("No designs available...", DESIGN_SUBMENU_BASE)
		return

	var next_id: int = DESIGN_SUBMENU_BASE

	for category in grouped.keys():
		var designs: Array = grouped[category]
		designs.sort_custom(func(a, b): return a.name.naturalnocasecmp_to(b.name) < 0)

		var cat_menu := PopupMenu.new()
		cat_menu.name = "Cat_%s" % category
		cat_menu.id_pressed.connect(_on_new_node_design_selected)

		var cat_first_id: int = next_id
		for design in designs:
			var d: BayterekNodeDesign = design
			cat_menu.add_item(d.name, next_id)
			_design_menu_id_to_design_id[next_id] = d.id
			next_id += 1

		_new_node_submenu.add_child(cat_menu)
		_new_node_submenu.add_submenu_node_item(category, cat_menu, cat_first_id)

func _on_new_node_design_selected(id: int) -> void:
	if not _design_menu_id_to_design_id.has(id):
		return
	var design_id: String = _design_menu_id_to_design_id[id]
	new_node_requested.emit(design_id, _last_tree_pos)

# ============================================================
# GROUP SUBMENU
# ============================================================

func _rebuild_group_submenu() -> void:
	if not _group_submenu or not editor or not editor.tree:
		return

	_group_submenu.clear()

	var has_selection := editor.tree_view and not editor.tree_view.selected_nodes.is_empty()
	if not has_selection:
		return

	var groups: Array = editor.tree.node_groups
	for i in groups.size():
		var group = groups[i]
		if group:
			_group_submenu.add_item(group.name, GROUP_SUBMENU_BASE + i)
			var idx := _group_submenu.item_count - 1
			_group_submenu.set_item_icon(idx, _make_color_icon(group.color))

	_group_submenu.add_separator()
	_group_submenu.add_item("New Group...", GROUP_SUBMENU_CREATE)
	_group_submenu.add_separator()
	_group_submenu.add_item("Remove from Group", GROUP_SUBMENU_REMOVE)

func _make_color_icon(c: Color) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(c)
	var border := Color(0, 0, 0, 0.6)
	for x in 16:
		img.set_pixel(x, 0, border)
		img.set_pixel(x, 15, border)
	for y in 16:
		img.set_pixel(0, y, border)
		img.set_pixel(15, y, border)
	return ImageTexture.create_from_image(img)

func _on_group_submenu_pressed(id: int) -> void:
	if id == GROUP_SUBMENU_REMOVE:
		remove_group_requested.emit()
		return
	if id == GROUP_SUBMENU_CREATE:
		create_group_requested.emit()
		return
	if id >= GROUP_SUBMENU_BASE and editor and editor.tree:
		var groups: Array = editor.tree.node_groups
		var idx: int = id - GROUP_SUBMENU_BASE
		if idx >= 0 and idx < groups.size():
			var group: BayterekNodeGroup = groups[idx]
			if group:
				assign_group_requested.emit(group.id)

# ============================================================
# ID PRESSED
# ============================================================

func _on_id_pressed(id: int) -> void:
	match id:
		CM_SAVE_PREFAB: save_as_prefab_requested.emit()
		CM_MAKE_UNIQUE: make_unique_requested.emit()
		CM_DELETE: delete_requested.emit()
		CM_MAKE_ROOT: make_root_requested.emit()
		CM_DUPLICATE: duplicate_requested.emit()
		CM_CLEANUP_ORPHANS: cleanup_orphans_requested.emit()