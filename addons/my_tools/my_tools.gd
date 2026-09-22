@tool
extends EditorPlugin

# Modül referansları
var modules: Dictionary = {}

# Ortak menü (modüller kendi item'larını ekleyecek)
var tools_menu: PopupMenu

# Menü item ID yöneticisi (modüller arası çakışma olmasın)
var _next_menu_id: int = 0

func _enter_tree():
	_setup_shared_menu()
	_load_modules()
	print("🛠️ My Tools plugin yüklendi!")

func _exit_tree():
	_unload_modules()
	
	remove_tool_menu_item("My Tools")
	if tools_menu:
		tools_menu.queue_free()
	
	print("🛠️ My Tools plugin kaldırıldı!")

# ===== ORTAK MENÜ =====
func _setup_shared_menu():
	tools_menu = PopupMenu.new()
	tools_menu.name = "My Tools"
	add_tool_submenu_item("My Tools", tools_menu)

# Modüllerin çağıracağı: yeni bir menü item'ı ekler ve ID döner
func add_menu_item(label: String, callback: Callable, separator_before: bool = false) -> int:
	if separator_before and tools_menu.item_count > 0:
		tools_menu.add_separator()
	
	var id = _next_menu_id
	_next_menu_id += 1
	tools_menu.add_item(label, id)
	tools_menu.set_item_metadata(tools_menu.item_count - 1, callback)
	return id

# Modüllerin çağıracağı: item'ı siler
func remove_menu_item(id: int):
	for i in range(tools_menu.item_count):
		if tools_menu.get_item_id(i) == id:
			tools_menu.remove_item(i)
			return

func _on_menu_pressed(id: int):
	# Metadata'daki Callable'ı çağır
	for i in range(tools_menu.item_count):
		if tools_menu.get_item_id(i) == id:
			var callback = tools_menu.get_item_metadata(i)
			if callback is Callable and callback.is_valid():
				callback.call()
			return

# ===== MODÜL YÖNETİMİ =====
func _load_modules():
	tools_menu.id_pressed.connect(_on_menu_pressed)
	
	_register_module("rescan", "res://addons/my_tools/modules/rescan_tool/rescan_module.gd")
	_register_module("snapshot", "res://addons/my_tools/modules/snapshot_tool/snapshot_module.gd")
	_register_module("user_folder", "res://addons/my_tools/modules/user_folder_tool/open_user_folder_module.gd")

func _register_module(module_name: String, script_path: String):
	var ModuleScript = load(script_path)
	if not ModuleScript:
		push_error("Modül yüklenemedi: " + script_path)
		return
	var module = ModuleScript.new()
	module.name = module_name.capitalize() + "Module"
	add_child(module)
	module.setup(self)
	modules[module_name] = module

func _unload_modules():
	for module_name in modules.keys():
		var module = modules[module_name]
		if is_instance_valid(module):
			module.teardown()
			module.queue_free()
	modules.clear()

func get_module(module_name: String) -> Node:
	return modules.get(module_name, null)