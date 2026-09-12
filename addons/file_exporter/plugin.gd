@tool
extends EditorPlugin

var main_panel_frame: MarginContainer
var exporter_panel: Control

func _enter_tree():
	# Main screen frame oluştur
	main_panel_frame = MarginContainer.new()
	main_panel_frame.add_theme_constant_override(&"margin_top", 5)
	main_panel_frame.add_theme_constant_override(&"margin_left", 5)
	main_panel_frame.add_theme_constant_override(&"margin_bottom", 5)
	main_panel_frame.add_theme_constant_override(&"margin_right", 5)
	main_panel_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Editor main screen'e ekle
	get_editor_interface().get_editor_main_screen().add_child(main_panel_frame)
	
	# Exporter panelini yükle ve ekle
	exporter_panel = preload("res://addons/file_exporter/panel.tscn").instantiate()
	main_panel_frame.add_child(exporter_panel)
	
	# Başlangıçta gizle
	_make_visible(false)
	
	print("📁 File Exporter plugin yüklendi!")

func _exit_tree():
	# Temizlik
	if is_instance_valid(main_panel_frame):
		main_panel_frame.queue_free()
	if is_instance_valid(exporter_panel):
		exporter_panel.queue_free()
	
	print("📁 File Exporter plugin kaldırıldı!")

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if main_panel_frame:
		main_panel_frame.visible = visible

func _get_plugin_name() -> String:
	return "Exporter"

func _get_plugin_icon() -> Texture2D:
	# İsterseniz bir icon ekleyebilirsiniz
	return preload("res://addons/file_exporter/export_icon.svg")
