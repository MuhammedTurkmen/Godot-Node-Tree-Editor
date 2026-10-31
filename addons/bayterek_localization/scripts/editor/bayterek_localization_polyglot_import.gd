@tool
class_name BayterekLocalizationPolyglotImport
extends RefCounted
## Polyglot Gamedev CSV formatını import eder.
##
## Format:
##   STRING ID,DESCRIPTION,ENGLISH,FRENCH / FRANÇAIS,...
##   LANGUAGE_CODE,IETF tags,enUS enGB,frFR,...
##   LANGUAGE_EN,LanguageName,English,French,...
##   LANGUAGE_DIRECTION,ltr or rtl,ltr,ltr,...
##   ,,,,,... (boş satır)
##   Polyglot,100,,,,...
##   CONTEXT_*,...,...
##   MENU_*,...,...
##
## Sadece registry'de kayıtlı locale'lere yazar. Eşleşmeyen sütunlar
## atlanır. Boş hücreler atlanır (mevcut değeri ezmez).
##
## Godot locale formatı: language_Script_COUNTRY_VARIANT
##   language — 2/3 harf küçük, Script — 4 harf Title, COUNTRY — 2 harf BÜYÜK

const Localization = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization.gd")
const Service = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization_service.gd")

## CSV sütun başlığı → Godot locale kodu (dil_küçük_ÜLKE_büyük).
## Registry'de olmayan locale'ler otomatik atlanır.
const COLUMN_TO_LOCALE := {
	"ENGLISH": "en_US",
	"TURKISH / TÜRKÇE": "tr_TR",
	"GERMAN / DEUTSCH": "de_DE",
	"FRENCH / FRANÇAIS": "fr_FR",
	"SPANISH / ESPAÑOL": "es_ES",
	"ITALIAN / ITALIANO": "it_IT",
	"PORTUGUESE / PORTUGUÊS (BR)": "pt_BR",
	"PORTUGUESE / PORTUGUÊS (PT)": "pt_PT",
	"RUSSIAN / РУССКИЙ": "ru_RU",
	"JAPANESE / 日本語": "ja_JP",
	"SIMPLIFIED CHINESE / 简体中文": "zh_Hans_CN",
	"TRADITIONAL CHINESE / 繁体中文": "zh_Hant_TW",
	"KOREAN / 한국어": "ko_KR",
	"POLISH / POLSKI": "pl_PL",
	"GREEK / ΕΛΛΗΝΙΚΑ": "el_GR",
	"DUTCH / NEDERLANDS": "nl_NL",
	"SWEDISH / SVENSKA": "sv_SE",
	"DANISH / DANSK": "da_DK",
	"NORWEGIAN (NB) / NORSK BOKMÅL": "nb_NO",
	"FINNISH / SUOMI": "fi_FI",
	"CZECH / ČEŠTINA": "cs_CZ",
	"HUNGARIAN / MAGYAR": "hu_HU",
	"ROMANIAN / ROMÂNĂ": "ro_RO",
	"THAI / ภาษาไทย": "th_TH",
	"BULGARIAN / БЪЛГАРСКИ": "bg_BG",
	"עברית / HEBREW": "he_IL",
	" العربية / ARABIC": "ar_SA",
	"BOSNIAN": "bs_BA",
}

## İçe aktarılacak key prefix'leri. Boş = hepsi.
## CONTEXT_* genelde tek başına anlam taşımaz, atlanır.
const SKIP_PREFIXES: Array[String] = ["CONTEXT_", "LANGUAGE_", "Polyglot"]


