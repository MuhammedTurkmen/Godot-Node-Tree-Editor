@tool
extends EditorScript
## Localization — seed default data + run API test in one go.
##
## Run via File > Run (Ctrl+Shift+X) from the Godot editor while this
## script is open.
##
## What it does:
##   1. Wipes the existing registry and reseeds it with 3 languages
##      (English, Türkçe, Deutsch) and 4 locales (en-US, en-GB, tr-TR, de-DE).
##   2. Writes locale JSON files with sample keys.
##   3. Prints a summary.
##   4. Exercises the GameLocalization API by instantiating a temporary
##      instance and calling bootstrap() with the current registry.

const Localization = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization.gd")
const Service = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization_service.gd")
const GameLocalizationScript = preload("res://addons/bayterek_localization/scripts/runtime/game_localization.gd")

# ============================================================
# TEST DATA
# ============================================================

const EN_US_VALUES := {
	"greetings": "Hello",
	"world": "World",
	"opening": "Welcome to the game",
	"greeting_with_name": "Hello {player_name}!",
	"menu_play": "Play",
	"menu_options": "Options",
	"menu_quit": "Quit",
	"menu_new_game": "New Game",
	"menu_load_game": "Load Game",
	"menu_settings": "Settings",
	"menu_credits": "Credits",
	"start_hint": "Press {@menu_play} to start",
	"hud_health": "Health: {current} / {max}",
	"hud_mana": "Mana: {current} / {max}",
	"hud_level": "Level {level}",
	"hud_gold": "Gold: {amount}",
	"dialog_yes": "Yes",
	"dialog_no": "No",
	"dialog_cancel": "Cancel",
	"dialog_confirm": "Confirm",
	"error_no_save": "No save file found.",
	"error_connection_lost": "Connection to server lost.",
	"tooltip_attack": "Attack power: {value}",
	"tooltip_defense": "Defense: {value}",
}

const TR_TR_VALUES := {
	"greetings": "Merhaba",
	"world": "Dünya",
	"opening": "Oyuna hoş geldin",
	"greeting_with_name": "Merhaba {player_name}!",
	"menu_play": "Oyna",
	"menu_options": "Seçenekler",
	"menu_quit": "Çıkış",
	"menu_new_game": "Yeni Oyun",
	"menu_load_game": "Oyun Yükle",
	"menu_settings": "Ayarlar",
	"menu_credits": "Katkıda Bulunanlar",
	"start_hint": "Başlamak için {@menu_play} tuşuna bas",
	"hud_health": "Can: {current} / {max}",
	"hud_mana": "Mana: {current} / {max}",
	"hud_level": "Seviye {level}",
	"hud_gold": "Altın: {amount}",
	"dialog_yes": "Evet",
	"dialog_no": "Hayır",
	"dialog_cancel": "İptal",
	"dialog_confirm": "Onayla",
	# Deliberately missing so the fallback test has something to prove:
	# error_no_save, error_connection_lost, tooltip_attack, tooltip_defense
}

const DE_DE_VALUES := {
	"greetings": "Hallo",
	"world": "Welt",
	"opening": "Willkommen im Spiel",
	"greeting_with_name": "Hallo {player_name}!",
	"menu_play": "Spielen",
	"menu_options": "Optionen",
	"menu_quit": "Beenden",
	"menu_new_game": "Neues Spiel",
	"menu_load_game": "Spiel laden",
	"menu_settings": "Einstellungen",
	"menu_credits": "Abspann",
	"start_hint": "Drücke {@menu_play}, um zu starten",
	"hud_health": "Leben: {current} / {max}",
	"hud_mana": "Mana: {current} / {max}",
	"hud_level": "Stufe {level}",
	"hud_gold": "Gold: {amount}",
	"dialog_yes": "Ja",
	"dialog_no": "Nein",
	"dialog_cancel": "Abbrechen",
	"dialog_confirm": "Bestätigen",
	"error_no_save": "Keine Speicherdatei gefunden.",
	"error_connection_lost": "Verbindung zum Server verloren.",
	"tooltip_attack": "Angriffskraft: {value}",
	"tooltip_defense": "Verteidigung: {value}",
}

# ============================================================
# RUN
# ============================================================

func _run() -> void:
	_seed_data()
	_run_api_test()

# ============================================================
# 1) SEED DATA
# ============================================================

func _seed_data() -> void:
	print("=== Localization: seed START ===")

	var registry := Service.load_registry()

	print("Clearing existing languages...")
	registry.languages.clear()
	registry.original_locale = ""

	Service.add_language(registry, "en", "US")
	Service.add_region(registry, "en", "GB")
	Service.add_language(registry, "tr", "TR")
	Service.add_language(registry, "de", "DE")

	registry.original_locale = "en-US"

	var save_err: Error = Service.save_registry(registry)
	if save_err != OK:
		push_error("Registry save failed: %d" % save_err)
		return
	print("Registry saved: ", Localization.get_registry_path())

	_write_locale("en-US", EN_US_VALUES)
	_write_locale("en-GB", EN_US_VALUES)
	_write_locale("tr-TR", TR_TR_VALUES)
	_write_locale("de-DE", DE_DE_VALUES)

	print("--- Registry summary ---")
	print("Languages: ", registry.get_language_count())
	print("Regions:   ", registry.get_region_count())
	print("Locales:   ", registry.get_all_locales())
	print("Original:  ", registry.original_locale)
	print("=== Localization: seed DONE ===")
	print("")

