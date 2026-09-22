@tool
class_name BayterekLocalizationKeyRow
extends PanelContainer
## A single row in the Editor's key table.

signal value_changed(key: String, new_value: String)
signal row_selected(key: String)
signal navigate_requested(key: String, direction: int)
signal key_rename_requested(old_key: String, new_key: String)

const KEY_COLUMN_WIDTH := 200
const MIN_ORIGINAL_COL := 160
const MIN_TRANSLATION_COL := 200

const STATE_NORMAL := Color(0, 0, 0, 0)
const STATE_SELECTED := Color(0.3, 0.5, 0.8, 0.25)
const STATE_MISSING := Color(1.0, 0.85, 0.4, 0.10)          # yellow — same as original
const STATE_EMPTY := Color(1.0, 0.4, 0.4, 0.12)              # red — empty
const STATE_PLACEHOLDER_MISMATCH := Color(1.0, 0.55, 0.2, 0.15)  # orange
const STATE_BROKEN_REF := Color(1.0, 0.25, 0.3, 0.18)        # bright red — missing {@key}
const STATE_CYCLE := Color(0.75, 0.4, 1.0, 0.20)             # purple — cycle

const FormatHelper = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization_format_string.gd")

var key: String = ""
var original_value: String = ""
var translation_value: String = ""
var is_original_locale: bool = false

## Validation flags set by the Editor.
var _broken_ref: bool = false
var _cyclic: bool = false
var _cycle_path: Array[String] = []

var _key_input: LineEdit
var _original_label: Label
var _translation_field: BayterekLocalizationTranslationField
var _row_style: StyleBoxFlat
var _selected: bool = false
var _suppress_key_signal: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size.y = 30

	if not _row_style:
		_row_style = StyleBoxFlat.new()
		_row_style.bg_color = STATE_NORMAL
		_row_style.content_margin_left = 6
		_row_style.content_margin_right = 6
		_row_style.content_margin_top = 2
		_row_style.content_margin_bottom = 2
		add_theme_stylebox_override("panel", _row_style)

	if _key_input and not _key_input.text.is_empty():
		_apply_values()

func _build() -> void:
	if _key_input:
		return

	var hbox := HBoxContainer.new()
	hbox.name = "RowHBox"
	hbox.add_theme_constant_override("separation", 4)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(hbox)

	_key_input = LineEdit.new()
	_key_input.name = "KeyInput"
	_key_input.custom_minimum_size.x = KEY_COLUMN_WIDTH
	_key_input.size_flags_horizontal = Control.SIZE_FILL
	_key_input.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	var key_style := StyleBoxFlat.new()
	key_style.bg_color = Color(0.12, 0.14, 0.18, 0.5)
	key_style.content_margin_left = 6
	key_style.content_margin_right = 6
	key_style.content_margin_top = 2
	key_style.content_margin_bottom = 2
	key_style.set_corner_radius_all(2)
	_key_input.add_theme_stylebox_override("normal", key_style)
	_key_input.add_theme_stylebox_override("focus", key_style)
	_key_input.text_submitted.connect(_on_key_submitted)
	_key_input.focus_exited.connect(_on_key_focus_exited)
	hbox.add_child(_key_input)

	_original_label = Label.new()
	_original_label.name = "OriginalLabel"
	_original_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_original_label.size_flags_stretch_ratio = 1.0
	_original_label.custom_minimum_size.x = MIN_ORIGINAL_COL
	_original_label.clip_text = true
	_original_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_original_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	_original_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_original_label)

	_translation_field = BayterekLocalizationTranslationField.new()
	_translation_field.name = "TranslationField"
	_translation_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_translation_field.size_flags_stretch_ratio = 1.0
	_translation_field.custom_minimum_size.x = MIN_TRANSLATION_COL
	_translation_field.text_changed.connect(_on_field_changed)
	_translation_field.field_focus_entered.connect(_on_field_focus_entered)
	_translation_field.text_submitted.connect(_on_field_submitted)
	hbox.add_child(_translation_field)

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

