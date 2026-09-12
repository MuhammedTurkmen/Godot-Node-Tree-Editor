@tool
extends PanelContainer

var settings: Object
var file_tree: Tree
var select_all_button: Button
var deselect_all_button: Button
var export_button: Button
var copy_logs_button: Button
var info_label: Label
var filter_container: HBoxContainer
var search_container: HBoxContainer
var search_input: LineEdit
var addons_checkbox: CheckBox
var filter_menus: Dictionary = {}  # Kategori -> MenuButton
var clear_buttons: Dictionary = {}  # Kategori -> Temizleme butonu
var filter_selections: Dictionary = {}  # Kategori -> Seçili uzantılar
var save_path: String
var export_path: String

# Filtre kategorileri
var filter_categories = {
	"godot": {
		"label": "Godot",
		"extensions": ["tres", "tscn", "godot", "res", "uid"]
	},
	"scripts": {
		"label": "Script",
		"extensions": ["gd", "cs", "csproj", "sln"]
	},
	"images": {
		"label": "Görsel",
		"extensions": ["png", "svg", "jpg", "jpeg", "webp", "bmp"]
	},
	"audio": {
		"label": "Ses",
		"extensions": ["wav", "ogg", "mp3", "flac"]
	},
	"other": {
		"label": "Diğer",
		"extensions": ["cfg", "json", "txt", "md", "import", "kanban", "issues"]
	}
}

func _ready():
	# Settings'i yükle
	var SettingsClass = load("res://addons/file_exporter/exporter_settings.gd")
	settings = SettingsClass.new()
	save_path = settings.get_save_path()
	export_path = settings.get_export_path()
	
	# Node'ları bul
	file_tree = get_node("VBox/Tree")
	select_all_button = get_node("VBox/HBox/SelectAll")
	deselect_all_button = get_node("VBox/HBox/DeselectAll")
	copy_logs_button = get_node("VBox/HBox/CopyLogs")
	export_button = get_node("VBox/HBox/Export")
	info_label = get_node("VBox/HBox/Info")
	filter_container = get_node("VBox/FilterContainer")
	search_container = get_node("VBox/SearchContainer")
	
	# Butonları bağla
	select_all_button.pressed.connect(_on_select_all)
	deselect_all_button.pressed.connect(_on_deselect_all)
	copy_logs_button.pressed.connect(_on_copy_logs)
	export_button.pressed.connect(_on_export)
	file_tree.item_edited.connect(_on_item_edited)
	
	# Arama ve filtreleri oluştur
	_create_filter_menus()
	_create_search_bar()
	
	# Dosyaları yükle
	_populate_tree()
	_load_selections()
	
	info_label.text = "✅ Hazır!"

func _create_filter_menus():
	# Eski widget'ları temizle
	for child in filter_container.get_children():
		child.queue_free()
	
	filter_menus.clear()
	clear_buttons.clear()
	filter_selections.clear()
	
	# Addons checkbox'ı
	addons_checkbox = CheckBox.new()
	addons_checkbox.text = "Addons"
	addons_checkbox.button_pressed = settings.get_include_addons()
	addons_checkbox.pressed.connect(_on_filter_changed)
	filter_container.add_child(addons_checkbox)
	
	# Ayırıcı
	var separator = VSeparator.new()
	filter_container.add_child(separator)
	
	# Her kategori için dropdown menü + temizle butonu
	for category_key in filter_categories.keys():
		var category = filter_categories[category_key]
		
		# Kategori için yatay kutu (menü + temizle butonu)
		var category_box = HBoxContainer.new()
		category_box.add_theme_constant_override("separation", 2)
		filter_container.add_child(category_box)
		
		# Dropdown menü
		var menu_button = MenuButton.new()
		menu_button.text = category.label + " ▾"
		menu_button.switch_on_hover = true
		
		var popup = menu_button.get_popup()
		popup.hide_on_checkable_item_selection = false
		
		# Kategori başlığı
		popup.add_item(category.label, -1)
		popup.set_item_disabled(0, true)
		popup.add_separator()
		
		# Uzantıları ekle - checkbox olarak
		for ext in category.extensions:
			popup.add_check_item("." + ext)
			var index = popup.item_count - 1
			popup.set_item_checked(index, true)
		
		popup.id_pressed.connect(_on_filter_item_selected.bind(category_key))
		category_box.add_child(menu_button)
		
		# Temizleme butonu (küçük x)
		var clear_button = Button.new()
		clear_button.text = "✕"
		clear_button.tooltip_text = "Tüm " + category.label + " seçimlerini kaldır"
		clear_button.custom_minimum_size.x = 25
		clear_button.pressed.connect(_on_clear_category.bind(category_key))
		category_box.add_child(clear_button)
		
		filter_menus[category_key] = menu_button
		clear_buttons[category_key] = clear_button
		filter_selections[category_key] = category.extensions.duplicate()  # Başlangıçta hepsi seçili
		
		# Kategoriler arası boşluk
		if category_key != filter_categories.keys()[-1]:
			var space = Control.new()
			space.custom_minimum_size.x = 10
			filter_container.add_child(space)

