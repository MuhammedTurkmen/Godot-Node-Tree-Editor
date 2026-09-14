@tool
class_name BayterekAllocationService
extends BayterekBaseService
## Allocation / preallocation / refund management.
##
## RULES:
## - Root nodes can always be allocated
## - A node can only be allocated if a neighbor (in or out) is already allocated
## - Deallocation: remaining nodes must still be connected to at least one root (strict graph check)
## - Multi-allocation: a node can be allocated multiple times (up to max_allocations)
## - Refund mode: special mode for batch deallocation

signal node_preallocated(node: BayterekNodeButton)
signal node_unpreallocated(node: BayterekNodeButton)

signal node_allocated(node: BayterekNodeButton)
signal node_deallocated(node: BayterekNodeButton)

signal refund_mode_entered
signal refund_mode_exited
signal node_refund_added(node: BayterekNodeButton)
signal node_refund_removed(node: BayterekNodeButton)

# External check callbacks
var preallocation_check: Callable
var allocation_check: Callable
var deallocation_check: Callable
var refund_check: Callable

# Runtime state
var _preallocated_nodes: Array[int] = []
var _refund_nodes: Array[int] = []
var _refund_mode: bool = false

# Shortcut — _tree_data.tree_state
var _allocated_nodes: Array[int]:
	get: return _tree_data.tree_state.allocated_nodes if _tree_data else []
var _allocation_level: Dictionary:
	get: return _tree_data.tree_state.allocation_level if _tree_data else {}

# ============================================================
# LOAD
# ============================================================

func load_tree(tree_data: BayterekTree) -> void:
	_tree_data = tree_data

	if not _tree_data:
		return
	if not _tree_data.tree_state:
		_tree_data.tree_state = BayterekTreeState.new()

	# Apply saved allocation state to nodes
	for node_id in _allocated_nodes:
		var node: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
		if not node:
			continue
		node.allocated = true
		node.set_state(Bayterek.AllocationState.ACTIVE)
		if _tree_data.multiallocation:
			node.allocation_level = _allocation_level.get(node_id, 1)
		node_allocated.emit(node)

# ============================================================
# MAIN ENTRY — NODE PRESSED
# ============================================================

func on_node_pressed(node: BayterekNodeButton) -> void:
	if not node:
		return
	if not _tree_data or not _tree_data.allocation:
		return

	if _tree_data.preallocation:
		if _refund_mode:
			_handle_refund_click(node)
		else:
			_handle_preallocation_click(node)
	else:
		_handle_direct_click(node)

# --- Preallocation flow ---
func _handle_preallocation_click(node: BayterekNodeButton) -> void:
	var pre_size: int = _preallocated_nodes.size()

	if _can_preallocate(node):
		_preallocated_nodes.append(node.id)
		node.preallocated = true
		node_preallocated.emit(node)
	elif _is_valid_deallocation(node, _get_remaining_post_unpreallocation(node.id)):
		_preallocated_nodes.erase(node.id)
		node.preallocated = false
		node_unpreallocated.emit(node)

	# CTRL held + new preallocation → confirm immediately
	if Input.is_key_pressed(KEY_CTRL) and pre_size == 0:
		confirm_preallocations()

# --- Direct allocation flow ---
func _handle_direct_click(node: BayterekNodeButton) -> void:
	if _can_allocate(node):
		_allocate_node(node)
	elif _is_valid_deallocation(node, _get_remaining_nodes(node.id)):
		_deallocate_node(node)

# --- Refund mode flow ---
func _handle_refund_click(node: BayterekNodeButton) -> void:
	var pre_size: int = _refund_nodes.size()

	if _can_stage_for_refund(node):
		node.refund = true
		_refund_nodes.append(node.id)
		node_refund_added.emit(node)
	elif _refund_nodes.has(node.id) and _can_unstage_refund(node):
		node.refund = false
		_refund_nodes.erase(node.id)
		node_refund_removed.emit(node)

	# CTRL batch confirm
	if Input.is_key_pressed(KEY_CTRL) and pre_size == 0:
		confirm_refund()

# ============================================================
# PUBLIC API
# ============================================================

func confirm_preallocations() -> void:
	for node_id in _preallocated_nodes:
		var node: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
		if node:
			_allocate_node(node)
	_preallocated_nodes.clear()

func clear_preallocations() -> void:
	for node_id in _preallocated_nodes:
		var node: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
		if node:
			node.preallocated = false
			node_unpreallocated.emit(node)
	_preallocated_nodes.clear()

