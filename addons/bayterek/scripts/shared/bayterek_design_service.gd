@tool
class_name BayterekDesignService
extends RefCounted
## Design CRUD + disk operations.
##
## NOTE: This is a fully static utility class. We do NOT use signals here
## because Godot 4 does not allow emitting instance signals from static
## functions. UI layers refresh themselves after calling these methods.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

# ============================================================
# QUERY
# ============================================================

static func get_all_designs() -> Array:
	var reg: BayterekDesignRegistry = Bayterek.get_designs_registry()
	if not reg:
		return []
	var out: Array = reg.designs.duplicate()
	out.sort_custom(func(a, b):
		if not a: return false
		if not b: return true
		return a.name.naturalnocasecmp_to(b.name) < 0
	)
	return out

static func get_design(design_id: String) -> BayterekNodeDesign:
	var reg: BayterekDesignRegistry = Bayterek.get_designs_registry()
	if not reg:
		return null
	return reg.get_design_by_id(design_id)

static func has_design(design_id: String) -> bool:
	return get_design(design_id) != null

static func get_designs_grouped_by_category() -> Dictionary:
	var reg: BayterekDesignRegistry = Bayterek.get_designs_registry()
	if not reg:
		return {}

	var groups: Dictionary = {}
	for design in reg.designs:
		if not design:
			continue
		var cat: String = design.category.strip_edges()
		if cat.is_empty():
			cat = "Uncategorized"
		if not groups.has(cat):
			groups[cat] = []
		groups[cat].append(design)

	var named: Array = []
	var uncategorized: Array = []
	for key in groups.keys():
		if key == "Uncategorized":
			uncategorized.append(key)
		else:
			named.append(key)

	named.sort()

	var result: Dictionary = {}
	for key in named:
		result[key] = groups[key]
	for key in uncategorized:
		result[key] = groups[key]

	return result

static func get_all_categories() -> Array:
	var reg: BayterekDesignRegistry = Bayterek.get_designs_registry()
	if not reg:
		return []

	var cats: Dictionary = {}
	for design in reg.designs:
		if not design:
			continue
		var cat: String = design.category.strip_edges()
		if not cat.is_empty():
			cats[cat] = true

	var result: Array = cats.keys()
	result.sort()
	return result

# ============================================================
# CREATE
# ============================================================

## Creates a brand-new design and saves it to disk.
##
## Important guarantees:
##   1. The new design gets a UNIQUE name AND a UNIQUE id. Both are
##      derived via _make_unique_name(), which now checks the registry
##      for BOTH name and id collisions.
##   2. `layers` and `exported_fields` are explicitly reset after .new()
##      to defend against shared typed-array references.
##   3. The freshly saved resource is reloaded with CACHE_MODE_IGNORE
##      and sanity-checked (must have 0 layers, id must not collide).
##   4. If anything goes wrong, the partial file is deleted so the
##      registry is never polluted.
static func create_design(base_name: String = "New Design", category: String = "") -> BayterekNodeDesign:
	_ensure_designs_dir()

	# --- 1. Unique name + unique id, both verified against the registry ---
	var unique_name: String = _make_unique_name(base_name)
	var snake: String = Bayterek.to_snake_case(unique_name)
	snake = _make_unique_id(snake)

	var file_path: String = "%s/%s.tres" % [Bayterek.get_designs_dir(), snake]

	# --- 2. Remove any stale file at the target path ---
	if FileAccess.file_exists(file_path):
		Bayterek.delete_resource_with_sidecar(file_path)

	# --- 3. Build a fresh, empty design ---
	var design := BayterekNodeDesign.new()
	design.id = snake
	design.name = unique_name
	design.category = category
	design.design_size = Vector2(100, 100)
	design.scale = Vector2.ONE
	design.layers = []
	design.exported_fields = {}
	design.bounds_layer_id = ""

	# --- 4. Save to disk ---
	var err: Error = Bayterek.safe_save(design, file_path)
	if err != OK:
		BayterekLogger.error("Could not save design (%d): %s" % [err, file_path], "designs")
		return null

	# --- 5. Reload with CACHE_MODE_IGNORE to get a truly fresh instance ---
	var saved: BayterekNodeDesign = ResourceLoader.load(
		file_path,
		"BayterekNodeDesign",
		ResourceLoader.CACHE_MODE_IGNORE
	)
	if not saved:
		BayterekLogger.error("Could not reload design after save: %s" % file_path, "designs")
		Bayterek.delete_resource_with_sidecar(file_path)
		return null

	saved.resource_path = file_path

	# --- 6. Sanity checks ---
	if saved.layers.size() != 0:
		BayterekLogger.error(
			"Fresh design has %d layers — expected 0. Aborting." % saved.layers.size(),
			"designs"
		)
		Bayterek.delete_resource_with_sidecar(file_path)
		return null

	var reg: BayterekDesignRegistry = Bayterek.get_designs_registry()
	if reg and reg.has_design_id(saved.id):
		# Should never happen after _make_unique_id(), but be defensive:
		# never let a new design silently overwrite an existing one.
		BayterekLogger.error(
			"Design id collision '%s' — aborting creation." % saved.id,
			"designs"
		)
		Bayterek.delete_resource_with_sidecar(file_path)
		return null

	# --- 7. Register + persist ---
	reg.add_design(saved)
	Bayterek.save_designs_registry()

	EditorInterface.get_resource_filesystem().scan()

	return saved

