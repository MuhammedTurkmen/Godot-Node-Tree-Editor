@tool
class_name BayterekLocalizationLanguageDialog
extends ConfirmationDialog
## Dialog for adding a new language (and optionally its first region).
##
## Uses the exact same pattern as Bayterek's delete dialog — no
## MarginContainer, direct VBoxContainer child with custom_minimum_size,
## min_size = Vector2i.ZERO, and reset_size() + size + popup_centered().

signal applied(language_code: String, region_code: String)

const Localization = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization.gd")

var _lang_dropdown: OptionButton
var _region_dropdown: OptionButton
var _hint_label: Label

var existing_language_codes: PackedStringArray = []

func _init() -> void:
	name = "AddLanguageDialog"
	title = "Add Language"
	ok_button_text = "Add"
	cancel_button_text = "Cancel"
	dialog_text = ""
	min_size = Vector2i.ZERO
	unresizable = true

	_build_ui()
	confirmed.connect(_on_confirmed)

func _build_ui() -> void:
	# Direct VBoxContainer as child — NO MarginContainer (Bayterek pattern).
	var vbox := VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.custom_minimum_size = Vector2(440, 140)
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# --- Language row ---
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 8)
	vbox.add_child(lang_row)

	var lang_label := Label.new()
	lang_label.text = "Language:"
	lang_label.custom_minimum_size = Vector2(90, 0)
	lang_row.add_child(lang_label)

	_lang_dropdown = OptionButton.new()
	_lang_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_row.add_child(_lang_dropdown)

	# --- Region row ---
	var region_row := HBoxContainer.new()
	region_row.add_theme_constant_override("separation", 8)
	vbox.add_child(region_row)

	var region_label := Label.new()
	region_label.text = "First region:"
	region_label.custom_minimum_size = Vector2(90, 0)
	region_label.tooltip_text = "Optional."
	region_row.add_child(region_label)

	_region_dropdown = OptionButton.new()
	_region_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	region_row.add_child(_region_dropdown)

	# --- Hint ---
	_hint_label = Label.new()
	_hint_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(440, 40)
	vbox.add_child(_hint_label)

func _populate_languages() -> void:
	_lang_dropdown.clear()

	for i in Localization.LANGUAGES.size():
		var entry: Dictionary = Localization.LANGUAGES[i]
		var code: String = entry.get("code", "")
		var name: String = entry.get("name", code)
		_lang_dropdown.add_item("%s  (%s)" % [name, code], i)
		_lang_dropdown.set_item_metadata(i, code)

		if existing_language_codes.has(code):
			_lang_dropdown.set_item_disabled(i, true)

	for i in _lang_dropdown.item_count:
		if not _lang_dropdown.is_item_disabled(i):
			_lang_dropdown.select(i)
			_on_language_changed(i)
			return

func _on_language_changed(_index: int) -> void:
	_rebuild_region_dropdown()
	_update_hint()

func _rebuild_region_dropdown() -> void:
	_region_dropdown.clear()
	_region_dropdown.add_item("(none — language itself is the locale)", 0)
	_region_dropdown.set_item_metadata(0, "")

	var lang_code: String = _get_selected_language_code()
	if lang_code.is_empty():
		return

	var regions: Array[Dictionary] = Localization.get_regions_for_language(lang_code)
	var idx: int = 1
	for reg in regions:
		var rcode: String = reg.get("code", "")
		var rname: String = reg.get("name", rcode)
		_region_dropdown.add_item("%s  (%s)" % [rname, rcode], idx)
		_region_dropdown.set_item_metadata(idx, rcode)
		idx += 1

	_region_dropdown.select(0)

func _update_hint() -> void:
	var lang_code: String = _get_selected_language_code()
	var region_code: String = _get_selected_region_code()

	if lang_code.is_empty():
		_hint_label.text = ""
		return

	var preview_locale: String = lang_code
	if not region_code.is_empty():
		preview_locale = "%s-%s" % [lang_code, region_code]

	_hint_label.text = "Will create locale:  %s\n→  %s/%s.json" % [
		preview_locale,
		Localization.get_languages_dir(),
		preview_locale,
	]

func _get_selected_language_code() -> String:
	var idx: int = _lang_dropdown.selected
	if idx < 0 or idx >= _lang_dropdown.item_count:
		return ""
	var meta = _lang_dropdown.get_item_metadata(idx)
	return "" if meta == null else String(meta)

func _get_selected_region_code() -> String:
	var idx: int = _region_dropdown.selected
	if idx < 0 or idx >= _region_dropdown.item_count:
		return ""
	var meta = _region_dropdown.get_item_metadata(idx)
	return "" if meta == null else String(meta)

# ============================================================
# PUBLIC API — Bayterek pattern
# ============================================================

func open(existing_codes: PackedStringArray) -> void:
	existing_language_codes = existing_codes
	_populate_languages()

	if _lang_dropdown.item_selected.is_connected(_on_language_changed):
		_lang_dropdown.item_selected.disconnect(_on_language_changed)
	_lang_dropdown.item_selected.connect(_on_language_changed)

	# Bayterek pattern: reset_size() + size + popup_centered() (no args).
	reset_size()
	size = Vector2i(500, 260)
	popup_centered()

func _on_confirmed() -> void:
	var lang_code: String = _get_selected_language_code()
	var region_code: String = _get_selected_region_code()
	if lang_code.is_empty():
		return
	applied.emit(lang_code, region_code)