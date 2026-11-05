@tool
extends SceneTree
## Bayterek → SkillTree / LocaleForge otomatik rename script'i.
##
## KULLANIM (Godot KAPALIYKEN, proje kökünde):
##   godot --headless --script rename_bayterek.gd

const DRY_RUN := false  # İşlem bittiğinde true yapıp sadece rapor alabilirsin.

# --- Klasör rename eşlemeleri ---
const FOLDER_MAP := {
	"res://addons/bayterek": "res://addons/skill_tree_forger",
	"res://addons/bayterek_localization": "res://addons/localization_forger",
}

# --- Sınıf/identifier değişimleri (UZUNDAN KISAYA sıralı!) ---
const IDENTIFIER_MAP := {
	# ===== LOCALIZATION (önce bunlar, çünkü daha uzun) =====
	"BayterekLocalizationImportExportDialog": "LocaleForgeImportExportDialog",
	"BayterekLocalizationPlaceholderHighlighter": "LocaleForgePlaceholderHighlighter",
	"BayterekLocalizationTranslationField": "LocaleForgeTranslationField",
	"BayterekLocalizationPreviewPanel": "LocaleForgePreviewPanel",
	"BayterekLocalizationLanguageDialog": "LocaleForgeLanguageDialog",
	"BayterekLocalizationPolyglotImport": "LocaleForgePolyglotImport",
	"BayterekLocalizationRegionDialog": "LocaleForgeRegionDialog",
	"BayterekLocalizationUndoHelper": "LocaleForgeUndoHelper",
	"BayterekLocalizationKeyCompleter": "LocaleForgeKeyCompleter",
	"BayterekLocalizationKeyRow": "LocaleForgeKeyRow",
	"BayterekLocalizationMainScreen": "LocaleForgeMainScreen",
	"BayterekLocalizationFormatString": "LocaleForgeFormatString",
	"BayterekLocalizationBrowser": "LocaleForgeBrowser",
	"BayterekLocalizationEditor": "LocaleForgeEditor",
	"BayterekLocalizationFuzzy": "LocaleForgeFuzzy",
	"BayterekLocalizationService": "LocaleForgeService",
	"BayterekLocalizationLoader": "LocaleForgeLoader",
	"BayterekLocalizationCsv": "LocaleForgeCsv",
	"BayterekLocalization": "LocaleForge",

	# ===== SKILL TREE (uzundan kısaya) =====
	"BayterekSkillTreeData": "SkillTreeData",
	"BayterekSkillTreeJson": "SkillTreeJson",
	"BayterekInspectorExportedFields": "SkillTreeInspectorExportedFields",
	"BayterekInspectorAttributes": "SkillTreeInspectorAttributes",
	"BayterekInspectorConnections": "SkillTreeInspectorConnections",
	"BayterekLayerStateTextures": "SkillTreeLayerStateTextures",
	"BayterekLayerStateColors": "SkillTreeLayerStateColors",
	"BayterekLayerTransformForm": "SkillTreeLayerTransformForm",
	"BayterekLayerPreviewPanel": "SkillTreeLayerPreviewPanel",
	"BayterekLayerPreview": "SkillTreeLayerPreview",
	"BayterekLayerEditor": "SkillTreeLayerEditor",
	"BayterekLayerTransform": "SkillTreeLayerTransform",
	"BayterekLayerNode": "SkillTreeLayerNode",
	"BayterekLayer": "SkillTreeLayer",
	"BayterekAttributesEditor": "SkillTreeAttributesEditor",
	"BayterekNodeEditorScreen": "SkillTreeNodeEditorScreen",
	"BayterekNodeSearch": "SkillTreeNodeSearch",
	"BayterekNodeAnimator": "SkillTreeNodeAnimator",
	"BayterekNodeButton": "SkillTreeNodeButton",
	"BayterekNodeGroup": "SkillTreeNodeGroup",
	"BayterekNodeDesign": "SkillTreeNodeDesign",
	"BayterekNode": "SkillTreeNode",
	"BayterekAllocationService": "SkillTreeAllocationService",
	"BayterekConnectionsService": "SkillTreeConnectionsService",
	"BayterekDecorationsService": "SkillTreeDecorationsService",
	"BayterekDesignService": "SkillTreeDesignService",
	"BayterekGroupFramesService": "SkillTreeGroupFramesService",
	"BayterekNodesService": "SkillTreeNodesService",
	"BayterekPrefabsService": "SkillTreePrefabsService",
	"BayterekBaseService": "SkillTreeBaseService",
	"BayterekRuntimeAnimator": "SkillTreeRuntimeAnimator",
	"BayterekAnimatorBuilder": "SkillTreeAnimatorBuilder",
	"BayterekProceduralGrid": "SkillTreeProceduralGrid",
	"BayterekTreeState": "SkillTreeState",
	"BayterekTreeView": "SkillTreeView",
	"BayterekTreeUI": "SkillTreeUI",
	"BayterekTree": "SkillTree",
	"BayterekRegistry": "SkillTreeRegistry",
	"BayterekAttribute": "SkillTreeAttribute",
	"BayterekGroupFrame": "SkillTreeGroupFrame",
	"BayterekGroupDialog": "SkillTreeGroupDialog",
	"BayterekGroup": "SkillTreeGroup",
	"BayterekBuilder": "SkillTreeBuilder",
	"BayterekLoader": "SkillTreeLoader",
	"BayterekSerializer": "SkillTreeSerializer",
	"BayterekAudioManager": "SkillTreeAudioManager",
	"BayterekPrefabThumbnail": "SkillTreePrefabThumbnail",
	"BayterekPrefabCard": "SkillTreePrefabCard",
	"BayterekPrefabsBar": "SkillTreePrefabsBar",
	"BayterekPrefab": "SkillTreePrefab",
	"BayterekConnection": "SkillTreeConnection",
	"BayterekLine2D": "SkillTreeLine2D",
	"BayterekLineData": "SkillTreeLineData",
	"BayterekCamera": "SkillTreeCamera",
	"BayterekTooltip": "SkillTreeTooltip",
	"BayterekLogger": "SkillTreeLogger",
	"BayterekArrowOverlay": "SkillTreeArrowOverlay",
	"BayterekTextureLayer": "SkillTreeTextureLayer",
	"BayterekToast": "SkillTreeToast",
	"BayterekRenameDialog": "SkillTreeRenameDialog",
	"BayterekFuzzySearch": "SkillTreeFuzzySearch",
	"BayterekPicker": "SkillTreePicker",
	"BayterekDesignListPanel": "SkillTreeDesignListPanel",
	"BayterekExportHelper": "SkillTreeExportHelper",
	"BayterekBrowser": "SkillTreeBrowser",
	"BayterekEditorContext": "SkillTreeEditorContext",
	"BayterekEditor": "SkillTreeEditor",
	"BayterekHierarchy": "SkillTreeHierarchy",
	"BayterekInspector": "SkillTreeInspector",
	"BayterekMainScreen": "SkillTreeMainScreen",
	"BayterekSelectionBox": "SkillTreeSelectionBox",
	"BayterekSettings": "SkillTreeSettings",
	"BayterekShortcuts": "SkillTreeShortcuts",
	"BayterekValidator": "SkillTreeValidator",
	"BayterekPlugin": "SkillTreePlugin",
	"BayterekCleanup": "SkillTreeCleanup",
	"BayterekScaffold": "SkillTreeScaffold",
}