## Duplicates an existing design.
##
## Uses `source.duplicate_design()` which hands out fresh layer ids
## to every layer, so the copy and the original are fully independent.
static func duplicate_design(source: BayterekNodeDesign) -> BayterekNodeDesign:
	if not source:
		return null

	_ensure_designs_dir()

	var base_name: String = source.name + " Copy"
	var unique_name: String = _make_unique_name(base_name)
	var snake: String = Bayterek.to_snake_case(unique_name)
	snake = _make_unique_id(snake)
	var file_path: String = "%s/%s.tres" % [Bayterek.get_designs_dir(), snake]

	if FileAccess.file_exists(file_path):
		Bayterek.delete_resource_with_sidecar(file_path)

	var copy: BayterekNodeDesign = source.duplicate_design()
	if not copy:
		return null

	copy.id = snake
	copy.name = unique_name

	var err: Error = Bayterek.safe_save(copy, file_path)
	if err != OK:
		BayterekLogger.error("Could not save duplicated design (%d): %s" % [err, file_path], "designs")
		return null

	var saved: BayterekNodeDesign = ResourceLoader.load(
		file_path,
		"BayterekNodeDesign",
		ResourceLoader.CACHE_MODE_IGNORE
	)
	if not saved:
		BayterekLogger.error("Could not reload duplicated design: %s" % file_path, "designs")
		Bayterek.delete_resource_with_sidecar(file_path)
		return null

	saved.resource_path = file_path

	var reg: BayterekDesignRegistry = Bayterek.get_designs_registry()
	if reg and reg.has_design_id(saved.id):
		BayterekLogger.error(
			"Duplicate design id collision '%s' — aborting." % saved.id,
			"designs"
		)
		Bayterek.delete_resource_with_sidecar(file_path)
		return null

	reg.add_design(saved)
	Bayterek.save_designs_registry()

	EditorInterface.get_resource_filesystem().scan()

	return saved

# ============================================================
# UPDATE
# ============================================================

static func save_design(design: BayterekNodeDesign) -> Error:
	if not design:
		return FAILED
	if design.resource_path.is_empty():
		BayterekLogger.error("Cannot save design with empty resource_path.", "designs")
		return FAILED

	return Bayterek.safe_save(design, design.resource_path)

static func rename_design(design: BayterekNodeDesign, new_name: String) -> bool:
	if not design:
		return false

	var trimmed: String = new_name.strip_edges()
	if trimmed.is_empty():
		return false
	if trimmed == design.name:
		return true

	design.set_design_name(trimmed)

	var err: Error = save_design(design)
	if err != OK:
		BayterekLogger.error("Could not save renamed design (%d)" % err, "designs")
		return false

	Bayterek.save_designs_registry()
	return true

# ============================================================
# DELETE
# ============================================================

static func delete_design(design: BayterekNodeDesign) -> bool:
	if not design:
		return false

	var path: String = design.resource_path
	var reg: BayterekDesignRegistry = Bayterek.get_designs_registry()
	reg.remove_design(design)

	if not path.is_empty():
		Bayterek.delete_resource_with_sidecar(path)

	Bayterek.save_designs_registry()
	EditorInterface.get_resource_filesystem().scan()

	return true

