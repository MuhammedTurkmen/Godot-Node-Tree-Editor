@tool
class_name BayterekNode
extends Resource
## Tek bir node'un veri modeli.

enum NodeType {
	SMALL,
	MEDIUM,
	LARGE,
	DECORATION,
}

## How this node decides whether it can be allocated, based on its
## incoming connections (in_nodes).
enum PrerequisiteMode {
	ANY,
	COUNT,
	ALL,
}

@export_storage var is_root: bool = false
@export_storage var reference_id: String = ""
@export_storage var id: int = 0
@export_storage var external_id: String = ""
@export_storage var name: String = ""
@export_storage var description: String = ""

@export_storage var type: NodeType = NodeType.SMALL

@export_storage var position: Vector2 = Vector2.ZERO
@export_storage var line_data: Dictionary = {}
@export_storage var out_nodes: Array[int] = []
@export_storage var in_nodes: Array[int] = []
@export_storage var attributes: Dictionary = {}
@export_storage var max_allocations: int = 1
@export_storage var locked: bool = false

# Prerequisite rules (only applies to non-root nodes)
@export_storage var prerequisite_mode: PrerequisiteMode = PrerequisiteMode.ANY
@export_storage var prerequisite_count: int = 1

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

# ============================================================
# LEGACY ALIAS — `icon` = `icon_texture_normal`
# ============================================================
## Eski kod `node_data.icon` çağırıyordu. Yeni görsel sistemde base icon
## `icon_texture_normal` oldu. Alias ile geriye dönük uyumluluk sağlıyoruz.

var icon: Texture2D:
	get:
		return icon_texture_normal
	set(value):
		icon_texture_normal = value

# ============================================================
# PREFAB OVERRIDES
# ============================================================

@export_storage var overridden_attributes: Dictionary = {}

func has_attribute_override(attr_id: String) -> bool:
	return overridden_attributes.has(attr_id)

func mark_attribute_override(attr_id: String) -> void:
	overridden_attributes[attr_id] = true

func clear_attribute_override(attr_id: String) -> void:
	overridden_attributes.erase(attr_id)

func clear_all_attribute_overrides() -> void:
	overridden_attributes.clear()

# ============================================================
# DEFAULTS
# ============================================================

## Copies the given tree's default visual settings into this node.
## Called when a node is created, so it inherits the project's look
## automatically. Users can then override any value per node.
func apply_defaults_from_tree(tree: BayterekTree) -> void:
	if not tree:
		return

	# Border textures
	border_texture_locked = tree.default_border_texture_locked
	border_texture_normal = tree.default_border_texture_normal
	border_texture_hover = tree.default_border_texture_hover
	border_texture_max_level = tree.default_border_texture_max_level

	# Border colors
	border_color_locked = tree.default_border_color_locked
	border_color_normal = tree.default_border_color_normal
	border_color_hover = tree.default_border_color_hover
	border_color_allocate = tree.default_border_color_allocate
	border_color_refund = tree.default_border_color_refund
	border_color_max_level = tree.default_border_color_max_level
	border_color_allocatable = tree.default_border_color_allocatable
	border_color_not_allocatable = tree.default_border_color_not_allocatable

	# Icon textures
	icon_texture_locked = tree.default_icon_texture_locked
	icon_texture_normal = tree.default_icon_texture_normal
	icon_texture_hover = tree.default_icon_texture_hover
	icon_texture_max_level = tree.default_icon_texture_max_level

	# Icon colors
	icon_color_locked = tree.default_icon_color_locked
	icon_color_normal = tree.default_icon_color_normal
	icon_color_hover = tree.default_icon_color_hover
	icon_color_allocate = tree.default_icon_color_allocate
	icon_color_refund = tree.default_icon_color_refund
	icon_color_max_level = tree.default_icon_color_max_level
	icon_color_allocatable = tree.default_icon_color_allocatable
	icon_color_not_allocatable = tree.default_icon_color_not_allocatable