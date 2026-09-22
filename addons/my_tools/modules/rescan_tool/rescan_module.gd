@tool
extends Node

var plugin: EditorPlugin
var _menu_id: int = -1

func setup(editor_plugin: EditorPlugin):
	plugin = editor_plugin
	
	# Kendi menü item'ını ekle (separator ile birlikte)
	_menu_id = plugin.add_menu_item("Rescan Files", _on_menu_clicked, true)
	
	print("🔄 Rescan modülü yüklendi!")

func teardown():
	# Kendi menü item'ını kaldır
	if _menu_id >= 0:
		plugin.remove_menu_item(_menu_id)
		_menu_id = -1
	
	print("🔄 Rescan modülü kaldırıldı!")

func _on_menu_clicked():
	rescan()

func rescan():
	print("Dosya sistemi yeniden taranıyor...")
	var filesystem = plugin.get_editor_interface().get_resource_filesystem()
	filesystem.scan()
	print("Tarama tamamlandı!")