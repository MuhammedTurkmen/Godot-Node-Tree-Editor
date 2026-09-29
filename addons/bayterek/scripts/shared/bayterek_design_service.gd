@tool
class_name BayterekDesignService
extends RefCounted
## Design CRUD + disk operations.

signal design_created(design: BayterekNodeDesign)
signal design_removed(design: BayterekNodeDesign)
signal design_renamed(design: BayterekNodeDesign, old_id: String)
signal designs_reloaded

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

static func create_design(base_name: String = "New Design", category: String = "") -> BayterekNodeDesign:
	_ensure_designs_dir()

	var unique_name: String = _make_unique_name(base_name)
	var snake: String = Bayterek.to_snake_case(unique_name)
	var file_path: String = "%s/%s.tres" % [Bayterek.get_designs_dir(), snake]

	# --- DEBUG ---
	print("[create_design] REQUEST name=", unique_name, " snake=", snake, " path=", file_path)

	var design := BayterekNodeDesign.new()
	design.id = snake
	design.name = unique_name
	design.category = category
	design.design_size = Vector2(100, 100)
	design.scale = Vector2.ONE

	# --- DEBUG ---
	print("[create_design] NEW instance=", design.get_instance_id(), " design.id=", design.id, " design.layers=", design.layers.size())

	var err: Error = Bayterek.safe_save(design, file_path)
	if err != OK:
		BayterekLogger.error("Could not save design (%d): %s" % [err, file_path], "designs")
		return null

	var saved: BayterekNodeDesign = ResourceLoader.load(file_path, "BayterekNodeDesign", ResourceLoader.CACHE_MODE_IGNORE)
	if not saved:
		BayterekLogger.error("Could not reload design after save: %s" % file_path, "designs")
		return null

	# --- DEBUG ---
	print("[create_design] LOADED instance=", saved.get_instance_id(), " saved.id=", saved.id, " saved.name=", saved.name, " saved.resource_path=", saved.resource_path, " saved.layers=", saved.layers.size())

	saved.resource_path = file_path

	var reg: BayterekDesignRegistry = Bayterek.get_designs_registry()
	reg.add_design(saved)
	Bayterek.save_designs_registry()

	EditorInterface.get_resource_filesystem().scan()

	return saved

static func duplicate_design(source: BayterekNodeDesign) -> BayterekNodeDesign:
	if not source:
		return null

	_ensure_designs_dir()

	var base_name: String = source.name + " Copy"
	var unique_name: String = _make_unique_name(base_name)
	var snake: String = Bayterek.to_snake_case(unique_name)
	var file_path: String = "%s/%s.tres" % [Bayterek.get_designs_dir(), snake]

	# --- DEBUG ---
	print("[duplicate_design] SOURCE instance=", source.get_instance_id(), " source.id=", source.id, " source.layers=", source.layers.size())
	print("[duplicate_design] TARGET name=", unique_name, " path=", file_path)

	var copy: BayterekNodeDesign = source.duplicate_design()
	copy.id = snake
	copy.name = unique_name

	# --- DEBUG ---
	print("[duplicate_design] COPY instance=", copy.get_instance_id(), " copy.id=", copy.id, " copy.layers=", copy.layers.size())

	var err: Error = Bayterek.safe_save(copy, file_path)
	if err != OK:
		BayterekLogger.error("Could not save duplicated design (%d): %s" % [err, file_path], "designs")
		return null

	var saved: BayterekNodeDesign = ResourceLoader.load(file_path, "BayterekNodeDesign", ResourceLoader.CACHE_MODE_IGNORE)
	if not saved:
		return null

	# --- DEBUG ---
	print("[duplicate_design] LOADED instance=", saved.get_instance_id(), " saved.id=", saved.id, " saved.layers=", saved.layers.size())

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

	# --- DEBUG ---
	print("[save_design] instance=", design.get_instance_id(), " id=", design.id, " name=", design.name, " path=", design.resource_path, " layers=", design.layers.size())

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