static func delete_multiple_designs(designs: Array) -> int:
	if designs.is_empty():
		return 0

	var reg: BayterekDesignRegistry = Bayterek.get_designs_registry()
	if not reg:
		return 0

	var count: int = 0
	for design in designs:
		if not design:
			continue
		if not (design is BayterekNodeDesign):
			continue

		var path: String = design.resource_path
		reg.remove_design(design)

		if not path.is_empty():
			Bayterek.delete_resource_with_sidecar(path)

		count += 1

	Bayterek.save_designs_registry()
	EditorInterface.get_resource_filesystem().scan()
	return count

# ============================================================
# RELOAD
# ============================================================

static func reload() -> void:
	Bayterek.reload_designs_registry()

# ============================================================
# PRIVATE
# ============================================================

static func _ensure_designs_dir() -> void:
	var dir_path: String = Bayterek.get_designs_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

## Returns a unique display name that doesn't collide with any existing
## design's name. Uses "New Design", "New Design 2", "New Design 3", ...
static func _make_unique_name(base_name: String) -> String:
	var trimmed: String = base_name.strip_edges()
	if trimmed.is_empty():
		trimmed = "New Design"

	var reg: BayterekDesignRegistry = Bayterek.get_designs_registry()
	if not reg:
		return trimmed

	var existing_names: Dictionary = {}
	for d in reg.designs:
		if d:
			existing_names[d.name] = true

	if not existing_names.has(trimmed):
		return trimmed

	var counter: int = 2
	var candidate: String = "%s %d" % [trimmed, counter]
	while existing_names.has(candidate):
		counter += 1
		candidate = "%s %d" % [trimmed, counter]

	return candidate

## Returns a unique id (snake_case) that doesn't collide with any
## existing design's id. If `base_id` is already taken, tries
## "base_id_2", "base_id_3", ...
##
## This is a belt-and-braces guard on top of _make_unique_name(): even
## if two different display names happen to snake_case into the same id
## (e.g. "New Design!" and "New-Design"), we still get distinct ids.
static func _make_unique_id(base_id: String) -> String:
	var trimmed: String = base_id.strip_edges()
	if trimmed.is_empty():
		trimmed = "new_design"

	var reg: BayterekDesignRegistry = Bayterek.get_designs_registry()
	if not reg:
		return trimmed

	var existing_ids: Dictionary = {}
	for d in reg.designs:
		if d and not d.id.is_empty():
			existing_ids[d.id] = true

	if not existing_ids.has(trimmed):
		return trimmed

	var counter: int = 2
	var candidate: String = "%s_%d" % [trimmed, counter]
	while existing_ids.has(candidate):
		counter += 1
		candidate = "%s_%d" % [trimmed, counter]

	return candidate

# ============================================================
# BULK JSON EXPORT / IMPORT
# ============================================================
#
# Tek dosyada tüm tasarımları taşımak için kullanılan schema:
#
#   {
#     "format": "bayterek-designs",
#     "version": 1,
#     "exported_at": "2026-...",
#     "designs": [ <design_dict>, ... ]
#   }
#
# Her design_dict, BayterekNodeDesign'in tam serialize edilmiş halidir
# (layers, exported_fields, bounds/progress layer id'leri dahil).
# Texture referansları res:// yolu olarak saklanır; import sırasında
# ResourceLoader.exists() ile kontrol edilir ve yoksa null'a düşer.

const BULK_FORMAT := "bayterek-designs"
const BULK_FORMAT_VERSION := 1

## Tüm tasarımları tek bir JSON dosyasına yazar.
## Dönüş: { ok: bool, count: int, path: String, error: String }
static func export_all_designs_to_json(path: String) -> Dictionary:
	var result: Dictionary = {"ok": false, "count": 0, "path": path, "error": ""}

	if path.strip_edges().is_empty():
		result["error"] = "Path is empty."
		return result

	var designs: Array = get_all_designs()
	if designs.is_empty():
		result["error"] = "No designs to export."
		return result

	var payload: Dictionary = {
		"format": BULK_FORMAT,
		"version": BULK_FORMAT_VERSION,
		"exported_at": Time.get_datetime_string_from_system(),
		"designs": [],
	}

	for design in designs:
		if not design:
			continue
		payload["designs"].append(_serialize_design_to_dict(design))

	var dir: String = path.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
		var mk_err: Error = DirAccess.make_dir_recursive_absolute(dir)
		if mk_err != OK:
			result["error"] = "Could not create directory: %s (err=%d)" % [dir, mk_err]
			return result

	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not f:
		result["error"] = "Could not open file for writing (err=%d)." % FileAccess.get_open_error()
		return result

	f.store_string(JSON.stringify(payload, "  "))
	f.close()

	result["ok"] = true
	result["count"] = (payload["designs"] as Array).size()
	return result

