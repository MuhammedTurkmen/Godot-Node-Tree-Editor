@tool
class_name BayterekNodeDesign
extends Resource
## Global node design template.
## Lives in res://bayterek_data/designs/ as its own .tres file.
## Holds the visual layer stack and design-time sizing.

signal layers_changed(design: BayterekNodeDesign, change_type: String)
signal name_changed(design: BayterekNodeDesign)
signal description_changed(design: BayterekNodeDesign)

@export_storage var id: String = ""
@export_storage var name: String = "New Design"
@export_storage var description: String = ""
@export_storage var category: String = ""

@export_storage var design_size: Vector2 = Vector2(100, 100)
@export_storage var scale: Vector2 = Vector2.ONE

@export_storage var layers: Array[BayterekLayer] = []

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

func clear_layers() -> void:
	layers.clear()
	layers_changed.emit(self, "reset")

## Notifies listeners that a layer inside the stack was modified.
func notify_layer_modified() -> void:
	layers_changed.emit(self, "modify")

## Deep-copies all layers from another source.
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

## Returns a deep copy of this design (new instance, new identity).
func duplicate_design() -> BayterekNodeDesign:
	var copy := BayterekNodeDesign.new()
	copy.id = ""  # caller assigns
	copy.name = name + " Copy"
	copy.description = description
	copy.category = category
	copy.design_size = design_size
	copy.scale = scale
	copy.copy_layers_from(layers)
	return copy

func _to_string() -> String:
	return "BayterekNodeDesign(id='%s', name='%s', layers=%d)" % [id, name, layers.size()]