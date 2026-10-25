@tool
extends Node
## Autoload: BayterekLoader. Registry + design API.
##
## Also acts as a global keyboard hook for undo/redo.
##
## SKILL TREE JSON API:
##   The JSON file at `<tree_path>.json` is the SOURCE OF TRUTH for
##   a tree's structure, attributes, node values and initial state.
##   The .tres is a lightweight runtime mirror that Godot can load
##   natively. The editor writes both; the runtime reads JSON first,
##   then falls back to .tres if the JSON is missing.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

var _registry: BayterekRegistry

## Weak reference to the currently-active Node Editor screen (if any).
var _active_node_editor: Node = null

func _init() -> void:
	_load_registry()

func _ready() -> void:
	set_process_input(true)
	set_process_unhandled_key_input(true)

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

func get_all_designs() -> Array:
	return BayterekDesignService.get_all_designs()

func get_design(design_id: String) -> BayterekNodeDesign:
	return BayterekDesignService.get_design(design_id)

func has_design(design_id: String) -> bool:
	return BayterekDesignService.has_design(design_id)

func reload_designs() -> void:
	BayterekDesignService.reload()

# ============================================================
# SKILL TREE JSON API
# ============================================================

static func get_tree_json_path(tree: BayterekTree) -> String:
	if not tree:
		return ""
	if tree.resource_path.is_empty():
		return ""
	return tree.resource_path.get_basename() + ".json"

static func has_tree_json(tree: BayterekTree) -> bool:
	var path := get_tree_json_path(tree)
	return not path.is_empty() and FileAccess.file_exists(path)

func load_tree_from_json(tree: BayterekTree) -> BayterekSkillTreeData:
	if not tree:
		return null
	var path := get_tree_json_path(tree)
	if path.is_empty():
		push_error("BayterekLoader: tree has no resource_path; cannot locate JSON.")
		return null
	if not FileAccess.file_exists(path):
		push_error("BayterekLoader: JSON not found: %s" % path)
		return null

	# Skip hydration if the tree is completely empty. This is the
	# "newly created tree" case — we do NOT want to overwrite it with
	# leftover JSON.
	if _is_tree_empty(tree):
		BayterekLogger.info("Skipping JSON hydration: tree '%s' is empty (new)." % tree.name, "loader")
		return null

	var raw := BayterekSkillTreeJson.load_file(path)
	if raw.is_empty():
		return null

	var data := BayterekSkillTreeJson.dict_to_data(raw)
	_apply_data_to_tree(tree, data)
	return data

func save_tree_to_json(tree: BayterekTree) -> Error:
	if not tree:
		return ERR_INVALID_PARAMETER
	var path := get_tree_json_path(tree)
	if path.is_empty():
		return ERR_INVALID_PARAMETER

	# Guard: don't write JSON for a tree whose .tres no longer exists
	# on disk. This prevents resurrecting .json files for deleted trees.
	if not tree.resource_path.is_empty() and not FileAccess.file_exists(tree.resource_path):
		BayterekLogger.warn("Refusing to write JSON for missing .tres: %s" % tree.resource_path, "loader")
		return ERR_FILE_NOT_FOUND

	var data := _tree_to_data(tree)
	var raw := BayterekSkillTreeJson.data_to_dict(data)
	return BayterekSkillTreeJson.save_file(path, raw)

func ensure_tree_loaded(tree: BayterekTree) -> BayterekSkillTreeData:
	if not tree:
		return null
	if has_tree_json(tree):
		return load_tree_from_json(tree)
	return null

func _is_tree_empty(tree: BayterekTree) -> bool:
	if not tree:
		return true
	if not tree.attributes.is_empty():
		return false
	if not tree.nodes.is_empty():
		return false
	if tree.tree_state:
		if not tree.tree_state.allocated_nodes.is_empty():
			return false
		if not tree.tree_state.allocation_level.is_empty():
			return false
	return true

# ============================================================
# TREE <-> DATA
# ============================================================

func _apply_data_to_tree(tree: BayterekTree, data: BayterekSkillTreeData) -> void:
	# Attributes: merge currencies + skills into tree.attributes.
	# The split is preserved in `data`, but the tree still needs a
	# single flat dictionary for the existing editor UI.
	tree.attributes.clear()
	for attr_id in data.currency_attributes.keys():
		tree.attributes[attr_id] = data.currency_attributes[attr_id]
	for attr_id in data.skill_attributes.keys():
		tree.attributes[attr_id] = data.skill_attributes[attr_id]

	# Nodes.
	tree.nodes.clear()
	for node in data.nodes:
		tree.nodes.append(node)

	# Sanitize currency values (clamp negative → 0).
	for node in tree.nodes:
		if node:
			node.sanitize_currency_values(tree)

	# Initial allocation.
	if not tree.tree_state:
		tree.tree_state = BayterekTreeState.new()
	tree.tree_state.allocated_nodes = data.initial_allocated.duplicate()
	tree.tree_state.allocation_level = data.initial_levels.duplicate()

func _tree_to_data(tree: BayterekTree) -> BayterekSkillTreeData:
	var data := BayterekSkillTreeData.new()
	data.tree_id = tree.id
	data.tree_name = tree.name

	for attr_id in tree.attributes.keys():
		var attr: BayterekAttribute = tree.attributes[attr_id]
		if not attr:
			continue
		if attr.is_currency:
			data.currency_attributes[attr_id] = attr
		else:
			data.skill_attributes[attr_id] = attr

	data.nodes = tree.nodes.duplicate()

	if tree.tree_state:
		data.initial_allocated = tree.tree_state.allocated_nodes.duplicate()
		data.initial_levels = tree.tree_state.allocation_level.duplicate()

	return data

# ============================================================
# NODE EDITOR REGISTRATION
# ============================================================

func register_node_editor(editor: Node) -> void:
	_active_node_editor = editor

func unregister_node_editor(editor: Node) -> void:
	if _active_node_editor == editor:
		_active_node_editor = null

# ============================================================
# GLOBAL INPUT HOOK (undo / redo)
# ============================================================

func _input(event: InputEvent) -> void:
	if not _active_node_editor:
		return
	if not is_instance_valid(_active_node_editor):
		_active_node_editor = null
		return
	if not _active_node_editor.is_visible_in_tree():
		return

	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if not (event.ctrl_pressed or event.meta_pressed):
		return

	var key: int = event.keycode
	var shift: bool = event.shift_pressed

	if key == KEY_Z and not shift:
		if _active_node_editor.has_method("try_handle_undo"):
			if _active_node_editor.try_handle_undo():
				get_viewport().set_input_as_handled()
		return

	if key == KEY_Y or (key == KEY_Z and shift):
		if _active_node_editor.has_method("try_handle_redo"):
			if _active_node_editor.try_handle_redo():
				get_viewport().set_input_as_handled()
		return

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