@tool
class_name BayterekLocalizationImportExportDialog
extends ConfirmationDialog
## Import / Export CSV dialog for the Localization editor.
##
## Çözüm: Preview içeriğini popup'tan SONRA yaz. İlk frame'de RichTextLabel
## boş kalır, content_min doğru hesaplanır, popup 760×560 olarak açılır.

signal export_completed(path: String)
signal import_completed(imported_count: int)

const Localization = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization.gd")
const Service = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization_service.gd")
const CSV = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization_csv.gd")

enum Mode { EXPORT, IMPORT }

const DIALOG_W := 760
const DIALOG_H := 560
const PREVIEW_HEIGHT := 240

## Default export/import klasörü — user:// altında otomatik oluşturulur.
const DEFAULT_USER_DIR := "user://localization"
const DEFAULT_EXPORT_FILENAME := "localization_export.csv"

var _mode: int = Mode.EXPORT
var _path_input: LineEdit
var _info_label: Label
var _preview_label: RichTextLabel
var _include_empty_check: CheckBox
var _include_original_check: CheckBox

var _registry: LocalizationRegistry = null
var _content_vbox: VBoxContainer = null

var _file_dialog: FileDialog = null

# ============================================================
# LIFECYCLE
# ============================================================

func _init() -> void:
	name = "LocalizationImportExportDialog"
	title = "Export CSV"
	ok_button_text = "Export"
	cancel_button_text = "Cancel"
	dialog_text = ""
	min_size = Vector2i.ZERO
	unresizable = true

	_build_ui()
	confirmed.connect(_on_confirmed)

func _build_ui() -> void:
	_content_vbox = VBoxContainer.new()
	_content_vbox.name = "ContentVBox"
	_content_vbox.custom_minimum_size = Vector2(700, 0)
	_content_vbox.add_theme_constant_override("separation", 8)
	add_child(_content_vbox)

	# --- Path row ---
	var path_row := HBoxContainer.new()
	path_row.add_theme_constant_override("separation", 6)
	_content_vbox.add_child(path_row)

	var path_lbl := Label.new()
	path_lbl.text = "File:"
	path_lbl.custom_minimum_size.x = 50
	path_row.add_child(path_lbl)

	_path_input = LineEdit.new()
	_path_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_input.placeholder_text = "user://localization/localization_export.csv"
	_path_input.text_changed.connect(_on_path_changed)
	path_row.add_child(_path_input)

	var browse_btn := Button.new()
	browse_btn.text = "Browse..."
	browse_btn.tooltip_text = "Masaüstü veya başka bir klasör seç"
	browse_btn.pressed.connect(_on_browse_pressed)
	path_row.add_child(browse_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Reset"
	reset_btn.tooltip_text = "Default yola dön (user://localization/)"
	reset_btn.pressed.connect(_on_reset_path_pressed)
	path_row.add_child(reset_btn)

	var copy_btn := Button.new()
	copy_btn.text = "Copy"
	copy_btn.tooltip_text = "Copy path to clipboard"
	copy_btn.pressed.connect(_on_copy_path_pressed)
	path_row.add_child(copy_btn)

	# --- Info ---
	_info_label = Label.new()
	_info_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 11)
	_content_vbox.add_child(_info_label)

	# --- Options row ---
	var options_row := HBoxContainer.new()
	options_row.add_theme_constant_override("separation", 12)
	_content_vbox.add_child(options_row)

	_include_original_check = CheckBox.new()
	_include_original_check.text = "Include original locale first"
	_include_original_check.button_pressed = true
	options_row.add_child(_include_original_check)

	_include_empty_check = CheckBox.new()
	_include_empty_check.text = "Include keys with empty values"
	_include_empty_check.button_pressed = true
	_include_empty_check.toggled.connect(_on_option_toggled)
	options_row.add_child(_include_empty_check)

	_content_vbox.add_child(HSeparator.new())

	var preview_lbl := Label.new()
	preview_lbl.text = "Preview:"
	preview_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	preview_lbl.add_theme_font_size_override("font_size", 11)
	_content_vbox.add_child(preview_lbl)

	# RichTextLabel — fit_content = false.
	_preview_label = RichTextLabel.new()
	_preview_label.bbcode_enabled = false
	_preview_label.fit_content = false
	_preview_label.scroll_active = true
	_preview_label.selection_enabled = true
	_preview_label.custom_minimum_size = Vector2(0, PREVIEW_HEIGHT)
	_preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_label.size_flags_vertical = Control.SIZE_FILL
	_preview_label.add_theme_font_size_override("normal_font_size", 11)
	_content_vbox.add_child(_preview_label)

