@tool
class_name BayterekAllocationService
extends BayterekBaseService
## Allocation / preallocation / refund management.
##
## Purchase model (see BayterekTree):
##   - INSTANT mode: a single click allocates immediately.
##   - HOLD mode:    press & hold for `default_hold_duration` seconds.
##
## Refund and preallocation are always INSTANT, regardless of the tree
## setting. HOLD is only used for normal allocation.

signal node_preallocated(node: BayterekNodeButton)
signal node_unpreallocated(node: BayterekNodeButton)
signal node_allocated(node: BayterekNodeButton)
signal node_deallocated(node: BayterekNodeButton)
signal refund_mode_entered
signal refund_mode_exited
signal node_refund_added(node: BayterekNodeButton)
signal node_refund_removed(node: BayterekNodeButton)

## HOLD-mode events. Only emitted when the tree is in HOLD purchase mode
## and the press is a valid allocation candidate.
signal hold_started(node: BayterekNodeButton)
signal hold_progress(node: BayterekNodeButton, t: float)
signal hold_completed(node: BayterekNodeButton)
signal hold_cancelled(node: BayterekNodeButton)

# External check callbacks
var preallocation_check: Callable
var allocation_check: Callable
var deallocation_check: Callable
var refund_check: Callable

# Runtime state
var _preallocated_nodes: Array[int] = []
var _refund_nodes: Array[int] = []
var _refund_mode: bool = false

# HOLD-mode state
var _hold_node: BayterekNodeButton = null
var _hold_elapsed: float = 0.0
var _hold_active: bool = false

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
		var lvl: int = _allocation_level.get(node_id, 1)
		if lvl <= 0:
			lvl = 1
			_allocation_level[node_id] = 1
		node.allocation_level = lvl
		node.refresh_state_only()
		node_allocated.emit(node)

# ============================================================
# PUBLIC GETTERS
# ============================================================

func get_preallocated_count() -> int:
	return _preallocated_nodes.size()

func get_refund_count() -> int:
	return _refund_nodes.size()

func is_holding() -> bool:
	return _hold_active

func get_hold_progress() -> float:
	if not _hold_active or not _tree_data:
		return 0.0
	var d: float = maxf(0.01, _tree_data.default_hold_duration)
	return clampf(_hold_elapsed / d, 0.0, 1.0)

# ============================================================
# PRESS START / END
# ============================================================

## Called when the user presses down on a node.
## Decides whether to trigger an instant action or start a hold.
func on_node_press_start(node: BayterekNodeButton) -> void:
	if not node:
		return
	if not _tree_data or not _tree_data.allocation:
		return

	# --- Refund mode: always INSTANT ---
	if _refund_mode:
		_handle_refund_click_instant(node)
		return

	# --- Preallocation confirm: always INSTANT ---
	if _tree_data.preallocation and _tree_data.allocation_confirm:
		_handle_preallocation_instant(node)
		return

	# --- HOLD mode ---
	if _tree_data.is_hold_purchase_mode():
		if _can_allocate(node):
			_start_hold(node)
		return

	# --- INSTANT mode (classic) ---
	if _can_allocate(node):
		_allocate_node(node)

## Called when the user releases the mouse button over the tree.
func on_node_press_end(_node: BayterekNodeButton) -> void:
	if _hold_active:
		_cancel_hold()

# ============================================================
# HOLD LOGIC
# ============================================================

func _start_hold(node: BayterekNodeButton) -> void:
	if _hold_active:
		return
	_hold_node = node
	_hold_elapsed = 0.0
	_hold_active = true
	hold_started.emit(node)

func _cancel_hold() -> void:
	if not _hold_active:
		return
	var node: BayterekNodeButton = _hold_node
	_hold_node = null
	_hold_elapsed = 0.0
	_hold_active = false
	hold_cancelled.emit(node)

func _complete_hold() -> void:
	if not _hold_active:
		return
	var node: BayterekNodeButton = _hold_node
	_hold_node = null
	_hold_elapsed = 0.0
	_hold_active = false

	if node and is_instance_valid(node) and _can_allocate(node):
		_allocate_node(node)

	hold_completed.emit(node)