## Bir JSON dosyasından tasarımları okur ve registry'ye ekler.
##
## Davranış:
##   - Aynı id veya aynı isimde tasarım varsa OTOMATİK yeniden
##     adlandırılır ("Name (Imported)", "Name (Imported 2)", ...).
##   - Var olan tasarımlar ASLA ezilmez.
##   - Her tasarım diske ayrı bir .tres olarak kaydedilir.
##
## Dönüş: { ok: bool, imported: int, skipped: int, errors: Array[String] }
static func import_designs_from_json(path: String) -> Dictionary:
	var result: Dictionary = {"ok": false, "imported": 0, "skipped": 0, "errors": []}

	if path.strip_edges().is_empty():
		result["errors"].append("Path is empty.")
		return result

	if not FileAccess.file_exists(path):
		result["errors"].append("File not found: %s" % path)
		return result

	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not f:
		result["errors"].append("Could not open file (err=%d)." % FileAccess.get_open_error())
		return result
	var text: String = f.get_as_text()
	f.close()

	var json := JSON.new()
	var parse_err: int = json.parse(text)
	if parse_err != OK:
		result["errors"].append("JSON parse error at line %d: %s" % [
			json.get_error_line(), json.get_error_message()
		])
		return result

	if not (json.data is Dictionary):
		result["errors"].append("Root JSON must be an object.")
		return result

	var payload: Dictionary = json.data
	if String(payload.get("format", "")) != BULK_FORMAT:
		result["errors"].append("Not a Bayterek designs file (format='%s')." % payload.get("format", ""))
		return result

	var raw_designs: Array = payload.get("designs", [])
	if raw_designs.is_empty():
		result["errors"].append("File contains no designs.")
		return result

	_ensure_designs_dir()

	var reg: BayterekDesignRegistry = Bayterek.get_designs_registry()
	if not reg:
		result["errors"].append("Design registry unavailable.")
		return result

	var imported: int = 0
	var skipped: int = 0

	for raw in raw_designs:
		if not (raw is Dictionary):
			skipped += 1
			continue

		var design: BayterekNodeDesign = _deserialize_design_from_dict(raw)
		if not design:
			skipped += 1
			continue

		# Benzersiz isim + id üret.
		design.name = _make_unique_name(design.name)
		var snake: String = Bayterek.to_snake_case(design.name)
		snake = _make_unique_id(snake)

		var file_path: String = "%s/%s.tres" % [Bayterek.get_designs_dir(), snake]
		if FileAccess.file_exists(file_path):
			Bayterek.delete_resource_with_sidecar(file_path)

		design.id = snake

		var save_err: Error = Bayterek.safe_save(design, file_path)
		if save_err != OK:
			result["errors"].append("Could not save '%s' (err=%d)." % [design.name, save_err])
			skipped += 1
			continue

		var saved: BayterekNodeDesign = ResourceLoader.load(
			file_path, "BayterekNodeDesign", ResourceLoader.CACHE_MODE_IGNORE
		)
		if not saved:
			Bayterek.delete_resource_with_sidecar(file_path)
			result["errors"].append("Reload failed for '%s'." % design.name)
			skipped += 1
			continue

		saved.resource_path = file_path

		if not reg.add_design(saved):
			Bayterek.delete_resource_with_sidecar(file_path)
			skipped += 1
			continue

		imported += 1

	Bayterek.save_designs_registry()
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()

	result["ok"] = true
	result["imported"] = imported
	result["skipped"] = skipped
	return result

# ============================================================
# SERIALIZATION — DESIGN
# ============================================================

static func _serialize_design_to_dict(design: BayterekNodeDesign) -> Dictionary:
	if not design:
		return {}

	var layers_arr: Array = []
	for layer in design.layers:
		if layer:
			layers_arr.append(_serialize_layer_to_dict(layer))

	return {
		"id": design.id,
		"name": design.name,
		"description": design.description,
		"category": design.category,
		"design_size": {"x": design.design_size.x, "y": design.design_size.y},
		"scale": {"x": design.scale.x, "y": design.scale.y},
		"bounds_layer_id": design.bounds_layer_id,
		"progress_layer_id": design.progress_layer_id,
		"progress_layer_mode": design.progress_layer_mode,
		"exported_fields": design.exported_fields.duplicate(true),
		"layers": layers_arr,
	}

