@tool
class_name BayterekExportHelper
extends RefCounted
## Helper for making a UI row "exportable to prefab".

const MARKER_TEXT := "◆"
const MARKER_COLOR := Color(1.0, 0.85, 0.35)
const MARKER_SIZE := 14

static func make_exportable(
	row: Control,
	field_path: String,
	design: BayterekNodeDesign,
	on_changed: Callable = Callable()
) -> void:
	if not row or field_path.is_empty():
		return

	# Guard: if this row was already set up, do nothing. Prevents
	# "Signal 'gui_input' is already connected" errors when the detail
	# form is rebuilt multiple times.
	if row.has_meta("__export_field_path"):
		# Still refresh the design reference and marker state.
		row.set_meta("__export_design", design)
		_refresh_marker(row)
		return

	# Marker Label at the end
	var marker := Label.new()
	marker.name = "__export_marker"
	marker.text = MARKER_TEXT
	marker.custom_minimum_size = Vector2(MARKER_SIZE, 0)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.add_theme_color_override("font_color", MARKER_COLOR)
	marker.add_theme_font_size_override("font_size", 10)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.visible = false
	row.add_child(marker)

	# Context menu
	var menu := PopupMenu.new()
	menu.name = "__export_menu"
	menu.add_item("Export to Prefab", 0)
	menu.add_item("Remove Export", 1)
	row.add_child(menu)

	row.set_meta("__export_field_path", field_path)
	row.set_meta("__export_design", design)
	row.set_meta("__export_marker", marker)
	row.set_meta("__export_menu", menu)
	row.set_meta("__export_on_changed", on_changed)

	row.gui_input.connect(_on_row_gui_input.bind(row))
	menu.id_pressed.connect(_on_menu_pressed.bind(row))

	_refresh_marker(row)

static func _on_row_gui_input(event: InputEvent, row: Control) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_RIGHT or not event.pressed:
		return

	if not row.has_meta("__export_menu"):
		return
	if not row.has_meta("__export_field_path"):
		return

	var design: BayterekNodeDesign = row.get_meta("__export_design", null)
	var menu: PopupMenu = row.get_meta("__export_menu", null)
	var field_path: String = row.get_meta("__export_field_path", "")

	if not menu or field_path.is_empty():
		return

	var exported: bool = false
	if design:
		exported = design.is_field_exported(field_path)

	menu.set_item_disabled(0, exported or design == null)
	menu.set_item_disabled(1, not exported)

	menu.position = Vector2i(row.get_screen_position() + event.position)
	menu.popup()
	row.accept_event()

static func _on_menu_pressed(id: int, row: Control) -> void:
	if not row.has_meta("__export_field_path"):
		return

	var design: BayterekNodeDesign = row.get_meta("__export_design", null)
	var field_path: String = row.get_meta("__export_field_path", "")
	var on_changed: Callable = row.get_meta("__export_on_changed", Callable())

	if not design or field_path.is_empty():
		return

	match id:
		0:
			design.set_field_exported(field_path, true)
		1:
			design.set_field_exported(field_path, false)

	_refresh_marker(row)

	if on_changed.is_valid():
		on_changed.call(field_path)

static func _refresh_marker(row: Control) -> void:
	if not row.has_meta("__export_marker"):
		return
	if not row.has_meta("__export_field_path"):
		return

	var design: BayterekNodeDesign = row.get_meta("__export_design", null)
	var field_path: String = row.get_meta("__export_field_path", "")
	var marker: Label = row.get_meta("__export_marker", null)

	if not marker or field_path.is_empty():
		return

	if design and design.is_field_exported(field_path):
		marker.visible = true
	else:
		marker.visible = false

static func rebind_design(row: Control, design: BayterekNodeDesign) -> void:
	if not row:
		return
	row.set_meta("__export_design", design)
	_refresh_marker(row)

static func refresh_row(row: Control) -> void:
	if not row:
		return
	_refresh_marker(row)