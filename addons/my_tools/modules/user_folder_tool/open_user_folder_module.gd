@tool
extends Node
## "Open User Folder" modülü.
##
## My Tools menüsüne "Open User Data Folder" item'ı ekler ve tıklanınca
## projenin `user://` klasörünü işletim sisteminin dosya yöneticisinde açar.

var plugin: EditorPlugin
var _menu_id: int = -1

func setup(editor_plugin: EditorPlugin) -> void:
	plugin = editor_plugin

	_menu_id = plugin.add_menu_item("Open User Data Folder", _on_menu_clicked, true)

	print("📂 Open User Folder modülü yüklendi!")

func teardown() -> void:
	if _menu_id >= 0:
		plugin.remove_menu_item(_menu_id)
		_menu_id = -1

	print("📂 Open User Folder modülü kaldırıldı!")

func _on_menu_clicked() -> void:
	open_user_folder()

## `user://` klasörünü işletim sistemi dosya yöneticisinde açar.
## Önce globalize_path ile gerçek yola çevirir, klasör yoksa oluşturur.
func open_user_folder() -> void:
	var user_dir: String = ProjectSettings.globalize_path("user://")

	# Klasör yoksa oluştur (ilk çalıştırmada olmayabilir).
	if not DirAccess.dir_exists_absolute(user_dir):
		var err: Error = DirAccess.make_dir_recursive_absolute(user_dir)
		if err != OK:
			push_error("User klasörü oluşturulamadı: %s (err=%d)" % [user_dir, err])
			return

	var open_err: Error = OS.shell_open(user_dir)
	if open_err != OK:
		push_error("User klasörü açılamadı: %s (err=%d)" % [user_dir, open_err])
	else:
		print("📂 User klasörü açıldı: ", user_dir)