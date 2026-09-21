@tool
class_name LocalizationLanguage
extends Resource
## A language entry (e.g. English, Türkçe).
##
## A language can optionally have regions. If it has no regions, the language
## itself acts as the single locale (e.g. "en" -> en.json).
##
## If it has regions, each region produces a locale code like "en-US".

@export_storage var code: String = ""             ## ISO 639-1 ("en", "tr", "de")
@export_storage var name: String = ""             ## Display name ("English", "Türkçe")
@export_storage var regions: Array[LocalizationRegion] = []

# ============================================================
# HELPERS
# ============================================================

func has_region(region_code: String) -> bool:
	for r in regions:
		if r and r.code == region_code:
			return true
	return false

func get_region(region_code: String) -> LocalizationRegion:
	for r in regions:
		if r and r.code == region_code:
			return r
	return null

func add_region(region: LocalizationRegion) -> bool:
	if not region:
		return false
	if has_region(region.code):
		return false
	regions.append(region)
	return true

func remove_region(region_code: String) -> bool:
	for i in regions.size():
		if regions[i] and regions[i].code == region_code:
			regions.remove_at(i)
			return true
	return false

## Returns all locales produced by this language.
##   - If regions is empty: returns [code]  (e.g. ["en"])
##   - Otherwise: returns ["en-US", "en-GB", ...]
func get_locales() -> PackedStringArray:
	var out: PackedStringArray = []
	if regions.is_empty():
		out.append(code)
	else:
		for r in regions:
			if r:
				out.append("%s-%s" % [code, r.code])
	return out

func _to_string() -> String:
	return "LocalizationLanguage(code='%s', name='%s', regions=%d)" % [code, name, regions.size()]