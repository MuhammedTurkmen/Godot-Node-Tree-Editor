@tool
extends Node
## Autoload: LocaleForgeLoader
##
## Editor-side loader. Owns the LocalizationRegistry (list of languages and
## regions) and provides save/load APIs.

const Localization = preload("res://addons/localization_forger/scripts/shared/localization_forger.gd")
const Service = preload("res://addons/localization_forger/scripts/shared/localeforge_service.gd")

var _registry: LocalizationRegistry = null

func _init() -> void:
	_registry = Service.load_registry()
	print("[LocaleForgeLoader] registry loaded: %s" % _registry)

func get_registry() -> LocalizationRegistry:
	return _registry

func reload_registry() -> void:
	_registry = Service.load_registry()

func save_registry() -> Error:
	if not _registry:
		return FAILED
	return Service.save_registry(_registry)