func enter_refund_mode() -> void:
	if _refund_mode:
		exit_refund_mode()
		return

	clear_preallocations()
	_refund_mode = true
	_refund_nodes.clear()
	refund_mode_entered.emit()

func exit_refund_mode() -> void:
	for node_id in _refund_nodes:
		var node: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
		if node:
			node.refund = false
			node_refund_removed.emit(node)
	_refund_nodes.clear()
	_refund_mode = false
	refund_mode_exited.emit()

func confirm_refund() -> void:
	for node_id in _refund_nodes:
		var node: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
		if node:
			_deallocate_node(node)
	_refund_nodes.clear()
	_refund_mode = false
	refund_mode_exited.emit()

func is_refund_mode() -> bool:
	return _refund_mode

func get_refund_nodes() -> Array[int]:
	return _refund_nodes.duplicate()

# ============================================================
# REFUND ALL
# ============================================================

## Stages ALL currently allocated nodes for refund.
## Does not deallocate immediately — user must confirm.
func stage_all_for_refund() -> void:
	if not _refund_mode:
		enter_refund_mode()

	for node_id in _allocated_nodes:
		if _refund_nodes.has(node_id):
			continue

		var node: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
		if not node:
			continue

		node.refund = true
		_refund_nodes.append(node_id)
		node_refund_added.emit(node)

# ============================================================
# ALLOCATION CHECKS
# ============================================================

func _can_preallocate(node: BayterekNodeButton) -> bool:
	if preallocation_check and not preallocation_check.call():
		return false

	if _tree_data.multiallocation:
		if node.preallocated:
			return false
		if node.allocated:
			if _allocation_level.get(node.id, 0) >= node.max_allocations:
				return false
	else:
		if node.allocated or node.preallocated:
			return false

	if node.is_root:
		return true

	var active_nodes: Array = _get_active_nodes()
	for in_id in node.node_data.in_nodes:
		if active_nodes.has(in_id):
			return true
	for out_id in node.node_data.out_nodes:
		if active_nodes.has(out_id):
			return true
	return false

func _can_allocate(node: BayterekNodeButton) -> bool:
	if allocation_check and not allocation_check.call():
		return false

	if _tree_data.multiallocation:
		if node.allocated:
			if _allocation_level.get(node.id, 0) >= node.max_allocations:
				return false
		if node.preallocated:
			return false
	else:
		if node.allocated:
			return false

	if node.is_root:
		return true

	for in_id in node.node_data.in_nodes:
		if _allocated_nodes.has(in_id):
			return true
	for out_id in node.node_data.out_nodes:
		if _allocated_nodes.has(out_id):
			return true
	return false

func _can_stage_for_refund(node: BayterekNodeButton) -> bool:
	if refund_check and not refund_check.call():
		return false
	if not node.allocated or _refund_nodes.has(node.id):
		return false

	if _tree_data.multiallocation:
		return _is_valid_deallocation(node, _get_remaining_post_deallocation(node.id))

	var remaining: Array[int] = _allocated_nodes.filter(
		func(id): return id != node.id and not _refund_nodes.has(id)
	)
	return _is_valid_deallocation(node, remaining)

func _can_unstage_refund(node: BayterekNodeButton) -> bool:
	var remaining: Array[int] = _allocated_nodes.filter(
		func(id): return not _refund_nodes.has(id) or id == node.id
	)

	if remaining.size() == _allocated_nodes.size():
		return true

	return _is_valid_deallocation(node, remaining)

# ============================================================
# STRICT GRAPH CHECK — _is_valid_deallocation
# ============================================================

func _is_valid_deallocation(node: BayterekNodeButton, remaining: Array[int]) -> bool:
	if deallocation_check and not deallocation_check.call():
		return false

	if _refund_mode:
		if not node.allocated:
			return false
	else:
		if not node.preallocated and not node.allocated:
			return false

	if remaining.is_empty():
		return true

	# All remaining nodes must still be connected to at least one root
	var visited: Dictionary = {}
	var stack: Array = []

	for node_id in remaining:
		var n: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
		if n and n.is_root:
			stack.append(n)
			visited[n.id] = true

	while not stack.is_empty():
		var current: BayterekNodeButton = stack.pop_back()
		var neighbors: Array = current.node_data.in_nodes + current.node_data.out_nodes

		for neighbor_id in neighbors:
			if not remaining.has(neighbor_id):
				continue
			if visited.has(neighbor_id):
				continue

			var neighbor_node: BayterekNodeButton = _tree_view.nodes_service.get_node(neighbor_id)
			if neighbor_node:
				visited[neighbor_id] = true
				stack.append(neighbor_node)

	for node_id in remaining:
		if not visited.has(node_id):
			return false

	return true

