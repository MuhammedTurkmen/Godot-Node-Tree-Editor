@tool
class_name BayterekPrefabCard
extends PanelContainer
## Prefab card for the prefab bar.
## Shows a design thumbnail + name. Drag source for the tree canvas.

signal rename_requested(prefab: BayterekPrefab)
signal duplicate_requested(prefab: BayterekPrefab)
signal delete_requested(prefab: BayterekPrefab)

const CARD_WIDTH := 80
const CARD_HEIGHT := 100
const THUMB_SIZE := Vector2(64, 64)

var prefab: BayterekPrefab = null
var editor: BayterekEditor = null

var _thumbnail: BayterekPrefabThumbnail
var _name_label: Label

func _init() -> void:
	custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	size_flags_vertical = SIZE_SHRINK_CENTER

var _style_normal: StyleBoxFlat
var _style_hover: StyleBoxFlat
var _style_pressed: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_styles()
	_build_ui()
	_apply_style(_style_normal)

	mouse_entered.connect(func(): _apply_style(_style_hover))
	mouse_exited.connect(func(): _apply_style(_style_normal))

func _build_styles() -> void:
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.15, 0.15, 0.18, 0.9)
	_style_normal.border_color = Color(0.3, 0.3, 0.35, 0.9)
	_style_normal.set_border_width_all(1)
	_style_normal.set_corner_radius_all(3)
	_style_normal.content_margin_left = 4
	_style_normal.content_margin_right = 4
	_style_normal.content_margin_top = 4
	_style_normal.content_margin_bottom = 4

	_style_hover = _style_normal.duplicate()
	_style_hover.bg_color = Color(0.2, 0.22, 0.28, 0.95)
	_style_hover.border_color = Color(0.5, 0.7, 1.0, 0.9)

	_style_pressed = _style_normal.duplicate()
	_style_pressed.bg_color = Color(0.25, 0.3, 0.4, 1.0)
	_style_pressed.border_color = Color(0.6, 0.8, 1.0, 1.0)

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	_thumbnail = BayterekPrefabThumbnail.new()
	_thumbnail.custom_minimum_size = THUMB_SIZE
	_thumbnail.size_flags_horizontal = SIZE_EXPAND_FILL
	_thumbnail.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(_thumbnail)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.add_theme_font_size_override("font_size", 11)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_name_label)

# ============================================================
# PUBLIC
# ============================================================

func set_prefab(p: BayterekPrefab, ed: BayterekEditor) -> void:
	prefab = p
	editor = ed

	if not prefab:
		return

	_name_label.text = prefab.node_name if not prefab.node_name.is_empty() else "(unnamed)"

	# Design'ı registry'den çöz
	var design: BayterekNodeDesign = null
	if not prefab.design_id.is_empty():
		var reg = Bayterek.get_designs_registry()
		if reg:
			design = reg.get_design_by_id(prefab.design_id)

	_thumbnail.set_design(design)

# ============================================================
# DRAG SOURCE
# ============================================================

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not prefab:
		return null

	# Preview: kart'ın küçük bir kopyası
	var preview := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 0.9)
	style.border_color = Color(0.6, 0.8, 1.0, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	preview.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = prefab.node_name
	lbl.add_theme_font_size_override("font_size", 11)
	preview.add_child(lbl)

	set_drag_preview(preview)

	# `_drop_data` bunu alır (BayterekTreeView._drag_can_drop bunu tanır)
	return {
		"type": "prefab",
		"prefab": prefab,
	}

# ============================================================
# MOUSE INPUT
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_apply_style(_style_pressed)
			await get_tree().create_timer(0.1).timeout
			if is_instance_valid(self):
				_apply_style(_style_hover)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_show_context_menu(event.global_position)
			accept_event()

func _apply_style(s: StyleBoxFlat) -> void:
	add_theme_stylebox_override("panel", s)

# ============================================================
# CONTEXT MENU
# ============================================================

func _show_context_menu(global_pos: Vector2) -> void:
	if not prefab:
		return

	var menu := PopupMenu.new()
	menu.add_item("Rename...", 0)
	menu.add_item("Duplicate", 1)
	menu.add_separator()
	menu.add_item("Delete", 2)

	menu.id_pressed.connect(func(id: int):
		match id:
			0: rename_requested.emit(prefab)
			1: duplicate_requested.emit(prefab)
			2: delete_requested.emit(prefab)
		menu.queue_free()
	)

	add_child(menu)
	menu.position = Vector2i(global_pos)
	menu.popup()