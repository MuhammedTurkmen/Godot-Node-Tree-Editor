@tool
extends EditorScript
## Bayterek: temizlik + test.
##
## Sırayla:
##   1. Data ve user kayıt dosyalarını temizler
##   2. Project settings (autoload + Bayterek setting'leri) temizler
##   3. Resource filesystem scan çağırır
##   4. Test suite'i çalıştırır (test_phase1.gd → run_all)
##
## addons/bayterek/ klasörü KORUNUR.
##
## Çalıştırmak için: Ctrl+Shift+X

const RESCAN_FILESYSTEM := true
const REMOVE_AUTOLOADS := true
const REMOVE_PROJECT_SETTINGS := true

const DATA_DIR := "res://data/bayterek"
const FIXTURES_DIR := "res://addons/bayterek/test_fixtures"

const AUTOLOAD_NAMES := [
	"BayterekLoader",
	"BayterekSerializer",
]

const PROJECT_SETTING_PREFIXES := [
	"addons/bayterek/",
]

const USER_FILES := [
	"user://bayterek_phase1_test.tres",
	"user://bayterek_phase1_test.tres.uid",
	"user://bayterek_serializer_test.tree",
]

const USER_DIRS := [
	"user://bayterek",
	"user://bayterek_v2",
]

# ============================================================
# RUN
# ============================================================

func _run() -> void:
	print("")
	print("╔══════════════════════════════════════════════════╗")
	print("║   Bayterek Cleanup + Test                        ║")
	print("╚══════════════════════════════════════════════════╝")
	print("")

	# --- FAZ 1: TEMİZLİK ---
	_run_cleanup()

	# --- FAZ 2: BİRKAÇ FRAME BEKLE ---
	# Editörün resource cache'i temizlesin ve dosya sistemi
	# taraması sakinleşsin diye birkaç frame bekle.
	await _wait_frames(3)

	# --- FAZ 3: TEST ---
	_run_tests()

# ============================================================
# FAZ 1 — CLEANUP
# ============================================================

func _run_cleanup() -> void:
	print("┌──────────────────────────────────────────────────┐")
	print("│  FAZ 1: Temizlik                                 │")
	print("└──────────────────────────────────────────────────┘")
	print("")

	var stats: Dictionary = {"files": 0, "dirs": 0}

	# 1. data/bayterek/
	if DirAccess.dir_exists_absolute(DATA_DIR):
		if _delete_dir_recursive(DATA_DIR, stats):
			print("  ✓ Data silindi: %s" % DATA_DIR)
		else:
			push_error("  ✗ Data silinemedi: %s" % DATA_DIR)
	else:
		print("  · Bulunamadı (atlandı): %s" % DATA_DIR)

	# 2. test_fixtures/
	if DirAccess.dir_exists_absolute(FIXTURES_DIR):
		if _delete_dir_recursive(FIXTURES_DIR, stats):
			print("  ✓ Test fixture'ları silindi: %s" % FIXTURES_DIR)
		else:
			push_error("  ✗ Test fixture'ları silinemedi: %s" % FIXTURES_DIR)
	else:
		print("  · Bulunamadı (atlandı): %s" % FIXTURES_DIR)

	# 3. user:// bilinen dosyalar
	for path in USER_FILES:
		if FileAccess.file_exists(path):
			var err: Error = DirAccess.remove_absolute(path)
			if err == OK:
				stats["files"] = int(stats["files"]) + 1
				print("  ✓ User dosyası silindi: %s" % path)
			else:
				push_error("  ✗ User dosyası silinemedi %s (err=%d)" % [path, err])
		else:
			print("  · Bulunamadı (atlandı): %s" % path)

	# 4. user:// klasörleri (tam sil)
	for dir in USER_DIRS:
		if not DirAccess.dir_exists_absolute(dir):
			print("  · Bulunamadı (atlandı): %s" % dir)
			continue
		if _delete_dir_recursive(dir, stats):
			print("  ✓ User klasörü silindi: %s" % dir)
		else:
			push_error("  ✗ User klasörü silinemedi: %s" % dir)

	# 5. Project settings
	if REMOVE_AUTOLOADS:
		_remove_autoloads()
	if REMOVE_PROJECT_SETTINGS:
		_remove_project_settings()

	# 6. Scan
	if RESCAN_FILESYSTEM:
		print("")
		print("  → Resource filesystem scan isteniyor...")
		EditorInterface.get_resource_filesystem().scan()

	print("")
	print("  Özet: %d dosya, %d klasör silindi." % [int(stats["files"]), int(stats["dirs"])])
	print("")