func _create_search_bar():
	# Eski widget'ları temizle
	for child in search_container.get_children():
		child.queue_free()
	
	var label = Label.new()
	label.text = "🔍"
	search_container.add_child(label)
	
	search_input = LineEdit.new()
	search_input.placeholder_text = "Dosya adı ara..."
	search_input.size_flags_horizontal = SIZE_EXPAND_FILL
	search_input.text_changed.connect(_on_search_changed)
	search_container.add_child(search_input)
	
	# Temizle butonu
	var clear_button = Button.new()
	clear_button.text = "Temizle"
	clear_button.pressed.connect(_on_clear_search)
	search_container.add_child(clear_button)

func _on_filter_item_selected(id: int, category_key: String):
	var menu_button = filter_menus[category_key]
	var popup = menu_button.get_popup()
	var category = filter_categories[category_key]
	
	# İlk 2 item başlık ve separator
	var item_text = popup.get_item_text(id)
	var extension = item_text.trim_prefix(".")
	
	if category.extensions.has(extension):
		var is_checked = popup.is_item_checked(id)
		popup.set_item_checked(id, not is_checked)
		
		# Seçimleri güncelle
		_update_filter_selections(category_key)
		
		_on_filter_changed()

func _on_clear_category(category_key: String):
	# O kategorinin tüm seçimlerini kaldır
	var menu_button = filter_menus[category_key]
	var popup = menu_button.get_popup()
	var category = filter_categories[category_key]
	
	# Tüm checkbox'ları kaldır
	for i in range(2, popup.item_count):  # Başlık ve separator'ı atla
		popup.set_item_checked(i, false)
	
	# Seçimleri güncelle
	filter_selections[category_key].clear()
	_update_menu_text(category_key)
	
	_on_filter_changed()

func _update_filter_selections(category_key: String):
	var menu_button = filter_menus[category_key]
	var popup = menu_button.get_popup()
	
	# Seçimleri güncelle
	filter_selections[category_key].clear()
	for i in range(2, popup.item_count):  # Başlık ve separator'ı atla
		var ext = popup.get_item_text(i).trim_prefix(".")
		if popup.is_item_checked(i):
			filter_selections[category_key].append(ext)
	
	# Menü metnini güncelle
	_update_menu_text(category_key)

func _update_menu_text(category_key: String):
	var menu_button = filter_menus[category_key]
	var category = filter_categories[category_key]
	var selected_count = filter_selections[category_key].size()
	var total_count = category.extensions.size()
	
	if selected_count == total_count:
		menu_button.text = category.label + " ▾"
	elif selected_count == 0:
		menu_button.text = category.label + " (0) ▾"
	else:
		menu_button.text = category.label + " (" + str(selected_count) + ") ▾"

func _on_filter_changed():
	_populate_tree()
	_load_selections()

func _on_search_changed(text: String):
	_populate_tree()
	_load_selections()

func _on_clear_search():
	if search_input:
		search_input.text = ""
	_populate_tree()
	_load_selections()

func _is_extension_filtered(extension: String) -> bool:
	# Her kategori için kontrol et
	for category_key in filter_categories.keys():
		var category = filter_categories[category_key]
		if category.extensions.has(extension):
			return filter_selections[category_key].has(extension)
	
	# Kategori dışı uzantılar için varsayılan olarak göster
	return true

func _is_filename_matches_search(file_name: String) -> bool:
	if not search_input or search_input.text.strip_edges() == "":
		return true
	
	var search_text = search_input.text.strip_edges().to_lower()
	return file_name.to_lower().contains(search_text)

func _populate_tree():
	file_tree.clear()
	
	file_tree.columns = 2
	file_tree.set_column_title(0, "Dosya Adı")
	file_tree.set_column_title(1, "✓")
	file_tree.set_column_expand(0, true)
	file_tree.set_column_expand(1, false)
	
	var root = file_tree.create_item()
	root.set_text(0, "📁 Proje Dosyaları")
	root.set_editable(0, false)
	
	_scan_folder("res://", root)

