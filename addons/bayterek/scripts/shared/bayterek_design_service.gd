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
	return reg.designs.duplicate()

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
## IMPORTANT (bug fix):
## The old implementation reused `BayterekNodeDesign.new()` directly and
## then saved it. In some Godot 4 editor sessions the typed array
## `layers: Array[BayterekLayer]` ends up being shared across instances
## created with `.new()`, so a fresh design would silently inherit the
## layer stack of the first design in the session — making every new
## design look identical.
##
## The fix has three parts:
##   1. Explicitly reset `design.layers` and `design.exported_fields`
##      right after `.new()`.
##   2. Delete any stale file at the target path before saving.
##   3. Reload with CACHE_MODE_IGNORE and abort if the fresh design
##      somehow has layers.
##
## Returns the new design on success, or null on failure.
static func create_design(base_name: String = "New Design", category: String = "") -> BayterekNodeDesign:
	_ensure_designs_dir()

	var unique_name: String = _make_unique_name(base_name)
	var snake: String = Bayterek.to_snake_case(unique_name)
	var file_path: String = "%s/%s.tres" % [Bayterek.get_designs_dir(), snake]

	# 1) Remove any stale file at the target path.
	if FileAccess.file_exists(file_path):
		Bayterek.delete_resource_with_sidecar(file_path)

	# 2) Build a brand-new, empty design.
	var design := BayterekNodeDesign.new()
	design.id = snake
	design.name = unique_name
	design.category = category
	design.design_size = Vector2(100, 100)
	design.scale = Vector2.ONE
	# Belt-and-braces reset (guards against shared typed-array references).
	design.layers = []
	design.exported_fields = {}
	design.bounds_layer_id = ""

	# 3) Save to disk.
	var err: Error = Bayterek.safe_save(design, file_path)
	if err != OK:
		BayterekLogger.error("Could not save design (%d): %s" % [err, file_path], "designs")
		return null

	# 4) Reload from disk bypassing the resource cache.
	var saved: BayterekNodeDesign = ResourceLoader.load(
		file_path,
		"BayterekNodeDesign",
		ResourceLoader.CACHE_MODE_IGNORE
	)
	if not saved:
		BayterekLogger.error("Could not reload design after save: %s" % file_path, "designs")
		return null

	saved.resource_path = file_path

	# 5) Sanity check — a fresh design MUST have zero layers.
	if saved.layers.size() != 0:
		BayterekLogger.error(
			"Fresh design has %d layers — expected 0. Aborting." % saved.layers.size(),
			"designs"
		)
		Bayterek.delete_resource_with_sidecar(file_path)
		return null

	var reg: BayterekDesignRegistry = Bayterek.get_designs_registry()
	reg.add_design(saved)
	Bayterek.save_designs_registry()

	EditorInterface.get_resource_filesystem().scan()

	return saved

## Duplicates an existing design.
##
## Uses `source.duplicate_design()` which now hands out fresh layer ids
## to every layer, so the copy and the original are fully independent.
static func duplicate_design(source: BayterekNodeDesign) -> BayterekNodeDesign:
	if not source:
		return null

	_ensure_designs_dir()

	var base_name: String = source.name + " Copy"
	var unique_name: String = _make_unique_name(base_name)
	var snake: String = Bayterek.to_snake_case(unique_name)
	var file_path: String = "%s/%s.tres" % [Bayterek.get_designs_dir(), snake]

	# Remove any stale file at the target path.
	if FileAccess.file_exists(file_path):
		Bayterek.delete_resource_with_sidecar(file_path)

	# Build the copy via the resource-level duplicator.
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
		return null

	saved.resource_path = file_path

	var reg: BayterekDesignRegistry = Bayterek.get_designs_registry()
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

## Deletes multiple designs at once. Returns the number of designs
## actually deleted.
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