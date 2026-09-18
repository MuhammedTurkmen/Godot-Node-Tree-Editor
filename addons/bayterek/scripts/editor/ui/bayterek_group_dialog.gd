@tool
class_name BayterekGroupDialog
extends ConfirmationDialog
## Dialog for creating/editing a node group (name + color).

signal applied(group_name: String, group_color: Color)

var _name_input: LineEdit
var _color_picker: ColorPickerButton

func _init() -> void:
	title = "Node Group"
	ok_button_text = "Apply"
	cancel_button_text = "Cancel"
	unresizable = false

	_build_ui()

	confirmed.connect(_on_confirmed)

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.custom_minimum_size = Vector2(380, 0)
	margin.add_child(vbox)

	# --- Name ---
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	vbox.add_child(name_row)

	var name_label := Label.new()
	name_label.text = "Name:"
	name_label.custom_minimum_size = Vector2(70, 0)
	name_row.add_child(name_label)

	_name_input = LineEdit.new()
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.placeholder_text = "Group name"
	name_row.add_child(_name_input)

	# --- Color ---
	var color_row := HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 8)
	vbox.add_child(color_row)

	var color_label := Label.new()
	color_label.text = "Color:"
	color_label.custom_minimum_size = Vector2(70, 0)
	color_row.add_child(color_label)

	_color_picker = ColorPickerButton.new()
	_color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_color_picker.custom_minimum_size = Vector2(0, 28)
	color_row.add_child(_color_picker)

## Opens the dialog for creation or editing.
func open_for(group_name: String, group_color: Color) -> void:
	_name_input.text = group_name
	_color_picker.color = group_color

	popup_centered(Vector2i(420, 160))

	_name_input.call_deferred("grab_focus")
	_name_input.call_deferred("select_all")

func _on_confirmed() -> void:
	var final_name: String = _name_input.text.strip_edges()
	if final_name.is_empty():
		final_name = "Group"
	applied.emit(final_name, _color_picker.color)