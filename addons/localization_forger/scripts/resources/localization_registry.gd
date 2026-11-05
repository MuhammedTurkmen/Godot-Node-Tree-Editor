@tool
class_name LocalizationRegistry
extends Resource
## Root resource. Holds every language (and their regions).
##
## Saved to res://data/localization/localization_registry.tres.
##
## `original_locale` designates the "source of truth" locale.
## `starred_locales` holds locales the user marked as favorites;
## they are listed right below the original locale in the Browser.
##
## Godot locale format: language_Script_COUNTRY_VARIANT
##   language — 2 or 3-letter lowercase
##   Script   — optional, 4-letter Title case (e.g. Hans, Hant)
##   COUNTRY  — optional, 2-letter UPPERCASE
##   VARIANT  — optional

@export_storage var languages: Array[LocalizationLanguage] = []
@export_storage var original_locale: String = ""

## Locales marked as favorites in the Browser.
## They appear immediately below the original locale in the tree.
@export_storage var starred_locales: Dictionary = {}  # locale -> true

# ============================================================
# LANGUAGE LOOKUP
# ============================================================

func has_language(lang_code: String) -> bool:
	for l in languages:
		if l and l.code == lang_code:
			return true
	return false

func get_language(lang_code: String) -> LocalizationLanguage:
	for l in languages:
		if l and l.code == lang_code:
			return l
	return null

func add_language(lang: LocalizationLanguage) -> bool:
	if not lang:
		return false
	if has_language(lang.code):
		return false
	languages.append(lang)
	return true

func remove_language(lang_code: String) -> bool:
	for i in languages.size():
		if languages[i] and languages[i].code == lang_code:
			languages.remove_at(i)
			return true
	return false

# ============================================================
# LOCALE LOOKUP
# ============================================================

## Returns { language: LocalizationLanguage, region: LocalizationRegion or null }
## for a locale string like "en_US" or "en".
func find_locale(locale: String) -> Dictionary:
	if locale.is_empty():
		return {}

	# Godot formatı: dil_Script_COUNTRY_VARIANT
	var parts: PackedStringArray = locale.split("_", false)
	if parts.size() < 2:
		var lang_only: LocalizationLanguage = get_language(locale)
		if lang_only:
			return {"language": lang_only, "region": null}
		return {}

	var lang_code: String = parts[0].to_lower()
	var lang: LocalizationLanguage = get_language(lang_code)
	if not lang:
		return {}

	# Kalan tüm parçaları region kodu olarak birleştir:
	#   en_US       → region = "US"
	#   zh_Hans_CN  → region = "Hans_CN"
	var region_parts: Array[String] = []
	for i in range(1, parts.size()):
		region_parts.append(parts[i])
	var region_code: String = "_".join(region_parts)

	var reg: LocalizationRegion = lang.get_region(region_code)
	if reg:
		return {"language": lang, "region": reg}

	return {}

func has_locale(locale: String) -> bool:
	return not find_locale(locale).is_empty()

## Returns every locale in the registry, e.g. ["en_US", "en_GB", "tr_TR"].
func get_all_locales() -> PackedStringArray:
	var out: PackedStringArray = []
	for l in languages:
		if not l:
			continue
		for loc in l.get_locales():
			out.append(loc)
	return out

## Returns the LocalizationRegion for a locale, or null.
func get_region_for_locale(locale: String) -> LocalizationRegion:
	var found: Dictionary = find_locale(locale)
	if found.is_empty():
		return null
	return found.get("region", null)

## Returns the LocalizationLanguage for a locale, or null.
func get_language_for_locale(locale: String) -> LocalizationLanguage:
	var found: Dictionary = find_locale(locale)
	if found.is_empty():
		return null
	return found.get("language", null)

# ============================================================
# ORIGINAL LOCALE
# ============================================================

func is_original(locale: String) -> bool:
	return not original_locale.is_empty() and locale == original_locale

## Sets the original locale. Returns true if the value actually changed.
## If `original_locale` is a valid locale in the registry, clears any
## star flag on it (original is implicitly top priority).
func set_original_locale(locale: String) -> bool:
	if locale == original_locale:
		return false
	original_locale = locale
	# Original and star flags are mutually exclusive.
	starred_locales.erase(locale)
	return true

## Picks a sensible default original locale if one isn't set yet.
## Preference order:
##   1. Existing original_locale if valid
##   2. English locales (en_US, en-US, en_GB, ...)
##   3. First available locale
func ensure_original_locale() -> void:
	var all_locales: PackedStringArray = get_all_locales()

	if not original_locale.is_empty() and all_locales.has(original_locale):
		return

	# Prefer English — try exact matches first, then prefix.
	var english_candidates: Array[String] = ["en_US", "en-US", "en_GB", "en-GB", "en"]
	for candidate in english_candidates:
		if all_locales.has(candidate):
			original_locale = candidate
			return

	# Any locale starting with "en"
	for loc in all_locales:
		var lower: String = loc.to_lower()
		if lower.begins_with("en_") or lower.begins_with("en-"):
			original_locale = loc
			return

	# Fallback: first locale
	if all_locales.size() > 0:
		original_locale = all_locales[0]

# ============================================================
# STARRED LOCALES
# ============================================================

func is_starred(locale: String) -> bool:
	return starred_locales.has(locale)

func star_locale(locale: String) -> bool:
	if locale.is_empty():
		return false
	if locale == original_locale:
		return false
	if starred_locales.has(locale):
		return false
	starred_locales[locale] = true
	return true

func unstar_locale(locale: String) -> bool:
	if not starred_locales.has(locale):
		return false
	starred_locales.erase(locale)
	return true

func toggle_star(locale: String) -> bool:
	if starred_locales.has(locale):
		unstar_locale(locale)
		return false
	star_locale(locale)
	return true

## Returns all locales in Browser display order:
##   1. Original locale (first)
##   2. Starred locales (sorted alphabetically)
##   3. Remaining locales (sorted alphabetically)
func get_locales_in_display_order() -> PackedStringArray:
	var all_locales: PackedStringArray = get_all_locales()

	var original: String = original_locale
	var starred: Array[String] = []
	var rest: Array[String] = []

	for loc in all_locales:
		if loc == original:
			continue
		if starred_locales.has(loc):
			starred.append(loc)
		else:
			rest.append(loc)

	starred.sort()
	rest.sort()

	var out: PackedStringArray = []
	if not original.is_empty() and all_locales.has(original):
		out.append(original)
	for loc in starred:
		out.append(loc)
	for loc in rest:
		out.append(loc)
	return out

# ============================================================
# HELPERS
# ============================================================

func get_language_count() -> int:
	return languages.size()

func get_region_count() -> int:
	var total: int = 0
	for l in languages:
		if l:
			total += l.regions.size()
	return total

## Cleans up starred_locales entries that no longer exist in the registry.
func sanitize_starred() -> bool:
	var all_locales: PackedStringArray = get_all_locales()
	var to_remove: Array[String] = []
	for loc in starred_locales.keys():
		if not all_locales.has(loc):
			to_remove.append(loc)
	for loc in to_remove:
		starred_locales.erase(loc)
	return not to_remove.is_empty()

func _to_string() -> String:
	return "LocalizationRegistry(languages=%d, original='%s', starred=%d)" % [
		languages.size(), original_locale, starred_locales.size()
	]