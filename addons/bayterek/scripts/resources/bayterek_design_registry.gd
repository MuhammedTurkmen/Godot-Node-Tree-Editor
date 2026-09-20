@tool
class_name BayterekDesignRegistry
extends Resource
## Holds all node design resources.
## Saved to res://bayterek_data/designs/designs_registry.tres.

@export_storage var designs: Array[BayterekNodeDesign] = []

# ============================================================
# LOOKUP
# ============================================================

func get_design_by_id(design_id: String) -> BayterekNodeDesign:
	if design_id.is_empty():
		return null
	for d in designs:
		if d and d.id == design_id:
			return d
	return null

func get_design_by_name(design_name: String) -> BayterekNodeDesign:
	for d in designs:
		if d and d.name == design_name:
			return d
	return null

func has_design_id(design_id: String) -> bool:
	return get_design_by_id(design_id) != null

# ============================================================
# MUTATION
# ============================================================

func add_design(design: BayterekNodeDesign) -> void:
	if not design:
		return
	if designs.has(design):
		return
	designs.append(design)

func remove_design(design: BayterekNodeDesign) -> void:
	designs.erase(design)

func clear() -> void:
	designs.clear()

func get_design_count() -> int:
	return designs.size()