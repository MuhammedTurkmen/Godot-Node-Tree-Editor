@tool
class_name BayterekLocalizationKeyRow
extends PanelContainer
## A single row in the Editor's key table.

signal value_changed(key: String, new_value: String)
signal row_selected(key: String)
signal navigate_requested(key: String, direction: int)

const KEY_COLUMN_WIDTH := 220
const STATE_NORMAL := Color(0, 0, 0, 0)
const STATE_SELECTED := Color(0.3, 0.5, 0.8, 0.25)
const STATE_MISSING := Color(1.0, 0.85, 0.4, 0.10)
const STATE_EMPTY := Color(1.0, 0.4, 0.4, 0.12)
const STATE_PLACEHOLDER_MISMATCH := Color(1.0, 0.55, 0.2, 0.15)

const FormatHelper = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization_format_string.gd")

var key: String = ""
var original_value: String = ""
var translation_value: String = ""
var is_original_locale: bool = false

var _key_label: Label
var _original_label: Label
var _translation_field: BayterekLocalizationTranslationField
var _row_style: StyleBoxFlat
var _selected: bool = false

# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size.y = 28

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

	# --- Key column ---
	_key_label = Label.new()
	_key_label.name = "KeyLabel"
	_key_label.custom_minimum_size.x = KEY_COLUMN_WIDTH
	_key_label.size_flags_horizontal = Control.SIZE_FILL
	_key_label.clip_text = true
	_key_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_key_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_key_label)

	# --- Original column ---
	_original_label = Label.new()
	_original_label.name = "OriginalLabel"
	_original_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_original_label.size_flags_stretch_ratio = 1.0
	_original_label.clip_text = true
	_original_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_original_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	_original_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_original_label)

	# --- Translation field ---
	_translation_field = BayterekLocalizationTranslationField.new()
	_translation_field.name = "TranslationField"
	_translation_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_translation_field.size_flags_stretch_ratio = 1.0
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
	return _translation_field != null and _translation_field.has_field_focus()

func _apply_values() -> void:
	if not _key_label:
		return

	_key_label.text = key
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

	if _selected:
		bg = STATE_SELECTED
	else:
		var cur: String = get_translation()
		var trimmed: String = cur.strip_edges()

		if not is_original_locale:
			if trimmed.is_empty():
				bg = STATE_EMPTY
			elif _has_placeholder_mismatch():
				bg = STATE_PLACEHOLDER_MISMATCH
			elif cur == original_value:
				bg = STATE_MISSING

	_row_style.bg_color = bg
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

func _on_field_changed(new_text: String) -> void:
	translation_value = new_text
	_update_row_style()
	value_changed.emit(key, new_text)

func _on_field_focus_entered() -> void:
	row_selected.emit(key)

func _on_field_submitted(_text: String) -> void:
	navigate_requested.emit(key, 1)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			row_selected.emit(key)
			accept_event()