@tool
class_name BayterekLocalization
extends RefCounted
## Global constants and helper functions for the Localization plugin.

const VERSION := "0.1.0"

const ROOT_PATH_SETTING := "addons/bayterek_localization/root_path"
const DEFAULT_ROOT_PATH := "res://data/localization"
const REGISTRY_FILENAME_SETTING := "addons/bayterek_localization/registry_filename"
const DEFAULT_REGISTRY_FILENAME := "localization_registry.tres"

const LANGUAGES_DIR_NAME := "languages"

const ICON_THEME := &"EditorIcons"
const LANGUAGE_ICON := "Translation"
const REGION_ICON := "Environment"
const KEY_ICON := "Key"

## All ISO 639-1 languages we support in the "Add Language" dropdown.
## "code" = ISO 639-1 (2-letter), "name" = English display name.
const LANGUAGES: Array[Dictionary] = [
	{"code": "en", "name": "English"},
	{"code": "tr", "name": "Türkçe"},
	{"code": "de", "name": "Deutsch"},
	{"code": "fr", "name": "Français"},
	{"code": "es", "name": "Español"},
	{"code": "it", "name": "Italiano"},
	{"code": "pt", "name": "Português"},
	{"code": "ru", "name": "Русский"},
	{"code": "ja", "name": "日本語"},
	{"code": "zh-Hans", "name": "中文 (Simplified)"},
	{"code": "zh-Hant", "name": "中文 (Traditional)"},
	{"code": "ko", "name": "한국어"},
	{"code": "ar", "name": "العربية"},
	{"code": "nl", "name": "Nederlands"},
	{"code": "pl", "name": "Polski"},
	{"code": "sv", "name": "Svenska"},
	{"code": "da", "name": "Dansk"},
	{"code": "fi", "name": "Suomi"},
	{"code": "no", "name": "Norsk"},
	{"code": "el", "name": "Ελληνικά"},
	{"code": "he", "name": "עברית"},
	{"code": "hi", "name": "हिन्दी"},
	{"code": "th", "name": "ไทย"},
	{"code": "vi", "name": "Tiếng Việt"},
	{"code": "id", "name": "Bahasa Indonesia"},
	{"code": "uk", "name": "Українська"},
	{"code": "cs", "name": "Čeština"},
	{"code": "ro", "name": "Română"},
	{"code": "hu", "name": "Magyar"},
]

