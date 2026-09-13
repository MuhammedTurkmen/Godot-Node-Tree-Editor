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

## Faz 8e — Prefab'dan override edilmiş attribute'ların listesi.
## Boşsa → tüm değerler prefab default'u (veya bağımsız node için hepsi override).
## Doluysa → sadece listedeki attribute'lar override.
@export_storage var overridden_attributes: Dictionary = {}

func has_attribute_override(attr_id: String) -> bool:
	return overridden_attributes.has(attr_id)

func mark_attribute_override(attr_id: String) -> void:
	overridden_attributes[attr_id] = true

func clear_attribute_override(attr_id: String) -> void:
	overridden_attributes.erase(attr_id)

func clear_all_attribute_overrides() -> void:
	overridden_attributes.clear()