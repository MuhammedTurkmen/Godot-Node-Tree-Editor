@tool
class_name BayterekLocalizationService
extends RefCounted
## File-system-level operations for the Localization plugin.
##
## Responsibilities:
##   - Load / save the LocalizationRegistry (.tres)
##   - Create / rename / delete language & region entries (and their JSON files)
##   - Read / write key-value JSON files
##
## All static — no instance needed.

const Localization = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization.gd")

# Explicit preloads — belt-and-suspenders. Even if the class_name registry
# hasn't caught up yet, these ensure the symbols resolve.
const LocalizationLanguage = preload("res://addons/bayterek_localization/scripts/resources/localization_language.gd")
const LocalizationRegion = preload("res://addons/bayterek_localization/scripts/resources/localization_region.gd")
const LocalizationRegistry = preload("res://addons/bayterek_localization/scripts/resources/localization_registry.gd")

# ============================================================
# REGISTRY LOAD / SAVE
# ============================================================

## Loads the registry from disk. Creates an empty one if missing.
static func load_registry() -> LocalizationRegistry:
	_ensure_dirs()

	var path: String = Localization.get_registry_path()

	if not FileAccess.file_exists(path):
		var fresh := LocalizationRegistry.new()
		ResourceSaver.save(fresh, path)
		return fresh

	var loaded = ResourceLoader.load(path, "LocalizationRegistry", ResourceLoader.CACHE_MODE_IGNORE)
	if not loaded or not loaded is LocalizationRegistry:
		push_warning("Localization: registry corrupt, rebuilding empty.")
		var fresh := LocalizationRegistry.new()
		ResourceSaver.save(fresh, path)
		return fresh

	return loaded

static func save_registry(registry: LocalizationRegistry) -> Error:
	if not registry:
		return FAILED
	_ensure_dirs()
	return ResourceSaver.save(registry, Localization.get_registry_path())

# ============================================================
# LANGUAGE CRUD
# ============================================================

## Adds a language. If `region_code` is provided, immediately creates a
## region under it. Returns the new language or null on error.
static func add_language(
	registry: LocalizationRegistry,
	lang_code: String,
	region_code: String = ""
) -> LocalizationLanguage:
	if not registry:
		return null
	if registry.has_language(lang_code):
		push_warning("Localization: language already exists: %s" % lang_code)
		return null

	var meta: Dictionary = Localization.find_language(lang_code)
	if meta.is_empty():
		push_warning("Localization: unknown language code: %s" % lang_code)
		return null

	var lang := LocalizationLanguage.new()
	lang.code = lang_code
	lang.name = meta.get("name", lang_code)

	registry.add_language(lang)

	if not region_code.is_empty():
		add_region(registry, lang_code, region_code)

	# If this is the first language and no original locale exists yet,
	# designate its (single) locale as original.
	if registry.original_locale.is_empty():
		var locales: PackedStringArray = lang.get_locales()
		if locales.size() > 0:
			registry.original_locale = locales[0]

	return lang

static func remove_language(registry: LocalizationRegistry, lang_code: String) -> bool:
	if not registry:
		return false
	var lang: LocalizationLanguage = registry.get_language(lang_code)
	if not lang:
		return false

	# Delete all region JSON files first.
	for region in lang.regions:
		if region and not region.file_path.is_empty():
			_delete_file_with_uid(region.file_path)

	# If language has no regions, delete its own JSON file.
	if lang.regions.is_empty():
		var path: String = _language_file_path(lang_code, "")
		_delete_file_with_uid(path)

	# If the original locale belonged to this language, clear it.
	var locales: PackedStringArray = lang.get_locales()
	if locales.has(registry.original_locale):
		registry.original_locale = ""
		_promote_first_locale_as_original(registry)

	return registry.remove_language(lang_code)

# ============================================================
# REGION CRUD
# ============================================================

