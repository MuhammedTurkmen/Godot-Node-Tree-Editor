@tool
class_name BayterekNodeDesign
extends Resource
## Global node design template.

signal layers_changed(design: BayterekNodeDesign, change_type: String)
signal name_changed(design: BayterekNodeDesign)
signal description_changed(design: BayterekNodeDesign)
signal exported_fields_changed(design: BayterekNodeDesign)

## Whitelist of layer fields that can be exported to prefabs.
const EXPORTABLE_LAYER_FIELDS: Array[String] = [
	"visible",
	"layer_name",
	"render_mode_override",
	"texture_filter_override",
	"transform.position",
	"transform.size",
	"transform.scale",
	"transform.rotation",
	"transform.flip_x",
	"transform.flip_y",
	"transform.skew",
	"transform.pivot",
	"transform.pivot_mode",
	"transform.scale_from_pivot",
	# Shape
	"shape_type",
	"corner_radius",
	"fill_enabled",
	"border_enabled",
	"border_width",
	"border_corner_gap",
	"border_top_enabled",
	"border_right_enabled",
	"border_bottom_enabled",
	"border_left_enabled",
	"shadow_enabled",
	"shadow_color",
	"shadow_size",
	"shadow_blur",
	# Texture
	"icon_enabled",
	"tint_enabled",
	"stretch_mode",
	"nine_patch_margin_left",
	"nine_patch_margin_top",
	"nine_patch_margin_right",
	"nine_patch_margin_bottom",
	"nine_patch_draw_center",
]

@export_storage var id: String = ""
@export_storage var name: String = "New Design"
@export_storage var description: String = ""
@export_storage var category: String = ""

## Fallback size for layers that don't specify their own size.
@export_storage var design_size: Vector2 = Vector2(100, 100)
@export_storage var scale: Vector2 = Vector2.ONE

@export_storage var layers: Array[BayterekLayer] = []

@export_storage var exported_fields: Dictionary = {}

# ============================================================
# EXPORTED FIELDS
# ============================================================

func is_field_exported(field_path: String) -> bool:
	return exported_fields.get(field_path, false)

func set_field_exported(field_path: String, exported: bool) -> void:
	if exported:
		exported_fields[field_path] = true
	else:
		exported_fields.erase(field_path)
	exported_fields_changed.emit(self)

func clear_all_exported_fields() -> void:
	exported_fields.clear()
	exported_fields_changed.emit(self)

# ============================================================
# FIELD PATH API
# ============================================================

func parse_field_path(path: String) -> Dictionary:
	if path.is_empty():
		return {}

	var parts: Array = path.split(".")
	if parts.is_empty():
		return {}

	var root: String = parts[0]

	if root == "design_size" or root == "scale":
		return {"root": root, "segments": []}

	if root == "layers":
		if parts.size() < 2:
			return {}
		var layer_id: String = parts[1]
		var segments: Array = []
		for i in range(2, parts.size()):
			segments.append(parts[i])
		return {"root": "layer", "layer_id": layer_id, "segments": segments}

	return {}

func get_field_value(field_path: String) -> Variant:
	var parsed: Dictionary = parse_field_path(field_path)
	if parsed.is_empty():
		return null

	var root: String = parsed.get("root", "")

	match root:
		"design_size":
			return design_size
		"scale":
			return scale
		"layer":
			var layer_id: String = parsed.get("layer_id", "")
			var layer: BayterekLayer = get_layer_by_id(layer_id)
			if not layer:
				return null
			var segments: Array = parsed.get("segments", [])
			return _get_property_in_object(layer, segments)

	return null

func set_field_value(field_path: String, value: Variant) -> void:
	var parsed: Dictionary = parse_field_path(field_path)
	if parsed.is_empty():
		return

	var root: String = parsed.get("root", "")

	match root:
		"design_size":
			design_size = value
		"scale":
			scale = value
		"layer":
			var layer_id: String = parsed.get("layer_id", "")
			var layer: BayterekLayer = get_layer_by_id(layer_id)
			if not layer:
				return
			var segments: Array = parsed.get("segments", [])
			_set_property_in_object(layer, segments, value)
			notify_layer_modified()

