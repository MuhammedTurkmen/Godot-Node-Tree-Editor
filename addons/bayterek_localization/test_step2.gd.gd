@tool
extends EditorScript
## Adım 2 smoke testi. Ctrl+Shift+X ile çalıştır.

const Localization = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization.gd")
const Service = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization_service.gd")
const Format = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization_format_string.gd")

func _run() -> void:
	print("=== ADIM 2 TESTİ ===")

	# --- Format string ---
	var ph := Format.extract_placeholders("Hello {player_name}, welcome to {world}!")
	print("placeholders: ", ph)
	assert(ph.size() == 2)
	assert(ph[0] == "player_name")
	assert(ph[1] == "world")

	var out := Format.format("Hello {player_name}, welcome to {world}!", {"player_name": "Ahmet", "world": "Bayterek"})
	print("formatted: ", out)
	assert(out == "Hello Ahmet, welcome to Bayterek!")

	var cmp := Format.compare_placeholders("Hi {a} and {b}", "Merhaba {a}")
	print("compare: ", cmp)
	assert(cmp["missing"].size() == 1 and cmp["missing"][0] == "b")
	assert(cmp["extra"].size() == 0)

	# --- Registry temiz başlat ---
	# Önceki testten kalma dosyaları temizle (güvenli reset):
	var reg_path := Localization.get_registry_path()
	if FileAccess.file_exists(reg_path):
		DirAccess.remove_absolute(reg_path)

	var registry := Service.load_registry()
	assert(registry != null)
	print("empty registry: ", registry)

	# --- Dil ekle (region'sız) ---
	var en := Service.add_language(registry, "en")
	assert(en != null)
	assert(en.code == "en")
	assert(en.get_locales() == PackedStringArray(["en"]))
	assert(registry.original_locale == "en")
	print("added 'en': ", en)

	# --- en'e US region'ı ekle ---
	var us := Service.add_region(registry, "en", "US")
	assert(us != null)
	assert(us.get_locale() == "en-US")
	assert(en.get_locales() == PackedStringArray(["en-US"]))
	assert(registry.original_locale == "en-US")
	print("added 'en-US': ", us)

	# --- en'e GB region'ı ekle ---
	var gb := Service.add_region(registry, "en", "GB")
	assert(gb != null)
	assert(en.get_locales().size() == 2)
	print("added 'en-GB': ", gb)

	# --- tr-TR ekle ---
	var tr := Service.add_language(registry, "tr", "TR")
	assert(tr != null)
	assert(tr.get_locales() == PackedStringArray(["tr-TR"]))
	print("added 'tr-TR': ", tr)

	# --- JSON yaz/oku ---
	var tr_path := Service.get_locale_file_path("tr-TR")
	print("tr-TR path: ", tr_path)
	Service.write_json(tr_path, {
		"greeting": "Merhaba {player_name}!",
		"menu_play": "Oyna",
		"menu_options": "Seçenekler",
	})
	var read_back := Service.read_json(tr_path)
	print("tr-TR content: ", read_back)
	assert(read_back.size() == 3)
	assert(read_back["menu_play"] == "Oyna")

	# --- Registry kaydet + reload ---
	Service.save_registry(registry)
	print("registry saved to: ", reg_path)

	var reloaded := Service.load_registry()
	assert(reloaded.get_language_count() == 2)
	assert(reloaded.get_region_count() == 3)
	assert(reloaded.original_locale == "en-US")
	print("reloaded registry: ", reloaded)
	print("all locales: ", reloaded.get_all_locales())

	print("=== TÜM TESTLER GEÇTİ ===")