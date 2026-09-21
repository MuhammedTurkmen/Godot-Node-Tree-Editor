@tool
class_name BayterekLocalizationRegionDialog
extends ConfirmationDialog
## Dialog for adding a new region. Bayterek pattern.

signal applied(language_code: String, region_code: String)

const Localization = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization.gd")

var _region_dropdown: OptionButton
var _hint_label: Label

var _language_code: String = ""
var existing_region_codes: PackedStringArray = []

func _init() -> void:
	name = "AddRegionDialog"
	title = "Add Region"
	ok_button_text = "Add"
	cancel_button_text = "Cancel"
	dialog_text = ""
	min_size = Vector2i.ZERO
	unresizable = true

	_build_ui()
	confirmed.connect(_on_confirmed)

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.custom_minimum_size = Vector2(440, 110)
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	var region_row := HBoxContainer.new()
	region_row.add_theme_constant_override("separation", 8)
	vbox.add_child(region_row)

	var region_label := Label.new()
	region_label.text = "Region:"
	region_label.custom_minimum_size = Vector2(90, 0)
	region_row.add_child(region_label)

	_region_dropdown = OptionButton.new()
	_region_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	region_row.add_child(_region_dropdown)

	_hint_label = Label.new()
	_hint_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(440, 40)
	vbox.add_child(_hint_label)

func _populate_regions() -> void:
	_region_dropdown.clear()

	var regions: Array[Dictionary] = Localization.get_regions_for_language(_language_code)
	var idx: int = 0
	var first_enabled: int = -1
	for reg in regions:
		var rcode: String = reg.get("code", "")
		var rname: String = reg.get("name", rcode)
		_region_dropdown.add_item("%s  (%s)" % [rname, rcode], idx)
		_region_dropdown.set_item_metadata(idx, rcode)
		if existing_region_codes.has(rcode):
			_region_dropdown.set_item_disabled(idx, true)
		elif first_enabled == -1:
			first_enabled = idx
		idx += 1

	if first_enabled >= 0:
		_region_dropdown.select(first_enabled)

	_update_hint()

func _update_hint() -> void:
	var region_code: String = _get_selected_region_code()
	if region_code.is_empty() or _language_code.is_empty():
		_hint_label.text = ""
		return

	var locale: String = "%s-%s" % [_language_code, region_code]
	_hint_label.text = "Will create locale:  %s\n→  %s/%s.json" % [
		locale,
		Localization.get_languages_dir(),
		locale,
	]

func _get_selected_region_code() -> String:
	var idx: int = _region_dropdown.selected
	if idx < 0 or idx >= _region_dropdown.item_count:
		return ""
	var meta = _region_dropdown.get_item_metadata(idx)
	return "" if meta == null else String(meta)

# ============================================================
# PUBLIC API — Bayterek pattern
# ============================================================

func open(language_code: String, existing_codes: PackedStringArray) -> void:
	_language_code = language_code
	existing_region_codes = existing_codes
	_populate_regions()

	if _region_dropdown.item_selected.is_connected(_on_region_changed):
		_region_dropdown.item_selected.disconnect(_on_region_changed)
	_region_dropdown.item_selected.connect(_on_region_changed)

	reset_size()
	size = Vector2i(500, 230)
	popup_centered()

func _on_region_changed(_index: int) -> void:
	_update_hint()

func _on_confirmed() -> void:
	var region_code: String = _get_selected_region_code()
	if region_code.is_empty():
		return
	applied.emit(_language_code, region_code)