# ============================================================
# HELPERS — REMAINING LISTS
# ============================================================

func _get_active_nodes() -> Array[int]:
	return _allocated_nodes + _preallocated_nodes

func _get_remaining_nodes(excluded_id: int, include_prealloc: bool = false) -> Array[int]:
	if _tree_data.multiallocation:
		return _get_remaining_post_deallocation(excluded_id, include_prealloc)

	var base: Array[int] = _allocated_nodes.duplicate()
	if include_prealloc:
		base += _preallocated_nodes
	return base.filter(func(id): return id != excluded_id)

func _get_remaining_post_deallocation(target_node_id: int, include_prealloc: bool = false) -> Array[int]:
	var remaining: Array[int] = []
	var resulting_levels: Dictionary = {}

	for node_id in _allocated_nodes:
		resulting_levels[node_id] = _allocation_level.get(node_id, 1)

	if _refund_mode:
		for refund_id in _refund_nodes:
			if resulting_levels.has(refund_id):
				resulting_levels[refund_id] -= 1
				if resulting_levels[refund_id] <= 0:
					resulting_levels.erase(refund_id)

	if resulting_levels.has(target_node_id):
		resulting_levels[target_node_id] -= 1
		if resulting_levels[target_node_id] <= 0:
			resulting_levels.erase(target_node_id)

	remaining.append_array(resulting_levels.keys())

	if include_prealloc:
		for node_id in _preallocated_nodes:
			if node_id != target_node_id and not remaining.has(node_id):
				remaining.append(node_id)

	return remaining

func _get_remaining_post_unpreallocation(target_node_id: int) -> Array[int]:
	var remaining: Array[int] = _allocated_nodes.duplicate()
	for node_id in _preallocated_nodes:
		if node_id == target_node_id:
			continue
		if not remaining.has(node_id):
			remaining.append(node_id)
	return remaining

# ============================================================
# ALLOCATE / DEALLOCATE (INTERNAL)
# ============================================================

func _allocate_node(node: BayterekNodeButton) -> void:
	if _tree_data.multiallocation:
		if _allocation_level.has(node.id):
			_allocation_level[node.id] += 1
		else:
			_allocation_level[node.id] = 1
			_allocated_nodes.append(node.id)
			node.allocated = true
		node.allocation_level = _allocation_level[node.id]
	else:
		if not _allocated_nodes.has(node.id):
			_allocated_nodes.append(node.id)
		node.allocated = true

	node.preallocated = false
	node_allocated.emit(node)

func _deallocate_node(node: BayterekNodeButton) -> void:
	if _tree_data.multiallocation:
		if _allocation_level.has(node.id):
			_allocation_level[node.id] -= 1
			node.allocation_level = _allocation_level[node.id]
			if _allocation_level[node.id] <= 0:
				_allocation_level.erase(node.id)
				_allocated_nodes.erase(node.id)
				node.allocated = false
	else:
		_allocated_nodes.erase(node.id)
		node.allocated = false

	node.refund = false
	node_deallocated.emit(node)

# ============================================================
# RELOAD FROM STATE
# ============================================================

## Re-applies tree_state to runtime nodes.
## Call this after loading a save file.
func reload_from_state() -> void:
	if not _tree_data or not _tree_data.tree_state:
		return

	# Clear current runtime state
	_preallocated_nodes.clear()
	_refund_nodes.clear()
	_refund_mode = false

	# Reset all nodes
	for node in _tree_view.nodes_service.get_all_nodes():
		node.allocated = false
		node.preallocated = false
		node.refund = false
		node.allocation_level = 0
		node.set_state(Bayterek.AllocationState.NORMAL)

	# Apply loaded state
	for node_id in _allocated_nodes:
		var node: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
		if not node:
			continue
		node.allocated = true
		node.set_state(Bayterek.AllocationState.ACTIVE)
		if _tree_data.multiallocation:
			node.allocation_level = _allocation_level.get(node_id, 1)

	# Refresh neighbors so INTERMEDIATE states appear
	for node in _tree_view.nodes_service.get_all_nodes():
		if not node.allocated and not node.preallocated:
			_tree_view.nodes_service._refresh_node_state(node)