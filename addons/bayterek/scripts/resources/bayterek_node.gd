@tool
class_name BayterekNode
extends Resource
## Data model for a single node.

enum NodeType {
	SMALL,
	MEDIUM,
	LARGE,
	DECORATION,
}

enum PrerequisiteMode {
	ANY,
	COUNT,
	ALL,
	GROUP_COMPLETE,
}

const MAX_LAYERS := 6

# ============================================================
# IDENTITY
# ============================================================

@export_storage var is_root: bool = false
@export_storage var reference_id: String = ""
@export_storage var id: int = 0
@export_storage var external_id: String = ""
@export_storage var name: String = ""
@export_storage var description: String = ""

@export_storage var type: NodeType = NodeType.SMALL

## Design reference — which BayterekNodeDesign this node uses.
@export_storage var design_id: String = ""

# ============================================================
# LAYOUT
# ============================================================

@export_storage var position: Vector2 = Vector2.ZERO
@export_storage var design_size: Vector2 = Vector2(100, 100)
@export_storage var scale: Vector2 = Vector2.ONE

# ============================================================
# GRAPH
# ============================================================

@export_storage var line_data: Dictionary = {}
@export_storage var out_nodes: Array[int] = []
@export_storage var in_nodes: Array[int] = []
@export_storage var attributes: Dictionary = {}
@export_storage var max_allocations: int = 1
@export_storage var locked: bool = false

# ============================================================
# PREREQUISITES
# ============================================================

@export_storage var prerequisite_mode: PrerequisiteMode = PrerequisiteMode.ANY
@export_storage var prerequisite_count: int = 1
@export_storage var prerequisite_group_id: String = ""

# ============================================================
# GROUPING
# ============================================================

@export_storage var group_id: String = ""

# ============================================================
# LAYERS (max 6)
# ============================================================

@export_storage var layers: Array[BayterekLayer] = []

# ============================================================
# PREFAB OVERRIDES
# ============================================================

@export_storage var overridden_attributes: Dictionary = {}

func has_attribute_override(attr_id: String) -> bool:
	return overridden_attributes.has(attr_id)

func mark_attribute_override(attr_id: String) -> void:
	overridden_attributes[attr_id] = true

func clear_attribute_override(attr_id: String) -> void:
	overridden_attributes.erase(attr_id)

func clear_all_attribute_overrides() -> void:
	overridden_attributes.clear()

# ============================================================
# LAYER MANAGEMENT
# ============================================================

func can_add_layer() -> bool:
	return layers.size() < MAX_LAYERS

func get_layer_count() -> int:
	return layers.size()

func add_layer(layer: BayterekLayer) -> bool:
	if not layer:
		return false
	if not can_add_layer():
		return false
	layers.append(layer)
	return true

func remove_layer(index: int) -> BayterekLayer:
	if index < 0 or index >= layers.size():
		return null
	var removed: BayterekLayer = layers[index]
	layers.remove_at(index)
	return removed

func move_layer(from_index: int, to_index: int) -> bool:
	if from_index < 0 or from_index >= layers.size():
		return false
	if to_index < 0 or to_index >= layers.size():
		return false
	if from_index == to_index:
		return false
	var layer: BayterekLayer = layers[from_index]
	layers.remove_at(from_index)
	layers.insert(to_index, layer)
	return true

func get_layer(index: int) -> BayterekLayer:
	if index < 0 or index >= layers.size():
		return null
	return layers[index]

func clear_layers() -> void:
	layers.clear()

func copy_layers_from(source_layers: Array) -> void:
	layers.clear()
	for layer in source_layers:
		if layer is BayterekLayer:
			layers.append(layer.duplicate_layer())

# ============================================================
# DESIGN APPLICATION
# ============================================================

## Applies a specific design's layers + sizing to this node.
func apply_design(design: BayterekNodeDesign) -> void:
	if not design:
		return
	design_id = design.id
	design_size = design.design_size
	scale = design.scale
	copy_layers_from(design.layers)

## Applies the tree's default design (if any).
## Called by BayterekNodesService when creating new nodes.
func apply_defaults_from_tree(tree: BayterekTree) -> void:
	if not tree:
		return
	if tree.default_design_id.is_empty():
		return

	var design: BayterekNodeDesign = Bayterek.get_designs_registry().get_design_by_id(tree.default_design_id)
	if not design:
		return

	apply_design(design)

# ============================================================
# ACTIVE STATE RESOLUTION
# ============================================================

## Returns the currently active node-level states as a Dictionary
## {"state_name": bool}. Computed once per visual refresh, then passed
## to each layer.
func resolve_active_states(runtime_flags: Dictionary) -> Dictionary:
	var result: Dictionary = {}

	var is_hovered: bool = runtime_flags.get("is_hovered", false)
	var is_clicked: bool = runtime_flags.get("is_clicked", false)
	var allocated: bool = runtime_flags.get("allocated", false)
	var preallocated: bool = runtime_flags.get("preallocated", false)
	var refund: bool = runtime_flags.get("refund", false)
	var allocation_level: int = runtime_flags.get("allocation_level", 0)
	var is_allocatable: bool = runtime_flags.get("is_allocatable", false)

	result["locked"] = locked
	result["prerefund"] = refund
	result["preallocated"] = preallocated and not refund
	result["max_level"] = allocated and max_allocations > 0 and allocation_level >= max_allocations
	result["hover"] = is_hovered
	result["clicked"] = is_clicked

	if not allocated and not preallocated:
		result["allocateable"] = is_allocatable
		result["not_allocateable"] = not is_allocatable
	else:
		result["allocateable"] = false
		result["not_allocateable"] = false

	var any_special: bool = false
	for key in ["locked", "prerefund", "preallocated", "max_level", "hover", "clicked", "allocateable", "not_allocateable"]:
		if result.get(key, false):
			any_special = true
			break
	result["normal"] = not any_special

	return result