@tool
extends Node
## Autoload: BayterekLocalizationLoader
##
## Editor-side loader. Owns the LocalizationRegistry (list of languages and
## regions) and provides save/load APIs.

const Localization = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization.gd")
const Service = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization_service.gd")

var _registry: LocalizationRegistry = null

func _init() -> void:
	_registry = Service.load_registry()
	print("[BayterekLocalizationLoader] registry loaded: %s" % _registry)

func get_registry() -> LocalizationRegistry:
	return _registry

func reload_registry() -> void:
	_registry = Service.load_registry()

func save_registry() -> Error:
	if not _registry:
		return FAILED
	return Service.save_registry(_registry)