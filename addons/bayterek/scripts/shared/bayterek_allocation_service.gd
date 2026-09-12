@tool
class_name BayterekAllocationService
extends BayterekBaseService
## Allocation / preallocation / refund yönetimi.

signal node_preallocated(node: BayterekNodeButton)
signal node_unpreallocated(node: BayterekNodeButton)
signal node_allocated(node: BayterekNodeButton)
signal node_deallocated(node: BayterekNodeButton)
signal refund_mode_entered
signal refund_mode_exited
signal node_refund_added(node: BayterekNodeButton)
signal node_refund_removed(node: BayterekNodeButton)

var preallocation_check: Callable
var allocation_check: Callable
var deallocation_check: Callable
var refund_check: Callable

var _preallocated_nodes: Array[int] = []
var _refund_nodes: Array[int] = []
var _refund_mode: bool = false

func load_tree(tree_data: BayterekTree) -> void:
	_tree_data = tree_data

func on_node_pressed(node: BayterekNodeButton) -> void:
	# TODO
	pass
