@tool
class_name BayterekPrefab
extends Resource
## Shared node template.

signal name_changed(prefab: BayterekPrefab)
signal description_changed(prefab: BayterekPrefab)
signal icon_changed(prefab: BayterekPrefab)
signal border_changed(prefab: BayterekPrefab)
signal attribute_changed(prefab: BayterekPrefab, attribute_id: String, removed: bool)
signal max_allocations_changed(prefab: BayterekPrefab)

@export_storage var reference_id: String
@export_storage var id: String
@export_storage var node_name: String
@export_storage var description: String
@export_storage var type: BayterekNode.NodeType = BayterekNode.NodeType.SMALL
@export_storage var icon: Texture2D
@export_storage var border_normal: Texture2D
@export_storage var border_intermediate: Texture2D
@export_storage var border_active: Texture2D
@export_storage var attributes: Dictionary = {}
@export_storage var max_allocations: int = 1

var nodes: Array = []

func add_node(node: BayterekNodeButton) -> void:
	if node in nodes:
		return
	nodes.append(node)

func remove_node(node: BayterekNodeButton) -> void:
	nodes.erase(node)

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

func set_icon(new_icon: Texture2D) -> void:
	icon = new_icon
	icon_changed.emit(self)

func set_border_normal(tex: Texture2D) -> void:
	border_normal = tex
	border_changed.emit(self)

func set_border_intermediate(tex: Texture2D) -> void:
	border_intermediate = tex
	border_changed.emit(self)

func set_border_active(tex: Texture2D) -> void:
	border_active = tex
	border_changed.emit(self)

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

## Helper to update a single attribute value
func set_attribute_value(attribute_id: String, index: int, value: Variant, level: int = -1) -> void:
	if not attributes.has(attribute_id):
		return

	var values = attributes[attribute_id]

	if level >= 0:
		# Multi-allocation: values is Array[Array]
		if not values is Array or values.size() <= level:
			return
		var level_values: Array = values[level]
		if index < 0 or index >= level_values.size():
			return
		level_values[index] = value
	else:
		# Single level
		if not values is Array:
			return
		if index < 0 or index >= values.size():
			return
		values[index] = value

	attribute_changed.emit(self, attribute_id, false)

## Resize attribute value counts across all levels
func set_attribute_value_count(attribute_id: String, new_count: int) -> void:
	if not attributes.has(attribute_id):
		return

	var values = attributes[attribute_id]
	if values is Array and values.size() > 0 and values[0] is Array:
		# Multi-allocation format
		for level in values.size():
			var level_values: Array = values[level]
			while level_values.size() < new_count:
				level_values.append(0)
			while level_values.size() > new_count:
				level_values.pop_back()
	else:
		# Single level
		while values.size() < new_count:
			values.append(0)
		while values.size() > new_count:
			values.pop_back()

	attribute_changed.emit(self, attribute_id, false)