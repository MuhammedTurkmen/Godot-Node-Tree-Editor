@tool
class_name BayterekLocalizationTranslationField
extends TextEdit
## DEBUG BUILD — caret sorununu tespit etmek için.
## TextEdit + SyntaxHighlighter kullanıyor (renkler için).

signal field_focus_entered
signal field_focus_exited
signal text_submitted(text: String)

const Highlighter = preload("res://addons/bayterek_localization/scripts/editor/ui/bayterek_localization_placeholder_highlighter.gd")

const MIN_HEIGHT := 24

var _updating: bool = false
var _has_focus_tracked: bool = false

# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	custom_minimum_size.y = MIN_HEIGHT
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_SHRINK_CENTER

	wrap_mode = TextEdit.LINE_WRAPPING_NONE
	scroll_fit_content_height = false
	scroll_horizontal = 0
	scroll_vertical = 0
	context_menu_enabled = true
	caret_blink = true
	caret_blink_interval = 0.5

	syntax_highlighter = Highlighter.new()

	text_changed.connect(_on_inner_text_changed)
	focus_entered.connect(_on_inner_focus_entered)
	focus_exited.connect(_on_inner_focus_exited)
	gui_input.connect(_on_inner_gui_input)

	print("[TF:", name, "] _ready() — TextEdit + Highlighter")

# ============================================================
# PUBLIC API
# ============================================================

func set_text(new_text: String) -> void:
	print("[TF:", name, "] set_text('", new_text, "') caret_before=", get_caret_column())
	if _updating:
		print("[TF:", name, "]   -> SKIP (_updating)")
		return
	var current: String = text
	if current == new_text:
		print("[TF:", name, "]   -> SKIP (same)")
		return

	var saved_line: int = get_caret_line()
	var saved_col: int = get_caret_column()

	_updating = true
	text = new_text
	_updating = false

	if _has_focus_tracked:
		var line_count: int = get_line_count()
		var line: int = clampi(saved_line, 0, max(0, line_count - 1))
		var col: int = clampi(saved_col, 0, get_line(line).length())
		set_caret_line(line)
		set_caret_column(col)
		print("[TF:", name, "]   -> restored caret to ", line, ":", col)
	else:
		set_caret_line(0)
		set_caret_column(text.length())
		print("[TF:", name, "]   -> caret to END (", text.length(), ")")

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
	return _has_focus_tracked

# ============================================================
# INTERNAL — TEXT CHANGE
# ============================================================

func _on_inner_text_changed() -> void:
	if _updating:
		return

	var stripped: String = text.replace("\n", "").replace("\r", "")

	# DEBUG: her text_changed'de caret ve text'i yaz.
	print("[TF:", name, "] text_changed. caret=", get_caret_column(), " text='", text, "'")

	if stripped == text:
		return

	print("[TF:", name, "]   -> STRIPPING newlines")

	var saved_line: int = get_caret_line()
	var saved_col: int = get_caret_column()

	_updating = true
	text = stripped
	_updating = false

	var line_count: int = get_line_count()
	var line: int = clampi(saved_line, 0, max(0, line_count - 1))
	var col: int = clampi(saved_col, 0, get_line(line).length())
	set_caret_line(line)
	set_caret_column(col)

# ============================================================
# INTERNAL — FOCUS
# ============================================================

func _on_inner_focus_entered() -> void:
	print("[TF:", name, "] focus_entered. caret=", get_caret_column())
	_has_focus_tracked = true
	field_focus_entered.emit()

func _on_inner_focus_exited() -> void:
	print("[TF:", name, "] focus_exited. caret=", get_caret_column())
	_has_focus_tracked = false
	field_focus_exited.emit()

# ============================================================
# INTERNAL — INPUT
# ============================================================

func _on_inner_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			text_submitted.emit(text)
			accept_event()