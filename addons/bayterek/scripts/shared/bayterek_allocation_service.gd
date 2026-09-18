@tool
class_name BayterekAllocationService
extends BayterekBaseService
## Allocation / preallocation / refund management.

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
# PUBLIC GETTERS (for HUD / test scenes)
# ============================================================

func get_preallocated_count() -> int:
	return _preallocated_nodes.size()

func get_refund_count() -> int:
	return _refund_nodes.size()

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

func _handle_preallocation_click(node: BayterekNodeButton) -> void:
	var pre_size: int = _preallocated_nodes.size()

	if _can_preallocate(node):
		_preallocated_nodes.append(node.id)
		node.preallocated = true
		node_preallocated.emit(node)
	else:
		var closure: Array[int] = _get_unpreallocation_closure(node.id)
		if not closure.is_empty():
			for node_id in closure:
				var n: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
				if not n:
					continue
				_preallocated_nodes.erase(node_id)
				n.preallocated = false
				node_unpreallocated.emit(n)

	if Input.is_key_pressed(KEY_CTRL) and pre_size == 0:
		confirm_preallocations()

func _handle_direct_click(node: BayterekNodeButton) -> void:
	if _can_allocate(node):
		_allocate_node(node)
	else:
		var closure: Array[int] = _get_deallocation_closure(node.id)
		if not closure.is_empty():
			for node_id in closure:
				var n: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
				if n:
					_deallocate_node(n)

func _handle_refund_click(node: BayterekNodeButton) -> void:
	var pre_size: int = _refund_nodes.size()

	if node.allocated and not _refund_nodes.has(node.id):
		# STAGE: pull in the full closure of nodes that must go with this one.
		var closure: Array[int] = _get_refund_closure(node.id)
		if _is_closure_valid_for_refund(closure):
			for node_id in closure:
				if _refund_nodes.has(node_id):
					continue
				var n: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
				if not n:
					continue
				n.refund = true
				_refund_nodes.append(node_id)
				node_refund_added.emit(n)
	elif _refund_nodes.has(node.id):
		# UNSTAGE: remove the closure that was staged by this click.
		var closure: Array[int] = _get_refund_closure(node.id)
		var remaining: Array[int] = _allocated_nodes.filter(
			func(id): return not closure.has(id)
		)
		if remaining.is_empty() or _is_valid_deallocation(node, remaining, true):
			for node_id in closure:
				if not _refund_nodes.has(node_id):
					continue
				var n: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
				if not n:
					continue
				n.refund = false
				_refund_nodes.erase(node_id)
				node_refund_removed.emit(n)

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
# PREREQUISITE LOGIC
# ============================================================

func _is_prerequisite_satisfied(node: BayterekNode, active_ids: Array, exclude_ids: Array = []) -> bool:
	if node.is_root:
		return true

	match node.prerequisite_mode:
		BayterekNode.PrerequisiteMode.ANY:
			for nid in node.in_nodes:
				if exclude_ids.has(nid):
					continue
				if active_ids.has(nid):
					return true
			for nid in node.out_nodes:
				if exclude_ids.has(nid):
					continue
				if active_ids.has(nid):
					return true
			return false

		BayterekNode.PrerequisiteMode.COUNT:
			if node.in_nodes.is_empty():
				for nid in node.out_nodes:
					if exclude_ids.has(nid):
						continue
					if active_ids.has(nid):
						return true
				return false

			var count: int = 0
			for nid in node.in_nodes:
				if exclude_ids.has(nid):
					continue
				if active_ids.has(nid):
					count += 1
					if count >= node.prerequisite_count:
						return true
			return false

		BayterekNode.PrerequisiteMode.ALL:
			if node.in_nodes.is_empty():
				for nid in node.out_nodes:
					if exclude_ids.has(nid):
						continue
					if active_ids.has(nid):
						return true
				return false

			for nid in node.in_nodes:
				if exclude_ids.has(nid):
					continue
				if not active_ids.has(nid):
					return false
			return true

	return true

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

	var active_ids: Array = _get_active_nodes()
	return _is_prerequisite_satisfied(node.node_data, active_ids, [])

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

	return _is_prerequisite_satisfied(node.node_data, _allocated_nodes, [])

