@tool
class_name BayterekLocalizationKeyRow
extends PanelContainer
## A single CELL in the localization editor's 3-column table.
##
## The editor instantiates THREE cells per logical row:
##   - one for the key
##   - one for the original value
##   - one for the translation value
##
## Each cell is added to its own column VBox (key / original / translation).
## The editor then synchronises row heights by setting the same
## `custom_minimum_size.y` on all three cells of a logical row.
##
## This class no longer builds an internal HSplitContainer. The split
## is owned by the editor (`_table_split` / `_mid_split`).

signal value_changed(key: String, new_value: String)
signal row_selected(key: String)
signal navigate_requested(key: String, direction: int)
signal key_rename_requested(old_key: String, new_key: String)
signal value_edit_started(key: String, current_value: String)
signal value_edit_committed(key: String, new_value: String)

enum CellKind {
	KEY,
	ORIGINAL,
	TRANSLATION,
}

const MIN_ORIGINAL_COL := 140
const MIN_TRANSLATION_COL := 200

const STATE_NORMAL := Color(0, 0, 0, 0)
const STATE_SELECTED := Color(0.3, 0.5, 0.8, 0.25)
const STATE_MISSING := Color(1.0, 0.85, 0.4, 0.10)
const STATE_EMPTY := Color(1.0, 0.4, 0.4, 0.12)
const STATE_PLACEHOLDER_MISMATCH := Color(1.0, 0.55, 0.2, 0.15)
const STATE_BROKEN_REF := Color(1.0, 0.25, 0.3, 0.18)
const STATE_CYCLE := Color(0.75, 0.4, 1.0, 0.20)

const FormatHelper = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization_format_string.gd")

var key: String = ""
var original_value: String = ""
var translation_value: String = ""
var is_original_locale: bool = false

var _kind: CellKind = CellKind.KEY
var _broken_ref: bool = false
var _cyclic: bool = false
var _cycle_path: Array[String] = []

var _key_edit: TextEdit
var _original_label: Label
var _translation_field: BayterekLocalizationTranslationField
var _row_style: StyleBoxFlat
var _selected: bool = false
var _suppress_key_signal: bool = false

var _key_provider_callback: Callable = Callable()

# Row identifier — editor uses this to group cells of the same logical row.
var _row_id: String = ""

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

	if _kind == CellKind.KEY and _key_edit and not _key_edit.text.is_empty():
		_apply_values()
	elif _kind == CellKind.TRANSLATION and _translation_field:
		_translation_field.set_text(translation_value)

# ============================================================
# SETUP — editor calls this per-cell
# ============================================================

func setup_as_key(p_key: String, p_is_original: bool, p_row_id: String) -> void:
	_kind = CellKind.KEY
	key = p_key
	is_original_locale = p_is_original
	_row_id = p_row_id

	_build_key_cell()
	_apply_values()
	_update_row_style()

func setup_as_original(p_key: String, p_original: String, p_row_id: String) -> void:
	_kind = CellKind.ORIGINAL
	key = p_key
	original_value = p_original
	_row_id = p_row_id

	_build_original_cell()
	_apply_values()
	_update_row_style()

func setup_as_translation(p_key: String, p_original: String, p_translation: String, p_is_original: bool, p_row_id: String) -> void:
	_kind = CellKind.TRANSLATION
	key = p_key
	original_value = p_original
	translation_value = p_translation
	is_original_locale = p_is_original
	_row_id = p_row_id

	_build_translation_cell()
	_apply_values()
	_update_row_style()

func get_row_id() -> String:
	return _row_id

func get_kind() -> CellKind:
	return _kind

# ============================================================
# CELL BUILDERS
# ============================================================

