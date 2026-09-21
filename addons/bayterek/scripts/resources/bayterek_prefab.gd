@tool
class_name BayterekPrefab
extends Resource
## Shared node template. Design'ı referans alır + sadece override edilebilir
## field'ları tutar.

signal name_changed(prefab: BayterekPrefab)
signal description_changed(prefab: BayterekPrefab)
signal attribute_changed(prefab: BayterekPrefab, attribute_id: String, removed: bool)
signal max_allocations_changed(prefab: BayterekPrefab)
signal exported_values_changed(prefab: BayterekPrefab)

@export_storage var reference_id: String
@export_storage var id: String
@export_storage var node_name: String
@export_storage var description: String
@export_storage var design_id: String = ""
@export_storage var attributes: Dictionary = {}
@export_storage var max_allocations: int = 1

@export_storage var exported_fields: Dictionary = {}
@export_storage var exported_values: Dictionary = {}

var nodes: Array = []

# ============================================================
# EXPORTED FIELD HELPERS
# ============================================================

func is_field_exported(field_path: String) -> bool:
	return exported_fields.get(field_path, false)

func get_exported_value(field_path: String) -> Variant:
	return exported_values.get(field_path, null)

func set_exported_value(field_path: String, value: Variant) -> void:
	if not is_field_exported(field_path):
		return
	exported_values[field_path] = value
	exported_values_changed.emit(self)

## Returns the effective value for `field_path`:
## - If an override exists in this prefab, returns that.
## - Otherwise reads from `design`.
func get_resolved_value(design: BayterekNodeDesign, field_path: String) -> Variant:
	if exported_values.has(field_path):
		return exported_values[field_path]
	if design:
		return design.get_field_value(field_path)
	return null

func copy_exported_fields_from(design: BayterekNodeDesign) -> void:
	if not design:
		return
	exported_fields = design.exported_fields.duplicate(true)

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
# SETTERS
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
			node.node_data.clear_all_exported_overrides()
	nodes.clear()

func for_each_node(callback: Callable) -> void:
	for node in get_nodes():
		if is_instance_valid(node):
			callback.call(node)