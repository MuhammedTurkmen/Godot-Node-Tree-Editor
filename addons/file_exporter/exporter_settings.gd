@tool
extends Object

const CONFIG_DIR := "user://MET/Exporter"
const CONFIG_PATH := "user://MET/Exporter/exporter_settings.cfg"

var config: ConfigFile
var config_path: String

func _init():
	config = ConfigFile.new()
	config_path = CONFIG_PATH
	_ensure_config_dir()
	_load_settings()

func _ensure_config_dir() -> void:
	var abs_dir: String = ProjectSettings.globalize_path(CONFIG_DIR)
	if not DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.make_dir_recursive_absolute(abs_dir)

func _load_settings():
	if not FileAccess.file_exists(config_path):
		_save_defaults()
	else:
		config.load(config_path)
		_ensure_tres_filter()

func _ensure_tres_filter():
	var filters = config.get_value("Settings", "filters", [])
	var default_filters = [
		"gd", "tres", "tscn", "uid", "csproj", "sln", "cs", 
		"cfg", "json", "txt", "png", "import", "godot", "res"
	]
	
	var needs_update = false
	
	for filter in default_filters:
		if not filters.has(filter):
			filters.append(filter)
			needs_update = true
	
	if needs_update:
		config.set_value("Settings", "filters", filters)
		config.save(config_path)

func _save_defaults():
	config.set_value("Settings", "export_path", "user://MET/Exporter/selected_files_report.txt")
	config.set_value("Settings", "save_path", "user://MET/Exporter/file_selections.cfg")
	config.set_value("Settings", "filters", [
		"gd", "tres", "tscn", "uid", "csproj", "sln", "cs", 
		"cfg", "json", "txt", "png", "import", "godot", "res"
	])
	config.set_value("Settings", "include_addons", true)
	config.save(config_path)

func get_export_path() -> String:
	return config.get_value("Settings", "export_path", "user://MET/Exporter/selected_files_report.txt")

func get_save_path() -> String:
	return config.get_value("Settings", "save_path", "user://MET/Exporter/file_selections.cfg")

func get_filters() -> Array:
	return config.get_value("Settings", "filters", [
		"gd", "tres", "tscn", "uid", "csproj", "sln", "cs", 
		"cfg", "json", "txt", "png", "import", "godot", "res"
	])

func get_include_addons() -> bool:
	return config.get_value("Settings", "include_addons", true)