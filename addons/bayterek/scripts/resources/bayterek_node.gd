@tool
class_name BayterekNode
extends Resource
## Data model for a single node.

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
@export_storage var is_decoration: bool = false
@export_storage var reference_id: String = ""
@export_storage var id: int = 0
@export_storage var external_id: String = ""
@export_storage var name: String = ""
@export_storage var description: String = ""

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
# LAYERS
# ============================================================

@export_storage var layers: Array[BayterekLayer] = []

# ============================================================
# PREFAB OVERRIDES
# ============================================================

@export_storage var overridden_attributes: Dictionary = {}
@export_storage var exported_overrides: Dictionary = {}

func has_attribute_override(attr_id: String) -> bool:
	return overridden_attributes.has(attr_id)

func mark_attribute_override(attr_id: String) -> void:
	overridden_attributes[attr_id] = true

func clear_attribute_override(attr_id: String) -> void:
	overridden_attributes.erase(attr_id)

func clear_all_attribute_overrides() -> void:
	overridden_attributes.clear()

# ============================================================
# EXPORTED OVERRIDES
# ============================================================

func has_exported_override(field_path: String) -> bool:
	return exported_overrides.has(field_path)

func set_exported_override(field_path: String, value: Variant) -> void:
	exported_overrides[field_path] = value

func clear_exported_override(field_path: String) -> void:
	exported_overrides.erase(field_path)

func clear_all_exported_overrides() -> void:
	exported_overrides.clear()

## Returns the effective exported value for a field.
## Priority: node override > prefab exported_values > design's own value.
func resolve_exported_value(field_path: String, prefab: BayterekPrefab, design: BayterekNodeDesign) -> Variant:
	if exported_overrides.has(field_path):
		return exported_overrides[field_path]
	if prefab and prefab.exported_values.has(field_path):
		return prefab.exported_values[field_path]
	if design:
		return design.get_field_value(field_path)
	return null

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

func get_layer_by_id(layer_id: String) -> BayterekLayer:
	if layer_id.is_empty():
		return null
	for layer in layers:
		if layer and layer.layer_id == layer_id:
			return layer
	return null

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

func apply_design(design: BayterekNodeDesign) -> void:
	if not design:
		return
	design_id = design.id
	design_size = design.design_size
	scale = design.scale
	copy_layers_from(design.layers)

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