# ============================================================
# PUBLIC API
# ============================================================

func open_export(registry: LocalizationRegistry, default_path: String = "") -> void:
	_mode = Mode.EXPORT
	_registry = registry
	title = "Export CSV"
	ok_button_text = "Export"
	_path_input.text = default_path if not default_path.is_empty() else _get_default_path()
	_info_label.text = "Export all locales to a single CSV file.\nEach locale becomes a column. Original locale first."
	_include_original_check.visible = true
	_include_empty_check.visible = true
	_preview_label.text = ""
	_popup_then_refresh.call_deferred()

func open_import(registry: LocalizationRegistry, default_path: String = "") -> void:
	_mode = Mode.IMPORT
	_registry = registry
	title = "Import CSV"
	ok_button_text = "Import"
	_path_input.text = default_path if not default_path.is_empty() else _get_default_path()
	_info_label.text = "Import translations from a CSV file.\nNew keys are added to the original locale. Existing keys are updated. Missing keys are preserved."
	_include_original_check.visible = false
	_include_empty_check.visible = false
	_preview_label.text = ""
	_popup_then_refresh.call_deferred()

## Default path — user://localization/localization_export.csv
## Klasör otomatik oluşturulur.
func _get_default_path() -> String:
	_ensure_default_dir()
	return "%s/%s" % [DEFAULT_USER_DIR, DEFAULT_EXPORT_FILENAME]

## user://localization/ klasörü yoksa oluştur.
func _ensure_default_dir() -> void:
	var global_path: String = ProjectSettings.globalize_path(DEFAULT_USER_DIR)
	if not DirAccess.dir_exists_absolute(global_path):
		var err: Error = DirAccess.make_dir_recursive_absolute(global_path)
		if err != OK:
			push_warning("Localization: could not create default dir: %s (err=%d)" % [global_path, err])

## Popup'ı doğru boyutta aç, SONRA preview'ı doldur.
func _popup_then_refresh() -> void:
	if not visible:
		show()
		await get_tree().process_frame

	popup_centered(Vector2i(DIALOG_W, DIALOG_H))

	await get_tree().process_frame
	_refresh_preview()

# ============================================================
# PATH BUTTONS
# ============================================================

func _on_browse_pressed() -> void:
	if not _file_dialog:
		_file_dialog = FileDialog.new()
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.use_native_dialog = true
		_file_dialog.file_selected.connect(_on_file_dialog_selected)
		add_child(_file_dialog)

	# Mod'a göre file dialog ayarları.
	if _mode == Mode.EXPORT:
		_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_file_dialog.title = "Export CSV — Save As"
		_file_dialog.current_file = _path_input.text.get_file()
		if _file_dialog.current_file.is_empty():
			_file_dialog.current_file = DEFAULT_EXPORT_FILENAME
	else:
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.title = "Import CSV — Open File"

	# Filtre.
	_file_dialog.filters = PackedStringArray(["*.csv ; CSV Files"])

	# Başlangıç klasörü — mevcut path'in klasörü.
	var current_dir: String = _path_input.text.get_base_dir()
	if not current_dir.is_empty():
		var global_dir: String = current_dir
		if current_dir.begins_with("user://") or current_dir.begins_with("res://"):
			global_dir = ProjectSettings.globalize_path(current_dir)
		if DirAccess.dir_exists_absolute(global_dir):
			_file_dialog.current_dir = global_dir

	_file_dialog.popup_centered_ratio(0.6)

