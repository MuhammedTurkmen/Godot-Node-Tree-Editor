@tool
extends Node
## Autoload: BayterekLoader. Registry + design API.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

var _registry: BayterekRegistry

func _init() -> void:
	_load_registry()

# ============================================================
# TREE API
# ============================================================

func get_registry() -> BayterekRegistry:
	return _registry

func load_tree(path: String, as_unique: bool = false) -> BayterekTree:
	if not _registry:
		push_error("Bayterek: registry not loaded.")
		return null

	var lower: String = path.to_lower()
	for group: BayterekGroup in _registry.groups:
		for tree: BayterekTree in group.trees:
			var key: String = "%s/%s" % [group.name.to_lower(), tree.name.to_lower()]
			if key == lower:
				if as_unique:
					return tree.duplicate(true) as BayterekTree
				return tree

	push_error("Bayterek: tree not found in registry: '%s'" % path)
	return null

func add_tree_to_registry(group: BayterekGroup, tree: BayterekTree) -> void:
	if not _registry:
		return
	if not _registry.groups.has(group):
		_registry.groups.append(group)
	if not group.trees.has(tree):
		group.trees.append(tree)

func reload_registry() -> void:
	_load_registry()

# ============================================================
# DESIGN API
# ============================================================

## Returns all node designs. Editor-only usage is fine at runtime too
## if you want to look up a design by id.
func get_all_designs() -> Array:
	return BayterekDesignService.get_all_designs()

## Returns a design by id, or null.
func get_design(design_id: String) -> BayterekNodeDesign:
	return BayterekDesignService.get_design(design_id)

## True if a design with this id exists.
func has_design(design_id: String) -> bool:
	return BayterekDesignService.has_design(design_id)

func reload_designs() -> void:
	BayterekDesignService.reload()

# ============================================================
# PRIVATE
# ============================================================

func _load_registry() -> void:
	var path: String = Bayterek.get_registry_path()

	if not ResourceLoader.exists(path):
		if OS.has_feature("editor"):
			_create_registry()
		else:
			push_error("Bayterek: registry file missing: %s" % path)
			return

	_registry = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as BayterekRegistry
	if not _registry:
		push_error("Bayterek: could not load registry: %s" % path)

func _create_registry() -> void:
	var root: String = Bayterek.get_root_path()
	DirAccess.make_dir_recursive_absolute(root)

	_registry = BayterekRegistry.new()
	var err: Error = ResourceSaver.save(_registry, Bayterek.get_registry_path())
	if err != OK:
		push_error("Bayterek: could not create registry (err=%d)" % err)
	else:
		print("Bayterek: registry created: ", Bayterek.get_registry_path())