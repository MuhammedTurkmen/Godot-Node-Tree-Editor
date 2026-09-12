@tool
extends Object

var config: ConfigFile
var config_path: String

func _init():
	config = ConfigFile.new()
	config_path = "user://exporter_settings.cfg"
	_load_settings()

func _load_settings():
	if not FileAccess.file_exists(config_path):
		_save_defaults()
	else:
		config.load(config_path)
		# Eski config'de tres yoksa ekle
		_ensure_tres_filter()

func _ensure_tres_filter():
	var filters = config.get_value("Settings", "filters", [])
	var default_filters = [
		"gd", "tres", "tscn", "uid", "csproj", "sln", "cs", 
		"cfg", "json", "txt", "png", "import", "godot", "res"
	]
	
	var needs_update = false
	
	# Eksik filtreleri ekle
	for filter in default_filters:
		if not filters.has(filter):
			filters.append(filter)
			needs_update = true
	
	if needs_update:
		config.set_value("Settings", "filters", filters)
		config.save(config_path)

func _save_defaults():
	config.set_value("Settings", "export_path", "user://selected_files_report.txt")
	config.set_value("Settings", "save_path", "user://file_selections.cfg")
	config.set_value("Settings", "filters", [
		"gd", "tres", "tscn", "uid", "csproj", "sln", "cs", 
		"cfg", "json", "txt", "png", "import", "godot", "res"
	])
	config.set_value("Settings", "include_addons", true)
	config.save(config_path)

func get_export_path() -> String:
	return config.get_value("Settings", "export_path", "user://selected_files_report.txt")

func get_save_path() -> String:
	return config.get_value("Settings", "save_path", "user://file_selections.cfg")

func get_filters() -> Array:
	return config.get_value("Settings", "filters", [
		"gd", "tres", "tscn", "uid", "csproj", "sln", "cs", 
		"cfg", "json", "txt", "png", "import", "godot", "res"
	])

func get_include_addons() -> bool:
	return config.get_value("Settings", "include_addons", true)