func _build_key_cell() -> void:
	if _key_edit:
		return

	_key_edit = TextEdit.new()
	_key_edit.name = "KeyEdit"
	_key_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_key_edit.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_key_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_key_edit.scroll_fit_content_height = true
	_key_edit.scroll_vertical = 0
	_key_edit.scroll_horizontal = 0
	_key_edit.context_menu_enabled = true
	_key_edit.caret_blink = true
	_key_edit.gui_input.connect(_on_key_gui_input)
	_key_edit.focus_exited.connect(_on_key_focus_exited)
	_key_edit.text_changed.connect(_on_key_text_changed)
	add_child(_key_edit)

func _build_original_cell() -> void:
	if _original_label:
		return

	_original_label = Label.new()
	_original_label.name = "OriginalLabel"
	_original_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_original_label.size_flags_vertical = SIZE_EXPAND_FILL
	_original_label.custom_minimum_size.x = MIN_ORIGINAL_COL
	_original_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_original_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	_original_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_original_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_original_label)

func _build_translation_cell() -> void:
	if _translation_field:
		return

	_translation_field = BayterekLocalizationTranslationField.new()
	_translation_field.name = "TranslationField"
	_translation_field.size_flags_horizontal = SIZE_EXPAND_FILL
	_translation_field.custom_minimum_size.x = MIN_TRANSLATION_COL
	_translation_field.text_changed.connect(_on_field_changed)
	_translation_field.text_submitted.connect(_on_field_submitted)
	_translation_field.field_focus_entered.connect(_on_field_focus_entered)
	_translation_field.field_focus_exited.connect(_on_field_focus_exited)
	add_child(_translation_field)

	if _key_provider_callback.is_valid():
		_translation_field.set_key_provider(_key_provider_callback)

# ============================================================
# PUBLIC API
# ============================================================

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
	if _key_edit != null and _key_edit.has_focus():
		return true
	return false

func set_key_provider_callback(cb: Callable) -> void:
	_key_provider_callback = cb
	if _translation_field:
		_translation_field.set_key_provider(cb)

# ============================================================
# APPLY VALUES
# ============================================================

func _apply_values() -> void:
	if _kind == CellKind.KEY and _key_edit:
		_suppress_key_signal = true
		_key_edit.text = key
		_key_edit.editable = is_original_locale
		if not is_original_locale:
			_key_edit.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
		else:
			_key_edit.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		_suppress_key_signal = false

	if _kind == CellKind.ORIGINAL and _original_label:
		_original_label.text = original_value

	if _kind == CellKind.TRANSLATION and _translation_field:
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
	elif _kind == CellKind.TRANSLATION:
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

func _on_key_text_changed() -> void:
	if _suppress_key_signal:
		return
	var stripped: String = _key_edit.text.replace("\n", "").replace("\r", "")
	if stripped != _key_edit.text:
		var saved_col: int = _key_edit.get_caret_column()
		_suppress_key_signal = true
		_key_edit.text = stripped
		_suppress_key_signal = false
		_key_edit.set_caret_line(0)
		_key_edit.set_caret_column(mini(saved_col, stripped.length()))

func _on_key_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_commit_key_rename(_key_edit.text)
		accept_event()

func _on_key_focus_exited() -> void:
	if _key_edit and _key_edit.text != key:
		_commit_key_rename(_key_edit.text)

func _on_field_changed() -> void:
	var new_text: String = get_translation()
	translation_value = new_text
	value_changed.emit(key, new_text)

func _on_field_submitted(_new_text: String) -> void:
	navigate_requested.emit(key, 1)

func _on_field_focus_entered() -> void:
	row_selected.emit(key)
	value_edit_started.emit(key, get_translation())

func _on_field_focus_exited() -> void:
	_update_row_style()
	value_edit_committed.emit(key, get_translation())

func _commit_key_rename(new_key_text: String) -> void:
	if _suppress_key_signal:
		return
	if not is_original_locale:
		return

	var trimmed: String = new_key_text.strip_edges()
	if trimmed.is_empty() or trimmed == key:
		_suppress_key_signal = true
		_key_edit.text = key
		_suppress_key_signal = false
		return

	key_rename_requested.emit(key, trimmed)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			row_selected.emit(key)
			accept_event()