# ============================================================
# 2) API TEST
# ============================================================

func _run_api_test() -> void:
	print("=== GameLocalization API test START ===")

	# Grab the registry through the autoload so we don't re-load the file.
	var loader: Node = _get_loader()
	var registry: LocalizationRegistry = null
	if loader:
		registry = loader.call("get_registry")

	if not registry:
		push_error("Cannot run API test: registry not available.")
		return

	# Fresh instance of GameLocalization (the autoload's _ready() does not
	# fire in the editor context, so we call bootstrap() ourselves).
	var gl: Node = GameLocalizationScript.new()
	gl.name = "GameLocalizationTestInstance"

	# Manually load the original locale + fallback.
	gl.call("bootstrap", registry)

	# Force debug mode on so we can see missing-arg markers.
	gl.set("debug_missing_args", true)

	# ------------------------------------------------------------
	print("Debug mode:  ", gl.get("debug_missing_args"))
	print("Available:   ", gl.call("get_available_languages"))
	print("Current:     ", gl.call("get_language"))
	print("")

	# ------------------------------------------------------------
	# Test 1: Basit key
	# ------------------------------------------------------------
	gl.call("set_language", "tr-TR")
	print("--- TR ---")
	print("greetings: ", gl.call("get_text", "greetings"))
	print("world:     ", gl.call("get_text", "world"))
	print("opening:   ", gl.call("get_text", "opening"))
	print("")

	# ------------------------------------------------------------
	# Test 2: Argümanlı key
	# ------------------------------------------------------------
	print("--- WITH ARGS ---")
	print(gl.call("get_text", "greeting_with_name", {"player_name": "Ahmet"}))
	print(gl.call("get_text", "hud_health", {"current": 75, "max": 100}))
	print(gl.call("get_text", "hud_level", {"level": 5}))
	print("")

	# ------------------------------------------------------------
	# Test 3: Eksik argüman (debug mode on → [name] markers)
	# ------------------------------------------------------------
	print("--- MISSING ARGS (debug) ---")
	print(gl.call("get_text", "greeting_with_name"))
	print(gl.call("get_text", "hud_health"))
	print("")

	# ------------------------------------------------------------
	# Test 4: translate() — metin içi {key} ve {@key} referansları
	# ------------------------------------------------------------
	print("--- TRANSLATE ---")
	print(gl.call("translate", "{greetings}, {world}. {opening}"))
	print(gl.call("translate", "{@start_hint}"))
	print(gl.call("translate", "Hello {player_name}, {@menu_play}!", {"player_name": "Ahmet"}))
	print("")

	# ------------------------------------------------------------
	# Test 5: Introspection
	# ------------------------------------------------------------
	print("--- INTROSPECTION ---")
	print("Required for greeting_with_name: ", gl.call("get_required_args", "greeting_with_name"))
	print("Required for hud_health:         ", gl.call("get_required_args", "hud_health"))
	print("Missing (no args):               ", gl.call("get_missing_args", "greeting_with_name", {}))
	print("Missing (with player_name):      ", gl.call("get_missing_args", "greeting_with_name", {"player_name": "Ahmet"}))
	print("")

	# ------------------------------------------------------------
	# Test 6: EN'e geç
	# ------------------------------------------------------------
	print("--- EN ---")
	gl.call("set_language", "en-US")
	print(gl.call("get_text", "greeting_with_name", {"player_name": "Ahmet"}))
	print(gl.call("translate", "{greetings}, {world}. {opening}"))
	print("")

	# ------------------------------------------------------------
	# Test 7: Fallback (tr-TR'de olmayan key → en-US'tan gelir)
	# ------------------------------------------------------------
	print("--- FALLBACK ---")
	gl.call("set_language", "tr-TR")
	print("tr-TR has error_no_save? ", gl.call("has_key", "error_no_save"))
	print("get_text(error_no_save):   ", gl.call("get_text", "error_no_save"))
	print("")

	# ------------------------------------------------------------
	# Test 8: has_key
	# ------------------------------------------------------------
	print("--- HAS_KEY ---")
	print("has menu_play:      ", gl.call("has_key", "menu_play"))
	print("has nonexistent:    ", gl.call("has_key", "nonexistent_key"))
	print("")

	# ------------------------------------------------------------
	# Test 9: Eksik key (tamamen yok)
	# ------------------------------------------------------------
	print("--- MISSING KEY ---")
	print(gl.call("get_text", "totally_missing_key"))
	print("")

	# Clean up.
	gl.free()

	print("=== GameLocalization API test DONE ===")

# ============================================================
# HELPERS
# ============================================================

func _write_locale(locale: String, values: Dictionary) -> void:
	var path: String = Service.get_locale_file_path(locale)
	var err: Error = Service.write_json(path, values)
	if err != OK:
		push_error("Failed to write %s (err=%d)" % [path, err])
		return
	print("Wrote %s (%d keys)" % [path, values.size()])

## Returns the BayterekLocalizationLoader autoload, or null if not present.
func _get_loader() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree:
		return null
	return tree.root.get_node_or_null("BayterekLocalizationLoader")