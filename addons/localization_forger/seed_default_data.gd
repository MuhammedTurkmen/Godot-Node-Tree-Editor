@tool
extends EditorScript
## Test: Import/Export dialog boyut kontrolü.
## Çalıştır: File > Run (Ctrl+Shift+X)

const Service = preload("res://addons/localization_forger/scripts/shared/localeforge_service.gd")
const Dialog = preload("res://addons/localization_forger/scripts/editor/localeforge_import_export_dialog.gd")

func _run() -> void:
	print("=== Import/Export Dialog boyut testi ===")

	var registry: LocalizationRegistry = Service.load_registry()
	if not registry or registry.get_all_locales().is_empty():
		push_error("Registry boş — önce seed_default_data.gd çalıştır.")
		return

	var screen: Vector2i = DisplayServer.screen_get_size()
	print("Ekran: %s" % screen)

	# --- Export testi ---
	var export_dialog := Dialog.new()
	EditorInterface.get_editor_main_screen().add_child(export_dialog)
	export_dialog.open_export(registry, "user://MET/Localization/test_export.csv")

	await Engine.get_main_loop().process_frame

	print("[EXPORT] size = %s (beklenen: (760, 560))" % export_dialog.size)
	if export_dialog.size == Vector2i(760, 560):
		print("  ✓ EXPORT BOYUT DOĞRU")
	elif export_dialog.size.y >= screen.y:
		push_error("  ✗ EXPORT ekranı kaplıyor: %s" % export_dialog.size)
	else:
		push_warning("  ⚠ EXPORT beklenmedik: %s" % export_dialog.size)

	export_dialog.hide()
	export_dialog.queue_free()
	await Engine.get_main_loop().process_frame

	# --- Import testi ---
	var import_dialog := Dialog.new()
	EditorInterface.get_editor_main_screen().add_child(import_dialog)
	import_dialog.open_import(registry, "user://MET/Localization/test_export.csv")

	await Engine.get_main_loop().process_frame

	print("[IMPORT] size = %s (beklenen: (760, 560))" % import_dialog.size)
	if import_dialog.size == Vector2i(760, 560):
		print("  ✓ IMPORT BOYUT DOĞRU")
	elif import_dialog.size.y >= screen.y:
		push_error("  ✗ IMPORT ekranı kaplıyor: %s" % import_dialog.size)
	else:
		push_warning("  ⚠ IMPORT beklenmedik: %s" % import_dialog.size)

	import_dialog.hide()
	import_dialog.queue_free()

	print("=== Test tamam ===")