# --- Path değişimleri (dosya yolları) ---
const PATH_MAP := {
	"res://addons/bayterek_localization/": "res://addons/localization_forger/",
	"res://addons/bayterek/": "res://addons/skill_tree_forger/",
}

# --- İşlenecek dosya uzantıları ---
const TEXT_EXTENSIONS := [
	"gd", "tscn", "tres", "cfg", "godot", "json", "md", "txt", "import",
]

# --- Atlanacak klasörler ---
const SKIP_DIRS := [
	".godot", ".git", ".import", "node_modules",
]

# --- Atlanacak dosyalar (Kendi kendini ve raporları bozmaması için) ---
const SKIP_FILES := [
	"rename_bayterek.gd", "rename_report.txt", "rapor.txt"
]

var _report_lines: PackedStringArray = []
var _changed_files: Array[String] = []
var _renamed_files: Array[String] = []
var _renamed_dirs: Array[String] = []

# ============================================================
# ENTRY POINT
# ============================================================

func _initialize() -> void:
	print("========================================")
	print("Bayterek Rename Script")
	print("  DRY_RUN = ", DRY_RUN)
	print("========================================")

	_log("Bayterek Rename Report")
	_log("DRY_RUN=%s" % DRY_RUN)
	_log("")

	# 1) Dosya içeriklerini değiştir
	print("\n--- FAZ 1: Dosya içerikleri ---")
	_process_all_files("res://")

	# 2) Dosyaları rename et
	print("\n--- FAZ 2: Dosya rename ---")
	_rename_files("res://")

	# 3) Klasörleri rename et
	print("\n--- FAZ 3: Klasör rename ---")
	_rename_folders()

	# 4) Rapor yaz
	_log("")
	_log("=== ÖZET ===")
	_log("Değişen dosya sayısı: %d" % _changed_files.size())
	_log("Rename edilen dosya sayısı: %d" % _renamed_files.size())
	_log("Rename edilen klasör sayısı: %d" % _renamed_dirs.size())
	_log("")
	_log("=== DEĞİŞEN DOSYALAR ===")
	for f in _changed_files:
		_log("  " + f)
	_log("")
	_log("=== RENAME EDİLEN DOSYALAR ===")
	for f in _renamed_files:
		_log("  " + f)
	_log("")
	_log("=== RENAME EDİLEN KLASÖRLER ===")
	for f in _renamed_dirs:
		_log("  " + f)

	_write_report()
	print("\nRapor yazıldı: res://rename_report.txt")
	print("========================================")
	quit()