func _scan_folder(path: String, parent_item: TreeItem):
	var dir = DirAccess.open(path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		
		var full_path = path.path_join(file_name)
		var is_dir = dir.current_is_dir()
		
		# .godot klasörünü her zaman atla
		if is_dir and file_name == ".godot":
			file_name = dir.get_next()
			continue
		
		# addons klasörünü checkbox durumuna göre dahil et
		if is_dir and file_name == "addons" and not addons_checkbox.button_pressed:
			file_name = dir.get_next()
			continue
		
		# Dosya adı arama filtresi
		if not is_dir and not _is_filename_matches_search(file_name):
			file_name = dir.get_next()
			continue
		
		if not is_dir:
			var extension = file_name.get_extension()
			if not _is_extension_filtered(extension):
				file_name = dir.get_next()
				continue
		
		var item = file_tree.create_item(parent_item)
		item.set_text(0, file_name)
		item.set_editable(0, false)
		item.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
		item.set_editable(1, true)
		item.set_meta("path", full_path)
		item.set_meta("is_dir", is_dir)
		item.set_meta("name", file_name)
		
		if is_dir:
			_scan_folder(full_path, item)
		
		file_name = dir.get_next()

func _on_item_edited():
	var item = file_tree.get_edited()
	if not item:
		return
	
	var column = file_tree.get_edited_column()
	if column != 1:
		return
	
	var is_dir = item.get_meta("is_dir", false)
	if is_dir:
		var checked = item.is_checked(1)
		_set_all_children_checked(item, checked)

func _set_all_children_checked(item: TreeItem, checked: bool):
	if not item:
		return
	
	var child = item.get_first_child()
	while child:
		if not child.get_meta("is_dir", false):
			child.set_checked(1, checked)
		else:
			_set_all_children_checked(child, checked)
		child = child.get_next()

func _load_selections():
	var config = ConfigFile.new()
	if config.load(save_path) == OK:
		for section in config.get_sections():
			var path = config.get_value(section, "path", "")
			var selected = config.get_value(section, "selected", false)
			if path != "":
				_set_item_selected(path, selected)

func _set_item_selected(path: String, selected: bool):
	_set_item_selected_recursive(file_tree.get_root(), path, selected)

func _set_item_selected_recursive(item: TreeItem, path: String, selected: bool):
	if not item:
		return
	
	var item_path = item.get_meta("path", "")
	if item_path == path:
		item.set_checked(1, selected)
		return
	
	var child = item.get_first_child()
	while child:
		_set_item_selected_recursive(child, path, selected)
		child = child.get_next()

func _on_select_all():
	_set_all_checked(file_tree.get_root(), true)
	info_label.text = "✅ Tüm dosyalar seçildi"

func _on_deselect_all():
	_set_all_checked(file_tree.get_root(), false)
	info_label.text = "❌ Tüm seçimler kaldırıldı"

func _set_all_checked(item: TreeItem, checked: bool):
	if not item:
		return
	
	item.set_checked(1, checked)
	
	var child = item.get_first_child()
	while child:
		_set_all_checked(child, checked)
		child = child.get_next()

func _on_export():
	_save_selections()
	
	var selected_files = _collect_selected_files(file_tree.get_root())
	
	if selected_files.is_empty():
		info_label.text = "⚠️ Hiç dosya seçilmedi!"
		return
	
	_export_files(selected_files)

func _collect_selected_files(item: TreeItem) -> Array:
	var selected_files = []
	_collect_selected_recursive(item, selected_files)
	return selected_files

func _collect_selected_recursive(item: TreeItem, selected_files: Array):
	if not item:
		return
	
	var path = item.get_meta("path", "")
	var is_dir = item.get_meta("is_dir", false)
	
	if path != "" and not is_dir and item.is_checked(1):
		selected_files.append({
			"path": path,
			"name": item.get_meta("name", path.get_file())
		})
	
	var child = item.get_first_child()
	while child:
		_collect_selected_recursive(child, selected_files)
		child = child.get_next()

func _export_files(selected_files: Array):
	var report = ""
	var found_files = []
	var not_found_files = []
	
	for file_data in selected_files:
		var file = FileAccess.open(file_data.path, FileAccess.READ)
		if file:
			found_files.append(file_data)
			file.close()
		else:
			not_found_files.append(file_data)
	
	report += "===== SEÇİLEN DOSYALAR =====\n"
	report += "Toplam: " + str(selected_files.size()) + " dosya\n"
	
	report += "Bulunan: " + str(found_files.size()) + " dosya\n"
	if found_files.is_empty():
		report += "- yok\n"
	else:
		for file_data in found_files:
			report += "- " + file_data.name + "\n"
	
	report += "Bulunamayan: " + str(not_found_files.size()) + " dosya\n"
	if not_found_files.is_empty():
		report += "- yok\n"
	else:
		for file_data in not_found_files:
			report += "- " + file_data.name + "\n"
	
	var time = Time.get_time_dict_from_system()
	report += "Tarih: " + str(time.hour).pad_zeros(2) + ":" + str(time.minute).pad_zeros(2) + "\n"
	report += "--------------------------------------------\n\n"
	
	for file_data in found_files:
		var file = FileAccess.open(file_data.path, FileAccess.READ)
		if file:
			var extension = file_data.path.get_extension().to_lower()
			report += "=== " + file_data.name + " ===\n\n"
			
			# .tres ve .res dosyaları için özel işleme
			if extension == "tres" or extension == "res":
				report += _process_tres_file(file_data.path, file)
			else:
				report += file.get_as_text()
			
			report += "\n\n\n"
			file.close()
	
	report += "=== folder tree ===\n\n"
	
	# Tüm proje yapısını tara
	var tree_dict = {}
	_scan_full_project_tree("res://", tree_dict)
	
	report += _tree_to_string(tree_dict, 0) + "\n"
	
	var output_file = FileAccess.open(export_path, FileAccess.WRITE)
	if output_file:
		output_file.store_string(report)
		output_file.close()
		info_label.text = "✅ " + str(selected_files.size()) + " dosya dışa aktarıldı"
		OS.shell_open(ProjectSettings.globalize_path(export_path))
	else:
		info_label.text = "❌ Rapor kaydedilemedi!"

func _process_tres_file(path: String, file: FileAccess) -> String:
	var content = ""
	
	file.seek(0)
	var header = file.get_buffer(4)
	file.seek(0)
	
	var is_binary = false
	for byte in header:
		if byte < 32 or byte > 126:
			is_binary = true
			break
	
	if is_binary:
		content += "[BINARY FORMAT - Cannot display content]\n"
		content += "File: " + path + "\n"
		content += "Size: " + str(file.get_length()) + " bytes\n"
	else:
		content = file.get_as_text()
		content = _fix_resource_references(content)
	
	return content

func _fix_resource_references(content: String) -> String:
	var lines = content.split("\n")
	var fixed_lines = []
	
	for line in lines:
		if "uid://" in line:
			var parts = line.split("uid://")
			if parts.size() > 1:
				var uid = parts[1].split("\"")[0]
				line = line.replace("uid://" + uid, "uid://" + uid.substr(0, 8) + "...")
		
		fixed_lines.append(line)
	
	return "\n".join(fixed_lines)

func _scan_full_project_tree(path: String, tree: Dictionary):
	var dir = DirAccess.open(path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		
		var full_path = path.path_join(file_name)
		var is_dir = dir.current_is_dir()
		
		if is_dir and file_name == ".godot":
			file_name = dir.get_next()
			continue
		
		if is_dir and file_name == "addons" and not addons_checkbox.button_pressed:
			file_name = dir.get_next()
			continue
		
		if is_dir:
			tree[file_name] = {}
			_scan_full_project_tree(full_path, tree[file_name])
		else:
			tree[file_name] = true
		
		file_name = dir.get_next()

func _tree_to_string(tree: Dictionary, indent: int) -> String:
	var result = ""
	var spaces = ""
	for i in range(indent):
		spaces += "    "
	
	var folders = []
	var files = []
	
	for key in tree.keys():
		if tree[key] is Dictionary:
			folders.append(key)
		else:
			files.append(key)
	
	folders.sort()
	files.sort()
	
	for folder in folders:
		result += spaces + "📁 " + folder + "/\n"
		result += _tree_to_string(tree[folder], indent + 1)
	
	for file in files:
		result += spaces + "📄 " + file + "\n"
	
	return result

func _save_selections():
	var config = ConfigFile.new()
	_save_selections_recursive(file_tree.get_root(), config, 0)
	config.save(save_path)

func _save_selections_recursive(item: TreeItem, config: ConfigFile, index: int) -> int:
	if not item:
		return index
	
	var path = item.get_meta("path", "")
	if path != "":
		config.set_value("item_" + str(index), "path", path)
		config.set_value("item_" + str(index), "selected", item.is_checked(1))
		index += 1
	
	var child = item.get_first_child()
	while child:
		index = _save_selections_recursive(child, config, index)
		child = child.get_next()
	
	return index
	
func _on_copy_logs():
	var log_path := "user://logs/godot.log"
	
	if FileAccess.file_exists(log_path):
		var file := FileAccess.open(log_path, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			file.close()
			
			if content.strip_edges().is_empty():
				info_label.text = "⚠️ Log dosyası boş!"
			else:
				DisplayServer.clipboard_set(content)
				info_label.text = "📋 Hata logları panoya kopyalandı!"
		else:
			info_label.text = "❌ Log dosyası okunamadı!"
	else:
		info_label.text = "⚠️ Log dosyası bulunamadı! (File Logging kapalı olabilir)"