@tool
class_name BayterekNodeDesign
extends Resource
## Global node design template.

signal layers_changed(design: BayterekNodeDesign, change_type: String)
signal name_changed(design: BayterekNodeDesign)
signal description_changed(design: BayterekNodeDesign)
signal exported_fields_changed(design: BayterekNodeDesign)
signal render_mode_changed(design: BayterekNodeDesign)

## Design-level render mode. Layers can override via `render_mode_override`.
enum RenderMode {
	VECTOR,
	PIXEL,
}

## Design-level texture filter. Layers can override via `texture_filter_override`.
## 0 = Linear (smooth), 1 = Nearest (pixel art).
enum TextureFilter {
	LINEAR,
	NEAREST,
}

@export_storage var id: String = ""
@export_storage var name: String = "New Design"
@export_storage var description: String = ""
@export_storage var category: String = ""

## Default render mode for this design's layers. Layers may override it.
@export_storage var render_mode: RenderMode = RenderMode.VECTOR

## Default texture filter for this design's layers. Layers may override it.
@export_storage var texture_filter: TextureFilter = TextureFilter.LINEAR

@export_storage var design_size: Vector2 = Vector2(100, 100)
@export_storage var scale: Vector2 = Vector2.ONE

@export_storage var layers: Array[BayterekLayer] = []

@export_storage var exported_fields: Dictionary = {}

# ============================================================
# RENDER MODE
# ============================================================

func set_render_mode(mode: RenderMode) -> void:
	if render_mode == mode:
		return
	render_mode = mode
	render_mode_changed.emit(self)
	layers_changed.emit(self, "render_mode")

# ============================================================
# TEXTURE FILTER
# ============================================================

func set_texture_filter(new_filter: TextureFilter) -> void:
	if texture_filter == new_filter:
		return
	texture_filter = new_filter
	layers_changed.emit(self, "texture_filter")

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

## Parses a field path into structured components.
## Returns a Dictionary with keys:
##   - "root": "design_size" | "scale" | "render_mode" | "texture_filter" | "layer"
##   - "layer_id": String (only if root == "layer")
##   - "segments": Array[String] — remaining segments after layer_id
func parse_field_path(path: String) -> Dictionary:
	if path.is_empty():
		return {}

	var parts: Array = path.split(".")
	if parts.is_empty():
		return {}

	var root: String = parts[0]

	if root == "design_size" or root == "scale" or root == "render_mode" or root == "texture_filter":
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

## Returns the value at `field_path` in this design.
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
		"render_mode":
			return int(render_mode)
		"texture_filter":
			return int(texture_filter)
		"layer":
			var layer_id: String = parsed.get("layer_id", "")
			var layer: BayterekLayer = get_layer_by_id(layer_id)
			if not layer:
				return null
			var segments: Array = parsed.get("segments", [])
			return _get_property_in_object(layer, segments)

	return null

## Sets the value at `field_path`. Emits `layers_changed` for layer fields.
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
		"render_mode":
			set_render_mode(value as RenderMode)
		"texture_filter":
			set_texture_filter(value as TextureFilter)
		"layer":
			var layer_id: String = parsed.get("layer_id", "")
			var layer: BayterekLayer = get_layer_by_id(layer_id)
			if not layer:
				return
			var segments: Array = parsed.get("segments", [])
			_set_property_in_object(layer, segments, value)
			notify_layer_modified()

## Validates whether a given path is a real field on this design.
func is_field_exportable(field_path: String) -> bool:
	var parsed: Dictionary = parse_field_path(field_path)
	if parsed.is_empty():
		return false

	var root: String = parsed.get("root", "")

	if root == "design_size" or root == "scale" or root == "render_mode" or root == "texture_filter":
		return true

	if root == "layer":
		var layer_id: String = parsed.get("layer_id", "")
		var layer: BayterekLayer = get_layer_by_id(layer_id)
		if not layer:
			return false
		var segments: Array = parsed.get("segments", [])
		return _is_property_reachable(layer, segments)

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

func _is_property_reachable(obj: Object, segments: Array) -> bool:
	if not obj:
		return false
	if segments.is_empty():
		return true

	var current: Variant = obj
	for seg in segments:
		if current == null:
			return false
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
				return false
		elif current is Dictionary:
			if not current.has(key):
				return false
			current = current[key]
		else:
			return false
	return true

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
	copy.render_mode = render_mode
	copy.texture_filter = texture_filter
	copy.design_size = design_size
	copy.scale = scale
	copy.copy_layers_from(layers)
	copy.exported_fields = exported_fields.duplicate(true)
	return copy

func _to_string() -> String:
	return "BayterekNodeDesign(id='%s', name='%s', mode=%s, filter=%s, layers=%d)" % [
		id, name, RenderMode.keys()[render_mode], TextureFilter.keys()[texture_filter], layers.size()
	]