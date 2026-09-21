@tool
class_name LocalizationRegistry
extends Resource
## Root resource. Holds every language (and their regions).
##
## Saved to res://data/localization/localization_registry.tres.
##
## `original_locale` designates the "source of truth" locale — the one whose
## key list drives the Editor's Key sidebar. Other locales only translate
## existing keys.

@export_storage var languages: Array[LocalizationLanguage] = []
@export_storage var original_locale: String = ""

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
## for a locale string like "en-US" or "en".
func find_locale(locale: String) -> Dictionary:
	if locale.is_empty():
		return {}

	# Try "lang-REGION"
	var dash: int = locale.find("-")
	if dash > 0:
		var lang_code: String = locale.substr(0, dash)
		var region_code: String = locale.substr(dash + 1)
		var lang: LocalizationLanguage = get_language(lang_code)
		if lang:
			var reg: LocalizationRegion = lang.get_region(region_code)
			if reg:
				return {"language": lang, "region": reg}
		return {}

	# No dash: treat as language-only locale
	var lang2: LocalizationLanguage = get_language(locale)
	if lang2:
		return {"language": lang2, "region": null}

	return {}

func has_locale(locale: String) -> bool:
	return not find_locale(locale).is_empty()

## Returns every locale in the registry, e.g. ["en-US", "en-GB", "tr-TR"].
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
# HELPERS
# ============================================================

func is_original(locale: String) -> bool:
	return not original_locale.is_empty() and locale == original_locale

func get_language_count() -> int:
	return languages.size()

func get_region_count() -> int:
	var total: int = 0
	for l in languages:
		if l:
			total += l.regions.size()
	return total

func _to_string() -> String:
	return "LocalizationRegistry(languages=%d, original='%s')" % [languages.size(), original_locale]