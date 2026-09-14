@tool
class_name BayterekIconSelector
extends Popup
## Icon selector — pick an icon from a spritesheet grid.
## Shows a preview of each cell (icon_size) and filters out empty cells.

signal icon_selected(node_type: int, texture: Texture2D, region: Vector2)

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

@export var editor: BayterekEditor

var _icon_type_dropdown: OptionButton
var _path_input: LineEdit
var _browse_button: Button
var _clear_button: Button
var _icons_list: ItemList
var _apply_button: Button
var _close_button: Button

var _current_node_type: int = BayterekNode.NodeType.SMALL
var _texture_cache: Texture2D = null

# ============================================================
# INIT
# ============================================================

func init() -> void:
	title = "Icon Selector"
	size = Vector2i(500, 500)
	unresizable = false
	borderless = false

	_build_ui()
	_connect_signals()

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.name = "PanelContainer"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.14, 1.0)
	panel_style.content_margin_left = 8
	panel_style.content_margin_right = 8
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# === Top row ===
	var top_row := HBoxContainer.new()
	top_row.name = "TopRow"
	top_row.add_theme_constant_override("separation", 6)
	vbox.add_child(top_row)

	_icon_type_dropdown = OptionButton.new()
	_icon_type_dropdown.name = "NodeType"
	_icon_type_dropdown.custom_minimum_size = Vector2(140, 0)
	_icon_type_dropdown.add_item("Small Nodes", BayterekNode.NodeType.SMALL)
	_icon_type_dropdown.add_item("Medium Nodes", BayterekNode.NodeType.MEDIUM)
	_icon_type_dropdown.add_item("Large Nodes", BayterekNode.NodeType.LARGE)
	_icon_type_dropdown.select(0)
	top_row.add_child(_icon_type_dropdown)

	_path_input = LineEdit.new()
	_path_input.name = "PathInput"
	_path_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_input.placeholder_text = "No texture selected"
	_path_input.editable = false
	top_row.add_child(_path_input)

	_browse_button = Button.new()
	_browse_button.name = "BrowseBtn"
	_browse_button.text = "..."
	_browse_button.tooltip_text = "Browse texture"
	_browse_button.custom_minimum_size = Vector2(36, 0)
	top_row.add_child(_browse_button)

	_clear_button = Button.new()
	_clear_button.name = "ClearBtn"
	_clear_button.text = "X"
	_clear_button.tooltip_text = "Clear texture"
	_clear_button.custom_minimum_size = Vector2(30, 0)
	_clear_button.visible = false
	top_row.add_child(_clear_button)

	# === Icons list ===
	_icons_list = ItemList.new()
	_icons_list.name = "IconsList"
	_icons_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_icons_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_icons_list.custom_minimum_size = Vector2(0, 300)
	_icons_list.max_columns = 0
	_icons_list.same_column_width = true
	_icons_list.icon_mode = ItemList.ICON_MODE_TOP
	_icons_list.fixed_icon_size = Vector2i(64, 64)
	_icons_list.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vbox.add_child(_icons_list)

	# === Bottom row ===
	var bottom_row := HBoxContainer.new()
	bottom_row.name = "BottomRow"
	bottom_row.alignment = BoxContainer.ALIGNMENT_END
	bottom_row.add_theme_constant_override("separation", 6)
	vbox.add_child(bottom_row)

	_apply_button = Button.new()
	_apply_button.name = "ApplyBtn"
	_apply_button.text = "Apply"
	_apply_button.custom_minimum_size = Vector2(90, 0)
	bottom_row.add_child(_apply_button)

	_close_button = Button.new()
	_close_button.name = "CloseBtn"
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(90, 0)
	bottom_row.add_child(_close_button)

