@tool
class_name LocalizationRegion
extends Resource
## A region / variant under a language (e.g. US, GB, TR).
##
## Regions are always parented by a language in the registry, but each region
## also stores its parent language code for safety (so we can build the full
## locale code without traversing the tree).
##
## Godot locale format: language_Script_COUNTRY_VARIANT
##   language — 2 or 3-letter lowercase
##   Script   — optional, 4-letter Title case (e.g. Hans, Hant)
##   COUNTRY  — optional, 2-letter UPPERCASE
##   VARIANT  — optional

@export_storage var code: String = ""             ## ISO 3166-1 alpha-2 ("US", "GB", "TR")
@export_storage var name: String = ""             ## Display name ("United States", "Türkiye")
@export_storage var language_code: String = ""    ## Parent language ("en", "tr")
@export_storage var file_path: String = ""        ## res://data/localization/languages/en_US.json

# ============================================================
# HELPERS
# ============================================================

## Returns the full locale code in Godot format, e.g. "en_US".
func get_locale() -> String:
	if language_code.is_empty():
		return code
	return "%s_%s" % [language_code, code]

func _to_string() -> String:
	return "LocalizationRegion(locale='%s', name='%s')" % [get_locale(), name]