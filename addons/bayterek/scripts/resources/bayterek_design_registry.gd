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
		print("[add_design] SKIP — instance already in registry. instance=", design.get_instance_id(), " id=", design.id)
		return
	designs.append(design)

	# --- DEBUG ---
	print("[add_design] ADDED instance=", design.get_instance_id(), " id=", design.id, " name=", design.name, " layers=", design.layers.size(), " total_designs=", designs.size())

func remove_design(design: BayterekNodeDesign) -> void:
	designs.erase(design)

func clear() -> void:
	designs.clear()

func get_design_count() -> int:
	return designs.size()

# ============================================================
# DEBUG — dump all
# ============================================================

func dump_registry() -> void:
	print("=== DESIGN REGISTRY DUMP ===")
	print("Total designs: ", designs.size())
	for i in designs.size():
		var d = designs[i]
		if not d:
			print("  [", i, "] NULL")
			continue
		print("  [", i, "] instance=", d.get_instance_id(), " id=", d.id, " name=", d.name, " path=", d.resource_path, " layers=", d.layers.size())
		for j in d.layers.size():
			var l = d.layers[j]
			if l:
				print("      layer[", j, "] instance=", l.get_instance_id(), " name=", l.layer_name, " type=", l.get_class())
	print("============================")