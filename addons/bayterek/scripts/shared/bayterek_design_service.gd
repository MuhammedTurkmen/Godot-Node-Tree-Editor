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