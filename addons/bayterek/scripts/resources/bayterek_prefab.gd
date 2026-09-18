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
@export_storage var attributes: Dictionary = {}
@export_storage var max_allocations: int = 1

# ============================================================
# VISUALS — Border
# ============================================================

@export_storage var border_texture_locked: Texture2D = null
@export_storage var border_texture_normal: Texture2D = null
@export_storage var border_texture_hover: Texture2D = null
@export_storage var border_texture_max_level: Texture2D = null

@export_storage var border_color_locked: Color = Color(0.5, 0.5, 0.5, 1.0)
@export_storage var border_color_normal: Color = Color(1, 1, 1, 1)
@export_storage var border_color_hover: Color = Color(1.2, 1.2, 1.2, 1)
@export_storage var border_color_allocate: Color = Color(1.0, 0.9, 0.3, 1)
@export_storage var border_color_refund: Color = Color(1.0, 0.4, 0.4, 1)
@export_storage var border_color_max_level: Color = Color(1.0, 0.85, 0.2, 1)
@export_storage var border_color_allocatable: Color = Color(0.6, 1.0, 0.6, 1)
@export_storage var border_color_not_allocatable: Color = Color(0.6, 0.6, 0.6, 1)

# ============================================================
# VISUALS — Icon
# ============================================================

@export_storage var icon_texture_locked: Texture2D = null
@export_storage var icon_texture_normal: Texture2D = null
@export_storage var icon_texture_hover: Texture2D = null
@export_storage var icon_texture_max_level: Texture2D = null

@export_storage var icon_color_locked: Color = Color(0.5, 0.5, 0.5, 1.0)
@export_storage var icon_color_normal: Color = Color(1, 1, 1, 1)
@export_storage var icon_color_hover: Color = Color(1.2, 1.2, 1.2, 1)
@export_storage var icon_color_allocate: Color = Color(1.0, 0.9, 0.3, 1)
@export_storage var icon_color_refund: Color = Color(1.0, 0.4, 0.4, 1)
@export_storage var icon_color_max_level: Color = Color(1.0, 0.85, 0.2, 1)
@export_storage var icon_color_allocatable: Color = Color(0.6, 1.0, 0.6, 1)
@export_storage var icon_color_not_allocatable: Color = Color(0.6, 0.6, 0.6, 1)

## Prefab'a bağlı runtime node'lar (kaydedilmez, runtime'da doldurulur)
var nodes: Array = []

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
# VISUAL SETTERS — emit border_changed/icon_changed
# ============================================================

func set_border_visuals_from_dict(data: Dictionary) -> void:
	border_texture_locked = data.get("border_texture_locked", border_texture_locked)
	border_texture_normal = data.get("border_texture_normal", border_texture_normal)
	border_texture_hover = data.get("border_texture_hover", border_texture_hover)
	border_texture_max_level = data.get("border_texture_max_level", border_texture_max_level)

	border_color_locked = data.get("border_color_locked", border_color_locked)
	border_color_normal = data.get("border_color_normal", border_color_normal)
	border_color_hover = data.get("border_color_hover", border_color_hover)
	border_color_allocate = data.get("border_color_allocate", border_color_allocate)
	border_color_refund = data.get("border_color_refund", border_color_refund)
	border_color_max_level = data.get("border_color_max_level", border_color_max_level)
	border_color_allocatable = data.get("border_color_allocatable", border_color_allocatable)
	border_color_not_allocatable = data.get("border_color_not_allocatable", border_color_not_allocatable)

	border_changed.emit(self)

func set_icon_visuals_from_dict(data: Dictionary) -> void:
	icon_texture_locked = data.get("icon_texture_locked", icon_texture_locked)
	icon_texture_normal = data.get("icon_texture_normal", icon_texture_normal)
	icon_texture_hover = data.get("icon_texture_hover", icon_texture_hover)
	icon_texture_max_level = data.get("icon_texture_max_level", icon_texture_max_level)

	icon_color_locked = data.get("icon_color_locked", icon_color_locked)
	icon_color_normal = data.get("icon_color_normal", icon_color_normal)
	icon_color_hover = data.get("icon_color_hover", icon_color_hover)
	icon_color_allocate = data.get("icon_color_allocate", icon_color_allocate)
	icon_color_refund = data.get("icon_color_refund", icon_color_refund)
	icon_color_max_level = data.get("icon_color_max_level", icon_color_max_level)
	icon_color_allocatable = data.get("icon_color_allocatable", icon_color_allocatable)
	icon_color_not_allocatable = data.get("icon_color_not_allocatable", icon_color_not_allocatable)

	icon_changed.emit(self)

# ============================================================
# ORPHAN / SILME
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