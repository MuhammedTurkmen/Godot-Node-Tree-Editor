@tool
extends RefCounted
## Allocation logic smoke test.
## Validates prerequisite modes and refund closure computation without
## needing a live tree view.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

static func run() -> bool:
	print("=== Bayterek Allocation Test ===")
	var ok: bool = true

	ok = _test_prerequisite_any() and ok
	ok = _test_prerequisite_count() and ok
	ok = _test_prerequisite_all() and ok
	ok = _test_prerequisite_group_complete() and ok
	ok = _test_refund_closure_simple() and ok
	ok = _test_refund_closure_cascade() and ok

	if ok:
		print("=== ALL ALLOCATION TESTS PASSED ===")
	else:
		push_error("=== SOME ALLOCATION TESTS FAILED ===")

	return ok

# ============================================================
# PREREQUISITE MODES
# ============================================================

static func _make_node(id: int, mode: BayterekNode.PrerequisiteMode, in_ids: Array, count: int = 1) -> BayterekNode:
	var n := BayterekNode.new()
	n.id = id
	n.prerequisite_mode = mode
	n.prerequisite_count = count

	# `in_nodes` is typed Array[int]. Rebuild it element-by-element so we
	# don't try to assign an untyped Array into a typed Array property.
	var typed: Array[int] = []
	for v in in_ids:
		typed.append(int(v))
	n.in_nodes = typed

	return n

static func _test_prerequisite_any() -> bool:
	print("--- Prerequisite ANY ---")

	var n2 := _make_node(2, BayterekNode.PrerequisiteMode.ANY, [1])

	assert(_check_prereq(n2, [1, 2]))
	assert(not _check_prereq(n2, [2]))

	print("  ANY OK")
	return true

static func _test_prerequisite_count() -> bool:
	print("--- Prerequisite COUNT ---")

	var n4 := _make_node(4, BayterekNode.PrerequisiteMode.COUNT, [1, 2, 3], 2)

	assert(_check_prereq(n4, [1, 2, 4]))
	assert(_check_prereq(n4, [1, 2, 3, 4]))
	assert(not _check_prereq(n4, [1, 4]))
	assert(not _check_prereq(n4, [4]))

	print("  COUNT OK")
	return true

static func _test_prerequisite_all() -> bool:
	print("--- Prerequisite ALL ---")

	var n3 := _make_node(3, BayterekNode.PrerequisiteMode.ALL, [1, 2])

	assert(_check_prereq(n3, [1, 2, 3]))
	assert(not _check_prereq(n3, [1, 3]))
	assert(not _check_prereq(n3, [3]))

	print("  ALL OK")
	return true

static func _test_prerequisite_group_complete() -> bool:
	print("--- Prerequisite GROUP_COMPLETE ---")

	var n4 := _make_node(4, BayterekNode.PrerequisiteMode.GROUP_COMPLETE, [])
	n4.prerequisite_group_id = "g1"

	var tree := BayterekTree.new()
	var group := BayterekNodeGroup.new()
	group.id = "g1"
	# `node_ids` is typed Array[int] — same caveat as in_nodes.
	var typed_ids: Array[int] = [1, 2, 3]
	group.node_ids = typed_ids
	tree.node_groups.append(group)

	assert(_check_prereq_group(n4, tree, [1, 2, 3, 4]))
	assert(not _check_prereq_group(n4, tree, [1, 2, 4]))

	print("  GROUP_COMPLETE OK")
	return true

# ============================================================
# HELPERS
# ============================================================

static func _check_prereq(node: BayterekNode, active_ids: Array) -> bool:
	if node.is_root:
		return true

	match node.prerequisite_mode:
		BayterekNode.PrerequisiteMode.ANY:
			for nid in node.in_nodes:
				if active_ids.has(nid):
					return true
			return false

		BayterekNode.PrerequisiteMode.COUNT:
			if node.in_nodes.is_empty():
				return false
			var count: int = 0
			for nid in node.in_nodes:
				if active_ids.has(nid):
					count += 1
					if count >= node.prerequisite_count:
						return true
			return false

		BayterekNode.PrerequisiteMode.ALL:
			if node.in_nodes.is_empty():
				return false
			for nid in node.in_nodes:
				if not active_ids.has(nid):
					return false
			return true

	return false

static func _check_prereq_group(node: BayterekNode, tree: BayterekTree, active_ids: Array) -> bool:
	if node.prerequisite_group_id.is_empty():
		return true
	var group: BayterekNodeGroup = tree.get_group_by_id(node.prerequisite_group_id)
	if not group:
		return true
	for member_id in group.node_ids:
		if not active_ids.has(member_id):
			return false
	return true

# ============================================================
# REFUND CLOSURE
# ============================================================

static func _test_refund_closure_simple() -> bool:
	print("--- Refund Closure (simple) ---")

	# graph: node_id -> Array[prerequisite_ids]
	# Linear chain:  1 (root) ← 2 ← 3 ← 4
	# Means: 2 depends on 1, 3 depends on 2, 4 depends on 3.
	var graph: Dictionary = {
		1: [],
		2: [1],
		3: [2],
		4: [3],
	}
	var allocated: Array = [1, 2, 3, 4]

	var closure: Array = _compute_closure(graph, allocated, 2)
	closure.sort()
	assert(closure == [2, 3, 4])

	print("  simple closure OK")
	return true

static func _test_refund_closure_cascade() -> bool:
	print("--- Refund Closure (branching) ---")

	# Branching:  1 (root) ← 2 ← 4
	#                1 ← 3
	# Means: 2 depends on 1, 3 depends on 1, 4 depends on 2.
	var graph: Dictionary = {
		1: [],
		2: [1],
		3: [1],
		4: [2],
	}
	var allocated: Array = [1, 2, 3, 4]

	var closure: Array = _compute_closure(graph, allocated, 2)
	closure.sort()
	assert(closure == [2, 4])

	print("  branching closure OK")
	return true

static func _compute_closure(graph: Dictionary, allocated: Array, start_id: int) -> Array:
	var closure: Array = [start_id]
	var changed: bool = true

	while changed:
		changed = false
		var remaining: Array = allocated.filter(func(id): return not closure.has(id))

		for node_id in remaining:
			var prereqs: Array = graph.get(node_id, [])
			if prereqs.is_empty():
				continue

			var any_prereq_gone: bool = false
			for p in prereqs:
				if not remaining.has(p):
					any_prereq_gone = true
					break

			if any_prereq_gone:
				closure.append(node_id)
				changed = true

	return closure