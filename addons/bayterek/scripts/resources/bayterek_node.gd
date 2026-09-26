@tool
class_name BayterekNode
extends Resource
## Data model for a single node.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

enum PrerequisiteMode {
	ANY,
	COUNT,
	ALL,
	GROUP_COMPLETE,
}

const MAX_LAYERS := 6

# ============================================================
# RENDER CACHE
# ============================================================

var _visual_bounds_cache: Rect2 = Rect2()
var _visual_bounds_cache_key: String = ""

var _active_states_cache: Dictionary = {}
var _active_states_cache_key: String = ""

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

func resolve_exported_value(field_path: String, prefab: BayterekPrefab, design: BayterekNodeDesign) -> Variant:
	if exported_overrides.has(field_path):
		return exported_overrides[field_path]
	if prefab and prefab.exported_values.has(field_path):
		return prefab.exported_values[field_path]
	if design:
		return design.get_field_value(field_path)
	return null

func resolve_field_value(field_path: String, prefab_ref: BayterekPrefab, design: BayterekNodeDesign) -> Variant:
	return resolve_exported_value(field_path, prefab_ref, design)

func has_field_override(field_path: String) -> bool:
	return exported_overrides.has(field_path)

# ============================================================
# DESIGN RESOLUTION
# ============================================================

## Returns the design that this node references, or null.
func _resolve_design() -> BayterekNodeDesign:
	if design_id.is_empty():
		return null
	return Bayterek.get_designs_registry().get_design_by_id(design_id)

# ============================================================
# EXPORTED OVERRIDES APPLICATION
# ============================================================

func apply_exported_overrides(design: BayterekNodeDesign, prefab_ref: BayterekPrefab) -> void:
	if not design:
		return

	copy_layers_from(design.layers)
	design_size = design.design_size
	scale = design.scale

	var all_paths: Dictionary = {}
	for p in design.exported_fields.keys():
		all_paths[p] = true
	if prefab_ref:
		for p in prefab_ref.exported_fields.keys():
			all_paths[p] = true

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

	clear_render_cache()

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
	clear_render_cache()
	return true

func remove_layer(index: int) -> BayterekLayer:
	if index < 0 or index >= layers.size():
		return null
	var removed: BayterekLayer = layers[index]
	layers.remove_at(index)
	clear_render_cache()
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
	clear_render_cache()
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
	clear_render_cache()

func copy_layers_from(source_layers: Array) -> void:
	layers.clear()
	for layer in source_layers:
		if layer is BayterekLayer:
			layers.append(layer.duplicate_layer())
	clear_render_cache()

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
# VISUAL BOUNDS
# ============================================================

func get_visual_bounds() -> Rect2:
	var cache_key: String = _make_visual_bounds_cache_key()
	if cache_key == _visual_bounds_cache_key:
		return _visual_bounds_cache

	# 1) If the design has a bounds layer, use its effective size.
	var design: BayterekNodeDesign = _resolve_design()
	if design and not design.bounds_layer_id.is_empty():
		var result: Rect2 = design.get_bounds_rect()
		_visual_bounds_cache = result
		_visual_bounds_cache_key = cache_key
		return result

	# 2) Otherwise, fall back to the union of all visible layers.
	if layers.is_empty():
		var empty_result: Rect2 = Rect2(-design_size * 0.5, design_size)
		_visual_bounds_cache = empty_result
		_visual_bounds_cache_key = cache_key
		return empty_result

	var has_any: bool = false
	var min_x: float = INF
	var min_y: float = INF
	var max_x: float = -INF
	var max_y: float = -INF

	for layer in layers:
		if not layer or not layer.visible:
			continue

		var pixel_mode: bool = layer.get_effective_render_mode() == 1

		var effective_size: Vector2 = layer.get_size(design_size)
		if effective_size.x <= 0.0 or effective_size.y <= 0.0:
			continue

		var matrix: Transform2D = layer.get_matrix(design_size, pixel_mode)
		var half: Vector2 = effective_size * 0.5

		var corners: Array[Vector2] = [
			Vector2(-half.x, -half.y),
			Vector2( half.x, -half.y),
			Vector2( half.x,  half.y),
			Vector2(-half.x,  half.y),
		]

		for c in corners:
			var w: Vector2 = matrix * c
			min_x = minf(min_x, w.x)
			min_y = minf(min_y, w.y)
			max_x = maxf(max_x, w.x)
			max_y = maxf(max_y, w.y)
			has_any = true

	if not has_any:
		var fallback: Rect2 = Rect2(-design_size * 0.5, design_size)
		_visual_bounds_cache = fallback
		_visual_bounds_cache_key = cache_key
		return fallback

	var result: Rect2 = Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
	_visual_bounds_cache = result
	_visual_bounds_cache_key = cache_key
	return result

func _make_visual_bounds_cache_key() -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append("%d_%d" % [int(round(design_size.x)), int(round(design_size.y))])
	parts.append("%d" % layers.size())

	# Include design_id so bounds_layer_id changes are caught.
	parts.append(design_id)

	# Include bounds_layer_id from design if it exists.
	var design: BayterekNodeDesign = _resolve_design()
	if design:
		parts.append(design.bounds_layer_id)

	for layer in layers:
		if not layer:
			parts.append("null")
			continue
		if not layer.visible:
			parts.append("hid")
			continue
		var t: BayterekLayerTransform = layer.transform
		if not t:
			parts.append("noT")
			continue
		parts.append("%d_%d_%d_%d_%d_%d_%d_%d_%d" % [
			int(round(t.position.x)),
			int(round(t.position.y)),
			int(round(t.size.x)),
			int(round(t.size.y)),
			int(round(t.scale.x * 100.0)),
			int(round(t.scale.y * 100.0)),
			int(round(t.rotation)),
			int(layer.get_effective_render_mode()),
			int(t.pivot_mode),
		])
	return "|".join(parts)

func get_visual_size() -> Vector2:
	return get_visual_bounds().size

# ============================================================
# CACHE MANAGEMENT
# ============================================================

## Clears visual bounds and active states caches.
func clear_render_cache() -> void:
	_visual_bounds_cache_key = ""
	_active_states_cache_key = ""
	for layer in layers:
		if layer is BayterekShapeLayer:
			layer.clear_render_cache()

# ============================================================
# ACTIVE STATE RESOLUTION
# ============================================================

func resolve_active_states(runtime_flags: Dictionary) -> Dictionary:
	var is_hovered: bool = runtime_flags.get("is_hovered", false)
	var is_clicked: bool = runtime_flags.get("is_clicked", false)
	var allocated: bool = runtime_flags.get("allocated", false)
	var preallocated: bool = runtime_flags.get("preallocated", false)
	var refund: bool = runtime_flags.get("refund", false)
	var allocation_level: int = runtime_flags.get("allocation_level", 0)
	var is_allocatable: bool = runtime_flags.get("is_allocatable", false)

	var cache_key: String = "%d_%d_%d_%d_%d_%d_%d_%d_%d_%d" % [
		int(locked),
		max_allocations,
		int(is_hovered),
		int(is_clicked),
		int(allocated),
		int(preallocated),
		int(refund),
		allocation_level,
		int(is_allocatable),
		int(layers.size()),
	]
	if cache_key == _active_states_cache_key:
		return _active_states_cache

	var result: Dictionary = {}

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

	_active_states_cache = result
	_active_states_cache_key = cache_key
	return result