## Ana giriş noktası.
## `csv_path` — okunacak dosya.
## `locale_filter` — sadece bu locale'lere yaz (boş = hepsi).
##
## Dönüş: { "imported": int, "skipped": int, "locales": Array[String] }
static func import_csv(csv_path: String, locale_filter: Array = []) -> Dictionary:
	var result: Dictionary = {"imported": 0, "skipped": 0, "locales": []}

	if not FileAccess.file_exists(csv_path):
		push_error("[PolyglotImport] Dosya yok: %s" % csv_path)
		return result

	var text: String = _read_file(csv_path)
	if text.is_empty():
		push_error("[PolyglotImport] Dosya okunamadı: %s" % csv_path)
		return result

	if text.begins_with("\ufeff"):
		text = text.substr(1)

	var records: Array = _parse_csv(text)
	if records.size() < 6:
		push_error("[PolyglotImport] CSV çok kısa veya bozuk.")
		return result

	var header: Array = records[0]

	var loader: Node = _get_loader()
	if not loader:
		push_error("[PolyglotImport] BayterekLocalizationLoader autoload yok.")
		return result
	var registry: LocalizationRegistry = loader.call("get_registry")
	if not registry:
		push_error("[PolyglotImport] Registry yok.")
		return result

	var col_to_locale: Dictionary = {}
	var new_languages_added: bool = false

	for i in header.size():
		var col_name: String = String(header[i]).strip_edges()
		if not COLUMN_TO_LOCALE.has(col_name):
			continue
		var locale: String = COLUMN_TO_LOCALE[col_name]
		if not locale_filter.is_empty() and not locale_filter.has(locale):
			continue

		if not registry.has_locale(locale):
			var added: bool = _ensure_locale_in_registry(registry, locale)
			if added:
				new_languages_added = true
			else:
				push_warning("[PolyglotImport] Locale eklenemedi: %s" % locale)
				continue

		col_to_locale[i] = locale

	if new_languages_added:
		loader.call("save_registry")

	if col_to_locale.is_empty():
		push_error("[PolyglotImport] Eşleşen locale yok.")
		return result

	var locale_data: Dictionary = {}
	for locale in col_to_locale.values():
		locale_data[locale] = {}
		if not result["locales"].has(locale):
			result["locales"].append(locale)

	for row_idx in range(1, records.size()):
		var row: Array = records[row_idx]
		if row.size() < 2:
			continue

		var key: String = String(row[0]).strip_edges()
		if key.is_empty():
			continue

		var should_skip: bool = false
		for prefix in SKIP_PREFIXES:
			if key.begins_with(prefix):
				should_skip = true
				break
		if should_skip:
			result["skipped"] = int(result["skipped"]) + 1
			continue

		var row_imported: bool = false
		for col_idx in col_to_locale.keys():
			if col_idx >= row.size():
				continue
			var locale: String = col_to_locale[col_idx]
			var value: String = String(row[col_idx])
			if value.is_empty():
				continue
			locale_data[locale][key] = value
			row_imported = true

		if row_imported:
			result["imported"] = int(result["imported"]) + 1

	for locale in locale_data.keys():
		var data: Dictionary = locale_data[locale]
		if data.is_empty():
			continue
		var path: String = Service.get_locale_file_path(locale)

		var existing: Dictionary = Service.read_json(path)
		for k in data.keys():
			existing[k] = data[k]

		Service.write_json(path, existing)

	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()

	print("[PolyglotImport] %d key, %d locale, %d atlandı" % [
		result["imported"], result["locales"].size(), result["skipped"]
	])
	return result

# ============================================================
# CSV PARSER (RFC 4180)
# ============================================================

static func _parse_csv(text: String) -> Array:
	var records: Array = []
	var current_record: Array = []
	var current_field: String = ""
	var in_quotes: bool = false
	var i: int = 0
	var n: int = text.length()

	while i < n:
		var c: String = text[i]

		if in_quotes:
			if c == "\"":
				if i + 1 < n and text[i + 1] == "\"":
					current_field += "\""
					i += 2
					continue
				in_quotes = false
				i += 1
				continue
			current_field += c
			i += 1
			continue

		match c:
			"\"":
				in_quotes = true
				i += 1
			",":
				current_record.append(current_field)
				current_field = ""
				i += 1
			"\r":
				i += 1
			"\n":
				current_record.append(current_field)
				current_field = ""
				records.append(current_record)
				current_record = []
				i += 1
			_:
				current_field += c
				i += 1

	if not current_field.is_empty() or not current_record.is_empty():
		current_record.append(current_field)
		records.append(current_record)

	return records


static func _read_file(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not f:
		return ""
	var text: String = f.get_as_text()
	f.close()
	return text


static func _get_loader() -> Node:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var root := (main_loop as SceneTree).root
		if root:
			return root.get_node_or_null("BayterekLocalizationLoader")
	return null

static func _ensure_locale_in_registry(registry: LocalizationRegistry, locale: String) -> bool:
	if locale.is_empty():
		return false
	if registry.has_locale(locale):
		return true

	var parts: PackedStringArray = locale.split("_", false)
	if parts.size() < 1:
		return false

	var lang_code: String = parts[0].to_lower()
	var region_code: String = ""

	# İlk parça dil; kalan TÜM parçalar region kodu (script + ülke).
	if parts.size() > 1:
		var tail: Array[String] = []
		for i in range(1, parts.size()):
			tail.append(parts[i])
		region_code = "_".join(tail)

	var lang: LocalizationLanguage = registry.get_language(lang_code)
	if not lang:
		var meta: Dictionary = Localization.find_language(lang_code)
		lang = LocalizationLanguage.new()
		lang.code = lang_code
		lang.name = meta.get("name", lang_code)
		registry.add_language(lang)

	if not region_code.is_empty():
		if not lang.has_region(region_code):
			var rmeta: Dictionary = Localization.find_region(region_code)
			var region := LocalizationRegion.new()
			region.code = region_code
			region.name = rmeta.get("name", region_code)
			region.language_code = lang_code
			region.file_path = Service.get_locale_file_path(locale)
			lang.add_region(region)

	return registry.has_locale(locale)