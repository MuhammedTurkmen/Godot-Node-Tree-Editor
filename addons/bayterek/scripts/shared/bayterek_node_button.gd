@tool
class_name BayterekNodeButton
extends BaseButton
## Tek bir node'un sahnedeki görsel temsili.

signal node_hovered(node: BayterekNodeButton, is_hovered: bool)

var tree: BayterekTree
var tree_view: BayterekTreeView
var node_data: BayterekNode
var prefab: BayterekPrefab
var allocated: bool = false
var preallocated: bool = false
var refund: bool = false
var allocation_level: int = 0
var state: Bayterek.AllocationState = Bayterek.AllocationState.NORMAL
