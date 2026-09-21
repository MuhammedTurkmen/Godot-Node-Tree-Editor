@tool
class_name BayterekLocalizationKeyRow
extends PanelContainer
## A single row in the Editor's key table.
##
## Columns:
##   [ Key (fixed width) ] [ Original (flex) ] [ Translation (flex, editable) ]
##
## The translation field is a LineEdit. When the row represents the original
## locale, the "original" column is hidden and the "translation" LineEdit is
## actually editing the original value.

signal value_changed(key: String, new_value: String)
signal row_selected(key: String)

const KEY_COLUMN_WIDTH := 220
const STATE_NORMAL := Color(0, 0, 0, 0)
const STATE_SELECTED := Color(0.3, 0.5, 0.8, 0.25)
const STATE_MISSING := Color(1.0, 0.85, 0.4, 0.10)
const STATE_EMPTY := Color(1.0, 0.4, 0.4, 0.12)

var key: String = ""
var original_value: String = ""
var translation_value: String = ""
var is_original_locale: bool = false

var _key_label: Label
var _original_label: Label
var _translation_input: LineEdit
var _row_style: StyleBoxFlat
var _selected: bool = false

# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size.y = 26

	if not _row_style:
		_row_style = StyleBoxFlat.new()
		_row_style.bg_color = STATE_NORMAL
		_row_style.content_margin_left = 6
		_row_style.content_margin_right = 6
		_row_style.content_margin_top = 2
		_row_style.content_margin_bottom = 2
		add_theme_stylebox_override("panel", _row_style)

	if _key_label and not _key_label.text.is_empty():
		_apply_values()

func _build() -> void:
	if _key_label:
		return

	var hbox := HBoxContainer.new()
	hbox.name = "RowHBox"
	hbox.add_theme_constant_override("separation", 4)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(hbox)

	# --- Key column (read-only) ---
	_key_label = Label.new()
	_key_label.name = "KeyLabel"
	_key_label.custom_minimum_size.x = KEY_COLUMN_WIDTH
	_key_label.size_flags_horizontal = Control.SIZE_FILL
	_key_label.clip_text = true
	_key_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_key_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_key_label)

	# --- Original column (read-only, dimmed) ---
	_original_label = Label.new()
	_original_label.name = "OriginalLabel"
	_original_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_original_label.size_flags_stretch_ratio = 1.0
	_original_label.clip_text = true
	_original_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_original_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	_original_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_original_label)

	# --- Translation column (editable) ---
	_translation_input = LineEdit.new()
	_translation_input.name = "TranslationInput"
	_translation_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_translation_input.size_flags_stretch_ratio = 1.0
	_translation_input.placeholder_text = ""
	_translation_input.text_changed.connect(_on_text_changed)
	_translation_input.focus_entered.connect(_on_focus_entered)
	hbox.add_child(_translation_input)

# ============================================================
# PUBLIC API
# ============================================================

func setup(p_key: String, p_original: String, p_translation: String, p_is_original: bool) -> void:
	key = p_key
	original_value = p_original
	translation_value = p_translation
	is_original_locale = p_is_original

	_build()
	_apply_values()

func get_translation() -> String:
	if not _translation_input:
		return translation_value
	return _translation_input.text

func set_translation(value: String, emit_signal: bool = false) -> void:
	translation_value = value
	if _translation_input:
		_translation_input.set_text(value)
		if emit_signal:
			value_changed.emit(key, value)
	_update_row_style()

func set_row_selected(sel: bool) -> void:
	_selected = sel
	_update_row_style()

func focus_translation() -> void:
	if _translation_input:
		_translation_input.grab_focus()
		_translation_input.select_all()

func _apply_values() -> void:
	if not _key_label:
		return

	_key_label.text = key
	_original_label.text = original_value
	_original_label.visible = not is_original_locale

	if _translation_input:
		_translation_input.text = translation_value
		_translation_input.editable = true

	_update_row_style()

# ============================================================
# STYLE LOGIC
# ============================================================

func _update_row_style() -> void:
	if not _row_style:
		return

	var bg: Color = STATE_NORMAL

	if _selected:
		bg = STATE_SELECTED
	else:
		# Missing / empty translation warnings
		var cur: String = get_translation()
		if cur.strip_edges().is_empty():
			# Empty — red-ish
			bg = STATE_EMPTY if not is_original_locale else STATE_NORMAL
		elif not is_original_locale and cur == original_value:
			# Same as original — yellow-ish
			bg = STATE_MISSING

	_row_style.bg_color = bg
	queue_redraw()

# ============================================================
# SIGNAL HANDLERS
# ============================================================

func _on_text_changed(new_text: String) -> void:
	translation_value = new_text
	_update_row_style()
	value_changed.emit(key, new_text)

func _on_focus_entered() -> void:
	row_selected.emit(key)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			row_selected.emit(key)
			accept_event()