func is_field_exportable(field_path: String) -> bool:
	var parsed: Dictionary = parse_field_path(field_path)
	if parsed.is_empty():
		return false

	var root: String = parsed.get("root", "")

	if root == "design_size" or root == "scale":
		return true

	if root == "layer":
		var layer_id: String = parsed.get("layer_id", "")
		var layer: BayterekLayer = get_layer_by_id(layer_id)
		if not layer:
			return false

		var segments: Array = parsed.get("segments", [])
		if segments.is_empty():
			return false

		var sub_path: String = ".".join(segments)
		if sub_path in EXPORTABLE_LAYER_FIELDS:
			return true

		for allowed in EXPORTABLE_LAYER_FIELDS:
			if sub_path.begins_with(allowed + "."):
				return true

		return false

	return false

# ============================================================
# PROPERTY WALKING
# ============================================================

func _get_property_in_object(obj: Object, segments: Array) -> Variant:
	if not obj or segments.is_empty():
		return obj

	var current: Variant = obj
	for seg in segments:
		if current == null:
			return null
		var key: String = String(seg)
		if current is Object:
			var obj_current: Object = current
			var found: bool = false
			for prop in obj_current.get_property_list():
				if prop.get("name", "") == key:
					current = obj_current.get(key)
					found = true
					break
			if not found:
				return null
		elif current is Dictionary:
			if not current.has(key):
				return null
			current = current[key]
		else:
			return null
	return current

func _set_property_in_object(obj: Object, segments: Array, value: Variant) -> void:
	if not obj or segments.is_empty():
		return

	var current: Variant = obj
	for i in range(segments.size() - 1):
		var seg: String = String(segments[i])
		if current is Object:
			var obj_current: Object = current
			var found: bool = false
			for prop in obj_current.get_property_list():
				if prop.get("name", "") == seg:
					current = obj_current.get(seg)
					found = true
					break
			if not found:
				return
		elif current is Dictionary:
			if not current.has(seg):
				return
			current = current[seg]
		else:
			return

	var last_seg: String = String(segments[segments.size() - 1])
	if current is Object:
		var obj_current: Object = current
		obj_current.set(last_seg, value)
	elif current is Dictionary:
		current[last_seg] = value

# ============================================================
# LAYER MANAGEMENT
# ============================================================

func can_add_layer() -> bool:
	return layers.size() < BayterekNode.MAX_LAYERS

func get_layer_count() -> int:
	return layers.size()

func add_layer(layer: BayterekLayer) -> bool:
	if not layer or not can_add_layer():
		return false
	layers.append(layer)
	layers_changed.emit(self, "add")
	return true

func remove_layer(index: int) -> BayterekLayer:
	if index < 0 or index >= layers.size():
		return null
	var removed: BayterekLayer = layers[index]
	layers.remove_at(index)
	layers_changed.emit(self, "remove")
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
	layers_changed.emit(self, "reorder")
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
	layers_changed.emit(self, "reset")

func notify_layer_modified() -> void:
	layers_changed.emit(self, "modify")

func copy_layers_from(source_layers: Array) -> void:
	layers.clear()
	for layer in source_layers:
		if layer is BayterekLayer:
			layers.append(layer.duplicate_layer())
	layers_changed.emit(self, "reset")

# ============================================================
# COMPUTED SIZE
# ============================================================

func get_computed_size() -> Vector2:
	var bounds: Rect2 = get_computed_bounds()
	if bounds.size.x > 0.0 and bounds.size.y > 0.0:
		return bounds.size
	return design_size

func get_computed_bounds() -> Rect2:
	if layers.is_empty():
		return Rect2(-design_size * 0.5, design_size)

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
		return Rect2(-design_size * 0.5, design_size)

	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

# ============================================================
# IDENTITY SETTERS
# ============================================================

func set_design_name(new_name: String) -> void:
	if name == new_name:
		return
	name = new_name
	name_changed.emit(self)

func set_description(new_desc: String) -> void:
	if description == new_desc:
		return
	description = new_desc
	description_changed.emit(self)

# ============================================================
# DUPLICATE
# ============================================================

func duplicate_design() -> BayterekNodeDesign:
	var copy := BayterekNodeDesign.new()
	copy.id = ""
	copy.name = name + " Copy"
	copy.description = description
	copy.category = category
	copy.design_size = design_size
	copy.scale = scale
	copy.copy_layers_from(layers)
	copy.exported_fields = exported_fields.duplicate(true)
	return copy

func _to_string() -> String:
	return "BayterekNodeDesign(id='%s', name='%s', layers=%d)" % [id, name, layers.size()]