static func _deserialize_design_from_dict(d: Dictionary) -> BayterekNodeDesign:
	if d.is_empty():
		return null

	var design := BayterekNodeDesign.new()
	design.id = ""   # import sırasında atanacak
	design.name = String(d.get("name", "Imported Design"))
	design.description = String(d.get("description", ""))
	design.category = String(d.get("category", ""))

	var ds: Dictionary = d.get("design_size", {})
	design.design_size = Vector2(float(ds.get("x", 100.0)), float(ds.get("y", 100.0)))

	var sc: Dictionary = d.get("scale", {})
	design.scale = Vector2(float(sc.get("x", 1.0)), float(sc.get("y", 1.0)))

	design.bounds_layer_id = String(d.get("bounds_layer_id", ""))
	design.progress_layer_id = String(d.get("progress_layer_id", ""))
	design.progress_layer_mode = int(d.get("progress_layer_mode", 2))

	var ef = d.get("exported_fields", {})
	if ef is Dictionary:
		design.exported_fields = ef.duplicate(true)

	design.layers = []

	var raw_layers: Array = d.get("layers", [])
	for raw in raw_layers:
		if not (raw is Dictionary):
			continue
		var layer: BayterekLayer = _deserialize_layer_from_dict(raw)
		if layer:
			design.layers.append(layer)

	return design

# ============================================================
# SERIALIZATION — LAYER
# ============================================================

static func _serialize_layer_to_dict(layer: BayterekLayer) -> Dictionary:
	var out: Dictionary = {
		"_type": "texture" if layer is BayterekTextureLayer else "base",
		"layer_id": layer.layer_id,
		"layer_name": layer.layer_name,
		"visible": layer.visible,
		"absolute": layer.absolute,
		"animation_id": layer.animation_id,
		"animated": layer.animated,
		"render_mode_override": int(layer.render_mode_override),
		"texture_filter_override": int(layer.texture_filter_override),
		"transform": _serialize_transform(layer.transform),
	}

	if layer is BayterekTextureLayer:
		var tl: BayterekTextureLayer = layer
		out["icon_enabled"] = tl.icon_enabled
		out["tint_enabled"] = tl.tint_enabled
		out["stretch_mode"] = int(tl.stretch_mode)
		out["nine_patch_margin_left"] = tl.nine_patch_margin_left
		out["nine_patch_margin_top"] = tl.nine_patch_margin_top
		out["nine_patch_margin_right"] = tl.nine_patch_margin_right
		out["nine_patch_margin_bottom"] = tl.nine_patch_margin_bottom
		out["nine_patch_draw_center"] = tl.nine_patch_draw_center
		out["icon_configs"] = _serialize_icon_configs(tl.icon_configs)
		out["tint_configs"] = _serialize_tint_configs(tl.tint_configs)

	return out

static func _deserialize_layer_from_dict(d: Dictionary) -> BayterekLayer:
	var type_str: String = String(d.get("_type", "base"))
	var layer: BayterekLayer

	if type_str == "texture":
		layer = BayterekTextureLayer.new()
	else:
		layer = BayterekLayer.new()

	layer.layer_id = String(d.get("layer_id", BayterekUUIDGenerator.v4()))
	layer.layer_name = String(d.get("layer_name", "Layer"))
	layer.visible = bool(d.get("visible", true))
	layer.absolute = bool(d.get("absolute", false))
	layer.animation_id = String(d.get("animation_id", ""))
	layer.animated = bool(d.get("animated", false))
	layer.render_mode_override = int(d.get("render_mode_override", 0)) as BayterekLayer.RenderModeOverride
	layer.texture_filter_override = int(d.get("texture_filter_override", 0)) as BayterekLayer.TextureFilterOverride
	layer.transform = _deserialize_transform(d.get("transform", {}))

	if layer is BayterekTextureLayer:
		var tl: BayterekTextureLayer = layer
		tl.icon_enabled = bool(d.get("icon_enabled", true))
		tl.tint_enabled = bool(d.get("tint_enabled", false))
		tl.stretch_mode = int(d.get("stretch_mode", 0)) as BayterekTextureLayer.StretchMode
		tl.nine_patch_margin_left = int(d.get("nine_patch_margin_left", 8))
		tl.nine_patch_margin_top = int(d.get("nine_patch_margin_top", 8))
		tl.nine_patch_margin_right = int(d.get("nine_patch_margin_right", 8))
		tl.nine_patch_margin_bottom = int(d.get("nine_patch_margin_bottom", 8))
		tl.nine_patch_draw_center = bool(d.get("nine_patch_draw_center", true))
		tl.icon_configs = _deserialize_icon_configs(d.get("icon_configs", {}))
		tl.tint_configs = _deserialize_tint_configs(d.get("tint_configs", {}))

	return layer

