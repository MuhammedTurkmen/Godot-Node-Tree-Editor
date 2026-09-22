@tool
extends Node
## Autoload: GameLocalization
##
## Runtime translation API.
##
##   get_text(key, args)   → key lookup + {arg} format
##   translate(text, args) → text with {@key} + {arg} resolution
##
## Inside both functions:
##   {name}  → args first, then key lookup
##   {@key}  → key lookup only

const Localization = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization.gd")
const Service = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization_service.gd")
const Format = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization_format_string.gd")

signal language_changed(new_locale: String)

var _current_locale: String = ""
var _original_locale: String = ""
var _translations: Dictionary = {}
var _fallback: Dictionary = {}

var debug_missing_args: bool = true

# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		debug_missing_args = true
	else:
		debug_missing_args = OS.is_debug_build()

	# Loader autoload'u scene tree'de olduğu için güvenli erişim.
	var loader: Node = null
	if is_inside_tree():
		loader = get_node_or_null("/root/BayterekLocalizationLoader")

	if loader:
		var reg = loader.call("get_registry")
		if reg:
			_original_locale = reg.original_locale
			_load_locale_into(_original_locale, _fallback)

	if not _original_locale.is_empty():
		set_language(_original_locale)

	if not Engine.is_editor_hint():
		var os_locale: String = _detect_os_locale()
		if not os_locale.is_empty():
			set_language(os_locale)

	print("[GameLocalization] ready. locale=%s original=%s debug_missing=%s" % [
		_current_locale, _original_locale, str(debug_missing_args)
	])

# ============================================================
# PUBLIC API
# ============================================================

func get_language() -> String:
	return _current_locale

func get_available_languages() -> PackedStringArray:
	if not is_inside_tree():
		return PackedStringArray()
	var loader: Node = get_node_or_null("/root/BayterekLocalizationLoader")
	if not loader:
		return PackedStringArray()
	var reg = loader.call("get_registry")
	if not reg:
		return PackedStringArray()
	return reg.get_all_locales()

func set_language(locale: String) -> bool:
	if locale.is_empty():
		return false
	if locale == _current_locale:
		return true

	var loaded: Dictionary = {}
	var path: String = Service.get_locale_file_path(locale)
	if FileAccess.file_exists(path):
		loaded = Service.read_json(path)
	else:
		push_warning("[GameLocalization] locale file not found: %s" % path)

	_current_locale = locale
	_translations = loaded

	language_changed.emit(_current_locale)
	return true

# ============================================================
# GET_TEXT — key lookup
# ============================================================

## Returns the translation for `key`, formatted with args.
## Nested {@key} references inside the value are NOT resolved here —
## use translate() for that.
func get_text(key: String, args: Dictionary = {}) -> String:
	if key.is_empty():
		return ""

	var raw: String = _lookup(key)
	if raw.is_empty():
		return "[%s]" % key

	if args.is_empty() and not Format.has_placeholders(raw):
		return raw

	if debug_missing_args:
		return Format.format_visible(raw, args)
	return Format.format(raw, args)

func has_key(key: String) -> bool:
	return not _lookup(key).is_empty()

# ============================================================
# TRANSLATE — text with {@key} + {arg}
# ============================================================

## Translates an arbitrary text.
##   {name}  → args first, then key lookup
##   {@key}  → key lookup only
func translate(text: String, args: Dictionary = {}) -> String:
	if text.is_empty():
		return text
	if debug_missing_args:
		return Format.resolve_visible(text, args, _lookup)
	return Format.resolve(text, args, _lookup)

# ============================================================
# INTROSPECTION
# ============================================================

func get_required_args(key: String) -> PackedStringArray:
	var raw: String = _lookup(key)
	if raw.is_empty():
		return PackedStringArray()
	return Format.extract_args(raw)

func get_missing_args(key: String, args: Dictionary) -> PackedStringArray:
	var required: PackedStringArray = get_required_args(key)
	var missing: PackedStringArray = []
	for name in required:
		if not args.has(name):
			missing.append(name)
	return missing

func reload() -> void:
	var keep: String = _current_locale
	_current_locale = ""
	if not keep.is_empty():
		set_language(keep)

	if not is_inside_tree():
		return
	var loader: Node = get_node_or_null("/root/BayterekLocalizationLoader")
	if loader:
		var reg = loader.call("get_registry")
		if reg:
			_original_locale = reg.original_locale
			_load_locale_into(_original_locale, _fallback)

## Manual bootstrap from a caller (used by editor-side test scripts).
func bootstrap(registry: LocalizationRegistry) -> void:
	if not registry:
		return
	_original_locale = registry.original_locale
	_load_locale_into(_original_locale, _fallback)
	if not _original_locale.is_empty():
		set_language(_original_locale)

# ============================================================
# INTERNAL
# ============================================================

func _lookup(key: String) -> String:
	if key.is_empty():
		return ""
	if _translations.has(key):
		return String(_translations[key])
	if _fallback.has(key):
		return String(_fallback[key])
	return ""

func _load_locale_into(locale: String, target: Dictionary) -> void:
	target.clear()
	if locale.is_empty():
		return
	var path: String = Service.get_locale_file_path(locale)
	if not FileAccess.file_exists(path):
		return
	var data: Dictionary = Service.read_json(path)
	for k in data.keys():
		target[k] = data[k]

func _detect_os_locale() -> String:
	var os_locale: String = OS.get_locale()
	if os_locale.is_empty():
		return ""
	var normalised: String = os_locale.replace("_", "-")
	var available: PackedStringArray = get_available_languages()
	for loc in available:
		if loc.to_lower() == normalised.to_lower():
			return loc
	var lang_only: String = normalised.split("-")[0].to_lower()
	for loc in available:
		if loc.to_lower().begins_with(lang_only + "-"):
			return loc
	return ""