func _can_stage_for_refund(node: BayterekNodeButton) -> bool:
	if refund_check and not refund_check.call():
		return false
	if not node.allocated or _refund_nodes.has(node.id):
		return false

	return _is_valid_deallocation(node, _get_remaining_post_deallocation(node.id))

func _can_unstage_refund(node: BayterekNodeButton) -> bool:
	var remaining: Array[int] = _allocated_nodes.filter(
		func(id): return not _refund_nodes.has(id) or id == node.id
	)
	if remaining.size() == _allocated_nodes.size():
		return true
	return _is_valid_deallocation(node, remaining, true)

# ============================================================
# GRAPH + PREREQUISITE VALIDITY
# ============================================================

func _is_valid_deallocation(node: BayterekNodeButton, remaining: Array[int], for_unstage: bool = false) -> bool:
	if deallocation_check and not deallocation_check.call():
		return false

	if not for_unstage:
		if _refund_mode:
			if not node.allocated:
				return false
		else:
			if not node.preallocated and not node.allocated:
				return false

	if remaining.is_empty():
		return true

	# 1) Connectivity check
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

	# 2) Prerequisite check
	for node_id in remaining:
		var n: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
		if not n:
			continue
		if not _is_prerequisite_satisfied(n.node_data, remaining, []):
			return false

	return true

# ============================================================
# CLOSURE COMPUTATION
# ============================================================

func _get_refund_closure(start_id: int) -> Array[int]:
	var closure: Array[int] = [start_id]
	var changed: bool = true

	while changed:
		changed = false

		var active_remaining: Array = _allocated_nodes.filter(
			func(id): return not closure.has(id) and not _refund_nodes.has(id)
		)

		for other_id in active_remaining:
			if closure.has(other_id):
				continue
			var other: BayterekNodeButton = _tree_view.nodes_service.get_node(other_id)
			if not other:
				continue
			if not _is_prerequisite_satisfied(other.node_data, active_remaining, []):
				if _is_prerequisite_satisfied(other.node_data, _allocated_nodes, []):
					closure.append(other_id)
					changed = true

		var visited: Dictionary = {}
		var stack: Array = []
		for node_id in active_remaining:
			var n: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
			if n and n.is_root:
				stack.append(n)
				visited[n.id] = true

		while not stack.is_empty():
			var cur: BayterekNodeButton = stack.pop_back()
			var neighbors: Array = cur.node_data.in_nodes + cur.node_data.out_nodes
			for nb_id in neighbors:
				if not active_remaining.has(nb_id):
					continue
				if visited.has(nb_id):
					continue
				var nb: BayterekNodeButton = _tree_view.nodes_service.get_node(nb_id)
				if nb:
					visited[nb_id] = true
					stack.append(nb)

		for node_id in active_remaining:
			if not visited.has(node_id) and not closure.has(node_id):
				closure.append(node_id)
				changed = true

	return closure

func _get_unpreallocation_closure(start_id: int) -> Array[int]:
	var active: Array = _get_active_nodes()
	var closure: Array[int] = [start_id]
	var changed: bool = true

	while changed:
		changed = false

		var active_remaining: Array = active.filter(
			func(id): return not closure.has(id)
		)

		for other_id in active_remaining:
			if closure.has(other_id):
				continue
			var other: BayterekNodeButton = _tree_view.nodes_service.get_node(other_id)
			if not other:
				continue
			if not _is_prerequisite_satisfied(other.node_data, active_remaining, []):
				if _is_prerequisite_satisfied(other.node_data, active, []):
					closure.append(other_id)
					changed = true

		var visited: Dictionary = {}
		var stack: Array = []
		for node_id in active_remaining:
			var n: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
			if n and n.is_root:
				stack.append(n)
				visited[n.id] = true

		while not stack.is_empty():
			var cur: BayterekNodeButton = stack.pop_back()
			var neighbors: Array = cur.node_data.in_nodes + cur.node_data.out_nodes
			for nb_id in neighbors:
				if not active_remaining.has(nb_id):
					continue
				if visited.has(nb_id):
					continue
				var nb: BayterekNodeButton = _tree_view.nodes_service.get_node(nb_id)
				if nb:
					visited[nb_id] = true
					stack.append(nb)

		for node_id in active_remaining:
			if not visited.has(node_id) and not closure.has(node_id):
				closure.append(node_id)
				changed = true

	return closure

