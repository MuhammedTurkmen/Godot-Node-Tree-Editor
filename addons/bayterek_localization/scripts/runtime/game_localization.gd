@tool
extends Node
## Autoload: GameLocalization
##
## Runtime translation API. Owns the active locale, resolves keys, and
## applies format-string placeholders like "{player_name}".
##
## STUB for Step 1. Full implementation in Step 6.
##
## Planned API:
##   GameLocalization.set_language("tr-TR") -> void
##   GameLocalization.get_language() -> String
##   GameLocalization.get_text(key: String, args: Dictionary = {}) -> String
##   GameLocalization.has_key(key: String) -> bool

var _current_locale: String = ""
var _translations: Dictionary = {}   # locale -> { key: value }
var _original_locale: String = ""    # fallback

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	print("[GameLocalization] ready (stub).")

func set_language(_locale: String) -> void:
	push_warning("[GameLocalization] set_language() not implemented yet (Step 6).")

func get_language() -> String:
	return _current_locale

func get_text(_key: String, _args: Dictionary = {}) -> String:
	push_warning("[GameLocalization] get_text() not implemented yet (Step 6).")
	return ""

func has_key(_key: String) -> bool:
	return false