# ============================================================
# FAZ 3 — TEST
# ============================================================

func _run_tests() -> void:
	print("┌──────────────────────────────────────────────────┐")
	print("│  FAZ 2: Test Suite                               │")
	print("└──────────────────────────────────────────────────┘")
	print("")

	var TestPhase1 = load("res://addons/bayterek/scripts/resources/layers/test_phase1.gd")
	if not TestPhase1:
		push_error("  ✗ test_phase1.gd yüklenemedi.")
		return

	# run_all() static bir metottur — doğrudan çağır.
	TestPhase1.run_all()

# ============================================================
# FRAME WAIT
# ============================================================

## Verilen sayıda editör frame'i bekler. EditorScript'te get_tree()
## olmadığı için Engine.get_main_loop() üzerinden SceneTree'ye erişiyoruz.
func _wait_frames(count: int) -> void:
	var main_loop := Engine.get_main_loop()
	if not main_loop is SceneTree:
		return
	var tree: SceneTree = main_loop
	for i in count:
		await tree.process_frame

# ============================================================
# DIRECTORY DELETION
# ============================================================

static func _delete_dir_recursive(path: String, stats: Dictionary) -> bool:
	if not DirAccess.dir_exists_absolute(path):
		return true

	var dir := DirAccess.open(path)
	if not dir:
		push_error("  Klasör açılamadı: %s" % path)
		return false

	var subdirs: PackedStringArray = dir.get_directories()
	for sub in subdirs:
		var sub_path: String = "%s/%s" % [path, sub]
		if not _delete_dir_recursive(sub_path, stats):
			return false

	var files: PackedStringArray = dir.get_files()
	for file_name in files:
		var file_path: String = "%s/%s" % [path, file_name]
		var err: Error = DirAccess.remove_absolute(file_path)
		if err != OK:
			push_error("  Dosya silinemedi: %s (err=%d)" % [file_path, err])
			return false
		stats["files"] = int(stats["files"]) + 1

	var rm_err: Error = DirAccess.remove_absolute(path)
	if rm_err != OK:
		push_error("  Klasör silinemedi: %s (err=%d)" % [path, rm_err])
		return false

	stats["dirs"] = int(stats["dirs"]) + 1
	return true

# ============================================================
# PROJECT.GODOT CLEANUP
# ============================================================

static func _remove_autoloads() -> void:
	var removed: int = 0
	for name in AUTOLOAD_NAMES:
		var key: String = "autoload/%s" % name
		if ProjectSettings.has_setting(key):
			ProjectSettings.clear(key)
			removed += 1
			print("  ✓ Autoload kaldırıldı: %s" % name)
		else:
			print("  · Autoload yok (atlandı): %s" % name)

	if removed > 0:
		var save_err: Error = ProjectSettings.save()
		if save_err != OK:
			push_error("  project.godot kaydedilemedi (err=%d)" % save_err)

static func _remove_project_settings() -> void:
	var removed: int = 0
	var to_remove: Array[String] = []

	for prop in ProjectSettings.get_property_list():
		var prop_name: String = prop.get("name", "")
		if prop_name.is_empty():
			continue
		for prefix in PROJECT_SETTING_PREFIXES:
			if prop_name.begins_with(prefix):
				to_remove.append(prop_name)
				break

	for key in to_remove:
		ProjectSettings.clear(key)
		removed += 1
		print("  ✓ Setting kaldırıldı: %s" % key)

	if removed > 0:
		var save_err: Error = ProjectSettings.save()
		if save_err != OK:
			push_error("  project.godot kaydedilemedi (err=%d)" % save_err)
	else:
		print("  · Silinecek Bayterek setting'i yok")