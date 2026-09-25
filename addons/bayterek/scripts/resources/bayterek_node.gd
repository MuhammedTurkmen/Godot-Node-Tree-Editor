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

## Cached from the design at apply time. Lets the node keep its render mode
## even if the design resource is later deleted or changed.
@export_storage var render_mode: BayterekNodeDesign.RenderMode = BayterekNodeDesign.RenderMode.VECTOR

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

## Same as `resolve_exported_value` — alias for readability at call sites
## that don't have the prefab/design refs handy.
func resolve_field_value(field_path: String, prefab_ref: BayterekPrefab, design: BayterekNodeDesign) -> Variant:
	return resolve_exported_value(field_path, prefab_ref, design)

## True if this field has a node-level override.
func has_field_override(field_path: String) -> bool:
	return exported_overrides.has(field_path)

# ============================================================
# EXPORTED OVERRIDES APPLICATION
# ============================================================

## Applies all exported overrides to this node's layers.
## Priority: node.exported_overrides > prefab.exported_values > design.
func apply_exported_overrides(design: BayterekNodeDesign, prefab_ref: BayterekPrefab) -> void:
	if not design:
		return

	# Önce design'dan taze layer'ları kopyala
	copy_layers_from(design.layers)
	design_size = design.design_size
	scale = design.scale
	render_mode = design.render_mode

	# Toplanacak field path'ler: design.exported_fields + prefab.exported_fields
	var all_paths: Dictionary = {}
	for p in design.exported_fields.keys():
		all_paths[p] = true
	if prefab_ref:
		for p in prefab_ref.exported_fields.keys():
			all_paths[p] = true

	# Her path için değeri resolve et ve layer'a yaz
	for field_path in all_paths.keys():
		if field_path == "design_size":
			var v: Variant = resolve_exported_value(field_path, prefab_ref, design)
			if v is Vector2:
				design_size = v
			continue
		if field_path == "scale":
			var v2: Variant = resolve_exported_value(field_path, prefab_ref, design)
			if v2 is Vector2:
				scale = v2
			continue
		if field_path == "render_mode":
			var v3: Variant = resolve_exported_value(field_path, prefab_ref, design)
			if typeof(v3) == TYPE_INT or typeof(v3) == TYPE_FLOAT:
				render_mode = int(v3) as BayterekNodeDesign.RenderMode
			continue

		var resolved: Variant = resolve_exported_value(field_path, prefab_ref, design)
		_apply_override_to_layer(field_path, resolved)

func _apply_override_to_layer(field_path: String, value: Variant) -> void:
	var parsed: Dictionary = parse_field_path_for_layer(field_path)
	if parsed.is_empty():
		return

	var layer_id: String = parsed.get("layer_id", "")
	var segments: Array = parsed.get("segments", [])
	if layer_id.is_empty() or segments.is_empty():
		return

	var layer: BayterekLayer = get_layer_by_id(layer_id)
	if not layer:
		return

	var current: Variant = layer
	for i in range(segments.size() - 1):
		var seg: String = String(segments[i])
		if current is Object:
			current = (current as Object).get(seg)
		elif current is Dictionary:
			if not current.has(seg):
				return
			current = current[seg]
		else:
			return

	var last_seg: String = String(segments[segments.size() - 1])
	if current is Object:
		(current as Object).set(last_seg, value)
	elif current is Dictionary:
		current[last_seg] = value

func parse_field_path_for_layer(path: String) -> Dictionary:
	var parts: Array = path.split(".")
	if parts.size() < 3:
		return {}
	if parts[0] != "layers":
		return {}

	var layer_id: String = parts[1]
	var segments: Array = []
	for i in range(2, parts.size()):
		segments.append(parts[i])

	return {"layer_id": layer_id, "segments": segments}

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
	render_mode = design.render_mode
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