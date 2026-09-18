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
##
##   ANY   — at least 1 incoming OR outgoing neighbor is active
##           (this is the default, legacy behavior)
##   COUNT — at least `prerequisite_count` incoming neighbors are active
##   ALL   — every incoming neighbor is active
##
## Root nodes ignore this entirely and can always be allocated.
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
@export_storage var icon: Texture2D
@export_storage var border_normal: Texture2D
@export_storage var border_intermediate: Texture2D
@export_storage var border_active: Texture2D

@export_storage var position: Vector2 = Vector2.ZERO
@export_storage var line_data: Dictionary = {}
@export_storage var out_nodes: Array[int] = []
@export_storage var in_nodes: Array[int] = []
@export_storage var attributes: Dictionary = {}
@export_storage var max_allocations: int = 1
@export_storage var locked: bool = false

## Prerequisite rules (only applies to non-root nodes)
@export_storage var prerequisite_mode: PrerequisiteMode = PrerequisiteMode.ANY
@export_storage var prerequisite_count: int = 1

## Faz 8e — Prefab'dan override edilmiş attribute'ların listesi.
@export_storage var overridden_attributes: Dictionary = {}

func has_attribute_override(attr_id: String) -> bool:
	return overridden_attributes.has(attr_id)

func mark_attribute_override(attr_id: String) -> void:
	overridden_attributes[attr_id] = true

func clear_attribute_override(attr_id: String) -> void:
	overridden_attributes.erase(attr_id)

func clear_all_attribute_overrides() -> void:
	overridden_attributes.clear()