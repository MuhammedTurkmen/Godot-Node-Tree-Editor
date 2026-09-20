@tool
class_name BayterekDesignService
extends RefCounted
## Design CRUD + disk operations.
## All design files live in res://data/bayterek/designs/.
##
## File naming: snake_case of the design name + ".tres"
## ID: same as file basename (unique)

signal design_created(design: BayterekNodeDesign)
signal design_removed(design: BayterekNodeDesign)
signal design_renamed(design: BayterekNodeDesign, old_id: String)
signal designs_reloaded

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

# ============================================================
# QUERY
# ============================================================

## Returns all designs from the registry.
static func get_all_designs() -> Array:
	var reg: BayterekDesignRegistry = Bayterek.get_designs_registry()
	if not reg:
		return []
	return reg.designs.duplicate()

## Returns a design by its id, or null.
static func get_design(design_id: String) -> BayterekNodeDesign:
	var reg: BayterekDesignRegistry = Bayterek.get_designs_registry()
	if not reg:
		return null
	return reg.get_design_by_id(design_id)

## True if a design with this id exists.
static func has_design(design_id: String) -> bool:
	return get_design(design_id) != null

# ============================================================
# CREATE
# ============================================================

## Creates a new design and saves it to disk.
## Returns the created design, or null on failure.
## If `base_name` conflicts, appends a counter.
static func create_design(base_name: String = "New Design", category: String = "") -> BayterekNodeDesign:
	_ensure_designs_dir()

	var unique_name: String = _make_unique_name(base_name)
	var snake: String = Bayterek.to_snake_case(unique_name)
	var file_path: String = "%s/%s.tres" % [Bayterek.get_designs_dir(), snake]

	var design := BayterekNodeDesign.new()
	design.id = snake
	design.name = unique_name
	design.category = category
	design.design_size = Vector2(100, 100)
	design.scale = Vector2.ONE

	# --- Default background layer ---
	# Start from a fresh shape layer so it inherits ALL default field values
	# from BayterekShapeLayer._init() (fill_configs, border_configs,
	# corner_radius, shadow settings, etc). Then override just what we
	# want for the default design.
	var shape := BayterekShapeLayer.new()
	shape.layer_name = "Background"
	shape.shape_type = BayterekShapeLayer.ShapeType.SQUARE
	shape.transform.size = design.design_size

	# Corner radius: a pleasing default that scales with the design size.
	# The layer will clamp it against its own geometry at render time.
	shape.corner_radius = design.design_size.x * 0.15

	# Enable fill + border with the "normal" state only.
	# Other states keep their default (disabled) values from the layer's
	# default configs, so the user can enable them later without losing
	# the pre-populated palette.
	shape.fill_enabled = true
	shape.border_enabled = true
	shape.border_width = 2.0

	# Override just the "normal" fill/border colors — merge into the
	# existing defaults so hover/locked/etc. configs are preserved.
	shape.fill_configs["normal"] = {
		"enabled": true,
		"color": Color(0.4, 0.7, 1.0, 1.0),
	}
	shape.border_configs["normal"] = {
		"enabled": true,
		"color": Color(1.0, 1.0, 1.0, 1.0),
	}

	design.add_layer(shape)

	var err: Error = ResourceSaver.save(design, file_path)
	if err != OK:
		push_error("Bayterek: Could not save design (%d): %s" % [err, file_path])
		return null

	var saved: BayterekNodeDesign = ResourceLoader.load(file_path, "BayterekNodeDesign", ResourceLoader.CACHE_MODE_IGNORE)
	if not saved:
		push_error("Bayterek: Could not reload design after save: %s" % file_path)
		return null

	saved.resource_path = file_path

	var reg: BayterekDesignRegistry = Bayterek.get_designs_registry()
	reg.add_design(saved)
	Bayterek.save_designs_registry()

	EditorInterface.get_resource_filesystem().scan()

	return saved