## Called by the Editor to set validation state.
func set_validation_flags(broken_ref: bool, cyclic: bool, cycle_path: Array[String] = []) -> void:
	_broken_ref = broken_ref
	_cyclic = cyclic
	_cycle_path = cycle_path
	_update_row_style()

func get_translation() -> String:
	if not _translation_field:
		return translation_value
	return _translation_field.get_text()

func set_translation(value: String, emit_signal: bool = false) -> void:
	translation_value = value
	if _translation_field:
		_translation_field.set_text(value)
		if emit_signal:
			value_changed.emit(key, value)
	_update_row_style()

func set_row_selected(sel: bool) -> void:
	_selected = sel
	_update_row_style()

func focus_translation() -> void:
	if _translation_field:
		_translation_field.grab_focus_field()
		_translation_field.select_all()

func has_field_focus() -> bool:
	if _translation_field != null and _translation_field.has_field_focus():
		return true
	if _key_input != null and _key_input.has_focus():
		return true
	return false

func _apply_values() -> void:
	if not _key_input:
		return

	_suppress_key_signal = true
	_key_input.text = key
	_key_input.editable = is_original_locale
	if not is_original_locale:
		_key_input.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	else:
		_key_input.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_suppress_key_signal = false

	_original_label.text = original_value
	_original_label.visible = not is_original_locale

	if _translation_field:
		_translation_field.set_text(translation_value)

	_update_row_style()

# ============================================================
# STYLE / VALIDATION
# ============================================================

func _update_row_style() -> void:
	if not _row_style:
		return

	var bg: Color = STATE_NORMAL
	var tooltip: String = ""

	if _selected:
		bg = STATE_SELECTED
	else:
		var cur: String = get_translation()
		var trimmed: String = cur.strip_edges()

		if not is_original_locale:
			if _cyclic:
				bg = STATE_CYCLE
				if _cycle_path.size() > 0:
					tooltip = "Reference cycle: " + " → ".join(_cycle_path)
			elif _broken_ref:
				bg = STATE_BROKEN_REF
				tooltip = "Missing {@key} reference"
			elif trimmed.is_empty():
				bg = STATE_EMPTY
				tooltip = "Empty translation"
			elif _has_placeholder_mismatch():
				bg = STATE_PLACEHOLDER_MISMATCH
				tooltip = "Placeholder mismatch with original"
			elif cur == original_value:
				bg = STATE_MISSING
				tooltip = "Same as original"

	_row_style.bg_color = bg
	tooltip_text = tooltip
	queue_redraw()

func _has_placeholder_mismatch() -> bool:
	if is_original_locale:
		return false
	if original_value.is_empty():
		return false

	var cmp: Dictionary = FormatHelper.compare_placeholders(original_value, get_translation())
	var missing: PackedStringArray = cmp.get("missing", [])
	var extra: PackedStringArray = cmp.get("extra", [])
	return (not missing.is_empty()) or (not extra.is_empty())

# ============================================================
# SIGNAL HANDLERS
# ============================================================

func _on_field_changed() -> void:
	var new_text: String = _translation_field.get_text()
	translation_value = new_text
	_update_row_style()
	value_changed.emit(key, new_text)

func _on_field_focus_entered() -> void:
	row_selected.emit(key)

func _on_field_submitted(_text: String) -> void:
	navigate_requested.emit(key, 1)

func _on_key_submitted(new_key_text: String) -> void:
	_commit_key_rename(new_key_text)

func _on_key_focus_exited() -> void:
	if _key_input and _key_input.text != key:
		_commit_key_rename(_key_input.text)

func _commit_key_rename(new_key_text: String) -> void:
	if _suppress_key_signal:
		return
	if not is_original_locale:
		return

	var trimmed: String = new_key_text.strip_edges()
	if trimmed.is_empty() or trimmed == key:
		_suppress_key_signal = true
		_key_input.text = key
		_suppress_key_signal = false
		return

	key_rename_requested.emit(key, trimmed)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			row_selected.emit(key)
			accept_event()