func _on_file_dialog_selected(path: String) -> void:
	_path_input.text = path
	if _mode == Mode.IMPORT:
		_refresh_preview()

func _on_reset_path_pressed() -> void:
	_path_input.text = _get_default_path()
	_refresh_preview()

# ============================================================
# PREVIEW
# ============================================================

func _on_path_changed(_text: String) -> void:
	if _mode == Mode.IMPORT:
		_refresh_preview()

func _on_option_toggled(_pressed: bool) -> void:
	if _mode == Mode.EXPORT:
		_refresh_preview()

func _refresh_preview() -> void:
	if _mode == Mode.EXPORT:
		_refresh_export_preview()
	else:
		_refresh_import_preview()

func _refresh_export_preview() -> void:
	_preview_label.text = ""

	if not _registry:
		_preview_label.text = "(no registry)"
		return

	var locale_codes: PackedStringArray = _ordered_locale_codes()

	var key_set: Dictionary = {}
	var locale_data: Dictionary = {}
	for loc in locale_codes:
		var data: Dictionary = Service.read_json(Service.get_locale_file_path(loc))
		locale_data[loc] = data
		for k in data.keys():
			key_set[k] = true

	var keys: Array = key_set.keys()
	keys.sort()

	var rows: Array = []
	for key in keys:
		var row: Dictionary = {"key": key}
		var has_any_value: bool = false
		for loc in locale_codes:
			var d: Dictionary = locale_data.get(loc, {})
			var val: String = String(d.get(key, ""))
			row[loc] = val
			if not val.strip_edges().is_empty():
				has_any_value = true

		if has_any_value or _include_empty_check.button_pressed:
			rows.append(row)

	var csv: String = CSV.serialize(locale_codes, rows)

	var lines: PackedStringArray = csv.split("\n")
	var preview: String = ""
	for i in range(min(30, lines.size())):
		preview += lines[i] + "\n"
	if lines.size() > 30:
		preview += "\n... (%d more lines)" % (lines.size() - 30)

	_preview_label.text = preview
	_info_label.text = "Export: %d keys × %d locales = %d cells\nTarget: %s" % [
		rows.size(), locale_codes.size(), rows.size() * locale_codes.size(), _path_input.text
	]

func _refresh_import_preview() -> void:
	_preview_label.text = ""

	var path: String = _path_input.text.strip_edges()
	if path.is_empty():
		_preview_label.text = "(enter a file path)"
		return

	if not FileAccess.file_exists(path):
		_preview_label.text = "(file not found: %s)\n\nTip: use Project → Open User Data Folder to find user:// files." % path
		return

	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not f:
		_preview_label.text = "(cannot open file)"
		return
	var text: String = f.get_as_text()
	f.close()

	var parsed: Dictionary = CSV.parse(text)
	if parsed.is_empty():
		_preview_label.text = "(CSV parse failed)"
		return

	var locale_codes: PackedStringArray = parsed.get("locale_codes", [])
	var rows: Array = parsed.get("rows", [])

	var preview: String = ""
	preview += "Detected locales: %s\n" % ", ".join(locale_codes)
	preview += "Total rows: %d\n\n" % rows.size()
	preview += "First 15 rows:\n"

	for i in range(min(15, rows.size())):
		var row: Dictionary = rows[i]
		preview += "  %s\n" % row.get("key", "")

	if rows.size() > 15:
		preview += "  ... (%d more)" % (rows.size() - 15)

	_preview_label.text = preview
	_info_label.text = "Import: %d rows, %d locales detected" % [rows.size(), locale_codes.size()]

# ============================================================
# COPY PATH
# ============================================================

func _on_copy_path_pressed() -> void:
	DisplayServer.clipboard_set(_path_input.text)
	print("[Localization] Copied path to clipboard: ", _path_input.text)

# ============================================================
# CONFIRM
# ============================================================

