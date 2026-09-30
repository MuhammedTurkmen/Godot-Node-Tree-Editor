@tool
extends Node
## Autoload: BayterekLoader. Registry + design API.
##
## Also acts as a global keyboard hook for undo/redo. The Godot editor
## reserves Ctrl+Z / Ctrl+Y for its own undo system and consumes them
## before any child Control's _shortcut_input() handler runs. By
## intercepting at the Autoload level — which sits ABOVE the editor's
## shortcut dispatcher in the input stack — we can guarantee that our
## undo fires first when a Node Editor screen is active.
##
## The screen registers itself via register_node_editor() on _ready()
## and unregisters on _exit_tree(). Only ONE screen can be active at a
## time; the most recent registration wins.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

var _registry: BayterekRegistry

## Weak reference to the currently-active Node Editor screen (if any).
## We use a plain `Node` type here to avoid a hard class dependency, and
## guard every access with is_instance_valid().
var _active_node_editor: Node = null

func _init() -> void:
	_load_registry()

func _ready() -> void:
	# Ensure we receive keyboard input even when no other node has focus.
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
# NODE EDITOR REGISTRATION
# ============================================================

## Called by a BayterekNodeEditorScreen when it becomes the active
## screen. Only one screen can be active at a time — the most recent
## caller wins.
func register_node_editor(editor: Node) -> void:
	_active_node_editor = editor

## Called by a BayterekNodeEditorScreen when it's torn down or loses
## focus. Only clears the reference if it still points at `editor` —
## this prevents a stale teardown from clearing a newer registration.
func unregister_node_editor(editor: Node) -> void:
	if _active_node_editor == editor:
		_active_node_editor = null

# ============================================================
# GLOBAL INPUT HOOK (undo / redo)
# ============================================================

## Intercept Ctrl+Z / Ctrl+Y / Ctrl+Shift+Z at the Autoload level.
##
## Autoloads are children of the root Window and get their _input()
## called BEFORE the Godot editor's own global shortcut handling — so
## this is the earliest safe place to steal the keystroke.
##
## We only consume the event if the active screen actually performed an
## undo/redo. If its stack was empty (or no screen is registered, or a
## text field has focus) we let the event fall through to the editor.
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