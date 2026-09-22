@tool
extends EditorPlugin
## Bayterek Localization plugin entry point.
##
## Responsibilities:
##   - Register autoload singletons (GameLocalization, BayterekLocalizationLoader)
##   - Register project settings (root_path, registry_filename)
##   - Ensure data directories exist on disk
##   - Create and mount the MainScreen in the editor

const Localization = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization.gd")

var _main_screen: BayterekLocalizationMainScreen
var _distraction: bool = false

# ============================================================
# LIFECYCLE
# ============================================================

func _enter_tree() -> void:
	_register_autoloads()
	_register_settings()
	_ensure_data_directories()
	_create_main_screen()

func _exit_tree() -> void:
	if _main_screen:
		_main_screen.queue_free()
		_main_screen = null
	_remove_autoloads()

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "Localization"

func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("Translation", Localization.ICON_THEME)

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

# ============================================================
# AUTOLOADS
# ============================================================

## Registers the plugin's autoload singletons.
## Uses `add_autoload_singleton()` which also writes to ProjectSettings.
func _register_autoloads() -> void:
	var game_localization_path: String = "res://addons/bayterek_localization/scripts/runtime/game_localization.gd"
	var loader_path: String = "res://addons/bayterek_localization/scripts/shared/bayterek_localization_loader.gd"

	# Autoload names and paths.
	var required: Dictionary = {
		"GameLocalization": game_localization_path,
		"BayterekLocalizationLoader": loader_path,
	}

	for name in required.keys():
		var path: String = required[name]

		# Check if it's already registered with the SAME path — skip if so.
		var setting_key: String = "autoload/" + name
		var current_value = ProjectSettings.get_setting(setting_key, null)

		if current_value != null and String(current_value) == path:
			continue  # Already registered correctly.

		# Register (or re-register) the autoload.
		add_autoload_singleton(name, path)
		print("[BayterekLocalization] Autoload registered: %s → %s" % [name, path])

func _remove_autoloads() -> void:
	remove_autoload_singleton("GameLocalization")
	remove_autoload_singleton("BayterekLocalizationLoader")

# ============================================================
# PROJECT SETTINGS
# ============================================================

func _register_settings() -> void:
	_register_setting(Localization.ROOT_PATH_SETTING, Localization.DEFAULT_ROOT_PATH, PROPERTY_HINT_DIR, "res://")
	_register_setting(Localization.REGISTRY_FILENAME_SETTING, Localization.DEFAULT_REGISTRY_FILENAME, PROPERTY_HINT_NONE, "")

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

# ============================================================
# DATA DIRECTORIES
# ============================================================

## Ensures res://data/localization/ and res://data/localization/languages/ exist.
func _ensure_data_directories() -> void:
	var root: String = Localization.get_root_path()
	var languages: String = Localization.get_languages_dir()

	if not DirAccess.dir_exists_absolute(root):
		DirAccess.make_dir_recursive_absolute(root)
	if not DirAccess.dir_exists_absolute(languages):
		DirAccess.make_dir_recursive_absolute(languages)

# ============================================================
# MAIN SCREEN
# ============================================================

func _create_main_screen() -> void:
	_main_screen = BayterekLocalizationMainScreen.new()
	if not _main_screen:
		push_error("Bayterek Localization: MainScreen could not be created.")
		return

	_main_screen.name = "BayterekLocalizationMainScreen"
	_main_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	EditorInterface.get_editor_main_screen().add_child(_main_screen)
	_main_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_make_visible(false)