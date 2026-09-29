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

## Adds a design to the registry.
##
## Guard against two failure modes that both produce the
## "new design looks like the old one" bug:
##
##   1. The SAME instance being added twice.
##   2. TWO DIFFERENT instances with the same `id` (a stale cached
##      resource slipping in alongside a freshly loaded one).
##
## In case 2 we replace the old entry with the new one, so
## `get_design_by_id()` always resolves to the freshest instance.
func add_design(design: BayterekNodeDesign) -> void:
	if not design:
		return

	# Guard 1: same instance already present.
	if designs.has(design):
		return

	# Guard 2: different instance, same id.
	if not design.id.is_empty():
		for existing in designs:
			if not existing:
				continue
			if existing.id == design.id:
				var idx: int = designs.find(existing)
				if idx >= 0:
					designs[idx] = design
				return

	designs.append(design)

func remove_design(design: BayterekNodeDesign) -> void:
	designs.erase(design)

## Removes any design whose id matches `design_id`.
## Returns true if something was removed.
func remove_design_by_id(design_id: String) -> bool:
	if design_id.is_empty():
		return false
	for i in range(designs.size() - 1, -1, -1):
		var d: BayterekNodeDesign = designs[i]
		if d and d.id == design_id:
			designs.remove_at(i)
			return true
	return false

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
		print("  [", i, "] instance=", d.get_instance_id(),
			" id=", d.id, " name=", d.name,
			" path=", d.resource_path, " layers=", d.layers.size())
		for j in d.layers.size():
			var l = d.layers[j]
			if l:
				print("      layer[", j, "] instance=", l.get_instance_id(),
					" id=", l.layer_id, " name=", l.layer_name,
					" type=", l.get_class())
	print("============================")