func _connect_signals() -> void:
	_browse_button.pressed.connect(_on_browse_pressed)
	_clear_button.pressed.connect(_on_clear_pressed)
	_icons_list.item_activated.connect(_on_icon_activated)
	_apply_button.pressed.connect(_on_apply_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	_icon_type_dropdown.item_selected.connect(_on_node_type_changed)

# ============================================================
# PUBLIC API
# ============================================================

func load_icons(node_type: int) -> void:
	if not editor or not editor.tree:
		return

	_current_node_type = node_type
	_icon_type_dropdown.select(node_type)

	_icons_list.clear()

	var icons_texture: Texture2D = editor.tree.icons.get(node_type, null)
	if not icons_texture:
		_path_input.text = ""
		_clear_button.visible = false
		return

	var icon_size: Vector2 = editor.tree.icon_sizes.get(node_type, Vector2.ZERO)
	if icon_size == Vector2.ZERO:
		return

	_texture_cache = icons_texture
	_icons_list.fixed_icon_size = Vector2i(int(icon_size.x), int(icon_size.y))
	_clear_button.visible = true
	_path_input.text = icons_texture.resource_path

	_populate_icons(icons_texture, icon_size)

# ============================================================
# PRIVATE
# ============================================================

func _populate_icons(texture: Texture2D, icon_size: Vector2) -> void:
	var columns: int = int(floor(texture.get_width() / icon_size.x))
	var rows: int = int(floor(texture.get_height() / icon_size.y))

	if columns <= 0 or rows <= 0:
		return

	var image: Image = texture.get_image()
	if image == null:
		return

	for y in rows:
		for x in columns:
			var region := Rect2(x * icon_size.x, y * icon_size.y, icon_size.x, icon_size.y)

			if _is_region_empty(image, region):
				continue

			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = region
			_icons_list.add_icon_item(atlas)

func _is_region_empty(image: Image, region: Rect2) -> bool:
	if image == null:
		return true

	var x_start: int = int(region.position.x)
	var y_start: int = int(region.position.y)
	var x_end: int = int(region.position.x + region.size.x)
	var y_end: int = int(region.position.y + region.size.y)

	for y in range(y_start, y_end):
		for x in range(x_start, x_end):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a > 0.01:
				return false
	return true

func _get_selected_region(texture: Texture2D) -> Vector2:
	var selected: PackedInt32Array = _icons_list.get_selected_items()
	if selected.is_empty():
		return Vector2.ZERO

	var index: int = selected[0]
	var icon_texture: Texture2D = _icons_list.get_item_icon(index)
	if icon_texture is AtlasTexture:
		return (icon_texture as AtlasTexture).region.position

	var icon_size: Vector2 = editor.tree.icon_sizes.get(_current_node_type, Vector2.ZERO)
	if icon_size == Vector2.ZERO:
		return Vector2.ZERO

	var columns: int = int(floor(texture.get_width() / icon_size.x))
	var x: int = (index % columns) * int(icon_size.x)
	var y: int = int(index / columns) * int(icon_size.y)
	return Vector2(x, y)

# ============================================================
# SIGNAL HANDLERS
# ============================================================

func _on_browse_pressed() -> void:
	hide()
	call_deferred("_open_texture_picker")

func _open_texture_picker() -> void:
	EditorInterface.popup_quick_open(_on_texture_picked, ["Texture2D"])

func _on_texture_picked(path: String) -> void:
	if path.is_empty():
		call_deferred("popup_centered")
		return
	if not editor or not editor.tree:
		call_deferred("popup_centered")
		return

	var texture: Texture2D = load(path) as Texture2D
	if not texture:
		call_deferred("popup_centered")
		return

	editor.tree.icons[_current_node_type] = texture
	_path_input.text = path
	_clear_button.visible = true

	load_icons(_current_node_type)

	if editor.has_method("set_dirty"):
		editor.set_dirty(true)

	call_deferred("popup_centered")

func _on_clear_pressed() -> void:
	if not editor or not editor.tree:
		return

	editor.tree.icons[_current_node_type] = null
	_path_input.text = ""
	_clear_button.visible = false
	_icons_list.clear()
	_texture_cache = null

	if editor.has_method("set_dirty"):
		editor.set_dirty(true)

func _on_icon_activated(index: int) -> void:
	_on_apply_pressed()

func _on_apply_pressed() -> void:
	if not _texture_cache:
		return
	if not editor or not editor.tree:
		return

	var selected: PackedInt32Array = _icons_list.get_selected_items()
	if selected.is_empty():
		return

	var region: Vector2 = _get_selected_region(_texture_cache)

	icon_selected.emit(_current_node_type, _texture_cache, region)
	hide()

func _on_close_pressed() -> void:
	hide()

func _on_node_type_changed(index: int) -> void:
	load_icons(index)