## Duplicates an existing design.
static func duplicate_design(source: BayterekNodeDesign) -> BayterekNodeDesign:
	if not source:
		return null

	_ensure_designs_dir()

	var base_name: String = source.name + " Copy"
	var unique_name: String = _make_unique_name(base_name)
	var snake: String = Bayterek.to_snake_case(unique_name)
	var file_path: String = "%s/%s.tres" % [Bayterek.get_designs_dir(), snake]

	var copy: BayterekNodeDesign = source.duplicate_design()
	copy.id = snake
	copy.name = unique_name

	var err: Error = ResourceSaver.save(copy, file_path)
	if err != OK:
		push_error("Bayterek: Could not save duplicated design (%d): %s" % [err, file_path])
		return null

	var saved: BayterekNodeDesign = ResourceLoader.load(file_path, "BayterekNodeDesign", ResourceLoader.CACHE_MODE_IGNORE)
	if not saved:
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

## Saves the design to its current resource_path.
static func save_design(design: BayterekNodeDesign) -> Error:
	if not design:
		return FAILED
	if design.resource_path.is_empty():
		push_error("Bayterek: Cannot save design with empty resource_path.")
		return FAILED

	return ResourceSaver.save(design, design.resource_path)

## Renames a design (updates name + moves file if needed).
static func rename_design(design: BayterekNodeDesign, new_name: String) -> bool:
	if not design:
		return false
	if new_name.strip_edges().is_empty():
		return false

	var trimmed: String = new_name.strip_edges()
	if trimmed == design.name:
		return true

	var old_id: String = design.id
	var new_snake: String = Bayterek.to_snake_case(trimmed)
	var old_path: String = design.resource_path
	var new_path: String = "%s/%s.tres" % [Bayterek.get_designs_dir(), new_snake]

	# Same id? Only update the display name.
	if new_snake == design.id:
		design.set_design_name(trimmed)
		save_design(design)
		Bayterek.save_designs_registry()
		return true

	# Collision check
	if FileAccess.file_exists(new_path):
		push_warning("Bayterek: Design file already exists: %s" % new_path)
		return false

	# Ensure unique id
	if Bayterek.get_designs_registry().has_design_id(new_snake):
		push_warning("Bayterek: Design id already in use: %s" % new_snake)
		return false

	# Rename file on disk
	if not old_path.is_empty() and FileAccess.file_exists(old_path):
		var rename_err: Error = DirAccess.rename_absolute(old_path, new_path)
		if rename_err != OK:
			push_error("Bayterek: Could not rename design file (%d)" % rename_err)
			return false

	design.id = new_snake
	design.set_design_name(trimmed)
	design.resource_path = new_path

	save_design(design)
	Bayterek.save_designs_registry()
	EditorInterface.get_resource_filesystem().scan()

	return true

# ============================================================
# DELETE
# ============================================================

## Deletes a design and its file. Returns true on success.
static func delete_design(design: BayterekNodeDesign) -> bool:
	if not design:
		return false

	var path: String = design.resource_path
	var reg: BayterekDesignRegistry = Bayterek.get_designs_registry()
	reg.remove_design(design)

	# Remove file
	if not path.is_empty() and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	# Remove .uid sidecar if present
	var uid_path: String = path + ".uid"
	if FileAccess.file_exists(uid_path):
		DirAccess.remove_absolute(uid_path)

	Bayterek.save_designs_registry()
	EditorInterface.get_resource_filesystem().scan()

	return true

# ============================================================
# RELOAD
# ============================================================

## Reloads the designs registry from disk.
static func reload() -> void:
	Bayterek.reload_designs_registry()

# ============================================================
# PRIVATE
# ============================================================

static func _ensure_designs_dir() -> void:
	var dir_path: String = Bayterek.get_designs_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

## Generates a unique display name based on `base_name`.
## If "Name" exists, tries "Name 2", "Name 3", ...
static func _make_unique_name(base_name: String) -> String:
	var trimmed: String = base_name.strip_edges()
	if trimmed.is_empty():
		trimmed = "New Design"

	var reg: BayterekDesignRegistry = Bayterek.get_designs_registry()
	if not reg:
		return trimmed

	# Build a set of existing names
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