@tool
class_name BayterekPrefab
extends Resource
## Shared node template. Mirrors BayterekNode's layer system.

# ============================================================
# SIGNALS
# ============================================================

signal name_changed(prefab: BayterekPrefab)
signal description_changed(prefab: BayterekPrefab)
signal attribute_changed(prefab: BayterekPrefab, attribute_id: String, removed: bool)
signal max_allocations_changed(prefab: BayterekPrefab)

## Emitted whenever the layer stack changes (add / remove / modify / reorder / reset).
## `change_type` is one of: "add", "remove", "modify", "reorder", "reset".
signal layers_changed(prefab: BayterekPrefab, change_type: String)

# ============================================================
# IDENTITY
# ============================================================

@export_storage var reference_id: String
@export_storage var id: String
@export_storage var node_name: String
@export_storage var description: String
@export_storage var type: BayterekNode.NodeType = BayterekNode.NodeType.SMALL
@export_storage var attributes: Dictionary = {}
@export_storage var max_allocations: int = 1

# ============================================================
# LAYOUT
# ============================================================

@export_storage var design_size: Vector2 = Vector2(100, 100)
@export_storage var scale: Vector2 = Vector2.ONE

# ============================================================
# LAYERS
# ============================================================

@export_storage var layers: Array[BayterekLayer] = []

## Runtime-only: nodes bound to this prefab. Not saved.
var nodes: Array = []

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

## Called after a layer's internal fields have been modified externally.
## Emits the signal so bound nodes refresh.
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
# NODE BINDING
# ============================================================

func add_node(node: BayterekNodeButton) -> void:
	if not is_instance_valid(node):
		return
	if node in nodes:
		return
	nodes.append(node)

func remove_node(node: BayterekNodeButton) -> void:
	nodes.erase(node)

func get_nodes() -> Array:
	var valid: Array = []
	for n in nodes:
		if is_instance_valid(n):
			valid.append(n)
	nodes = valid
	return nodes

# ============================================================
# SETTERS (emit signals)
# ============================================================

func set_node_name(new_name: String) -> void:
	if node_name == new_name:
		return
	node_name = new_name
	id = new_name.to_snake_case()
	name_changed.emit(self)

func set_description(new_desc: String) -> void:
	if description == new_desc:
		return
	description = new_desc
	description_changed.emit(self)

func set_max_allocations(value: int) -> void:
	if max_allocations == value:
		return
	max_allocations = value
	max_allocations_changed.emit(self)

func set_attribute(attribute_id: String, values: Variant) -> void:
	attributes[attribute_id] = values
	attribute_changed.emit(self, attribute_id, false)

func remove_attribute(attribute_id: String) -> void:
	if not attributes.has(attribute_id):
		return
	attributes.erase(attribute_id)
	attribute_changed.emit(self, attribute_id, true)

func set_attribute_value(attribute_id: String, index: int, value: Variant, level: int = -1) -> void:
	if not attributes.has(attribute_id):
		return

	var values = attributes[attribute_id]

	if level >= 0:
		if not values is Array or values.size() <= level:
			return
		var level_values: Array = values[level]
		if index < 0 or index >= level_values.size():
			return
		level_values[index] = value
	else:
		if not values is Array:
			return
		if index < 0 or index >= values.size():
			return
		values[index] = value

	attribute_changed.emit(self, attribute_id, false)

func set_attribute_value_count(attribute_id: String, new_count: int) -> void:
	if not attributes.has(attribute_id):
		return

	var values = attributes[attribute_id]
	if values is Array and values.size() > 0 and values[0] is Array:
		for level in values.size():
			var level_values: Array = values[level]
			while level_values.size() < new_count:
				level_values.append(0)
			while level_values.size() > new_count:
				level_values.pop_back()
	else:
		while values.size() < new_count:
			values.append(0)
		while values.size() > new_count:
			values.pop_back()

	attribute_changed.emit(self, attribute_id, false)

# ============================================================
# ORPHAN / DELETE
# ============================================================

func orphan_all_nodes() -> void:
	for node in get_nodes():
		if not is_instance_valid(node):
			continue
		if node.prefab == self:
			node.prefab = null
		if node.node_data:
			node.node_data.reference_id = ""
			node.node_data.clear_all_attribute_overrides()
	nodes.clear()

func for_each_node(callback: Callable) -> void:
	for node in get_nodes():
		if is_instance_valid(node):
			callback.call(node)