## Adds a region to an existing language. Creates an empty JSON file.
static func add_region(
	registry: LocalizationRegistry,
	lang_code: String,
	region_code: String
) -> LocalizationRegion:
	if not registry:
		return null
	var lang: LocalizationLanguage = registry.get_language(lang_code)
	if not lang:
		push_warning("Localization: language not found: %s" % lang_code)
		return null
	if lang.has_region(region_code):
		push_warning("Localization: region already exists: %s-%s" % [lang_code, region_code])
		return null

	var meta: Dictionary = Localization.find_region(region_code)
	if meta.is_empty():
		push_warning("Localization: unknown region code: %s" % region_code)
		return null

	var region := LocalizationRegion.new()
	region.code = region_code
	region.name = meta.get("name", region_code)
	region.language_code = lang_code
	region.file_path = _language_file_path(lang_code, region_code)

	# If the language previously had no regions, it used its own JSON file
	# (lang.json). Now that we're adding a region, we must materialise that
	# language-only JSON into the region file so we don't lose keys.
	if lang.regions.is_empty():
		var old_path: String = _language_file_path(lang_code, "")
		if FileAccess.file_exists(old_path):
			var old_data: Dictionary = read_json(old_path)
			write_json(region.file_path, old_data)
			_delete_file_with_uid(old_path)
		else:
			write_json(region.file_path, {})
	else:
		write_json(region.file_path, {})

	lang.add_region(region)

	if registry.original_locale == lang_code:
		registry.original_locale = "%s-%s" % [lang_code, region_code]

	return region

static func remove_region(
	registry: LocalizationRegistry,
	lang_code: String,
	region_code: String
) -> bool:
	if not registry:
		return false
	var lang: LocalizationLanguage = registry.get_language(lang_code)
	if not lang:
		return false
	var region: LocalizationRegion = lang.get_region(region_code)
	if not region:
		return false

	if not region.file_path.is_empty():
		_delete_file_with_uid(region.file_path)

	var was_original: bool = registry.original_locale == region.get_locale()
	var removed: bool = lang.remove_region(region_code)

	# If language now has no regions, it becomes a language-only locale.
	# Create its lang.json if it doesn't exist.
	if lang.regions.is_empty():
		var path: String = _language_file_path(lang_code, "")
		if not FileAccess.file_exists(path):
			write_json(path, {})

	if was_original:
		registry.original_locale = ""
		_promote_first_locale_as_original(registry)

	return removed

# ============================================================
# JSON READ / WRITE
# ============================================================

## Reads a JSON file into a Dictionary<String, String>.
## Returns {} if the file doesn't exist or is malformed.
static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not f:
		push_warning("Localization: cannot open %s for reading" % path)
		return {}

	var text: String = f.get_as_text()
	f.close()

	if text.strip_edges().is_empty():
		return {}

	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("Localization: malformed JSON at %s" % path)
		return {}

	# Normalise all values to strings.
	var out: Dictionary = {}
	for k in parsed.keys():
		out[String(k)] = str(parsed[k])
	return out

## Writes a Dictionary<String, String> to a JSON file (pretty, sorted keys).
static func write_json(path: String, data: Dictionary) -> Error:
	# Sort keys alphabetically for stable diffs in Git.
	var keys: Array = data.keys()
	keys.sort()

	var ordered: Dictionary = {}
	for k in keys:
		ordered[k] = data[k]

	var text: String = JSON.stringify(ordered, "\t", false)

	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not f:
		push_error("Localization: cannot open %s for writing" % path)
		return FAILED

	f.store_string(text)
	f.close()
	return OK

# ============================================================
# LOCALE FILE PATH HELPERS
# ============================================================

## Builds "res://data/localization/languages/<locale>.json".
##   language-only:  _language_file_path("en", "")    -> ".../en.json"
##   region:         _language_file_path("en", "US")  -> ".../en-US.json"
static func _language_file_path(lang_code: String, region_code: String) -> String:
	var dir: String = Localization.get_languages_dir()
	var locale: String = Localization.compose_locale(lang_code, region_code)
	return "%s/%s.json" % [dir, locale]

## Public helper for other classes.
static func get_locale_file_path(locale: String) -> String:
	var dir: String = Localization.get_languages_dir()
	return "%s/%s.json" % [dir, locale]

# ============================================================
# INTERNAL HELPERS
# ============================================================

static func _ensure_dirs() -> void:
	var root: String = Localization.get_root_path()
	var languages: String = Localization.get_languages_dir()
	if not DirAccess.dir_exists_absolute(root):
		DirAccess.make_dir_recursive_absolute(root)
	if not DirAccess.dir_exists_absolute(languages):
		DirAccess.make_dir_recursive_absolute(languages)

static func _delete_file_with_uid(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var uid_path: String = path + ".uid"
	if FileAccess.file_exists(uid_path):
		DirAccess.remove_absolute(uid_path)

static func _promote_first_locale_as_original(registry: LocalizationRegistry) -> void:
	for l in registry.languages:
		if not l:
			continue
		var locales: PackedStringArray = l.get_locales()
		if locales.size() > 0:
			registry.original_locale = locales[0]
			return
	registry.original_locale = ""