## Called by BayterekTreeView every frame. Returns the current progress
## if a hold is active, or 0.0 otherwise.
func tick_hold(delta: float) -> float:
	if not _hold_active or not _tree_data:
		return 0.0

	_hold_elapsed += delta
	var duration: float = maxf(0.01, _tree_data.default_hold_duration)
	var t: float = clampf(_hold_elapsed / duration, 0.0, 1.0)

	if _hold_node and is_instance_valid(_hold_node):
		hold_progress.emit(_hold_node, t)

	if t >= 1.0:
		_complete_hold()
		return 0.0

	return t

# ============================================================
# INSTANT HANDLERS
# ============================================================

func _handle_refund_click_instant(node: BayterekNodeButton) -> void:
	# Identical to the old refund flow but triggered on press.
	if _tree_data.refund_confirm:
		_handle_refund_click(node)
	else:
		_handle_immediate_refund_click(node)

func _handle_preallocation_instant(node: BayterekNodeButton) -> void:
	var pre_size: int = _preallocated_nodes.size()

	if _can_preallocate(node):
		_preallocated_nodes.append(node.id)
		node.preallocated = true
		node_refresh(node)
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
				node_refresh(n)
				node_unpreallocated.emit(n)

	if Input.is_key_pressed(KEY_CTRL) and pre_size == 0:
		confirm_preallocations()

func _handle_refund_click(node: BayterekNodeButton) -> void:
	var pre_size: int = _refund_nodes.size()

	if node.allocated and not _refund_nodes.has(node.id):
		var closure: Array[int] = _get_refund_closure(node.id)
		if _is_closure_valid_for_refund(closure):
			for node_id in closure:
				if _refund_nodes.has(node_id):
					continue
				var n: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
				if not n:
					continue
				n.refund = true
				node_refresh(n)
				_refund_nodes.append(node_id)
				node_refund_added.emit(n)
	elif _refund_nodes.has(node.id):
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
				node_refresh(n)
				_refund_nodes.erase(node_id)
				node_refund_removed.emit(n)

	if Input.is_key_pressed(KEY_CTRL) and pre_size == 0:
		confirm_refund()

func _handle_immediate_refund_click(node: BayterekNodeButton) -> void:
	if not node.allocated:
		return

	var closure: Array[int] = _get_refund_closure(node.id)
	if closure.is_empty():
		return

	if not _is_closure_valid_for_refund(closure):
		return

	for node_id in closure:
		var n: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
		if not n:
			continue
		_deallocate_node(n)

# ============================================================
# PUBLIC API — CONFIRM / CLEAR
# ============================================================

func confirm_preallocations() -> void:
	var snapshot: Array[int] = _preallocated_nodes.duplicate()
	_preallocated_nodes.clear()

	for node_id in snapshot:
		var node: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
		if node:
			_allocate_node(node)

func confirm_refund() -> void:
	var snapshot: Array[int] = _refund_nodes.duplicate()
	_refund_nodes.clear()
	_refund_mode = false

	for node_id in snapshot:
		var node: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
		if node:
			_deallocate_node(node)

	refund_mode_exited.emit()

func clear_preallocations() -> void:
	var snapshot: Array[int] = _preallocated_nodes.duplicate()
	_preallocated_nodes.clear()

	for node_id in snapshot:
		var node: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
		if node:
			node.preallocated = false
			node_refresh(node)
			node_unpreallocated.emit(node)

func enter_refund_mode() -> void:
	if _refund_mode:
		exit_refund_mode()
		return

	clear_preallocations()
	_refund_mode = true
	_refund_nodes.clear()
	refund_mode_entered.emit()

func exit_refund_mode() -> void:
	var snapshot: Array[int] = _refund_nodes.duplicate()
	_refund_nodes.clear()
	_refund_mode = false

	for node_id in snapshot:
		var node: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
		if node:
			node.refund = false
			node_refresh(node)
			node_refund_removed.emit(node)

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
		node_refresh(node)
		_refund_nodes.append(node_id)
		node_refund_added.emit(node)

