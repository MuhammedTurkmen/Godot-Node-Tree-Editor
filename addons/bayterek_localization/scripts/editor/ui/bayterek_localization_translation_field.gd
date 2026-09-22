@tool
class_name BayterekLocalizationTranslationField
extends TextEdit
## Single-line translation input with placeholder highlighting.
##
## TextEdit already declares a native `text_changed` signal (no args). We
## reuse that instead of declaring our own signal of the same name.
##
## Note: TextEdit's scrollbar properties are plain ints (0 = disabled).
## There is no SCROLL_MODE_* enum on TextEdit (that's ScrollContainer).

signal field_focus_entered
signal field_focus_exited
signal text_submitted(text: String)

const Highlighter = preload("res://addons/bayterek_localization/scripts/editor/ui/bayterek_localization_placeholder_highlighter.gd")

const MIN_HEIGHT := 24

var _updating: bool = false

# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	custom_minimum_size.y = MIN_HEIGHT
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_SHRINK_CENTER

	# Single-line behaviour.
	wrap_mode = TextEdit.LINE_WRAPPING_NONE
	scroll_fit_content_height = false
	scroll_horizontal = 0
	scroll_vertical = 0
	context_menu_enabled = true
	caret_blink = true
	caret_blink_interval = 0.5

	# Placeholder highlighting.
	syntax_highlighter = Highlighter.new()

	# Native TextEdit signals — reused, not redefined.
	text_changed.connect(_on_inner_text_changed)
	focus_entered.connect(_on_inner_focus_entered)
	focus_exited.connect(_on_inner_focus_exited)
	gui_input.connect(_on_inner_gui_input)

# ============================================================
# PUBLIC API
# ============================================================

func set_text(new_text: String) -> void:
	if _updating:
		return
	_updating = true
	text = new_text
	_updating = false
	set_caret_line(0)
	set_caret_column(text.length())

func get_text() -> String:
	return text.replace("\n", "").replace("\r", "")

func set_placeholder(p: String) -> void:
	placeholder_text = p

func grab_focus_field() -> void:
	grab_focus()

func select_all() -> void:
	super.select_all()

func set_editable(on: bool) -> void:
	editable = on

func is_editable() -> bool:
	return editable

func has_field_focus() -> bool:
	return has_focus()

# ============================================================
# INTERNAL
# ============================================================

func _on_inner_text_changed() -> void:
	if _updating:
		return

	# Strip any newlines that sneak in (paste, IME, etc.).
	var stripped: String = text.replace("\n", "").replace("\r", "")
	if stripped != text:
		var caret_col: int = get_caret_column()
		_updating = true
		text = stripped
		_updating = false
		set_caret_line(0)
		set_caret_column(min(caret_col, text.length()))

func _on_inner_focus_entered() -> void:
	field_focus_entered.emit()

func _on_inner_focus_exited() -> void:
	field_focus_exited.emit()

func _on_inner_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			text_submitted.emit(text)
			accept_event()