# ============================================================
# FAZ 1: DOSYA İÇERİKLERİ
# ============================================================

func _process_all_files(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		push_error("Klasör açılamadı: " + dir_path)
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue

		var full_path := dir_path.path_join(entry)

		if dir.current_is_dir():
			if entry in SKIP_DIRS:
				entry = dir.get_next()
				continue
			_process_all_files(full_path)
		else:
			_process_file(full_path)

		entry = dir.get_next()
	dir.list_dir_end()

func _process_file(path: String) -> void:
	var file_name := path.get_file()
	if file_name in SKIP_FILES:
		return

	var ext := path.get_extension().to_lower()

	# .uid dosyalarına dokunma — sadece isimleri değişecek
	if ext == "uid":
		return

	if ext not in TEXT_EXTENSIONS:
		return

	# Binary dosyaları atla
	if path.ends_with(".png") or path.ends_with(".wav") or path.ends_with(".svg"):
		return

	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return
	var original := f.get_as_text()
	f.close()

	var modified := _replace_all_in_text(original)

	if modified != original:
		if not DRY_RUN:
			var w := FileAccess.open(path, FileAccess.WRITE)
			if w:
				w.store_string(modified)
				w.close()
		_changed_files.append(path)
		print("  ✏️  " + path)

func _replace_all_in_text(text: String) -> String:
	var result := text

	# 1) Path'ler (res://addons/bayterek...)
	for old_path in PATH_MAP.keys():
		result = result.replace(old_path, PATH_MAP[old_path])

	# 2) Identifier'lar
	for old_id in IDENTIFIER_MAP.keys():
		result = result.replace(old_id, IDENTIFIER_MAP[old_id])

	# 3) Dosya adı referansları
	result = _replace_file_name_refs(result)

	return result

func _replace_file_name_refs(text: String) -> String:
	# bayterek_localization_xxx.gd → localeforge_xxx.gd
	var re_loc := RegEx.new()
	re_loc.compile("bayterek_localization_([a-z0-9_]+\\.gd)")
	text = re_loc.sub(text, "localeforge_$1", true)

	# bayterek.gd (ana plugin) → skill_tree_forger.gd
	var re_main := RegEx.new()
	re_main.compile("\\bbayterek\\.gd\\b")
	text = re_main.sub(text, "skill_tree_forger.gd", true)

	# bayterek_skill_tree_data.gd → skilltree_data.gd
	var re_data := RegEx.new()
	re_data.compile("bayterek_skill_tree_data\\.gd")
	text = re_data.sub(text, "skilltree_data.gd", true)

	# bayterek_skill_tree_json.gd → skilltree_json.gd
	var re_json := RegEx.new()
	re_json.compile("bayterek_skill_tree_json\\.gd")
	text = re_json.sub(text, "skilltree_json.gd", true)

	# bayterek_xxx.gd → skilltree_xxx.gd
	var re_tree := RegEx.new()
	re_tree.compile("bayterek_([a-z0-9_]+\\.gd)")
	text = re_tree.sub(text, "skilltree_$1", true)

	return text

# ============================================================
# FAZ 2: DOSYA RENAME
# ============================================================

func _rename_files(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue

		var full_path := dir_path.path_join(entry)

		if dir.current_is_dir():
			if entry in SKIP_DIRS:
				entry = dir.get_next()
				continue
			_rename_files(full_path)
		else:
			var new_name := _compute_new_file_name(entry)
			if new_name != entry:
				var new_path := dir_path.path_join(new_name)
				if not DRY_RUN:
					var err := DirAccess.rename_absolute(full_path, new_path)
					if err != OK:
						push_error("Rename başarısız: %s → %s (err=%d)" % [full_path, new_path, err])
				_renamed_files.append("%s → %s" % [full_path, new_path])
				print("  📄 " + full_path + " → " + new_name)

		entry = dir.get_next()
	dir.list_dir_end()

func _compute_new_file_name(name: String) -> String:
	if name == "bayterek.gd":
		return "skill_tree_forger.gd"
	if name == "bayterek.gd.uid":
		return "skill_tree_forger.gd.uid"
	if name == "bayterek_localization.gd":
		return "localization_forger.gd"
	if name == "bayterek_localization.gd.uid":
		return "localization_forger.gd.uid"
	if name == "bayterek_skill_tree_data.gd":
		return "skilltree_data.gd"
	if name == "bayterek_skill_tree_data.gd.uid":
		return "skilltree_data.gd.uid"
	if name == "bayterek_skill_tree_json.gd":
		return "skilltree_json.gd"
	if name == "bayterek_skill_tree_json.gd.uid":
		return "skilltree_json.gd.uid"
		
	if name.begins_with("bayterek_localization_"):
		return "localeforge_" + name.substr("bayterek_localization_".length())
	if name.begins_with("bayterek_"):
		return "skilltree_" + name.substr("bayterek_".length())
	return name

# ============================================================
# FAZ 3: KLASÖR RENAME
# ============================================================

func _rename_folders() -> void:
	for old_path in FOLDER_MAP.keys():
		var new_path: String = FOLDER_MAP[old_path]
		if DirAccess.dir_exists_absolute(old_path):
			if not DRY_RUN:
				var err := DirAccess.rename_absolute(old_path, new_path)
				if err != OK:
					push_error("Klasör rename başarısız: %s → %s (err=%d)" % [old_path, new_path, err])
					continue
			_renamed_dirs.append("%s → %s" % [old_path, new_path])
			print("  📁 " + old_path + " → " + new_path)
		else:
			print("  ⚠️  Klasör yok: " + old_path)

# ============================================================
# RAPOR
# ============================================================

func _log(line: String) -> void:
	_report_lines.append(line)
	print(line)

func _write_report() -> void:
	var f := FileAccess.open("res://rename_report.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_report_lines))
		f.close()