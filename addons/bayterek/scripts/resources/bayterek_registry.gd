@tool
class_name BayterekRegistry
extends Resource
## Tüm grupları tutan kök resource.

@export_storage var groups: Array[BayterekGroup] = []

func find_group_by_path(path: String) -> BayterekGroup:
	for g in groups:
		if g.resource_path == path:
			return g
	return null

func get_tree_by_path(path: String) -> BayterekTree:
	for g in groups:
		for t in g.trees:
			if t.resource_path == path:
				return t
	return null