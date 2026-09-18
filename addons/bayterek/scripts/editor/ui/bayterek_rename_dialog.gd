@tool
class_name BayterekRenameDialog
extends ConfirmationDialog
## Dialog for renaming + editing a node's description.
##
## Layout:
##   ┌─────────────────────────────────┐
##   │  Edit Node                      │
##   ├─────────────────────────────────┤
##   │  Name:      [...............]   │
##   │                                 │
##   │  Description:                   │
##   │  ┌───────────────────────────┐  │
##   │  │                           │  │
##   │  │                           │  │
##   │  └───────────────────────────┘  │
##   │                                 │
##   │              [Cancel] [Apply]   │
##   └─────────────────────────────────┘

signal applied(new_name: String, new_description: String)

var _name_input: LineEdit
var _description_input: TextEdit

func _init() -> void:
	title = "Edit Node"
	ok_button_text = "Apply"
	cancel_button_text = "Cancel"
	unresizable = false

	_build_ui()

	confirmed.connect(_on_confirmed)
	canceled.connect(_on_canceled)

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.custom_minimum_size = Vector2(420, 0)
	margin.add_child(vbox)

	# --- Name row ---
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	vbox.add_child(name_row)

	var name_label := Label.new()
	name_label.text = "Name:"
	name_label.custom_minimum_size = Vector2(90, 0)
	name_row.add_child(name_label)

	_name_input = LineEdit.new()
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.placeholder_text = "Node name"
	name_row.add_child(_name_input)

	# --- Description label ---
	var desc_label := Label.new()
	desc_label.text = "Description:"
	vbox.add_child(desc_label)

	# --- Description input ---
	_description_input = TextEdit.new()
	_description_input.custom_minimum_size = Vector2(0, 120)
	_description_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_description_input.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_description_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_description_input.placeholder_text = "Optional description"
	vbox.add_child(_description_input)

	# Tab navigation: name → description
	_name_input.text_submitted.connect(func(_t: String): _description_input.grab_focus())

## Opens the dialog with the given name and description prefilled.
## The dialog is centered and the name field is focused + selected.
func open_for(node_name: String, node_description: String) -> void:
	_name_input.text = node_name
	_description_input.text = node_description

	popup_centered(Vector2i(440, 280))

	# Focus name field and select all text so typing replaces it.
	_name_input.call_deferred("grab_focus")
	_name_input.call_deferred("select_all")

func _on_confirmed() -> void:
	var name_text: String = _name_input.text.strip_edges()
	var desc_text: String = _description_input.text.strip_edges()
	applied.emit(name_text, desc_text)

func _on_canceled() -> void:
	pass

func _input(event: InputEvent) -> void:
	# Escape cancels — ConfirmationDialog usually does this, but if
	# focus is inside the TextEdit, Escape might be swallowed.
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			hide()
			get_viewport().set_input_as_handled()