func _get_deallocation_closure(start_id: int) -> Array[int]:
	var closure: Array[int] = [start_id]
	var changed: bool = true

	while changed:
		changed = false

		var active_remaining: Array = _allocated_nodes.filter(
			func(id): return not closure.has(id)
		)

		for other_id in active_remaining:
			if closure.has(other_id):
				continue
			var other: BayterekNodeButton = _tree_view.nodes_service.get_node(other_id)
			if not other:
				continue
			if not _is_prerequisite_satisfied(other.node_data, active_remaining, []):
				if _is_prerequisite_satisfied(other.node_data, _allocated_nodes, []):
					closure.append(other_id)
					changed = true

		var visited: Dictionary = {}
		var stack: Array = []
		for node_id in active_remaining:
			var n: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
			if n and n.is_root:
				stack.append(n)
				visited[n.id] = true

		while not stack.is_empty():
			var cur: BayterekNodeButton = stack.pop_back()
			var neighbors: Array = cur.node_data.in_nodes + cur.node_data.out_nodes
			for nb_id in neighbors:
				if not active_remaining.has(nb_id):
					continue
				if visited.has(nb_id):
					continue
				var nb: BayterekNodeButton = _tree_view.nodes_service.get_node(nb_id)
				if nb:
					visited[nb_id] = true
					stack.append(nb)

		for node_id in active_remaining:
			if not visited.has(node_id) and not closure.has(node_id):
				closure.append(node_id)
				changed = true

	return closure

# ============================================================
# CLOSURE VALIDITY
# ============================================================

func _is_closure_valid_for_refund(closure: Array[int]) -> bool:
	if closure.is_empty():
		return false

	var remaining: Array[int] = _allocated_nodes.filter(
		func(id): return not closure.has(id) and not _refund_nodes.has(id)
	)

	if remaining.is_empty():
		return true

	var visited: Dictionary = {}
	var stack: Array = []
	for node_id in remaining:
		var n: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
		if n and n.is_root:
			stack.append(n)
			visited[n.id] = true

	while not stack.is_empty():
		var cur: BayterekNodeButton = stack.pop_back()
		var neighbors: Array = cur.node_data.in_nodes + cur.node_data.out_nodes
		for nb_id in neighbors:
			if not remaining.has(nb_id):
				continue
			if visited.has(nb_id):
				continue
			var nb: BayterekNodeButton = _tree_view.nodes_service.get_node(nb_id)
			if nb:
				visited[nb_id] = true
				stack.append(nb)

	for node_id in remaining:
		if not visited.has(node_id):
			return false

	for node_id in remaining:
		var n: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
		if not n:
			continue
		if not _is_prerequisite_satisfied(n.node_data, remaining, []):
			return false

	return true

# ============================================================
# HELPERS
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
# ALLOCATE / DEALLOCATE
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

func reload_from_state() -> void:
	if not _tree_data or not _tree_data.tree_state:
		return

	_preallocated_nodes.clear()
	_refund_nodes.clear()
	_refund_mode = false

	for node in _tree_view.nodes_service.get_all_nodes():
		node.allocated = false
		node.preallocated = false
		node.refund = false
		node.allocation_level = 0
		node.set_state(Bayterek.AllocationState.NORMAL)

	for node_id in _allocated_nodes:
		var node: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
		if not node:
			continue
		node.allocated = true
		node.set_state(Bayterek.AllocationState.ACTIVE)
		if _tree_data.multiallocation:
			node.allocation_level = _allocation_level.get(node_id, 1)

	for node in _tree_view.nodes_service.get_all_nodes():
		if not node.allocated and not node.preallocated:
			_tree_view.nodes_service._refresh_node_state(node)