func _on_confirmed() -> void:
	var path: String = _path_input.text.strip_edges()
	if path.is_empty():
		return

	if _mode == Mode.EXPORT:
		_do_export(path)
	else:
		_do_import(path)

# ============================================================
# EXPORT
# ============================================================

func _do_export(path: String) -> void:
	if not _registry:
		return

	var locale_codes: PackedStringArray = _ordered_locale_codes()

	var key_set: Dictionary = {}
	var locale_data: Dictionary = {}
	for loc in locale_codes:
		var data: Dictionary = Service.read_json(Service.get_locale_file_path(loc))
		locale_data[loc] = data
		for k in data.keys():
			key_set[k] = true

	var keys: Array = key_set.keys()
	keys.sort()

	var rows: Array = []
	for key in keys:
		var row: Dictionary = {"key": key}
		var has_any_value: bool = false
		for loc in locale_codes:
			var d: Dictionary = locale_data.get(loc, {})
			var val: String = String(d.get(key, ""))
			row[loc] = val
			if not val.strip_edges().is_empty():
				has_any_value = true

		if has_any_value or _include_empty_check.button_pressed:
			rows.append(row)

	var csv: String = CSV.serialize(locale_codes, rows)

	# Klasörü oluştur (kullanıcı manuel path girdiyse bile).
	var dir: String = path.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not f:
		push_error("CSV export: cannot open '%s' for writing." % path)
		return
	f.store_string(csv)
	f.close()

	print("[Localization] Exported %d keys × %d locales to %s" % [
		rows.size(), locale_codes.size(), path
	])
	export_completed.emit(path)

# ============================================================
# IMPORT
# ============================================================

func _do_import(path: String) -> void:
	if not _registry:
		return

	if not FileAccess.file_exists(path):
		push_error("CSV import: file not found: %s" % path)
		return

	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not f:
		push_error("CSV import: cannot open '%s'." % path)
		return
	var text: String = f.get_as_text()
	f.close()

	var parsed: Dictionary = CSV.parse(text)
	if parsed.is_empty():
		push_error("CSV import: parse failed.")
		return

	var csv_locales: PackedStringArray = parsed.get("locale_codes", [])
	var rows: Array = parsed.get("rows", [])

	var registered: PackedStringArray = _registry.get_all_locales()
	var valid_locales: PackedStringArray = []
	for loc in csv_locales:
		if registered.has(loc):
			valid_locales.append(loc)
		else:
			push_warning("CSV import: unknown locale '%s' — skipped." % loc)

	if valid_locales.is_empty():
		push_error("CSV import: no valid locales found in CSV.")
		return

	var locale_data: Dictionary = {}
	for loc in valid_locales:
		locale_data[loc] = Service.read_json(Service.get_locale_file_path(loc))

	var imported: int = 0
	for row in rows:
		var key: String = String(row.get("key", ""))
		if key.is_empty():
			continue

		for loc in valid_locales:
			var val: String = String(row.get(loc, ""))
			var data: Dictionary = locale_data[loc]
			data[key] = val
		imported += 1

	for loc in valid_locales:
		var path_json: String = Service.get_locale_file_path(loc)
		var err: Error = Service.write_json(path_json, locale_data[loc])
		if err != OK:
			push_error("CSV import: failed to write %s (err=%d)" % [path_json, err])

	print("[Localization] Imported %d keys into %d locales from %s" % [
		imported, valid_locales.size(), path
	])
	import_completed.emit(imported)

# ============================================================
# HELPERS
# ============================================================

func _ordered_locale_codes() -> PackedStringArray:
	if not _registry:
		return PackedStringArray()

	var all: PackedStringArray = _registry.get_all_locales()
	var orig: String = _registry.original_locale

	var out: PackedStringArray = []
	if not orig.is_empty() and all.has(orig):
		out.append(orig)

	var others: Array = []
	for loc in all:
		if loc != orig:
			others.append(loc)
	others.sort()
	for loc in others:
		out.append(loc)

	return out