## All ISO 3166-1 alpha-2 regions we support in the "Add Region" dropdown.
## "code" = region code, "name" = English display name, "languages" = which
## language codes this region belongs to (used for filtering).
const REGIONS: Array[Dictionary] = [
	# English
	{"code": "US", "name": "United States", "languages": ["en"]},
	{"code": "GB", "name": "United Kingdom", "languages": ["en"]},
	{"code": "AU", "name": "Australia", "languages": ["en"]},
	{"code": "CA", "name": "Canada", "languages": ["en", "fr"]},
	{"code": "NZ", "name": "New Zealand", "languages": ["en"]},
	{"code": "IE", "name": "Ireland", "languages": ["en"]},
	# Turkish
	{"code": "TR", "name": "Türkiye", "languages": ["tr"]},
	{"code": "CY", "name": "Cyprus", "languages": ["tr", "el"]},
	# German
	{"code": "DE", "name": "Deutschland", "languages": ["de"]},
	{"code": "AT", "name": "Österreich", "languages": ["de"]},
	{"code": "CH", "name": "Schweiz", "languages": ["de", "fr", "it"]},
	# French
	{"code": "FR", "name": "France", "languages": ["fr"]},
	{"code": "BE", "name": "Belgique", "languages": ["fr", "nl"]},
	# Spanish
	{"code": "ES", "name": "España", "languages": ["es"]},
	{"code": "MX", "name": "México", "languages": ["es"]},
	{"code": "AR", "name": "Argentina", "languages": ["es"]},
	{"code": "CO", "name": "Colombia", "languages": ["es"]},
	# Italian
	{"code": "IT", "name": "Italia", "languages": ["it"]},
	# Portuguese
	{"code": "PT", "name": "Portugal", "languages": ["pt"]},
	{"code": "BR", "name": "Brasil", "languages": ["pt"]},
	# Russian
	{"code": "RU", "name": "Россия", "languages": ["ru"]},
	# Japanese
	{"code": "JP", "name": "日本", "languages": ["ja"]},
	# Chinese
	{"code": "CN", "name": "中国", "languages": ["zh-Hans"]},
	{"code": "TW", "name": "台灣", "languages": ["zh-Hant"]},
	{"code": "HK", "name": "香港", "languages": ["zh-Hant"]},
	# Korean
	{"code": "KR", "name": "대한민국", "languages": ["ko"]},
	# Arabic
	{"code": "SA", "name": "السعودية", "languages": ["ar"]},
	{"code": "AE", "name": "الإمارات", "languages": ["ar"]},
	{"code": "EG", "name": "مصر", "languages": ["ar"]},
	# Dutch
	{"code": "NL", "name": "Nederland", "languages": ["nl"]},
	# Polish
	{"code": "PL", "name": "Polska", "languages": ["pl"]},
	# Swedish
	{"code": "SE", "name": "Sverige", "languages": ["sv"]},
	# Danish
	{"code": "DK", "name": "Danmark", "languages": ["da"]},
	# Finnish
	{"code": "FI", "name": "Suomi", "languages": ["fi"]},
	# Norwegian
	{"code": "NO", "name": "Norge", "languages": ["no"]},
	# Greek
	{"code": "GR", "name": "Ελλάδα", "languages": ["el"]},
	# Hebrew
	{"code": "IL", "name": "ישראל", "languages": ["he"]},
	# Hindi
	{"code": "IN", "name": "भारत", "languages": ["hi", "en"]},
	# Thai
	{"code": "TH", "name": "ไทย", "languages": ["th"]},
	# Vietnamese
	{"code": "VN", "name": "Việt Nam", "languages": ["vi"]},
	# Indonesian
	{"code": "ID", "name": "Indonesia", "languages": ["id"]},
	# Ukrainian
	{"code": "UA", "name": "Україна", "languages": ["uk"]},
	# Czech
	{"code": "CZ", "name": "Česko", "languages": ["cs"]},
	# Romanian
	{"code": "RO", "name": "România", "languages": ["ro"]},
	# Hungarian
	{"code": "HU", "name": "Magyarország", "languages": ["hu"]},
]

# ============================================================
# PATHS
# ============================================================

static func get_root_path() -> String:
	return ProjectSettings.get_setting(ROOT_PATH_SETTING, DEFAULT_ROOT_PATH)

static func get_languages_dir() -> String:
	return "%s/%s" % [get_root_path(), LANGUAGES_DIR_NAME]

static func get_registry_filename() -> String:
	return ProjectSettings.get_setting(REGISTRY_FILENAME_SETTING, DEFAULT_REGISTRY_FILENAME)

static func get_registry_path() -> String:
	return "%s/%s" % [get_root_path(), get_registry_filename()]

# ============================================================
# HELPERS
# ============================================================

static func to_snake_case(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9]+")
	var result: String = regex.sub(text.strip_edges(), "_", true)
	return result.to_lower()

## Looks up a language dict by code. Returns {} if not found.
static func find_language(code: String) -> Dictionary:
	for lang in LANGUAGES:
		if lang.get("code", "") == code:
			return lang
	return {}

## Looks up a region dict by code. Returns {} if not found.
static func find_region(code: String) -> Dictionary:
	for reg in REGIONS:
		if reg.get("code", "") == code:
			return reg
	return {}

## Returns all regions whose "languages" list contains `lang_code`.
static func get_regions_for_language(lang_code: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for reg in REGIONS:
		var langs: Array = reg.get("languages", [])
		if langs.has(lang_code):
			out.append(reg)
	return out

## Composes a locale code like "en-US" from a language + region code.
static func compose_locale(language_code: String, region_code: String) -> String:
	if region_code.is_empty():
		return language_code
	return "%s-%s" % [language_code, region_code]