# ============================================================
# CLEAR ALL
# ============================================================

func clear_all_allocations() -> void:
	var pre_snapshot: Array[int] = _preallocated_nodes.duplicate()
	_preallocated_nodes.clear()
	for node_id in pre_snapshot:
		var node: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
		if node:
			node.preallocated = false
			node_refresh(node)
			node_unpreallocated.emit(node)

	var was_refund_mode: bool = _refund_mode
	var refund_snapshot: Array[int] = _refund_nodes.duplicate()
	_refund_nodes.clear()
	_refund_mode = false
	for node_id in refund_snapshot:
		var node: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
		if node:
			node.refund = false
			node_refresh(node)
			node_refund_removed.emit(node)

	var allocated_snapshot: Array[int] = _allocated_nodes.duplicate()
	for node_id in allocated_snapshot:
		var node: BayterekNodeButton = _tree_view.nodes_service.get_node(node_id)
		if node:
			node.allocated = false
			node.allocation_level = 0
			node.refund = false
			node.preallocated = false
			node.set_state(Bayterek.AllocationState.NORMAL)
			node_deallocated.emit(node)

	_allocated_nodes.clear()
	_allocation_level.clear()

	_refresh_all_node_visuals()

	if was_refund_mode:
		refund_mode_exited.emit()

func _refresh_all_node_visuals() -> void:
	if not _tree_view or not _tree_view.nodes_service:
		return
	for node in _tree_view.nodes_service.get_all_nodes():
		if not is_instance_valid(node):
			continue
		node_refresh(node)

func node_refresh(node: BayterekNodeButton) -> void:
	if not is_instance_valid(node):
		return
	if node.has_method("refresh_state_only"):
		node.refresh_state_only()
	elif node.has_method("refresh_visuals"):
		node.refresh_visuals()

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

		BayterekNode.PrerequisiteMode.GROUP_COMPLETE:
			if node.prerequisite_group_id.is_empty():
				return true
			var group: BayterekNodeGroup = _tree_data.get_group_by_id(node.prerequisite_group_id) if _tree_data else null
			if not group:
				return true
			for member_id in group.node_ids:
				if exclude_ids.has(member_id):
					continue
				if not active_ids.has(member_id):
					return false
			return true

	return true

# ============================================================
# ALLOCATION CHECKS
# ============================================================

func _can_preallocate(node: BayterekNodeButton) -> bool:
	if preallocation_check and not preallocation_check.call():
		return false

	if not node.node_data:
		return false

	if _tree_data.multiallocation:
		if node.preallocated:
			return false
		if node.allocated:
			if _allocation_level.get(node.id, 0) >= node.node_data.max_allocations:
				return false
	else:
		if node.allocated or node.preallocated:
			return false

	var active_ids: Array = _get_active_nodes()
	return _is_prerequisite_satisfied(node.node_data, active_ids, [])

func _can_allocate(node: BayterekNodeButton) -> bool:
	if allocation_check and not allocation_check.call():
		return false

	if not node.node_data:
		return false

	if _tree_data.multiallocation:
		if node.allocated:
			if _allocation_level.get(node.id, 0) >= node.node_data.max_allocations:
				return false
		if node.preallocated:
			return false
	else:
		if node.allocated:
			return false

	return _is_prerequisite_satisfied(node.node_data, _allocated_nodes, [])

# ============================================================
# VALIDATION
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
		_allocation_level[node.id] = 1
		node.allocation_level = 1

	node.preallocated = false

	node_refresh(node)

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
		_allocation_level.erase(node.id)
		node.allocated = false
		node.allocation_level = 0

	node.refund = false

	node_refresh(node)

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
	_hold_node = null
	_hold_elapsed = 0.0
	_hold_active = false

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
		var lvl: int = _allocation_level.get(node_id, 1)
		if lvl <= 0:
			lvl = 1
			_allocation_level[node_id] = 1
		node.allocation_level = lvl
		node_refresh(node)

	for node in _tree_view.nodes_service.get_all_nodes():
		if not node.allocated and not node.preallocated:
			_tree_view.nodes_service._refresh_node_state(node)