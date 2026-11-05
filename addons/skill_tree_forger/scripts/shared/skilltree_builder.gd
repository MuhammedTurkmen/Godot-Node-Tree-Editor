@tool
class_name SkillTreeBuilder
extends RefCounted
## Builder for creating runtime SkillTreeView instances.
##
## Usage:
##   var view = SkillTreeBuilder.new(tree) \
##       .set_parent(some_control) \
##       .node_allocated_callback(_on_allocated) \
##       .wallet_can_afford_callback(_on_can_afford) \
##       .wallet_spend_callback(_on_spend) \
##       .wallet_refund_callback(_on_refund) \
##       .build()
##
## The builder returns a SkillTreeView with services already wired.

var _tree: SkillTree
var _parent: Node
var _save_path: String = ""

var _tree_version_mismatch_callback: Callable

var _node_created_callback: Callable
var _node_allocated_callback: Callable
var _node_deallocated_callback: Callable
var _node_pressed_callback: Callable

var _prefab_created_callback: Callable
var _line_created_callback: Callable

var _preallocation_check_callback: Callable
var _allocation_check_callback: Callable
var _deallocation_check_callback: Callable
var _refund_check_callback: Callable

# --- Wallet callbacks (currency / cost integration) ---
#
# The host game provides these. Bayterek never stores currency; it
# just asks "is this affordable?" and "charge / refund this much".
# All three callbacks receive (attribute_id: String, amount: int).
#
# If a callback is not set, the operation is treated as allowed / a no-op.
var _wallet_can_afford_callback: Callable
var _wallet_spend_callback: Callable
var _wallet_refund_callback: Callable

func _init(tree_data: SkillTree) -> void:
	_tree = tree_data

# ============================================================
# SETTERS
# ============================================================

func set_parent(parent: Node) -> SkillTreeBuilder:
	_parent = parent
	return self

func set_save_path(save_path: String) -> SkillTreeBuilder:
	_save_path = save_path
	return self

func tree_version_mismatch_callback(callback: Callable) -> SkillTreeBuilder:
	_tree_version_mismatch_callback = callback
	return self

func node_created_callback(callback: Callable) -> SkillTreeBuilder:
	_node_created_callback = callback
	return self

func node_allocated_callback(callback: Callable) -> SkillTreeBuilder:
	_node_allocated_callback = callback
	return self

func node_deallocated_callback(callback: Callable) -> SkillTreeBuilder:
	_node_deallocated_callback = callback
	return self

func node_pressed_callback(callback: Callable) -> SkillTreeBuilder:
	_node_pressed_callback = callback
	return self

func prefab_created_callback(callback: Callable) -> SkillTreeBuilder:
	_prefab_created_callback = callback
	return self

func line_created_callback(callback: Callable) -> SkillTreeBuilder:
	_line_created_callback = callback
	return self

func preallocation_check_callback(callback: Callable) -> SkillTreeBuilder:
	_preallocation_check_callback = callback
	return self

func allocation_check_callback(callback: Callable) -> SkillTreeBuilder:
	_allocation_check_callback = callback
	return self

func deallocation_check_callback(callback: Callable) -> SkillTreeBuilder:
	_deallocation_check_callback = callback
	return self

func refund_check_callback(callback: Callable) -> SkillTreeBuilder:
	_refund_check_callback = callback
	return self

# --- Wallet setters ---

## Set the callback that checks whether the player can afford a cost.
## Signature: `func(attr_id: String, amount: int) -> bool`
func wallet_can_afford_callback(callback: Callable) -> SkillTreeBuilder:
	_wallet_can_afford_callback = callback
	return self

## Set the callback that charges the player.
## Signature: `func(attr_id: String, amount: int) -> void`
func wallet_spend_callback(callback: Callable) -> SkillTreeBuilder:
	_wallet_spend_callback = callback
	return self

## Set the callback that refunds the player.
## Signature: `func(attr_id: String, amount: int) -> void`
func wallet_refund_callback(callback: Callable) -> SkillTreeBuilder:
	_wallet_refund_callback = callback
	return self

# ============================================================
# BUILD
# ============================================================

func build() -> SkillTreeView:
	if not _tree:
		push_error("SkillTreeBuilder: tree_data is null. Pass a SkillTree to _init().")
		return null

	if not _parent:
		push_error("SkillTreeBuilder: parent not set. Use set_parent() before build().")
		return null

	# 1. Create the tree view
	var tree_view := SkillTreeView.new()
	tree_view.name = "SkillTreeView"

	# 2. Connect high-level signals BEFORE load_tree so we don't miss emissions
	if _tree_version_mismatch_callback:
		tree_view.tree_version_mismatch.connect(_tree_version_mismatch_callback)

	if _node_created_callback:
		tree_view.node_created.connect(_node_created_callback)

	if _node_allocated_callback:
		tree_view.node_allocated.connect(_node_allocated_callback)

	if _node_deallocated_callback:
		tree_view.node_deallocated.connect(_node_deallocated_callback)

	if _prefab_created_callback:
		tree_view.prefab_created.connect(_prefab_created_callback)

	if _line_created_callback:
		tree_view.line_created.connect(_line_created_callback)

	# 3. Add to scene tree
	tree_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_parent.add_child(tree_view)

	# 4. Load tree state from disk (runtime only)
	if not Engine.is_editor_hint():
		var serializer = _get_serializer()
		if serializer:
			serializer.load_tree_state(_tree, _save_path)

	# 5. Load tree data (creates containers + services)
	tree_view.load_tree(_tree)

	# 6. Wire allocation check callbacks
	if tree_view.allocation_service:
		if _preallocation_check_callback:
			tree_view.allocation_service.preallocation_check = _preallocation_check_callback
		if _allocation_check_callback:
			tree_view.allocation_service.allocation_check = _allocation_check_callback
		if _deallocation_check_callback:
			tree_view.allocation_service.deallocation_check = _deallocation_check_callback
		if _refund_check_callback:
			tree_view.allocation_service.refund_check = _refund_check_callback

		# 7. Wire wallet callbacks
		if _wallet_can_afford_callback:
			tree_view.allocation_service.wallet_can_afford = _wallet_can_afford_callback
		if _wallet_spend_callback:
			tree_view.allocation_service.wallet_spend = _wallet_spend_callback
		if _wallet_refund_callback:
			tree_view.allocation_service.wallet_refund = _wallet_refund_callback

	# 8. Wire node_pressed callback (user hook, if provided)
	if _node_pressed_callback and tree_view.nodes_service:
		tree_view.nodes_service.node_pressed.connect(_node_pressed_callback)

	return tree_view

# ============================================================
# PRIVATE
# ============================================================

## Locates the SkillTreeSerializer autoload at runtime.
## Returns null if not registered (edit mode or plugin disabled).
func _get_serializer() -> Node:
	if not _parent or not _parent.is_inside_tree():
		return null
	var root := _parent.get_tree().root
	return root.get_node_or_null("SkillTreeSerializer")