@tool
extends EditorPlugin
## Bayterek plugin entry point.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

var _main_screen: BayterekMainScreen
var _distraction: bool = false

func _enter_tree() -> void:
	_register_autoloads()
	_register_settings()
	_create_main_screen()

func _exit_tree() -> void:
	if _main_screen:
		_main_screen.queue_free()
		_main_screen = null
	_remove_autoloads()

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "Bayterek"

func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("Node", Bayterek.ICON_THEME)

func _make_visible(visible: bool) -> void:
	if not _main_screen:
		return
	_main_screen.visible = visible

	if visible:
		_distraction = EditorInterface.distraction_free_mode
		EditorInterface.distraction_free_mode = true
	else:
		EditorInterface.distraction_free_mode = _distraction

	if visible and not _main_screen.initialized:
		_main_screen.init()

# --- Autoloads ---

func _register_autoloads() -> void:
	if not ProjectSettings.has_setting("autoload/BayterekLoader"):
		add_autoload_singleton("BayterekLoader", "res://addons/bayterek/scripts/shared/bayterek_loader.gd")
	if not ProjectSettings.has_setting("autoload/BayterekSerializer"):
		add_autoload_singleton("BayterekSerializer", "res://addons/bayterek/scripts/runtime/bayterek_serializer.gd")

func _remove_autoloads() -> void:
	remove_autoload_singleton("BayterekLoader")
	remove_autoload_singleton("BayterekSerializer")

# --- Project settings ---

func _register_settings() -> void:
	_register_setting(Bayterek.ROOT_PATH_SETTING, Bayterek.DEFAULT_ROOT_PATH, PROPERTY_HINT_DIR, "res://")
	_register_setting(Bayterek.REGISTRY_FILENAME_SETTING, Bayterek.DEFAULT_REGISTRY_FILENAME, PROPERTY_HINT_NONE, "")

func _register_setting(setting_name: String, default_value: Variant, hint: int, hint_string: String) -> void:
	if not ProjectSettings.has_setting(setting_name):
		ProjectSettings.set_setting(setting_name, default_value)
	ProjectSettings.set_initial_value(setting_name, default_value)
	ProjectSettings.add_property_info({
		"name": setting_name,
		"type": typeof(default_value),
		"hint": hint,
		"hint_string": hint_string,
	})

# --- Main screen ---

func _create_main_screen() -> void:
	_main_screen = BayterekMainScreen.new()
	if not _main_screen:
		push_error("Bayterek: MainScreen oluşturulamadı.")
		return

	_main_screen.name = "BayterekMainScreen"
	_main_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	EditorInterface.get_editor_main_screen().add_child(_main_screen)
	_main_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_make_visible(false)