# ============================================================
# SERIALIZATION — TRANSFORM / CONFIGS
# ============================================================

static func _serialize_transform(t: BayterekLayerTransform) -> Dictionary:
	if not t:
		return {}
	return {
		"position": {"x": t.position.x, "y": t.position.y},
		"size": {"x": t.size.x, "y": t.size.y},
		"scale": {"x": t.scale.x, "y": t.scale.y},
		"flip_x": t.flip_x,
		"flip_y": t.flip_y,
		"rotation": t.rotation,
		"skew": {"x": t.skew.x, "y": t.skew.y},
		"pivot": {"x": t.pivot.x, "y": t.pivot.y},
		"pivot_mode": int(t.pivot_mode),
		"scale_from_pivot": t.scale_from_pivot,
	}

static func _deserialize_transform(d: Dictionary) -> BayterekLayerTransform:
	var t := BayterekLayerTransform.new()
	if d.is_empty():
		return t

	var p: Dictionary = d.get("position", {})
	t.position = Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0)))

	var s: Dictionary = d.get("size", {})
	t.size = Vector2(float(s.get("x", 0.0)), float(s.get("y", 0.0)))

	var sc: Dictionary = d.get("scale", {})
	t.scale = Vector2(float(sc.get("x", 1.0)), float(sc.get("y", 1.0)))

	t.flip_x = bool(d.get("flip_x", false))
	t.flip_y = bool(d.get("flip_y", false))
	t.rotation = float(d.get("rotation", 0.0))

	var sk: Dictionary = d.get("skew", {})
	t.skew = Vector2(float(sk.get("x", 0.0)), float(sk.get("y", 0.0)))

	var pv: Dictionary = d.get("pivot", {})
	t.pivot = Vector2(float(pv.get("x", 0.5)), float(pv.get("y", 0.5)))

	t.pivot_mode = int(d.get("pivot_mode", 4)) as BayterekLayerTransform.PivotMode
	t.scale_from_pivot = bool(d.get("scale_from_pivot", false))
	return t

static func _serialize_icon_configs(configs: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for state in configs.keys():
		var entry = configs[state]
		if not (entry is Dictionary):
			continue
		out[String(state)] = {
			"enabled": bool(entry.get("enabled", false)),
			"texture": _texture_to_path(entry.get("texture", null)),
		}
	return out

static func _deserialize_icon_configs(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if not (raw is Dictionary):
		return out
	for state in raw.keys():
		var entry = raw[state]
		if not (entry is Dictionary):
			continue
		out[String(state)] = {
			"enabled": bool(entry.get("enabled", false)),
			"texture": _path_to_texture(String(entry.get("texture", ""))),
		}
	return out

static func _serialize_tint_configs(configs: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for state in configs.keys():
		var entry = configs[state]
		if not (entry is Dictionary):
			continue
		var c: Color = entry.get("color", Color.WHITE)
		out[String(state)] = {
			"enabled": bool(entry.get("enabled", false)),
			"color": {"r": c.r, "g": c.g, "b": c.b, "a": c.a},
		}
	return out

static func _deserialize_tint_configs(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if not (raw is Dictionary):
		return out
	for state in raw.keys():
		var entry = raw[state]
		if not (entry is Dictionary):
			continue
		var c: Dictionary = entry.get("color", {})
		out[String(state)] = {
			"enabled": bool(entry.get("enabled", false)),
			"color": Color(
				float(c.get("r", 1.0)),
				float(c.get("g", 1.0)),
				float(c.get("b", 1.0)),
				float(c.get("a", 1.0))
			),
		}
	return out

static func _texture_to_path(tex: Texture2D) -> String:
	if tex == null:
		return ""
	if tex is AtlasTexture:
		var atlas: AtlasTexture = tex
		if atlas.atlas and not atlas.atlas.resource_path.is_empty():
			return atlas.atlas.resource_path
		return ""
	return tex.resource_path

static func _path_to_texture(path: String) -> Texture2D:
	if path.strip_edges().is_empty():
		return null
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D